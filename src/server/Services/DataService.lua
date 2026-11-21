--[[
	DataService
	Loads, holds, autosaves and releases each player's saved data.

	Safety features
	  * Session locking: a server stamps its JobId on the record when it loads it.
	    Another server will not overwrite a record locked by someone else, which
	    stops item duplication when a player hops servers quickly.
	  * Retries with back-off on every DataStore call.
	  * Reconcile: missing or wrongly typed fields are filled from the template,
	    so old or damaged saves never crash the game.
	  * Autosave every AUTOSAVE_INTERVAL seconds, save on leave, save on shutdown.
	  * If DataStores are unavailable (unpublished place, or Studio API access off)
	    it falls back to memory-only data and warns loudly. Nothing persists then.

	Other services must never edit data before DataService.Get returns a table.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)

local STORE_NAME = "CritterChaos_PlayerData_v1"
local SCHEMA_VERSION = 1
local LOCK_STALE_AFTER = 600 -- seconds; a lock older than this belongs to a crashed server
local AUTOSAVE_INTERVAL = 90
local MAX_ATTEMPTS = 5

local DataService = {}

type Profile = {
	data: { [string]: any },
	key: string,
	saving: boolean,
	released: boolean,
}

local profiles: { [Player]: Profile } = {}
local loadedCallbacks: { (Player, { [string]: any }) -> () } = {}

local store: DataStore? = nil
local memoryOnly = false

-------------------------------------------------------------------------------
-- Template and reconcile
-------------------------------------------------------------------------------

local function newTemplate()
	return {
		version = SCHEMA_VERSION,
		coins = 0,
		gems = 0,
		crystals = {}, -- [islandId] = amount
		xp = 0,
		level = 1,
		nextUid = 1,
		creatures = {}, -- [uid string] = { id, level, t, fav }
		discovered = {}, -- [creatureId string] = first discovery os.time()
		stats = {
			discoveries = 0,
			coinsEarned = 0,
		},
		tutorialDone = false,
		settings = {
			music = true,
			sfx = true,
		},
	}
end

-- Fills in anything missing or of the wrong type. Never removes extra keys,
-- so data from newer versions is not destroyed by an older server.
local function reconcile(target: { [any]: any }, template: { [any]: any })
	for key, default in pairs(template) do
		local current = target[key]
		if type(current) ~= type(default) then
			if type(default) == "table" then
				target[key] = table.clone(default)
				reconcile(target[key], default)
			else
				target[key] = default
			end
		elseif type(default) == "table" and next(default) ~= nil then
			reconcile(current, default)
		end
	end
	return target
end

-------------------------------------------------------------------------------
-- DataStore helpers
-------------------------------------------------------------------------------

local function initStore()
	local ok, result = pcall(function()
		local ds = DataStoreService:GetDataStore(STORE_NAME)
		-- A cheap read tells us whether API access actually works.
		ds:GetAsync("__probe")
		return ds
	end)
	if ok then
		store = result
	else
		memoryOnly = true
		warn(
			"[DataService] DataStores unavailable, progress will NOT save. "
				.. "Publish the place and enable 'Studio Access to API Services' in Game Settings > Security. Error: "
				.. tostring(result)
		)
	end
end

local function now(): number
	return os.time()
end

-- Loads the record and claims the session lock. Returns data or nil on failure.
local function loadRecord(key: string): { [string]: any }?
	if memoryOnly then
		return reconcile({}, newTemplate())
	end
	local ds = store :: DataStore

	for attempt = 1, MAX_ATTEMPTS do
		local forceSteal = attempt == MAX_ATTEMPTS
		local lockedElsewhere = false

		local ok, record = pcall(function()
			return ds:UpdateAsync(key, function(old)
				old = if type(old) == "table" then old else {}
				local lock = old.lock
				if
					not forceSteal
					and type(lock) == "table"
					and lock.jobId ~= game.JobId
					and now() - (tonumber(lock.time) or 0) < LOCK_STALE_AFTER
				then
					lockedElsewhere = true
					return nil -- cancel, another server still owns this session
				end
				old.lock = { jobId = game.JobId, time = now() }
				return old
			end)
		end)

		if ok and record and not lockedElsewhere then
			local data = if type(record.data) == "table" then record.data else {}
			return reconcile(data, newTemplate())
		end

		if not ok then
			warn(("[DataService] Load attempt %d failed for %s: %s"):format(attempt, key, tostring(record)))
		end
		-- Locked elsewhere usually means the old server is still saving. Wait for it.
		task.wait(if lockedElsewhere then 6 else attempt * 2)
	end
	return nil
end

-- Writes data. If release is true the session lock is cleared.
local function saveRecord(key: string, data: { [string]: any }, release: boolean): boolean
	if memoryOnly then
		return true
	end
	local ds = store :: DataStore

	for attempt = 1, MAX_ATTEMPTS do
		local lostLock = false
		local ok, err = pcall(function()
			ds:UpdateAsync(key, function(old)
				old = if type(old) == "table" then old else {}
				local lock = old.lock
				if type(lock) == "table" and lock.jobId ~= game.JobId then
					lostLock = true
					return nil -- another server took over; do not overwrite its data
				end
				return {
					data = data,
					lock = if release then nil else { jobId = game.JobId, time = now() },
				}
			end)
		end)
		if ok then
			if lostLock then
				warn("[DataService] Lost session lock for " .. key .. ", save skipped")
				return false
			end
			return true
		end
		warn(("[DataService] Save attempt %d failed for %s: %s"):format(attempt, key, tostring(err)))
		task.wait(attempt * 2)
	end
	return false
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

-- Returns the player's live data table, or nil if it is not loaded yet.
function DataService.Get(player: Player): { [string]: any }?
	local profile = profiles[player]
	return if profile then profile.data else nil
end

-- Runs callback(player, data) for every player once their data has loaded.
function DataService.OnLoaded(callback: (Player, { [string]: any }) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in pairs(profiles) do
		task.spawn(callback, player, profile.data)
	end
end

-- Sends the player a fresh copy of their data. Call after any change.
function DataService.Sync(player: Player)
	local data = DataService.Get(player)
	if data then
		Remotes.Event("DataSync"):FireClient(player, data)
	end
end

function DataService.IsMemoryOnly(): boolean
	return memoryOnly
end

local function saveProfile(player: Player, release: boolean)
	local profile = profiles[player]
	if not profile or profile.released then
		return
	end
	-- Wait for an in-flight autosave so two writes never race.
	while profile.saving do
		task.wait(0.1)
	end
	profile.saving = true
	saveRecord(profile.key, profile.data, release)
	profile.saving = false
	if release then
		profile.released = true
	end
end

local function onPlayerAdded(player: Player)
	local key = "Player_" .. player.UserId
	local data = loadRecord(key)

	if not data then
		player:Kick("Critter Chaos couldn't load your save. Your progress is safe, please rejoin in a minute.")
		return
	end

	if not player.Parent then
		-- Left while loading. Release the lock we just took.
		saveRecord(key, data, true)
		return
	end

	profiles[player] = { data = data, key = key, saving = false, released = false }

	for _, callback in ipairs(loadedCallbacks) do
		task.spawn(callback, player, data)
	end
	DataService.Sync(player)
end

local function onPlayerRemoving(player: Player)
	saveProfile(player, true)
	profiles[player] = nil
end

function DataService.Start()
	initStore()

	Remotes.Function("GetData").OnServerInvoke = function(player)
		return DataService.Get(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	-- Autosave loop
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in pairs(profiles) do
				task.spawn(saveProfile, player, false)
			end
		end
	end)

	-- Server shutdown: save everyone and wait (Roblox allows up to 30 seconds).
	game:BindToClose(function()
		if RunService:IsStudio() and memoryOnly then
			return
		end
		local pending = 0
		for player in pairs(profiles) do
			pending += 1
			task.spawn(function()
				saveProfile(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
