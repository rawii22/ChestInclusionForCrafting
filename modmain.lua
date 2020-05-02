function GetOverflowContainers(player)
	local x,y,z = player.Transform:GetWorldPosition()
	local chests = GLOBAL.TheSim:FindEntities(x,y,z, 20, nil, {"quantum"}, {"chest", "cellar"})
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
		HasItem, ItemCount = OldHas(self, item, amount)
		local num_left_to_find = amount - ItemCount
		local overflows = GetOverflowContainers(self.inst)
		if overflows ~= nil then
			for k,chest in pairs(overflows) do
				--if ItemCount < amount then
					local chestHas, chestAmount = chest.components.container:Has(item, num_left_to_find)
					ItemCount = ItemCount + chestAmount
					--print("prefab: "..item.." chestHas: "..chestHas.." chestAmount: "..chestAmount)
				--end
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
		local items = OldGetItemByName(self, item, amount)
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
		local oldItem = OldRemoveItem(self, item, wholestack) --since this function was meant to always work, we pickup here if OldItem returns nil
		if oldItem == nil then
			local chests = GetOverflowContainers(self.inst)
			for k,chest in pairs(chests) do
				local remoteOldItem = chest.components.container:RemoveItem(item, wholestack)
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
		HasItem, ItemCount = OldHas(inst, item, amount)
		local num_left_to_find = amount - ItemCount
		local overflows = GetOverflowContainers(inst._parent)
		if overflows ~= nil then
			for k,chest in pairs(overflows) do
				--if ItemCount < amount then
					local chestHas, chestAmount = chest.replica.container:Has(item, num_left_to_find)
					ItemCount = ItemCount + chestAmount
				--end
			end
			HasItem = ItemCount >= amount
		end
		return HasItem, ItemCount
	end
end
AddPrefabPostInit("inventory_classified", HasClient)
--[[
local function GetItemByNameClient(prefab)
	local OldGetItemByName = prefab.GetItemByName
	prefab.GetItemByName = function(self, item, amount)
		local items = OldGetItemByName(self, item, amount)
		local itemsCount = getNumItems(items)
		print("itemsCount "..itemsCount)
		local amount_left = amount - itemsCount
		if amount_left > 0 then
			local chests = GetOverflowContainers(self.inst)
			if chests ~= nil then
				for i,chest in pairs(chests) do
					local chestItems = chest.replica.container:GetItemByName(item, amount_left)
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
AddPrefabPostInit("inventory_classified", GetItemByNameClient)
]]
local function RemoveIngredientsClient(prefab)
	local OldRemoveIngredients = prefab.RemoveIngredients
	prefab.RemoveIngredients = function(inst, recipe, ingredientmod)
		if inst:IsBusy() then
			return false
		end
		local chests = GetOverflowContainers(inst._parent)
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
		OldRemoveIngredients(inst, recipe, ingredientmod)
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
				end
			end
		end
		return true
	end
end
AddPrefabPostInit("inventory_classified", RemoveIngredientsClient)
-------------------------------------------------End for client

--[[
local function onnear(inst, player)
	print("onnear")
	player:PushEvent("refreshinventory")
end
local function onfar(inst)
	for k,v in pairs(GLOBAL.AllPlayers) do
		print("onfar: "..v.prefab)
		v:PushEvent("refreshinventory")
	end
end
]]
AddPrefabPostInitAny(function(inst)
	if inst and inst:HasTag("chest") or inst:HasTag("cellar") then
		inst:AddComponent("remoteinventory")
		inst.components.remoteinventory:SetDist(20, 20)
		--inst.components.remoteinventory:SetOnPlayerNear(onnear)
		--inst.components.remoteinventory:SetOnPlayerFar(onfar)
	end
end)