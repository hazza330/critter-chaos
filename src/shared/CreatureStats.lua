--[[
	CreatureStats
	Numbers derived from a creature the player owns. Shared so the inventory
	shows exactly what the server pays out.
]]

local Config = script.Parent.Config
local Creatures = require(Config.Creatures)
local Rarities = require(Config.Rarities)
local Economy = require(Config.Economy)

local CreatureStats = {}

-- Coins this owned creature produces every Economy.IncomeInterval seconds.
-- entry is a saved record: { id, level, ... }
function CreatureStats.Income(entry): number
	local creature = Creatures.Get(entry.id)
	if not creature then
		return 0
	end
	local base = Rarities.Info[creature.rarity].income
	local level = math.max(1, tonumber(entry.level) or 1)
	return math.floor(base * (1 + (level - 1) * Economy.IncomePerLevel) + 0.5)
end

function CreatureStats.EquipLimit(_data): number
	-- Upgrades will add to this in Stage 3.
	return Economy.BaseEquipSlots
end

return CreatureStats
