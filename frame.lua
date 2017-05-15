module 'rosterfilter'

local gui = require 'rosterfilter.gui'


function LOAD()
	for i = 1, getn(tab_info) do
		tabs:create_tab(tab_info[i].name)
	end
end

do
    local frame = CreateFrame('Frame', 'RosterFilterFrame', UIParent)
    gui.set_window_style(frame)
    gui.set_size(frame, 750, 400)
    frame:SetPoint('LEFT', 750, 0)
    frame:SetToplevel(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag('LeftButton')
	frame:SetScript('OnMouseDown', function() if IsControlKeyDown() then this:StartSizing(); end end)
	frame:SetScript('OnMouseUp', function() this:StopMovingOrSizing(); end)
	frame:SetScript('OnDragStart', function() this:StartMoving() end)
	frame:SetScript('OnDragStop', function() this:StopMovingOrSizing() end)
	frame:SetScript('OnShow', function() PlaySound('igMainMenuOpen') end)
	frame:SetScript('OnHide', function() PlaySound('igMainMenuClose'); end)
	frame.content = CreateFrame('Frame', nil, frame)
	frame.content:SetAllPoints()
	frame:Hide()
	M.RosterFilterFrame = frame
end

do
	tabs = gui.tabs(RosterFilterFrame, 'DOWN')
	tabs._on_select = on_tab_click
	function M.set_tab(id) tabs:select(id) end
end

do
	local frame = CreateFrame('Frame', nil, RosterFilterFrame)
	gui.set_size(frame, 10, 10)
	frame:SetPoint('BOTTOMRIGHT', RosterFilterFrame, 'BOTTOMRIGHT')
	frame:SetScript('OnMouseDown', function() RosterFilterFrame:StartSizing(); end)
	frame:SetScript('OnMouseUp', function() RosterFilterFrame:StopMovingOrSizing(); end)
end
