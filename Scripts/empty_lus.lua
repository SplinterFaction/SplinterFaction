base = piece('base')

function script.Create()
end

function script.Killed()
	return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end