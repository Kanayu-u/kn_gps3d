KnGps3dLocales = KnGps3dLocales or {}

--[[
 hud.* と beacon.* は GTA の DrawText でワールド内に描画されるため、
 ゲーム側フォントにグリフが無い日本語は文字化けする。
 そのため既定では ASCII のままにしてある。

 日本語表示を試したい場合は Config.worldTextAscii = false にしてから
 hud.* / beacon.* を書き換える (環境によっては表示されない)。
 チャット通知 (notify.*) は NUI 経由なので日本語で問題ない。
]]

KnGps3dLocales['ja'] = {
    -- チャット表示名
    ['chat.prefix'] = 'kn_gps3d',

    -- ルートソース名
    ['route.user'] = 'ユーザー',
    ['route.mission'] = 'ミッション',

    -- チャット通知
    ['notify.routeActive'] = '有効なルート: ^3%s^7',
    ['notify.routeUserFailed'] = '^1ユーザールートに切替できません:^7 %s',
    ['notify.routeMissionFailed'] = '^1ミッションルートに切替できません:^7 %s',
    ['notify.status'] = 'ソース: ^3%s^7 | プリセット: ^5%d - %s^7 | 点数: %d | スロット: %s | 利用可能: [%s]',
    ['notify.presetSelected'] = 'プリセット ^3%d^7 を適用: %s',
    ['notify.presetStatus'] = 'プリセット: ^3%d^7 - %s',
    ['notify.presetInvalid'] = '^1プリセット番号が不正です。^7',
    ['notify.colorDefault'] = 'ユーザールートの色を rgba(%d, %d, %d, %d) に変更しました',
    ['notify.colorMission'] = 'ミッションルートの色を rgba(%d, %d, %d, %d) に変更しました',
    ['notify.usageRoute'] = '^3使い方:^7 /gps3d_route manual|blip|toggle|status',
    ['notify.usagePreset'] = '^3使い方:^7 /gpspreset 番号|next|prev|status',
    ['notify.usageColorDefault'] = '^3使い方:^7 /gpscolordefault r g b [a]^7 現在: rgba(%d, %d, %d, %d)',
    ['notify.usageColorMission'] = '^3使い方:^7 /gpscolormission r g b [a]^7 現在: rgba(%d, %d, %d, %d)',
    ['notify.beaconOn'] = '空中ビーコン: ^2ON^7',
    ['notify.beaconOff'] = '空中ビーコン: ^1OFF^7',
    ['notify.unknownError'] = '原因不明',
    ['notify.none'] = 'なし',
    ['notify.unknown'] = '不明',

    -- ワールド内テキスト (ASCII 固定)
    ['hud.modeUser'] = 'GPS MODE: USER',
    ['hud.modeMission'] = 'GPS MODE: MISSION',
    ['hud.modeOff'] = 'GPS MODE: OFF',
    ['hud.fxOn'] = 'GPS FX: ON',
    ['hud.fxOff'] = 'GPS FX: OFF',
    ['hud.color'] = 'GPS COLOR: %s',
    ['hud.preset'] = 'GPS PRESET: %s',
    ['hud.cooldown'] = 'GPS COOLDOWN: %ds',

    -- ビーコン
    ['beacon.label'] = 'WAYPOINT',
    ['beacon.unitMeter'] = 'M',
    ['beacon.unitKm'] = 'KM',

    -- リボンプリセット名 (実テクスチャを展開して確認した見た目に基づく)
    ['preset.chevronFlat'] = 'シェブロン / フラット',
    ['preset.chevronOutline'] = 'シェブロン / 縁取り',
    ['preset.chevronGloss'] = 'シェブロン / 光沢',
    ['preset.chevronBevel'] = 'シェブロン / 立体',
    ['preset.chevronNeon'] = 'シェブロン / ネオン',
    ['preset.hatch'] = '斜めハッチ',
    ['preset.chevronLarge'] = 'シェブロン / 大',
    ['preset.solid'] = 'ソリッド帯',
    ['preset.solidDouble'] = 'ソリッド帯 / 二重ライン',
    ['preset.centerStripe'] = 'センターライン',
    ['preset.barLadder'] = '横バー',
    ['preset.plain'] = 'プレーン',
    ['preset.blueDash'] = 'ブルーダッシュ',

    -- コンソール
    ['console.nativeMissing'] = 'このランタイムではルートサンプリング用ネイティブが利用できません。',

    --[[
     /gpsedit 設定パネル (NUI なので日本語で問題ない)
     項目キーは config/editor.lua のスキーマ id と対応する。
    ]]
    ['editor.title'] = 'GPS 設定',
    ['editor.subtitle'] = '3D ルートとビーコンの見た目を調整',
    ['editor.close'] = '閉じる',
    ['editor.reset'] = 'リセット',
    ['editor.resetAll'] = 'すべて既定に戻す',
    ['editor.resetAllConfirm'] = 'もう一度押すと初期化',
    ['editor.notReady'] = '設定パネルの読み込みが完了していません。数秒後にもう一度お試しください。',
    ['editor.saved'] = '保存しました',
    ['editor.notify.reset'] = '設定を既定に戻しました',

    ['editor.section.display'] = '表示',
    ['editor.section.ribbon'] = '路面リボン',
    ['editor.section.beacon'] = '目的地ビーコン',

    ['editor.field.route.enabled'] = '路面に 3D ルートを表示',
    ['editor.field.beacon.enabled'] = '目的地ビーコンを表示',
    ['editor.field.route.extraAnimations'] = 'AR 起動演出 (車体のライン)',
    ['editor.field.route.source'] = 'ルートソース',
    ['editor.field.route.preset'] = 'プリセット',
    ['editor.field.route.color'] = 'リボンの色',
    ['editor.field.route.distanceScale'] = '描画距離の倍率',
    ['editor.field.ribbon.width'] = 'リボンの幅',
    ['editor.field.ribbon.lift'] = '路面からの浮き',
    ['editor.field.ribbon.repeatDistance'] = '模様の間隔',
    ['editor.field.ribbon.dashEnabled'] = '破線にする',
    ['editor.field.ribbon.dashLength'] = '破線の長さ',
    ['editor.field.ribbon.dashGap'] = '破線の間隔',
    ['editor.field.ribbon.nearFadeEnabled'] = '手前をフェードする',
    ['editor.field.ribbon.nearFadeDistance'] = 'フェード距離',

    ['editor.field.beacon.color'] = 'ビーコンの色',
    ['editor.field.beacon.beamBottomHeight'] = 'ビーム下端の高さ',
    ['editor.field.beacon.beamTopHeight'] = 'ビーム上端の高さ',
    ['editor.field.beacon.beamWidth'] = 'ビームの太さ',
    ['editor.field.beacon.markerScale'] = '▼ の大きさ',
    ['editor.field.beacon.labelScale'] = 'ラベルの文字サイズ',
    ['editor.field.beacon.distanceScale'] = '距離の文字サイズ',
    ['editor.field.beacon.distanceMode'] = '距離の計算方法',
    ['editor.field.beacon.hideCloserThan'] = 'この距離より近いと非表示',
    ['editor.field.beacon.labelEnabled'] = 'ラベルを表示',
    ['editor.field.beacon.separatorEnabled'] = '区切り線を表示',

    ['editor.option.manual'] = 'ユーザー',
    ['editor.option.blip'] = 'ミッション',
    ['editor.option.direct'] = '直線距離',
    ['editor.option.route'] = 'ルート残距離',

    ['editor.tab.route.defaultColor'] = 'ユーザー',
    ['editor.tab.route.missionColor'] = 'ミッション',
    ['editor.tab.beacon.beamColor'] = 'ビーム',
    ['editor.tab.beacon.markerFillColor'] = '▼',
    ['editor.tab.beacon.labelColor'] = 'ラベル',
    ['editor.tab.beacon.separatorColor'] = '区切り線',
    ['editor.tab.beacon.distanceColor'] = '距離',
}
