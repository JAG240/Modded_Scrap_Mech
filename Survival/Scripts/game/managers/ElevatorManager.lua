dofile( "$SURVIVAL_DATA/Scripts/util.lua" )

ElevatorManager = class( nil )

ELEVATOR_TRAVEL_TICKS = 600
ELEVATOR_MOVEWALLS_TICK = ELEVATOR_TRAVEL_TICKS - 60
ELEVATOR_TRANSFER_TICK = 10

function ElevatorManager.sv_onCreate( self )
	--print( "ElevatorManager.onCreate()" )

	-- Game script managed global elevator table
	self.elevators = sm.storage.load( STORAGE_CHANNEL_ELEVATORS )
	if self.elevators then
		--print( "Loaded elevators:" )
		--print( self.elevators )
	else
		self.elevators = {}
		self:sv_saveElevators()
	end

	self.activeElevators = {}
	self.interactableToElevator = {}
end

local CellTagToWarehouseFloors = { ["WAREHOUSE2"] = 2, ["WAREHOUSE3"] = 3, ["WAREHOUSE4"] = 4 }

function ElevatorManager.sv_loadElevatorsOnCell( self, x, y, cellTags )
	--print("--- passing data to elevators on cell " .. x .. ":" .. y .. " ---")

	local exits = {}
	local nodes = sm.cell.getNodesByTag( x, y, "ELEVATOR_EXIT_HINT" )
	for i,n in ipairs( nodes ) do
		local vector = n.rotation * ( sm.vec3.new( 0, 1, 0 ) * n.scale )
		local x1, y1 = getCell( n.position.x + vector.x, n.position.y + vector.y )
		exits[i] = { x = x1, y = y1 }
	end

	local setParamsOnElevators = function( tags, exits )
		local elevators = sm.cell.getInteractablesByTags( x, y, tags )
		for _,e in ipairs( elevators ) do
			print( "ElevatorCell: "..tags[1].."_"..tags[2].." found!" )
			local maxLevels = 0
			local foundFloorTag = false
			for _, tag in ipairs( cellTags ) do
				if CellTagToWarehouseFloors[tag] then
					maxLevels = CellTagToWarehouseFloors[tag]
					foundFloorTag = true
					break
				end
			end
			assert( tags[2] ~= "ENTRANCE" or #exits > 0, "Elevator on ("..x..", "..y..") does not have an exit hint" )
			--assert( tags[2] ~= "ENTRANCE" or maxLevels ~= 0, "Elevator is not placed on a warehouse tile" )
			if foundFloorTag == false then
				maxLevels = 4
			end

			local params = {
				name = tags[1].."_"..tags[2],
				x = x,
				y = y,
				exits = exits,
				maxLevels = maxLevels,
			}
			e:setParams( params )
		end
	end

	setParamsOnElevators( { "ELEVATOR", "ENTRANCE" }, exits )
	setParamsOnElevators( { "ELEVATOR", "EXIT" } )

end

function ElevatorManager.sv_saveElevators( self )
	sm.storage.save( STORAGE_CHANNEL_ELEVATORS, self.elevators )
	--print( "Saved elevators:" )
	--print( self.elevators )
end

function ElevatorManager.sv_onFixedUpdate( self )
	local save = false
	for _,elevator in pairs( self.activeElevators ) do
		-- Transfer
		if (elevator.ticksToDestination == ELEVATOR_TRANSFER_TICK) or elevator.failsafe then
			if elevator.destination == "b" then
				assert(true)
				--print( "Elevator portal transfer A to B" )
				if not elevator.portal:transferAToB() then
					if elevator.failsafe == false then
						for _,object in ipairs( elevator.portal:getContentsA() ) do
							if type( object ) == "Character" then
								local player = object:getPlayer()
								if player then
									sm.log.info( "Player wants to move to destination B but transfer tick occured to early, enable failsafe" )
									elevator.failsafe = true
									elevator.ticksToDestination = elevator.ticksToDestination + 40
								end
							end
						end
					end
				else
					elevator.failsafe = false
					elevator.ticksToDestination = ELEVATOR_TRANSFER_TICK
				end
			elseif elevator.destination == "a" then
				--print( "Elevator portal transfer B to A" )
				if not elevator.portal:transferBToA() then
					local hasA = elevator.portal:hasOpeningA()
					local hasB = elevator.portal:hasOpeningB()
					--print( "HasA: ", hasA, " - HasB: ", hasB )
				end
			end
			save = true
		end

		-- Open doors
		if elevator.ticksToDestination == 0 then
			if elevator.a and sm.exists( elevator.a ) then
				elevator.a.active = elevator.destination == "a"
				elevator.a:setPower( 0 )
			end
			if elevator.b and sm.exists( elevator.b ) then
				elevator.b.active = elevator.destination == "b"
				elevator.b:setPower( 0 )
			end
		else
			assert( elevator.ticksToDestination > 0 )

			-- Countdown
			elevator.ticksToDestination = elevator.ticksToDestination - 1
			if elevator.ticksToDestination == 0 then
				save = true
			end

			-- Close doors
			if elevator.a and sm.exists( elevator.a ) then
				elevator.a.active = false
				if elevator.ticksToDestination == ELEVATOR_MOVEWALLS_TICK then
					elevator.a:setPower( elevator.destination == "a" and -1 or 1 )
				end
			end
			if elevator.b and sm.exists( elevator.b ) then
				elevator.b.active = false
				if elevator.ticksToDestination == ELEVATOR_MOVEWALLS_TICK then
					elevator.b:setPower( elevator.destination == "b" and 1 or -1 )
				end
			end
		end
	end
	if save then
		self:sv_saveElevators()
	end
end


function ElevatorManager.sv_registerElevator( self, interactable, portal )
	local elevator = self.elevators[portal.id]
	if elevator then
		-- Exists, check if A (load) otherwise, set as B
		assert( elevator.a )
		if elevator.a ~= interactable then
			assert( elevator.b == nil or elevator.b == interactable )
			elevator.b = interactable
		end
	else
		-- Does not exist, create and set as A
		elevator = {}
		elevator.portal = portal
		elevator.destination = "b"
		elevator.ticksToDestination = 0 -- At destination
		elevator.a = interactable
		elevator.failsafe = false
		self.elevators[portal.id] = elevator
	end

	self:sv_saveElevators()
	addToArrayIfNotExists( self.activeElevators, elevator )
	self.interactableToElevator[interactable.id] = elevator
end


function ElevatorManager.sv_removeElevator( self, interactable )
	local elevator = self.interactableToElevator[interactable.id]
	if elevator == nil then
		return
	end

	self.interactableToElevator[interactable.id] = nil
	local remove = true
	for _,e in pairs( self.interactableToElevator ) do
		if e == elevator then
			remove = false
			break
		end
	end
	if remove then
		--print( "Removed elevator from active elevators:" )
		--print( elevator )
		removeFromArray( self.activeElevators, function( value ) return value == elevator; end )
	end
end

function ElevatorManager.sv_getElevatorDestination( self, interactable )
	local elevator = self.interactableToElevator[interactable.id]
	assert( elevator, "Attempt to get an non existing elevator for interactable"..interactable.id )

	return elevator.destination, elevator.ticksToDestination
end

function ElevatorManager.sv_call( self, interactable )
	local elevator = self.interactableToElevator[interactable.id]
	assert( elevator )

	if elevator.ticksToDestination == 0 then -- Not on the move
		print( "Elevator CALL!" )
		if elevator.destination == "b" and interactable == elevator.a then
			elevator.destination = "a"
			elevator.ticksToDestination = ELEVATOR_TRAVEL_TICKS
		elseif elevator.destination == "a" and interactable == elevator.b then
			elevator.destination = "b"
			elevator.ticksToDestination = ELEVATOR_TRAVEL_TICKS
		end
	end
end


function ElevatorManager.sv_go( self, interactable )
	print( "Elevator GO!" )
	local elevator = self.interactableToElevator[interactable.id]
	assert( elevator )

	if elevator.ticksToDestination == 0 then -- Not on the move
		-- A to B
		if elevator.destination == "a" and interactable == elevator.a then
			elevator.destination = "b"
			elevator.ticksToDestination = ELEVATOR_TRAVEL_TICKS
			if elevator.portal:getWorldB() then
				self:sv_prepareCell( elevator.portal:getWorldB(), elevator.portal:getPositionB(), elevator.portal:getContentsA() )
			end
		-- B to A
		elseif elevator.destination == "b" and interactable == elevator.b then
			elevator.destination = "a"
			elevator.ticksToDestination = ELEVATOR_TRAVEL_TICKS
			if elevator.portal:getWorldA() then
				self:sv_prepareCell( elevator.portal:getWorldA(), elevator.portal:getPositionA(), elevator.portal:getContentsB() )
			end
		elseif interactable == elevator.a then
			print( "Elevator is not here. FAILSAFE ACTIVATED!" )
			elevator.portal:transferAToB()
		elseif interactable == elevator.b then
			print( "Elevator is not here. FAILSAFE ACTIVATED!" )
			elevator.portal:transferBToA()
		end
	end
end

function ElevatorManager.sv_prepareCell( self, world, position, contents )
	local params = {}
	params.world = world
	params.cellX = math.floor( position.x / 64 )
	params.cellY = math.floor( position.y / 64 )
	params.players = {}

	for _,object in ipairs( contents ) do
		if type( object ) == "Character" then
			local player = object:getPlayer()
			if player then
				params.players[#params.players + 1] = player
			end
		end
	end

	sm.event.sendToGame( "sv_e_prepareCell", params )
end
