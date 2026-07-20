local M = {}

local inputSources = {
	english = "com.apple.keylayout.ABC",
	chinese = "im.rime.inputmethod.Squirrel.Hans",
}

local macismPath = os.getenv("HOME") .. "/.local/bin/macism"

local function setInputSource(sourceId)
	local _, ok = hs.execute(macismPath .. " " .. sourceId, true)
	if not ok then
		hs.alert.show("Failed to switch input source")
	end
end

function M.switchToEnglish()
	setInputSource(inputSources.english)
end

function M.switchToChinese()
	setInputSource(inputSources.chinese)
end

M.ghosttyToggle = hs.hotkey.bind({ "option" }, "`", function()
	local ghostty = hs.application.get("com.mitchellh.ghostty")
	if ghostty == nil then
		hs.application.launchOrFocus("/Applications/Ghostty.app")
		return
	end

	if ghostty:isFrontmost() then
		ghostty:hide()
	else
		ghostty:activate()
	end
end)

local shiftKeyCodes = {
	[56] = "left",
	[60] = "right",
}
local pendingShiftSide = nil
local shiftWasUsedWithAnotherKey = false

M.inputMethodTap = hs.eventtap
	.new({
		hs.eventtap.event.types.flagsChanged,
		hs.eventtap.event.types.keyDown,
		hs.eventtap.event.types.leftMouseDown,
		hs.eventtap.event.types.rightMouseDown,
		hs.eventtap.event.types.otherMouseDown,
	}, function(event)
		local eventType = event:getType()

		if eventType ~= hs.eventtap.event.types.flagsChanged then
			if pendingShiftSide ~= nil then
				shiftWasUsedWithAnotherKey = true
			end
			return false
		end

		local side = shiftKeyCodes[event:getKeyCode()]
		if side == nil then
			if pendingShiftSide ~= nil then
				shiftWasUsedWithAnotherKey = true
			end
			return false
		end

		if event:getFlags().shift then
			pendingShiftSide = side
			shiftWasUsedWithAnotherKey = false
			return false
		end

		if pendingShiftSide == side and not shiftWasUsedWithAnotherKey then
			if side == "left" then
				M.switchToEnglish()
			else
				M.switchToChinese()
			end
		end

		pendingShiftSide = nil
		shiftWasUsedWithAnotherKey = false
		return false
	end)
	:start()

return M
