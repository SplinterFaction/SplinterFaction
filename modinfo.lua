-- $Id: modinfo.lua 4663 2009-05-24 06:00:10Z det $
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    modinfo.lua
--  brief:   Mod Info
--

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return {
	name='SplinterFaction',
	description='SplinterFaction',
	shortname='SF',
	version='$VERSION', -- 0.1.41
	-- DON'T FORGET TO UPDATE THE AUTOHOST!
	mutator='Official',
	game='SplinterFaction',
	shortGame='SF',
	modtype=1,
	depend = {
		"SplinterFaction Unittextures 2",
		-- "Dreamstate Logic Music Addon 1",
		-- "Spring Features v1.9",
	},
}
