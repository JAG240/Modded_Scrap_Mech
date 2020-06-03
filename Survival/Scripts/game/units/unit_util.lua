
function getClosestCharacter( position, characters )
	local closestDistance2
	local closestCharacter
	for _,character in ipairs( characters ) do
		local distance2 = ( position - character.worldPosition ):length2()
		if closestDistance2 == nil or distance2 < closestDistance2 then
			closestCharacter = character
		end
	end
	return closestCharacter, math.sqrt( closestDistance2 )
end

function listenForCharacterNoise( listeningCharacter, noiseScale )
	local closestCharacter = nil
	local bestFraction = -1
	local allPlayers = sm.player.getAllPlayers()
	for _, player in ipairs( allPlayers ) do
		if player.character then
			local noiseRadius = player.character:getCurrentMovementNoiseRadius() * noiseScale
			if noiseRadius > 0 then
				local noiseFraction = 1.0 - ( player.character.worldPosition - listeningCharacter.worldPosition ):length() / noiseRadius
				if noiseFraction > 0 and ( noiseFraction > bestFraction or bestFraction == -1 ) then
					bestFraction = noiseFraction
					closestCharacter = player.character
				end
			end
		end
	end
	if closestCharacter then
		local success, result = sm.physics.raycast( listeningCharacter.worldPosition, closestCharacter.worldPosition, listeningCharacter )
		if success and result.type == "character" and result:getCharacter() == closestCharacter then
			return closestCharacter
		end
	end
	return nil
end

function initTumble( self )
	self.tumbleReset = Timer()
	self.tumbleReset:start( DEFAULT_TUMBLE_TICK_TIME )
	self.airTicks = 0
end

function startTumble( self, tumbleTickTime, tumbleState )
	if not self.unit.character:isDowned() then
		self.unit.character:setTumbling( true )
		if tumbleTickTime then
			self.tumbleReset:start( tumbleTickTime )
		else
			self.tumbleReset:start( DEFAULT_TUMBLE_TICK_TIME )
		end
		if tumbleState then
			self.currentState:stop()
			self.currentState = tumbleState
			self.currentState:start()
		end
	end
end

function updateTumble( self )
	if self.unit.character:isTumbling() then
		local tumbleVelocity = self.unit.character:getTumblingLinearVelocity()
		if tumbleVelocity:length() < 1.0 then
			self.tumbleReset:tick()

			if self.tumbleReset:done() then
				self.unit.character:setTumbling( false )
				self.tumbleReset:reset()
			end
		else
			self.tumbleReset:reset()
		end
	end
end

function updateAirTumble( self, tumbleState )
	if not self.unit.character:isOnGround() and not self.unit.character:isSwimming() and not self.unit.character:isTumbling() then
		self.airTicks = self.airTicks + 1
		if self.airTicks >= AIR_TICK_TIME_TO_TUMBLE then
			startTumble( self, DEFAULT_TUMBLE_TICK_TIME, tumbleState )
		end
	else
		self.airTicks = 0
	end
end

function initCrushing( self, crushTickTime )
	self.crushTicks = 0
	self.crushTickTime = crushTickTime and crushTickTime or DEFAULT_CRUSH_TICK_TIME
	self.crushUpdate = false
end

function onCrush( self  )
	self.crushUpdate = true
end

function updateCrushing( self )
	
	if self.crushUpdate then
		self.crushTicks = math.min( self.crushTicks + 1, self.crushTickTime )
		self.crushUpdate = false
	else
		self.crushTicks = math.max( self.crushTicks - 1, 0 ) 
	end
	
	if self.crushTicks >= self.crushTickTime then
		return true
	else
		return false
	end
	
end

function selectRaidTarget( self, targetCharacter, closestVisibleCrop )
	
	local prioritizeCharacterDistance = 3.0
	local deaggroDistance = 34.0
	local aggroDistance = 30.0

	-- Raiders prioritize targeting crops over distant players
	local closeToCharacter = false
	local inAggroDistance = false
	local overDeaggroDistance = true
	if targetCharacter then
		closeToCharacter = ( targetCharacter and ( targetCharacter.worldPosition - self.unit.character.worldPosition ):length() <= prioritizeCharacterDistance )
		inAggroDistance = ( targetCharacter and ( targetCharacter.worldPosition - self.homePosition ):length() <= aggroDistance )
		overDeaggroDistance = ( targetCharacter and ( targetCharacter.worldPosition - self.homePosition ):length() >= deaggroDistance )
	end
	local characterIsWithinAggroRange = inAggroDistance or ( self.target == targetCharacter and not overDeaggroDistance )
	if ( closeToCharacter or closestVisibleCrop == nil ) and characterIsWithinAggroRange then
		self.target = targetCharacter
	else
		self.target = closestVisibleCrop
	end
	
end

function FindNearbyEdible( character, edibleUuid, searchRadius, reach )
	local closestShape = nil
	local closestDistance = nil
	local contactResults = sm.physics.getSphereContacts(character.worldPosition, searchRadius )
	local bodies = contactResults["bodies"]
	for _, body in ipairs( bodies )do
		for _, shape in ipairs( body:getShapes() )do
			if shape:getShapeUuid() == edibleUuid then
				local distanceToShape = ( shape.worldPosition - character.worldPosition ):length()
				if not closestDistance then
					closestDistance = distanceToShape
					closestShape = shape
				else
					if distanceToShape < closestDistance then
						closestDistance = distanceToShape
						closestShape = shape
					end
				end
			end
		end
	end
	
	if closestShape and sm.exists( closestShape ) then
		return closestShape, closestDistance <= reach
	end
	return nil, false
end