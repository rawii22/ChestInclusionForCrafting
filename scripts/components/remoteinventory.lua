--This is basically a playerprox that only refreshes the inventory and that works for multiple players.

local function OnUpdateCheck(self)
    for k,v in pairs(AllPlayers) do
		local isNear = v:IsNear(self.inst, self.near)
		if isNear ~= self.isnear[v] then
			print("About to refresh...")
			self.isnear[v] = isNear
			self:Refresh(v)
		end
	end
end

local RemoteInventory = Class(function(self, inst)
	self.inst = inst
	
	self.task = nil
	self.period = 10 * FRAMES
	self.near = 20
	self.far = 20
	self.isnear = {}
	--self.onnear = nil
	--self.onfar = nil
	
	self.onupdatecheck = function() OnUpdateCheck(self) end
	
	self.inst:StartUpdatingComponent(self)
end)

--[[
function RemoteInventory:SetOnPlayerNear(fn)
    self.onnear = fn
end

function RemoteInventory:SetOnPlayerFar(fn)
    self.onfar = fn
end
]]

function RemoteInventory:SetDist(near, far)
    self.near = near
    self.far = far
end

function RemoteInventory:Schedule()
    self:Stop()
    self.task = self.inst:DoPeriodicTask(self.period, self.onupdatecheck, nil, self)
end

function RemoteInventory:Stop()
    if self.task ~= nil then
        self.task:Cancel()
        self.task = nil
    end
end

function RemoteInventory:OnEntityWake()
	print("OnEntityWake")
    self:Schedule()
    self:ForceUpdate()
end

function RemoteInventory:OnEntitySleep()
	print("OnEntitySleep")
    self:ForceUpdate()
    self:Stop()
end

function RemoteInventory:ForceUpdate()
    if self.task ~= nil then
        self.onupdatecheck()
    end
end

function RemoteInventory:Refresh(player)
	print("Refreshing for "..player.prefab)
	for k,v in pairs(self.isnear) do
		print("k: "..tostring(k))
		print(v and "true" or "false")
		
	end
	print("player: "..tostring(player))
	if TheWorld.ismastersim then
		player:PushEvent("refreshinventory")
	else
		player:PushEvent("refreshcrafting")
	end
end

return RemoteInventory