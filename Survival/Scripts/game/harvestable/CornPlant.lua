dofile("$SURVIVAL_DATA/Scripts/game/survival_loot.lua")

CornPlant = class()

function CornPlant.server_onProjectile( self, hitPos, hitTime, hitVelocity, projectileName, attacker, damage )
	self:sv_onHit()
end

function CornPlant.server_onMelee( self, hitPos, attacker, damage )
	self:sv_onHit()
end

function CornPlant.server_onExplosion( self, center, destructionLevel )
	self:sv_onHit()
end

function CornPlant.sv_onHit( self )
	if not self.destroyed and sm.exists( self.harvestable ) then

		local lootList = {}
		local slots = math.random( 3, 4 )
		for i = 1, slots do
			lootList[i] = { uuid = obj_resource_corn, quantity = math.random(3,5) }
		end
		SpawnLoot( self.harvestable, lootList )
		
		sm.harvestable.create( hvs_farmables_growing_cornplant, self.harvestable.worldPosition, self.harvestable.worldRotation )
		
		self.harvestable:destroy()
		self.destroyed = true
	end
end
