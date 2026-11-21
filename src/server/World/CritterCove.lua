--[[
	CritterCove
	Builds the starting island from code when the server starts, so the map lives
	in version control alongside the scripts. Later you can replace any part of
	this with hand-built models in Studio; the services only care about the
	"DiscoverySpot" tag and the SpawnLocation.

	Stage 1 contents
	  * Terrain island with sand beach, grass, hills and a pond, surrounded by sea
	  * Spawn Plaza: spawn pad, CRITTER CHAOS sign, welcome board, signpost
	  * Creature Meadow: trees, flowers, six discovery bushes
	  * Path from the plaza to the meadow
	  * Marked plots for districts that arrive in later stages

	Performance: everything is anchored, decorations have CanQuery/CanTouch off,
	and particle rates are kept low.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local CritterCove = {}

local GROUND_FALLBACK = 3
local rng = Random.new(1337) -- fixed seed so the island looks the same every server

local mapFolder: Folder
local decorFolder: Folder

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { workspace.Terrain }

-- Height of the terrain surface at x, z.
local function groundY(x: number, z: number): number
	local result = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), rayParams)
	return if result then result.Position.Y else GROUND_FALLBACK
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent or decorFolder
	return p
end

local function decor(p: BasePart)
	p.CanQuery = false
	p.CanTouch = false
end

local function surfaceText(target: BasePart, face: Enum.NormalId, text: string, opts: { [string]: any }?)
	local options = opts or {}
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.Parent = target

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = options.scaled ~= false
	label.TextSize = options.textSize or 40
	label.TextWrapped = true
	label.RichText = true
	label.Font = options.font or Enum.Font.FredokaOne
	label.TextColor3 = options.color or Color3.new(1, 1, 1)
	label.TextXAlignment = options.alignX or Enum.TextXAlignment.Center
	label.TextYAlignment = options.alignY or Enum.TextYAlignment.Center
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	local pad = UDim.new(0, options.padding or 20)
	padding.PaddingLeft, padding.PaddingRight, padding.PaddingTop, padding.PaddingBottom = pad, pad, pad, pad
	padding.Parent = label

	if options.stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(40, 30, 60)
		stroke.Parent = label
	end
	return gui
end

-------------------------------------------------------------------------------
-- Terrain and lighting
-------------------------------------------------------------------------------

local function buildTerrain()
	local terrain = workspace.Terrain
	terrain:Clear()

	-- Sea
	terrain:FillBlock(CFrame.new(0, -10, 0), Vector3.new(1600, 20, 1600), Enum.Material.Water)
	-- Sea bed so water isn't bottomless
	terrain:FillBlock(CFrame.new(0, -24, 0), Vector3.new(1600, 8, 1600), Enum.Material.Sand)

	-- Beach and main grass plateau
	terrain:FillCylinder(CFrame.new(0, -4, 0), 12, 240, Enum.Material.Sand)
	terrain:FillCylinder(CFrame.new(0, -2, 0), 12, 215, Enum.Material.Grass)

	-- Hills give the meadow some shape (kept away from the plaza)
	terrain:FillBall(Vector3.new(170, -12, 90), 40, Enum.Material.Grass)
	terrain:FillBall(Vector3.new(150, -16, -110), 36, Enum.Material.Grass)
	terrain:FillBall(Vector3.new(-120, -20, -150), 45, Enum.Material.Rock)
	terrain:FillBall(Vector3.new(-160, -14, 120), 32, Enum.Material.LeafyGrass)

	-- Meadow pond
	terrain:FillCylinder(CFrame.new(110, 2, 30), 6, 16, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(110, -1, 30), 4, 16, Enum.Material.Water)
end

local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.2
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 160)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(199, 225, 255)
	atmosphere.Decay = Color3.fromRGB(120, 160, 210)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	grade.Saturation = 0.15
	grade.Contrast = 0.05
	grade.Parent = Lighting
end

-------------------------------------------------------------------------------
-- Props
-------------------------------------------------------------------------------

local LEAF_COLOURS = {
	Color3.fromRGB(92, 184, 92),
	Color3.fromRGB(70, 160, 80),
	Color3.fromRGB(120, 200, 90),
}

local function tree(x: number, z: number, scale: number)
	local y = groundY(x, z)
	local height = 10 * scale
	local trunk = part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 1.6 * scale, 1.6 * scale),
		CFrame = CFrame.new(x, y + height / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(120, 85, 60),
		Material = Enum.Material.Wood,
	})
	decor(trunk)
	local leafColour = LEAF_COLOURS[rng:NextInteger(1, #LEAF_COLOURS)]
	for i = 1, 3 do
		local size = (6 - i) * scale * 1.3
		local offset = Vector3.new(rng:NextNumber(-1.5, 1.5), height + (i - 1) * 1.8 * scale, rng:NextNumber(-1.5, 1.5))
		local leaf = part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			Position = Vector3.new(x, y, z) + offset,
			Color = leafColour,
			Material = Enum.Material.SmoothPlastic,
		})
		decor(leaf)
		leaf.CanCollide = false
	end
end

local FLOWER_COLOURS = {
	Color3.fromRGB(255, 120, 160),
	Color3.fromRGB(255, 220, 90),
	Color3.fromRGB(170, 130, 255),
	Color3.fromRGB(255, 255, 255),
}

local function flower(x: number, z: number)
	local y = groundY(x, z)
	local stem = part({
		Name = "Stem",
		Size = Vector3.new(0.2, 1.2, 0.2),
		Position = Vector3.new(x, y + 0.6, z),
		Color = Color3.fromRGB(80, 150, 60),
		CanCollide = false,
	})
	decor(stem)
	local head = part({
		Name = "Petals",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.8, 0.8, 0.8),
		Position = Vector3.new(x, y + 1.3, z),
		Color = FLOWER_COLOURS[rng:NextInteger(1, #FLOWER_COLOURS)],
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	decor(head)
end

local function discoveryBush(x: number, z: number, name: string)
	local y = groundY(x, z)
	local model = Instance.new("Model")
	model.Name = "DiscoveryBush_" .. name
	model.Parent = mapFolder

	-- The tagged part is what the service hooks into.
	local hitbox = part({
		Name = "Spot",
		Size = Vector3.new(6, 4, 6),
		Position = Vector3.new(x, y + 2, z),
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})
	hitbox:SetAttribute("IslandId", "CritterCove")
	hitbox:SetAttribute("SpotName", "Rustling Bush")
	CollectionService:AddTag(hitbox, "DiscoverySpot")
	model.PrimaryPart = hitbox

	for i = 1, 3 do
		local size = 3.2 + rng:NextNumber(0, 1.2)
		local bush = part({
			Name = "Bush",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			Position = Vector3.new(x + (i - 2) * 1.6, y + size / 2 - 0.3, z + rng:NextNumber(-0.8, 0.8)),
			Color = Color3.fromRGB(60, 150, 70),
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
		decor(bush)
	end

	-- A few slow sparkles so players can spot interactive bushes.
	local attachment = Instance.new("Attachment")
	attachment.Parent = hitbox
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 2
	sparkle.Lifetime = NumberRange.new(1, 1.6)
	sparkle.Speed = NumberRange.new(1, 2)
	sparkle.SpreadAngle = Vector2.new(60, 60)
	sparkle.Size = NumberSequence.new(0.4, 0)
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160))
	sparkle.LightEmission = 0.8
	sparkle.Parent = attachment
end

-------------------------------------------------------------------------------
-- Areas
-------------------------------------------------------------------------------

local function buildSpawnPlaza()
	local y = groundY(0, 0)

	local plaza = part({
		Name = "PlazaFloor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 64, 64),
		CFrame = CFrame.new(0, y + 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(236, 222, 190),
		Material = Enum.Material.Slate,
		Parent = mapFolder,
	})
	plaza.CanQuery = false

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CoveSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, y + 1.2, 0)
	spawn.Color = Color3.fromRGB(255, 200, 90)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = mapFolder

	-- Big sign behind spawn, facing the spawn point.
	local signBoard = part({
		Name = "CritterChaosSign",
		Size = Vector3.new(44, 12, 1.5),
		CFrame = CFrame.new(0, y + 16, -34),
		Color = Color3.fromRGB(255, 140, 60),
		Material = Enum.Material.SmoothPlastic,
		Parent = mapFolder,
	})
	surfaceText(signBoard, Enum.NormalId.Front, "CRITTER CHAOS", { stroke = true, padding = 30 })
	for _, side in ipairs({ -18, 18 }) do
		part({
			Name = "SignPost",
			Size = Vector3.new(2, 16, 2),
			Position = Vector3.new(side, y + 8, -34),
			Color = Color3.fromRGB(120, 85, 60),
			Material = Enum.Material.Wood,
			Parent = mapFolder,
		})
	end

	-- Welcome board: real instructions, no buttons.
	local board = part({
		Name = "WelcomeBoard",
		Size = Vector3.new(14, 10, 1),
		CFrame = CFrame.new(-24, y + 6, -14) * CFrame.Angles(0, math.rad(40), 0),
		Color = Color3.fromRGB(90, 60, 40),
		Material = Enum.Material.Wood,
		Parent = mapFolder,
	})
	surfaceText(
		board,
		Enum.NormalId.Front,
		'<font size="56">Welcome to Critter Cove!</font>\n\n'
			.. "Follow the path east to the Creature Meadow.\n"
			.. "Look for sparkling bushes and hold the Search prompt to discover creatures.\n\n"
			.. "Rarer creatures give more coins and XP.",
		{ scaled = true, font = Enum.Font.Gotham, alignY = Enum.TextYAlignment.Top }
	)

	-- Signpost showing where everything is. Districts not built yet say so honestly.
	local post = part({
		Name = "Signpost",
		Size = Vector3.new(1, 9, 1),
		Position = Vector3.new(26, y + 4.5, 8),
		Color = Color3.fromRGB(120, 85, 60),
		Material = Enum.Material.Wood,
		Parent = mapFolder,
	})
	local arrows = {
		{ "Creature Meadow  →", 0, Color3.fromRGB(110, 200, 110) },
		{ "Habitats (Stage 4)", 90, Color3.fromRGB(160, 160, 160) },
		{ "Marketplace (Stage 3)", 180, Color3.fromRGB(160, 160, 160) },
		{ "Trading Plaza (Stage 6)", 270, Color3.fromRGB(160, 160, 160) },
	}
	for i, info in ipairs(arrows) do
		local plank = part({
			Name = "Plank",
			Size = Vector3.new(9, 1.4, 0.3),
			CFrame = CFrame.new(post.Position + Vector3.new(0, 4.5 - i * 1.6, 0))
				* CFrame.Angles(0, math.rad(info[2]), 0)
				* CFrame.new(4, 0, 0),
			Color = info[3],
			Material = Enum.Material.Wood,
			Parent = mapFolder,
		})
		surfaceText(plank, Enum.NormalId.Front, info[1], { padding = 6 })
		surfaceText(plank, Enum.NormalId.Back, info[1], { padding = 6 })
	end
end

local function buildPath(from: Vector3, to: Vector3, width: number)
	local steps = math.ceil((to - from).Magnitude / 8)
	for i = 0, steps - 1 do
		local a = from:Lerp(to, i / steps)
		local b = from:Lerp(to, (i + 1) / steps)
		local mid = (a + b) / 2
		local y = groundY(mid.X, mid.Z)
		local slab = part({
			Name = "Path",
			Size = Vector3.new(width, 0.4, (b - a).Magnitude + 0.6),
			CFrame = CFrame.lookAt(Vector3.new(mid.X, y + 0.15, mid.Z), Vector3.new(b.X, y + 0.15, b.Z)),
			Color = Color3.fromRGB(214, 190, 150),
			Material = Enum.Material.Ground,
			CanCollide = false,
		})
		decor(slab)
	end
end

local function buildMeadow()
	-- Discovery bushes spread around the meadow, a couple tucked near the pond and hills.
	local spots = {
		{ 85, -20 },
		{ 95, 55 },
		{ 135, 10 },
		{ 140, -55 },
		{ 175, 40 },
		{ 120, 85 },
	}
	for i, pos in ipairs(spots) do
		discoveryBush(pos[1], pos[2], tostring(i))
	end

	-- Flowers scattered in the meadow
	for _ = 1, 70 do
		local x = rng:NextNumber(70, 190)
		local z = rng:NextNumber(-90, 100)
		local nearPond = (Vector2.new(x, z) - Vector2.new(110, 30)).Magnitude < 20
		if not nearPond then
			flower(x, z)
		end
	end

	local label = part({
		Name = "MeadowSign",
		Size = Vector3.new(12, 3, 0.6),
		CFrame = CFrame.new(64, groundY(64, -8) + 5, -8) * CFrame.Angles(0, math.rad(-90), 0),
		Color = Color3.fromRGB(110, 200, 110),
		Material = Enum.Material.Wood,
		Parent = mapFolder,
	})
	surfaceText(label, Enum.NormalId.Front, "Creature Meadow", { stroke = true, padding = 8 })
	surfaceText(label, Enum.NormalId.Back, "Creature Meadow", { stroke = true, padding = 8 })
end

local function scatterTrees()
	local placed = 0
	local attempts = 0
	while placed < 45 and attempts < 400 do
		attempts += 1
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(40, 200)
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		local onPath = math.abs(z) < 8 and x > 0 and x < 90
		local onSpot = (Vector2.new(x, z) - Vector2.new(110, 30)).Magnitude < 22
		if not onPath and not onSpot then
			tree(x, z, rng:NextNumber(0.9, 1.5))
			placed += 1
		end
	end
end

-------------------------------------------------------------------------------
-- Entry point
-------------------------------------------------------------------------------

function CritterCove.Build()
	mapFolder = Instance.new("Folder")
	mapFolder.Name = "CritterCove"
	mapFolder.Parent = workspace

	decorFolder = Instance.new("Folder")
	decorFolder.Name = "Decor"
	decorFolder.Parent = mapFolder

	-- Remove the default Baseplate if the place still has one.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	for _, existing in ipairs(workspace:GetChildren()) do
		if existing:IsA("SpawnLocation") then
			existing:Destroy()
		end
	end

	buildTerrain()
	setupLighting()
	buildSpawnPlaza()
	buildPath(Vector3.new(30, 0, 0), Vector3.new(85, 0, 0), 8)
	buildMeadow()
	scatterTrees()
end

return CritterCove
