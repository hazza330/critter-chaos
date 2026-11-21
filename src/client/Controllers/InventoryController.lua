--[[
	InventoryController
	The inventory screen: every creature the player owns.

	  * Search by name, sort (rarity, income, level, newest, name), filter by island
	  * Favourites only toggle
	  * Cards show model thumbnail, name, rarity colour, level, income, equipped and
	    favourite badges
	  * Detail pane: stats, discovery date, ability, comparison with your weakest
	    equipped creature, Equip/Unequip and Favourite buttons
	  * Equip Best and Unequip All

	All changes go through the InventoryAction RemoteFunction. The server
	checks them and sends fresh data back, and the screen redraws from that.
	Cards are cached per uid, so redraws don't rebuild every 3D thumbnail.
]]

local Shared = game:GetService("ReplicatedStorage").Shared
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Islands = require(Shared.Config.Islands)
local Economy = require(Shared.Config.Economy)
local CreatureStats = require(Shared.CreatureStats)
local Remotes = require(Shared.Remotes)
local UI = require(script.Parent.Parent.UI)
local Viewport = require(script.Parent.Parent.Viewport)
local ClientData = require(script.Parent.Parent.ClientData)
local NotifyController = require(script.Parent.NotifyController)

local InventoryController = {}

local SORTS = { "Rarity", "Income", "Level", "Newest", "Name" }
local ISLAND_KEYS = { "All" }
for key in pairs(Islands.Info) do
	table.insert(ISLAND_KEYS, key)
end

local panel: Frame
local grid: ScrollingFrame
local headerInfo: TextLabel
local searchBox: TextBox
local sortButton: TextButton
local islandButton: TextButton
local favButton: TextButton
local emptyLabel: TextLabel

local detail: Frame
local detailView: Frame
local detailName: TextLabel
local detailRarity: TextLabel
local detailStats: TextLabel
local equipButton: TextButton
local favouriteButton: TextButton

local sortIndex = 1
local islandIndex = 1
local favOnly = false
local selectedUid: string? = nil
local shownUid: string? = nil
local busy = false

type Card = { button: TextButton, nameLabel: TextLabel, infoLabel: TextLabel, badge: TextLabel, star: TextLabel }
local cards: { [string]: Card } = {}

-------------------------------------------------------------------------------
-- Server calls
-------------------------------------------------------------------------------

local function request(action: string, uid: string?)
	if busy then
		return
	end
	busy = true
	local ok, result, message = pcall(function()
		return Remotes.Function("InventoryAction"):InvokeServer(action, uid)
	end)
	busy = false
	if not ok then
		NotifyController.Show("Couldn't reach the server, try again", "error")
	elseif not result and message then
		NotifyController.Show(message, "error")
	end
end

-------------------------------------------------------------------------------
-- Detail pane
-------------------------------------------------------------------------------

local function weakestEquippedIncome(data): number?
	local weakest = nil
	for _, uid in ipairs(data.equipped) do
		local entry = data.creatures[uid]
		if entry then
			local income = CreatureStats.Income(entry)
			if not weakest or income < weakest then
				weakest = income
			end
		end
	end
	return weakest
end

local function showDetail()
	local data = ClientData.Get()
	local entry = data and selectedUid and data.creatures[selectedUid]
	if not data or not entry then
		detail.Visible = false
		shownUid = nil
		return
	end
	local creature = Creatures.Get(entry.id)
	if not creature then
		detail.Visible = false
		return
	end
	detail.Visible = true
	local rarity = Rarities.Info[creature.rarity]
	local income = CreatureStats.Income(entry)
	local equipped = table.find(data.equipped, selectedUid) ~= nil

	if shownUid ~= selectedUid then
		shownUid = selectedUid
		for _, child in ipairs(detailView:GetChildren()) do
			child:Destroy()
		end
		Viewport.Show(detailView, entry.id, { spin = true })
	end

	detailName.Text = creature.name
	detailRarity.Text = creature.rarity .. "  ·  " .. creature.element
	detailRarity.TextColor3 = rarity.color

	local island = Islands.Get(creature.island)
	local compare
	local weakest = weakestEquippedIncome(data)
	if equipped then
		compare = "Currently equipped"
	elseif not weakest then
		compare = "Nothing equipped yet"
	elseif #data.equipped < CreatureStats.EquipLimit(data) then
		compare = ("Free slot: +%d coins"):format(income)
	else
		local diff = income - weakest
		compare = if diff > 0
			then ("+%d vs your weakest equipped"):format(diff)
			elseif diff < 0 then ("%d vs your weakest equipped"):format(diff)
			else "Same as your weakest equipped"
	end

	detailStats.Text = table.concat({
		("Level %d"):format(entry.level or 1),
		("Income: %d coins / %ds"):format(income, Economy.IncomeInterval),
		("Island: %s"):format(if island then island.displayName else creature.island),
		("Found: %s"):format(os.date("%d %b %Y", entry.t or 0)),
		("Ability: %s"):format(creature.ability),
		compare,
	}, "\n")

	equipButton.Text = if equipped then "Unequip" else "Equip"
	equipButton.BackgroundColor3 = if equipped then UI.Colors.Bad else UI.Colors.Good
	favouriteButton.Text = if entry.fav then "★ Favourited" else "☆ Favourite"
end

-------------------------------------------------------------------------------
-- Grid
-------------------------------------------------------------------------------

local function makeCard(uid: string, entry): Card
	local creature = Creatures.Get(entry.id)
	local rarity = Rarities.Info[creature.rarity]
	local button = UI.new("TextButton", {
		Name = uid,
		BackgroundColor3 = UI.Colors.PanelLight,
		Text = "",
		AutoButtonColor = false,
		Parent = grid,
	}, { UI.corner(12) })
	UI.new("UIStroke", { Name = "Border", Color = rarity.color, Thickness = 3, Parent = button })
	UI.animateButton(button)

	local view = UI.new("Frame", {
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.new(1, -12, 0, 70),
		BackgroundTransparency = 1,
		Parent = button,
	})
	Viewport.Show(view, entry.id)

	local nameLabel = UI.new("TextLabel", {
		Position = UDim2.new(0, 4, 1, -44),
		Size = UDim2.new(1, -8, 0, 20),
		BackgroundTransparency = 1,
		Text = creature.name,
		Font = UI.Font,
		TextScaled = true,
		TextColor3 = UI.Colors.Text,
		Parent = button,
	})
	local infoLabel = UI.new("TextLabel", {
		Position = UDim2.new(0, 4, 1, -22),
		Size = UDim2.new(1, -8, 0, 18),
		BackgroundTransparency = 1,
		Text = "",
		Font = UI.BodyFont,
		TextSize = 13,
		TextColor3 = rarity.color,
		Parent = button,
	})
	local badge = UI.new("TextLabel", {
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = UI.Colors.Good,
		Text = "E",
		Font = UI.Font,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 3,
		Parent = button,
	}, { UI.corner(11) })
	local star = UI.new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 2),
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1,
		Text = "★",
		Font = UI.Font,
		TextSize = 20,
		TextColor3 = UI.Colors.Coin,
		Visible = false,
		ZIndex = 3,
		Parent = button,
	})

	button.Activated:Connect(function()
		selectedUid = uid
		showDetail()
	end)

	return { button = button, nameLabel = nameLabel, infoLabel = infoLabel, badge = badge, star = star }
end

local function sortKey(a, b, data): boolean
	local ea, eb = a.entry, b.entry
	local equippedA = table.find(data.equipped, a.uid) ~= nil
	local equippedB = table.find(data.equipped, b.uid) ~= nil
	if equippedA ~= equippedB then
		return equippedA
	end
	if ea.fav ~= eb.fav then
		return ea.fav == true
	end
	local ca, cb = Creatures.Get(ea.id), Creatures.Get(eb.id)
	local mode = SORTS[sortIndex]
	if mode == "Rarity" then
		local ra, rb = Rarities.Info[ca.rarity].rank, Rarities.Info[cb.rarity].rank
		if ra ~= rb then
			return ra > rb
		end
	elseif mode == "Income" then
		local ia, ib = CreatureStats.Income(ea), CreatureStats.Income(eb)
		if ia ~= ib then
			return ia > ib
		end
	elseif mode == "Level" then
		if (ea.level or 1) ~= (eb.level or 1) then
			return (ea.level or 1) > (eb.level or 1)
		end
	elseif mode == "Newest" then
		return tonumber(a.uid) > tonumber(b.uid)
	elseif mode == "Name" then
		if ca.name ~= cb.name then
			return ca.name < cb.name
		end
	end
	return tonumber(a.uid) < tonumber(b.uid)
end

local function refresh()
	if not panel.Visible then
		return
	end
	local data = ClientData.Get()
	if not data then
		return
	end

	-- Create and remove cards to match owned creatures.
	for uid, card in pairs(cards) do
		if not data.creatures[uid] then
			card.button:Destroy()
			cards[uid] = nil
		end
	end
	local list = {}
	local total = 0
	for uid, entry in pairs(data.creatures) do
		if Creatures.Get(entry.id) then
			total += 1
			if not cards[uid] then
				cards[uid] = makeCard(uid, entry)
			end
			table.insert(list, { uid = uid, entry = entry })
		end
	end
	table.sort(list, function(a, b)
		return sortKey(a, b, data)
	end)

	local query = searchBox.Text:lower()
	local islandFilter = ISLAND_KEYS[islandIndex]
	local shown = 0
	for index, item in ipairs(list) do
		local card = cards[item.uid]
		local creature = Creatures.Get(item.entry.id)
		local matches = (query == "" or creature.name:lower():find(query, 1, true) ~= nil)
			and (islandFilter == "All" or creature.island == islandFilter)
			and (not favOnly or item.entry.fav == true)
		card.button.Visible = matches
		card.button.LayoutOrder = index
		if matches then
			shown += 1
		end
		local equipped = table.find(data.equipped, item.uid) ~= nil
		card.badge.Visible = equipped
		card.star.Visible = item.entry.fav == true
		card.button.BackgroundColor3 = if equipped then Color3.fromRGB(52, 80, 70) else UI.Colors.PanelLight
		card.infoLabel.Text = ("Lv %d · %d/%ds"):format(item.entry.level or 1, CreatureStats.Income(item.entry), Economy.IncomeInterval)
	end

	emptyLabel.Visible = shown == 0
	emptyLabel.Text = if total == 0
		then "No creatures yet. Search the sparkling bushes in Creature Meadow!"
		else "Nothing matches your search."

	headerInfo.Text = ("Equipped %d/%d  ·  %d/%d creatures"):format(
		#data.equipped,
		CreatureStats.EquipLimit(data),
		total,
		Economy.CollectionCapacity
	)
	showDetail()
end

-------------------------------------------------------------------------------
-- Build
-------------------------------------------------------------------------------

local function toolbarButton(parent: Instance, text: string, width: number, color: Color3, order: number): TextButton
	local button = UI.new("TextButton", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(width, 34),
		BackgroundColor3 = color,
		Text = text,
		Font = UI.Font,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Parent = parent,
	}, { UI.corner(10) })
	UI.animateButton(button)
	return button
end

local function build(root: ScreenGui)
	panel = UI.new("Frame", {
		Name = "Inventory",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(860, 520),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		ZIndex = 10,
		Parent = root,
	}, { UI.corner(20), UI.stroke(Color3.new(0, 0, 0), 3) })

	UI.new("TextLabel", {
		Position = UDim2.fromOffset(20, 12),
		Size = UDim2.fromOffset(200, 40),
		BackgroundTransparency = 1,
		Text = "Inventory",
		Font = UI.Font,
		TextSize = 34,
		TextColor3 = UI.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	headerInfo = UI.new("TextLabel", {
		Position = UDim2.fromOffset(190, 20),
		Size = UDim2.new(1, -260, 0, 30),
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
		InventoryController.Toggle(false)
	end)

	-- Toolbar
	local toolbar = UI.new("Frame", {
		Position = UDim2.fromOffset(20, 62),
		Size = UDim2.new(1, -40, 0, 34),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	searchBox = UI.new("TextBox", {
		LayoutOrder = 1,
		Size = UDim2.fromOffset(170, 34),
		BackgroundColor3 = UI.Colors.PanelLight,
		PlaceholderText = "Search...",
		PlaceholderColor3 = UI.Colors.Muted,
		Text = "",
		ClearTextOnFocus = false,
		Font = UI.BodyFont,
		TextSize = 16,
		TextColor3 = UI.Colors.Text,
		Parent = toolbar,
	}, { UI.corner(10), UI.padding(6) })
	searchBox:GetPropertyChangedSignal("Text"):Connect(refresh)

	sortButton = toolbarButton(toolbar, "Sort: Rarity", 130, Color3.fromRGB(90, 110, 180), 2)
	sortButton.Activated:Connect(function()
		sortIndex = sortIndex % #SORTS + 1
		sortButton.Text = "Sort: " .. SORTS[sortIndex]
		refresh()
	end)

	islandButton = toolbarButton(toolbar, "Island: All", 150, Color3.fromRGB(70, 150, 160), 3)
	islandButton.Activated:Connect(function()
		islandIndex = islandIndex % #ISLAND_KEYS + 1
		local key = ISLAND_KEYS[islandIndex]
		local info = Islands.Get(key)
		islandButton.Text = "Island: " .. (if info then info.displayName else "All")
		refresh()
	end)

	favButton = toolbarButton(toolbar, "☆ Favourites", 120, Color3.fromRGB(150, 120, 60), 4)
	favButton.Activated:Connect(function()
		favOnly = not favOnly
		favButton.Text = if favOnly then "★ Favourites" else "☆ Favourites"
		refresh()
	end)

	local best = toolbarButton(toolbar, "Equip Best", 110, UI.Colors.Good, 5)
	best.Activated:Connect(function()
		request("equipBest")
	end)
	local clear = toolbarButton(toolbar, "Unequip All", 110, Color3.fromRGB(120, 120, 140), 6)
	clear.Activated:Connect(function()
		request("unequipAll")
	end)

	-- Grid
	grid = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(20, 106),
		Size = UDim2.new(1, -310, 1, -126),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(100, 124),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UI.padding(4),
	})
	emptyLabel = UI.new("TextLabel", {
		Position = UDim2.fromOffset(20, 200),
		Size = UDim2.new(1, -330, 0, 60),
		BackgroundTransparency = 1,
		Text = "",
		Font = UI.BodyFont,
		TextSize = 18,
		TextWrapped = true,
		TextColor3 = UI.Colors.Muted,
		Visible = false,
		Parent = panel,
	})

	-- Detail pane
	detail = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 106),
		Size = UDim2.new(0, 270, 1, -126),
		BackgroundColor3 = UI.Colors.PanelLight,
		Visible = false,
		Parent = panel,
	}, { UI.corner(14), UI.padding(12) })
	detailView = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundTransparency = 1,
		Parent = detail,
	})
	detailName = UI.new("TextLabel", {
		Position = UDim2.fromOffset(0, 122),
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		Font = UI.Font,
		TextScaled = true,
		TextColor3 = UI.Colors.Text,
		Parent = detail,
	})
	detailRarity = UI.new("TextLabel", {
		Position = UDim2.fromOffset(0, 150),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Font = UI.Font,
		TextSize = 17,
		Parent = detail,
	})
	detailStats = UI.new("TextLabel", {
		Position = UDim2.fromOffset(0, 176),
		Size = UDim2.new(1, 0, 1, -226),
		BackgroundTransparency = 1,
		Font = UI.BodyFont,
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = detail,
	})
	equipButton = UI.new("TextButton", {
		Position = UDim2.new(0, 0, 1, -42),
		Size = UDim2.new(0.5, -4, 0, 40),
		BackgroundColor3 = UI.Colors.Good,
		Text = "Equip",
		Font = UI.Font,
		TextSize = 18,
		TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Parent = detail,
	}, { UI.corner(10) })
	UI.animateButton(equipButton)
	equipButton.Activated:Connect(function()
		local data = ClientData.Get()
		if not data or not selectedUid then
			return
		end
		local equipped = table.find(data.equipped, selectedUid) ~= nil
		request(if equipped then "unequip" else "equip", selectedUid)
	end)
	favouriteButton = UI.new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 1, -42),
		Size = UDim2.new(0.5, -4, 0, 40),
		BackgroundColor3 = Color3.fromRGB(150, 120, 60),
		Text = "☆ Favourite",
		Font = UI.Font,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Parent = detail,
	}, { UI.corner(10) })
	UI.animateButton(favouriteButton)
	favouriteButton.Activated:Connect(function()
		if selectedUid then
			request("favourite", selectedUid)
		end
	end)
end

-- Other panels register here so opening one closes the rest.
local closeOthers: (() -> ())? = nil
function InventoryController.SetCloseOthers(fn: () -> ())
	closeOthers = fn
end

function InventoryController.Toggle(force: boolean?)
	local show = if force ~= nil then force else not panel.Visible
	if show and closeOthers then
		closeOthers()
	end
	panel.Visible = show
	if show then
		refresh()
	end
end

function InventoryController.IsOpen(): boolean
	return panel.Visible
end

function InventoryController.Start(root: ScreenGui, hud)
	build(root)
	ClientData.Changed:Connect(refresh)
	hud.AddMenuButton("Inventory", Color3.fromRGB(110, 200, 120), 2, function()
		InventoryController.Toggle()
	end)
end

return InventoryController
