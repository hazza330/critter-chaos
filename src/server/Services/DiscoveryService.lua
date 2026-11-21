--[[
	DiscoveryService
	Turns every part tagged "DiscoverySpot" into a searchable spot and decides,
	on the server only, which creature a player finds.

	Flow when a player triggers a spot
	  1. Check their data is loaded.
	  2. Check distance, per-spot cooldown, global cooldown and collection capacity.
	  3. Check the island is unlocked for their level.
	  4. Roll a rarity from the island's weight table, then a creature of that rarity.
	  5. Add the creature, give coins and XP, mark the species as discovered.
	  6. Tell the client to play the reveal, and sync data.

	The client never sends anything here except the ProximityPrompt trigger,
	which Roblox itself raises on the server. There is nothing for an exploiter
	to spoof except standing near a bush, and distance is rechecked anyway.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Islands = require(Shared.Config.Islands)
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)
local ProgressService = require(script.Parent.ProgressService)

local SPOT_TAG = "DiscoverySpot"
local ANNOUNCE_RANK = 5 -- Legendary and above are announced to the whole server

local DiscoveryService = {}

local rng = Random.new()
local lastAnyDiscovery: { [Player]: number } = {}
local lastSpotUse: { [Player]: { [Instance]: number } } = {}

-------------------------------------------------------------------------------
-- Rolling
-------------------------------------------------------------------------------

-- luck multiplies Rare and better weights. 1 = no bonus.
function DiscoveryService.RollRarity(islandId: string, luck: number): string
	local island = Islands.Get(islandId)
	local weights = island.rarityWeights

	local total = 0
	local adjusted = {}
	for _, rarity in ipairs(Rarities.Order) do
		local weight = weights[rarity]
		if weight then
			if Rarities.Info[rarity].rank >= 3 then
				weight *= luck
			end
			adjusted[rarity] = weight
			total += weight
		end
	end

	local roll = rng:NextNumber() * total
	local cumulative = 0
	for _, rarity in ipairs(Rarities.Order) do
		local weight = adjusted[rarity]
		if weight then
			cumulative += weight
			if roll <= cumulative then
				return rarity
			end
		end
	end
	return "Common"
end

-- Picks a creature of the rolled rarity. If the island has none at that rarity
-- (for example no Mythic in Critter Cove yet) it steps down until it finds one.
function DiscoveryService.PickCreature(islandId: string, rarity: string)
	local rank = Rarities.Info[rarity].rank
	for r = rank, 1, -1 do
		local name = Rarities.Order[r]
		local pool = Creatures.ForIslandAndRarity(islandId, name)
		if #pool > 0 then
			return pool[rng:NextInteger(1, #pool)]
		end
	end
	return nil
end

-------------------------------------------------------------------------------
-- Granting
-------------------------------------------------------------------------------

local function countKeys(t: { [any]: any }): number
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, { text = text, kind = kind or "info" })
end

local function grantCreature(player: Player, data, creature)
	local uid = tostring(data.nextUid)
	data.nextUid += 1
	data.creatures[uid] = { id = creature.id, level = 1, t = os.time(), fav = false }

	local speciesKey = tostring(creature.id)
	local firstTime = data.discovered[speciesKey] == nil
	if firstTime then
		data.discovered[speciesKey] = os.time()
	end
	data.stats.discoveries += 1

	local info = Rarities.Info[creature.rarity]
	local xp = info.xp + (if firstTime then Economy.FirstDiscoveryBonusXP else 0)
	ProgressService.AddCoins(player, info.coins)
	ProgressService.AddXP(player, xp)

	return uid, firstTime, info.coins, xp
end

local function onTriggered(spot: BasePart, player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end

	-- Distance check (ProximityPrompt already limits this, but never trust one layer)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - spot.Position).Magnitude > Economy.DiscoveryMaxDistance then
		return
	end

	local clock = os.clock()
	if clock - (lastAnyDiscovery[player] or 0) < Economy.DiscoveryGlobalCooldown then
		return
	end
	local spotTimes = lastSpotUse[player]
	if not spotTimes then
		spotTimes = {}
		lastSpotUse[player] = spotTimes
	end
	local sinceSpot = clock - (spotTimes[spot] or -math.huge)
	if sinceSpot < Economy.DiscoverySpotCooldown then
		notify(player, ("This spot needs %ds to settle"):format(math.ceil(Economy.DiscoverySpotCooldown - sinceSpot)))
		return
	end

	if countKeys(data.creatures) >= Economy.CollectionCapacity then
		notify(player, "Your collection is full!", "error")
		return
	end

	local islandId = spot:GetAttribute("IslandId") or "CritterCove"
	local island = Islands.Get(islandId)
	if not island then
		warn("[DiscoveryService] Unknown island on spot " .. spot:GetFullName())
		return
	end
	if data.level < island.unlockLevel then
		notify(player, ("Reach level %d to search here"):format(island.unlockLevel), "error")
		return
	end

	lastAnyDiscovery[player] = clock
	spotTimes[spot] = clock

	-- Hidden spots carry a Luck attribute that boosts Rare and better.
	local luck = math.clamp(tonumber(spot:GetAttribute("Luck")) or 1, 1, 5)
	local rarity = DiscoveryService.RollRarity(islandId, luck)
	local creature = DiscoveryService.PickCreature(islandId, rarity)
	if not creature then
		warn("[DiscoveryService] No creature available on " .. islandId)
		return
	end

	local uid, firstTime, coins, xp = grantCreature(player, data, creature)

	Remotes.Event("Discovered"):FireClient(player, {
		creatureId = creature.id,
		uid = uid,
		firstTime = firstTime,
		coins = coins,
		xp = xp,
	})
	DataService.Sync(player)

	if Rarities.Info[creature.rarity].rank >= ANNOUNCE_RANK then
		Remotes.Event("Notify"):FireAllClients({
			text = ("%s discovered a %s %s!"):format(player.DisplayName, creature.rarity, creature.name),
			kind = "rare",
		})
	end
end

-------------------------------------------------------------------------------
-- Spot setup
-------------------------------------------------------------------------------

local function setupSpot(spot: Instance)
	if not spot:IsA("BasePart") or spot:FindFirstChild("DiscoveryPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DiscoveryPrompt"
	prompt.ActionText = "Search"
	prompt.ObjectText = spot:GetAttribute("SpotName") or "Rustling Bush"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = spot

	prompt.Triggered:Connect(function(player)
		onTriggered(spot, player)
	end)
end

function DiscoveryService.Start()
	for _, spot in ipairs(CollectionService:GetTagged(SPOT_TAG)) do
		setupSpot(spot)
	end
	CollectionService:GetInstanceAddedSignal(SPOT_TAG):Connect(setupSpot)

	Players.PlayerRemoving:Connect(function(player)
		lastAnyDiscovery[player] = nil
		lastSpotUse[player] = nil
	end)
end

return DiscoveryService
