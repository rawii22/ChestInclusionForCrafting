local json = GLOBAL.json
local pcall = GLOBAL.pcall

local RADIUS = GetModConfigData("RADIUS")
local CHESTERON = GetModConfigData("CHESTERON")

function GetOverflowContainers(player)
	--[[if GLOBAL.TheNet:GetIsClient() then --apparently this check is not needed because clients have access to TheSim and their own Transform component.
        return {}
    end]]
	local x,y,z = player.Transform:GetWorldPosition()
	local chests = GLOBAL.TheSim:FindEntities(x,y,z, RADIUS, nil, {"quantum", "burnt"}, {"chest", "cellar", "fridge", CHESTERON and "chester" or ""})
	return #chests > 0 and chests or nil
end

function getNumItems(list) --the value of the table must be a number
	local amount = 0
	if list == nil then
		return amount
	end
		
	for k,v in pairs(list) do
		amount = amount + v
	end
	return amount
end


-------------------------------------------------Begin for host
local function HasOverride(component)
	local OldHas = component.Has
	component.Has = function(self, item, amount, runoriginal)
		-- Search in inventory, active item, & backpack
		HasItem, ItemCount = OldHas(self, item, amount)
		-- Search in nearby containers
		local num_left_to_find = amount - ItemCount
		local overflows = GetOverflowContainers(self.inst)
		if overflows ~= nil then
			for k,chest in pairs(overflows) do
				local chestHas, chestAmount = chest.components.container:Has(item, num_left_to_find)
				ItemCount = ItemCount + chestAmount
			end
			HasItem = ItemCount >= amount
		end
		return HasItem, ItemCount
	end
end
AddComponentPostInit("inventory", HasOverride)

local function GetItemByNameOverride(component)
	local OldGetItemByName = component.GetItemByName
	component.GetItemByName = function(self, item, amount)
		-- Search in inventory, active item, & backpack
		local items = OldGetItemByName(self, item, amount)
		-- Search in nearby containers
		local itemsCount = getNumItems(items)
		local amount_left = amount - itemsCount
		if amount_left > 0 then
			local chests = GetOverflowContainers(self.inst)
			if chests ~= nil then
				for i,chest in pairs(chests) do
					local chestItems = chest.components.container:GetItemByName(item, amount_left)
					if getNumItems(chestItems) > 0 then
						for k,v in pairs(chestItems) do
							items[k] = v
							amount_left = amount_left - getNumItems(chestItems)
							if amount_left <= 0 then
								break
							end
						end
					end
				end
			end
		end
		return items
	end
end
AddComponentPostInit("inventory", GetItemByNameOverride)

local function RemoveItemRemote(component)
	local OldRemoveItem = component.RemoveItem
	component.RemoveItem = function(self, item, wholestack)
		-- Remove from inventory, active item, or backpack
		local oldItem = OldRemoveItem(self, item, wholestack) --since this function was meant to always work, we pickup here if OldItem returns nil
		-- Remove from nearby containers
		if oldItem == nil then
			local chests = GetOverflowContainers(self.inst)
			for k,chest in pairs(chests) do
				local remoteOldItem = chest.components.container:RemoveItem(item, wholestack)
				chest:PushEvent("itemlose")
				if remoteOldItem ~= nil then
					return remoteOldItem
				end
			end
		else
			return oldItem
		end
	end
end
AddComponentPostInit("inventory", RemoveItemRemote)
-------------------------------------------------End for host


-------------------------------------------------Begin for client
local function HasClient(prefab)
	local OldHas = prefab.Has
	prefab.Has = function(inst, item, amount, runoriginal)
		-- Search in inventory, active item, & backpack
		HasItem, ItemCount = OldHas(inst, item, amount)
		-- Search in nearby containers, available on client via variable on player, '_itemTable'
		local num_left_to_find = amount - ItemCount
		for name,count in pairs(inst._parent.player_classified._itemTable) do
			if name == item then
				ItemCount = ItemCount + count
				break
			end
		end
		HasItem = ItemCount >= amount
		return HasItem, ItemCount
	end
end
AddPrefabPostInit("inventory_classified", HasClient)

local function RemoveIngredientsClient(prefab)
	local OldRemoveIngredients = prefab.RemoveIngredients
	prefab.RemoveIngredients = function(inst, recipe, ingredientmod)
		if inst:IsBusy() then
			return false
		end
		local chests = GetOverflowContainers(inst._parent) or {}
		for k,chest in pairs(chests) do
			local chestClassified = chest.replica.container.classified
			if chestClassified ~= nil and chestClassified:IsBusy() then
				return false
			end
		end
		
		local allItems = {}
		for k,v in ipairs(recipe.ingredients) do
			local _, total = inst:Has(v.type, v.amount)
			allItems[v.type] = total
		end
		-- Remove recipe ingredients from inventory, active item, or backpack
		OldRemoveIngredients(inst, recipe, ingredientmod)
		-- Remove recipe ingredients from nearby containers
		local newAllItems = {}
		for k,v in ipairs(recipe.ingredients) do
			local _, total = inst:Has(v.type, v.amount)
			newAllItems[v.type] = total
		end
		for k,v in ipairs(recipe.ingredients) do
			local amountRemoved = allItems[v.type] - newAllItems[v.type]
			local amountLeft = v.amount - amountRemoved
			for k,chest in pairs(chests) do
				local chestHas, chestAmount = chest.replica.container:Has(v.type, amountLeft)
				if chest.replica.container.classified ~= nil  then
					if chestHas then
						chest.replica.container.classified:ConsumeByName(v.type, amountLeft)
					else
						chest.replica.container.classified:ConsumeByName(v.type, chestAmount)
						amountLeft = amountLeft - chestAmount
					end
					chest:PushEvent("itemlose")
				end
			end
		end
		return true
	end
end
AddPrefabPostInit("inventory_classified", RemoveIngredientsClient)

-- Get all prefabs stored in 'chests' and the amount for each
local function findAllFromChest(chests)
    if not chests or #chests == 0 then
        return {}
    end
    local items = {}
    for k, v in pairs(chests) do
        if v.components.container then
            local prefabs = {}
            for _, i in pairs(v.components.container.slots) do prefabs[i.prefab] = true end
            for t, _ in pairs(prefabs) do
                local found, amount = v.components.container:Has(t, 1)
                items[t] = (items[t] or 0) + amount
            end
        end
    end
    return items
end

-- Publish available items in nearby containers to net variable on player, '_items'
local function allItemUpdate(inst)
    local chests = GetOverflowContainers(inst._parent)
    local items = findAllFromChest(chests)
    local r, result = pcall(json.encode, items)
    if not r then print("Could not encode all items: "..tostring(items)) end
    if result then
        inst._items:set(result)
    end
end

-- When '_items' changes, store available items in '_itemTable'
local function itemsDirty(inst)
    --print("itemsDirty: "..inst._items:value())
    local r, result = pcall(json.decode, inst._items:value())
    if not r then print("Could not decode JSON: "..inst._items:value()) end
    if result then
        inst._itemTable = result
    end
    if GLOBAL.TheNet:GetIsClient() then
        inst._parent:PushEvent("refreshcrafting") --stacksizechange
    end
end

AddPrefabPostInit("player_classified", function(inst)
	inst._itemTable = {}
	inst._items = GLOBAL.net_string(inst.GUID, "_items", "itemsDirty")
	inst._items:set("")
	inst:ListenForEvent("itemsDirty", itemsDirty)
	inst.allItemUpdate = allItemUpdate
	if GLOBAL.TheWorld.ismastersim then
		inst.smashtask = inst:DoPeriodicTask(15 * GLOBAL.FRAMES, allItemUpdate)
	end
end)
-------------------------------------------------End for client

-- These functions override the FindItems functionality defined in Gem Core API making Gem Core compatible with this mod.
-- Host
local function FindItemsOverride(component)
	local OldFindItems = component.FindItems
	component.FindItems = function(self, fn)
		-- Search in inventory, active item, & backpack
		local items = OldFindItems(self, fn)
		-- Search in nearby containers
		local overflows = GetOverflowContainers(self.inst) or {}
		for k, overflow in pairs(overflows) do
			for _, item in pairs(overflow.components.container:FindItems(fn)) do
				table.insert(items, item)
			end
		end
		return items
	end
end
AddComponentPostInit("inventory", FindItemsOverride) --'FindItems' exists in the main game so we do not need to check if GemCore is enabled

-- Client
local function FindItemsClient(prefab)
	local OldFindItems = prefab.FindItems
	prefab.FindItems = function(inst, fn)
		-- Search in inventory, active item, & backpack
		local items = OldFindItems(inst, fn)
		-- Search in nearby containers
		local overflows = GetOverflowContainers(inst._parent) or {}
		for k, overflow in pairs(overflows) do
			for _, item in pairs(overflow.replica.container:FindItems(fn)) do
				table.insert(items, item)
			end
		end
		return items
	end
end

if GLOBAL.KnownModIndex:IsModEnabled("workshop-1378549454") then --This is the name of the Gem Core API Mod
	AddPrefabPostInit("inventory_classified", FindItemsClient)
end
------------------------------------------End of Gem Core Compatibility Section


AddPrefabPostInitAny(function(inst)
	if inst and (inst:HasTag("chest") or inst:HasTag("cellar") or inst:HasTag("fridge") or inst:HasTag(CHESTERON and "chester" or "")) then
		inst:AddComponent("remoteinventory")
		inst.components.remoteinventory:SetDist(RADIUS, RADIUS)
	end
end)