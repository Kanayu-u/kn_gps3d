--[[
===============================================================================
 kn_gps3d / client/beacon.lua
-----------------------------------------------------------------------------
 目的地の空中ウェイポイント・ビーコン。

 構成 (上から下):
   距離        '110' + 小さい 'M'     画面座標
   区切り線    細い横線                画面座標 (または カメラ直交の 3D 線)
   ラベル      'WAYPOINT'             画面座標
   ▼ マーカー  DrawRect の横棒積み    画面座標
   垂直ビーム  DrawRect の縦積み      画面座標 (両端はワールド点を投影)

 位置の基準はワールド座標 (目的地の真上) だが、描画はすべて画面座標で行う。
 これで距離が変わっても文字サイズと間隔が一定に保たれ、かつ ▼ とビームが
 同じ投影を共有するので互いにずれない (beamSpace = 'world' で旧来の
 DrawLine によるワールド描画に戻せる)。

 画面内維持 (keepOnScreen):
   - 縦のはみ出し  : ビーム自体を短くしてスタックを画面内へ収める
   - 横/背後       : カメラ空間で方向を求めて画面端にクランプし、
                     ビームを省いた簡易表示 + 方向を指す矢印にする

 client.lua が公開する KnGps3dInternal 経由で目的地とルート状態を取得する。
===============================================================================
]]

local Config = KnGps3dConfig
local WL = KnGps3dWorldL

local beaconState = {
    enabled = true,
    groundKey = nil,
    groundZ = nil,
    groundAt = 0,
    occluded = false,
    occlusionHandle = nil,
    lastOcclusionStart = 0,
    -- 画面内フィッティングで求めたビーム上端高さ (平滑化用に前フレーム値を保持)
    fittedHeight = nil,
}

-------------------------------------------------------------------------------
-- ヘルパ
-------------------------------------------------------------------------------

--[[
 /gpsedit による手動上書き。

 Config.beacon を基底に、ここに入っているキーだけを重ねた実効テーブルを返す。
 毎フレーム作り直さないよう結果をキャッシュし、上書きが変わったときだけ捨てる。
 Config 自体は書き換えないので「既定に戻す」は override を空にするだけで済む。
]]
local beaconOverride = {}
local beaconMerged = nil

local function invalidateBeaconCache()
    beaconMerged = nil
end

local function cfg()
    local base = Config and Config.beacon
    if type(base) ~= 'table' then
        return nil
    end

    if beaconMerged ~= nil then
        return beaconMerged
    end

    if next(beaconOverride) == nil then
        beaconMerged = base
        return base
    end

    local merged = {}
    for key, value in pairs(base) do
        merged[key] = value
    end
    for key, value in pairs(beaconOverride) do
        merged[key] = value
    end

    beaconMerged = merged
    return merged
end

local function bridge()
    local internal = KnGps3dInternal
    if type(internal) ~= 'table' then
        return nil
    end

    return internal
end

local function clampChannel(value, fallback)
    local numeric = tonumber(value)
    if numeric == nil then
        return fallback or 255
    end

    return math.floor(math.max(0, math.min(255, numeric)))
end

local function color(source, fallback)
    local base = source or fallback or { r = 255, g = 255, b = 255, a = 255 }
    return clampChannel(base.r, 255), clampChannel(base.g, 255), clampChannel(base.b, 255), clampChannel(base.a, 255)
end

-- 距離フェード・パルス用。scale が 1.0 のときは元のテーブルをそのまま返して
-- 毎フレームの無駄なテーブル生成を避ける。
local function scaleAlpha(source, scale)
    if source == nil or scale == nil or scale >= 0.999 then
        return source
    end

    local r, g, b, a = color(source)
    local factor = math.max(0.0, math.min(1.0, scale))

    return { r = r, g = g, b = b, a = math.floor((a * factor) + 0.5) }
end

local function aspectRatio()
    if type(GetAspectRatio) == 'function' then
        local ratio = GetAspectRatio(false)
        if ratio and ratio > 0.1 then
            return ratio
        end
    end

    return 16.0 / 9.0
end

-------------------------------------------------------------------------------
-- パレット
--
-- 既定色は beacon 直下のキー。ルートソースや距離に応じて
-- beacon.palettes.mission / beacon.palettes.near で部分的に上書きできる。
-- 優先順位: near > mission > 既定
-------------------------------------------------------------------------------

local function resolvePalette(beacon, routeSource, flatDistance)
    local palettes = beacon.palettes
    if type(palettes) ~= 'table' then
        return nil
    end

    if beacon.nearHighlightEnabled ~= false and type(palettes.near) == 'table' then
        local nearDistance = tonumber(beacon.nearDistance) or 0.0
        if nearDistance > 0.0 and flatDistance and flatDistance <= nearDistance then
            return palettes.near
        end
    end

    if routeSource == 'blip' and type(palettes.mission) == 'table' then
        return palettes.mission
    end

    return nil
end

--[[
 /gpsedit で明示的に指定された値はパレットより優先する。
 そうしないと近距離パレット (シアン) の適用中に色を編集しても何も変わらず、
 エディタとして破綻するため。
]]
local function pick(beacon, palette, key)
    if beaconOverride[key] ~= nil then
        return beaconOverride[key]
    end

    if palette and palette[key] ~= nil then
        return palette[key]
    end

    return beacon[key]
end

-------------------------------------------------------------------------------
-- カメラ
-------------------------------------------------------------------------------

local function rotationToDirection(rot)
    local radX = math.rad(rot.x)
    local radZ = math.rad(rot.z)
    local cosX = math.abs(math.cos(radX))

    return vector3(-math.sin(radZ) * cosX, math.cos(radZ) * cosX, math.sin(radX))
end

-- カメラ視線に直交する水平方向 (ビームの太さ・3D 区切り線に使う)
local function cameraRightVector()
    if type(GetFinalRenderedCamRot) ~= 'function' then
        return vector3(1.0, 0.0, 0.0)
    end

    local forward = rotationToDirection(GetFinalRenderedCamRot(2))
    local length = math.sqrt((forward.x * forward.x) + (forward.y * forward.y))
    if length < 0.0001 then
        return vector3(1.0, 0.0, 0.0)
    end

    return vector3(-forward.y / length, forward.x / length, 0.0)
end

--[[
 カメラ基底 (位置 / 前 / 右 / 上)。ロールは無視する (ゲームプレイカメラでは十分)。
 画面外・背後の方向計算に使う。
]]
local function cameraBasis()
    if type(GetFinalRenderedCamCoord) ~= 'function' or type(GetFinalRenderedCamRot) ~= 'function' then
        return nil
    end

    local camPos = GetFinalRenderedCamCoord()
    local forward = rotationToDirection(GetFinalRenderedCamRot(2))

    -- right = normalize(cross(forward, worldUp))
    local rx, ry = forward.y, -forward.x
    local length = math.sqrt((rx * rx) + (ry * ry))
    local right
    if length > 0.0001 then
        right = vector3(rx / length, ry / length, 0.0)
    else
        right = vector3(1.0, 0.0, 0.0)
    end

    -- up = cross(right, forward)
    local up = vector3(
        (right.y * forward.z) - (right.z * forward.y),
        (right.z * forward.x) - (right.x * forward.z),
        (right.x * forward.y) - (right.y * forward.x)
    )

    return camPos, forward, right, up
end

local function cameraFov()
    if type(GetFinalRenderedCamFov) == 'function' then
        local fov = GetFinalRenderedCamFov()
        if fov and fov > 1.0 and fov < 179.0 then
            return fov
        end
    end

    return 50.0
end

--[[
 スクリーン投影。

 ビーコンの画面座標は必ずこの関数を通す。▼・テキスト・ビームが同じ変換を
 共有していれば、投影に多少の誤差があっても互いにずれない。

 projectionAspectFix: GetScreenCoordFromWorldCoord の X が 16:9 基準で
 返っているという仮説への補正 (config 参照)。16:9 では恒等変換になる。
]]
local function projectScreen(beacon, x, y, z)
    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(x, y, z)
    if sx == nil or sy == nil then
        return false, nil, nil
    end

    if beacon and beacon.projectionAspectFix == true then
        local ratio = aspectRatio()
        if ratio > 0.1 and math.abs(ratio - (16.0 / 9.0)) > 0.01 then
            sx = 0.5 + ((sx - 0.5) * ((16.0 / 9.0) / ratio))
        end
    end

    return onScreen, sx, sy
end

local function isInFrontOfCamera(pos)
    local camPos, forward = cameraBasis()
    if not camPos then
        return true
    end

    local delta = pos - camPos
    return ((delta.x * forward.x) + (delta.y * forward.y) + (delta.z * forward.z)) > 0.01
end

--[[
 画面外・背後の目的地を画面端に寄せた座標を求める。

 画面内に収まっている間は必ず GetScreenCoordFromWorldCoord (エンジンの投影) を
 使う。自前の FOV 計算で位置を出すと、エンジンがワールド座標で描くビームと
 数ピクセルずれて ▼ がビームの真上に乗らなくなるため。
 ここでのカメラ空間計算は、ネイティブの結果が信用できない画面外・背後に限る。
]]
local function resolveEdgePos(beacon, pos, ratio)
    local marginX = tonumber(beacon.clampMarginX) or 0.06
    local marginY = tonumber(beacon.clampMarginY) or 0.08

    local camPos, forward, right, up = cameraBasis()
    if not camPos then
        return 0.5, marginY
    end

    local delta = pos - camPos
    local dz = (delta.x * forward.x) + (delta.y * forward.y) + (delta.z * forward.z)
    local dx = (delta.x * right.x) + (delta.y * right.y) + (delta.z * right.z)
    local dy = (delta.x * up.x) + (delta.y * up.y) + (delta.z * up.z)

    local sx, sy

    if dz > 0.01 then
        local tanV = math.tan(math.rad(cameraFov() * 0.5))
        local tanH = tanV * ratio
        sx = 0.5 + (((dx / dz) / tanH) * 0.5)
        sy = 0.5 - (((dy / dz) / tanV) * 0.5)
    else
        -- 背後。方向だけを使って画面外の遠方へ飛ばし、その後クランプする。
        local magnitude = math.sqrt((dx * dx) + (dy * dy))
        if magnitude < 0.0001 then
            sx, sy = 10.0, 0.5
        else
            sx = 0.5 + ((dx / magnitude) * 10.0)
            sy = 0.5 - ((dy / magnitude) * 10.0)
        end
    end

    return math.max(marginX, math.min(1.0 - marginX, sx)),
        math.max(marginY, math.min(1.0 - marginY, sy))
end

-------------------------------------------------------------------------------
-- 目的地の地面 Z
--
-- ウェイポイント blip の座標は Z が 0 で返ることが多いため、地面を解決する。
--   1) GetGroundZFor_3dCoord   : コリジョンが読み込まれている範囲で正確
--   2) ハイトマップ            : 遠距離のフォールバック
--   3) 元の Z                  : 最後の砦
-------------------------------------------------------------------------------

local function probeGroundZ(pos)
    if type(GetGroundZFor_3dCoord) == 'function' then
        local ok, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, 1000.0, false)
        if ok and groundZ and groundZ == groundZ then
            return groundZ
        end
    end

    if type(GetHeightmapBottomZForPosition) == 'function' then
        local value = GetHeightmapBottomZForPosition(pos.x, pos.y)
        if value and value == value and value > -200.0 then
            return value
        end
    end

    if type(GetHeightmapTopZForPosition) == 'function' then
        local value = GetHeightmapTopZForPosition(pos.x, pos.y)
        if value and value == value and value > -200.0 then
            return value
        end
    end

    return pos.z
end

local function resolveGroundZ(beacon, dest)
    local key = ('%d:%d'):format(math.floor(dest.x + 0.5), math.floor(dest.y + 0.5))
    local now = GetGameTimer()
    local refreshMs = tonumber(beacon.groundProbeRefreshMs) or 1500

    if beaconState.groundKey == key and beaconState.groundZ ~= nil and (now - beaconState.groundAt) < refreshMs then
        return beaconState.groundZ
    end

    local groundZ = probeGroundZ(dest)
    beaconState.groundKey = key
    beaconState.groundZ = groundZ
    beaconState.groundAt = now

    return groundZ
end

-------------------------------------------------------------------------------
-- 遮蔽判定 (非同期レイキャスト。既定は無効)
-------------------------------------------------------------------------------

local function updateOcclusion(beacon, targetPos)
    if beacon.occlusionCheckEnabled ~= true then
        beaconState.occluded = false
        return
    end

    if type(StartShapeTestRay) ~= 'function' or type(GetShapeTestResult) ~= 'function' then
        beaconState.occluded = false
        return
    end

    if beaconState.occlusionHandle then
        local status, hit = GetShapeTestResult(beaconState.occlusionHandle)
        if status ~= 1 then
            beaconState.occluded = hit == 1 or hit == true
            beaconState.occlusionHandle = nil
        end
        return
    end

    local now = GetGameTimer()
    local intervalMs = tonumber(beacon.occlusionCheckIntervalMs) or 250
    if (now - beaconState.lastOcclusionStart) < intervalMs then
        return
    end

    if type(GetFinalRenderedCamCoord) ~= 'function' then
        return
    end

    beaconState.lastOcclusionStart = now
    local camPos = GetFinalRenderedCamCoord()
    -- flag 1 = マップジオメトリのみ (車両・歩行者では遮られない)
    beaconState.occlusionHandle = StartShapeTestRay(
        camPos.x, camPos.y, camPos.z,
        targetPos.x, targetPos.y, targetPos.z,
        1, 0, 4
    )
end

-------------------------------------------------------------------------------
-- 描画: ビーム (ワールド 3D)
-------------------------------------------------------------------------------

local function drawBeam(beacon, palette, dest, groundZ, topHeightOverride, alphaScale, bottomHeightOverride)
    if beacon.beamEnabled == false then
        return
    end

    local bottomHeight = tonumber(bottomHeightOverride) or tonumber(beacon.beamBottomHeight) or 8.0
    local topHeight = tonumber(topHeightOverride) or tonumber(beacon.beamTopHeight) or 25.0
    if topHeight <= (bottomHeight + 0.3) then
        return
    end

    local r, g, b, a = color(scaleAlpha(pick(beacon, palette, 'beamColor'), alphaScale))
    -- 描画数に直結するので上限を入れる (config の打ち間違いでフレームが落ちる)
    local segments = math.max(1, math.min(128, math.floor(tonumber(beacon.beamSegments) or 14)))
    local fadeRatio = math.max(0.0, math.min(1.0, tonumber(beacon.beamFadeRatio) or 0.45))
    local lineCount = math.max(1, math.min(16, math.floor(tonumber(beacon.beamLineCount) or 1)))
    local lineSpacing = tonumber(beacon.beamLineSpacing) or 0.06

    local right = cameraRightVector()
    local span = topHeight - bottomHeight
    local step = span / segments

    for lineIndex = 1, lineCount do
        local offsetScale = (lineIndex - ((lineCount + 1) * 0.5)) * lineSpacing
        local ox = right.x * offsetScale
        local oy = right.y * offsetScale

        for i = 0, segments - 1 do
            -- t = 0 が下端、1 が上端
            local t0 = i / segments
            local t1 = (i + 1) / segments
            local alphaFactor = 1.0
            if fadeRatio > 0.0 then
                local mid = (t0 + t1) * 0.5
                if mid < fadeRatio then
                    alphaFactor = mid / fadeRatio
                end
            end

            local segmentAlpha = math.floor((a * alphaFactor) + 0.5)
            if segmentAlpha > 0 then
                local z0 = groundZ + bottomHeight + (step * i)
                local z1 = groundZ + bottomHeight + (step * (i + 1))
                DrawLine(
                    dest.x + ox, dest.y + oy, z0,
                    dest.x + ox, dest.y + oy, z1,
                    r, g, b, segmentAlpha
                )
            end
        end
    end
end

--[[
 ビーム (画面座標)。

 上端は ▼ が乗っている点 (topX, topY) をそのまま使い、下端だけを投影する。
 こうすると投影ネイティブに誤差があっても ▼ とビームは必ず一直線に並ぶ。

 DrawRect は軸平行の矩形しか描けないため、傾いたビームは細かい矩形の階段に
 なる。矩形の幅を「1 段あたりの横移動量 + 太さ」に広げて隙間を埋める。
]]
local function drawBeamScreen(beacon, palette, dest, groundZ, bottomHeight, alphaScale, topX, topY)
    if beacon.beamEnabled == false then
        return
    end

    local r, g, b, a = color(scaleAlpha(pick(beacon, palette, 'beamColor'), alphaScale))
    if a <= 0 then
        return
    end

    local bottomPos = vector3(dest.x, dest.y, groundZ + bottomHeight)
    if not isInFrontOfCamera(bottomPos) then
        return
    end

    local _, bx, by = projectScreen(beacon, bottomPos.x, bottomPos.y, bottomPos.z)
    if bx == nil or by == nil then
        return
    end

    -- 真上から見下ろしている等で下端が上端より上に来る場合は描かない
    local length = by - topY
    if length <= 0.002 then
        return
    end

    local width = math.max(0.0004, tonumber(beacon.beamWidth) or 0.0016)
    local fadeRatio = math.max(0.0, math.min(1.0, tonumber(beacon.beamFadeRatio) or 0.45))

    -- 画面上の長さに応じて分割数を決める (短いビームで無駄に描かない)
    local segments = math.max(6, math.min(96, math.ceil(length / 0.006)))
    local stepY = length / segments
    local stepX = (bx - topX) / segments
    local rectWidth = math.abs(stepX) + width
    -- 継ぎ目に隙間が出ないよう少し重ねる
    local rectHeight = stepY * 1.2

    for i = 0, segments - 1 do
        -- t = 0 が下端、1 が上端 (world 版と意味をそろえる)
        local t = 1.0 - ((i + 0.5) / segments)
        local alphaFactor = 1.0
        if fadeRatio > 0.0 and t < fadeRatio then
            alphaFactor = t / fadeRatio
        end

        local segmentAlpha = math.floor((a * alphaFactor) + 0.5)
        if segmentAlpha > 0 then
            DrawRect(
                topX + (stepX * (i + 0.5)),
                topY + (stepY * (i + 0.5)),
                rectWidth, rectHeight,
                r, g, b, segmentAlpha
            )
        end
    end
end

-------------------------------------------------------------------------------
-- 描画: 三角マーカー (画面座標。DrawRect の細帯を積んで三角形にする)
--
-- direction: 'down' | 'up' | 'left' | 'right'
-- (cx, cy) は三角形の中心。
-------------------------------------------------------------------------------

local function drawTriangleMarker(cx, cy, width, height, direction, bars, fill, outline, outlineThickness, ratio)
    local barCount = math.max(3, math.min(128, math.floor(bars or 26)))
    local vertical = direction ~= 'left' and direction ~= 'right'

    local fr, fg, fb, fa = color(fill)

    local orr, og, ob, oa = 255, 255, 255, 255
    local thickness = 0.003
    if outline then
        orr, og, ob, oa = color(outline)
        thickness = math.max(0.0008, tonumber(outlineThickness) or 0.003)
    end

    if vertical then
        -- 横帯を縦に積む。'down' は上辺が広く下が尖る。
        local barHeight = height / barCount
        local drawHeight = barHeight * 1.6
        local topY = cy - (height * 0.5)

        for i = 0, barCount - 1 do
            local t = (i + 0.5) / barCount
            if direction == 'up' then
                t = 1.0 - t
            end

            local barWidth = width * (1.0 - t)
            local y = topY + (barHeight * (i + 0.5))

            if barWidth > 0.0002 and fa > 0 then
                DrawRect(cx, y, barWidth, drawHeight, fr, fg, fb, fa)
            end

            if outline then
                local half = barWidth * 0.5
                DrawRect(cx - half, y, thickness, drawHeight, orr, og, ob, oa)
                DrawRect(cx + half, y, thickness, drawHeight, orr, og, ob, oa)
            end
        end

        if outline then
            -- 底辺 (広い側)。X の太さと見た目を揃えるためアスペクト比を掛ける。
            local baseY = direction == 'up' and (cy + (height * 0.5)) or (cy - (height * 0.5))
            DrawRect(cx, baseY, width, thickness * ratio, orr, og, ob, oa)
        end
    else
        -- 縦帯を横に積む。'left' は右辺が広く左が尖る。
        local barWidth = width / barCount
        local drawWidth = barWidth * 1.6
        local leftX = cx - (width * 0.5)

        for i = 0, barCount - 1 do
            local t = (i + 0.5) / barCount
            if direction == 'right' then
                t = 1.0 - t
            end

            local barHeight = height * t
            local x = leftX + (barWidth * (i + 0.5))

            if barHeight > 0.0002 and fa > 0 then
                DrawRect(x, cy, drawWidth, barHeight, fr, fg, fb, fa)
            end

            if outline then
                local half = barHeight * 0.5
                DrawRect(x, cy - half, drawWidth, thickness * ratio, orr, og, ob, oa)
                DrawRect(x, cy + half, drawWidth, thickness * ratio, orr, og, ob, oa)
            end
        end

        if outline then
            local baseX = direction == 'right' and (cx - (width * 0.5)) or (cx + (width * 0.5))
            DrawRect(baseX, cy, thickness, height, orr, og, ob, oa)
        end
    end
end

-------------------------------------------------------------------------------
-- 描画: テキスト (画面座標)
-------------------------------------------------------------------------------

local function textHeight(scale, font)
    if type(GetRenderedCharacterHeight) == 'function' then
        local height = GetRenderedCharacterHeight(scale, font or 4)
        if height and height > 0.0 then
            return height
        end
    end

    return scale * 0.035
end

local function textWidth(text, scale, font)
    if type(BeginTextCommandGetWidth) == 'function' and type(EndTextCommandGetWidth) == 'function' then
        SetTextScale(scale, scale)
        SetTextFont(font or 4)
        BeginTextCommandGetWidth('STRING')
        AddTextComponentSubstringPlayerName(text)
        local width = EndTextCommandGetWidth(true)
        if width and width > 0.0 then
            return width
        end
    end

    -- ネイティブが無い場合の概算
    return #text * scale * 0.0145
end

local function drawText(text, x, y, scale, font, tint, centred)
    local r, g, b, a = color(tint)
    SetTextScale(scale, scale)
    SetTextFont(font or 4)
    SetTextProportional(true)
    SetTextColour(r, g, b, a)
    SetTextOutline()
    SetTextCentre(centred ~= false)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

-------------------------------------------------------------------------------
-- 距離文字列
-------------------------------------------------------------------------------

local function formatDistance(beacon, meters)
    local kmThreshold = tonumber(beacon.distanceKmThreshold) or 1000.0

    if beacon.distanceKmEnabled ~= false and meters >= kmThreshold then
        local decimals = math.max(0, math.floor(tonumber(beacon.distanceKmDecimals) or 1))
        return ('%.' .. decimals .. 'f'):format(meters / 1000.0), WL('beacon.unitKm')
    end

    return ('%d'):format(math.floor(meters + 0.5)), WL('beacon.unitMeter')
end

local function getDistanceMeters(beacon, flatDistance)
    if beacon.distanceMode == 'route' then
        local api = bridge()
        local routeLength = api and api.getRouteLength and api.getRouteLength() or 0.0
        if routeLength and routeLength > 0.0 then
            return routeLength
        end
    end

    return flatDistance
end

-------------------------------------------------------------------------------
-- レイアウト
-------------------------------------------------------------------------------

--[[
 ビーム上端より上に積む要素の合計高さ (画面比) を先に測る。
 高さは文字の内容に依存しない (scale と font だけで決まる) ため、
 描画前に確定できる。
]]
local function measureStackHeight(beacon, ratio)
    local total = 0.0

    if beacon.markerEnabled ~= false then
        total = total + (tonumber(beacon.markerGapY) or 0.002) + (tonumber(beacon.markerHeight) or 0.021)
    end

    if beacon.labelEnabled ~= false then
        local scale = tonumber(beacon.labelScale) or 0.50
        total = total + (tonumber(beacon.labelGapY) or 0.018) + textHeight(scale, math.floor(tonumber(beacon.labelFont) or 4))
    end

    if beacon.separatorEnabled ~= false and beacon.separatorMode ~= 'world' then
        total = total + (tonumber(beacon.separatorGapY) or 0.006)
            + ((tonumber(beacon.separatorThickness) or 0.0016) * ratio)
    end

    if beacon.distanceEnabled ~= false then
        local scale = tonumber(beacon.distanceScale) or 0.85
        total = total + (tonumber(beacon.distanceGapY) or 0.022) + textHeight(scale, math.floor(tonumber(beacon.distanceFont) or 4))
    end

    return total
end

--[[
 目標の画面 Y になるビーム上端の高さを二分探索で求める。

 固定 XY に対して画面 Y は高さの単調減少関数 (高いほど上 = Y が小さい) なので
 二分探索が成立する。GetScreenCoordFromWorldCoord は 8 回程度なら十分に軽い。
]]
local function findHeightForScreenY(beacon, dest, groundZ, minHeight, maxHeight, targetY)
    local low = minHeight
    local high = maxHeight

    -- 12 回で (25-2)/4096 ≈ 6mm 精度。輪郭線のちらつきを避けるため 8 回から増やした。
    for _ = 1, 12 do
        local mid = (low + high) * 0.5
        local ok, _, sy = projectScreen(beacon, dest.x, dest.y, groundZ + mid)

        if not ok or sy < targetY then
            -- 上に行き過ぎている → もっと低く
            high = mid
        else
            low = mid
        end
    end

    return (low + high) * 0.5
end

-------------------------------------------------------------------------------
-- 描画: 距離テキスト ('110' + 小さい 'M')
-------------------------------------------------------------------------------

local function drawDistanceText(beacon, palette, sx, bottomY, meters, alphaScale)
    local scale = tonumber(beacon.distanceScale) or 0.85
    local suffixScale = tonumber(beacon.distanceSuffixScale) or 0.45
    local font = math.floor(tonumber(beacon.distanceFont) or 4)
    local gapX = tonumber(beacon.distanceSuffixGapX) or 0.002

    local valueText, unitText = formatDistance(beacon, meters)

    local valueHeight = textHeight(scale, font)
    local suffixHeight = textHeight(suffixScale, font)
    local valueY = bottomY - valueHeight
    -- 数値と単位の下端を揃える
    local suffixY = valueY + (valueHeight - suffixHeight)

    local valueWidth = textWidth(valueText, scale, font)
    local suffixWidth = textWidth(unitText, suffixScale, font)
    local totalWidth = valueWidth + gapX + suffixWidth

    local valueX = sx - (totalWidth * 0.5) + (valueWidth * 0.5)
    local suffixX = sx + (totalWidth * 0.5) - (suffixWidth * 0.5)

    local tint = scaleAlpha(pick(beacon, palette, 'distanceColor'), alphaScale)
    drawText(valueText, valueX, valueY, scale, font, tint, true)
    drawText(unitText, suffixX, suffixY, suffixScale, font, tint, true)

    return valueY
end

-------------------------------------------------------------------------------
-- 描画: 画面端に寄せた簡易表示 (目的地が画面外・背後のとき)
-------------------------------------------------------------------------------

local function drawClampedBeacon(beacon, palette, sx, sy, meters, alphaScale, ratio, markerAlpha)
    local marginX = tonumber(beacon.clampMarginX) or 0.06
    local marginY = tonumber(beacon.clampMarginY) or 0.08
    local edgeEpsilon = 0.0015

    -- どの端に寄っているかで矢印の向きを決める
    local direction = 'down'
    if sx <= (marginX + edgeEpsilon) then
        direction = 'left'
    elseif sx >= (1.0 - marginX - edgeEpsilon) then
        direction = 'right'
    elseif sy <= (marginY + edgeEpsilon) then
        direction = 'up'
    end

    local markerWidth = tonumber(beacon.markerWidth) or 0.020
    local markerHeight = tonumber(beacon.markerHeight) or 0.021

    drawTriangleMarker(
        sx,
        sy,
        markerWidth,
        markerHeight,
        direction,
        beacon.markerBars,
        scaleAlpha(pick(beacon, palette, 'markerFillColor'), markerAlpha),
        beacon.markerOutlineEnabled ~= false
            and scaleAlpha(pick(beacon, palette, 'markerOutlineColor'), markerAlpha) or nil,
        beacon.markerOutlineThickness,
        ratio
    )

    if beacon.distanceEnabled == false or beacon.clampedShowDistance == false then
        return
    end

    -- 矢印の下に距離を出す。上端に寄っているときだけは下向きに逃がす。
    local scale = tonumber(beacon.distanceScale) or 0.85
    local font = math.floor(tonumber(beacon.distanceFont) or 4)
    local height = textHeight(scale, font)
    local gap = tonumber(beacon.clampedDistanceGapY) or 0.006
    local bottomY

    if direction == 'up' then
        bottomY = sy + (markerHeight * 0.5) + gap + height
    else
        bottomY = sy - (markerHeight * 0.5) - gap
    end

    drawDistanceText(beacon, palette, sx, bottomY, meters, alphaScale)
end

-------------------------------------------------------------------------------
-- 描画: ビーコン全体
-------------------------------------------------------------------------------

local function drawBeacon(beacon, palette, dest, groundZ, flatDistance, alphaScale)
    local ratio = aspectRatio()
    local bottomHeight = tonumber(beacon.beamBottomHeight) or 8.0
    local topHeight = tonumber(beacon.beamTopHeight) or 25.0
    local meters = getDistanceMeters(beacon, flatDistance)

    -- パルス (マーカーとビームにだけ掛ける。文字は読みやすさ優先で掛けない)
    local markerAlpha = alphaScale
    if beacon.pulseEnabled == true then
        local periodMs = math.max(120.0, tonumber(beacon.pulsePeriodMs) or 1600.0)
        local amount = math.max(0.0, math.min(1.0, tonumber(beacon.pulseAmount) or 0.18))
        local phase = (GetGameTimer() % periodMs) / periodMs
        local wave = (math.sin(phase * math.pi * 2.0) + 1.0) * 0.5
        markerAlpha = alphaScale * (1.0 - (amount * (1.0 - wave)))
    end

    local anchor = vector3(dest.x, dest.y, groundZ + topHeight)
    local inFront = isInFrontOfCamera(anchor)

    --[[
     画面内フィッティング。

     ビーム上端を固定ワールド高さにすると、目的地に近づくほど仰角が大きくなり、
     上に積んだテキストが画面上端を突き抜けて読めなくなる。
     スタックの合計高さを測り、はみ出す場合はビーム自体を短くして
     スタック全体が画面内に収まる高さへ引き下げる。

     二分探索は「はみ出していなければ最大高さに収束する」ため、
     判定を挟まず常に走らせてよい (投影が信用できない画面上端付近でも安全)。
    ]]
    if beacon.fitToScreen ~= false and inFront then
        local margin = tonumber(beacon.fitMarginY) or 0.03
        local stackHeight = measureStackHeight(beacon, ratio)

        --[[
         探索の下限はビーム下端ではなく fitMinHeight まで下げる。
         下限をビーム下端(8m)にすると、目的地に近づいたとき 8m 上を見上げる形に
         なり、ビーコンが視線より上に外れて見えなくなる。
        ]]
        local minHeight = math.max(0.5, tonumber(beacon.fitMinHeight) or 2.0)
        local fitted = findHeightForScreenY(beacon, dest, groundZ, math.min(minHeight, topHeight), topHeight, margin + stackHeight)

        --[[
         平滑化。

         毎フレーム二分探索をやり直すと、カメラの微動で結果が数 cm 単位で揺れ、
         ▼ の細い輪郭線が 1〜2px 単位で振動して「ちらつき」として見える。
         前フレーム値へ指数移動平均で寄せて安定させる。
         目的地変更などで大きく飛んだ場合は平滑化せず即座に追従する。
        ]]
        local previous = beaconState.fittedHeight
        if previous and math.abs(previous - fitted) < 8.0 then
            local factor = math.max(0.02, math.min(1.0, tonumber(beacon.fitSmoothing) or 0.25))
            fitted = previous + ((fitted - previous) * factor)
        end
        beaconState.fittedHeight = fitted

        if fitted < (topHeight - 0.01) then
            topHeight = fitted
            anchor = vector3(dest.x, dest.y, groundZ + topHeight)
        end
    end

    -- ビーム上端が下端より低くなったら、下端も一緒に引き下げて破綻を防ぐ
    if topHeight <= (bottomHeight + 1.0) then
        bottomHeight = math.max(0.3, topHeight - 4.0)
    end

    -- 画面内ではエンジンの投影をそのまま使う (ビームとの位置ずれを避ける)
    local onScreen, sx, sy = projectScreen(beacon, anchor.x, anchor.y, anchor.z)

    --[[
     フィッティング後も画面に収まらない = 横方向に外れている、または背後。
     その場合ワールド座標のビームは画面に映らないので省略し、
     画面端に寄せた簡易表示に切り替える。
    ]]
    if not onScreen or not inFront then
        if beacon.keepOnScreen == false then
            return
        end

        local edgeX, edgeY = resolveEdgePos(beacon, anchor, ratio)
        drawClampedBeacon(beacon, palette, edgeX, edgeY, meters, alphaScale, ratio, markerAlpha)
        return
    end

    if beacon.beamSpace == 'world' then
        drawBeam(beacon, palette, dest, groundZ, topHeight, alphaScale, bottomHeight)
    else
        drawBeamScreen(beacon, palette, dest, groundZ, bottomHeight, alphaScale, sx, sy)
    end

    local cursorY = sy

    -- ▼ マーカー
    if beacon.markerEnabled ~= false then
        local markerWidth = tonumber(beacon.markerWidth) or 0.020
        local markerHeight = tonumber(beacon.markerHeight) or 0.021
        local gapY = tonumber(beacon.markerGapY) or 0.002
        local topY = cursorY - gapY - markerHeight

        local fillColor = pick(beacon, palette, 'markerFillColor')
        local outlineColor = beacon.markerOutlineEnabled ~= false
            and pick(beacon, palette, 'markerOutlineColor') or nil

        drawTriangleMarker(
            sx,
            topY + (markerHeight * 0.5),
            markerWidth,
            markerHeight,
            'down',
            beacon.markerBars,
            scaleAlpha(fillColor, markerAlpha),
            scaleAlpha(outlineColor, markerAlpha),
            beacon.markerOutlineThickness,
            ratio
        )

        -- 二重シェブロン (小さい ▼ を内側に重ねる)
        if beacon.markerDoubleEnabled == true then
            local innerScale = math.max(0.1, math.min(0.95, tonumber(beacon.markerDoubleScale) or 0.62))
            local innerAlpha = markerAlpha * math.max(0.0, math.min(1.0, tonumber(beacon.markerDoubleAlpha) or 0.8))
            local innerGap = tonumber(beacon.markerDoubleGapY) or 0.006

            drawTriangleMarker(
                sx,
                topY + (markerHeight * 0.5) - innerGap,
                markerWidth * innerScale,
                markerHeight * innerScale,
                'down',
                beacon.markerBars,
                scaleAlpha(fillColor, innerAlpha),
                scaleAlpha(outlineColor, innerAlpha),
                beacon.markerOutlineThickness,
                ratio
            )
        end

        cursorY = topY
    end

    -- ラベル ('WAYPOINT')
    if beacon.labelEnabled ~= false then
        local scale = tonumber(beacon.labelScale) or 0.50
        local font = math.floor(tonumber(beacon.labelFont) or 4)
        local gapY = tonumber(beacon.labelGapY) or 0.018
        local height = textHeight(scale, font)
        local drawY = cursorY - gapY - height

        drawText(WL('beacon.label'), sx, drawY, scale, font,
            scaleAlpha(pick(beacon, palette, 'labelColor'), alphaScale), true)
        cursorY = drawY
    end

    -- 区切り線
    if beacon.separatorEnabled ~= false then
        local gapY = tonumber(beacon.separatorGapY) or 0.006
        local separatorColor = pick(beacon, palette, 'separatorColor')

        if beacon.separatorMode == 'world' then
            -- カメラ直交の 3D 線。参照画像に見えるわずかな傾きを再現する。
            local r, g, b, a = color(scaleAlpha(separatorColor, alphaScale))
            local halfWidth = (tonumber(beacon.separatorWorldWidth) or 5.0) * 0.5
            local right = cameraRightVector()
            local lineZ = anchor.z + (tonumber(beacon.separatorWorldOffsetZ) or 4.0)
            DrawLine(
                anchor.x - (right.x * halfWidth), anchor.y - (right.y * halfWidth), lineZ,
                anchor.x + (right.x * halfWidth), anchor.y + (right.y * halfWidth), lineZ,
                r, g, b, a
            )
            cursorY = cursorY - gapY
        else
            local r, g, b, a = color(scaleAlpha(separatorColor, alphaScale))
            local width = tonumber(beacon.separatorWidth) or 0.078
            local thickness = (tonumber(beacon.separatorThickness) or 0.0016) * ratio
            local drawY = cursorY - gapY - (thickness * 0.5)
            DrawRect(sx, drawY, width, thickness, r, g, b, a)
            cursorY = drawY - (thickness * 0.5)
        end
    end

    -- 距離
    if beacon.distanceEnabled ~= false then
        local gapY = tonumber(beacon.distanceGapY) or 0.022
        drawDistanceText(beacon, palette, sx, cursorY - gapY, meters, alphaScale)
    end
end

-------------------------------------------------------------------------------
-- 表示条件
-------------------------------------------------------------------------------

local function shouldDraw(beacon)
    if beaconState.enabled ~= true or beacon.enabled == false then
        return false
    end

    local api = bridge()
    if not api then
        return false
    end

    if beacon.requireGpsEnabled ~= false and api.isEnabled and not api.isEnabled() then
        return false
    end

    local sources = beacon.sources
    if type(sources) == 'table' and api.getRouteSource then
        local source = api.getRouteSource()
        local key = source == 'blip' and 'blip' or 'manual'
        if sources[key] == false then
            return false
        end
    end

    if beacon.requireVehicle ~= false and api.getEligibleVehicle and api.getEligibleVehicle() == 0 then
        return false
    end

    return true
end

-------------------------------------------------------------------------------
-- メインループ
-------------------------------------------------------------------------------

CreateThread(function()
    while true do
        local waitTime = 300
        local beacon = cfg()

        if beacon and shouldDraw(beacon) then
            local api = bridge()
            local dest = api and api.getDestination and api.getDestination() or nil

            if dest then
                local ped = PlayerPedId()
                local playerPos = ped ~= 0 and GetEntityCoords(ped) or nil
                local groundZ = resolveGroundZ(beacon, dest)

                local flatDistance = 0.0
                if playerPos then
                    local dx = dest.x - playerPos.x
                    local dy = dest.y - playerPos.y
                    flatDistance = math.sqrt((dx * dx) + (dy * dy))
                end

                --[[
                 距離しきい値の前後で急に消えると目立つため、
                 fadeRange の区間でアルファを線形に落とす。
                ]]
                local alphaScale = 1.0
                if playerPos then
                    local fadeRange = math.max(0.0, tonumber(beacon.fadeRange) or 12.0)

                    local hideCloserThan = tonumber(beacon.hideCloserThan) or 0.0
                    if hideCloserThan > 0.0 then
                        if flatDistance <= hideCloserThan then
                            alphaScale = 0.0
                        elseif fadeRange > 0.0 and flatDistance < (hideCloserThan + fadeRange) then
                            alphaScale = math.min(alphaScale, (flatDistance - hideCloserThan) / fadeRange)
                        end
                    end

                    local maxDistance = tonumber(beacon.maxDrawDistance) or 0.0
                    if maxDistance > 0.0 then
                        if flatDistance >= maxDistance then
                            alphaScale = 0.0
                        elseif fadeRange > 0.0 and flatDistance > (maxDistance - fadeRange) then
                            alphaScale = math.min(alphaScale, (maxDistance - flatDistance) / fadeRange)
                        end
                    end
                end

                if alphaScale > 0.01 then
                    updateOcclusion(beacon, vector3(dest.x, dest.y, groundZ + 1.0))
                    if beaconState.occluded then
                        alphaScale = 0.0
                    end
                end

                if alphaScale > 0.01 then
                    waitTime = 0
                    local routeSource = api.getRouteSource and api.getRouteSource() or 'manual'
                    local palette = resolvePalette(beacon, routeSource, flatDistance)
                    drawBeacon(beacon, palette, dest, groundZ, flatDistance, alphaScale)
                end
            end
        end

        Wait(waitTime)
    end
end)

--[[
===============================================================================
 内部ブリッジ (client/editor.lua 用)
-----------------------------------------------------------------------------
 client.lua の KnGps3dInternal と同じ方針。ファイル間で local を共有できないため
 /gpsedit が必要とする窓口だけをグローバルに出す。外部リソースは exports を使う。
===============================================================================
]]

KnGps3dBeaconInternal = {
    isEnabled = function()
        return beaconState.enabled == true
    end,

    setEnabled = function(enabled)
        beaconState.enabled = enabled == true
        return beaconState.enabled
    end,

    -- 実効値 (上書き → Config の順)
    getValue = function(key)
        local beacon = cfg()
        return beacon and beacon[key]
    end,

    -- value == nil で上書きを解除して Config の値へ戻す
    setOverride = function(key, value)
        if type(key) ~= 'string' then
            return false
        end

        beaconOverride[key] = value
        invalidateBeaconCache()
        -- 高さが変わるとフィッティングの平滑化が古い値へ引っ張るため捨てる
        beaconState.fittedHeight = nil

        return true
    end,

    clearOverrides = function()
        beaconOverride = {}
        invalidateBeaconCache()
        beaconState.fittedHeight = nil
    end,
}

-------------------------------------------------------------------------------
-- コマンド / エクスポート
-------------------------------------------------------------------------------

RegisterCommand('gps3dbeacon', function()
    beaconState.enabled = not beaconState.enabled
    TriggerEvent('chat:addMessage', {
        color = { 255, 255, 255 },
        multiline = false,
        args = {
            KnGps3dL('chat.prefix'),
            beaconState.enabled and KnGps3dL('notify.beaconOn') or KnGps3dL('notify.beaconOff'),
        },
    })
end, false)

CreateThread(function()
    Wait(1000)
    TriggerEvent('chat:addSuggestion', '/gps3dbeacon', KnGps3dL('suggest.beacon'))
end)

exports('SetBeaconEnabled', function(enabled)
    beaconState.enabled = enabled == true
    return beaconState.enabled
end)

exports('IsBeaconEnabled', function()
    return beaconState.enabled == true
end)
