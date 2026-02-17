function widget:GetInfo()
	return {
		name      = "Split Selection Hotkeys",
		desc      = "Hotkeys to split current selection in half and swap/recombine",
		author    = "ChatGPT",
		date      = "2026-02-16",
		license   = "GPLv2",
		layer     = 0,
		enabled   = true,
	}
end

local GetSelectedUnits = Spring.GetSelectedUnits
local SelectUnitArray  = Spring.SelectUnitArray
local Echo             = Spring.Echo

local halfA, halfB = nil, nil
local activeHalf = nil -- "A" or "B"

local function copyArray(src)
	local dst = {}
	for i = 1, #src do dst[i] = src[i] end
	return dst
end

local function makeSet(arr)
	local s = {}
	for i = 1, #arr do s[arr[i]] = true end
	return s
end

local function sameUnitSet(a, b)
	if (not a) or (not b) then return false end
	if #a ~= #b then return false end
	local sa = makeSet(a)
	for i = 1, #b do
		if not sa[b[i]] then return false end
	end
	return true
end

local function uniqueMerge(a, b)
	local out, seen = {}, {}
	if a then
		for i = 1, #a do
			local id = a[i]
			if not seen[id] then seen[id] = true; out[#out+1] = id end
		end
	end
	if b then
		for i = 1, #b do
			local id = b[i]
			if not seen[id] then seen[id] = true; out[#out+1] = id end
		end
	end
	return out
end

local function splitSelection()
	local sel = GetSelectedUnits()
	if not sel or #sel < 2 then
		Echo("[SplitSelection] Need at least 2 units selected.")
		return
	end

	local n = #sel
	local cut = math.floor(n / 2)

	halfA, halfB = {}, {}
	for i = 1, n do
		if i <= cut then
			halfA[#halfA + 1] = sel[i]
		else
			halfB[#halfB + 1] = sel[i]
		end
	end

	-- Select A by default (first half)
	activeHalf = "A"
	SelectUnitArray(halfA, false)
	Echo(string.format("[SplitSelection] Split %d units into %d + %d.", n, #halfA, #halfB))
end

local function swapHalves()
	if not halfA or not halfB then
		Echo("[SplitSelection] No stored split. Use Split first.")
		return
	end

	-- If player manually changed selection, try to resync which half they’re on.
	local sel = GetSelectedUnits() or {}
	if sameUnitSet(sel, halfA) then
		activeHalf = "A"
	elseif sameUnitSet(sel, halfB) then
		activeHalf = "B"
	end

	if activeHalf == "A" then
		activeHalf = "B"
		SelectUnitArray(halfB, false)
		Echo(string.format("[SplitSelection] Swapped to half B (%d units).", #halfB))
	elseif activeHalf == "B" then
		activeHalf = "A"
		SelectUnitArray(halfA, false)
		Echo(string.format("[SplitSelection] Swapped to half A (%d units).", #halfA))
	else
		-- If we somehow lost state, fall back to selecting A.
		activeHalf = "A"
		SelectUnitArray(halfA, false)
		Echo("[SplitSelection] Lost half state; selected half A.")
	end
end

local function recombine()
	if not halfA or not halfB then
		Echo("[SplitSelection] Nothing to recombine (no stored split).")
		return
	end

	local merged = uniqueMerge(halfA, halfB)
	if #merged == 0 then
		Echo("[SplitSelection] Recombine failed (merged selection empty).")
		return
	end

	activeHalf = nil
	SelectUnitArray(merged, false)
	Echo(string.format("[SplitSelection] Recombined to %d units.", #merged))
end

function widget:Initialize()
	widgetHandler:AddAction("splitselection", splitSelection, nil, "t")
	widgetHandler:AddAction("swapselectionhalf", swapHalves, nil, "t")
	widgetHandler:AddAction("recombineselection", recombine, nil, "t")
end

function widget:Shutdown()
	widgetHandler:RemoveAction("splitselection")
	widgetHandler:RemoveAction("swapselectionhalf")
	widgetHandler:RemoveAction("recombineselection")
end
