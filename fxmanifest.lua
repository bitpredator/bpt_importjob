fx_version 'adamant'

game 'gta5'

description 'ESX Import Job'
author 'bitpredator'
version '1.0.0'

shared_script '@es_extended/imports.lua'

client_scripts {
	'@es_extended/locale.lua',
	'locales/*.lua',
	'config.lua',
	'client/main.lua'
}

server_scripts {
	'@es_extended/locale.lua',
	'locales/*.lua',
	'config.lua',
	'server/main.lua'
}

dependency {
	'es_extended',
	'bpt_crafting',
	'bpt_teleport',
}

-- the following map must also be installed " https://www.gta5-mods.com/maps/secret-warehouse-base-sp-fivem "