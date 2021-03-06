dofile "$SURVIVAL_DATA/Scripts/game/units/unit_util.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/util/Ticker.lua"
dofile "$SURVIVAL_DATA/Scripts/game/util/Timer.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_units.lua"
dofile "$SURVIVAL_DATA/Scripts/game/units/states/PathingState.lua"
dofile "$SURVIVAL_DATA/Scripts/game/units/states/BreachState.lua"
dofile "$SURVIVAL_DATA/Scripts/game/units/states/CombatAttackState.lua"
dofile "$SURVIVAL_DATA/Scripts/game/units/states/CircleFollowState.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_constants.lua"

HaybotUnit = class( nil )

local WaterTumbleTickTime = 3.0 * 40
local AllyRange = 20.0

function HaybotUnit.server_onCreate( self )
	
	self.target = nil
	self.previousTarget = nil
	self.lastTargetPosition = nil
	self.ambushPosition = nil
	self.saved = self.storage:load()
	if self.saved == nil then
		self.saved = {}
	end
	if self.saved.stats == nil then
		self.saved.stats = { hp = 25, maxhp = 25 }
	end
	
	if self.params then
		if self.params.tetherPoint then
			self.homePosition = self.params.tetherPoint
			if self.params.ambush == true then
				self.ambushPosition = self.params.tetherPoint
			end
			if self.params.raider == true then
				self.saved.raidPosition = self.params.tetherPoint
			end
		end
		if self.params.raider then
			self.saved.raider = true
		end
		if self.params.groupId then
			g_unitManager:sv_addUnitToGroup( self.unit, self.params.groupId )
			self.saved.groupId = self.params.groupId
		end
		if self.params.temporary then
			self.saved.temporary = self.params.temporary
			self.saved.deathTickTimestamp = sm.game.getCurrentTick() + getTicksUntilDayCycleFraction( DAYCYCLE_DAWN )
		end
		if self.params.deathTick then
			self.saved.deathTickTimestamp = self.params.deathTick
		end
	end
	
	if not self.homePosition then
		self.homePosition = self.unit.character.worldPosition
	end
	self.storage:save( self.saved )
	
	self.unit.eyeHeight = self.unit.character:getHeight() * 0.75
	
	self.unit.visionFrustum = {
		{ 3.0, math.rad( 80.0 ), math.rad( 80.0 ) },
		{ 20.0, math.rad( 40.0 ), math.rad( 35.0 ) },
		{ 40.0, math.rad( 20.0 ), math.rad( 20.0 ) }
	}
	self.unit:setWhiskerData( 3, math.rad( 60.0 ), 1.5, 5.0 )
	self.noiseScale = 1.0
	self.impactCooldownTicks = 0
	self.specialHitsToDie = 3
	
	self.stateTicker = Ticker()
	self.stateTicker:init()
	
	-- Idle	
	self.idleState = self.unit:createState( "idle" )
	self.idleState.debugName = "idleState"
	self.idleState.randomEventCooldownMin = 4
	self.idleState.randomEventCooldownMax = 6
	self.idleState.randomEvents = { { name = "idlespecial01", time = 4.0, interruptible = true, chance = 0.5 },
									{ name = "idlespecial02", time = 7.5, interruptible = true, chance = 0.5 } }
	
	-- Stagger
	self.staggeredEventState = self.unit:createState( "wait" )
	self.staggeredEventState.debugName = "staggeredState"
	self.staggeredEventState.time = 0.25
	self.staggeredEventState.interruptible = false
	self.stagger = 0.0
	self.staggerProjectile = 0.5
	self.staggerMelee = 1.0
	self.staggerCooldownTickTime = 1.65 * 40
	self.staggerCooldownTicks = 0
	
	-- Circle follow
	self.circleFollowState = CircleFollowState()
	self.circleFollowState:sv_onCreate( self.unit, 3.7, 7.0, 20.0, 40 * 2, 40 * 10, 40 * 1.5, 40 * 3.5, 40 * 1.0, 40 * 2.0 )

	-- Roam
	self.roamStartTimeMin = 40 * 4 -- 4 seconds
	self.roamStartTimeMax = 40 * 8 -- 8 seconds
	self.roamTimer = Timer()
	self.roamTimer:start( math.random( self.roamStartTimeMin, self.roamStartTimeMax ) )
	self.roamState = self.unit:createState( "roam" )
	self.roamState.debugName = "roam"
	self.roamState.tetherPosition = self.unit.character.worldPosition
	self.roamState.roamCenterOffset = 0.0

	-- Pathing
	self.pathingState = PathingState()
	self.pathingState:sv_onCreate( self.unit )
	self.pathingState:sv_setTolerance( 1.0 )
	self.pathingState:sv_setMovementType( "sprint" )
	
	-- Attacks
	self.attackState01 = self.unit:createState( "meleeAttack" )
	self.attackState01.meleeType = "HaybotPitchforkSwipe"
	self.attackState01.event = "attack01"
	self.attackState01.damage = 30
	self.attackState01.attackRange = 1.75
	self.attackState01.animationCooldown = 1.65 * 40
	self.attackState01.attackCooldown = 0.25 * 40
	self.attackState01.globalCooldown = 0.0 * 40
	self.attackState01.attackDelay = 0.25 * 40
	
	self.attackState02 = self.unit:createState( "meleeAttack" )
	self.attackState02.meleeType = "HaybotPitchfork"
	self.attackState02.event = "attack02"
	self.attackState02.damage = 20
	self.attackState02.attackRange = 1.75
	self.attackState02.animationCooldown = 0.825 * 40
	self.attackState02.attackCooldown = 2.0 * 40
	self.attackState02.globalCooldown = 0.0 * 40
	self.attackState02.attackDelay = 0.25 * 40
	
	self.attackState03 = self.unit:createState( "meleeAttack" )
	self.attackState03.meleeType = "HaybotPitchfork"
	self.attackState03.event = "attack03"
	self.attackState03.damage = 20
	self.attackState03.attackRange = 1.75
	self.attackState03.animationCooldown = 0.925 * 40
	self.attackState03.attackCooldown = 2.0 * 40
	self.attackState03.globalCooldown = 0.0 * 40
	self.attackState03.attackDelay = 0.25 * 40
	
	self.attackStateSprint01 = self.unit:createState( "meleeAttack" )
	self.attackStateSprint01.meleeType = "HaybotPitchfork"
	self.attackStateSprint01.event = "sprintattack01"
	self.attackStateSprint01.damage = 20
	self.attackStateSprint01.attackRange = 1.75
	self.attackStateSprint01.animationCooldown = 0.8 * 40
	self.attackStateSprint01.attackCooldown = 3.0 * 40
	self.attackStateSprint01.globalCooldown = 0.0 * 40
	self.attackStateSprint01.attackDelay = 0.3 * 40	
	
	-- Combat
	self.combatAttackState = CombatAttackState()
	self.combatAttackState:sv_onCreate( self.unit )
	self.stateTicker:addState( self.combatAttackState )
	-- self.combatAttackState:sv_addAttack( self.attackState01 )
	self.combatAttackState:sv_addAttack( self.attackState02 )
	self.combatAttackState:sv_addAttack( self.attackState03 )
	--self.combatAttackState:sv_addAttack( self.attackStateSprint01 )
	self.combatRange = 1.0 -- Range where the unit will perform attacks
	
	self.combatTicks = 0
	self.combatTicksAttack = 20 * 40
	self.combatTicksBerserk = 50 * 40
	self.combatTicksAttackCost = 20 * 40

	self.nextFakeAggroMin = 4 * 40
	self.nextFakeAggroMax = 6 * 40
	self.nextFakeAggro = math.random( self.nextFakeAggroMin, self.nextFakeAggroMax )
	
	self.nextAggroMin = 10 * 40
	self.nextAggroMax = 16 * 40
	self.nextAggro = math.random( self.nextAggroMin, self.nextAggroMax )
	
	-- Breach
	self.breachState = BreachState()
	self.breachState:sv_onCreate( self.unit, math.ceil( 40 * 2.0 ) )
	self.stateTicker:addState( self.breachState )
	self.breachState:sv_setBreachRange( self.combatRange )
	--self.breachState:sv_addAttack( self.attackState02 )
	self.breachState:sv_addAttack( self.attackState03 )
	
	-- Combat approach
	self.combatApproachState = self.unit:createState( "positioning" )
	self.combatApproachState.debugName = "combatApproachState"
	self.combatApproachState.timeout = 1.5
	self.combatApproachState.tolerance = self.combatRange
	self.combatApproachState.avoidance = false
	self.combatApproachState.movementType = "sprint"
	self.pathingCombatRange = 2.0 -- Range where the unit will approach the player without obstacle checking
	
	-- Avoid
	self.avoidState = self.unit:createState( "positioning" )
	self.avoidState.debugName = "avoid"
	self.avoidState.timeout = 1.5
	self.avoidState.tolerance = 0.5
	self.avoidState.avoidance = false
	self.avoidState.movementType = "sprint"
	self.avoidCount = 0
	self.avoidLimit = 3
	
	-- Swim
	self.swimState = self.unit:createState( "followDirection" )
	self.swimState.debugName = "swim"
	self.swimState.avoidance = false
	self.swimState.movementType = "walk"
	self.lastStablePosition = nil

	-- Tumble
	initTumble( self )
	
	-- Crushing
	initCrushing( self, DEFAULT_CRUSH_TICK_TIME )
	
	-- Flee
	self.dayFlee = self.unit:createState( "flee" )
	self.dayFlee.movementAngleThreshold = math.rad( 180 )
	self.dayFlee.maxFleeTime = 0.0
	self.dayFlee.maxDeviation = 45 * math.pi / 180
	
	self.griefTimer = Timer()
	self.griefTimer:start( 40 * 9.0 )
	
	self.currentState = self.idleState
	self.currentState:start()
	
end

function HaybotUnit.server_onRefresh( self )
	print( "-- HaybotUnit refreshed --" )
end

function HaybotUnit.server_onDestroy( self )
	print( "-- HaybotUnit terminated --" )
end

function HaybotUnit.server_onFixedUpdate( self, dt )
	
	if sm.exists( self.unit ) and not self.destroyed then
		if self.saved.deathTickTimestamp and sm.game.getCurrentTick() >= self.saved.deathTickTimestamp then
			self.unit:destroy()
			self.destroyed = true
			return
		end
	end
	
	self.stateTicker:tick()
	
	if updateCrushing( self ) then
		print("'HaybotUnit' was crushed!")
		self:sv_onDeath( sm.vec3.new( 0, 0, 0 ) )
	end
	
	updateTumble( self )
	updateAirTumble( self, self.idleState )
	
	self.griefTimer:tick()

	local currentTargetPosition
	if self.target and sm.exists( self.target ) then
		currentTargetPosition = self.target.worldPosition
	else
		self.avoidCount = 0
	end
	if self.currentState then
		self.currentState:onFixedUpdate( dt )
	
		self.unit:setMovementDirection( self.currentState:getMovementDirection() )
		self.unit:setMovementType( self.currentState:getMovementType() )
		if self.currentState ~= self.swimState then
			if currentTargetPosition and self.currentState ~= self.combatAttackState and self.currentState ~= self.breachState and self.currentState ~= self.avoidState and self.currentState ~= self.dayFlee then
				self.unit:setFacingDirection( ( currentTargetPosition - self.unit.character.worldPosition ):normalize() )
			else
				self.unit:setFacingDirection( self.currentState:getFacingDirection() )
			end
		end
		
		-- Random roaming during idle
		if self.currentState == self.idleState then
			self.roamTimer:tick()
		end
		
		-- Always aggro when next to the target
		local closeCombat = false
		if self.target and sm.exists( self.target ) then
			local fromToTarget = self.target.worldPosition - self.unit.character.worldPosition
			local distance = fromToTarget:length()
			if distance <= self.pathingCombatRange then
				closeCombat = true
			end
		end
		
		-- Decrease aggro with time
		self.combatTicks = math.max( self.combatTicks - 1, closeCombat and 1 or 0 )
		
		self.staggerCooldownTicks = math.max( self.staggerCooldownTicks - 1, 0 )
		self.impactCooldownTicks = math.max( self.impactCooldownTicks - 1, 0 )
		
		-- Occasionally add random aggro for fakeouts and small attacks
		if self.currentState == self.circleFollowState then
			-- Real attack
			self.nextAggro = self.nextAggro - 1
			if self.nextAggro <= 0 then
				self.nextAggro = math.random( self.nextAggroMin, self.nextAggroMax )
				self.combatTicks = math.max( self.combatTicks, self.combatTicksAttack )
			end

			-- Fake attack
			self.nextFakeAggro = self.nextFakeAggro - 1
			if self.nextFakeAggro <= 0 then
				self.nextFakeAggro = math.random( self.nextFakeAggroMin, self.nextFakeAggroMax )
				self.circleFollowState:sv_rush( 16 ) -- Sprint toward target during the given tick time
				self.avoidCount = 0
			end
		end
		
	end
	
	-- Update target for haybot character
	if self.target ~= self.previousTarget then
		self:sv_updateCharacterTarget()
		self.previousTarget = self.target
	end
end

function HaybotUnit.server_onUnitUpdate( self, dt )
	
	if self.currentState then
		self.currentState:onUnitUpdate( dt )
	end
	
	-- Temporary units are routed by the daylight
	if self.saved.temporary then
		if self.currentState ~= self.dayFlee and sm.game.getCurrentTick() >= self.saved.deathTickTimestamp - DaysInTicks( 1 / 24 ) then
			local prevState = self.currentState
			prevState:stop()
			self.currentState = self.dayFlee
			self.currentState:start()
		end
		if self.currentState == self.dayFlee then
			return
		end
	end
	
	if self.unit.character:isTumbling() then
		return
	end
	
	local targetCharacter
	local currentTargetPosition
	
	local closestVisiblePlayerCharacter
	local closestHeardPlayerCharacter
	local closestVisibleWocCharacter
	local closestVisibleWormCharacter
	local closestVisibleCrop
	closestVisiblePlayerCharacter = sm.ai.getClosestVisiblePlayerCharacter( self.unit )
	if not closestVisiblePlayerCharacter then
		closestHeardPlayerCharacter = listenForCharacterNoise( self.unit.character, self.noiseScale )
	end
	if not closestVisiblePlayerCharacter and not closestHeardPlayerCharacter then
		closestVisibleWocCharacter = sm.ai.getClosestVisibleCharacterType( self.unit, unit_woc )
	end
	if not closestVisibleWocCharacter and not closestVisiblePlayerCharacter and not closestHeardPlayerCharacter then
		closestVisibleWormCharacter = sm.ai.getClosestVisibleCharacterType( self.unit, unit_worm )
	end
	if self.saved.raider then
		closestVisibleCrop = sm.ai.getClosestVisibleCrop( self.unit )
	elseif not closestVisibleWormCharacter and not closestVisibleWocCharacter and not closestVisiblePlayerCharacter and not closestHeardPlayerCharacter then
		if self.griefTimer:done() then
			closestVisibleCrop = sm.ai.getClosestVisibleCrop( self.unit )
		end
	end
	
	local restartPathing = false
	
	local allyUnits = {}
	local nearbyAllies = 0
	if self.saved.groupId then
		for _, allyUnit in ipairs( g_unitManager:sv_getUnitGroup( self.saved.groupId ) ) do
			if sm.exists( allyUnit ) then
				allyUnits[#allyUnits+1] = allyUnit
				if ( allyUnit.character.worldPosition - self.unit.character.worldPosition ):length() <= AllyRange then
					nearbyAllies = nearbyAllies + 1
				end
			end
		end
	end
	
	-- Find target
	if closestVisiblePlayerCharacter then
		targetCharacter = closestVisiblePlayerCharacter
	elseif closestHeardPlayerCharacter then
		targetCharacter = closestHeardPlayerCharacter
	elseif closestVisibleWocCharacter then
		targetCharacter = closestVisibleWocCharacter
	elseif closestVisibleWormCharacter then
		targetCharacter = closestVisibleWormCharacter
	end
	
	-- Share found target
	local foundTarget = false
	if targetCharacter and self.target == nil then
		for _, allyUnit in ipairs( allyUnits ) do
			if self.unit ~= allyUnit then
				if ( allyUnit.character.worldPosition - self.unit.character.worldPosition ):length() <= AllyRange then
					sm.event.sendToUnit( allyUnit, "sv_e_receiveTarget", { targetCharacter = targetCharacter, sendingUnit = self.unit } )
				end
			end
		end
		foundTarget = true
	end
	
	if self.saved.raider then
		selectRaidTarget( self, targetCharacter, closestVisibleCrop )
	else
		if targetCharacter then
			self.target = targetCharacter
		else
			self.target = closestVisibleCrop
		end
	end
	
	-- Cooldown after attacking a crop
	if type( self.target ) == "Harvestable" then
		local _, attackResult = self.combatAttackState:isDone()
		if attackResult == "started" or attackResult == "attacked" then
			self.griefTimer:reset()
		end
	end
	
	local prevState = self.currentState
	if self.unit.character:isOnGround() and not self.unit.character:isSwimming() then
		self.lastStablePosition = self.unit.character.worldPosition
	end
	
	if self.target then
		currentTargetPosition = self.target.worldPosition
		if type( self.target ) == "Harvestable" then
			currentTargetPosition = self.target.worldPosition + sm.vec3.new( 0, 0, self.unit.character:getHeight() * 0.5 )
		end
		local fromToTarget = self.target.worldPosition - self.unit.character.worldPosition
		self.combatAttackState:sv_setAttackDirection( fromToTarget:normalize() ) -- Turn ongoing attacks toward moving players
		self.lastTargetPosition = currentTargetPosition
		
		self.combatApproachState.desiredPosition = currentTargetPosition
		self.combatApproachState.desiredDirection = fromToTarget:normalize()
		self.attackState01.attackDirection = fromToTarget:normalize()
	end
	
	-- Find dangerous obstacles
	local shouldAvoid = false
	local closestDangerShape, _ = g_unitManager:sv_getClosestDangers( self.unit.character.worldPosition )
	if closestDangerShape then
		local fromToDanger = closestDangerShape.worldPosition - self.unit.character.worldPosition
		local distance = fromToDanger:length()
		if distance <= 3.5 and ( ( self.target and self.avoidCount < self.avoidLimit ) or self.target == nil ) then
			self.avoidState.desiredPosition = self.unit.character.worldPosition - fromToDanger:normalize() * 2
			self.avoidState.desiredDirection = fromToDanger:normalize()
			shouldAvoid = true
		end
	end
	
	-- Raiders will continue attacking an ambush position
	if self.saved.raidPosition then
		local flatFromToRaid = sm.vec3.new( self.saved.raidPosition.x,  self.saved.raidPosition.y, self.unit.character.worldPosition.z ) - self.unit.character.worldPosition
		if flatFromToRaid:length() >= RAIDER_AMBUSH_RADIUS then
			self.ambushPosition = self.saved.raidPosition
		end
	end
	
	-- Ambushers will always have somewhere they want to go
	if self.ambushPosition then
		if not self.lastTargetPosition and not self.target then
			self.lastTargetPosition = self.ambushPosition
		end
		local flatFromToAmbush = sm.vec3.new( self.ambushPosition.x,  self.ambushPosition.y, self.unit.character.worldPosition.z ) - self.unit.character.worldPosition
		if flatFromToAmbush:length() <= 2.0 then
			-- Finished ambush
			self.ambushPosition = nil
		end
	end
	
	-- Check for direct path
	local directPath = false
	if self.lastTargetPosition then
		local directPathDistance = 7.0 
		local fromToTarget = self.lastTargetPosition - self.unit.character.worldPosition
		local distance = fromToTarget:length()
		if distance <= directPathDistance then
			directPath = sm.ai.directPathAvailable( self.unit, self.lastTargetPosition, directPathDistance )
		end
	end
	
	local combatPathing = self.combatTicks > 0 or nearbyAllies >= 3 or closestVisibleCrop or closestVisibleWormCharacter
	-- Auto aggressive behaviour if the target is close, but unreachable
	if not directPath and self.lastTargetPosition and not combatPathing then
		combatPathing = true
	end
	
	-- Update pathingState destination and condition
	local pathingConditions = { { variable = sm.pathfinder.conditionProperty.target, value = ( self.lastTargetPosition and 1 or 0 ) } }
	self.pathingState:sv_setConditions( pathingConditions )
	if self.currentState == self.pathingState then
		if currentTargetPosition then
			self.pathingState:sv_setDestination( currentTargetPosition )
		elseif self.lastTargetPosition then
			self.pathingState:sv_setDestination( self.lastTargetPosition )
		end
	end
	
	-- Breach check
	local breachDestination = nil
	if combatPathing then
		local nextTargetPosition
		if currentTargetPosition then
			nextTargetPosition = currentTargetPosition
		elseif self.lastTargetPosition then
			nextTargetPosition = self.lastTargetPosition
		end
		-- Always check for breachable in front of the unit
		if nextTargetPosition == nil then
			nextTargetPosition = self.unit.character.worldPosition + self.unit.character.direction
		end
		
		if nextTargetPosition then
			local breachDepth = 0.25
			local characterRadius = self.unit.character:getRadius()
			local fromToNextTarget = sm.vec3.new( nextTargetPosition.x, nextTargetPosition.y, self.unit.character.worldPosition.z ) - self.unit.character.worldPosition
			local leveledNextTargetPosition = sm.vec3.new( nextTargetPosition.x, nextTargetPosition.y, self.unit.character.worldPosition.z )
			local valid, breachPosition = sm.ai.getBreachablePosition( self.unit, leveledNextTargetPosition, breachDepth + self.unit.character:getRadius(), 5 )
			if valid and breachPosition then
				local flatFromToNextTarget = leveledNextTargetPosition
				flatFromToNextTarget.z = 0
				if flatFromToNextTarget:length() <= 0 then
					flatFromToNextTarget = sm.vec3.new(0, 1, 0 )
				end
				breachDestination = nextTargetPosition + flatFromToNextTarget:normalize() * ( breachDepth + self.unit.character:getRadius() ) 
			end
		else
			self.combatTicks = 0
			combatPathing = false
		end
	end
	
	local done, result = self.currentState:isDone()
	-- Abort task
	if ( ( breachDestination and self.currentState ~= self.breachState ) or ( directPath and self.currentState == self.breachState ) or foundTarget or shouldAvoid or self.unit.character:isSwimming() ) and not done then
		done = true
		result = nil
	end
	if self.currentState == self.attackState01 then
		-- Not allowed to abort
		done, result = self.currentState:isDone()
	end
	if done then
		-- Reduce aggro with successful attacks
		if self.currentState == self.combatAttackState and ( result == "finished" or result == "ready" ) then
			self.combatTicks = math.max( self.combatTicks - self.combatTicksAttackCost, 0 )
		end
		
		-- Select state
		if self.unit.character:isSwimming() then
			local landPosition = self.lastStablePosition and self.lastStablePosition or self.homePosition
			if landPosition then
				local landDirection = landPosition - self.unit.character.worldPosition
				landDirection.z = 0
				if landDirection:length() >= FLT_EPSILON then
					landDirection = landDirection:normalize()
				else
					landDirection = sm.vec3.new( 0, 1, 0 )
				end
				self.swimState.desiredDirection = landDirection
			end
			self.currentState = self.swimState
		elseif self.currentState == self.staggeredEventState then
			--Counterattack
			self.currentState = self.attackState01
		elseif shouldAvoid then
			if self.currentState ~= self.avoidState  then
				self.avoidCount = math.min( self.avoidCount + 1, self.avoidLimit )
			end
			self.currentState = self.avoidState
		elseif self.currentState == self.pathingState and result == "arrived" or self.currentState == self.combatApproachState and result == "timeout" or self.currentState == self.breachState then
			if breachDestination then
				self.breachState:sv_setDestination( breachDestination )
				self.currentState = self.breachState
			else
				-- Special check for obstacles or direct routes to players after pathing
				local nextTargetPosition
				if currentTargetPosition then
					nextTargetPosition = currentTargetPosition
				elseif self.lastTargetPosition then
					nextTargetPosition = self.lastTargetPosition
				end
				if nextTargetPosition == nil then
					nextTargetPosition = self.unit.character.worldPosition + self.unit.character.direction
				end
				self.circleFollowState:sv_setTargetPosition( nextTargetPosition )
				self.currentState = self.circleFollowState
			end
		elseif self.currentState == self.pathingState and breachDestination then
			-- Start breaching path obstacle
			self.breachState:sv_setDestination( breachDestination )
			self.currentState = self.breachState
		elseif combatPathing then
			-- Select combat state
			if currentTargetPosition then
				local fromToTarget = currentTargetPosition - self.unit.character.worldPosition
				local distance = fromToTarget:length()
				local flatCurrentTargetPosition = sm.vec3.new(  currentTargetPosition.x, currentTargetPosition.y, self.unit.character.worldPosition.z )
				local flatFromToTarget = flatCurrentTargetPosition - self.unit.character.worldPosition
				local flatDistance = flatFromToTarget:length()
				
				if flatDistance <= self.combatRange then
					-- Attack towards target character
					self.combatAttackState:sv_setAttackDirection( fromToTarget:normalize() )
					self.currentState = self.combatAttackState
				elseif flatDistance <= self.pathingCombatRange and self.currentState ~= self.combatAttackState then
					-- Move close to the target to increase the likelihood of a hit
					self.combatApproachState.desiredPosition = flatCurrentTargetPosition
					self.combatApproachState.desiredDirection = fromToTarget:normalize()
					self.currentState = self.combatApproachState
				else
					-- Move towards target character
					if directPath then
						self.combatApproachState.desiredPosition = flatCurrentTargetPosition
						self.combatApproachState.desiredDirection = fromToTarget:normalize()
						self.currentState = self.combatApproachState
					else
						if self.currentState ~= self.pathingState then
							self.pathingState:sv_setDestination( currentTargetPosition )
						end
						self.currentState = self.pathingState
					end
				end
			elseif self.lastTargetPosition then
				if self.currentState ~= self.pathingState then
					self.pathingState:sv_setDestination( self.lastTargetPosition )
				end
				self.currentState = self.pathingState
				self.lastTargetPosition = nil
			else
				self.currentState = self.idleState
				self.combatTicks = 0
			end
		else
			-- Select non-combat state
			if self.target then 
				-- Stick close to the target and circle around
				self.circleFollowState:sv_setTargetPosition( self.target.worldPosition )
				self.currentState = self.circleFollowState
			elseif self.lastTargetPosition then
				if self.currentState ~= self.pathingState then
					self.pathingState:sv_setDestination( self.lastTargetPosition )
				end
				self.currentState = self.pathingState
				self.lastTargetPosition = nil
			elseif self.roamTimer:done() and not ( self.currentState == self.idleState and result == "started" ) then
				self.roamTimer:start( math.random( self.roamStartTimeMin, self.roamStartTimeMax ) )
				self.currentState = self.roamState
			elseif not ( self.currentState == self.roamState and result == "roaming" ) then
				self.currentState = self.idleState
			end
		end
	end
	
	if prevState ~= self.currentState or restartPathing then
		
		
		if ( prevState == self.roamState and self.currentState ~= self.idleState ) or ( prevState == self.idleState and self.currentState ~= self.roamState ) then
			self.unit:sendCharacterEvent( "alerted" )
		elseif self.currentState == self.idleState and prevState ~= self.roamState then
			self.unit:sendCharacterEvent( "roaming" )
		end
		
		prevState:stop()
		self.currentState:start()
		if DEBUG_AI_STATES then
			print("change state")
			if self.currentState == self.idleState then
				print("idleState")
			elseif self.currentState == self.pathingState then
				print("pathingState")
			elseif self.currentState == self.roamState then
				print("roamState")
			elseif self.currentState == self.circleFollowState then
				print("circleFollowState")
			elseif self.currentState == self.combatApproachState then
				print("combatApproachState")
			elseif self.currentState == self.staggeredEventState then
				print("staggeredEventState")
			elseif self.currentState == self.combatAttackState then
				print("combatAttackState")
			elseif self.currentState == self.breachState then
				print("breachState")
			else
				print("unknown")
			end
		end
		
	end
end

function HaybotUnit.server_onProjectile( self, hitPos, hitTime, hitVelocity, projectileName, attacker, damage )
	if type( attacker ) == "Player" or type( attacker ) == "Shape" then
		if damage > 0 then
			self:sv_addStagger( self.staggerProjectile )
			if type( attacker ) == "Player" then
				local attackingCharacter = attacker:getCharacter()
				self.target = attackingCharacter
				self.lastTargetPosition = attackingCharacter.worldPosition
			elseif type( attacker ) == "Shape" then
				self.target = attacker
				self.lastTargetPosition = attacker.worldPosition
			end
			self.combatTicks = math.max( self.combatTicks, self.combatTicksBerserk )

			local impact = hitVelocity:normalize() * 6
			self:sv_takeDamage( damage, impact, hitPos )
		end
	end
	if projectileName == "water" then
		startTumble( self, WaterTumbleTickTime, self.idleState )
		sm.effect.playEffect( "Part - Electricity", self.unit.character.worldPosition )
	end
end

function HaybotUnit.server_onMelee( self, hitPos, attacker, damage )
	if type( attacker ) == "Player" then
		local attackingCharacter = attacker:getCharacter()
		local ZAxis = sm.vec3.new( 0.0, 0.0, 1.0 )
		
		self:sv_addStagger( self.staggerMelee )
		self.target = attackingCharacter
		self.lastTargetPosition = attackingCharacter.worldPosition
		self.combatTicks = math.max( self.combatTicks, self.combatTicksBerserk )
		
		local attackDirection = ( self.unit.character.worldPosition - attackingCharacter.worldPosition ):normalize()
		local impact = attackDirection * 6
		self:sv_takeDamage( damage, impact, hitPos )
	end
end

function HaybotUnit.server_onExplosion( self, center, destructionLevel )
	local impact = ( self.unit:getCharacter().worldPosition - center ):normalize()
	self:sv_takeDamage( self.saved.stats.maxhp, impact, self.unit:getCharacter().worldPosition )
end

function HaybotUnit.server_onCollision( self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal  ) 

	if type( other ) == "Character" then
		if not sm.exists( other ) then
			return
		end
		if other:isPlayer() then
			if self.target == nil then
				self.target = other
				self.lastTargetPosition = other.worldPosition
			end
		end
	end
	
	if self.impactCooldownTicks > 0 then
		return
	end
		
	local damageFraction, tumbleTicks = CharacterCollision( self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal )
	local damage = damageFraction * self.saved.stats.maxhp
	if damage > 0 or tumbleTicks > 0 then
		self.impactCooldownTicks = 0.25 * 40
	end
	if damage > 0 then
		print("'HaybotUnit' took collision damage")
		self:sv_takeDamage( damage, collisionNormal, collisionPosition )
	end
	if tumbleTicks > 0 then
		startTumble( self, tumbleTicks, self.idleState )
	end
	
end

function HaybotUnit.server_onCollisionCrush( self )
	if not sm.exists( self.unit ) then
		return
	end
	onCrush( self )
end

function HaybotUnit.sv_updateCharacterTarget( self )
	if self.unit.character then
		sm.event.sendToCharacter( self.unit.character, "sv_n_updateTarget", { target = self.target } )
	end
end

function HaybotUnit.sv_addStagger( self, stagger )
	
	-- Update stagger
	if self.staggerCooldownTicks <= 0 then
		self.staggerCooldownTicks = self.staggerCooldownTickTime
		self.stagger = self.stagger + stagger
		local triggerStaggered = false
		while self.stagger >= 1.0 do
			self.stagger = self.stagger - 1.0
			triggerStaggered = true
		end
		if triggerStaggered then
			local prevState = self.currentState
			self.currentState = self.staggeredEventState
			prevState:stop()
			self.currentState:start()
		end
	end
	
end

function HaybotUnit.sv_takeDamage( self, damage, impact, hitPos )
	if self.saved.stats.hp > 0 then
		self.saved.stats.hp = self.saved.stats.hp - damage
		self.saved.stats.hp = math.max( self.saved.stats.hp, 0 )
		print( "'HaybotUnit' received:", damage, "damage.", self.saved.stats.hp, "/", self.saved.stats.maxhp, "HP" )
		
		for _, allyUnit in ipairs( g_unitManager:sv_getUnitGroup( self.saved.groupId ) ) do
			if sm.exists( allyUnit ) and self.unit ~= allyUnit then
				sm.event.sendToUnit( allyUnit, "sv_e_allyDamaged", { sendingUnit = self.unit } )
			end
		end
		
		local effectRotation = sm.quat.identity()
		if impact and impact:length() >= FLT_EPSILON then
			effectRotation = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), -impact:normalize() )
		end
		sm.effect.playEffect( "Haybot - Hit", hitPos, nil, effectRotation )

		if self.saved.stats.hp <= 0 then
			self:sv_onDeath( impact )
		else
			self.unit:sendCharacterEvent( "impact" )
			self.storage:save( self.saved )
		end
	end
end

function HaybotUnit.sv_onDeath( self, impact )
	local character = self.unit:getCharacter()
	if not self.destroyed then
		g_unitManager:sv_addDeathMarker( character.worldPosition )
		self.saved.stats.hp = 0
		self.unit:destroy()
		print("'HaybotUnit' killed!")
		self.unit:sendCharacterEvent( "explode" )
		self:sv_spawnParts( impact )
		local loot = SelectLoot( "loot_haybot" )
		SpawnLoot( self.unit, loot )
		self.destroyed = true
	end
end

function HaybotUnit.sv_spawnParts( self, impact )
	local character = self.unit:getCharacter()

	local lookDirection = character:getDirection()
	local bodyPos = character.worldPosition
	local bodyRot = sm.quat.identity()
	lookDirection = sm.vec3.new( lookDirection.x, lookDirection.y, 0 )
	if lookDirection:length() >= FLT_EPSILON then
		lookDirection = lookDirection:normalize()
		bodyRot = sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), lookDirection  ) --Turn parts sideways
	end
	local bodyOffset = bodyRot * sm.vec3.new( -0.25, 0.25, 0.375 )
	bodyPos = bodyPos - bodyOffset

	local headBody = sm.body.createBody( bodyPos, bodyRot, true )
	local headShape = headBody:createPart( obj_robotparts_haybothead, sm.vec3.new( 0, 1, 2 ), sm.vec3.new( 0, 1, 0 ), sm.vec3.new( -1, 0, 0 ), true )
	sm.physics.applyImpulse( headShape, impact * headShape.mass, true )
	
	local middleBody = sm.body.createBody( bodyPos, bodyRot, true )
	local middleShape = middleBody:createPart( obj_robotparts_haybotbody, sm.vec3.new( 0, 0, 0 ), sm.vec3.new( 0, 1, 0 ), sm.vec3.new( -1, 0, 0 ), true )
	sm.physics.applyImpulse( middleShape, impact * middleShape.mass, true )
	
	local rightArmBody = sm.body.createBody( bodyPos, bodyRot, true )
	local rightArmShape = rightArmBody:createPart( obj_robotparts_haybotfork, sm.vec3.new( 1, 2, 0 ), sm.vec3.new( 0, 1, 0 ), sm.vec3.new( -1, 0, 0 ), true )
	sm.physics.applyImpulse( rightArmShape, impact * rightArmShape.mass, true )
	
	local tiltAxis = sm.vec3.new( 0, 1, 0 ):rotateZ( math.rad( math.random( 0, 359 ) ) )
	local tiltRotation = sm.quat.angleAxis( math.rad( math.random( 18, 22 ) ), tiltAxis )
	
	local scrapBody = sm.body.createBody( bodyPos, tiltRotation, true )
	local scrapShape = scrapBody:createPart( obj_harvest_metal, sm.vec3.new( -1, 2, -1 ), sm.vec3.new( 0, -1, 0 ), sm.vec3.new( 1, 0, 0 ), true )
end

function HaybotUnit.sv_e_receiveTarget( self, params )
	if self.target == nil then
		self.target = params.targetCharacter
		self.lastTargetPosition = params.targetCharacter.worldPosition
	end
end

function HaybotUnit.sv_e_allyDamaged( self, params )
	if sm.exists( params.sendingUnit ) and ( params.sendingUnit.character.worldPosition - self.unit.character.worldPosition ):length() <= AllyRange then
		self.circleFollowState:sv_avoid( 30,  params.sendingUnit.character.worldPosition ) -- Sprint evasively during the given tick time
	end
end

function HaybotUnit.sv_e_onEnterWater( self ) end

function HaybotUnit.sv_e_onStayWater( self ) end
