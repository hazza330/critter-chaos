--[[
	ProgressService
	The only place that changes coins, gems, XP and level. Every other service
	calls these functions instead of editing data directly, so rules such as
	"no negative amounts" and "level up when XP is full" live in one spot.

	Also maintains leaderstats (the default Roblox player list board), which only
	shows game stats, never private information.
]]

local Shared = game:GetService("ReplicatedStorage").Shared
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)

local ProgressService = {}

local function countKeys(t: { [any]: any }): number
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

local function updateLeaderstats(player: Player)
	local data = DataService.Get(player)
	local stats = player:FindFirstChild("leaderstats")
	if not data or not stats then
		return
	end
	local level = stats:FindFirstChild("Level") :: IntValue
	local species = stats:FindFirstChild("Species") :: IntValue
	local coins = stats:FindFirstChild("Coins") :: IntValue
	level.Value = data.level
	species.Value = countKeys(data.discovered)
	coins.Value = data.coins
end

local function createLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	for _, name in ipairs({ "Level", "Species", "Coins" }) do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = folder
	end
	folder.Parent = player
	updateLeaderstats(player)
end

local function isValidAmount(amount: number): boolean
	return type(amount) == "number" and amount >= 0 and amount == math.floor(amount) and amount < 1e12
end

function ProgressService.AddCoins(player: Player, amount: number): boolean
	local data = DataService.Get(player)
	if not data or not isValidAmount(amount) then
		return false
	end
	data.coins += amount
	data.stats.coinsEarned += amount
	updateLeaderstats(player)
	return true
end

-- Returns true only if the player could afford it and the coins were taken.
function ProgressService.SpendCoins(player: Player, amount: number): boolean
	local data = DataService.Get(player)
	if not data or not isValidAmount(amount) or data.coins < amount then
		return false
	end
	data.coins -= amount
	updateLeaderstats(player)
	return true
end

function ProgressService.AddXP(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data or not isValidAmount(amount) then
		return
	end
	data.xp += amount
	local startLevel = data.level
	while data.level < Economy.MaxLevel and data.xp >= Economy.XPToNextLevel(data.level) do
		data.xp -= Economy.XPToNextLevel(data.level)
		data.level += 1
	end
	if data.level >= Economy.MaxLevel then
		data.xp = 0
	end
	if data.level > startLevel then
		Remotes.Event("Notify"):FireClient(player, {
			text = ("Level up! You're now level %d"):format(data.level),
			kind = "levelup",
		})
	end
	updateLeaderstats(player)
end

ProgressService.Refresh = updateLeaderstats

function ProgressService.Start()
	DataService.OnLoaded(function(player)
		createLeaderstats(player)
	end)
end

return ProgressService
