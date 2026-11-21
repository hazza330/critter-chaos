--[[
	InventoryService
	Handles every inventory request from the client through one RemoteFunction:

	  InventoryAction(action, uid) -> ok: boolean, message: string?

	Actions
	  "equip"       equip the creature with this uid
	  "unequip"     unequip it
	  "favourite"   toggle its favourite flag
	  "equipBest"   equip the highest-income creatures up to the limit
	  "unequipAll"  clear all equipped creatures

	Every request is type-checked, rate-limited and checked against the player's
	own saved data. The client can only ever refer to creatures by uid, and a uid
	the player doesn't own is rejected.

	The equipped creature ids are published as a JSON player attribute
	("EquippedPets") so every client can draw everyone's followers locally.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local CreatureStats = require(Shared.CreatureStats)
local Creatures = require(Shared.Config.Creatures)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)

local RATE_LIMIT = 0.15 -- seconds between requests per player

local InventoryService = {}

local lastRequest: { [Player]: number } = {}

local function isEquipped(data, uid: string): boolean
	return table.find(data.equipped, uid) ~= nil
end

-- Removes uids that no longer exist or point at unknown creatures, drops
-- duplicates and trims to the current limit. Run on load and after changes.
local function sanitise(data)
	local seen = {}
	local clean = {}
	local limit = CreatureStats.EquipLimit(data)
	for _, uid in ipairs(data.equipped) do
		local entry = type(uid) == "string" and data.creatures[uid]
		if entry and Creatures.Get(entry.id) and not seen[uid] and #clean < limit then
			seen[uid] = true
			table.insert(clean, uid)
		end
	end
	data.equipped = clean
end

local function publish(player: Player, data)
	local ids = {}
	for _, uid in ipairs(data.equipped) do
		table.insert(ids, data.creatures[uid].id)
	end
	player:SetAttribute("EquippedPets", HttpService:JSONEncode(ids))
end

local handlers: { [string]: (Player, any, string?) -> (boolean, string?) } = {}

handlers.equip = function(_player, data, uid)
	if not uid or not data.creatures[uid] then
		return false, "You don't own that creature"
	end
	if isEquipped(data, uid) then
		return true
	end
	if #data.equipped >= CreatureStats.EquipLimit(data) then
		return false, ("You can only equip %d creatures"):format(CreatureStats.EquipLimit(data))
	end
	table.insert(data.equipped, uid)
	return true
end

handlers.unequip = function(_player, data, uid)
	if not uid then
		return false, "Bad request"
	end
	local index = table.find(data.equipped, uid)
	if index then
		table.remove(data.equipped, index)
	end
	return true
end

handlers.favourite = function(_player, data, uid)
	local entry = uid and data.creatures[uid]
	if not entry then
		return false, "You don't own that creature"
	end
	entry.fav = not entry.fav
	return true
end

handlers.equipBest = function(_player, data)
	local list = {}
	for uid, entry in pairs(data.creatures) do
		if Creatures.Get(entry.id) then
			table.insert(list, { uid = uid, income = CreatureStats.Income(entry) })
		end
	end
	table.sort(list, function(a, b)
		if a.income ~= b.income then
			return a.income > b.income
		end
		return tonumber(a.uid) < tonumber(b.uid)
	end)
	data.equipped = {}
	for i = 1, math.min(#list, CreatureStats.EquipLimit(data)) do
		table.insert(data.equipped, list[i].uid)
	end
	return true
end

handlers.unequipAll = function(_player, data)
	data.equipped = {}
	return true
end

local function onRequest(player: Player, action: any, uid: any): (boolean, string?)
	local clock = os.clock()
	if clock - (lastRequest[player] or 0) < RATE_LIMIT then
		return false, "Slow down a little"
	end
	lastRequest[player] = clock

	if type(action) ~= "string" or (uid ~= nil and (type(uid) ~= "string" or #uid > 12)) then
		return false, "Bad request"
	end
	local handler = handlers[action]
	if not handler then
		return false, "Bad request"
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Your data is still loading"
	end

	local ok, message = handler(player, data, uid)
	if ok then
		sanitise(data)
		publish(player, data)
		DataService.Sync(player)
	end
	return ok, message
end

function InventoryService.Start()
	Remotes.Function("InventoryAction").OnServerInvoke = onRequest

	DataService.OnLoaded(function(player, data)
		sanitise(data)
		publish(player, data)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return InventoryService
