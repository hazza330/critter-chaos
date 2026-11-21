--[[
	RevealController
	Plays the discovery reveal when the server says a creature was found.
	Purely visual: the creature was already added on the server before this runs.

	Sequence: screen dims, a rarity-coloured orb spins and grows, it bursts to
	show the name, rarity and rewards. Rarer finds hold longer and play a
	higher-pitched sound. Tap/click anywhere or wait to dismiss.

	Stage 2 replaces the orb with the creature's actual 3D model in a ViewportFrame.
]]

local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)
local UI = require(script.Parent.Parent.UI)

local RevealController = {}

local overlay: TextButton
local orb: Frame
local nameLabel: TextLabel
local rarityLabel: TextLabel
local rewardLabel: TextLabel
local newBadge: TextLabel
local sound: Sound

local queue = {}
local playing = false
local dismissed: BindableEvent

local function build(root: ScreenGui)
	overlay = UI.new("TextButton", {
		Name = "Reveal",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 50,
		Parent = root,
	})

	orb = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 51,
		Parent = overlay,
	}, {
		UI.corner(999),
		UI.new("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)),
			Rotation = 45,
		}),
	})

	newBadge = UI.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.24),
		Size = UDim2.fromOffset(200, 34),
		BackgroundColor3 = UI.Colors.Accent,
		Text = "NEW SPECIES!",
		Font = UI.Font,
		TextSize = 20,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 52,
		Visible = false,
		Parent = overlay,
	}, { UI.corner(17) })

	nameLabel = UI.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.new(0.9, 0, 0, 60),
		BackgroundTransparency = 1,
		Text = "",
		Font = UI.Font,
		TextSize = 54,
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 1,
		ZIndex = 52,
		Parent = overlay,
	}, { UI.new("UIStroke", { Thickness = 3, Color = Color3.fromRGB(30, 20, 40) }) })

	rarityLabel = UI.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.6, 62),
		Size = UDim2.new(0.9, 0, 0, 34),
		BackgroundTransparency = 1,
		Text = "",
		Font = UI.Font,
		TextSize = 30,
		TextTransparency = 1,
		ZIndex = 52,
		Parent = overlay,
	}, { UI.new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(30, 20, 40) }) })

	rewardLabel = UI.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.6, 104),
		Size = UDim2.new(0.9, 0, 0, 26),
		BackgroundTransparency = 1,
		Text = "",
		Font = UI.BodyFont,
		TextSize = 22,
		TextColor3 = UI.Colors.Coin,
		TextTransparency = 1,
		ZIndex = 52,
		Parent = overlay,
	})

	sound = UI.new("Sound", {
		SoundId = "rbxasset://sounds/electronicpingshort.wav",
		Volume = 0.6,
		Parent = SoundService,
	})

	dismissed = Instance.new("BindableEvent")
	overlay.Activated:Connect(function()
		dismissed:Fire()
	end)
end

local function play(payload)
	local creature = Creatures.Get(payload.creatureId)
	if not creature then
		return
	end
	local rarity = Rarities.Info[creature.rarity]
	local rank = rarity.rank

	-- Reset
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	orb.Size = UDim2.fromOffset(0, 0)
	orb.Rotation = 0
	orb.BackgroundColor3 = rarity.color
	orb.BackgroundTransparency = 0
	newBadge.Visible = false
	for _, label in ipairs({ nameLabel, rarityLabel, rewardLabel }) do
		label.TextTransparency = 1
	end

	TweenService:Create(overlay, TweenInfo.new(0.25), { BackgroundTransparency = 0.45 }):Play()

	-- Build-up: longer for rarer creatures.
	local buildUp = 0.6 + rank * 0.2
	TweenService:Create(orb, TweenInfo.new(buildUp, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.fromOffset(160, 160),
		Rotation = 360 * (1 + rank),
	}):Play()
	task.wait(buildUp)

	-- Burst
	sound.PlaybackSpeed = 0.8 + rank * 0.12
	SoundService:PlayLocalSound(sound)
	TweenService:Create(orb, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(220, 220) }):Play()

	nameLabel.Text = creature.name
	rarityLabel.Text = creature.rarity:upper() .. "  ·  " .. creature.element
	rarityLabel.TextColor3 = rarity.color
	rewardLabel.Text = ("+%d coins   +%d XP"):format(payload.coins, payload.xp)
	newBadge.Visible = payload.firstTime == true

	local fadeIn = TweenInfo.new(0.3)
	for _, label in ipairs({ nameLabel, rarityLabel, rewardLabel }) do
		TweenService:Create(label, fadeIn, { TextTransparency = 0 }):Play()
	end

	-- Hold, or until the player taps.
	local hold = 2 + rank * 0.4
	local done = false
	local connection = dismissed.Event:Connect(function()
		done = true
	end)
	local start = os.clock()
	while not done and os.clock() - start < hold do
		task.wait()
	end
	connection:Disconnect()

	-- Out
	local fadeOut = TweenInfo.new(0.25)
	TweenService:Create(overlay, fadeOut, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(orb, fadeOut, { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0) }):Play()
	for _, label in ipairs({ nameLabel, rarityLabel, rewardLabel }) do
		TweenService:Create(label, fadeOut, { TextTransparency = 1 }):Play()
	end
	newBadge.Visible = false
	task.wait(0.25)
	overlay.Visible = false
end

local function pump()
	if playing then
		return
	end
	playing = true
	while #queue > 0 do
		play(table.remove(queue, 1))
	end
	playing = false
end

function RevealController.Start(root: ScreenGui)
	build(root)
	Remotes.Event("Discovered").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		table.insert(queue, payload)
		task.spawn(pump)
	end)
end

return RevealController
