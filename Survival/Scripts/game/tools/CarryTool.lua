dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

CarryTool = class( nil )

local scrapwoodRenderables = {
	"$SURVIVAL_DATA/Character/Char_Tools/Char_item/char_item_scrapwood.rend"
}

local stoneRenderables = {
	"$SURVIVAL_DATA/Character/Char_Tools/Char_item/char_item_stone.rend"
}

local scrapmetalRenderables = {
	"$SURVIVAL_DATA/Character/Char_Tools/Char_item/char_item_scrapmetal.rend"
}

local woodRenderables = {
	"$SURVIVAL_DATA/Character/Char_Tools/Char_item/char_item_wood.rend"
}

local metalRenderables = {
	"$SURVIVAL_DATA/Character/Char_Tools/Char_item/char_item_metal.rend"
}

local harvestItems =
{
	obj_harvest_wood,
	obj_harvest_wood2,
	obj_harvest_metal,
	obj_harvest_metal2,
	obj_harvest_stone
}

local heavyRenderables = {
	"$SURVIVAL_DATA/Character/Char_Tools/char_heavytool/char_heavytool.rend"
}

local wormRenderables = {
	"$SURVIVAL_DATA/Character/Char_Tools/Char_toolgorp/char_toolgorp.rend"
}

local renderablesItemTp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_item.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_item/char_item_tp_animlist.rend" }
local renderablesItemFp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_item.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_item/char_item_fp_animlist.rend" }

local renderablesHeavyTp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_heavytool.rend", "$SURVIVAL_DATA/Character/Char_Tools/char_heavytool/char_heavytool_tp_animlist.rend" }
local renderablesHeavyFp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_heavytool.rend", "$SURVIVAL_DATA/Character/Char_Tools/char_heavytool/char_heavytool_fp_animlist.rend" }

local renderablesWormTp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_toolgorp.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_toolgorp/char_toolgorp_tp.rend" }
local renderablesWormFp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_toolgorp.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_toolgorp/char_toolgorp_fp.rend" }


CarryTool.emptyTpRenderables = {}
CarryTool.emptyFpRenderables = {}

sm.tool.preloadRenderables( scrapwoodRenderables )
sm.tool.preloadRenderables( stoneRenderables )
sm.tool.preloadRenderables( scrapmetalRenderables )
sm.tool.preloadRenderables( woodRenderables )
sm.tool.preloadRenderables( metalRenderables )
sm.tool.preloadRenderables( heavyRenderables )
sm.tool.preloadRenderables( wormRenderables )
sm.tool.preloadRenderables( renderablesItemTp )
sm.tool.preloadRenderables( renderablesItemFp )
sm.tool.preloadRenderables( renderablesHeavyTp )
sm.tool.preloadRenderables( renderablesHeavyFp )
sm.tool.preloadRenderables( renderablesWormTp )
sm.tool.preloadRenderables( renderablesWormFp )

function CarryTool.client_onCreate( self )
	self:client_onRefresh()
end

function CarryTool.client_onRefresh( self )
	if self.tool:isLocal() then
		self.activeItem = nil
		self.wasOnGround = true
	end
	self:cl_updateCarryRenderables( nil )
	self:cl_loadAnimations( nil )
end

function CarryTool.cl_loadAnimations( self, activeUid )

	if isAnyOf( activeUid, harvestItems ) then
		self.tpAnimations = createTpAnimations(
			self.tool,
			{
				idle = { "item_idle", { looping = true } },
				sprint = { "item_sprint_idle" },
				pickup = { "item_pickup", { nextAnimation = "idle" } },
				putdown = { "item_putdown" }

			}
		)
		local movementAnimations = {

			idle = "item_idle",

			runFwd = "item_run",
			runBwd = "item_runbwd",

			sprint = "item_sprint_idle",

			jump = "item_jump",
			jumpUp = "item_jump_up",
			jumpDown = "item_jump_down",

			land = "item_jump_land",
			landFwd = "item_jump_land_fwd",
			landBwd = "item_jump_land_bwd",

			crouchIdle = "item_crouch_idle",
			crouchFwd = "item_crouch_run",
			crouchBwd = "item_crouch_runbwd"
		}

		for name, animation in pairs( movementAnimations ) do
			self.tool:setMovementAnimation( name, animation )
		end

		if self.tool:isLocal() then
			self.fpAnimations = createFpAnimations(
				self.tool,
				{
					idle = { "item_idle", { looping = true } },

					sprintInto = { "item_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
					sprintIdle = { "item_sprint_idle", { looping = true } },
					sprintExit = { "item_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },

					equip = { "item_pickup", { nextAnimation = "idle" } },
					unequip = { "item_putdown" }
				}
			)
		end
		setTpAnimation( self.tpAnimations, "idle", 5.0 )
		self.blendTime = 0.2
	elseif activeUid == obj_character_worm then
		self.tpAnimations = createTpAnimations(
			self.tool,
			{
				idle = { "toolgorp_idle", { looping = true } },
				sprint = { "toolgorp_sprint" },
				pickup = { "toolgorp_pickup", { nextAnimation = "idle" } },
				putdown = { "toolgorp_putdown" }

			}
		)
		local movementAnimations = {

			idle = "toolgorp_idle",

			runFwd = "toolgorp_run_fwd",
			runBwd = "toolgorp_run_bwd",

			sprint = "toolgorp_sprint",

			jump = "toolgorp_jump",
			jumpUp = "toolgorp_jump_up",
			jumpDown = "toolgorp_jump_down",

			land = "toolgorp_jump_land",
			landFwd = "toolgorp_jump_land_fwd",
			landBwd = "toolgorp_jump_land_bwd",

			crouchIdle = "toolgorp_crouch_idle",
			crouchFwd = "toolgorp_crouch_fwd",
			crouchBwd = "toolgorp_crouch_bwd",

			swimIdle = "toolgorp_swim_idle",
			swimFwd = "toolgorp_swim_fwd",
			swimBwd = "toolgorp_swim_bwd"
		}

		for name, animation in pairs( movementAnimations ) do
			self.tool:setMovementAnimation( name, animation )
		end

		if self.tool:isLocal() then
			self.fpAnimations = createFpAnimations(
				self.tool,
				{
					idle = { "toolgorp_idle", { looping = true } },

					sprintInto = { "toolgorp_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
					sprintIdle = { "toolgorp_sprint_idle", { looping = true } },
					sprintExit = { "toolgorp_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },

					jump = { "toolgorp_jump", { nextAnimation = "idle" } },
					land = { "toolgorp_jump_land", { nextAnimation = "idle" } },

					equip = { "toolgorp_pickup", { nextAnimation = "idle" } },
					unequip = { "toolgorp_putdown" }
				}
			)
		end
		setTpAnimation( self.tpAnimations, "idle", 5.0 )
		self.blendTime = 0.2
	else
		self.tpAnimations = createTpAnimations(
			self.tool,
			{
				idle = { "heavytool_idle", { looping = true } },
				sprint = { "heavytool_sprint_idle" },
				pickup = { "heavytool_pickup", { nextAnimation = "idle" } },
				putdown = { "heavytool_putdown" }

			}
		)
		local movementAnimations = {

			idle = "heavytool_idle",

			runFwd = "heavytool_run",
			runBwd = "heavytool_runbwd",

			sprint = "heavytool_sprint_idle",

			jump = "heavytool_jump",
			jumpUp = "heavytool_jump_up",
			jumpDown = "heavytool_jump_down",

			land = "heavytool_jump_land",
			landFwd = "heavytool_jump_land_fwd",
			landBwd = "heavytool_jump_land_bwd",

			crouchIdle = "heavytool_crouch_idle",
			crouchFwd = "heavytool_crouch_run",
			crouchBwd = "heavytool_crouch_runbwd"
		}

		for name, animation in pairs( movementAnimations ) do
			self.tool:setMovementAnimation( name, animation )
		end

		if self.tool:isLocal() then
			self.fpAnimations = createFpAnimations(
				self.tool,
				{
					idle = { "heavytool_idle", { looping = true } },

					sprintInto = { "heavytool_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
					sprintIdle = { "heavytool_sprint_idle", { looping = true } },
					sprintExit = { "heavytool_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },

					equip = { "heavytool_pickup", { nextAnimation = "idle" } },
					unequip = { "heavytool_putdown" }
				}
			)
		end
		setTpAnimation( self.tpAnimations, "idle", 5.0 )
		self.blendTime = 0.2
	end
end

function CarryTool.client_onUpdate( self, dt )

	--local isOnGround =  self.tool:isOnGround()

	if self.tool:isLocal() then
		if self.equipped then
			if self.tool:isSprinting() and self.fpAnimations.currentAnimation ~= "sprintInto" and self.fpAnimations.currentAnimation ~= "sprintIdle" then
				swapFpAnimation( self.fpAnimations, "sprintExit", "sprintInto", 0.0 )
			elseif not self.tool:isSprinting() and ( self.fpAnimations.currentAnimation == "sprintIdle" or self.fpAnimations.currentAnimation == "sprintInto" ) then
				swapFpAnimation( self.fpAnimations, "sprintInto", "sprintExit", 0.0 )
			end

			-- if not isOnGround and self.wasOnGround and self.fpAnimations.currentAnimation ~= "jump" then
			-- 	swapFpAnimation( self.fpAnimations, "land", "jump", 0.2 )
			-- elseif isOnGround and not self.wasOnGround and self.fpAnimations.currentAnimation ~= "land" then
			-- 	swapFpAnimation( self.fpAnimations, "jump", "land", 0.2 )
			-- end
		end
		updateFpAnimations( self.fpAnimations, self.equipped, dt )

		--self.wasOnGround = isOnGround
	end

	if not self.equipped then
		if self.wantEquipped then
			self.wantEquipped = false
			self.equipped = true
		end
		return
	end

	if self.tool:isLocal() then
		local carryContainer = sm.localPlayer.getCarry()
		local activeItem = carryContainer:getItem( 0 ).uuid
		if self.activeItem ~= activeItem then
			self.activeItem = activeItem
			self.network:sendToServer( "sv_n_updateCarryRenderables", activeItem )
		end
	end

	local crouchWeight = self.tool:isCrouching() and 1.0 or 0.0
	local normalWeight = 1.0 - crouchWeight
	local totalWeight = 0.0

	for name, animation in pairs( self.tpAnimations.animations ) do
		animation.time = animation.time + dt

		if name == self.tpAnimations.currentAnimation then
			animation.weight = math.min( animation.weight + ( self.tpAnimations.blendSpeed * dt ), 1.0 )

			if animation.time >= animation.info.duration - self.blendTime then
				if ( name == "use" or name == "useempty" ) then
					setTpAnimation( self.tpAnimations, "idle", 10.0 )
				elseif name == "pickup" then
					setTpAnimation( self.tpAnimations, "idle", 0.001 )
				elseif animation.nextAnimation ~= "" then
					setTpAnimation( self.tpAnimations, animation.nextAnimation, 0.001 )
				end

			end
		else
			animation.weight = math.max( animation.weight - ( self.tpAnimations.blendSpeed * dt ), 0.0 )
		end

		totalWeight = totalWeight + animation.weight
	end


	totalWeight = totalWeight == 0 and 1.0 or totalWeight
	for name, animation in pairs( self.tpAnimations.animations ) do

		local weight = animation.weight / totalWeight
		if name == "idle" then
			self.tool:updateMovementAnimation( animation.time, weight )
		elseif animation.crouch then
			self.tool:updateAnimation( animation.info.name, animation.time, weight * normalWeight )
			self.tool:updateAnimation( animation.crouch.name, animation.time, weight * crouchWeight )
		else
			self.tool:updateAnimation( animation.info.name, animation.time, weight )
		end
	end
end

function CarryTool.client_onToggle( self )
	return false
end

function CarryTool.client_onEquip( self )

	if self.tool:isLocal() then
		self.tool:setBlockSprint( true )
		local carryContainer = sm.localPlayer.getCarry()
		local activeItem = carryContainer:getItem( 0 ).uuid
		self.activeItem = activeItem
		self.network:sendToServer( "sv_n_updateCarryRenderables", activeItem )
		if activeItem == obj_character_worm then
			sm.effect.playEffect( "Glowgorp - Pickup", self.tool:getOwner().character.worldPosition )
		end
	end

	self:cl_updateCarryRenderables( self.activeItem )
	self:cl_loadAnimations( self.activeItem )

	self.wantEquipped = true

	setTpAnimation( self.tpAnimations, "pickup", 0.0001 )
	if self.tool:isLocal() then
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end

end

function CarryTool.sv_n_updateCarryRenderables( self, activeUid, player )
	self.network:sendToClients( "cl_n_updateActiveCarry", { activeUid = activeUid, player = player } )
end

function CarryTool.cl_n_updateActiveCarry( self, params )
	if params.player ~= sm.localPlayer.getPlayer() then
		self:cl_updateCarryRenderables( params.activeUid )
		self:cl_loadAnimations( params.activeUid )
	end
end

function CarryTool.cl_updateCarryRenderables( self, activeUid )

	local carryRenderables = {}
	local animationRenderablesTp = {}
	local animationRenderablesFp = {}

	if activeUid == sm.uuid.getNil() or activeUid == nil then
		animationRenderablesTp = self.emptyTpRenderables
		animationRenderablesFp = self.emptyFpRenderables
		self.emptyTpRenderables = {}
		self.emptyFpRenderables = {}
	elseif activeUid == obj_harvest_wood then
		carryRenderables = scrapwoodRenderables
		animationRenderablesTp = renderablesItemTp
		animationRenderablesFp = renderablesItemFp
	elseif activeUid == obj_harvest_metal then
		carryRenderables = scrapmetalRenderables
		animationRenderablesTp = renderablesItemTp
		animationRenderablesFp = renderablesItemFp
	elseif activeUid == obj_harvest_stone then
		carryRenderables = stoneRenderables
		animationRenderablesTp = renderablesItemTp
		animationRenderablesFp = renderablesItemFp
	elseif  activeUid == obj_harvest_wood2 then
		carryRenderables = woodRenderables
		animationRenderablesTp = renderablesItemTp
		animationRenderablesFp = renderablesItemFp
	elseif  activeUid == obj_harvest_metal2 then
		carryRenderables = metalRenderables
		animationRenderablesTp = renderablesItemTp
		animationRenderablesFp = renderablesItemFp
	elseif activeUid == obj_character_worm then
		carryRenderables = wormRenderables
		animationRenderablesTp = renderablesWormTp
		animationRenderablesFp = renderablesWormFp
	else
		carryRenderables = heavyRenderables
		animationRenderablesTp = renderablesHeavyTp
		animationRenderablesFp = renderablesHeavyFp
	end

	local currentRenderablesTp = {}
	local currentRenderablesFp = {}

	for k,v in pairs( animationRenderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( animationRenderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end

	self.emptyTpRenderables = shallowcopy( animationRenderablesTp )
	self.emptyFpRenderables = shallowcopy( animationRenderablesFp )

	for k,v in pairs( carryRenderables ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( carryRenderables ) do currentRenderablesFp[#currentRenderablesFp+1] = v end

	self.tool:setTpRenderables( currentRenderablesTp )
	if self.tool:isLocal() then
		self.tool:setFpRenderables( currentRenderablesFp )
	end

end

function CarryTool.client_onUnequip( self )

	if self.tool:isLocal() then
		self:cl_updateCarryRenderables( nil )

		self.tool:setBlockSprint( false )
		local carryContainer = sm.localPlayer.getCarry()
		local activeItem = carryContainer:getItem( 0 ).uuid
		self.activeItem = activeItem
		self.network:sendToServer( "sv_n_updateCarryRenderables", activeItem )
	end

	self.wantEquipped = false
	self.equipped = false
	setTpAnimation( self.tpAnimations, "putdown" )
	if self.tool:isLocal() and self.fpAnimations.currentAnimation ~= "unequip" then
		swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
	end

end

function CarryTool.client_onEquippedUpdate( self, primaryState, secondaryState )

	local playerCarry = sm.localPlayer.getCarry()
	local carryUuid = sm.container.itemUuid( playerCarry )[1]
	local characterShape = sm.item.getCharacterShape( carryUuid )
	local isHarvest = sm.shape.getIsHarvest( carryUuid )

	if isHarvest and secondaryState ~= sm.tool.interactState.start then
		local aimRange = 7.5
		local success, result = sm.localPlayer.getRaycast( aimRange )
		if result.type == "body" then
			local shape = result:getShape()
			local shapeContainer = nil
			if shape:getShapeUuid() == obj_craftbot_refinery then
				shapeContainer = shape.interactable:getContainer( 1 )
			elseif shape:getShapeUuid() == obj_craftbot_resourcecontainer then
				shapeContainer = shape.interactable:getContainer( 0 )
			end
			if shapeContainer then
				if sm.container.canCollect( shapeContainer, carryUuid, 1 ) then
					sm.gui.setCenterIcon( "Use" )
					local keyBindingText =  sm.gui.getKeyBinding( "Create" )
					sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_INSERT}" )

					if primaryState == sm.tool.interactState.start then
						local character = self.tool:getOwner().character
						local fromPosition = character:getTpBonePos( "jnt_right_weapon" )
						local fromRotation = character:getTpBoneRot( "jnt_right_weapon" )
						local params = { containerA = playerCarry, itemA = carryUuid, quantityA = 1, targetShape = shape, fromPosition = fromPosition, fromRotation = fromRotation  }
						self.network:sendToServer( "sv_n_sendItem", params )
					end
					return true, true
				end
			end
		end
	elseif ( primaryState == sm.tool.interactState.start and characterShape ) or secondaryState == sm.tool.interactState.start then
		local dropRange = 7.5
		local success, result = sm.localPlayer.getRaycast( dropRange )

		local fraction = 1
		if success then
			fraction = result.fraction
		end

		local aimPosition = sm.localPlayer.getRaycastStart() + sm.localPlayer.getDirection() * dropRange * fraction
		local camUp = sm.camera.getUp()
		local camRight = sm.camera.getRight()
		local camDirection = sm.camera.getDirection()

		local params = { containerA = playerCarry, itemA = carryUuid, quantityA = 1, aimPosition = aimPosition, camUp = camUp, camRight = camRight, camDirection = camDirection, raycastNormal = result.normalWorld }
		if characterShape then
			params.characterShape = characterShape
			if primaryState == sm.tool.interactState.start then
				params.checkCollision = true
			end
		end

		self.network:sendToServer( "sv_n_dropCarry", params )
		return true, true
	end

	if characterShape then
		return true, true
	end

	return false, false

end

function CarryTool.sv_n_dropCarry( self, params )

	local up = params.camRight
	local forward = params.camUp
	forward.y = 0
	forward = forward:normalize()
	local rotation = sm.quat.lookRotation( forward, up )
	if params.characterShape then

		local offset = params.raycastNormal * params.characterShape.placementSphereRadius
		local spawnPosition = params.aimPosition + offset
		local collision = false
		if params.checkCollision then
			collision = sm.physics.sphereContactCount( spawnPosition, params.characterShape.placementSphereRadius ) > 0
		end
		if not collision then
			if sm.container.beginTransaction() then
				sm.container.spendFromSlot( params.containerA, 0, params.itemA, params.quantityA, true )
				if sm.container.endTransaction() then
					sm.unit.createUnit( sm.uuid.new( params.characterShape.characterUuid ), spawnPosition, math.random()*2*math.pi )
				end
			end
		end
	else
		local shapeOffset = sm.item.getShapeOffset( params.itemA )
		local rotatedOffset = rotation * shapeOffset
		local diagonalLength = math.sqrt( rotatedOffset.x * rotatedOffset.x + rotatedOffset.y * rotatedOffset.y + rotatedOffset.z * rotatedOffset.z )
		local offset = -rotatedOffset + params.raycastNormal * diagonalLength
		local spawnPosition = params.aimPosition + offset
		if sm.container.beginTransaction() then
			sm.container.spendFromSlot( params.containerA, 0, params.itemA, params.quantityA, true )
			if sm.container.endTransaction() then
				local shape = sm.shape.createPart( params.itemA, spawnPosition, rotation, true, true )
				if params.containerA:getSize() > 1 then -- Additional items in carry
					local interactable = shape:getInteractable()
					local container = interactable:getContainer( 0 )
					if container == nil then
						container = interactable:addContainer( 0, params.containerA:getSize() - 1, params.containerA:getMaxStackSize() )
					end
					sm.container.beginTransaction()
					for slot = 2, params.containerA:getSize() do
						local item = params.containerA:getItem( slot - 1 )
						--sm.container.spendFromSlot( params.containerA, slot - 1, item.uuid, item.quantity, true )
						--sm.container.collectToSlot( container, slot - 2, item.uuid, item.quantity, true )
						sm.container.setItem( params.containerA, slot - 1, sm.uuid.getNil(), 0 )
						sm.container.setItem( container, slot - 2, item.uuid, item.quantity, item.instance )
					end
					if not sm.container.endTransaction() then
						sm.log.error("Failed to move carry items!")
					end
				end
			end
		end
	end

end

function CarryTool.sv_n_sendItem( self, params )
	sm.event.sendToInteractable( params.targetShape.interactable, "sv_e_receiveItem", params )
end