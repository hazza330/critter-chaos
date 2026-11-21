--[[
	Economy
	Global tuning values. Keep numbers here, not inside services.
]]

local Economy = {}

-- Discovery
Economy.DiscoverySpotCooldown = 8 -- seconds before the same player can use the same spot again
Economy.DiscoveryGlobalCooldown = 1.5 -- seconds between any two discoveries by one player
Economy.DiscoveryMaxDistance = 14 -- studs; server rejects triggers from further away
Economy.FirstDiscoveryBonusXP = 25 -- extra XP the first time a species is found
Economy.CollectionCapacity = 100 -- starting max creatures a player can hold

-- Creature income (used from Stage 3)
Economy.IncomeInterval = 10

-- Levels: XP needed to go from `level` to `level + 1`.
function Economy.XPToNextLevel(level: number): number
	return math.floor(50 * level ^ 1.5)
end

Economy.MaxLevel = 100

return Economy
