--[[
===============================================================================
 kn_gps3d / config
-----------------------------------------------------------------------------
 3D GPS リボン + 空中ウェイポイント・ビーコンの全設定。
 ロジック側 (client.lua) はこのテーブルを読むだけで、値を書き換えない。
 ※ 例外: currentRoutePreset のみ実行時のプリセット切替で更新される。
===============================================================================
]]

KnGps3dConfig = {
    -- 表示言語 ('ja' | 'en')
    -- チャット通知に適用される。ワールド内テキストは下記 worldTextAscii を参照。
    locale = 'ja',

    -- ワールド内 3D テキスト (モードバナー / ビーコン) を ASCII に固定する。
    -- GTA の DrawText はゲーム側フォントに日本語グリフが無いと文字化けするため既定 true。
    worldTextAscii = true,

    -- General
    enabled = true,
    drawWhenOnFoot = false,
    ignoredVehicleClasses = {
        [14] = true, -- boats
        [16] = true, -- planes
    },

    -- Route sources
    routeSource = 'manual',
    routeSources = {
        manual = true,
        blip = true,
        multi = false, -- intentionally ignored
    },
    enableExternalBlipRouteCapture = true,
    externalBlipRouteScanIntervalMs = 1000,
    routeSwitchKeysEnabled = true,
    shortcutRouteToggleEnabled = true,
    shortcutColorCycleEnabled = true,
    shortcutPresetCycleEnabled = true,
    shortcutGpsToggleEnabled = true,
    shortcutAnimationToggleEnabled = true,
    shortcutModifierKey = 21, -- SHIFT
    routeSwitchKeyUp = 188,
    routeColorKey = 246, -- Y
    routePresetKeyLeft = 189,
    routePresetKeyRight = 190,
    routeToggleKey = 187, -- DOWN
    routeAnimationToggleKey = 303, -- U
    routeToggleCooldownMs = 10000,

    -- Route sampling
    lowSpeedSampleStep = 6.0,
    mediumSpeedSampleStep = 7.5,
    highSpeedSampleStep = 9.0,
    lowSpeedRouteDistance = 90.0,
    mediumSpeedRouteDistance = 150.0,
    highSpeedRouteDistance = 200.0,
    mediumSpeedKmh = 100.0,
    highSpeedKmh = 200.0,

    -- Junction smoothing
    ignoreJunctionNodes = false,
    smoothJunctionTransitions = true,
    junctionPaddingPoints = 1,
    junctionCurveStrength = 0.22,
    junctionCurveMaxHandle = 6.2,

    -- Route placement
    routeHeight = 0.22,

    --[[
    ---------------------------------------------------------------------------
     GTA 本体の GPS 経路探索に対する調整
    ---------------------------------------------------------------------------
     このリソースは経路探索を行わず、ゲームが計算済みの GPS ルートを読んで
     3D 表示しているだけ (ミニマップの青線と同じ経路)。
     したがって「遠回りする」「地下に案内されない」は本体側の挙動であり、
     ここから触れるのは以下の本体フラグだけ。
    ---------------------------------------------------------------------------
    ]]
    gpsRouting = {
        --[[
         「GPS 非対象」フラグが付いた道 (裏路地・未舗装路など) も経路に使う。

         GTA の GPS は既定でこれらを避けるため遠回りになることがある。
         有効にすると近道が選ばれやすくなる。

         注意: これはクライアント全体の GPS 挙動を変えるグローバル設定で、
         ミニマップのルート線にも同じ影響が出る。
         効果は道路データ依存のため実機で確認すること。
        ]]
        ignoreNoGpsFlag = false,
    },

    --[[
    ---------------------------------------------------------------------------
     直線誘導
    ---------------------------------------------------------------------------
     道路ルートが目的地まで届いていない場合 (道路から離れた場所、地下施設など)、
     ルート終端から目的地まで直線の破線を引く。

     ルートが描画距離上限で切られているだけの場合 (目的地が単に遠い) は
     「届いていない」わけではないので引かない。
    ---------------------------------------------------------------------------
    ]]
    directGuidance = {
        enabled = true,
        minGapDistance = 20.0,   -- この距離以上離れていたら誘導線を引く
        maxGapDistance = 500.0,  -- これ以上離れている場合は引かない (誤判定対策)
        sampleStep = 4.0,
        color = { r = 255, g = 255, b = 255, a = 190 },
        ribbon = {
            width = 1.0,
            dashEnabled = true,
            dashLength = 1.6,
            dashGap = 2.2,
            repeatDistance = 1.6,
            nearFadeEnabled = false,
            worldStablePhase = false,
        },
    },

    -- Periodic update by velocity
    lowSpeedUpdateMs = 2500,
    mediumSpeedUpdateMs = 1500,
    highSpeedUpdateMs = 500,
    periodicRebuildEnabled = true,

    -- Route extend
    routeExtendNearEndEnabled = true,
    routeExtendNearEndPoints = 30,
    routeExtendNearEndDistance = 130.0,
    routeExtendMaxJoinDistance = 10.0,
    routeExtendCooldownMs = 700,

    -- Route trim
    routeTrimBehindEnabled = true,
    routeTrimKeepBehindPoints = 18,
    routeTrimMinHeadDistance = 100.0,

    -- Draw culling
    markerDrawAheadOnly = true,
    markerBehindCullBuffer = -2.5,

    -- Off-route rebuild
    offRouteRebuildEnabled = true,
    offRouteRebuildDistance = 14.0,
    offRouteRebuildConfirmMs = 500,
    offRouteRebuildCooldownMs = 1400,
    offRouteRebuildMinSpeedKmh = 100.0,

    -- Ground / Z
    routeGroundProbeEnabled = true,
    routeGroundProbeZ = 1000.0,
    routeGroundOffset = 0.0,
    routeGroundMaxDelta = 2.5,
    routeHeightAssistEnabled = false,
    routeHeightAssistBlend = 0.45,
    routeHeightAssistMaxDelta = 3.0,
    groundProbeCacheEnabled = true,
    groundProbeCacheCell = 1.0,
    groundProbeCacheTtlMs = 1200,
    groundProbeCacheMaxEntries = 1500,

    -- Ribbon
    texturedRoute = {
        width = 1.35,
        lift = 0.03,
        repeatDistance = 4.0,
        maxMiterScale = 1.35,
        nearFadeEnabled = true,
        nearFadeDistance = 12.0,
        nearFadeStartAlpha = 0.0,

        -- 破線モード (プリセット側 dash 指定で上書きされる)
        -- dashEnabled = true でリボンを dashLength / dashGap に分割する。
        dashEnabled = false,
        dashLength = 2.6,
        dashGap = 1.9,

        -- 破線・テクスチャ位相をワールドに固定する。
        -- false の場合、ルート再構築のたびに模様がプレイヤー基準で滑る。
        worldStablePhase = true,
    },

    -- Presets
    currentRoutePreset = 0,
    routePresets = {
        [0] = {
            name = 'Chevron Flat',
            nameKey = 'preset.chevronFlat',
            textureDict = 'chevrons',
            textureName = 'chevrons',
        },
        [1] = {
            name = 'Chevron Outlined',
            nameKey = 'preset.chevronOutline',
            textureDict = 'chevrons',
            textureName = 'chevron_line_06',
        },
        [2] = {
            name = 'Chevron Gloss',
            nameKey = 'preset.chevronGloss',
            textureDict = 'chevrons',
            textureName = 'chevron_fire_01',
        },
        [3] = {
            name = 'Chevron Beveled',
            nameKey = 'preset.chevronBevel',
            textureDict = 'chevrons',
            textureName = 'chevron_ice_01',
        },
        [4] = {
            name = 'Chevron Neon',
            nameKey = 'preset.chevronNeon',
            textureDict = 'chevrons',
            textureName = 'chevron_neon_01',
        },
        [5] = {
            name = 'Diagonal Hatch',
            nameKey = 'preset.hatch',
            textureDict = 'chevrons',
            textureName = 'chevron_line_05',
        },
        [6] = {
            name = 'Chevron Large',
            nameKey = 'preset.chevronLarge',
            textureDict = 'chevrons',
            textureName = 'chevron_line_07',
        },
        [7] = {
            name = 'Solid Band',
            nameKey = 'preset.solid',
            textureDict = 'chevrons',
            textureName = 'chevron_line_01',
        },
        [8] = {
            name = 'Solid Double Rail',
            nameKey = 'preset.solidDouble',
            textureDict = 'chevrons',
            textureName = 'chevron_line_02',
        },
        [9] = {
            name = 'Center Stripe',
            nameKey = 'preset.centerStripe',
            textureDict = 'chevrons',
            textureName = 'chevron_line_08',
        },
        [10] = {
            name = 'Bar Ladder',
            nameKey = 'preset.barLadder',
            textureDict = 'chevrons',
            textureName = 'chevron_line_04',
        },
        [11] = {
            name = 'Plain Band',
            nameKey = 'preset.plain',
            textureDict = 'chevrons',
            textureName = 'chevron_line_03',
        },

        --[[
         参照画像の青い破線スタイル。

         defaultColor / missionColor を持つプリセットは、適用時に色も上書きする。
         ribbon テーブルは Config.texturedRoute への上書き。
         既存 [0]-[11] はどちらも未指定なので従来どおり色・形状設定を変えない。

         注意: 参照画像の「角が丸い菱形」に完全一致するテクスチャは
         chevrons.ytd に含まれていない。ここでは最も近い chevron_line_03 を
         使っている。完全一致させるには CodeWalker で YTD にテクスチャを
         1 枚追加し、textureName を差し替える必要がある。
        ]]
        [12] = {
            name = 'Blue Dash',
            nameKey = 'preset.blueDash',
            textureDict = 'chevrons',
            textureName = 'chevron_line_03',
            defaultColor = { r = 47, g = 127, b = 208, a = 235 },
            missionColor = { r = 47, g = 127, b = 208, a = 235 },
            ribbon = {
                dashEnabled = true,
                dashLength = 2.6,
                dashGap = 1.9,
                width = 1.5,
                repeatDistance = 2.6,
                nearFadeEnabled = false,
            },
        },
    },
    routeColorPalette = {
        { name = 'Hot Red', color = { r = 255, g = 0, b = 0, a = 205 } },
        { name = 'Crimson', color = { r = 220, g = 20, b = 60, a = 205 } },
        { name = 'Orange Red', color = { r = 255, g = 69, b = 0, a = 205 } },
        { name = 'Amber', color = { r = 255, g = 140, b = 0, a = 205 } },
        { name = 'Gold', color = { r = 255, g = 184, b = 28, a = 205 } },
        { name = 'Sun Yellow', color = { r = 255, g = 214, b = 64, a = 205 } },
        { name = 'Rose Pink', color = { r = 255, g = 92, b = 138, a = 205 } },
        { name = 'Magenta', color = { r = 255, g = 0, b = 140, a = 205 } },
        { name = 'Ice Blue', color = { r = 100, g = 210, b = 255, a = 205 } },
        { name = 'White', color = { r = 255, g = 255, b = 255, a = 205 } },
        { name = 'Route Blue', color = { r = 47, g = 127, b = 208, a = 235 } },
    },

    -- Mode switch feedback
    modeFxEnabled = true,
    modeFxName = 'SwitchHUDOut',
    modeFxDurationMs = 300,
    modeFxSoundName = '5_SEC_WARNING',
    modeFxSoundSet = 'HUD_MINI_GAME_SOUNDSET',
    noRouteSoundName = 'ERROR',
    noRouteSoundSet = 'HUD_FRONTEND_DEFAULT_SOUNDSET',

    -- Extra animations
    extraAnimationsEnabled = true,
    animationOnEnabled = true,
    animationOffEnabled = true,
    geoAnimIntroProfile = 'on',
    geoAnimQuickOnProfile = 'on_fast',
    geoAnimOffProfile = 'off',

    -- 3D mode banner
    modeHintEnabled = true,
    modeHintDurationMs = 1800,
    modeHintAnchorOffsetZ = 1.1,
    modeHintTextOffsetZ = 2.0,
    modeHintLineColor = { r = 255, g = 255, b = 255, a = 165 },

    --[[
    ---------------------------------------------------------------------------
     空中ウェイポイント・ビーコン
    ---------------------------------------------------------------------------
     目的地の真上に、垂直ビーム + ▼マーカー + ラベル + 区切り線 + 距離 を表示する。

     ビームのみワールド座標 (3D) で描画し、上に積むテキスト類は
     ビーム上端をスクリーン投影した点を基準に「画面座標」で配置する。
     これにより距離が変わっても文字の間隔・大きさが一定に保たれる。
    ---------------------------------------------------------------------------
    ]]
    beacon = {
        enabled = true,

        -- どのルートソースで表示するか
        sources = {
            manual = true,
            blip = true,
        },

        -- 表示条件
        requireVehicle = true,   -- 車両搭乗中のみ表示 (false で徒歩でも表示)
        requireGpsEnabled = true, -- 3D GPS が OFF のときは表示しない
        maxDrawDistance = 0.0,   -- これより遠いと非表示 (0.0 = 無制限)
        hideCloserThan = 8.0,    -- これより近いと非表示 (0.0 = 無効)
        fadeRange = 12.0,        -- 上記しきい値の前後でフェードする距離 (m。0.0 で即消え)

        --[[
         画面内フィッティング。

         ビーム上端を固定ワールド高さにすると、目的地に近づくほど仰角が大きくなり
         上に積んだテキストが画面上端からはみ出して読めなくなる。
         有効時はスタックの合計高さを測り、はみ出す場合はビームを短くして
         全体が画面内に収まる高さまで自動的に引き下げる。
        ]]
        fitToScreen = true,
        fitMarginY = 0.03,       -- 画面上端から確保する余白 (画面高比)
        --[[
         フィッティングでビーム上端を下げられる最小の高さ (m)。

         これをビーム下端 (8m) にすると、目的地に近づいたとき 8m 上を
         見上げる形になりビーコンが視線より上に外れる。低めにしておくと
         接近するほどビーコンが目線まで降りてくる。
        ]]
        fitMinHeight = 2.0,
        --[[
         フィッティング結果の平滑化係数 (0.02〜1.0)。

         毎フレーム二分探索をやり直すとカメラの微動で結果が数 cm 揺れ、
         ▼ の細い輪郭線が振動して「ちらつき」として見える。
         小さいほど滑らかだが追従が遅れる。1.0 で平滑化なし。
        ]]
        fitSmoothing = 0.25,

        --[[
         垂直ビーム

         参照画像を実測すると、ビームは地面に接しておらず空中で終わっており、
         下端に向かってフェードしている (距離 110m の画面上サイズから逆算して
         地面から約 8m 〜 25m の区間)。それを既定値として再現する。
         地面まで伸ばしたい場合は beamBottomHeight = 0.0 にする。
        ]]
        beamEnabled = true,
        beamBottomHeight = 8.0,  -- 目的地の地面からのビーム下端 (m)
        beamTopHeight = 25.0,    -- 目的地の地面からのビーム上端 (m)
        beamColor = { r = 255, g = 255, b = 255, a = 235 },
        -- 下端フェードのための縦分割数 ('world' のときのみ使用)
        beamSegments = 14,
        -- 下端側の何割をフェード区間にするか (0.0 = フェードなし)
        beamFadeRatio = 0.45,

        --[[
         ビームの描画空間。

         'screen' (既定)
           ビーム上下端をスクリーン投影してから画面座標で描く。
           ▼ とビームが同じ投影を通るので、投影ネイティブに誤差があっても
           必ず真下に揃う。太さ (beamWidth) も指定できる。深度テストはされない。

         'world'
           DrawLine によるワールド 3D 描画 (v2.2.0 までの挙動)。
           建物に隠れるが、常に 1px 幅で、GetScreenCoordFromWorldCoord の
           投影とずれると ▼ の真下に来ない。
        ]]
        beamSpace = 'screen',
        beamWidth = 0.0016,      -- 'screen' のときの太さ (画面幅比。約 3px @1920)

        -- 'world' 用: DrawLine は常に 1px 幅なので、太く見せたい場合は本数を増やす。
        -- カメラに直交する方向へ beamLineSpacing(m) ずつずらして重ね描きする。
        beamLineCount = 2,
        beamLineSpacing = 0.06,

        --[[
         スクリーン投影のアスペクト比補正 (既定オフ)。

         GetScreenCoordFromWorldCoord が返す X が 16:9 基準になっており、
         16:10 / ウルトラワイドなど実解像度が 16:9 でない環境で、
         ワールド描画 (DrawLine / DrawTexturedPoly) の位置と横方向にずれる
         ---という仮説に対する補正。16:9 では何も起きない。

         【未検証】実機で確認するまで既定は false のままにしている。
         判定方法: ビーコンが路面リボンの終端の真上に来ていない場合は
         true にして改善するか見る。悪化するなら false へ戻す。
        ]]
        projectionAspectFix = false,

        --[[
         以下の寸法は参照画像 (1919x1082) の実測から逆算した初期値。
         GTA のテキストスケール → 実ピクセルの対応は解像度と font に依存するため、
         文字サイズ (labelScale / distanceScale) は実機で一度見てから微調整する。
         調整キー: markerWidth / markerHeight / labelScale / distanceScale /
                   separatorWidth / 各 *GapY
        ]]

        -- ▼ マーカー (画面座標。DrawRect の横棒を積んで三角形を作る)
        markerEnabled = true,
        markerWidth = 0.020,     -- 画面幅比 (実測 約37px / 1919px)
        markerHeight = 0.021,    -- 画面高比 (実測 約23px / 1082px)
        markerBars = 26,         -- 三角形の分割数。多いほど輪郭が滑らか
        markerFillColor = { r = 255, g = 255, b = 255, a = 96 },
        markerOutlineEnabled = true,
        markerOutlineColor = { r = 255, g = 255, b = 255, a = 240 },
        markerOutlineThickness = 0.0030,
        markerGapY = 0.002,      -- ビーム上端からマーカー下端までの画面距離

        -- 二重シェブロン (小さい ▼ を内側に重ねる)
        markerDoubleEnabled = false,
        markerDoubleScale = 0.62,
        markerDoubleAlpha = 0.8,
        markerDoubleGapY = 0.006,

        -- パルス (マーカーとビームのアルファを脈動させる。文字は対象外)
        pulseEnabled = false,
        pulsePeriodMs = 1600,
        pulseAmount = 0.18,      -- 0.0 = 変化なし / 1.0 = 完全に消えるまで

        -- ラベル ('WAYPOINT')
        labelEnabled = true,
        labelScale = 0.50,
        labelFont = 4,
        labelColor = { r = 255, g = 255, b = 255, a = 245 },
        labelGapY = 0.018,       -- マーカー上端からの画面距離

        -- 区切り線 (参照画像のライムグリーン)
        separatorEnabled = true,
        -- 'screen' = 水平な DrawRect (距離が変わっても崩れない)
        -- 'world'  = カメラ直交の 3D DrawLine (参照画像のわずかな傾きを再現)
        separatorMode = 'screen',
        separatorColor = { r = 168, g = 224, b = 74, a = 255 },
        separatorWidth = 0.078,  -- 画面幅比 ('screen' 時。実測 約153px / 1919px)
        separatorThickness = 0.0016,
        separatorWorldWidth = 5.0,      -- m ('world' 時)
        separatorWorldOffsetZ = 4.0,    -- ビーム上端からの高さ (m) ('world' 時)
        separatorGapY = 0.006,   -- ラベル上端からの画面距離

        -- 距離表示 ('110' + 小さい 'M')
        distanceEnabled = true,
        distanceScale = 0.85,
        distanceSuffixScale = 0.45,
        distanceFont = 4,
        distanceColor = { r = 255, g = 255, b = 255, a = 250 },
        distanceGapY = 0.022,    -- 区切り線からの画面距離
        distanceSuffixGapX = 0.002,
        -- 'direct' = プレイヤーから目的地までの水平直線距離
        -- 'route'  = GPS ルートに沿った残り距離
        distanceMode = 'direct',
        distanceKmEnabled = true,
        distanceKmThreshold = 1000.0,
        distanceKmDecimals = 1,

        --[[
         画面内維持。

         目的地が画面の横や背後にあるとビーコンごと視界から消えて方角を失うため、
         カメラ空間で方向を求めて画面端にクランプする。
         クランプ中はワールド座標のビームが画面に映らないので省略し、
         寄っている端に応じて向きを変えた矢印 + 距離だけの簡易表示にする。

         false にすると画面外では何も描かない (従来動作)。
        ]]
        keepOnScreen = true,
        clampMarginX = 0.06,     -- 画面端から確保する余白 (画面幅比)
        clampMarginY = 0.08,     -- 画面端から確保する余白 (画面高比)
        clampedShowDistance = true, -- クランプ中も距離を出す
        clampedDistanceGapY = 0.006,

        -- 建物の裏に目的地があるときビーコン全体を隠す。
        -- 毎フレームではなく occlusionCheckIntervalMs 間隔でレイキャストする。
        -- コストがあるため既定 false。
        occlusionCheckEnabled = false,
        occlusionCheckIntervalMs = 250,

        -- 目的地の地面 Z を再取得する間隔 (目的地が変わらない限り再利用する)
        groundProbeRefreshMs = 1500,

        --[[
         パレット。

         上の各色が既定値で、ここで宣言したキーだけを状況に応じて上書きする。
         優先順位: near > mission > 既定

           mission : MISSION ルート (他スクリプトの routed blip) 追従時 = 金色
           near    : 目的地まで nearDistance 以内に入ったとき = 「もうすぐ着く」

         不要なら nearHighlightEnabled = false、
         あるいは palettes.near / palettes.mission ごと消せば常に既定色になる。
        ]]
        nearHighlightEnabled = true,
        nearDistance = 60.0,

        palettes = {
            mission = {
                beamColor = { r = 255, g = 214, b = 64, a = 235 },
                markerFillColor = { r = 255, g = 214, b = 64, a = 96 },
                markerOutlineColor = { r = 255, g = 226, b = 120, a = 240 },
                separatorColor = { r = 255, g = 184, b = 28, a = 255 },
                labelColor = { r = 255, g = 226, b = 120, a = 245 },
                distanceColor = { r = 255, g = 240, b = 190, a = 250 },
            },

            -- 既定の区切り線がライムグリーンなので、緑系だと差が分かりにくい。
            -- 接近が一目で分かるようシアン寄りにして文字色も変える。
            near = {
                beamColor = { r = 64, g = 226, b = 255, a = 245 },
                markerFillColor = { r = 64, g = 226, b = 255, a = 130 },
                markerOutlineColor = { r = 150, g = 240, b = 255, a = 250 },
                separatorColor = { r = 64, g = 226, b = 255, a = 255 },
                labelColor = { r = 150, g = 240, b = 255, a = 250 },
                distanceColor = { r = 200, g = 248, b = 255, a = 255 },
            },
        },
    },
}
