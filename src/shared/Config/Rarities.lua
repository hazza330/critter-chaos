--[[
	Rarities
	Display colours and base balance values for each rarity tier.
	All numbers here are starting values and are meant to be tuned in playtesting.

	income   = coins produced every Economy.IncomeInterval seconds while equipped (Stage 3)
	coins    = one-off coin reward when this rarity is discovered
	xp       = XP reward when discovered
]]

local Rarities = {}

Rarities.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

Rarities.Info = {
	Common = { rank = 1, color = Color3.fromRGB(176, 190, 197), income = 1, coins = 5, xp = 10 },
	Uncommon = { rank = 2, color = Color3.fromRGB(102, 204, 102), income = 2, coins = 10, xp = 20 },
	Rare = { rank = 3, color = Color3.fromRGB(66, 165, 245), income = 4, coins = 25, xp = 45 },
	Epic = { rank = 4, color = Color3.fromRGB(171, 71, 188), income = 8, coins = 60, xp = 100 },
	Legendary = { rank = 5, color = Color3.fromRGB(255, 193, 7), income = 15, coins = 150, xp = 250 },
	Mythic = { rank = 6, color = Color3.fromRGB(255, 82, 82), income = 25, coins = 400, xp = 600 },
	Secret = { rank = 7, color = Color3.fromRGB(30, 30, 30), income = 30, coins = 500, xp = 800 },
}

function Rarities.Get(name: string)
	return Rarities.Info[name]
end

return Rarities
