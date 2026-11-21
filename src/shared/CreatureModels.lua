--[[
	CreatureModels
	Builds each creature's 3D model from parts. Used by the client for
	following pets, inventory thumbnails and the discovery reveal.

	Every model:
	  * has an invisible anchored PrimaryPart called "Root" at the body centre
	  * faces -Z (Roblox's forward direction)
	  * has every other part welded to Root, unanchored, massless, non-colliding,
	    so moving Root moves the whole creature in one cheap operation
	  * has attributes HalfHeight (Root to feet) and Move (walk/hop/float/fly)
	  * parts named "Wing" carry a Side attribute (-1 or 1) and are flapped by
	    the PetController through their Weld's C0

	Rarity effects: Epic and above glow, Legendary and above sparkle.
	To add a creature, add a recipe to RECIPES with the same id as in Creatures.
]]

local Config = script.Parent.Config
local Creatures = require(Config.Creatures)
local Rarities = require(Config.Rarities)

local CreatureModels = {}

local BLACK = Color3.fromRGB(25, 25, 32)
local WHITE = Color3.fromRGB(255, 255, 255)

type Builder = { model: Model, root: Part }

local function newBuilder(name: string): Builder
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.4, 0.4, 0.4)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	return { model = model, root = root }
end

-- shape: "ball" (ellipsoid), "block" or "cylinder"
local function add(b: Builder, shape: string, size: Vector3, color: Color3, offset: CFrame, extra: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	if shape == "ball" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	elseif shape == "cylinder" then
		p.Shape = Enum.PartType.Cylinder
		p.Size = size
	end
	for key, value in pairs(extra or {}) do
		(p :: any)[key] = value
	end
	p.CFrame = b.root.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Name = "Joint"
	weld.Part0 = b.root
	weld.Part1 = p
	weld.C0 = offset
	weld.Parent = p
	p.Parent = b.model
	return p
end

local function eyes(b: Builder, y: number, z: number, spacing: number, size: number, sleepy: boolean?)
	for _, side in ipairs({ -1, 1 }) do
		if sleepy then
			add(b, "block", Vector3.new(size * 1.1, size * 0.22, 0.08), BLACK, CFrame.new(side * spacing, y, z))
		else
			add(b, "ball", Vector3.new(size, size, size * 0.6), BLACK, CFrame.new(side * spacing, y, z))
			add(
				b,
				"ball",
				Vector3.new(size * 0.35, size * 0.35, size * 0.2),
				WHITE,
				CFrame.new(side * spacing + size * 0.15, y + size * 0.15, z - size * 0.28)
			)
		end
	end
end

local function wing(b: Builder, size: Vector3, color: Color3, offset: CFrame, side: number, extra: { [string]: any }?)
	local part = add(b, "ball", size, color, offset, extra)
	part.Name = "Wing"
	part:SetAttribute("Side", side)
	return part
end

local function legs(b: Builder, color: Color3, y: number, xs: number, zs: number, size: number)
	for _, x in ipairs({ -xs, xs }) do
		for _, z in ipairs({ -zs, zs }) do
			add(b, "block", Vector3.new(size, size * 1.6, size), color, CFrame.new(x, y, z))
		end
	end
end

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function lighter(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

-- Four-legged body used by Sunpup and Crystal Fox.
local function quadruped(b: Builder, color: Color3, earColor: Color3)
	add(b, "ball", Vector3.new(1.5, 1.3, 2.0), color, CFrame.new())
	add(b, "ball", Vector3.new(1.0, 0.9, 1.2), lighter(color, 0.5), CFrame.new(0, -0.15, -0.5))
	add(b, "ball", Vector3.new(1.4, 1.3, 1.3), color, CFrame.new(0, 0.75, -0.95))
	add(b, "ball", Vector3.new(0.7, 0.5, 0.6), lighter(color, 0.5), CFrame.new(0, 0.55, -1.45))
	add(b, "ball", Vector3.new(0.25, 0.2, 0.2), BLACK, CFrame.new(0, 0.68, -1.75))
	eyes(b, 0.9, -1.52, 0.3, 0.3)
	for _, side in ipairs({ -1, 1 }) do
		add(
			b,
			"ball",
			Vector3.new(0.35, 0.8, 0.22),
			earColor,
			CFrame.new(side * 0.45, 1.5, -0.9) * CFrame.Angles(0, 0, math.rad(-side * 15))
		)
	end
	legs(b, color, -0.7, 0.42, 0.55, 0.35)
end

local RECIPES: { [number]: (Builder, any) -> number } = {
	-- 1 Sproutling
	[1] = function(b, c)
		add(b, "ball", Vector3.new(2, 1.9, 2), c.color, CFrame.new())
		add(b, "ball", Vector3.new(1.2, 0.9, 0.4), lighter(c.color, 0.35), CFrame.new(0, -0.35, -0.8))
		eyes(b, 0.2, -0.85, 0.38, 0.4)
		add(b, "block", Vector3.new(0.15, 0.5, 0.15), darker(c.color, 0.35), CFrame.new(0, 1.1, 0))
		for _, side in ipairs({ -1, 1 }) do
			add(
				b,
				"ball",
				Vector3.new(0.9, 0.12, 0.45),
				Color3.fromRGB(90, 210, 90),
				CFrame.new(side * 0.4, 1.38, 0) * CFrame.Angles(0, 0, math.rad(side * 25))
			)
		end
		return 0.95
	end,

	-- 2 Bubbles
	[2] = function(b, c)
		add(b, "ball", Vector3.new(2.2, 2.2, 2.2), c.color, CFrame.new(), {
			Transparency = 0.45,
			Material = Enum.Material.Glass,
		})
		add(b, "ball", Vector3.new(1.4, 1.4, 1.4), lighter(c.color, 0.4), CFrame.new(0, -0.1, 0))
		eyes(b, 0.15, -0.7, 0.3, 0.36)
		add(b, "ball", Vector3.new(0.5, 0.5, 0.3), WHITE, CFrame.new(-0.5, 0.65, -0.75), { Transparency = 0.3 })
		return 1.1
	end,

	-- 3 Pebblit
	[3] = function(b, c)
		add(b, "ball", Vector3.new(2.4, 1.6, 2.2), c.color, CFrame.new(), { Material = Enum.Material.Slate })
		add(b, "ball", Vector3.new(0.8, 0.5, 0.7), darker(c.color, 0.2), CFrame.new(0.45, 0.75, 0.2), {
			Material = Enum.Material.Slate,
		})
		add(b, "ball", Vector3.new(0.5, 0.35, 0.5), Color3.fromRGB(110, 170, 90), CFrame.new(-0.5, 0.75, 0.4))
		eyes(b, 0.15, -1.02, 0.4, 0.4, true)
		return 0.8
	end,

	-- 4 Flutterbug
	[4] = function(b, c)
		add(b, "ball", Vector3.new(1.0, 1.0, 1.5), c.color, CFrame.new(0, 0, 0.2))
		add(b, "ball", Vector3.new(0.9, 0.9, 0.9), lighter(c.color, 0.3), CFrame.new(0, 0.25, -0.75))
		eyes(b, 0.35, -1.15, 0.22, 0.3)
		for _, side in ipairs({ -1, 1 }) do
			wing(b, Vector3.new(1.6, 0.08, 1.1), Color3.fromRGB(255, 240, 250), CFrame.new(side * 0.95, 0.4, 0.1), side, {
				Transparency = 0.25,
			})
			add(
				b,
				"block",
				Vector3.new(0.06, 0.6, 0.06),
				darker(c.color, 0.5),
				CFrame.new(side * 0.2, 0.9, -0.85) * CFrame.Angles(math.rad(-20), 0, math.rad(-side * 20))
			)
		end
		return 0.5
	end,

	-- 5 Sunpup
	[5] = function(b, c)
		quadruped(b, c.color, Color3.fromRGB(235, 150, 50))
		add(
			b,
			"ball",
			Vector3.new(0.35, 0.35, 1.0),
			Color3.fromRGB(235, 150, 50),
			CFrame.new(0, 0.45, 1.15) * CFrame.Angles(math.rad(35), 0, 0)
		)
		return 1.05
	end,

	-- 6 Shellby
	[6] = function(b, c)
		add(b, "ball", Vector3.new(1.4, 0.8, 2.0), c.color, CFrame.new(0, -0.1, -0.1))
		add(b, "ball", Vector3.new(1.7, 1.5, 1.7), Color3.fromRGB(250, 215, 170), CFrame.new(0, 0.5, 0.35))
		add(b, "ball", Vector3.new(0.1, 1.0, 1.0), Color3.fromRGB(220, 160, 120), CFrame.new(0.86, 0.5, 0.35))
		add(b, "ball", Vector3.new(0.1, 1.0, 1.0), Color3.fromRGB(220, 160, 120), CFrame.new(-0.86, 0.5, 0.35))
		for _, side in ipairs({ -1, 1 }) do
			add(b, "block", Vector3.new(0.1, 0.6, 0.1), c.color, CFrame.new(side * 0.25, 0.35, -0.85))
			add(b, "ball", Vector3.new(0.3, 0.3, 0.3), BLACK, CFrame.new(side * 0.25, 0.7, -0.85))
		end
		return 0.5
	end,

	-- 7 Glowfin
	[7] = function(b, c)
		local neon = { Material = Enum.Material.Neon, Transparency = 0.15 }
		add(b, "ball", Vector3.new(1.1, 1.3, 2.3), c.color, CFrame.new())
		add(b, "ball", Vector3.new(0.9, 0.8, 1.8), lighter(c.color, 0.55), CFrame.new(0, -0.25, -0.1))
		add(b, "ball", Vector3.new(0.12, 1.3, 0.9), c.color, CFrame.new(0, 0, 1.4), neon)
		add(b, "ball", Vector3.new(0.1, 0.7, 0.9), c.color, CFrame.new(0, 0.7, 0.1), neon)
		for _, side in ipairs({ -1, 1 }) do
			wing(b, Vector3.new(0.7, 0.08, 0.45), c.color, CFrame.new(side * 0.6, -0.2, -0.2), side, neon)
		end
		eyes(b, 0.2, -0.95, 0.38, 0.3)
		return 0.65
	end,

	-- 8 Mossback
	[8] = function(b, c)
		local skin = Color3.fromRGB(160, 150, 105)
		add(b, "ball", Vector3.new(2.2, 0.8, 2.6), skin, CFrame.new(0, -0.15, 0))
		add(b, "ball", Vector3.new(2.5, 1.6, 2.9), c.color, CFrame.new(0, 0.35, 0), { Material = Enum.Material.Grass })
		for _, pos in ipairs({ Vector3.new(-0.5, 1.1, 0.2), Vector3.new(0.4, 1.05, -0.4), Vector3.new(0.2, 1.1, 0.7) }) do
			add(b, "ball", Vector3.new(0.6, 0.45, 0.6), Color3.fromRGB(120, 200, 80), CFrame.new(pos))
		end
		add(b, "ball", Vector3.new(0.3, 0.3, 0.3), Color3.fromRGB(230, 60, 80), CFrame.new(0.25, 1.35, 0.7))
		add(b, "ball", Vector3.new(0.9, 0.8, 1.0), skin, CFrame.new(0, 0.05, -1.65))
		eyes(b, 0.2, -2.05, 0.25, 0.25)
		legs(b, skin, -0.5, 0.8, 0.9, 0.45)
		return 0.85
	end,

	-- 9 Crystal Fox
	[9] = function(b, c)
		quadruped(b, c.color, Color3.fromRGB(140, 200, 255))
		for i = 1, 3 do
			add(
				b,
				"block",
				Vector3.new(0.3, 0.3, 0.8),
				Color3.fromRGB(140, 220, 255),
				CFrame.new(0, 0.3 + i * 0.22, 0.85 + i * 0.35) * CFrame.Angles(math.rad(30 + i * 8), math.rad(45), 0),
				{ Material = Enum.Material.Neon, Transparency = 0.2 }
			)
		end
		return 1.05
	end,

	-- 10 Golden Griffin
	[10] = function(b, c)
		add(b, "ball", Vector3.new(1.7, 1.5, 2.5), c.color, CFrame.new(), { Material = Enum.Material.Foil })
		add(b, "ball", Vector3.new(1.3, 1.3, 1.3), Color3.fromRGB(250, 245, 230), CFrame.new(0, 1.0, -1.3))
		add(b, "ball", Vector3.new(0.4, 0.35, 0.7), Color3.fromRGB(255, 150, 40), CFrame.new(0, 0.85, -2.05))
		eyes(b, 1.2, -1.85, 0.33, 0.3)
		for _, side in ipairs({ -1, 1 }) do
			wing(b, Vector3.new(2.8, 0.14, 1.4), darker(c.color, 0.1), CFrame.new(side * 1.7, 0.5, 0.1), side, {
				Material = Enum.Material.Foil,
			})
			add(
				b,
				"ball",
				Vector3.new(0.25, 0.6, 0.15),
				Color3.fromRGB(250, 245, 230),
				CFrame.new(side * 0.35, 1.75, -1.2) * CFrame.Angles(0, 0, math.rad(-side * 20))
			)
		end
		add(b, "ball", Vector3.new(0.5, 0.3, 1.3), darker(c.color, 0.2), CFrame.new(0, 0.2, 1.6))
		legs(b, Color3.fromRGB(255, 150, 40), -0.8, 0.45, 0.6, 0.3)
		return 1.15
	end,
}

local function defaultRecipe(b: Builder, c): number
	add(b, "ball", Vector3.new(2, 2, 2), c.color, CFrame.new())
	eyes(b, 0.2, -0.85, 0.38, 0.4)
	return 1
end

local function addRarityEffects(b: Builder, creature)
	local rank = Rarities.Info[creature.rarity].rank
	if rank >= 4 then
		local light = Instance.new("PointLight")
		light.Color = creature.color
		light.Range = 8
		light.Brightness = 1
		light.Shadows = false
		light.Parent = b.root
	end
	if rank >= 5 then
		local attachment = Instance.new("Attachment")
		attachment.Parent = b.root
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Name = "RaritySparkle"
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Rate = 4
		sparkle.Lifetime = NumberRange.new(0.8, 1.4)
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Size = NumberSequence.new(0.35, 0)
		sparkle.Color = ColorSequence.new(lighter(creature.color, 0.4))
		sparkle.LightEmission = 1
		sparkle.Parent = attachment
	end
end

-- Builds a fresh model for a creature id, positioned at the origin.
function CreatureModels.Build(creatureId: number): Model
	local creature = Creatures.Get(creatureId)
	assert(creature, "Unknown creature id " .. tostring(creatureId))
	local b = newBuilder(creature.name)
	local recipe = RECIPES[creatureId] or defaultRecipe
	local halfHeight = recipe(b, creature)
	addRarityEffects(b, creature)
	b.model:SetAttribute("HalfHeight", halfHeight)
	b.model:SetAttribute("Move", creature.move or "walk")
	b.model:SetAttribute("CreatureId", creatureId)
	return b.model
end

-- Turns a model into a black silhouette (for undiscovered creatures).
function CreatureModels.Silhouette(model: Model)
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("BasePart") and inst.Name ~= "Root" then
			inst.Color = Color3.fromRGB(12, 12, 18)
			inst.Material = Enum.Material.SmoothPlastic
			inst.Transparency = 0
		elseif inst:IsA("Light") or inst:IsA("ParticleEmitter") then
			inst:Destroy()
		end
	end
end

return CreatureModels
