--[[
===============================================================================
 kn_gps3d / client/editor.lua
-----------------------------------------------------------------------------
 /gpsedit 設定パネル。

 config/editor.lua のスキーマを唯一の定義として、
   - NUI へ渡す項目リストの組み立て
   - NUI から返ってきた値の検証と適用
   - クライアント KVP への保存 / 復元
 を行う。

 値の適用先は id の接頭辞で決まり、例外だけ SPECIAL_GET / SPECIAL_SET で扱う。

 【セキュリティ】NUI からのメッセージは信用しない。
 このパネルはサーバー通信も金銭もアイテムも扱わないため実害は自分の描画だけだが、
 ループ回数や描画数に効く値に NaN や極端な数値が入るとクライアントが固まる。
 したがって受信値は必ずスキーマの min/max/options で検証してから適用する。
===============================================================================
]]

local Config = KnGps3dConfig
local L = KnGps3dL
local EditorConfig = KnGps3dEditorConfig
local Schema = KnGps3dEditorSchema

local editorState = {
    open = false,
    -- NUI ページの JS が起動して 'ready' を返したか
    pageReady = false,
    -- 既定から変更された値だけを保持する (保存対象)
    overrides = {},
    saveAt = 0,
    saveQueued = false,
}

-- ▼ の大きさはスキーマ上 1 本のスライダーだが、実体は幅と高さの 2 値。
-- 倍率の基準となる Config の初期値を起動時に控えておく。
local BASE_MARKER_WIDTH = tonumber(Config.beacon and Config.beacon.markerWidth) or 0.020
local BASE_MARKER_HEIGHT = tonumber(Config.beacon and Config.beacon.markerHeight) or 0.021

-------------------------------------------------------------------------------
-- スキーマ索引
-------------------------------------------------------------------------------

local FIELDS = {}

local function indexSchema()
    for _, section in ipairs(Schema.sections or {}) do
        for _, field in ipairs(section.fields or {}) do
            if field.kind == 'color' then
                -- 色ウィジェットのタブはそれぞれが独立した設定値
                for _, tabId in ipairs(field.tabs or {}) do
                    FIELDS[tabId] = { id = tabId, kind = 'colorValue' }
                end
            else
                FIELDS[field.id] = field
            end
        end
    end
end

indexSchema()

-------------------------------------------------------------------------------
-- ブリッジ
-------------------------------------------------------------------------------

local function routeApi()
    local api = KnGps3dInternal
    return type(api) == 'table' and api or nil
end

local function beaconApi()
    local api = KnGps3dBeaconInternal
    return type(api) == 'table' and api or nil
end

local function suffixOf(id)
    return string.match(id, '^[^.]+%.(.+)$')
end

-------------------------------------------------------------------------------
-- 値の取得 / 適用
-------------------------------------------------------------------------------

local SPECIAL_GET = {
    ['route.enabled'] = function()
        local api = routeApi()
        return api ~= nil and api.isEnabled() == true
    end,

    ['route.extraAnimations'] = function()
        local api = routeApi()
        return api ~= nil and api.getExtraAnimations() == true
    end,

    ['route.source'] = function()
        local api = routeApi()
        return api and api.getRouteSource() or 'manual'
    end,

    ['route.preset'] = function()
        local api = routeApi()
        return api and api.getPresetIndex() or 0
    end,

    ['route.defaultColor'] = function()
        local api = routeApi()
        return api and api.getRouteColor('default') or nil
    end,

    ['route.missionColor'] = function()
        local api = routeApi()
        return api and api.getRouteColor('mission') or nil
    end,

    ['route.distanceScale'] = function()
        local api = routeApi()
        return api and api.getRouteDistanceScale() or 1.0
    end,

    ['beacon.enabled'] = function()
        local api = beaconApi()
        return api ~= nil and api.isEnabled() == true
    end,

    ['beacon.markerScale'] = function()
        local api = beaconApi()
        if not api or BASE_MARKER_WIDTH <= 0.0 then
            return 1.0
        end

        local current = tonumber(api.getValue('markerWidth')) or BASE_MARKER_WIDTH
        return current / BASE_MARKER_WIDTH
    end,
}

local SPECIAL_SET = {
    ['route.enabled'] = function(value)
        local api = routeApi()
        if not api then
            return false
        end

        api.setEnabled(value)
        return true
    end,

    ['route.extraAnimations'] = function(value)
        local api = routeApi()
        return api ~= nil and api.setExtraAnimations(value) == true
    end,

    ['route.source'] = function(value)
        local api = routeApi()
        return api ~= nil and api.setRouteSource(value) == true
    end,

    ['route.preset'] = function(value)
        local api = routeApi()
        return api ~= nil and api.setPreset(value) == true
    end,

    ['route.defaultColor'] = function(value)
        local api = routeApi()
        if not api then
            return false
        end

        api.setRouteColor('default', value.r, value.g, value.b, value.a)
        return true
    end,

    ['route.missionColor'] = function(value)
        local api = routeApi()
        if not api then
            return false
        end

        api.setRouteColor('mission', value.r, value.g, value.b, value.a)
        return true
    end,

    ['route.distanceScale'] = function(value)
        local api = routeApi()
        return api ~= nil and api.setRouteDistanceScale(value) == true
    end,

    ['beacon.enabled'] = function(value)
        local api = beaconApi()
        if not api then
            return false
        end

        api.setEnabled(value)
        return true
    end,

    ['beacon.markerScale'] = function(value)
        local api = beaconApi()
        if not api then
            return false
        end

        api.setOverride('markerWidth', BASE_MARKER_WIDTH * value)
        api.setOverride('markerHeight', BASE_MARKER_HEIGHT * value)
        return true
    end,
}

--[[
 上書きの解除。

 ribbon.* / beacon.* は上書きテーブルからキーを消せば Config / プリセットの値へ
 自然に戻るが、既存のセッター経由で適用している項目 (下記) は「戻す先」を
 明示しないと戻せない。Config は書き換えないので初期値は起動時のまま参照できる。
 プリセット番号だけは applyRoutePreset が Config.currentRoutePreset を
 書き戻すため、起動時の値を控えておく。
]]
local BASE_PRESET_INDEX = Config.currentRoutePreset or 0

local function currentPresetTable()
    local api = routeApi()
    local index = api and api.getPresetIndex() or BASE_PRESET_INDEX
    return (Config.routePresets or {})[index]
end

local SPECIAL_CLEAR = {
    ['route.enabled'] = function()
        local api = routeApi()
        if not api then
            return false
        end

        api.setEnabled(Config.enabled ~= false)
        return true
    end,

    ['route.extraAnimations'] = function()
        local api = routeApi()
        return api ~= nil and api.setExtraAnimations(Config.extraAnimationsEnabled ~= false) == true
    end,

    ['route.source'] = function()
        local api = routeApi()
        return api ~= nil and api.setRouteSource(Config.routeSource or 'manual') == true
    end,

    ['route.preset'] = function()
        local api = routeApi()
        return api ~= nil and api.setPreset(BASE_PRESET_INDEX) == true
    end,

    -- プリセットが色を持たない場合は現在色のまま (プリセット [0]-[11] は未指定)
    ['route.defaultColor'] = function()
        local api = routeApi()
        local preset = currentPresetTable()
        if not api or not preset or not preset.defaultColor then
            return false
        end

        api.setRouteColor('default', preset.defaultColor.r, preset.defaultColor.g,
            preset.defaultColor.b, preset.defaultColor.a)
        return true
    end,

    ['route.missionColor'] = function()
        local api = routeApi()
        local preset = currentPresetTable()
        if not api or not preset or not preset.missionColor then
            return false
        end

        api.setRouteColor('mission', preset.missionColor.r, preset.missionColor.g,
            preset.missionColor.b, preset.missionColor.a)
        return true
    end,

    ['route.distanceScale'] = function()
        local api = routeApi()
        return api ~= nil and api.setRouteDistanceScale(1.0) == true
    end,

    ['beacon.enabled'] = function()
        local api = beaconApi()
        if not api then
            return false
        end

        api.setEnabled(not (Config.beacon and Config.beacon.enabled == false))
        return true
    end,

    ['beacon.markerScale'] = function()
        local api = beaconApi()
        if not api then
            return false
        end

        api.setOverride('markerWidth', nil)
        api.setOverride('markerHeight', nil)
        return true
    end,
}

local function getValue(id)
    local special = SPECIAL_GET[id]
    if special then
        return special()
    end

    local key = suffixOf(id)
    if key == nil then
        return nil
    end

    if string.sub(id, 1, 7) == 'ribbon.' then
        local api = routeApi()
        return api and api.getRibbonValue(key)
    end

    if string.sub(id, 1, 7) == 'beacon.' then
        local api = beaconApi()
        return api and api.getValue(key)
    end

    return nil
end

local function applyValue(id, value)
    local special = SPECIAL_SET[id]
    if special then
        return special(value)
    end

    local key = suffixOf(id)
    if key == nil then
        return false
    end

    if string.sub(id, 1, 7) == 'ribbon.' then
        local api = routeApi()
        return api ~= nil and api.setRibbonOverride(key, value) == true
    end

    if string.sub(id, 1, 7) == 'beacon.' then
        local api = beaconApi()
        return api ~= nil and api.setOverride(key, value) == true
    end

    return false
end

local function clearValue(id)
    local special = SPECIAL_CLEAR[id]
    if special then
        special()
    else
        -- ribbon.* / beacon.* は nil を渡せば上書きが外れる
        applyValue(id, nil)
    end

    editorState.overrides[id] = nil
end

-------------------------------------------------------------------------------
-- 検証
--
-- ここを通っていない値は絶対に適用しない。
-------------------------------------------------------------------------------

local function isFiniteNumber(value)
    local numeric = tonumber(value)
    if numeric == nil then
        return nil
    end

    -- NaN は自分自身と等しくない / inf は上限比較で弾く
    if numeric ~= numeric or numeric == math.huge or numeric == -math.huge then
        return nil
    end

    return numeric
end

local function sanitizeColor(value)
    if type(value) ~= 'table' then
        return nil
    end

    local channels = {}
    for _, key in ipairs({ 'r', 'g', 'b', 'a' }) do
        local numeric = isFiniteNumber(value[key])
        if numeric == nil then
            if key ~= 'a' then
                return nil
            end
            numeric = 255
        end
        channels[key] = math.floor(math.max(0, math.min(255, numeric)))
    end

    return channels
end

local function sanitize(field, value)
    local kind = field.kind

    if kind == 'toggle' then
        return value == true
    end

    if kind == 'colorValue' then
        return sanitizeColor(value)
    end

    if kind == 'choice' then
        for _, option in ipairs(field.options or {}) do
            if option == value then
                return value
            end
        end
        return nil
    end

    if kind == 'preset' then
        local numeric = isFiniteNumber(value)
        if numeric == nil then
            return nil
        end

        --[[
         存在しない番号は弾く。「適用されていない値」が上書きとして保存されると
         KVP 復元時とリセット表示が実際とずれるため。
         2.5.2 で applyRoutePreset 側も範囲外を失敗として返すようになったが、
         保存経路の検証はここで完結させておく (呼び順に依存させない)。
        ]]
        local index = math.floor(numeric)
        if (Config.routePresets or {})[index] == nil then
            return nil
        end

        return index
    end

    if kind == 'slider' then
        local numeric = isFiniteNumber(value)
        if numeric == nil then
            return nil
        end

        local min = isFiniteNumber(field.min) or 0.0
        local max = isFiniteNumber(field.max) or 1.0
        return math.max(min, math.min(max, numeric))
    end

    return nil
end

-------------------------------------------------------------------------------
-- 永続化 (クライアント KVP)
-------------------------------------------------------------------------------

local function kvpKey()
    return EditorConfig.kvpKey or 'kn_gps3d:settings'
end

local function queueSave()
    editorState.saveQueued = true
    editorState.saveAt = GetGameTimer() + (tonumber(EditorConfig.saveDebounceMs) or 800)
end

local function saveNow()
    editorState.saveQueued = false

    if next(editorState.overrides) == nil then
        DeleteResourceKvp(kvpKey())
        return
    end

    local ok, encoded = pcall(json.encode, {
        v = Schema.version,
        values = editorState.overrides,
    })

    if ok and type(encoded) == 'string' then
        SetResourceKvp(kvpKey(), encoded)
    end
end

local function loadSaved()
    local raw = GetResourceKvpString(kvpKey())
    if type(raw) ~= 'string' or raw == '' then
        return
    end

    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' or type(decoded.values) ~= 'table' then
        DeleteResourceKvp(kvpKey())
        return
    end

    --[[
     スキーマのバージョンが違う場合は項目の意味が変わっている可能性があるため
     復元せず捨てる。中途半端に適用すると原因の分からない見た目になる。
    ]]
    if tonumber(decoded.v) ~= Schema.version then
        DeleteResourceKvp(kvpKey())
        return
    end

    local function restore(id, value)
        local field = FIELDS[id]
        if not field then
            return
        end

        local clean = sanitize(field, value)
        if clean ~= nil and applyValue(id, clean) then
            editorState.overrides[id] = clean
        end
    end

    --[[
     AR 演出の設定を先に戻す。pairs の順序は不定なので、後回しになると
     route.enabled の復元で演出が一度流れてしまう (演出を切ってあるのに)。
    ]]
    if decoded.values['route.extraAnimations'] ~= nil then
        restore('route.extraAnimations', decoded.values['route.extraAnimations'])
    end

    for id, value in pairs(decoded.values) do
        if id ~= 'route.extraAnimations' then
            restore(id, value)
        end
    end
end

-------------------------------------------------------------------------------
-- NUI ペイロード
-------------------------------------------------------------------------------

local function labelFor(key, fallback)
    local text = L(key)
    -- ロケール未定義のとき KnGps3dL はキーをそのまま返す
    if text == key then
        return fallback or key
    end

    return text
end

local function buildOptions(field)
    local options = {}

    for _, value in ipairs(field.options or {}) do
        options[#options + 1] = {
            value = value,
            label = labelFor('editor.option.' .. value, value),
        }
    end

    return options
end

local function buildPresets()
    local api = routeApi()
    local list = api and api.listPresets() or {}
    local options = {}

    for _, entry in ipairs(list) do
        options[#options + 1] = {
            value = entry.index,
            label = entry.name,
            -- パネルにサムネイルを出すためのテクスチャ名 (web/thumb/<名前>.png)
            texture = entry.texture,
        }
    end

    return options
end

local function buildTabs(field)
    local tabs = {}

    for _, tabId in ipairs(field.tabs or {}) do
        tabs[#tabs + 1] = {
            id = tabId,
            label = labelFor('editor.tab.' .. tabId, tabId),
            value = getValue(tabId),
            dirty = editorState.overrides[tabId] ~= nil,
        }
    end

    return tabs
end

local function buildPayload()
    local sections = {}

    for _, section in ipairs(Schema.sections or {}) do
        local fields = {}

        for _, field in ipairs(section.fields or {}) do
            local entry = {
                id = field.id,
                kind = field.kind,
                label = labelFor('editor.field.' .. field.id, field.id),
            }

            if field.kind == 'color' then
                entry.tabs = buildTabs(field)
            elseif field.kind == 'choice' then
                entry.options = buildOptions(field)
                entry.value = getValue(field.id)
                entry.dirty = editorState.overrides[field.id] ~= nil
            elseif field.kind == 'preset' then
                entry.options = buildPresets()
                entry.value = getValue(field.id)
                entry.dirty = editorState.overrides[field.id] ~= nil
            else
                entry.value = getValue(field.id)
                entry.min = field.min
                entry.max = field.max
                entry.step = field.step
                entry.decimals = field.decimals
                entry.dirty = editorState.overrides[field.id] ~= nil
            end

            fields[#fields + 1] = entry
        end

        sections[#sections + 1] = {
            id = section.id,
            label = labelFor('editor.section.' .. section.id, section.id),
            fields = fields,
        }
    end

    return {
        action = 'open',
        title = labelFor('editor.title', 'GPS Settings'),
        subtitle = labelFor('editor.subtitle', ''),
        text = {
            reset = labelFor('editor.reset', 'Reset'),
            resetAll = labelFor('editor.resetAll', 'Reset everything'),
            resetAllConfirm = labelFor('editor.resetAllConfirm', 'Press again'),
            close = labelFor('editor.close', 'Close'),
            saved = labelFor('editor.saved', 'Saved'),
        },
        sections = sections,
    }
end

-------------------------------------------------------------------------------
-- 開閉
-------------------------------------------------------------------------------

local function closeEditor()
    if not editorState.open then
        return
    end

    editorState.open = false
    SetNuiFocus(false, false)
    -- keepGameInput で立てたフラグは明示的に降ろす (他リソースの NUI に残る)
    if type(SetNuiFocusKeepInput) == 'function' then
        SetNuiFocusKeepInput(false)
    end
    SendNUIMessage({ action = 'close' })

    if editorState.saveQueued then
        saveNow()
    end
end

local function openEditor()
    if editorState.open then
        closeEditor()
        return
    end

    --[[
     ページの JS が動いていないのにフォーカスを渡すと、パネルも出ないうえ
     ESC も効かずカーソルが取られたままになる。ready を受け取るまで開かない。
    ]]
    if not editorState.pageReady then
        TriggerEvent('chat:addMessage', {
            color = { 255, 255, 255 },
            multiline = false,
            args = { L('chat.prefix'), L('editor.notReady') },
        })
        return
    end

    editorState.open = true
    SendNUIMessage(buildPayload())

    if EditorConfig.keepGameInput == true then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)
    else
        SetNuiFocus(true, true)
    end
end

-------------------------------------------------------------------------------
-- NUI コールバック
-------------------------------------------------------------------------------

RegisterNUICallback('ready', function(_, cb)
    editorState.pageReady = true
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closeEditor()
    cb({ ok = true })
end)

RegisterNUICallback('set', function(data, cb)
    if type(data) ~= 'table' or type(data.id) ~= 'string' then
        cb({ ok = false })
        return
    end

    local field = FIELDS[data.id]
    if not field then
        cb({ ok = false })
        return
    end

    local clean = sanitize(field, data.value)
    if clean == nil then
        cb({ ok = false })
        return
    end

    if not applyValue(data.id, clean) then
        cb({ ok = false })
        return
    end

    editorState.overrides[data.id] = clean
    queueSave()

    --[[
     プリセットを変えるとリボンの「基底値」が総入れ替えになるため、
     上書きしていない項目の表示が実際とずれる。パネルごと組み直させる。
    ]]
    if data.id == 'route.preset' then
        cb({ ok = true, payload = buildPayload() })
        return
    end

    -- 適用後の実効値を返す (クランプで丸められた場合に UI を追従させる)
    cb({ ok = true, value = getValue(data.id) })
end)

RegisterNUICallback('reset', function(data, cb)
    if type(data) ~= 'table' or type(data.id) ~= 'string' then
        cb({ ok = false })
        return
    end

    local field = FIELDS[data.id]
    if not field then
        cb({ ok = false })
        return
    end

    clearValue(data.id)
    queueSave()

    if data.id == 'route.preset' then
        cb({ ok = true, payload = buildPayload() })
        return
    end

    cb({ ok = true, value = getValue(data.id) })
end)

RegisterNUICallback('resetAll', function(_, cb)
    -- 上書きされている項目だけを個別に戻す
    local ids = {}
    for id in pairs(editorState.overrides) do
        ids[#ids + 1] = id
    end

    for _, id in ipairs(ids) do
        clearValue(id)
    end

    -- 取りこぼし対策 (スキーマから消えた古いキーなど)
    local route = routeApi()
    if route then
        route.clearRibbonOverrides()
    end

    local beacon = beaconApi()
    if beacon then
        beacon.clearOverrides()
    end

    editorState.overrides = {}
    saveNow()

    TriggerEvent('chat:addMessage', {
        color = { 255, 255, 255 },
        multiline = false,
        args = { L('chat.prefix'), L('editor.notify.reset') },
    })

    -- 現在値でパネルを組み直す
    cb({ ok = true, payload = buildPayload() })
end)

-------------------------------------------------------------------------------
-- コマンド / 保存スレッド
-------------------------------------------------------------------------------

if EditorConfig.enabled ~= false then
    local commandName = EditorConfig.commandName or 'gpsedit'

    RegisterCommand(commandName, function()
        openEditor()
    end, false)

    if EditorConfig.keyMappingEnabled ~= false then
        RegisterKeyMapping(commandName, labelFor('editor.title', 'GPS Settings'),
            'keyboard', EditorConfig.keyMappingDefault or '')
    end

    -- コマンド名は EditorConfig.commandName で変更できるので、候補もそれに追従させる
    CreateThread(function()
        Wait(1000)
        TriggerEvent('chat:addSuggestion', '/' .. commandName, KnGps3dL('suggest.edit'))
    end)

    CreateThread(function()
        --[[
         プレイヤーが読み込まれる前に復元するとルート再構築が空振りするため、
         ped が出てくるまで待つ (上限 20 秒)。
        ]]
        local waited = 0
        while PlayerPedId() == 0 and waited < 20000 do
            waited = waited + 100
            Wait(100)
        end

        Wait(500)
        loadSaved()

        while true do
            if editorState.saveQueued and GetGameTimer() >= editorState.saveAt then
                saveNow()
            end

            Wait(500)
        end
    end)

    AddEventHandler('onResourceStop', function(resourceName)
        if resourceName ~= GetCurrentResourceName() then
            return
        end

        if editorState.open then
            SetNuiFocus(false, false)
            if type(SetNuiFocusKeepInput) == 'function' then
                SetNuiFocusKeepInput(false)
            end
        end
    end)
end
