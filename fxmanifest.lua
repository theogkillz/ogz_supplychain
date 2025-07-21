fx_version 'cerulean'
game 'gta5'

author 'VirgilDev - Rewritten by The OG KiLLz'
description 'OGz_SupplyChainMaster - The Ultimate Supply Chain/Business Script'
version '1.0.1'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    '@lation_ui/init.lua',
    'shared/config_main.lua',
    'shared/config_locations.lua',
    'shared/config_items.lua',
}

client_scripts {
    'client/cl_main.lua',
    'client/cl_restaurant.lua',
    'client/cl_warehouse.lua',
    'client/cl_seller.lua',
    'client/cl_stock.lua'
}

server_scripts {
    'server/sv_main.lua',
    'server/sv_restaurant.lua',
    'server/sv_warehouse.lua',
    'server/sv_team.lua',
    'server/sv_leaderboard.lua',
    'server/sv_farming.lua',
    '@oxmysql/lib/MySQL.lua'
}

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'oxmysql',
    'lation_ui'
}