--[[
	TreasureService
	Hidden treasure chests (parts tagged "TreasureChest" with a ChestId attribute).
	Each chest can be opened once every REFILL_HOURS per player. The last opening
	time is saved in data.chests[ChestId] using server time, so reconnecting or
	hopping servers doesn't reset it.
]]

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)
local ProgressService = require(script.Parent.ProgressService)

local REFILL_HOURS = 20
local REWARD_COINS = 150
local REWARD_GEMS = 5
local REWARD_XP = 40
local MAX_DISTANCE = 14

local TreasureService = {}

local function notify(player: Player, text: string, kind: string)
	Remotes.Event("Notify"):FireClient(player, { text = text, kind = kind })
end

local function onOpen(chestPart: BasePart, player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - chestPart.Position).Magnitude > MAX_DISTANCE then
		return
	end

	local id = chestPart:GetAttribute("ChestId")
	if type(id) ~= "string" then
		return
	end
	local now = os.time()
	local last = tonumber(data.chests[id]) or 0
	local wait = last + REFILL_HOURS * 3600 - now
	if wait > 0 then
		notify(player, ("This chest refills in %dh %dm"):format(wait // 3600, (wait % 3600) // 60), "info")
		return
	end

	data.chests[id] = now
	ProgressService.AddCoins(player, REWARD_COINS)
	ProgressService.AddGems(player, REWARD_GEMS)
	ProgressService.AddXP(player, REWARD_XP)
	DataService.Sync(player)
	notify(player, ("Treasure! +%d coins  +%d gems"):format(REWARD_COINS, REWARD_GEMS), "success")
end

local function setup(chestPart: Instance)
	if not chestPart:IsA("BasePart") or chestPart:FindFirstChild("ChestPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ChestPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = "Treasure Chest"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = chestPart
	prompt.Triggered:Connect(function(player)
		onOpen(chestPart, player)
	end)
end

function TreasureService.Start()
	for _, chest in ipairs(CollectionService:GetTagged("TreasureChest")) do
		setup(chest)
	end
	CollectionService:GetInstanceAddedSignal("TreasureChest"):Connect(setup)
end

return TreasureService
