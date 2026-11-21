--[[
	Creatures
	Master list of every creature. Server and client both read this, but only the
	server decides which creature a player gets.

	Fields
	  id          stable numeric ID (never reuse or renumber, saves depend on it)
	  name        display name
	  rarity      key into Rarities.Info
	  element     flavour type
	  island      key into Islands
	  color       main body colour (used by the Stage 2 model builder)
	  description collection entry text
	  personality short behaviour note, drives idle animation choice in Stage 2
	  ability     short ability description (balanced numbers come in Stage 3)

	Stage 1 ships Critter Cove only. Other islands are added in Stage 5.
]]

local Creatures = {}

Creatures.List = {
	{
		id = 1,
		name = "Sproutling",
		rarity = "Common",
		element = "Nature",
		island = "CritterCove",
		color = Color3.fromRGB(124, 200, 92),
		description = "A seedling that grew legs and never looked back. Leaves a trail of tiny leaves.",
		personality = "Bouncy",
		ability = "Occasionally drops a bonus leaf.",
	},
	{
		id = 2,
		name = "Bubbles",
		rarity = "Common",
		element = "Water",
		island = "CritterCove",
		color = Color3.fromRGB(120, 200, 255),
		description = "Drifts along on its own bubble. Pops into giggles if you poke it.",
		personality = "Floaty",
		ability = "Produces water droplets.",
	},
	{
		id = 3,
		name = "Pebblit",
		rarity = "Common",
		element = "Earth",
		island = "CritterCove",
		color = Color3.fromRGB(150, 140, 130),
		description = "Looks exactly like a rock until it sneezes.",
		personality = "Sleepy",
		ability = "Sometimes digs up a pebble.",
	},
	{
		id = 4,
		name = "Flutterbug",
		rarity = "Uncommon",
		element = "Flying",
		island = "CritterCove",
		color = Color3.fromRGB(255, 160, 210),
		description = "Its wings hum a different note depending on its mood.",
		personality = "Curious",
		ability = "Slightly speeds up nearby discoveries.",
	},
	{
		id = 5,
		name = "Sunpup",
		rarity = "Uncommon",
		element = "Nature",
		island = "CritterCove",
		color = Color3.fromRGB(255, 205, 80),
		description = "Soaks up sunlight all day and glows faintly at night.",
		personality = "Playful",
		ability = "Earns a little more during the day.",
	},
	{
		id = 6,
		name = "Shellby",
		rarity = "Uncommon",
		element = "Water",
		island = "CritterCove",
		color = Color3.fromRGB(240, 140, 110),
		description = "Collects shiny things in its shell. Will not share them.",
		personality = "Shy",
		ability = "Finds the odd seashell.",
	},
	{
		id = 7,
		name = "Glowfin",
		rarity = "Rare",
		element = "Water",
		island = "CritterCove",
		color = Color3.fromRGB(80, 255, 220),
		description = "A fish that swims through the air as if it were water. Glows brighter near ponds.",
		personality = "Graceful",
		ability = "Lights up hidden discovery spots.",
	},
	{
		id = 8,
		name = "Mossback",
		rarity = "Rare",
		element = "Nature",
		island = "CritterCove",
		color = Color3.fromRGB(70, 120, 60),
		description = "A tortoise with a whole garden growing on its back.",
		personality = "Patient",
		ability = "Grows berries over time.",
	},
	{
		id = 9,
		name = "Crystal Fox",
		rarity = "Epic",
		element = "Magic",
		island = "CritterCove",
		color = Color3.fromRGB(180, 220, 255),
		description = "Its tail is made of living crystal that chimes when it runs.",
		personality = "Clever",
		ability = "Produces bonus island crystals.",
	},
	{
		id = 10,
		name = "Golden Griffin",
		rarity = "Legendary",
		element = "Flying",
		island = "CritterCove",
		color = Color3.fromRGB(255, 200, 40),
		description = "Guardian of the cove. Only shows itself to collectors it trusts.",
		personality = "Proud",
		ability = "Large boost to coin generation.",
	},
}

-- Lookup by id, built once.
Creatures.ById = {}
for _, creature in ipairs(Creatures.List) do
	assert(Creatures.ById[creature.id] == nil, "Duplicate creature id " .. creature.id)
	Creatures.ById[creature.id] = creature
end

function Creatures.Get(id: number)
	return Creatures.ById[id]
end

-- Returns every creature on an island with the given rarity.
function Creatures.ForIslandAndRarity(islandId: string, rarity: string)
	local result = {}
	for _, creature in ipairs(Creatures.List) do
		if creature.island == islandId and creature.rarity == rarity then
			table.insert(result, creature)
		end
	end
	return result
end

return Creatures
