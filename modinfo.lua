name = "Chest Includer"
description = "This mod allows you to craft objects using items from nearby chests.\n\nThanks to Syl for some multiplayer functionality!!\n https://github.com/rawii22/ChestInclusionForCrafting" --something with Syl
author = "rawii22 & lord_of_les_ralph"
version = "1.1.0"
icon = "modicon.tex"
icon_atlas = "modicon.xml"

forumthread = ""

api_version = 10

priority = -1
dst_compatible = true
all_clients_require_mod = true
client_only_mod = false


configuration_options = {
    {
        name = "RADIUS",
        label = "Chest Range",
		hover = "This is the range within which you must reside to use the items of nearby chests.",
        options = {
            { description = "10", data = 10 },
            { description = "20", data = 20 },
            { description = "40", data = 40 },
            { description = "100", data = 100 },
        },
        default = 20
    },
	{
		name = "CHESTERON",
		label = "Chester Inclusion",
		hover = "\"On\" will include chester. \"Off\" will exclude chester.",
		options = {
			{ description = "Off", data = false},
			{ description = "On", data = true},
		},
		default = true
	},
}