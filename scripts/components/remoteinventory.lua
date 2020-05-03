--This is basically a playerprox that only refreshes the inventory and that works for multiple players.

local function OnUpdateCheck(self)
    for k,v in pairs(AllPlayers) do
		local isNear = v:IsNear(self.inst, self.near)
		if isNear ~= self.isnear[v] then
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
	self.inst:ListenForEvent("itemget", function() self:RefreshCurrentPlayer() end)
	self.inst:ListenForEvent("itemlose", function() self:RefreshCurrentPlayer() end)
	
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
    self:Schedule()
    self:ForceUpdate()
end

function RemoteInventory:OnEntitySleep()
    self:ForceUpdate()
    self:Stop()
end

function RemoteInventory:ForceUpdate()
    if self.task ~= nil then
        self.onupdatecheck()
    end
end

function RemoteInventory:Refresh(player)
	if player ~= nil then
		if TheWorld.ismastersim then
			player:PushEvent("refreshinventory")
		else
			player:PushEvent("refreshcrafting")
		end
	end
end

function RemoteInventory:RefreshCurrentPlayer()
	self:Refresh(ThePlayer)
end

return RemoteInventory