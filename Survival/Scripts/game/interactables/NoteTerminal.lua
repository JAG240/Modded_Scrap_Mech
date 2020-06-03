-- NoteTerminal.lua --

NoteTerminal = class( nil )
NoteTerminal.maxParentCount = 1
NoteTerminal.maxChildCount = 0
NoteTerminal.colorNormal = sm.color.new( 0xdeadbeef )
NoteTerminal.colorHighlight = sm.color.new( 0xdeadbeef )
NoteTerminal.connectionInput = sm.interactable.connectionType.logic
NoteTerminal.connectionOutput = sm.interactable.connectionType.none

-- Client

function NoteTerminal.client_onCreate( self )
	self:cl_init()
end

function NoteTerminal.client_onRefresh( self )
	self:cl_init()
end

function NoteTerminal.cl_init( self )
	self.pages = {
	"Coming soon"
	}
	self.currentPage = 3
	self.pageTime = 3
	self.currentPageTime = 0.0
	self.reading = false
end

function NoteTerminal.client_canInteract( self )
	local parent = self.interactable:getSingleParent()
	if parent and parent.active then
		sm.gui.setCenterIcon( "Use" )
		local keyBindingText =  sm.gui.getKeyBinding( "Use" )
		sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_USE}" )
	else
		sm.gui.setCenterIcon( "Hit" )
		sm.gui.setInteractionText( "#{INFO_REQUIRES_POWER}" )
		return false
	end
	return true
end

function NoteTerminal.client_onInteract( self, character, state )
	if state == true then
		local parent = self.interactable:getSingleParent()
		if parent and parent.active then
			self:cl_startStory()
		end
	end
end

function NoteTerminal.client_onUpdate( self, deltaTime )
	if self.reading then
		local page = self.pages[self.currentPage]
		if page then
			sm.gui.displayAlertText( page, 3 )
			self.currentPageTime = self.currentPageTime + deltaTime
			if self.currentPageTime > self.pageTime then
				self.currentPage = self.currentPage + 1
				self.currentPageTime = 0.0
			end
		else
			self.reading = false
		end
	end
end

function NoteTerminal.cl_startStory( self )
	if self.reading then
		self.currentPage = 1
		self.currentPageTime = 0.0
	else
		self.reading = true
		self.currentPage = 3
		self.currentPageTime = 0.0
	end
end