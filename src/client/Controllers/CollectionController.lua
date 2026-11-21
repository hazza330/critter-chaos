--[[
	CollectionController
	The Collection book: every species, discovered ones in full colour with how
	many you own, undiscovered ones as "???" silhouettes. Selecting a card shows
	its details. Filter by rarity tabs.

	Stage 2 extends this into the full inventory (equip, favourite, sort, search).
]]

local Shared = game:GetService("ReplicatedStorage").Shared
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local UI = require(script.Parent.Parent.UI)
local ClientData = require(script.Parent.Parent.ClientData)

local CollectionController = {}

local panel: Frame
local grid: ScrollingFrame
local countLabel: TextLabel
local detail: Frame
local detailName: TextLabel
local detailRarity: TextLabel
local detailText: TextLabel
local filter: string? = nil

local function ownedCounts(data): { [number]: number }
	local counts = {}
	for _, entry in pairs(data.creatures) do
		counts[entry.id] = (counts[entry.id] or 0) + 1
	end
	return counts
end

local function showDetail(creature, discovered: boolean, owned: number)
	detail.Visible = true
	if discovered then
		local rarity = Rarities.Info[creature.rarity]
		detailName.Text = ("#%03d  %s"):format(creature.id, creature.name)
		detailRarity.Text = creature.rarity .. "  ·  " .. creature.element
		detailRarity.TextColor3 = rarity.color
		detailText.Text = ("%s\n\nPersonality: %s\nAbility: %s\nOwned: %d"):format(
			creature.description,
			creature.personality,
			creature.ability,
			owned
		)
	else
		detailName.Text = ("#%03d  ???"):format(creature.id)
		detailRarity.Text = creature.rarity
		detailRarity.TextColor3 = UI.Colors.Muted
		detailText.Text = "Not discovered yet. Keep searching!"
	end
end

local function refresh()
	if not panel.Visible then
		return
	end
	local data = ClientData.Get()
	if not data then
		return
	end
	local counts = ownedCounts(data)

	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end

	local found = 0
	for _, creature in ipairs(Creatures.List) do
		local discovered = data.discovered[tostring(creature.id)] ~= nil
		if discovered then
			found += 1
		end
		if filter == nil or creature.rarity == filter then
			local rarity = Rarities.Info[creature.rarity]
			local owned = counts[creature.id] or 0
			local card = UI.new("TextButton", {
				Name = creature.name,
				LayoutOrder = creature.id,
				BackgroundColor3 = if discovered then UI.Colors.PanelLight else Color3.fromRGB(28, 30, 44),
				Text = "",
				AutoButtonColor = false,
				Parent = grid,
			}, { UI.corner(12), UI.new("UIStroke", { Color = rarity.color, Thickness = 3 }) })
			UI.animateButton(card)

			-- Stage 2 swaps this coloured circle for a live model thumbnail.
			UI.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 10),
				Size = UDim2.fromOffset(56, 56),
				BackgroundColor3 = if discovered then creature.color else Color3.fromRGB(15, 15, 22),
				Parent = card,
			}, { UI.corner(28) })
			UI.new("TextLabel", {
				Position = UDim2.new(0, 4, 1, -44),
				Size = UDim2.new(1, -8, 0, 22),
				BackgroundTransparency = 1,
				Text = if discovered then creature.name else "???",
				Font = UI.Font,
				TextScaled = true,
				TextColor3 = UI.Colors.Text,
				Parent = card,
			})
			UI.new("TextLabel", {
				Position = UDim2.new(0, 4, 1, -22),
				Size = UDim2.new(1, -8, 0, 18),
				BackgroundTransparency = 1,
				Text = if discovered then ("x%d"):format(owned) else creature.rarity,
				Font = UI.BodyFont,
				TextSize = 14,
				TextColor3 = rarity.color,
				Parent = card,
			})
			card.Activated:Connect(function()
				showDetail(creature, discovered, owned)
			end)
		end
	end
	countLabel.Text = ("%d / %d species discovered"):format(found, #Creatures.List)
end

local function build(root: ScreenGui)
	panel = UI.new("Frame", {
		Name = "Collection",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(760, 480),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		ZIndex = 10,
		Parent = root,
	}, { UI.corner(20), UI.stroke(Color3.new(0, 0, 0), 3) })

	UI.new("TextLabel", {
		Position = UDim2.fromOffset(20, 12),
		Size = UDim2.new(1, -80, 0, 40),
		BackgroundTransparency = 1,
		Text = "Collection",
		Font = UI.Font,
		TextSize = 34,
		TextColor3 = UI.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	countLabel = UI.new("TextLabel", {
		Position = UDim2.fromOffset(200, 20),
		Size = UDim2.new(1, -280, 0, 30),
		BackgroundTransparency = 1,
		Text = "",
		Font = UI.BodyFont,
		TextSize = 18,
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})

	local close = UI.new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = UI.Colors.Bad,
		Text = "X",
		Font = UI.Font,
		TextSize = 24,
		TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Parent = panel,
	}, { UI.corner(12) })
	UI.animateButton(close)
	close.Activated:Connect(function()
		CollectionController.Toggle(false)
	end)

	-- Rarity filter tabs
	local tabs = UI.new("Frame", {
		Position = UDim2.fromOffset(20, 62),
		Size = UDim2.new(1, -40, 0, 32),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local tabList = { "All", "Common", "Uncommon", "Rare", "Epic", "Legendary" }
	for i, name in ipairs(tabList) do
		local info = Rarities.Info[name]
		local tab = UI.new("TextButton", {
			LayoutOrder = i,
			Size = UDim2.fromOffset(98, 32),
			BackgroundColor3 = if info then info.color else UI.Colors.Accent,
			Text = name,
			Font = UI.Font,
			TextSize = 16,
			TextColor3 = Color3.fromRGB(30, 30, 40),
			AutoButtonColor = false,
			Parent = tabs,
		}, { UI.corner(10) })
		UI.animateButton(tab)
		tab.Activated:Connect(function()
			filter = if name == "All" then nil else name
			refresh()
		end)
	end

	grid = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(20, 104),
		Size = UDim2.new(1, -300, 1, -124),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(104, 124),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UI.padding(4),
	})

	detail = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 104),
		Size = UDim2.new(0, 250, 1, -124),
		BackgroundColor3 = UI.Colors.PanelLight,
		Visible = false,
		Parent = panel,
	}, { UI.corner(14), UI.padding(14) })
	detailName = UI.new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Font = UI.Font,
		TextScaled = true,
		TextColor3 = UI.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = detail,
	})
	detailRarity = UI.new("TextLabel", {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Font = UI.Font,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = detail,
	})
	detailText = UI.new("TextLabel", {
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 1, -66),
		BackgroundTransparency = 1,
		Font = UI.BodyFont,
		TextSize = 16,
		TextWrapped = true,
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = detail,
	})
end

function CollectionController.Toggle(force: boolean?)
	local show = if force ~= nil then force else not panel.Visible
	panel.Visible = show
	if show then
		detail.Visible = false
		refresh()
	end
end

function CollectionController.Start(root: ScreenGui, hud)
	build(root)
	ClientData.Changed:Connect(refresh)
	hud.AddMenuButton("Collection", Color3.fromRGB(90, 170, 255), 1, function()
		CollectionController.Toggle()
	end)
end

return CollectionController
