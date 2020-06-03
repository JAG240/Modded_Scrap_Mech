-- OilGeyser.lua --
dofile "$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua"

OilGeyser = class( nil )

function OilGeyser.client_onInteract( self, state )
	self.network:sendToServer( "sv_n_harvest" )
end

function OilGeyser.server_onRemoved( self, player )
	self:sv_n_harvest( nil, player )
end

function OilGeyser.client_onCreate( self )
	self.cl = {}
	self.cl.acitveGeyser = sm.effect.createEffect( "Oilgeyser - OilgeyserLoop" )
	self.cl.acitveGeyser:setPosition( self.harvestable.worldPosition )
	self.cl.acitveGeyser:setRotation( self.harvestable.worldRotation )
	self.cl.acitveGeyser:start()
end

function OilGeyser.cl_n_onInventoryFull( self )
	sm.gui.displayAlertText( "#{INFO_INVENTORY_FULL}", 4 )
end

function OilGeyser.sv_n_harvest( self, params, player )
	if not self.harvested and sm.exists( self.harvestable ) then
		local container = player:getInventory()
		if sm.container.beginTransaction() then
			sm.container.collect( container, obj_resource_crudeoil, math.random(3,5))
			if sm.container.endTransaction() then
				sm.effect.playEffect( 	"Oilgeyser - Picked", self.harvestable.worldPosition )
				sm.harvestable.create( hvs_farmables_growing_oilgeyser, self.harvestable.worldPosition, self.harvestable.worldRotation )
				sm.harvestable.destroy( self.harvestable )
				self.harvested = true
			else
				self.network:sendToClient( player, "cl_n_onInventoryFull" )
			end
		end
	end
end

function OilGeyser.client_onDestroy( self )
	self.cl.acitveGeyser:stop()
	self.cl.acitveGeyser:destroy()
end
