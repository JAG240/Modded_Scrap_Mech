dofile("$SURVIVAL_DATA/Scripts/game/survival_loot.lua")

SlimyClam = class()


function SlimyClam.server_onMelee( self, hitPos, attacker, damage )
	self:sv_onHit()
end

function SlimyClam.server_onExplosion( self, center, destructionLevel )
	self:sv_onHit()
end

function SlimyClam.sv_onHit( self )
	if not self.harvested and sm.exists( self.harvestable ) then
		local harvest = {
			lootUid = obj_resources_slimyclam,
			lootQuantity = math.random(3,5)
		}
		local pos = self.harvestable:getPosition() + sm.vec3.new( 0, 0, 0.5 )
		sm.projectile.harvestableCustomProjectileAttack( harvest, "loot", 0, pos, sm.noise.gunSpread( sm.vec3.new( 0, 0, 1 ), 20 ) * 5, self.harvestable, 0 )
	
		sm.harvestable.create( hvs_farmables_slimyclam_broken, self.harvestable.worldPosition, self.harvestable.worldRotation )
		sm.harvestable.destroy( self.harvestable )
		self.harvested = true
	end
end

function SlimyClam.client_onCreate( self )
	self.cl = {}
	self.cl.bubbleEffect = sm.effect.createEffect( "SlimyClam - Bubbles" )
	self.cl.bubbleEffect:setPosition( self.harvestable.worldPosition )
	self.cl.bubbleEffect:setRotation( self.harvestable.worldRotation )
	self.cl.bubbleEffect:start()
end

function SlimyClam.client_onDestroy( self )
	self.cl.bubbleEffect:stop()
	self.cl.bubbleEffect:destroy()
end