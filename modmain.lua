local function GetOverflowContainers(component)
	local OldGetOverflow = component.GetOverflowContainer
	component.GetOverflowContainer = function(self)
		local chest = --[[DoUpdateRecipesRemote() and]] GLOBAL.c_find("treasurechest", 20) --or nil
		return --[[GLOBAL.ThePlayer:OldGetOverflow() or]] (chest ~= nil and chest.components.container ~= nil and chest.components.container.canbeopened)
			and chest.components.container
			or nil
	end
end

AddComponentPostInit("inventory", GetOverflowContainers)
--[[
function DoUpdateRecipesRemote(self)
	local OldDoUpdateRecipes = self.DoUpdateRecipes
	self.DoUpdateRecipes = function(self)
		OldDoUpdateRecipes()
		local item = GLOBAL.c_find("treasurechest", 20) ~= nil 
		if item then
			return true
		else
			return false
		end
	end
end
AddClassPostConstruct("widgets/crafttabs", DoUpdateRecipesRemote)
]]