--[[
	HudController
	Always-visible HUD:
	  top left   level badge and XP bar
	  top right  coins and gems
	  bottom     menu buttons (only ones whose panels exist are shown)
]]

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Remotes)
local UI = require(script.Parent.Parent.UI)
local ClientData = require(script.Parent.Parent.ClientData)

local HudController = {}

local levelLabel: TextLabel
local xpFill: Frame
local xpText: TextLabel
local coinLabel: TextLabel
local gemLabel: TextLabel
local bottomBar: Frame

local lastCoins: number? = nil

local function currencyPill(parent: Instance, order: number, color: Color3, icon: string): TextLabel
	local pill = UI.new("Frame", {
		Name = "Pill",
		LayoutOrder = order,
		Size = UDim2.fromOffset(170, 44),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		Parent = parent,
	}, { UI.corner(22), UI.stroke() })
	UI.new("TextLabel", {
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.fromOffset(4, 4),
		BackgroundColor3 = color,
		Text = icon,
		Font = UI.Font,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(60, 40, 20),
		Parent = pill,
	}, { UI.corner(18) })
	return UI.new("TextLabel", {
		Size = UDim2.new(1, -52, 1, 0),
		Position = UDim2.fromOffset(46, 0),
		BackgroundTransparency = 1,
		Text = "0",
		Font = UI.Font,
		TextSize = 24,
		TextColor3 = UI.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = pill,
	})
end

local function build(root: ScreenGui)
	-- Top left: level and XP
	local levelFrame = UI.new("Frame", {
		Name = "Level",
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(250, 56),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		Parent = root,
	}, { UI.corner(16), UI.stroke() })

	levelLabel = UI.new("TextLabel", {
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.fromOffset(4, 4),
		BackgroundColor3 = UI.Colors.Accent,
		Text = "1",
		Font = UI.Font,
		TextSize = 24,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = levelFrame,
	}, { UI.corner(24) })

	local bar = UI.new("Frame", {
		Size = UDim2.new(1, -68, 0, 18),
		Position = UDim2.new(0, 60, 0.5, 4),
		BackgroundColor3 = Color3.fromRGB(20, 22, 36),
		Parent = levelFrame,
	}, { UI.corner(9) })
	xpFill = UI.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = UI.Colors.Good,
		Parent = bar,
	}, { UI.corner(9) })
	xpText = UI.new("TextLabel", {
		Size = UDim2.new(1, -68, 0, 20),
		Position = UDim2.new(0, 60, 0, 4),
		BackgroundTransparency = 1,
		Text = "XP",
		Font = UI.BodyFont,
		TextSize = 14,
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = levelFrame,
	})

	-- Top right: currencies
	local currencies = UI.new("Frame", {
		Name = "Currencies",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(170, 100),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		UI.new("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
		}),
	})
	coinLabel = currencyPill(currencies, 1, UI.Colors.Coin, "C")
	gemLabel = currencyPill(currencies, 2, UI.Colors.Gem, "G")

	-- Bottom: menu buttons
	bottomBar = UI.new("Frame", {
		Name = "BottomBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(400, 64),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

-- Adds a bottom-bar button. Controllers call this so a button only exists
-- when its panel really works.
function HudController.AddMenuButton(text: string, color: Color3, order: number, onClick: () -> ()): TextButton
	local button = UI.new("TextButton", {
		Name = text,
		LayoutOrder = order,
		Size = UDim2.fromOffset(130, 60),
		BackgroundColor3 = color,
		Text = text,
		Font = UI.Font,
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Parent = bottomBar,
	}, { UI.corner(16), UI.stroke(Color3.new(0, 0, 0), 3) })
	UI.new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Thickness = 2,
		Color = Color3.fromRGB(40, 30, 60),
		Parent = button,
	})
	UI.animateButton(button)
	button.Activated:Connect(onClick)
	return button
end

local function refresh(data)
	local needed = Economy.XPToNextLevel(data.level)
	local ratio = if data.level >= Economy.MaxLevel then 1 else math.clamp(data.xp / needed, 0, 1)
	levelLabel.Text = tostring(data.level)
	xpText.Text = if data.level >= Economy.MaxLevel then "MAX LEVEL" else ("%d / %d XP"):format(data.xp, needed)
	TweenService:Create(xpFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(ratio, 1) }):Play()

	coinLabel.Text = UI.formatNumber(data.coins)
	gemLabel.Text = UI.formatNumber(data.gems)

	-- Little bounce when coins go up.
	if lastCoins and data.coins > lastCoins then
		local pill = coinLabel.Parent :: Frame
		local scale = pill:FindFirstChildOfClass("UIScale") or UI.new("UIScale", { Parent = pill })
		scale.Scale = 1.12
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	lastCoins = data.coins
end

-- "+N" that floats up from the coin counter when creatures pay out.
local function floatIncome(amount: number)
	local pill = coinLabel.Parent :: Frame
	local label = UI.new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0, -8, 0, 8),
		Size = UDim2.fromOffset(120, 28),
		BackgroundTransparency = 1,
		Text = "+" .. UI.formatNumber(amount),
		Font = UI.Font,
		TextSize = 24,
		TextColor3 = UI.Colors.Coin,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = pill,
	}, { UI.new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(60, 40, 10) }) })
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, info, { Position = UDim2.new(0, -8, 0, 40), TextTransparency = 1 }):Play()
	TweenService:Create(label:FindFirstChildOfClass("UIStroke"), info, { Transparency = 1 }):Play()
	task.delay(1.25, function()
		label:Destroy()
	end)
end

function HudController.Start(root: ScreenGui)
	build(root)
	Remotes.Event("Income").OnClientEvent:Connect(function(amount)
		if type(amount) == "number" then
			floatIncome(amount)
		end
	end)
	ClientData.Changed:Connect(refresh)
	local data = ClientData.Get()
	if data then
		refresh(data)
	end
end

return HudController
