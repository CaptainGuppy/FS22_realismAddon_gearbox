-- by modelleicher ( Farming Agency )
-- Inputs for realismAddon_gearbox

realismAddon_gearbox_inputs = {}

function realismAddon_gearbox_inputs.prerequisitesPresent(specializations)
	return true
end

-- Action Event Adding
-- custom function for adding actionEvents since there might be a lot
function realismAddon_gearbox_inputs.onRegisterActionEvents(self, isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self.spec_realismAddon_gearbox_inputs

		-- Update allManualActive here
		spec.allManualActive = realismAddon_gearbox_overrides.checkIsManual(self.spec_motorized.motor)

		-- Clear previous action events
		spec.actionEvents = {}
		self:clearActionEventsTable(spec.actionEvents)

		if isActiveForInputIgnoreSelection and spec.allManualActive then
			-- hand throttle
			self:addRealismAddonActionEvent("PRESSED_OR_AXIS", "RAGB_HANDTHROTTLE_UP", "HANDTHROTTLE_INPUT")
			self:addRealismAddonActionEvent("PRESSED_OR_AXIS", "RAGB_HANDTHROTTLE_DOWN", "HANDTHROTTLE_INPUT")
			self:addRealismAddonActionEvent("PRESSED_OR_AXIS", "RAGB_HANDTHROTTLE_AXIS", "HANDTHROTTLE_INPUT")

			-- gear shift via axis
			self:addRealismAddonActionEvent("PRESSED_OR_AXIS", "RAGB_GEARSHIFT_AXIS", "RAGB_GEARSHIFT_AXIS")

			-- second group set
			self:addRealismAddonActionEvent("BUTTON_SINGLE_ACTION", "RAGB_GROUPSECOND_UP", "GROUPSECOND_INPUT")
			self:addRealismAddonActionEvent("BUTTON_SINGLE_ACTION", "RAGB_GROUPSECOND_DOWN", "GROUPSECOND_INPUT")
		end
	end
end

function realismAddon_gearbox_inputs:addRealismAddonActionEvent(type, inputAction, func, showHud)
	local spec = self.spec_realismAddon_gearbox_inputs

	-- The actionEvents table should already be cleared in onRegisterActionEvents

	local _, actionEventId = nil
	if type == "BUTTON_SINGLE_ACTION" then
		_, actionEventId = self:addActionEvent(spec.actionEvents, InputAction[inputAction], self,
			realismAddon_gearbox_inputs[func], false, true, false, true)
	elseif type == "BUTTON_DOUBLE_ACTION" then
		_, actionEventId = self:addActionEvent(spec.actionEvents, InputAction[inputAction], self,
			realismAddon_gearbox_inputs[func], true, true, false, true)
	elseif type == "PRESSED_OR_AXIS" then
		_, actionEventId = self:addActionEvent(spec.actionEvents, InputAction[inputAction], self,
			realismAddon_gearbox_inputs[func], false, false, true, true)
	end
	if not showHud then
		g_inputBinding:setActionEventTextVisibility(actionEventId, false)
	end
end

-- INPUT CALLBACKS

-- hand throttle
function realismAddon_gearbox_inputs:HANDTHROTTLE_INPUT(actionName, inputValue)
	local spec = self.spec_realismAddon_gearbox_inputs

	-- Ensure the action only proceeds if allManualActive is true
	if not spec.allManualActive then
		return
	end

	spec.handThrottleDown = false
	spec.handThrottleUp = false
	if actionName == "RAGB_HANDTHROTTLE_AXIS" then
		-- round to 1% resolution
		inputValue = math.floor(inputValue * 100) / 100
		if spec.handThrottlePercent ~= inputValue then
			self:raiseDirtyFlags(spec.synchHandThrottleDirtyFlag)
			spec.handThrottlePercent = inputValue
		end
	elseif actionName == "RAGB_HANDTHROTTLE_UP" and inputValue == 1 then
		spec.handThrottleUp = true
	elseif actionName == "RAGB_HANDTHROTTLE_DOWN" and inputValue == 1 then
		spec.handThrottleDown = true
	end
end

-- shifting axis for fps transmissions
function realismAddon_gearbox_inputs:RAGB_GEARSHIFT_AXIS(actionName, inputValue)
	local input = self.spec_realismAddon_gearbox_inputs
	local motor = self.spec_motorized.motor
	local gears = motor.currentGears

	-- Ensure the action only proceeds if allManualActive is true
	if not input.allManualActive then
		return
	end

	-- calculate wanted gear as rounded value of all gears * inputValue
	local wantedGear = math.floor(#gears * inputValue)

	-- only call the event if inputAxis moved enough to be a new gear
	if input.gearAxisPosition ~= wantedGear then
		if wantedGear ~= motor.gear then
			MotorGearShiftEvent.sendEvent(self, MotorGearShiftEvent.TYPE_SELECT_GEAR, wantedGear)
		end
		input.gearAxisPosition = wantedGear
	end
end

-- second group set
function realismAddon_gearbox_inputs:GROUPSECOND_INPUT(actionName, inputValue)
	local spec_ragb = self.spec_realismAddon_gearbox

	-- Ensure the action only proceeds if allManualActive is true
	if not self.spec_realismAddon_gearbox_inputs.allManualActive then
		return
	end

	if spec_ragb.groupsSecondSet ~= nil then
		local wantedGroup = spec_ragb.groupsSecondSet.currentGroup
		if actionName == "RAGB_GROUPSECOND_UP" then
			wantedGroup = math.min(spec_ragb.groupsSecondSet.currentGroup + 1, #spec_ragb.groupsSecondSet.groups)
		elseif actionName == "RAGB_GROUPSECOND_DOWN" then
			wantedGroup = math.max(spec_ragb.groupsSecondSet.currentGroup - 1, 1)
		end

		if wantedGroup ~= spec_ragb.groupsSecondSet.currentGroup then
			self:processSecondGroupSetInputs(wantedGroup)
		end
	end
end

-- ACTUAL SPEC

function realismAddon_gearbox_inputs.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", realismAddon_gearbox_inputs)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", realismAddon_gearbox_inputs)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", realismAddon_gearbox_inputs)
	SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", realismAddon_gearbox_inputs)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", realismAddon_gearbox_inputs)
end

function realismAddon_gearbox_inputs.registerFunctions(vehicleType)
	-- No custom functions to register in this example
end

-- LOAD
function realismAddon_gearbox_inputs:onLoad(savegame)
	self.addRealismAddonActionEvent = realismAddon_gearbox_inputs.addRealismAddonActionEvent

	self.spec_realismAddon_gearbox_inputs = {}
	local spec = self.spec_realismAddon_gearbox_inputs

	-- this value contains an up-to-date value if we are in manual mode
	spec.allManualActive = false

	-- hand throttle values
	spec.handThrottlePercent = 0
	spec.handThrottleDown = false
	spec.handThrottleUp = false

	spec.synchHandThrottleDirtyFlag = self:getNextDirtyFlag()

	-- gear shift axis values
	spec.gearAxisPosition = 0
end

-- UPDATE
function realismAddon_gearbox_inputs:onUpdate(dt)
	local spec = self.spec_realismAddon_gearbox_inputs

	-- Check if transmission is manual
	local allManualActive = realismAddon_gearbox_overrides.checkIsManual(self.spec_motorized.motor)

	if allManualActive ~= spec.allManualActive then
		spec.allManualActive = allManualActive

		-- Request action event update when allManualActive changes
		self:requestActionEventUpdate()
	end

	if spec.allManualActive then
		-- Calculating hand throttle
		if spec.handThrottleDown then
			spec.handThrottlePercent = math.max(0, spec.handThrottlePercent - 0.001 * dt)
			self:raiseDirtyFlags(spec.synchHandThrottleDirtyFlag)
		elseif spec.handThrottleUp then
			spec.handThrottlePercent = math.min(1, spec.handThrottlePercent + 0.001 * dt)
			self:raiseDirtyFlags(spec.synchHandThrottleDirtyFlag)
		end
	end

	-- Ensure the vehicle's motor remains active when hand throttle is engaged
	if spec.handThrottlePercent > 0 then
		self.spec_motorized.forceIsActiveMotor = true
	else
		self.spec_motorized.forceIsActiveMotor = false
	end
end

-- READ AND WRITE UPDATE

function realismAddon_gearbox_inputs:onWriteUpdateStream(streamId, connection, dirtyMask)
	local spec = self.spec_realismAddon_gearbox_inputs

	if connection:getIsServer() and spec.allManualActive then
		-- hand throttle
		if streamWriteBool(streamId, bitAND(dirtyMask, spec.synchHandThrottleDirtyFlag) ~= 0) then
			streamWriteUIntN(streamId, spec.handThrottlePercent * 100, 7)
		end
	end
end

function realismAddon_gearbox_inputs:onReadUpdateStream(streamId, timestamp, connection)
	local spec = self.spec_realismAddon_gearbox_inputs

	if not connection:getIsServer() and spec.allManualActive then
		-- hand throttle
		if streamReadBool(streamId) then
			spec.handThrottlePercent = streamReadUIntN(streamId, 7) / 100
		end
	end
end
