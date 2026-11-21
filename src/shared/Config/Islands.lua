--[[
	Islands
	Per-island settings. rarityWeights are percentages and do not have to sum to 100;
	the roll normalises them. Secret creatures are never in this table because they
	can only be found through their own special requirements.
]]

local Islands = {}

Islands.Info = {
	CritterCove = {
		displayName = "Critter Cove",
		unlockLevel = 1,
		rarityWeights = {
			Common = 55,
			Uncommon = 25,
			Rare = 12,
			Epic = 6,
			Legendary = 1.8,
			Mythic = 0.2,
		},
	},
}

function Islands.Get(id: string)
	return Islands.Info[id]
end

return Islands
