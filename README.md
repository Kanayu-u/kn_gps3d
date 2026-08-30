# kn_gps3d

3D GPS リボン + 空中ウェイポイント・ビーコン。

[l2k_gps3d](https://github.com/Lafa2K/l2k_gps3d) v1.2.0 (Lafa2K + Codex, MIT) の
**フォーク**。MIT License のまま公開している。

ルートソースは 2 系統:

- `USER` = プレイヤーのウェイポイント
- `MISSION` = 他スクリプトが `SetBlipRoute` した blip

`multi` は既定で無効のまま無視される。
ジオアニメ (AR 起動演出) モジュールはこのリソースに同梱済みで、`l2k_geoanim` は不要。

---

## ファイル構成

```
kn_gps3d/
├─ config/config.lua        全設定 (これだけ編集すればよい)
├─ config/editor.lua        /gpsedit パネルの項目定義
├─ locales/locale.lua       翻訳ランタイム
├─ locales/ja.lua           日本語
├─ locales/en.lua           英語 (フォールバック)
├─ client.lua               ルート算出・リボン描画・コマンド・exports
├─ client/beacon.lua        空中ウェイポイント・ビーコン
├─ client/editor.lua        /gpsedit の適用処理・KVP 保存
├─ web/                     /gpsedit パネル (NUI。外部依存なし)
├─ gpsgeoanim.config.lua    AR 起動演出のキーフレーム
├─ gpsgeoanim.client.lua    AR 演出の描画エンジン
├─ stream/chevrons.ytd      リボン用テクスチャ 12 種
└─ data/, audiodirectory/   カスタム音声 (signal-power-up)
```

---

## 空中ウェイポイント・ビーコン

目的地の上空に、上から順に以下を表示する。

| 要素 | 描画方式 |
|---|---|
| 距離 (`110` + 小さい `M`) | 画面座標 / `DrawText` 2 パーツ |
| 区切り線 (ライムグリーン) | 画面座標 `DrawRect` (または カメラ直交の 3D 線) |
| ラベル (`WAYPOINT`) | 画面座標 / `DrawText` |
| ▼ マーカー | 画面座標 / `DrawRect` の横棒積み + 斜辺トレース |
| 垂直ビーム | 画面座標 / `DrawRect` の縦積み (両端はワールド点を投影・下端フェード) |

位置の基準はワールド座標 (目的地の真上) だが、描画はすべて画面座標で行う。
距離が変わっても文字サイズと間隔が一定に保たれ、かつ ▼ とビームが同じ投影を
共有するので互いにずれない。

> v2.2.0 まではビームだけを `DrawLine` でワールド描画していたが、
> `GetScreenCoordFromWorldCoord` の投影と一致しない環境があり
> (実測: 1920x1200 / 16:10 で約 24px)、ビームが ▼ の真下に来なかった。
> `beacon.beamSpace = 'world'` で旧描画 (建物に隠れる) に戻せる。

ビームは既定で地面に接さず空中で終わる (地面から約 8m〜25m)。
地面まで伸ばしたい場合は `beacon.beamBottomHeight = 0.0`。

主な設定 (`config/config.lua` の `beacon`):

| キー | 内容 |
|---|---|
| `beamBottomHeight` / `beamTopHeight` | ビームの下端・上端の高さ (m) |
| `beamLineCount` / `beamLineSpacing` | `DrawLine` は 1px 固定なので本数で太さを出す |
| `markerWidth` / `markerHeight` | ▼ の画面比サイズ |
| `labelScale` / `distanceScale` | 文字サイズ (**実機で要微調整**) |
| `distanceMode` | `'direct'` 直線距離 / `'route'` ルート残距離 |
| `requireVehicle` | 車両搭乗中のみ表示 |
| `hideCloserThan` | 近距離で非表示にする閾値 (m) |
| `keepOnScreen` | 画面外・背後でも画面端に寄せて表示し続ける |
| `fitToScreen` | 画面上端からはみ出す場合にビームを短くして収める |
| `occlusionCheckEnabled` | 建物裏で全体を隠す (レイキャスト、既定オフ) |
| `separatorMode` | `'screen'` 水平線 / `'world'` 3D 線 (参照画像のわずかな傾きを再現) |
| `palettes.mission` / `.near` | MISSION 追従時・目的地接近時の色 |
| `markerDoubleEnabled` / `pulseEnabled` | 二重シェブロン / 脈動 (どちらも既定オフ) |

### 画面内維持のふるまい

| 状況 | 表示 |
|---|---|
| 目的地が画面内 | ビーム + ▼ + ラベル + 区切り線 + 距離 (フル表示) |
| 上にはみ出す | ビームを短くしてスタック全体を画面内へ収める |
| 横・背後にある | 画面端にクランプし、端に応じて向きを変えた矢印 + 距離 (ビームは省略) |

### 色の切り替え

`palettes` は宣言したキーだけを上書きする。優先順位は **near > mission > 既定**。

- `palettes.mission` — MISSION ルート追従時 (既定: 金色)
- `palettes.near` — `nearDistance` (60m) 以内に接近時 (既定: 緑)

---

## コマンド

- `/gpsedit` — **設定パネルを開く** (下記)
- `/gps3d` — 3D GPS の ON/OFF
- `/gps3dbeacon` — 空中ビーコンの ON/OFF
- `/gps3d_route manual|blip|toggle|status` — ルートソース切替 / 状態表示
- `/gpspreset index|next|prev|status` — リボンプリセット
- `/gpscolordefault r g b [a]` — `USER` ルートの色
- `/gpscolormission r g b [a]` — `MISSION` ルートの色
- `/geoanim [on|shutdown|off|status]` — AR 演出の手動制御

## 設定パネル `/gpsedit`

ゲーム内でリボンとビーコンの見た目をライブ調整する NUI パネル。
外部ライブラリには依存しない。

| セクション | 調整できるもの |
|---|---|
| 表示 | 路面リボン ON/OFF、ビーコン ON/OFF、AR 起動演出 ON/OFF、ルートソース (USER / MISSION) |
| 路面リボン | プリセット (サムネイル付き一覧・使用中の項目を強調)、色 (HSV + 不透明度、USER / MISSION 別)、幅、浮き、模様の間隔、破線 ON/OFF・長さ・間隔、手前フェード、描画距離倍率 |
| 目的地ビーコン | 色 (ビーム / ▼ / ラベル / 区切り線 / 距離)、ビーム上下端・太さ、▼ の大きさ、文字サイズ、距離の計算方法 (直線 / ルート残)、非表示距離、ラベル・区切り線の表示 |

- 変更は即座に反映される。項目名の右の `↺` で **その項目だけ** 既定へ戻せる。
- 右下の「すべて既定に戻す」は誤爆防止のため 2 度押し。
- 変更が止まってから 0.8 秒後にクライアント KVP へ自動保存し、次回接続時に復元する。
- `ESC` または `×` で閉じる。
- ポーズメニュー > キー設定 からキーを割り当てられる (既定は未割り当て)。

### 設定の重なり順

```
Config.texturedRoute  →  preset.ribbon  →  /gpsedit の上書き
Config.beacon         →  palettes.*     →  /gpsedit の上書き
```

`Config` 自体は書き換えないので、リセットは上書きを外すだけで済む。
プリセットを切り替えても `/gpsedit` の調整は残る。
ビーコンの色だけは `/gpsedit` の指定がパレット (mission / near) より優先される
(そうしないと近距離パレット適用中に色を編集しても何も変わらないため)。

### 項目を増やす

`config/editor.lua` のスキーマに 1 行足せば、パネルの UI も適用処理も自動で付く。
表示名は `locales/*.lua` の `editor.field.<id>` に書く。
適用先は id の接頭辞 (`route.` / `ribbon.` / `beacon.`) で決まる。

> **NUI から来る値は信用しない設計**。スキーマの `min` / `max` / `options` が
> そのまま検証に使われる。ループ回数や描画数に効く値を追加するときは
> 必ず現実的な上限を入れること (NaN や極端な値でクライアントが固まるため)。

---

## ショートカット

すべて許可された車両に乗っている必要がある。config で個別に無効化可能。

- `SHIFT + UP` — `USER` / `MISSION` 切替
- `SHIFT + Y` — 現在のルートソースの色を循環
- `SHIFT + LEFT / RIGHT` — リボンプリセットを循環
- `SHIFT + DOWN` — 3D GPS の ON/OFF (再有効化にクールダウンあり)
- `SHIFT + U` — AR 演出の ON/OFF。初回イントロ演出のフラグもリセットされる
  (`/gpsedit` の「AR 起動演出」トグルと同じ状態を切り替える)

キーは `config/config.lua` の `routeColorKey` / `routeAnimationToggleKey` 等で変更する。

---

## プリセット

プリセットは基本的にリボンの見た目 (テクスチャ) だけを変え、
`USER` / `MISSION` に設定した色は書き換えない。

例外として、プリセットが `defaultColor` / `missionColor` / `ribbon` を
明示的に持つ場合はそれらも適用される。

| # | 名前 | テクスチャ |
|---|---|---|
| 0 | シェブロン / フラット | `chevrons` |
| 1 | シェブロン / 縁取り | `chevron_line_06` |
| 2 | シェブロン / 光沢 | `chevron_fire_01` |
| 3 | シェブロン / 立体 | `chevron_ice_01` |
| 4 | シェブロン / ネオン | `chevron_neon_01` |
| 5 | 斜めハッチ | `chevron_line_05` |
| 6 | シェブロン / 大 | `chevron_line_07` |
| 7 | ソリッド帯 | `chevron_line_01` |
| 8 | ソリッド帯 / 二重ライン | `chevron_line_02` |
| 9 | センターライン | `chevron_line_08` |
| 10 | 横バー | `chevron_line_04` |
| 11 | プレーン | `chevron_line_03` |
| 12 | **ブルーダッシュ** | `chevron_line_03` + 色 / 破線設定 |

`[0]`〜`[11]` は色を書き換えない。`[12]` のみ `defaultColor` / `missionColor` /
`ribbon` を持つため色と破線設定も適用される。

名前は `nameKey` でロケール管理下にある (`locales/*.lua` の `preset.*`)。
`nameKey` を持たないプリセット (独自に追加したもの) は `name` がそのまま使われる。
名前は `stream/chevrons.ytd` を復号して 12 枚のテクスチャを実際に確認して付けた。
同じ画像を 40px に縮小したものが `web/thumb/` にあり、`/gpsedit` の一覧に出る。

### 破線モード

```lua
texturedRoute = {
    dashEnabled = true,
    dashLength = 2.6,   -- 破線 1 本の長さ (m)
    dashGap = 1.9,      -- 間隔 (m)
}
```

破線 1 つがテクスチャ 1 枚分に収まるよう UV を張るため、
サンプル点の境界で分断されても模様が崩れない。

> `Blue Dash` の角丸形状は `chevrons.ytd` に一致するテクスチャが無いため近似
> (`chevron_line_03`)。完全一致させるには CodeWalker で YTD にテクスチャを
> 1 枚追加して `textureName` を差し替える。

### 模様の位相

`worldStablePhase = true` (既定) の場合、各点が持つルート距離と原点の前進量から
位相を補正し、模様をワールドに固定する。
`false` にすると従来動作 (ルート再構築ごとに模様がプレイヤー基準でずれる) に戻る。

---

## 表示言語

`config/config.lua` の `locale = 'ja' | 'en'`。

チャット通知は NUI 経由なので日本語で問題ない。
一方 **ワールド内の 3D テキスト (`DrawText`) はゲーム側フォントに日本語グリフが
無いと文字化けする**ため、`worldTextAscii = true` (既定) では非 ASCII を検出して
英語へフォールバックする。日本語表示を試す場合は `false` にしてから
`locales/ja.lua` の `hud.*` / `beacon.*` を書き換える。

---

## 外部 blip のルート捕捉

他スクリプトが以下を行っている場合:

```lua
local blip = AddBlipForCoord(x, y, z)
SetBlipRoute(blip, true)
```

`Config.enableExternalBlipRouteCapture = true` で自動的に捕捉して 3D 表示する。

## ルートに対する非干渉性

このリソースは既に存在するルートを読むだけで、外部のルートを所有しない。

- 外部の routed blip をクリアしない
- 他スクリプトの GPS ロジックを再構築しない
- どのルートを 3D 表示するか決めるだけ

そのため他リソースは `SetBlipRoute` / ウェイポイント生成 / ミッション進行 /
配達フロー / レースチェックポイントをそのまま扱い続けられる。

---

## Exports

```lua
exports.kn_gps3d:SetEnabled(true)
exports.kn_gps3d:SetActiveRouteSource('manual')   -- 'manual' | 'blip'
exports.kn_gps3d:SetTrackedBlip(blip)
exports.kn_gps3d:ClearTrackedBlip()
exports.kn_gps3d:SetRoutePreset(12)
exports.kn_gps3d:SetDefaultRouteColor(255, 255, 255, 205)
exports.kn_gps3d:SetMissionRouteColor(255, 214, 64, 215)

-- 空中ビーコン
exports.kn_gps3d:SetBeaconEnabled(true)
exports.kn_gps3d:IsBeaconEnabled()

-- 同梱 GeoAnim
exports.kn_gps3d:PlayProfile('on', vehicle)       -- 'on' | 'on_fast' | 'off'
exports.kn_gps3d:StopExtraAnimations()
```

---

## 注意点

- ボートと飛行機のクラスは既定で無視される (`ignoredVehicleClasses`)
- リボンは速度連動のサンプリングと距離制限で高速走行時の負荷を抑えている
- 初回の大きな AR イントロは 1 度だけ再生され、以降は短縮版 (`on_fast`) になる。
  `SHIFT + K` でリセットされる
- ビーム (`DrawLine`) は建物に隠れるが `DrawText` は貫通するため、
  目的地が建物裏にあるとき文字だけ浮く可能性がある → `occlusionCheckEnabled`

---

## Credit / ライセンス

原作: **[l2k_gps3d](https://github.com/Lafa2K/l2k_gps3d)** by Lafa2K + Codex (MIT License)。
本リソースはその**フォーク**であり、原作と同じ MIT License で配布する。
`LICENSE` には原作の著作権表示を保持したまま、改変分の著作権表示を追記している。

### 上流からそのまま引き継いでいるファイル

以下は原作のバイナリ素材を**一切変更せずに**同梱している (git blob SHA 一致を確認済み)。
いずれも原作の MIT License の下で再配布している。

| ファイル | 用途 |
|---|---|
| `stream/chevrons.ytd` | リボン用テクスチャ 12 種 |
| `audiodirectory/custom_sounds.awc` | `signal-power-up` 音声 |
| `data/signal-power-up_sounds.dat54.rel` | 上記のサウンドデータ定義 |
| `gpsgeoanim.config.lua` | AR 起動演出のキーフレーム |

### このフォークで追加・改変した主なもの

- `client/beacon.lua` — 空中ウェイポイント・ビーコン (新規)
- `client/editor.lua` + `web/` — `/gpsedit` 設定パネル (新規・NUI / 外部依存なし)
- `config/` — 設定の分離
- `locales/` — 多言語化 (日本語 / 英語)
- `client.lua` — ルート算出・リボン描画の改修
- `gpsgeoanim.client.lua` — 演出エンジンの改修

変更履歴は `CHANGELOG.md` を参照 (v2.0.0 がフォーク時点)。
