local function GetOverflowContainers(player)
	local x,y,z = player.Transform:GetWorldPosition()
	local chests = TheSim:FindEntities(x,y,z, 20, {"chest"}, {"quantum"})
	return #chests > 0 and chests or nil
end

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
		print("itemsCount "..itemsCount)
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

local function RemoveItemRemote(component)
	print("Hello")
	local OldRemoveItem = component.RemoveItem
	print("Hello2")
	component.RemoveItem = function(self, item, wholestack)
		print("Hello3")
		local oldItem = OldRemoveItem(self, item, wholestack) --since this function was meant to always work, we pickup here if OldItem returns nil
		print("oldItem:")
		print(oldItem)
		if oldItem == nil then
			local chests = GetOverflowContainers(self.inst)
			for k,chest in pairs(chests) do
				local remoteOldItem = chest.components.container:RemoveItem(item, whoelstack)
				print("remoteOldItem:")
				print(remoteOldItem)
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

--[[
AddPrefabPostInitAny(function(inst)
	if inst and inst:HasTag("player") then
		inst:AddComponent("RemoteInventory")
	end
end)
]]

local function onnear(inst, player)
	player:PushEvent("refreshinventory")
end
local function onfar(inst)
	for k,v in pairs(GLOBAL.AllPlayers) do
		v:PushEvent("refreshinventory")
	end
end

AddPrefabPostInitAny(function(inst)
	if inst and inst:HasTag("chest") then
		inst:AddComponent("playerprox")
		inst.components.playerprox:SetDist(20, 20)
		inst.components.playerprox:SetOnPlayerNear(onnear)
		inst.components.playerprox:SetOnPlayerFar(onfar)
	end
end)