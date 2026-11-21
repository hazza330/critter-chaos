--[[
	CritterCove
	Builds the starting island from code when the server starts, so the map lives
	in version control alongside the scripts. Any part of this can later be
	replaced with hand-built models in Studio; the services only care about the
	"DiscoverySpot" tag and the SpawnLocation.

	Layout (ground level is about y = 4, island radius about 215 studs)
	  Centre        Spawn Plaza: spawn pad, fountain, lanterns, sign, welcome board
	  East          Creature Meadow: pond with stepping stones, flowers, mushrooms, 6 bushes
	  North         Cliffs with a waterfall into a lagoon
	                  * hidden cave behind the waterfall (secret spot, luck x3)
	                  * wooden stairs on the east side up to a lookout (secret spot, luck x2)
	  South         Beach with a dock and a moored boat
	  Edges         Palm-lined beach, rocks, small islets offshore
	  Sky           Clouds, tropical water, slow day/night cycle with lanterns at night

	Performance: everything is anchored, decorations have CanQuery and CanTouch off,
	particle rates are low and lights have short ranges with shadows off.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local CritterCove = {}

local GROUND_FALLBACK = 4
local rng = Random.new(1337) -- fixed seed so the island looks the same on every server

local mapFolder: Folder
local decorFolder: Folder
local lamps: { Light } = {}
local lampBulbs: { BasePart } = {}

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.IgnoreWater = true

-- Height of the terrain surface at x, z. fromY lets you start the ray below
-- an overhang (for example inside the waterfall cave).
local function groundY(x: number, z: number, fromY: number?): number
	rayParams.FilterDescendantsInstances = { workspace.Terrain }
	local startY = fromY or 300
	local result = workspace:Raycast(Vector3.new(x, startY, z), Vector3.new(0, -(startY + 300), 0), rayParams)
	return if result then result.Position.Y else GROUND_FALLBACK
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	local shape = props.Shape
	if shape then
		p.Shape = shape
	end
	for key, value in pairs(props) do
		if key ~= "Parent" and key ~= "Shape" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent or decorFolder
	return p
end

-- Decorations: no touch events or raycasts, cheaper for the engine.
local function decor(p: BasePart): BasePart
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function ball(position: Vector3, size: Vector3, color: Color3, props: { [string]: any }?): Part
	local p = part({
		Size = size,
		CFrame = if typeof(position) == "CFrame" then position :: any else CFrame.new(position),
		Color = color,
		CanCollide = false,
	})
	for key, value in pairs(props or {}) do
		(p :: any)[key] = value
	end
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	decor(p)
	return p
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

local function particles(parent: Instance, props: { [string]: any }): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.LightEmission = 0.6
	for key, value in pairs(props) do
		(emitter :: any)[key] = value
	end
	emitter.Parent = parent
	return emitter
end

-------------------------------------------------------------------------------
-- Terrain, water, sky
-------------------------------------------------------------------------------

local function buildTerrain()
	local terrain = workspace.Terrain
	terrain:Clear()

	-- Material colours: brighter, more tropical than Roblox defaults.
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(106, 190, 76))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(80, 160, 70))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(240, 222, 170))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(140, 132, 128))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(170, 140, 100))

	terrain.WaterColor = Color3.fromRGB(40, 190, 200)
	terrain.WaterTransparency = 0.75
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.25
	terrain.WaterWaveSpeed = 8

	-- Animated grass blades. Not every client setting allows it, so it's optional.
	pcall(function()
		(terrain :: any).Decoration = true
	end)

	-- Sea and sea bed
	terrain:FillBlock(CFrame.new(0, -10, 0), Vector3.new(1800, 20, 1800), Enum.Material.Water)
	terrain:FillBlock(CFrame.new(0, -26, 0), Vector3.new(1800, 12, 1800), Enum.Material.Sand)

	-- Shallow sandy shelf so the water near the beach looks turquoise.
	terrain:FillCylinder(CFrame.new(0, -9, 0), 6, 270, Enum.Material.Sand)

	-- Beach and main grass plateau
	terrain:FillCylinder(CFrame.new(0, -4, 0), 12, 240, Enum.Material.Sand)
	terrain:FillCylinder(CFrame.new(0, -2, 0), 12, 215, Enum.Material.Grass)

	-- Patches of darker grass for variety
	for _ = 1, 10 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(50, 180)
		terrain:FillCylinder(
			CFrame.new(math.cos(angle) * radius, 3, math.sin(angle) * radius),
			2,
			rng:NextNumber(12, 24),
			Enum.Material.LeafyGrass
		)
	end

	-- Rolling hills (kept away from the plaza and paths)
	terrain:FillBall(Vector3.new(170, -12, 90), 40, Enum.Material.Grass)
	terrain:FillBall(Vector3.new(150, -16, -110), 36, Enum.Material.Grass)
	terrain:FillBall(Vector3.new(-160, -14, 120), 32, Enum.Material.LeafyGrass)
	terrain:FillBall(Vector3.new(-150, -18, -40), 34, Enum.Material.Grass)

	-- North cliffs: a raised rocky wall with grass on top.
	terrain:FillBlock(CFrame.new(-10, 15, -185), Vector3.new(150, 30, 60), Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(-10, 31, -185), Vector3.new(150, 3, 60), Enum.Material.Grass)
	for _, pos in ipairs({
		Vector3.new(-80, 18, -170),
		Vector3.new(-60, 22, -195),
		Vector3.new(40, 20, -175),
		Vector3.new(60, 16, -195),
		Vector3.new(-20, 26, -205),
	}) do
		terrain:FillBall(pos, rng:NextNumber(14, 20), Enum.Material.Rock)
	end

	-- Lagoon at the foot of the waterfall
	terrain:FillCylinder(CFrame.new(-10, 2, -135), 8, 17, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(-10, -2, -135), 6, 17, Enum.Material.Sand)
	terrain:FillCylinder(CFrame.new(-10, 0, -135), 3, 17, Enum.Material.Water)

	-- Secret cave behind the waterfall. Its mouth just breaks the cliff face.
	terrain:FillBall(Vector3.new(-10, 9, -163), 11, Enum.Material.Air)
	terrain:FillBlock(CFrame.new(-10, 2, -163), Vector3.new(20, 2, 20), Enum.Material.Slate)

	-- Meadow pond
	terrain:FillCylinder(CFrame.new(110, 2, 30), 6, 16, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(110, -1, 30), 4, 16, Enum.Material.Water)

	-- Small islets offshore
	for i = 1, 5 do
		local angle = (i / 5) * math.pi * 2 + 0.4
		local radius = rng:NextNumber(310, 360)
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		terrain:FillCylinder(CFrame.new(x, -4, z), 10, rng:NextNumber(16, 26), Enum.Material.Sand)
		terrain:FillBall(Vector3.new(x, -6, z), 10, Enum.Material.Grass)
	end

	-- Sea stacks: tall rocks out in the water
	for _, pos in ipairs({ Vector3.new(260, 0, -120), Vector3.new(-250, 0, 170), Vector3.new(120, 0, 270) }) do
		terrain:FillBall(pos + Vector3.new(0, 6, 0), 10, Enum.Material.Rock)
		terrain:FillBall(pos + Vector3.new(2, 16, 1), 7, Enum.Material.Rock)
	end

	-- Clouds
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(255, 255, 255)
	clouds.Parent = terrain
end

local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 20
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(70, 70, 90)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 165)
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 0.7
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3

	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 9
	sky.StarCount = 3000
	sky.Parent = Lighting

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(199, 225, 255)
	atmosphere.Decay = Color3.fromRGB(110, 170, 220)
	atmosphere.Glare = 0.35
	atmosphere.Haze = 1.3
	atmosphere.Parent = Lighting

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 28
	bloom.Threshold = 1.4
	bloom.Parent = Lighting

	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	rays.Parent = Lighting

	local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	grade.Saturation = 0.2
	grade.Contrast = 0.08
	grade.TintColor = Color3.fromRGB(255, 250, 240)
	grade.Parent = Lighting
end

-------------------------------------------------------------------------------
-- Props
-------------------------------------------------------------------------------

local LEAF_COLOURS = {
	Color3.fromRGB(92, 184, 92),
	Color3.fromRGB(70, 160, 80),
	Color3.fromRGB(120, 200, 90),
	Color3.fromRGB(150, 200, 70),
}

local function tree(x: number, z: number, scale: number)
	local y = groundY(x, z)
	local height = 10 * scale
	decor(part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 1.6 * scale, 1.6 * scale),
		CFrame = CFrame.new(x, y + height / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(120, 85, 60),
		Material = Enum.Material.Wood,
	}))
	local leafColour = LEAF_COLOURS[rng:NextInteger(1, #LEAF_COLOURS)]
	for i = 1, 3 do
		local size = (6 - i) * scale * 1.3
		local offset = Vector3.new(rng:NextNumber(-1.5, 1.5), height + (i - 1) * 1.8 * scale, rng:NextNumber(-1.5, 1.5))
		ball(Vector3.new(x, y, z) + offset, Vector3.new(size, size * 0.85, size), leafColour)
	end
end

-- Palm: a curved trunk of segments with drooping fronds and coconuts.
local function palm(x: number, z: number, scale: number, leanAngle: number)
	local y = groundY(x, z)
	local segments = 7
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, leanAngle, 0)
	for i = 1, segments do
		local bend = math.rad(4 * scale)
		cf = cf * CFrame.Angles(bend, 0, 0) * CFrame.new(0, 1.8 * scale, 0)
		decor(part({
			Name = "PalmTrunk",
			Size = Vector3.new(1.1 * scale, 2 * scale, 1.1 * scale) * (1 - i * 0.04),
			CFrame = cf,
			Color = if i % 2 == 0 then Color3.fromRGB(150, 110, 70) else Color3.fromRGB(135, 98, 62),
			Material = Enum.Material.Wood,
		}))
	end
	local top = cf.Position + Vector3.new(0, 0.8 * scale, 0)
	for i = 1, 7 do
		local yaw = (i / 7) * math.pi * 2
		local frond = CFrame.new(top) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-25), 0, 0)
		ball(frond * CFrame.new(0, 0, -3.2 * scale), Vector3.new(1.6 * scale, 0.25, 7 * scale), Color3.fromRGB(70, 170, 70))
	end
	for i = 1, 3 do
		local yaw = i * 2.1
		ball(
			CFrame.new(top + Vector3.new(math.cos(yaw) * 0.6, -0.7, math.sin(yaw) * 0.6)),
			Vector3.new(0.8, 0.8, 0.8) * scale,
			Color3.fromRGB(110, 80, 45)
		)
	end
end

local FLOWER_COLOURS = {
	Color3.fromRGB(255, 120, 160),
	Color3.fromRGB(255, 220, 90),
	Color3.fromRGB(170, 130, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 150, 80),
}

local function flower(x: number, z: number)
	local y = groundY(x, z)
	decor(part({
		Name = "Stem",
		Size = Vector3.new(0.2, 1.2, 0.2),
		Position = Vector3.new(x, y + 0.6, z),
		Color = Color3.fromRGB(80, 150, 60),
		CanCollide = false,
	}))
	ball(Vector3.new(x, y + 1.3, z), Vector3.new(1, 0.5, 1), FLOWER_COLOURS[rng:NextInteger(1, #FLOWER_COLOURS)])
	ball(Vector3.new(x, y + 1.45, z), Vector3.new(0.4, 0.3, 0.4), Color3.fromRGB(255, 230, 120))
end

local function mushroom(x: number, z: number, scale: number)
	local y = groundY(x, z)
	decor(part({
		Name = "MushroomStem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6 * scale, 0.7 * scale, 0.7 * scale),
		CFrame = CFrame.new(x, y + 0.8 * scale, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(245, 235, 215),
		CanCollide = false,
	}))
	local capColour = if rng:NextNumber() < 0.5 then Color3.fromRGB(230, 70, 70) else Color3.fromRGB(150, 90, 220)
	ball(Vector3.new(x, y + 1.7 * scale, z), Vector3.new(2.2, 1.2, 2.2) * scale, capColour)
	for i = 1, 3 do
		local a = i * 2.1
		ball(
			Vector3.new(x + math.cos(a) * 0.6 * scale, y + 2.15 * scale, z + math.sin(a) * 0.6 * scale),
			Vector3.new(0.35, 0.15, 0.35) * scale,
			Color3.fromRGB(255, 255, 255)
		)
	end
end

local function rock(x: number, z: number, scale: number)
	local y = groundY(x, z)
	local p = part({
		Name = "Rock",
		Size = Vector3.new(3, 2, 2.6) * scale,
		CFrame = CFrame.new(x, y + 0.6 * scale, z)
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)),
		Color = Color3.fromRGB(150, 145, 140):Lerp(Color3.fromRGB(110, 105, 100), rng:NextNumber()),
		Material = Enum.Material.Slate,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	decor(p)
end

local function lantern(x: number, z: number)
	local y = groundY(x, z)
	decor(part({
		Name = "LanternPost",
		Size = Vector3.new(0.6, 7, 0.6),
		Position = Vector3.new(x, y + 3.5, z),
		Color = Color3.fromRGB(80, 60, 45),
		Material = Enum.Material.Wood,
	}))
	decor(part({
		Name = "LanternCap",
		Size = Vector3.new(1.8, 0.4, 1.8),
		Position = Vector3.new(x, y + 8.4, z),
		Color = Color3.fromRGB(60, 45, 35),
		Material = Enum.Material.Wood,
	}))
	local bulb = decor(part({
		Name = "LanternBulb",
		Size = Vector3.new(1.3, 1.6, 1.3),
		Position = Vector3.new(x, y + 7.4, z),
		Color = Color3.fromRGB(255, 200, 120),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.2,
		CanCollide = false,
	}))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 110)
	light.Range = 16
	light.Brightness = 1.6
	light.Shadows = false
	light.Enabled = false
	light.Parent = bulb
	table.insert(lamps, light)
	table.insert(lampBulbs, bulb)
end

local function discoveryBush(x: number, z: number, name: string, options: { [string]: any }?)
	local opts = options or {}
	local y = opts.y or groundY(x, z)
	local model = Instance.new("Model")
	model.Name = "DiscoverySpot_" .. name
	model.Parent = mapFolder

	-- The tagged part is what DiscoveryService hooks into.
	local hitbox = part({
		Name = "Spot",
		Size = Vector3.new(6, 4, 6),
		Position = Vector3.new(x, y + 2, z),
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})
	hitbox:SetAttribute("IslandId", "CritterCove")
	hitbox:SetAttribute("SpotName", opts.spotName or "Rustling Bush")
	hitbox:SetAttribute("Luck", opts.luck or 1)
	CollectionService:AddTag(hitbox, "DiscoverySpot")
	model.PrimaryPart = hitbox

	if opts.crystals then
		-- Glowing crystal cluster instead of a bush.
		for i = 1, 5 do
			local h = rng:NextNumber(2, 4.5)
			local p = decor(part({
				Name = "Crystal",
				Size = Vector3.new(0.9, h, 0.9),
				CFrame = CFrame.new(x + rng:NextNumber(-1.8, 1.8), y + h / 2 - 0.3, z + rng:NextNumber(-1.8, 1.8))
					* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)),
				Color = opts.crystals,
				Material = Enum.Material.Neon,
				Transparency = 0.15,
				CanCollide = false,
				Parent = model,
			}))
			if i == 1 then
				local light = Instance.new("PointLight")
				light.Color = opts.crystals
				light.Range = 18
				light.Brightness = 1.5
				light.Shadows = false
				light.Parent = p
			end
		end
	else
		for i = 1, 3 do
			local size = 3.2 + rng:NextNumber(0, 1.2)
			local bush = ball(
				Vector3.new(x + (i - 2) * 1.6, y + size / 2 - 0.3, z + rng:NextNumber(-0.8, 0.8)),
				Vector3.new(size, size * 0.9, size),
				Color3.fromRGB(60, 150, 70)
			)
			bush.Parent = model
		end
		-- A couple of berries so bushes read as special.
		for _ = 1, 4 do
			ball(
				Vector3.new(x + rng:NextNumber(-2, 2), y + rng:NextNumber(1.5, 3), z + rng:NextNumber(-1.8, 1.8)),
				Vector3.new(0.5, 0.5, 0.5),
				Color3.fromRGB(230, 60, 90)
			).Parent = model
		end
	end

	-- Slow sparkles so players can spot interactive places.
	local attachment = Instance.new("Attachment")
	attachment.Parent = hitbox
	particles(attachment, {
		Rate = opts.sparkleRate or 2,
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(1, 2),
		SpreadAngle = Vector2.new(60, 60),
		Size = NumberSequence.new(0.4, 0),
		Color = ColorSequence.new(opts.sparkleColour or Color3.fromRGB(255, 240, 160)),
		LightEmission = 0.8,
	})
end

-------------------------------------------------------------------------------
-- Areas
-------------------------------------------------------------------------------

local function buildSpawnPlaza()
	local y = groundY(0, 0)

	decor(part({
		Name = "PlazaFloor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 66, 66),
		CFrame = CFrame.new(0, y + 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(236, 222, 190),
		Material = Enum.Material.Slate,
		Parent = mapFolder,
	}))
	-- Decorative ring inlay
	decor(part({
		Name = "PlazaRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.3, 50, 50),
		CFrame = CFrame.new(0, y + 0.42, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(215, 190, 150),
		Material = Enum.Material.Slate,
		Parent = mapFolder,
	}))
	decor(part({
		Name = "PlazaInner",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.4, 46, 46),
		CFrame = CFrame.new(0, y + 0.44, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(236, 222, 190),
		Material = Enum.Material.Slate,
		Parent = mapFolder,
	}))

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CoveSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, y + 1.2, 14) -- default facing is -Z, towards the fountain and sign
	spawn.Color = Color3.fromRGB(255, 200, 90)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = mapFolder

	-- Fountain in the middle of the plaza
	local fy = y + 0.8
	decor(part({
		Name = "FountainBasin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.4, 16, 16),
		CFrame = CFrame.new(0, fy + 1.2, -8) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(200, 195, 185),
		Material = Enum.Material.Marble,
		Parent = mapFolder,
	}))
	decor(part({
		Name = "FountainWater",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 14, 14),
		CFrame = CFrame.new(0, fy + 2.3, -8) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(80, 200, 230),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		CanCollide = false,
		Parent = mapFolder,
	}))
	decor(part({
		Name = "FountainPillar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, 2, 2),
		CFrame = CFrame.new(0, fy + 4, -8) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(200, 195, 185),
		Material = Enum.Material.Marble,
		Parent = mapFolder,
	}))
	local bowl = decor(part({
		Name = "FountainBowl",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 6, 6),
		CFrame = CFrame.new(0, fy + 7, -8) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(200, 195, 185),
		Material = Enum.Material.Marble,
		Parent = mapFolder,
	}))
	local spout = Instance.new("Attachment")
	spout.Position = Vector3.new(0.6, 0, 0) -- cylinder's X axis points up here
	spout.Parent = bowl
	particles(spout, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Rate = 30,
		Lifetime = NumberRange.new(0.9, 1.2),
		Speed = NumberRange.new(9, 11),
		SpreadAngle = Vector2.new(14, 14),
		Acceleration = Vector3.new(0, -26, 0),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 0.9),
		}),
		Transparency = NumberSequence.new(0.3, 1),
		Color = ColorSequence.new(Color3.fromRGB(200, 240, 255)),
		LightEmission = 0.2,
		EmissionDirection = Enum.NormalId.Right,
	})

	-- Lanterns around the plaza edge
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2 + math.pi / 8
		lantern(math.cos(a) * 31, math.sin(a) * 31)
	end

	-- Big sign behind the fountain, facing spawn.
	local signBoard = part({
		Name = "CritterChaosSign",
		Size = Vector3.new(46, 12, 1.5),
		CFrame = CFrame.new(0, y + 17, -36),
		Color = Color3.fromRGB(255, 140, 60),
		Parent = mapFolder,
	})
	surfaceText(signBoard, Enum.NormalId.Back, "CRITTER CHAOS", { stroke = true, padding = 30 })
	surfaceText(signBoard, Enum.NormalId.Front, "CRITTER CHAOS", { stroke = true, padding = 30 })
	decor(part({
		Name = "SignTrim",
		Size = Vector3.new(48, 1.2, 2),
		Position = Vector3.new(0, y + 23.4, -36),
		Color = Color3.fromRGB(255, 220, 90),
		Parent = mapFolder,
	}))
	for _, side in ipairs({ -19, 19 }) do
		decor(part({
			Name = "SignPost",
			Size = Vector3.new(2, 18, 2),
			Position = Vector3.new(side, y + 9, -36),
			Color = Color3.fromRGB(120, 85, 60),
			Material = Enum.Material.Wood,
			Parent = mapFolder,
		}))
		palm(side * 1.4, -38, 1.1, side > 0 and 0.4 or -0.4)
	end

	-- Welcome board: real instructions, no buttons.
	local board = part({
		Name = "WelcomeBoard",
		Size = Vector3.new(14, 10, 1),
		CFrame = CFrame.lookAt(Vector3.new(-24, y + 6, 10), Vector3.new(0, y + 6, 20)),
		Color = Color3.fromRGB(90, 60, 40),
		Material = Enum.Material.Wood,
		Parent = mapFolder,
	})
	surfaceText(
		board,
		Enum.NormalId.Front,
		'<font size="56">Welcome to Critter Cove!</font>\n\n'
			.. "Follow the path east to the Creature Meadow and search the sparkling bushes.\n\n"
			.. "Explorers say something glitters behind the waterfall up north...",
		{ scaled = true, font = Enum.Font.Gotham, alignY = Enum.TextYAlignment.Top }
	)

	-- Signpost showing where everything is. Districts not built yet say so honestly.
	local post = decor(part({
		Name = "Signpost",
		Size = Vector3.new(1, 9, 1),
		Position = Vector3.new(26, y + 4.5, 10),
		Color = Color3.fromRGB(120, 85, 60),
		Material = Enum.Material.Wood,
		Parent = mapFolder,
	}))
	local arrows = {
		{ "Creature Meadow", 0, Color3.fromRGB(110, 200, 110) },
		{ "Waterfall", 90, Color3.fromRGB(90, 170, 230) },
		{ "Market (Stage 3)", 180, Color3.fromRGB(160, 160, 160) },
		{ "Dock", 270, Color3.fromRGB(200, 170, 110) },
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
		decor(part({
			Name = "Path",
			Size = Vector3.new(width, 0.4, (b - a).Magnitude + 0.6),
			CFrame = CFrame.lookAt(Vector3.new(mid.X, y + 0.15, mid.Z), Vector3.new(b.X, y + 0.15, b.Z)),
			Color = Color3.fromRGB(214, 190, 150),
			Material = Enum.Material.Ground,
			CanCollide = false,
		}))
		-- Edge stones every other segment
		if i % 2 == 0 then
			local right = CFrame.lookAt(a, b).RightVector
			for _, side in ipairs({ -1, 1 }) do
				local p = mid + right * side * (width / 2 + 0.6)
				rock(p.X, p.Z, 0.35)
			end
		end
	end
end

local function buildMeadow()
	local spots = {
		{ 85, -20 },
		{ 95, 55 },
		{ 135, 10 },
		{ 140, -55 },
		{ 175, 40 },
		{ 120, 85 },
	}
	for i, pos in ipairs(spots) do
		discoveryBush(pos[1], pos[2], "Meadow" .. i)
	end

	for _ = 1, 110 do
		local x = rng:NextNumber(65, 195)
		local z = rng:NextNumber(-100, 110)
		if (Vector2.new(x, z) - Vector2.new(110, 30)).Magnitude > 20 then
			flower(x, z)
		end
	end

	-- Mushroom clusters
	for _, centre in ipairs({ Vector2.new(160, -20), Vector2.new(90, 100), Vector2.new(185, 75) }) do
		for _ = 1, 4 do
			mushroom(centre.X + rng:NextNumber(-4, 4), centre.Y + rng:NextNumber(-4, 4), rng:NextNumber(0.7, 1.4))
		end
	end

	-- Stepping stones across the pond
	for i = 0, 5 do
		local x = 96 + i * 5.5
		local z = 30 + math.sin(i) * 2
		decor(part({
			Name = "SteppingStone",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 4, 4),
			CFrame = CFrame.new(x, 1.3, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(170, 165, 155),
			Material = Enum.Material.Slate,
		})).CanQuery = true -- pets can stand on them
	end
	-- Lily pads
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(5, 13)
		decor(part({
			Name = "LilyPad",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, 2.2, 2.2),
			CFrame = CFrame.new(110 + math.cos(a) * r, 1.05, 30 + math.sin(a) * r) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(80, 170, 70),
			CanCollide = false,
		}))
	end

	-- Low fence along the meadow's west edge, with a gap for the path.
	for z = -80, 80, 6 do
		if math.abs(z) > 8 then
			local y = groundY(66, z)
			decor(part({
				Name = "FencePost",
				Size = Vector3.new(0.5, 3, 0.5),
				Position = Vector3.new(66, y + 1.5, z),
				Color = Color3.fromRGB(150, 110, 75),
				Material = Enum.Material.Wood,
			}))
			decor(part({
				Name = "FenceRail",
				Size = Vector3.new(0.3, 0.4, 6),
				Position = Vector3.new(66, y + 2.2, z + 3),
				Color = Color3.fromRGB(170, 130, 90),
				Material = Enum.Material.Wood,
				CanCollide = false,
			}))
		end
	end

	-- Drifting pollen across the meadow
	local pollen = decor(part({
		Name = "PollenEmitter",
		Size = Vector3.new(120, 1, 180),
		Position = Vector3.new(130, groundY(130, 0) + 4, 0),
		Transparency = 1,
		CanCollide = false,
	}))
	particles(pollen, {
		Rate = 12,
		Lifetime = NumberRange.new(5, 8),
		Speed = NumberRange.new(0.3, 1),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(0.18),
		Color = ColorSequence.new(Color3.fromRGB(255, 250, 200)),
		LightEmission = 1,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})

	local label = part({
		Name = "MeadowSign",
		Size = Vector3.new(12, 3, 0.6),
		CFrame = CFrame.new(64, groundY(64, -10) + 5, -10) * CFrame.Angles(0, math.rad(-90), 0),
		Color = Color3.fromRGB(110, 200, 110),
		Material = Enum.Material.Wood,
		Parent = mapFolder,
	})
	surfaceText(label, Enum.NormalId.Front, "Creature Meadow", { stroke = true, padding = 8 })
	surfaceText(label, Enum.NormalId.Back, "Creature Meadow", { stroke = true, padding = 8 })
end

local function buildWaterfall()
	local topY = 32
	local baseY = 1
	local x, faceZ = -10, -154.5

	-- Several overlapping translucent sheets read as falling water.
	for i, data in ipairs({
		{ width = 14, offset = 0, colour = Color3.fromRGB(150, 220, 255), transparency = 0.35 },
		{ width = 10, offset = -0.4, colour = Color3.fromRGB(210, 245, 255), transparency = 0.5 },
		{ width = 16, offset = 0.4, colour = Color3.fromRGB(110, 200, 240), transparency = 0.55 },
	}) do
		local sheet = decor(part({
			Name = "WaterfallSheet" .. i,
			Size = Vector3.new(data.width, topY - baseY, 0.4),
			Position = Vector3.new(x, (topY + baseY) / 2, faceZ + 1.2 + data.offset),
			Color = data.colour,
			Material = Enum.Material.Glass,
			Transparency = data.transparency,
			CanCollide = false,
			CastShadow = false,
			Parent = mapFolder,
		}))
		-- Scrolling texture is animated on the client by AmbientController.
		local texture = Instance.new("Texture")
		texture.Texture = "rbxasset://textures/water/normal_02.dds"
		texture.Face = Enum.NormalId.Front
		texture.StudsPerTileU = 10
		texture.StudsPerTileV = 14
		texture.Transparency = 0.4
		texture.Color3 = Color3.fromRGB(255, 255, 255)
		texture.Parent = sheet
		CollectionService:AddTag(texture, "ScrollingTexture")
	end

	-- Lip at the top where water pours over
	decor(part({
		Name = "WaterfallLip",
		Size = Vector3.new(16, 1, 6),
		Position = Vector3.new(x, topY + 0.2, faceZ - 2),
		Color = Color3.fromRGB(90, 190, 230),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		CanCollide = false,
		Parent = mapFolder,
	}))

	-- Mist where it hits the lagoon
	local mist = decor(part({
		Name = "WaterfallMist",
		Size = Vector3.new(16, 1, 4),
		Position = Vector3.new(x, baseY + 0.5, faceZ + 3),
		Transparency = 1,
		CanCollide = false,
		Parent = mapFolder,
	}))
	particles(mist, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Rate = 25,
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(50, 50),
		Size = NumberSequence.new(2, 6),
		Transparency = NumberSequence.new(0.6, 1),
		Color = ColorSequence.new(Color3.fromRGB(230, 250, 255)),
		LightEmission = 0.3,
		EmissionDirection = Enum.NormalId.Top,
	})

	-- Hidden cave behind the falls: glowing crystals and a lucky discovery spot.
	discoveryBush(x, faceZ - 10, "WaterfallCave", {
		y = groundY(x, faceZ - 10, 12),
		spotName = "Glimmering Crystals",
		luck = 3,
		crystals = Color3.fromRGB(120, 220, 255),
		sparkleRate = 4,
		sparkleColour = Color3.fromRGB(170, 240, 255),
	})
	for _ = 1, 6 do
		local cx = x + rng:NextNumber(-7, 7)
		local cz = faceZ - rng:NextNumber(6, 16)
		local cy = groundY(cx, cz, 12)
		decor(part({
			Name = "CaveCrystal",
			Size = Vector3.new(0.6, rng:NextNumber(1.5, 3), 0.6),
			CFrame = CFrame.new(cx, cy + 1, cz) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.5, 0.5)),
			Color = Color3.fromRGB(180, 140, 255),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = mapFolder,
		}))
	end

	-- Rocks around the lagoon
	for i = 1, 10 do
		local a = (i / 10) * math.pi * 2
		rock(x + math.cos(a) * 19, -135 + math.sin(a) * 19, rng:NextNumber(0.6, 1.3))
	end
end

local function buildCliffStairs()
	-- Wooden stairs up the east end of the cliff to a lookout with a lucky spot.
	local z = -170
	local baseY = groundY(110, z)
	local topY = 33
	local steps = math.ceil((topY - baseY) / 2)
	for i = 1, steps do
		local stepTop = baseY + i * 2
		local x = 106 - i * 3
		decor(part({
			Name = "Stair",
			Size = Vector3.new(3, stepTop - baseY + 2, 8),
			Position = Vector3.new(x, (stepTop + baseY - 2) / 2, z),
			Color = if i % 2 == 0 then Color3.fromRGB(150, 110, 75) else Color3.fromRGB(135, 98, 66),
			Material = Enum.Material.WoodPlanks,
			Parent = mapFolder,
		})).CanQuery = true
	end

	-- Lookout: railing, telescope-ish post, and a nest with a lucky spot.
	local lx, lz = 30, -195
	local ly = groundY(lx, lz)
	decor(part({
		Name = "LookoutDeck",
		Size = Vector3.new(16, 0.6, 12),
		Position = Vector3.new(lx, ly + 0.3, lz),
		Color = Color3.fromRGB(150, 110, 75),
		Material = Enum.Material.WoodPlanks,
		Parent = mapFolder,
	}))
	discoveryBush(lx, lz, "Lookout", {
		y = ly + 0.6,
		spotName = "Feathered Nest",
		luck = 2,
		sparkleColour = Color3.fromRGB(255, 220, 120),
	})
	local sign = part({
		Name = "LookoutSign",
		Size = Vector3.new(8, 2, 0.4),
		CFrame = CFrame.new(lx, ly + 5, lz + 6),
		Color = Color3.fromRGB(110, 200, 110),
		Material = Enum.Material.Wood,
		Parent = mapFolder,
	})
	surfaceText(sign, Enum.NormalId.Back, "Griffin's Lookout", { stroke = true, padding = 6 })
	surfaceText(sign, Enum.NormalId.Front, "Griffin's Lookout", { stroke = true, padding = 6 })
end

local function buildDock()
	local z0, z1 = 222, 270
	local deckY = 2.4
	decor(part({
		Name = "Dock",
		Size = Vector3.new(8, 0.6, z1 - z0),
		Position = Vector3.new(0, deckY, (z0 + z1) / 2),
		Color = Color3.fromRGB(160, 120, 80),
		Material = Enum.Material.WoodPlanks,
		Parent = mapFolder,
	})).CanQuery = true
	for z = z0 + 2, z1, 8 do
		for _, side in ipairs({ -4, 4 }) do
			decor(part({
				Name = "DockPost",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(12, 1, 1),
				CFrame = CFrame.new(side, deckY - 4, z) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(110, 80, 55),
				Material = Enum.Material.Wood,
			}))
		end
	end

	-- Moored boat
	local bx, bz = 10, 262
	decor(part({
		Name = "BoatHull",
		Size = Vector3.new(6, 2.4, 14),
		Position = Vector3.new(bx, 0.8, bz),
		Color = Color3.fromRGB(220, 90, 70),
		Material = Enum.Material.Wood,
	}))
	decor(part({
		Name = "BoatTrim",
		Size = Vector3.new(6.2, 0.4, 14.2),
		Position = Vector3.new(bx, 2.1, bz),
		Color = Color3.fromRGB(250, 245, 230),
		Material = Enum.Material.Wood,
	}))
	decor(part({
		Name = "BoatMast",
		Size = Vector3.new(0.5, 12, 0.5),
		Position = Vector3.new(bx, 8, bz),
		Color = Color3.fromRGB(120, 85, 60),
		Material = Enum.Material.Wood,
	}))
	decor(part({
		Name = "BoatSail",
		Size = Vector3.new(0.2, 9, 7),
		Position = Vector3.new(bx + 0.4, 9, bz + 3.6),
		Color = Color3.fromRGB(250, 245, 230),
		Material = Enum.Material.Fabric,
		CanCollide = false,
	}))
end

local function scatterNature()
	-- Leafy trees inland
	local placed, attempts = 0, 0
	while placed < 40 and attempts < 500 do
		attempts += 1
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(45, 195)
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		local onPath = math.abs(z) < 10 and x > 0 and x < 90
		local nearPond = (Vector2.new(x, z) - Vector2.new(110, 30)).Magnitude < 22
		local onCliff = z < -120 and x > -95 and x < 115
		local inMeadowCore = x > 75 and x < 185 and z > -70 and z < 95
		if not (onPath or nearPond or onCliff or inMeadowCore) then
			tree(x, z, rng:NextNumber(0.9, 1.5))
			placed += 1
		end
	end
	-- A few trees inside the meadow, away from bushes
	for _, pos in ipairs({ Vector2.new(115, -30), Vector2.new(160, 95), Vector2.new(80, 25), Vector2.new(185, -40) }) do
		tree(pos.X, pos.Y, 1.3)
	end

	-- Palms around the beach, skipping the cliffs and the dock
	for i = 1, 30 do
		local angle = (i / 30) * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local x, z = math.cos(angle) * rng:NextNumber(220, 232), math.sin(angle) * rng:NextNumber(220, 232)
		local nearDock = math.abs(x) < 14 and z > 0
		local nearCliff = z < -150 and x > -100 and x < 80
		if not nearDock and not nearCliff then
			-- Lean outwards towards the sea.
			palm(x, z, rng:NextNumber(0.9, 1.25), math.atan2(-x, -z) + math.pi)
		end
	end

	-- Palms on the islets
	for i = 1, 5 do
		local angle = (i / 5) * math.pi * 2 + 0.4
		local x, z = math.cos(angle) * 335, math.sin(angle) * 335
		local hit = groundY(x, z)
		if hit > 0 then
			palm(x, z, 1.1, rng:NextNumber(0, 6))
		end
	end

	-- Rocks along the shore and inland
	for _ = 1, 40 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = if rng:NextNumber() < 0.6 then rng:NextNumber(205, 238) else rng:NextNumber(50, 200)
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		if not (math.abs(z) < 10 and x > 0 and x < 90) then
			rock(x, z, rng:NextNumber(0.5, 1.6))
		end
	end

	-- Mushrooms under trees in the west woods
	for _ = 1, 10 do
		mushroom(rng:NextNumber(-180, -60), rng:NextNumber(-100, 140), rng:NextNumber(0.6, 1.1))
	end
end

-------------------------------------------------------------------------------
-- Day / night
-------------------------------------------------------------------------------

local DAY_LENGTH = 15 * 60 -- real seconds for a full 24 hour cycle

local function startDayCycle()
	task.spawn(function()
		local lastLit = nil
		while true do
			local dt = task.wait(1)
			Lighting.ClockTime = (Lighting.ClockTime + dt * 24 / DAY_LENGTH) % 24
			local night = Lighting.ClockTime > 18.2 or Lighting.ClockTime < 6.3
			if night ~= lastLit then
				lastLit = night
				for _, light in ipairs(lamps) do
					light.Enabled = night
				end
				for _, bulb in ipairs(lampBulbs) do
					bulb.Material = if night then Enum.Material.Neon else Enum.Material.SmoothPlastic
				end
			end
		end
	end)
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

	-- Remove the template's Baseplate and spawn if the place still has them.
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
	buildPath(Vector3.new(-4, 0, -30), Vector3.new(-10, 0, -115), 7)
	buildPath(Vector3.new(0, 0, 32), Vector3.new(0, 0, 220), 7)
	buildMeadow()
	buildWaterfall()
	buildCliffStairs()
	buildDock()
	scatterNature()
	startDayCycle()
end

return CritterCove
