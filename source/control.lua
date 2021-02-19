local private = {}

-- item to wagon mapping
local activeWagonsMapping = {
		["iron-ore"]=1, ["copper-ore"]=1, ["stone"]=1,
		["wood"]=1, ["coal"]=1, ["steel-plate"]=1, ["stone-brick"]=1,
		["iron-plate"]="plate", ["copper-plate"]="plate",
		["water"]=1, ["crude-oil"]=1, ["petroleum-gas"]=1, ["light-oil"]=1, ["heavy-oil"]=1, ["sulfuric-acid"]=1
}
-- whether wagon with name "wag-...-wagon" may be transformed (all mappings above may be transformed)
local activeWagons = {
	["stuff"]=1, ["closed"]=1, ["plate"]=1
}


script.on_init(private.on_init)
script.on_configuration_changed(private.on_init)

private.on_init = function()
	global = global or {}
	global.version = global.version or 1
	global.monitored = global.monitored or {} -- key = string id of train, value is table of monitored train
	global.schedule = global.schedule or {} -- [tick][nr] = {$trainId} --train table
end


script.on_event(defines.events.on_train_created, function(event)
	if event.old_train_id_1 then
		private.unmonitor(event.old_train_id_1)
	end
	if event.old_train_id_2 then
		private.unmonitor(event.old_train_id_2)
	end
	private.monitor(event.train)
end)


script.on_event(defines.events.on_train_changed_state, function(event)
	local train = event.train
	if train.state == defines.train_state.manual_control then
		if train.speed ~= 0 then
			private.unmonitor(train.id)
		else
			private.monitor(train)
		end
	elseif train.state == defines.train_state.wait_station or train.state == defines.train_state.no_schedule
			or train.state == defines.train_state.no_path then
		private.monitor(train)
	end
end)


script.on_event(defines.events.on_tick, function(event)
	private.on_init() -- TODO: remove after dev
	if global.schedule[game.tick] == nil then
		return
	end
	for _,trainId in pairs(global.schedule[game.tick]) do
		local t = global.monitored[""..trainId]
		if t then
			local train = t.train
			if train.valid then
				private.checkTrain(train)
				if train.valid then
					private.scheduleAdd(train, 30)
				end
			end
		end
	end
	global.schedule[game.tick] = nil
end)

-- Updating trains

private.checkTrain = function(oldTrain)
	local replaced = false
	local train = oldTrain
	local sp = train.speed
	local mode = train.manual_mode
	for _, wagon in pairs(train.cargo_wagons) do
		local content = wagon.get_inventory(defines.inventory.cargo_wagon).get_contents()
		train = private.checkWagon(train, wagon, content, false)
	end
	for _, wagon in pairs(train.fluid_wagons) do
		local content = wagon.get_fluid_contents()
		train = private.checkWagon(train, wagon, content, true)
	end
	if train ~= oldTrain then
		train.speed = sp
		train.manual_mode = mode
	end
end

private.checkWagon = function(train, wagon, content, isFluid)
	if not private.mayTransformWagon(wagon.name) then return train end
	local shouldBe = private.targetWagonForContent(content, isFluid)
	local is = wagon.name
	if is ~= shouldBe then
		local newWagon = private.replaceWagon(wagon, shouldBe)
		private.addCargo(newWagon, content, isFluid)
		return newWagon.train
	end
	return train
end

private.mayTransformWagon = function(name)
	if name == "cargo-wagon" or name == "fluid-wagon" then return true end
	local middle = name:sub(5,-7) -- remove "wag-" prefix and "-wagon" postfix
	return activeWagons[middle] or activeWagonsMapping[middle]
end

private.replaceWagon = function(wagon, shouldBe)
	local pos = wagon.position
	local force = wagon.force
	local surface = wagon.surface
	wagon.destroy()
	return surface.create_entity{name=shouldBe,position=pos, force=force}
end

private.targetWagonForContent = function(content, isFluid)
	local types = 0
	local name = ""
	for key, amount in pairs(content) do
		types = types + 1
		if activeWagonsMapping[key] == 1 then 
			name = "wag-"..key.."-wagon" 
		elseif activeWagonsMapping[key] then
			name = "wag-"..activeWagonsMapping[key].."-wagon"
		end
	end
	if types >= 4 then
		name = "wag-stuff-wagon"
	elseif types >= 2 then
		name = "wag-closed-wagon"
	elseif name == "" then
		name = isFluid and "fluid-wagon" or "cargo-wagon"
	end
	return name
end

private.addCargo = function(wagon, content, isFluid)
	if isFluid then
		for name, amount in pairs(content) do
			wagon.insert_fluid{name=name, amount=amount}
		end
	else
		local inventory = wagon.get_inventory(defines.inventory.cargo_wagon)
		for itemName, amount in pairs(content) do
			inventory.insert{name=itemName, count=amount}
		end
	end
end

--- Monitoring trains

private.monitor = function(train)
	if not global.monitored[""..train.id] then
		global.monitored[""..train.id] = { --- Alexander-max0 Fix it please
			train=train,
		}
		private.scheduleAdd(train)
	end
end

private.unmonitor = function(trainId)
	global.monitored[""..trainId] = nil
end


private.scheduleAdd = function(train, inTicks)
	inTicks = inTicks or 0
	local tick = game.tick + 1 + inTicks
	if train == nil then
		err("scheduleAdd can't be called for nil train")
		return nil
	end
	if global.schedule[tick] == nil then
		global.schedule[tick] = {}
	end
	table.insert(global.schedule[tick], train.id)
end