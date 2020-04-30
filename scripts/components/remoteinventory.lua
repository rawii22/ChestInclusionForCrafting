local RemoteInventory = Class(function(self, inst)
	self.inst = inst
	
	self.inst:StartUpdatingComponent(self)
end)

function RemoteInventory:OnUpdate()
	self.inst:PushEvent("refreshinventory")
end

return RemoteInventory