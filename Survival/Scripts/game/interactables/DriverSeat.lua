-- Seat.lua --
dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_shapes.lua")
dofile("$SURVIVAL_DATA/Scripts/game/interactables/Seat.lua")

DriverSeat = class( Seat )
DriverSeat.maxChildCount = 20
DriverSeat.connectionOutput = sm.interactable.connectionType.seated + sm.interactable.connectionType.power + sm.interactable.connectionType.bearing
DriverSeat.colorNormal = sm.color.new( 0x80ff00ff )
DriverSeat.colorHighlight = sm.color.new( 0xb4ff68ff )
DriverSeat.guiSpeedAngle = math.rad( 27 )

DriverSeat.Levels = {
	[tostring(obj_scrap_driverseat)] = { maxConnections = 4 },
	[tostring(obj_interactive_driverseat_01)] = { maxConnections = 6, allowAdjustingJoints = false, upgrade = obj_interactive_driverseat_02, cost = 1, title = "LEVEL 1" },
	[tostring(obj_interactive_driverseat_02)] = { maxConnections = 8, allowAdjustingJoints = false, upgrade = obj_interactive_driverseat_03, cost = 2, title = "LEVEL 2" },
	[tostring(obj_interactive_driverseat_03)] = { maxConnections = 12, allowAdjustingJoints = false, upgrade = obj_interactive_driverseat_04, cost = 3, title = "LEVEL 3" },
	[tostring(obj_interactive_driverseat_04)] = { maxConnections = 16, allowAdjustingJoints = false, upgrade = obj_interactive_driverseat_05, cost = 5, title = "LEVEL 4" },
	[tostring(obj_interactive_driverseat_05)] = { maxConnections = 20, allowAdjustingJoints = true, title = "LEVEL 5" },
}

function DriverSeat.server_onCreate( self )
    Seat:server_onCreate( self )
end

function DriverSeat.server_onFixedUpdate( self )
    Seat.server_onFixedUpdate( self )
    if self.interactable:isActive() then
        self.interactable:setPower( self.interactable:getSteeringPower() )
    else
        self.interactable:setPower( 0 )
        self.interactable:setSteeringFlag( 0 )
    end
end

function DriverSeat.sv_n_setBearingData( self, data, player )

	assert( data.joint )
	
	if data.leftAngle then
		self.interactable:setSteeringJointLeftAngleLimit( data.joint, data.leftAngle )
	end
	
	if data.rightAngle then
		self.interactable:setSteeringJointRightAngleLimit( data.joint, data.rightAngle )
	end
	
	if data.leftSpeed then
		self.interactable:setSteeringJointLeftAngleSpeed( data.joint, data.leftSpeed )
	end
	
	if data.rightSpeed then
		self.interactable:setSteeringJointRightAngleSpeed( data.joint, data.rightSpeed )
	end
	
	if data.unlocked ~= nil then
		self.interactable:setSteeringJointUnlocked( data.joint, data.unlocked )
	end
	
	data.player = player
	self.network:sendToClients( "cl_n_onBearingDataUpdated", data )
end

function DriverSeat.client_canInteractThroughJoint( self )
	local level = self.Levels[tostring( self.shape:getShapeUuid() )]

	return level.allowAdjustingJoints
end

function DriverSeat.client_onInteractThroughJoint( self, character, state, joint )
	local level = self.Levels[tostring( self.shape:getShapeUuid() )]
	
    if level.allowAdjustingJoints then
		self.bearingGui = sm.gui.createSteeringBearingGui()
		self.bearingGui:open()
		self.bearingGui:setOnCloseCallback( "cl_onGuiClosed" )
		
		self.currentJoint = joint
		
		self.bearingGui:setSliderCallback("LeftAngle", "cl_onLeftAngleChanged")
		self.bearingGui:setSliderData("LeftAngle", 120, self.interactable:getSteeringJointLeftAngleLimit( joint ) - 1 )
		
		self.bearingGui:setSliderCallback("RightAngle", "cl_onRightAngleChanged")
		self.bearingGui:setSliderData("RightAngle", 120, self.interactable:getSteeringJointRightAngleLimit( joint ) - 1 )
		
		local leftSpeedValue = self.interactable:getSteeringJointLeftAngleSpeed( joint ) * self.guiSpeedAngle
		local rightSpeedValue = self.interactable:getSteeringJointRightAngleSpeed( joint ) * self.guiSpeedAngle
		
		self.bearingGui:setSliderCallback("LeftSpeed", "cl_onLeftSpeedChanged")
		self.bearingGui:setSliderData("LeftSpeed", 10, leftSpeedValue - 1)
		
		self.bearingGui:setSliderCallback("RightSpeed", "cl_onRightSpeedChanged")
		self.bearingGui:setSliderData("RightSpeed", 10, rightSpeedValue - 1)
		
		local unlocked = self.interactable:getSteeringJointUnlocked( joint )
		
		if unlocked then
			self.bearingGui:setButtonState( "Off", true )
		else
			self.bearingGui:setButtonState( "On", true )
		end
		
		self.bearingGui:setButtonCallback( "On", "cl_onLockButtonClicked" )
		self.bearingGui:setButtonCallback( "Off", "cl_onLockButtonClicked" )

        print("Character "..character:getId().." interacted with joint "..joint:getId())
    else
        print("Joint settings only allowed on level 5!")
    end
end

function DriverSeat.client_onAction( self, controllerAction, state )
    if state == true then
        if controllerAction == sm.interactable.actions.forward then
            self.interactable:setSteeringFlag( sm.interactable.steering.forward )
        elseif controllerAction == sm.interactable.actions.backward then
            self.interactable:setSteeringFlag( sm.interactable.steering.backward )
        elseif controllerAction == sm.interactable.actions.left then
            self.interactable:setSteeringFlag( sm.interactable.steering.left )
        elseif controllerAction == sm.interactable.actions.right then
            self.interactable:setSteeringFlag( sm.interactable.steering.right )
        else
            return Seat.client_onAction( self, controllerAction, state )
        end
    else
        if controllerAction == sm.interactable.actions.forward then
            self.interactable:unsetSteeringFlag( sm.interactable.steering.forward )
        elseif controllerAction == sm.interactable.actions.backward then
            self.interactable:unsetSteeringFlag( sm.interactable.steering.backward )
        elseif controllerAction == sm.interactable.actions.left then
            self.interactable:unsetSteeringFlag( sm.interactable.steering.left )
        elseif controllerAction == sm.interactable.actions.right then
            self.interactable:unsetSteeringFlag( sm.interactable.steering.right )
        else
            return Seat.client_onAction( self, controllerAction, state )
        end
    end
    return true
end

function DriverSeat.client_getAvailableChildConnectionCount( self, connectionType )
	
	local level = self.Levels[tostring( self.shape:getShapeUuid() )]
	assert( level )

	local filter = sm.interactable.connectionType.seated + sm.interactable.connectionType.bearing + sm.interactable.connectionType.power
	local currentConnectionCount = #self.interactable:getChildren( filter )

	if bit.band( connectionType, filter ) then
		local availableChildCount = level.maxConnections or 255
		return availableChildCount - currentConnectionCount
	end
	return 0
end

function DriverSeat.client_onCreate( self )
    Seat.client_onCreate( self )
    self.animWeight = 0.5
    self.interactable:setAnimEnabled("j_ratt", true)
	
	self.updateDelay = 0.0
	self.updateData = {}
end

function DriverSeat.client_onUpdate( self, dt )
    Seat.client_onUpdate( self, dt )

    local steeringAngle = self.interactable:getSteeringAngle();
    local angle = self.animWeight * 2.0 - 1.0 -- Convert anim weight 0,1 to angle -1,1
    
    if angle < steeringAngle then
        angle = min( angle + 4.2441*dt, steeringAngle )
    elseif angle > steeringAngle then
        angle = max( angle - 4.2441*dt, steeringAngle )
    end

    self.animWeight = angle * 0.5 + 0.5; -- Convert back to 0,1
    self.interactable:setAnimProgress("j_ratt", self.animWeight)
	
	if self.updateDelay > 0.0 then
		self.updateDelay = math.max( 0.0, self.updateDelay - dt )
		
		if self.updateDelay == 0 then
			self.network:sendToServer("sv_n_setBearingData", self.updateData )
			self.updateData = {}
		end
	end
end

function DriverSeat.cl_onLeftAngleChanged( self, sliderName, sliderPos )
	self.updateData.joint = self.currentJoint
	self.updateData.leftAngle = sliderPos + 1
	self.updateDelay = 0.1
end

function DriverSeat.cl_onRightAngleChanged( self, sliderName, sliderPos )
	self.updateData.joint = self.currentJoint
	self.updateData.rightAngle = sliderPos + 1
	self.updateDelay = 0.1
end

function DriverSeat.cl_onLeftSpeedChanged( self, sliderName, sliderPos )
	self.updateData.joint = self.currentJoint
	self.updateData.leftSpeed = (1 + sliderPos) / self.guiSpeedAngle
	self.updateDelay = 0.1
end

function DriverSeat.cl_onRightSpeedChanged( self, sliderName, sliderPos )
	self.updateData.joint = self.currentJoint
	self.updateData.rightSpeed = (1 + sliderPos) / self.guiSpeedAngle
	self.updateDelay = 0.1
end

function DriverSeat.cl_onLockButtonClicked( self, buttonName )
	self.updateData.joint = self.currentJoint
	self.updateData.unlocked = buttonName == "Off"
	self.updateDelay = 0.1
end

function DriverSeat.cl_onGuiClosed( self )
	if self.updateDelay > 0.0 then
		self.network:sendToServer( "sv_n_setBearingData", self.updateData )
		self.updateData = {}
		self.updateDelay = 0.0
	end
end

function DriverSeat.cl_n_onBearingDataUpdated( self, data )
	if self.bearingGui and self.bearingGui:isActive() then
		if data.player ~= sm.localPlayer.getPlayer() then
			if data.joint == self.currentJoint then
				if data.leftAngle then
					self.bearingGui:setSliderPosition( "LeftAngle", data.leftAngle - 1 )
				end
				
				if data.rightAngle then
					self.bearingGui:setSliderPosition( "RightAngle", data.rightAngle - 1 )
				end
				
				if data.leftSpeed then
					self.bearingGui:setSliderPosition( "LeftSpeed", ( data.leftSpeed * self.guiSpeedAngle ) - 1 )
				end
				
				if data.rightSpeed then
					self.bearingGui:setSliderPosition( "RightSpeed", ( data.rightSpeed * self.guiSpeedAngle ) - 1 )
				end
				
				if data.unlocked ~= nil then
					if data.unlocked then
						self.bearingGui:setButtonState( "Off", true )
					else
						self.bearingGui:setButtonState( "On", true )
					end
				end
			end
		end
	end
end

DriverSaddle = class( DriverSeat )
DriverSaddle.Levels = {
	[tostring(obj_interactive_driversaddle_01)] = { maxConnections = 6, allowAdjustingJoints = false, upgrade = obj_interactive_driversaddle_02, cost = 1, title = "LEVEL 1" },
	[tostring(obj_interactive_driversaddle_02)] = { maxConnections = 8, allowAdjustingJoints = false, upgrade = obj_interactive_driversaddle_03, cost = 2, title = "LEVEL 2" },
	[tostring(obj_interactive_driversaddle_03)] = { maxConnections = 12, allowAdjustingJoints = false, upgrade = obj_interactive_driversaddle_04, cost = 3, title = "LEVEL 3" },
	[tostring(obj_interactive_driversaddle_04)] = { maxConnections = 16, allowAdjustingJoints = false, upgrade = obj_interactive_driversaddle_05, cost = 5, title = "LEVEL 4" },
	[tostring(obj_interactive_driversaddle_05)] = { maxConnections = 20, allowAdjustingJoints = true, title = "LEVEL 5" },
}