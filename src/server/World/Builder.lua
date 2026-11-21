--[[
	Builder
	Shared helpers for building maps from code: ground height lookup, parts,
	ellipsoids, signs, particles, and reusable props (trees, palms, flowers,
	mushrooms, rocks, lanterns).

	Call Builder.SetDefaultParent(folder) before building. Every helper puts
	new parts there unless a Parent is given.

	Lanterns register their lights in Builder.lamps / Builder.lampBulbs so the
	day/night cycle can switch them on at dusk.
]]

local Builder = {}

local GROUND_FALLBACK = 4
local rng = Random.new(1337) -- fixed seed so the island looks the same on every server
Builder.rng = rng

local decorFolder: Instance = workspace
local lamps: { Light } = {}
local lampBulbs: { BasePart } = {}
Builder.lamps = lamps
Builder.lampBulbs = lampBulbs

function Builder.SetDefaultParent(folder: Instance)
	decorFolder = folder
end

-------------------------------------------------------------------------------
-- Core helpers
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

-- Any BasePart class (WedgePart, TrussPart...) with the same defaults as part().
local function make(className: string, props: { [string]: any }): BasePart
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props) do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent or decorFolder
	return p
end

-- Welds `child` to `base` so it moves with it. Used for things the client
-- animates (windmill blades, bobbing boats): only the base is anchored.
local function weldTo(base: BasePart, child: BasePart)
	child.Anchored = false
	child.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = child
	weld.Parent = child
end

Builder.make = make
Builder.weldTo = weldTo
Builder.groundY = groundY
Builder.part = part
Builder.decor = decor
Builder.ball = ball
Builder.surfaceText = surfaceText
Builder.particles = particles
Builder.tree = tree
Builder.palm = palm
Builder.flower = flower
Builder.mushroom = mushroom
Builder.rock = rock
Builder.lantern = lantern

return Builder
