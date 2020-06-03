-- BuilderbotCharacter.lua --

BuilderbotCharacter = class( nil )

local movementEffects = "$CHALLENGE_DATA/Character/Char_builderbot/builderbot_movement_effects.json"

function BuilderbotCharacter.server_onCreate( self ) end

function BuilderbotCharacter.client_onCreate( self )
	print( "-- BuilderbotCharacter created --" )
end

function BuilderbotCharacter.client_onDestroy( self )
	print( "-- BuilderbotCharacter destroyed --" )
end

function BuilderbotCharacter.client_onRefresh( self )
	print( "-- BuilderbotCharacter refreshed --" )
end

function BuilderbotCharacter.client_onGraphicsLoaded( self )
	print("-- BuilderbotCharacter graphics loaded --")
	self.character:setMovementEffects( movementEffects )
	self.graphicsLoaded = true
end

function BuilderbotCharacter.client_onGraphicsUnloaded( self )
	self.graphicsLoaded = false
end

function BuilderbotCharacter.client_onUpdate( self, deltaTime )
	if not self.graphicsLoaded then
		return
	end
	
	local activeAnimations = self.character:getActiveAnimations()
	sm.gui.setCharacterDebugText( self.character, "" ) -- Clear debug text
	if activeAnimations then
		for i, animation in ipairs( activeAnimations ) do
			if animation.name ~= "" and animation.name ~= "spine_turn" then
				local truncatedWeight = math.floor( animation.weight * 10 + 0.5 ) / 10
				sm.gui.setCharacterDebugText( self.character, tostring( animation.name .. " : " .. truncatedWeight ), false ) -- Add debug text without clearing
			end
		end
	end
end

function BuilderbotCharacter.client_onEvent( self, event )
	self:client_handleEvent( event )
end

function BuilderbotCharacter.client_handleEvent( self, event ) end