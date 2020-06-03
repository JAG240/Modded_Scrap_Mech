-- PigmentFlower.lua --
dofile "$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua"

PigmentFlower = class( nil )

function PigmentFlower.client_onInteract( self, state )
	self.network:sendToServer( "sv_n_harvest" )
end

function PigmentFlower.server_onMelee( self, hitPos, attacker, damage )
	if not self.harvested and sm.exists( self.harvestable ) then
		sm.effect.playEffect( "Pigmentflower - Picked", self.harvestable.worldPosition )
		
		local harvest = {
			lootUid = obj_resource_flower,
			lootQuantity = 1
		}
		local pos = self.harvestable:getPosition() + sm.vec3.new( 0, 0, 0.5 )
		sm.projectile.harvestableCustomProjectileAttack( harvest, "loot", 0, pos, sm.noise.gunSpread( sm.vec3.new( 0, 0, 1 ), 20 ) * 5, self.harvestable, 0 )
		
		sm.harvestable.create( hvs_farmables_growing_pigmentflower, self.harvestable.worldPosition, self.harvestable.worldRotation )
		sm.harvestable.destroy( self.harvestable )
		self.harvested = true
	end
end

function PigmentFlower.server_onRemoved( self, player )
	self:sv_n_harvest( nil, player )
end

function PigmentFlower.cl_n_onInventoryFull( self )
	sm.gui.displayAlertText( "#{INFO_INVENTORY_FULL}", 4 )
end

function PigmentFlower.sv_n_harvest( self, params, player )
	if not self.harvested and sm.exists( self.harvestable ) then
		local container = player:getInventory()
		if sm.container.beginTransaction() then
			sm.container.collect( container, obj_resource_flower, math.random(3,5))
			if sm.container.endTransaction() then
				sm.effect.playEffect( "Pigmentflower - Picked", self.harvestable.worldPosition )
				sm.harvestable.create( hvs_farmables_growing_pigmentflower, self.harvestable.worldPosition, self.harvestable.worldRotation )
				sm.harvestable.destroy( self.harvestable )
				self.harvested = true
			else
				self.network:sendToClient( player, "cl_n_onInventoryFull" )
			end
		end
	end
end
