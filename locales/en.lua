KnGps3dLocales = KnGps3dLocales or {}

KnGps3dLocales['en'] = {
    -- Chat prefix
    ['chat.prefix'] = 'kn_gps3d',

    -- Route source names
    ['route.user'] = 'USER',
    ['route.mission'] = 'MISSION',

    -- Chat notifications
    ['notify.routeActive'] = 'Active route: ^3%s^7',
    ['notify.routeUserFailed'] = '^1USER route failed:^7 %s',
    ['notify.routeMissionFailed'] = '^1MISSION route failed:^7 %s',
    ['notify.status'] = 'Source: ^3%s^7 | Preset: ^5%d - %s^7 | Points: %d | Slot: %s | Available: [%s]',
    ['notify.presetSelected'] = 'Preset ^3%d^7 selected: %s',
    ['notify.presetStatus'] = 'Preset: ^3%d^7 - %s',
    ['notify.presetInvalid'] = '^1Invalid preset index.^7',
    ['notify.colorDefault'] = 'USER color changed to rgba(%d, %d, %d, %d)',
    ['notify.colorMission'] = 'MISSION color changed to rgba(%d, %d, %d, %d)',
    ['notify.usageRoute'] = '^3Usage:^7 /gps3d_route manual|blip|toggle|status',
    ['notify.usagePreset'] = '^3Usage:^7 /gpspreset index|next|prev|status',
    ['notify.usageColorDefault'] = '^3Usage:^7 /gpscolordefault r g b [a]^7. Current: rgba(%d, %d, %d, %d)',
    ['notify.usageColorMission'] = '^3Usage:^7 /gpscolormission r g b [a]^7. Current: rgba(%d, %d, %d, %d)',
    ['notify.beaconOn'] = 'Waypoint beacon: ^2ON^7',
    ['notify.beaconOff'] = 'Waypoint beacon: ^1OFF^7',
    ['notify.unknownError'] = 'unknown error',
    ['notify.none'] = 'none',
    ['notify.unknown'] = 'unknown',

    -- Chat command suggestions (shown when typing /)
    ['suggest.gps3d'] = 'Toggle the 3D GPS display',
    ['suggest.route'] = 'Switch the route source',
    ['suggest.routeArg'] = 'manual | blip | toggle | status',
    ['suggest.preset'] = 'Change the ribbon appearance preset',
    ['suggest.presetArg'] = 'index | next | prev | status',
    ['suggest.colorDefault'] = 'Change the user route colour',
    ['suggest.colorMission'] = 'Change the mission route colour',
    ['suggest.colorArg'] = '0-255',
    ['suggest.colorArgAlpha'] = '0-255 (optional)',
    ['suggest.beacon'] = 'Toggle the floating waypoint beacon',
    ['suggest.edit'] = 'Open the GPS settings panel',
    ['suggest.geoanim'] = 'Play the AR startup animation',
    ['suggest.geoanimArg'] = 'on | off | shutdown | toggle',

    -- World text (drawn with DrawText: ASCII only)
    ['hud.modeUser'] = 'GPS MODE: USER',
    ['hud.modeMission'] = 'GPS MODE: MISSION',
    ['hud.modeOff'] = 'GPS MODE: OFF',
    ['hud.fxOn'] = 'GPS FX: ON',
    ['hud.fxOff'] = 'GPS FX: OFF',
    ['hud.color'] = 'GPS COLOR: %s',
    ['hud.preset'] = 'GPS PRESET: %s',
    ['hud.cooldown'] = 'GPS COOLDOWN: %ds',

    -- Beacon
    ['beacon.label'] = 'WAYPOINT',
    ['beacon.unitMeter'] = 'M',
    ['beacon.unitKm'] = 'KM',

    -- Ribbon preset names (based on the actual textures decoded from chevrons.ytd)
    ['preset.chevronFlat'] = 'Chevron / Flat',
    ['preset.chevronOutline'] = 'Chevron / Outlined',
    ['preset.chevronGloss'] = 'Chevron / Gloss',
    ['preset.chevronBevel'] = 'Chevron / Beveled',
    ['preset.chevronNeon'] = 'Chevron / Neon',
    ['preset.hatch'] = 'Diagonal Hatch',
    ['preset.chevronLarge'] = 'Chevron / Large',
    ['preset.solid'] = 'Solid Band',
    ['preset.solidDouble'] = 'Solid Band / Double Rail',
    ['preset.centerStripe'] = 'Center Stripe',
    ['preset.barLadder'] = 'Bar Ladder',
    ['preset.plain'] = 'Plain',
    ['preset.blueDash'] = 'Blue Dash',

    -- Console
    ['console.nativeMissing'] = 'route sampling native not available in this runtime.',

    -- /gpsedit settings panel (NUI: non-ASCII is fine here)
    ['editor.title'] = 'GPS Settings',
    ['editor.subtitle'] = 'Customize the 3D route and beacon',
    ['editor.close'] = 'Close',
    ['editor.reset'] = 'Reset',
    ['editor.resetAll'] = 'Reset everything',
    ['editor.resetAllConfirm'] = 'Press again to reset',
    ['editor.notReady'] = 'Settings panel is still loading. Try again in a moment.',
    ['editor.saved'] = 'Saved',
    ['editor.notify.reset'] = 'Settings restored to defaults',

    ['editor.section.display'] = 'Display',
    ['editor.section.ribbon'] = 'Road ribbon',
    ['editor.section.beacon'] = 'Destination beacon',

    ['editor.field.route.enabled'] = 'Show GPS on the road',
    ['editor.field.beacon.enabled'] = 'Show 3D destination',
    ['editor.field.route.extraAnimations'] = 'AR boot animation (vehicle outline)',
    ['editor.field.route.source'] = 'Route source',
    ['editor.field.route.preset'] = 'Preset',
    ['editor.field.route.color'] = 'Ribbon color',
    ['editor.field.route.distanceScale'] = 'Draw distance scale',
    ['editor.field.ribbon.width'] = 'Ribbon width',
    ['editor.field.ribbon.lift'] = 'Height above road',
    ['editor.field.ribbon.repeatDistance'] = 'Pattern spacing',
    ['editor.field.ribbon.dashEnabled'] = 'Dashed',
    ['editor.field.ribbon.dashLength'] = 'Dash length',
    ['editor.field.ribbon.dashGap'] = 'Dash gap',
    ['editor.field.ribbon.nearFadeEnabled'] = 'Fade when near',
    ['editor.field.ribbon.nearFadeDistance'] = 'Fade distance',

    ['editor.field.beacon.color'] = 'Beacon color',
    ['editor.field.beacon.beamBottomHeight'] = 'Beam bottom height',
    ['editor.field.beacon.beamTopHeight'] = 'Beam top height',
    ['editor.field.beacon.beamWidth'] = 'Beam width',
    ['editor.field.beacon.markerScale'] = 'Chevron scale',
    ['editor.field.beacon.labelScale'] = 'Label text size',
    ['editor.field.beacon.distanceScale'] = 'Distance text size',
    ['editor.field.beacon.distanceMode'] = 'Distance mode',
    ['editor.field.beacon.hideCloserThan'] = 'Hide closer than',
    ['editor.field.beacon.labelEnabled'] = 'Show label',
    ['editor.field.beacon.separatorEnabled'] = 'Show separator',

    ['editor.option.manual'] = 'USER',
    ['editor.option.blip'] = 'MISSION',
    ['editor.option.direct'] = 'Straight line',
    ['editor.option.route'] = 'Along route',

    ['editor.tab.route.defaultColor'] = 'USER',
    ['editor.tab.route.missionColor'] = 'MISSION',
    ['editor.tab.beacon.beamColor'] = 'Beam',
    ['editor.tab.beacon.markerFillColor'] = 'Chevron',
    ['editor.tab.beacon.labelColor'] = 'Label',
    ['editor.tab.beacon.separatorColor'] = 'Separator',
    ['editor.tab.beacon.distanceColor'] = 'Distance',
}
