-- Fence.lua --
dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")

Fence = class( nil )

function Fence.server_onCreate( self )
	self:sv_init()
end

function Fence.server_onRefresh( self ) 
	self:sv_init()
end

function Fence.sv_init( self ) 
	self.destroyed = false
	
	if self.areaTrigger then
		sm.areaTrigger.destroy( self.areaTrigger )
		self.areaTrigger = nil
	end
	
	local aabbMin, aabbMax = self.harvestable:getAabb()
	local bounds = sm.vec3.new( math.abs( aabbMax.x - aabbMin.x ), math.abs( aabbMax.y - aabbMin.y ), math.abs( aabbMax.z - aabbMin.z ) )
	local centerPos = aabbMin + bounds * 0.5

	self.areaTrigger = sm.areaTrigger.createBox( bounds * 0.5, centerPos, nil, sm.areaTrigger.filter.dynamicBody )
	self.areaTrigger:bindOnEnter( "trigger_onEnter" )
end

function Fence.sv_onHit( self, impactVelocity )
	if sm.exists( self.harvestable ) and not self.destroyed then
		local harvestablePosition = sm.harvestable.getPosition( self.harvestable )
		local harvestableRotation = sm.harvestable.getRotation( self.harvestable )
		
		if self.data.effectName then
			harvestableRotation = harvestableRotation * sm.quat.new( -0.70710678118, 0, 0, 0.70710678118 )
			harvestablePosition = harvestablePosition + harvestableRotation * sm.vec3.new( 0, 0, 0.75 )
			
			sm.effect.playEffect( self.data.effectName, harvestablePosition, nil, harvestableRotation, nil, { Color = self.harvestable:getColor(), velocity = impactVelocity:length(), startVelocity = impactVelocity, velocity_max_50 = impactVelocity:length() } )
		end
		sm.harvestable.destroy( self.harvestable )
		self.destroyed = true
	end
end

function Fence.server_onMelee( self, hitPos, attacker, damage )
	local harvestablePosition = sm.harvestable.getPosition( self.harvestable )
	self:sv_onHit( attacker.character.direction * 5 )
end

function Fence.server_onExplosion( self, center, destructionLevel )
	local harvestablePosition = sm.harvestable.getPosition( self.harvestable )
	self:sv_onHit( ( center - harvestablePosition ):normalize() * 5 )
end

function Fence.trigger_onEnter( self, trigger, results )
	for _, result in ipairs( results ) do
		if sm.exists( result ) then
			if type( result ) == "Body" then
				self:sv_onHit( result:getVelocity() )
			end
		end
	end
end