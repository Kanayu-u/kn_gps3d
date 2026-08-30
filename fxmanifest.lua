fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'Kanayu_u'
description '3D GPS ribbon renderer with floating waypoint beacon (based on l2k_gps3d by Lafa2K + Codex).'
version '2.5.3'

shared_scripts {
    'config/config.lua',
    'config/editor.lua',
    'locales/locale.lua',
    'locales/en.lua',
    'locales/ja.lua',
    'gpsgeoanim.config.lua'
}

-- 読み込み順に依存あり: client.lua → beacon.lua → editor.lua
-- (後段が前段の公開するグローバルブリッジを参照するため)
client_scripts {
    'gpsgeoanim.client.lua',
    'client.lua',
    'client/beacon.lua',
    'client/editor.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    -- chevrons.ytd から復号したプリセットのサムネイル
    'web/thumb/*.png',
    'data/signal-power-up_sounds.dat54.rel',
    'audiodirectory/custom_sounds.awc'
}

data_file 'AUDIO_WAVEPACK'  'audiodirectory'
data_file 'AUDIO_SOUNDDATA' 'data/signal-power-up_sounds.dat'
