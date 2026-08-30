--[[
===============================================================================
 kn_gps3d / locale runtime
-----------------------------------------------------------------------------
 KnGps3dLocales[lang][key] = 文字列 (string.format 用の書式を含む)

 KnGps3dL(key, ...)      : 通常の翻訳取得 (チャット通知など)
 KnGps3dWorldL(key, ...) : ワールド内 3D テキスト用の翻訳取得

 ワールド内テキストは GTA の DrawText で描画されるため、ゲーム側フォントに
 グリフが無い文字 (日本語など) は文字化けする。Config.worldTextAscii = true の
 場合は非 ASCII を含む文字列を検出して英語版へフォールバックする。
===============================================================================
]]

KnGps3dLocales = KnGps3dLocales or {}

local FALLBACK_LANG = 'en'

local function resolve(lang, key)
    local table_ = KnGps3dLocales[lang]
    if type(table_) == 'table' and table_[key] ~= nil then
        return table_[key]
    end

    return nil
end

local function currentLang()
    local config = KnGps3dConfig
    if type(config) == 'table' and type(config.locale) == 'string' and config.locale ~= '' then
        return config.locale
    end

    return FALLBACK_LANG
end

local function format(template, ...)
    if select('#', ...) == 0 then
        return template
    end

    local ok, result = pcall(string.format, template, ...)
    if ok then
        return result
    end

    -- 書式と引数が食い違っても描画を止めない
    return template
end

function KnGps3dL(key, ...)
    local template = resolve(currentLang(), key)
        or resolve(FALLBACK_LANG, key)
        or key

    return format(template, ...)
end

local function hasNonAscii(text)
    if type(text) ~= 'string' then
        return false
    end

    for i = 1, #text do
        if text:byte(i) > 127 then
            return true
        end
    end

    return false
end

function KnGps3dWorldL(key, ...)
    local lang = currentLang()
    local template = resolve(lang, key)

    local config = KnGps3dConfig
    local asciiOnly = type(config) ~= 'table' or config.worldTextAscii ~= false

    if template == nil or (asciiOnly and hasNonAscii(template)) then
        template = resolve(FALLBACK_LANG, key) or template or key
    end

    return format(template, ...)
end
