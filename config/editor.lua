--[[
===============================================================================
 kn_gps3d / config/editor.lua
-----------------------------------------------------------------------------
 /gpsedit 設定パネルの項目定義。

 パネルの見た目 (web/) も適用処理 (client/editor.lua) もこのスキーマから
 生成される。項目を増やすときはここに 1 行足すだけでよい。
 適用先は id の接頭辞で決まる:

   route.*   ルート全体 (client.lua の KnGps3dInternal 経由)
   ribbon.*  リボンの実効設定への上書き (RIBBON_KEYS に含まれるキーのみ)
   beacon.*  ビーコン設定への上書き (client/beacon.lua)

 例外は client/editor.lua の SPECIAL_FIELDS で処理する。

 表示名は locales の editor.field.<id> / editor.section.<id> /
 editor.option.<値> から引く。

 【重要】NUI から来る値は信用しない。ここの min/max/step/options が
 そのままクライアント側の検証に使われる。ループ回数や描画数に効く値を
 追加するときは必ず現実的な上限を入れること。
===============================================================================
]]

KnGps3dEditorConfig = {
    enabled = true,
    commandName = 'gpsedit',

    -- ポーズメニュー > キー設定 に項目を出す (既定は未割り当て)
    keyMappingEnabled = true,
    keyMappingDefault = '',

    --[[
     パネルを開いている間もゲーム側にキー入力を流す。
     true にすると調整しながら運転できるが、WASD 等がゲームとパネルの
     両方に届くため既定は false。
    ]]
    keepGameInput = false,

    -- 変更が止まってから保存するまでの待ち時間 (ms)
    saveDebounceMs = 800,

    -- 保存先 (クライアント KVP。プレイヤーごとにローカル保存される)
    kvpKey = 'kn_gps3d:settings',
}

KnGps3dEditorSchema = {
    -- 保存データの互換判定に使う。項目の意味を変えたら上げる。
    version = 1,

    sections = {
        {
            id = 'display',
            fields = {
                { id = 'route.enabled', kind = 'toggle' },
                { id = 'beacon.enabled', kind = 'toggle' },
                { id = 'route.extraAnimations', kind = 'toggle' },
                { id = 'route.source', kind = 'choice', options = { 'manual', 'blip' } },
            },
        },

        {
            id = 'ribbon',
            fields = {
                { id = 'route.preset', kind = 'preset' },
                {
                    id = 'route.color',
                    kind = 'color',
                    tabs = { 'route.defaultColor', 'route.missionColor' },
                },
                { id = 'ribbon.width', kind = 'slider', min = 0.2, max = 4.0, step = 0.05, decimals = 2 },
                { id = 'ribbon.lift', kind = 'slider', min = 0.0, max = 1.5, step = 0.01, decimals = 2 },
                { id = 'ribbon.repeatDistance', kind = 'slider', min = 0.5, max = 16.0, step = 0.1, decimals = 1 },
                { id = 'ribbon.dashEnabled', kind = 'toggle' },
                { id = 'ribbon.dashLength', kind = 'slider', min = 0.3, max = 10.0, step = 0.1, decimals = 1 },
                { id = 'ribbon.dashGap', kind = 'slider', min = 0.1, max = 10.0, step = 0.1, decimals = 1 },
                { id = 'ribbon.nearFadeEnabled', kind = 'toggle' },
                { id = 'ribbon.nearFadeDistance', kind = 'slider', min = 0.0, max = 40.0, step = 0.5, decimals = 1 },
                { id = 'route.distanceScale', kind = 'slider', min = 0.5, max = 2.5, step = 0.05, decimals = 2 },
            },
        },

        {
            id = 'beacon',
            fields = {
                {
                    id = 'beacon.color',
                    kind = 'color',
                    tabs = {
                        'beacon.beamColor',
                        'beacon.markerFillColor',
                        'beacon.labelColor',
                        'beacon.separatorColor',
                        'beacon.distanceColor',
                    },
                },
                { id = 'beacon.beamBottomHeight', kind = 'slider', min = 0.0, max = 30.0, step = 0.5, decimals = 1 },
                { id = 'beacon.beamTopHeight', kind = 'slider', min = 5.0, max = 60.0, step = 0.5, decimals = 1 },
                { id = 'beacon.beamWidth', kind = 'slider', min = 0.0004, max = 0.006, step = 0.0002, decimals = 4 },
                { id = 'beacon.markerScale', kind = 'slider', min = 0.3, max = 3.0, step = 0.05, decimals = 2 },
                { id = 'beacon.labelScale', kind = 'slider', min = 0.2, max = 1.5, step = 0.01, decimals = 2 },
                { id = 'beacon.distanceScale', kind = 'slider', min = 0.2, max = 2.0, step = 0.01, decimals = 2 },
                { id = 'beacon.distanceMode', kind = 'choice', options = { 'direct', 'route' } },
                { id = 'beacon.hideCloserThan', kind = 'slider', min = 0.0, max = 50.0, step = 1.0, decimals = 0 },
                { id = 'beacon.labelEnabled', kind = 'toggle' },
                { id = 'beacon.separatorEnabled', kind = 'toggle' },
            },
        },
    },
}
