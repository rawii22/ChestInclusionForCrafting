name = "Chest Includer"
description = "" --something with Syl
author = "rawii22 & lord_of_les_ralph"
version = "1.0"

forumthread = ""

api_version = 10

priority = - 1
dst_compatible = true
all_clients_require_mod = true
client_only_mod = false


configuration_options = {
    {
        name = "RADIUS",
        label = "Chest Range",
		hover = "This is the range within which you must reside to use the items of nearby chests",
        options = {
            { description = "10", data = 10 },
            { description = "20", data = 20 },
            { description = "40", data = 40 },
            { description = "100", data = 100 },
            { description = "Infinite", data = -1 },
        },
        default = 20
    },
}