local M = {}

local englishInputSource = "com.apple.keylayout.ABC"
local chineseInputSource = "im.rime.inputmethod.Squirrel.Hans"

local tapDuration = 0.25
local switchTimeout = 0.35

local leftShiftKeyCode = 56
local rightShiftKeyCode = 60
local shiftKeyCodes = { [leftShiftKeyCode] = "left", [rightShiftKeyCode] = "right" }

local shiftKeyDownTime = { left = nil, right = nil }
local otherKeyPressed = { left = false, right = false }

local function clearSwitchTimeout()
	if M.switchTimeoutTimer then
		M.switchTimeoutTimer:stop()
		M.switchTimeoutTimer = nil
	end
	M.switchInFlight = false
end

local function applyInputSource(targetSource)
	if targetSource == englishInputSource then
		return hs.keycodes.setLayout("ABC")
	end

	return hs.keycodes.currentSourceID(targetSource)
end

local function drainPendingSwitch()
	if M.switchInFlight or not M.pendingTargetSource then
		return
	end

	local targetSource = M.pendingTargetSource
	M.pendingTargetSource = nil

	local currentSource = hs.keycodes.currentSourceID()
	if currentSource == targetSource then
		return
	end

	M.switchInFlight = true
	local switched = applyInputSource(targetSource)
	if not switched then
		clearSwitchTimeout()
		return
	end

	-- Some input methods do not emit the change callback reliably under load.
	M.switchTimeoutTimer = hs.timer.doAfter(switchTimeout, function()
		clearSwitchTimeout()
		drainPendingSwitch()
	end)
end

local function scheduleInputSourceSwitch(targetSource)
	M.pendingTargetSource = targetSource

	if M.pendingSwitchTimer then
		M.pendingSwitchTimer:stop()
	end

	-- Delay the actual source switch until after the eventtap callback returns.
	M.pendingSwitchTimer = hs.timer.doAfter(0.01, function()
		M.pendingSwitchTimer = nil
		drainPendingSwitch()
	end)
end

M.inputSourceWatcher = hs.keycodes.inputSourceChanged(function()
	clearSwitchTimeout()
	drainPendingSwitch()
end)

M.shiftEventTap = hs.eventtap.new(
	{ hs.eventtap.event.types.flagsChanged, hs.eventtap.event.types.keyDown },
	function(event)
		local keyCode = event:getKeyCode()
		local flags = event:getFlags()

		if shiftKeyCodes[keyCode] then
			local side = shiftKeyCodes[keyCode]
			if event:getType() == hs.eventtap.event.types.flagsChanged then
				if not flags:contain({ "shift" }) then
					if shiftKeyDownTime[side] and not otherKeyPressed[side] then
						local duration = hs.timer.secondsSinceEpoch() - shiftKeyDownTime[side]
						if duration < tapDuration then
							if side == "left" then
								scheduleInputSourceSwitch(englishInputSource)
							elseif side == "right" then
								scheduleInputSourceSwitch(chineseInputSource)
							end
						end
					end
					shiftKeyDownTime[side] = nil
					otherKeyPressed[side] = false
				else
					shiftKeyDownTime[side] = hs.timer.secondsSinceEpoch()
					otherKeyPressed[side] = false
				end
			end
		elseif shiftKeyDownTime.left or shiftKeyDownTime.right then
			otherKeyPressed.left = true
			otherKeyPressed.right = true
		end

		return false
	end
)

M.shiftEventTap:start()

return M
