
-- Constants:
local guiUpdateEveryTicks = 5
local private = {}
--------------------------------------------------
-- API
--------------------------------------------------

-- Requried:
-- modName - prefix which your ui components have. e.g. "hc.belt-sorter.1.1" (modName = "hc")

-- Usage:
-- each known gui defines these functions:
gui = {} 
-- [$entityName] = { 
--    open = $function(player,entity, gui_type),			-- gui_type = defines.gui_type.entity / custom
--    close = $function(player, gui_type),            -- gui_type = defines.gui_type.entity / custom
--    click = $function(nameArr, player, entity) }

-- Required Calls from control.lua:
-- gui_tick()
-- gui_init()

-- Helper functions:
-- gui_playersWithOpenGuiOf(entity) : {x:LuaPlayer, ...}
-- gui_scheduleEvent($uiComponentIdentifier,$player)

--------------------------------------------------
-- Global data
--------------------------------------------------

-- This helper file uses the following global data variables:
-- global.gui.playerData = { entity = $entity }
--     "      events[$tick] = { {$uiComponentIdentifier, $player}, ... }
--     "      version = $number
--     "      inEvent = $bool                 Used to detect when it should set active entity for player

--------------------------------------------------
-- Implementation
--------------------------------------------------


function gui_init()
	if global.gui == nil then
		global.gui = {
			events = {},
			playerData = {},
			version = 3
		}
	end
	local prevGui = global.gui.version
	if not global.gui.version then
		global.gui.version = 1
		global.itemSelection = nil
	end
	if global.gui.version < 3 then
		global.gui.version = 3
		global.gui.playerData = {}
	end
	if global.gui.version ~= prevGui then
		info("Migrated gui version to "..tostring(global.gui.version))
	end
end

local function handleEvent(uiComponentIdentifier,player)
	local guiEvent = split(uiComponentIdentifier,".")
	local eventIsForMod = table.remove(guiEvent,1)
	if eventIsForMod == modName then
		local entityName = player.opened_gui_type == defines.gui_type.entity and player.opened.name or nil
		if entityName == nil then
			entityName = player.opened_gui_type == defines.gui_type.custom and player.opened.name or nil
		end
		if entityName and gui[entityName] then
			if gui[entityName].click ~= nil then
				local pdata = private.playerData(player.name)
				gui[entityName].click(guiEvent,player,pdata.entity)
			end
		elseif entityName == nil then
			local entityName = table.remove(guiEvent,1)
			if gui[entityName] and gui[entityName].click ~= nil then
				gui[entityName].click(guiEvent,player,nil)
			else
				info("No entityName found for player "..player.name)
			end
		else
			warn("No gui registered for "..entityName)
		end
		return true
	else
		-- gui event might be from other mods
		info("unknown gui event occured: "..serpent.block(uiComponentIdentifier)..". If this component belongs to your mod it should contain \"$modName.\" as the beginning of the component name.")
	end
end

function gui_scheduleEvent(uiComponentIdentifier,player)
	global.gui.events = global.gui.events or {}
	table.insert(global.gui.events,{uiComponentIdentifier=uiComponentIdentifier,player=player})
end


function gui_tick()
	if game.tick % guiUpdateEveryTicks ~= 0 then return end
	if global.gui.events ~= nil then
		local events = global.gui.events
		global.gui.events = nil
		if #events > 0 then
			for _,event in pairs(events) do
				handleEvent(event.uiComponentIdentifier, event.player)
			end
		end
	end
end

function gui_open(event)
	local entity = event.entity
	local player = game.players[event.player_index]
	local pdata = private.playerData(player.name)
	local root = not global.gui.inEvent
	if root then 
		pdata.entity = entity
		global.gui.inEvent = true
	end
	if entity and gui[entity.name] and gui[entity.name].open then
		gui[entity.name].open(player, entity, event.gui_type)
	end
	if root then
		global.gui.inEvent = false
	end
end


function gui_close(event)
	local entity = event.entity
	local player = game.players[event.player_index]
	local pdata = private.playerData(player.name)
	local root = not global.gui.inEvent
	if root then 
		pdata.entity = nil
		global.gui.inEvent = true
	end
	if entity and gui[entity.name] and gui[entity.name].close then
		gui[entity.name].close(player, event.gui_type)
	end
	local element = event.element
	if element and gui[element.name] and gui[element.name].close then
		gui[element.name].close(player, event.gui_type)
	end
	if root then
		global.gui.inEvent = false
	end
end


private.playerData = function(playerName)
	if not global.gui.playerData[playerName] then
		global.gui.playerData[playerName] = {}
	end
	return global.gui.playerData[playerName]
end

--------------------------------------------------
-- Event registration
--------------------------------------------------

local function handleGuiEvent(event)
	local player = game.players[event.player_index]
	local uiComponentIdentifier = event.element.name
	return handleEvent(uiComponentIdentifier,player)
end

script.on_event(defines.events.on_gui_click,handleGuiEvent)
script.on_event(defines.events.on_gui_text_changed,handleGuiEvent)
script.on_event(defines.events.on_gui_elem_changed,handleGuiEvent)
script.on_event(defines.events.on_gui_opened,gui_open)
script.on_event(defines.events.on_gui_closed,gui_close)
--script.on_event(defines.events.on_gui_checked_state_changed,handleGuiEvent)

--------------------------------------------------
-- Helper functions
--------------------------------------------------

function gui_playersWithOpenGuiOf(entity)
	local result = {}
	for _,player in pairs(game.players) do
		if player.connected then
			local openEntity = player.opened
			if openEntity == entity then
				table.insert(result,player)
			end
		end
	end
	return result
end
