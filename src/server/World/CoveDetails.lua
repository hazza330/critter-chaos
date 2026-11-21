--[[
	CoveDetails
	Second detail pass for Critter Cove. CritterCove builds the landforms and
	main areas; this adds the small things that make each place feel lived in.

	  Plaza    Griffin statue on the fountain, floor pattern, bunting between
	           lanterns, benches, planters, market stalls (Market opens in Stage 3),
	           barrels and crates
	  Beach    huts on stilts, umbrellas and towels, deckchairs, lifeguard tower,
	           campfire with log seats, sandcastle, shells, starfish, driftwood,
	           buoys and a second boat that bob on the water
	  Meadow   windmill with turning sails, grass tufts, extra bushes
	  Woods    pine trees, fallen logs, stumps, ferns, glowing mushrooms,
	           a ruined stone arch
	  Cliffs   hanging vines and flower ledges
	  Secrets  three treasure chests (see TreasureService)

	Moving parts are tagged for the client to animate:
	  "Spinner"  anchored hub, rotated about its local X axis (Speed attribute)
	  "Bobber"   anchored base, bobbed and rocked like a floating object
	  "NightOnly" particle emitters switched on at night by the day cycle
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local CreatureModels = require(ReplicatedStorage.Shared.CreatureModels)

local rng = Builder.rng
local groundY, part, decor, ball, make, weldTo =
	Builder.groundY, Builder.part, Builder.decor, Builder.ball, Builder.make, Builder.weldTo
local surfaceText, particles = Builder.surfaceText, Builder.particles
local rock, mushroom, flower = Builder.rock, Builder.mushroom, Builder.flower

local CoveDetails = {}

local WOOD = Color3.fromRGB(150, 110, 75)
local DARK_WOOD = Color3.fromRGB(110, 80, 55)
local STONE = Color3.fromRGB(190, 185, 175)

local mapFolder: Instance

-------------------------------------------------------------------------------
-- Small reusable props
-------------------------------------------------------------------------------

local function crate(position: Vector3, size: number, yaw: number)
	decor(part({
		Name = "Crate",
		Size = Vector3.new(size, size, size),
		CFrame = CFrame.new(position + Vector3.new(0, size / 2, 0)) * CFrame.Angles(0, yaw, 0),
		Color = Color3.fromRGB(180, 140, 90),
		Material = Enum.Material.WoodPlanks,
	}))
end

local function barrel(position: Vector3)
	decor(part({
		Name = "Barrel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 2.4, 2.4),
		CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(140, 95, 60),
		Material = Enum.Material.Wood,
	}))
	for _, dy in ipairs({ 0.5, 2.5 }) do
		decor(part({
			Name = "BarrelBand",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.25, 2.5, 2.5),
			CFrame = CFrame.new(position + Vector3.new(0, dy, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(70, 70, 75),
			Material = Enum.Material.Metal,
			CanCollide = false,
		}))
	end
end

local function bench(cf: CFrame)
	-- cf faces the direction a sitter would look.
	decor(part({ Name = "BenchSeat", Size = Vector3.new(6, 0.4, 1.6), CFrame = cf * CFrame.new(0, 1.6, 0), Color = WOOD, Material = Enum.Material.WoodPlanks }))
	decor(part({
		Name = "BenchBack",
		Size = Vector3.new(6, 1.6, 0.3),
		CFrame = cf * CFrame.new(0, 2.6, 0.75) * CFrame.Angles(math.rad(-10), 0, 0),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
	}))
	for _, x in ipairs({ -2.5, 2.5 }) do
		decor(part({ Name = "BenchLeg", Size = Vector3.new(0.4, 1.5, 1.4), CFrame = cf * CFrame.new(x, 0.75, 0), Color = Color3.fromRGB(60, 60, 65), Material = Enum.Material.Metal }))
	end
end

local function planter(position: Vector3, yaw: number)
	local cf = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	decor(part({ Name = "Planter", Size = Vector3.new(6, 1.6, 2.4), CFrame = cf * CFrame.new(0, 0.8, 0), Color = STONE, Material = Enum.Material.Brick }))
	decor(part({ Name = "PlanterSoil", Size = Vector3.new(5.6, 0.2, 2), CFrame = cf * CFrame.new(0, 1.62, 0), Color = Color3.fromRGB(90, 65, 45), Material = Enum.Material.Ground }))
	for i = 1, 6 do
		local local_ = cf * CFrame.new(-2.3 + i * 0.75, 0, rng:NextNumber(-0.5, 0.5))
		local p = local_.Position
		ball(Vector3.new(p.X, position.Y + 2.1, p.Z), Vector3.new(0.9, 0.9, 0.9), Color3.fromRGB(60, 150, 60))
		ball(Vector3.new(p.X, position.Y + 2.6, p.Z), Vector3.new(0.6, 0.4, 0.6), ({
			Color3.fromRGB(255, 120, 160),
			Color3.fromRGB(255, 220, 90),
			Color3.fromRGB(170, 130, 255),
		})[rng:NextInteger(1, 3)])
	end
end

local function grassTuft(x: number, z: number)
	local y = groundY(x, z)
	local colour = Color3.fromRGB(90, 170, 70):Lerp(Color3.fromRGB(140, 200, 80), rng:NextNumber())
	for i = 1, 3 do
		local h = rng:NextNumber(1.2, 2.4)
		decor(make("WedgePart", {
			Name = "GrassBlade",
			Size = Vector3.new(0.15, h, 0.6),
			CFrame = CFrame.new(x, y + h / 2, z) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), i * 2.1, rng:NextNumber(-0.25, 0.25)),
			Color = colour,
			CanCollide = false,
			CastShadow = false,
		}))
	end
end

local function pine(x: number, z: number, scale: number)
	local y = groundY(x, z)
	decor(part({
		Name = "PineTrunk",
		Size = Vector3.new(1.2, 6, 1.2) * scale,
		Position = Vector3.new(x, y + 3 * scale, z),
		Color = Color3.fromRGB(100, 70, 50),
		Material = Enum.Material.Wood,
	}))
	local green = Color3.fromRGB(50, 120, 70):Lerp(Color3.fromRGB(70, 150, 80), rng:NextNumber())
	for i = 0, 3 do
		local size = (7 - i * 1.6) * scale
		local layerPos = Vector3.new(x, y + (5 + i * 2.4) * scale, z)
		-- Two crossed pairs of wedges read as a cone from every angle.
		for r = 0, 1 do
			for _, flip in ipairs({ 0, math.pi }) do
				decor(make("WedgePart", {
					Name = "PineNeedles",
					Size = Vector3.new(0.4, 3.2 * scale, size / 2),
					CFrame = CFrame.new(layerPos) * CFrame.Angles(0, r * math.pi / 2 + flip, 0) * CFrame.new(0, 0, size / 4),
					Color = green,
					CanCollide = false,
				}))
			end
		end
		decor(part({
			Name = "PineCore",
			Size = Vector3.new(size * 0.45, 2.2 * scale, size * 0.45),
			Position = layerPos - Vector3.new(0, 0.4 * scale, 0),
			Color = green,
			CanCollide = false,
		}))
	end
end

local function fern(x: number, z: number)
	local y = groundY(x, z)
	for i = 1, 6 do
		local yaw = (i / 6) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		ball(
			CFrame.new(x, y + 0.5, z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(25), 0, 0) * CFrame.new(0, 0, -1.2) :: any,
			Vector3.new(0.7, 0.12, 2.6),
			Color3.fromRGB(70, 150, 70)
		)
	end
end

local function log(x: number, z: number, length: number, yaw: number)
	local y = groundY(x, z)
	decor(part({
		Name = "Log",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, 1.8, 1.8),
		CFrame = CFrame.new(x, y + 0.8, z) * CFrame.Angles(0, yaw, 0),
		Color = Color3.fromRGB(120, 85, 60),
		Material = Enum.Material.Wood,
	}))
	ball(CFrame.new(x, y + 1.7, z) * CFrame.Angles(0, yaw, 0) * CFrame.new(rng:NextNumber(-1, 1), 0, 0) :: any, Vector3.new(1.4, 0.4, 1), Color3.fromRGB(100, 170, 70))
end

local function stump(x: number, z: number)
	local y = groundY(x, z)
	decor(part({
		Name = "Stump",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, 2.2, 2.2),
		CFrame = CFrame.new(x, y + 0.8, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(120, 85, 60),
		Material = Enum.Material.Wood,
	}))
	decor(part({
		Name = "StumpTop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, 2, 2),
		CFrame = CFrame.new(x, y + 1.62, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(210, 170, 120),
		Material = Enum.Material.Wood,
		CanCollide = false,
	}))
end

local function shell(x: number, z: number)
	local y = groundY(x, z)
	local colours = {
		Color3.fromRGB(255, 220, 210),
		Color3.fromRGB(255, 190, 160),
		Color3.fromRGB(250, 240, 220),
		Color3.fromRGB(240, 170, 200),
	}
	if rng:NextNumber() < 0.3 then
		-- Starfish
		local colour = if rng:NextNumber() < 0.5 then Color3.fromRGB(255, 120, 80) else Color3.fromRGB(240, 90, 120)
		local yaw = rng:NextNumber(0, 6)
		for i = 1, 5 do
			ball(
				CFrame.new(x, y + 0.1, z) * CFrame.Angles(0, yaw + i * (math.pi * 2 / 5), 0) * CFrame.new(0, 0, -0.45) :: any,
				Vector3.new(0.35, 0.15, 0.9),
				colour
			)
		end
	else
		ball(
			CFrame.new(x, y + 0.15, z) * CFrame.Angles(0, rng:NextNumber(0, 6), 0) :: any,
			Vector3.new(0.7, 0.35, 0.6),
			colours[rng:NextInteger(1, #colours)]
		)
	end
end

-------------------------------------------------------------------------------
-- Plaza
-------------------------------------------------------------------------------

local function buildPlaza()
	local y = groundY(0, 0)

	-- Floor pattern: spokes radiating from the fountain
	for i = 0, 15 do
		local a = (i / 16) * math.pi * 2
		decor(part({
			Name = "FloorLine",
			Size = Vector3.new(0.35, 0.1, 15),
			CFrame = CFrame.new(0, y + 1.05, -8) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 17),
			Color = Color3.fromRGB(205, 180, 140),
			Material = Enum.Material.Slate,
			CanCollide = false,
		}))
	end

	-- Golden Griffin statue on top of the fountain, carved in marble with gold wings.
	local ok, statue = pcall(CreatureModels.Build, 10)
	if ok then
		statue.Name = "GriffinStatue"
		for _, inst in ipairs(statue:GetDescendants()) do
			if inst:IsA("BasePart") then
				inst.Anchored = true
				inst.CanCollide = false
				inst.CanQuery = false
				if inst.Name == "Wing" then
					inst.Material = Enum.Material.Foil
					inst.Color = Color3.fromRGB(240, 190, 60)
				elseif inst.Name ~= "Root" then
					inst.Material = Enum.Material.Marble
					inst.Color = Color3.fromRGB(235, 232, 225)
				end
			elseif inst:IsA("Light") or inst:IsA("ParticleEmitter") or inst:IsA("JointInstance") then
				inst:Destroy()
			end
		end
		statue:ScaleTo(1.8)
		statue:PivotTo(CFrame.new(0, y + 10.2, -8) * CFrame.Angles(0, math.rad(180), 0))
		statue.Parent = mapFolder
	end

	-- Bunting strung between neighbouring lanterns
	local flagColours = {
		Color3.fromRGB(255, 90, 90),
		Color3.fromRGB(255, 200, 70),
		Color3.fromRGB(90, 190, 255),
		Color3.fromRGB(120, 220, 120),
		Color3.fromRGB(200, 120, 255),
	}
	for i = 1, 8 do
		local a1 = (i / 8) * math.pi * 2 + math.pi / 8
		local a2 = ((i + 1) / 8) * math.pi * 2 + math.pi / 8
		local p1 = Vector3.new(math.cos(a1) * 31, y + 8.6, math.sin(a1) * 31)
		local p2 = Vector3.new(math.cos(a2) * 31, y + 8.6, math.sin(a2) * 31)
		local flags = 9
		for f = 1, flags do
			local t = f / (flags + 1)
			local pos = p1:Lerp(p2, t) - Vector3.new(0, math.sin(t * math.pi) * 2, 0)
			decor(make("WedgePart", {
				Name = "Bunting",
				Size = Vector3.new(0.1, 1.4, 1.1),
				CFrame = CFrame.lookAt(pos, pos + (p2 - p1)) * CFrame.Angles(0, math.rad(90), math.rad(180)) * CFrame.new(0, 0.7, 0),
				Color = flagColours[(f + i) % #flagColours + 1],
				Material = Enum.Material.Fabric,
				CanCollide = false,
				CastShadow = false,
			}))
		end
	end

	-- Benches facing the fountain, away from the paths
	for _, deg in ipairs({ 35, 55, 125, 235, 305, 325 }) do
		local a = math.rad(deg)
		local pos = Vector3.new(math.cos(a) * 25, y + 0.9, math.sin(a) * 25)
		bench(CFrame.lookAt(pos, Vector3.new(0, pos.Y, -8)) * CFrame.Angles(0, math.pi, 0))
	end

	-- Planters by the paths
	planter(Vector3.new(36, y, -9), 0)
	planter(Vector3.new(36, y, 9), 0)
	planter(Vector3.new(-12, y, -40), math.rad(90))
	planter(Vector3.new(9, y, -40), math.rad(90))

	-- Market stalls on the west side. They become the Marketplace in Stage 3.
	local awnings = {
		{ Color3.fromRGB(230, 80, 80), Color3.fromRGB(255, 245, 235) },
		{ Color3.fromRGB(80, 150, 230), Color3.fromRGB(255, 245, 235) },
		{ Color3.fromRGB(240, 180, 60), Color3.fromRGB(255, 245, 235) },
		{ Color3.fromRGB(110, 190, 110), Color3.fromRGB(255, 245, 235) },
	}
	for i, deg in ipairs({ 152, 170, 190, 208 }) do
		local a = math.rad(deg)
		local pos = Vector3.new(math.cos(a) * 46, 0, math.sin(a) * 46)
		local gy = groundY(pos.X, pos.Z)
		local cf = CFrame.lookAt(Vector3.new(pos.X, gy, pos.Z), Vector3.new(0, gy, 0))
		decor(part({ Name = "StallCounter", Size = Vector3.new(9, 3.2, 3), CFrame = cf * CFrame.new(0, 1.6, -1), Color = WOOD, Material = Enum.Material.WoodPlanks }))
		for _, x in ipairs({ -4.2, 4.2 }) do
			for _, z in ipairs({ -2.3, 2 }) do
				decor(part({ Name = "StallPole", Size = Vector3.new(0.5, 8, 0.5), CFrame = cf * CFrame.new(x, 4, z), Color = DARK_WOOD, Material = Enum.Material.Wood }))
			end
		end
		for s = 0, 5 do
			decor(part({
				Name = "Awning",
				Size = Vector3.new(1.5, 0.2, 6),
				CFrame = cf * CFrame.new(-3.75 + s * 1.5, 8.2, -0.6) * CFrame.Angles(math.rad(-14), 0, 0),
				Color = awnings[i][(s % 2) + 1],
				Material = Enum.Material.Fabric,
				CanCollide = false,
			}))
		end
		-- Goods on the counter
		for g = 1, 5 do
			ball(
				(cf * CFrame.new(-3.4 + g * 1.4, 3.6, -1.3)).Position,
				Vector3.new(0.9, 0.9, 0.9),
				({ Color3.fromRGB(255, 90, 80), Color3.fromRGB(255, 200, 60), Color3.fromRGB(140, 210, 90), Color3.fromRGB(200, 120, 230) })[(g + i) % 4 + 1]
			)
		end
		crate((cf * CFrame.new(5.6, 0, 1)).Position, 2, rng:NextNumber(0, 1))
		if i % 2 == 0 then
			barrel((cf * CFrame.new(-5.8, 0, 1.4)).Position)
		end
	end
	local marketSign = part({
		Name = "MarketSign",
		Size = Vector3.new(12, 2.4, 0.4),
		CFrame = CFrame.lookAt(Vector3.new(-37, y + 10.5, 0), Vector3.new(0, y + 10.5, 0)),
		Color = Color3.fromRGB(255, 170, 60),
		Material = Enum.Material.Wood,
		Parent = mapFolder,
	})
	surfaceText(marketSign, Enum.NormalId.Front, "Market · opens in Stage 3", { stroke = true, padding = 6 })
	for _, z in ipairs({ -5.5, 5.5 }) do
		decor(part({ Name = "MarketSignPost", Size = Vector3.new(0.5, 10, 0.5), Position = Vector3.new(-37.3, y + 5, z), Color = DARK_WOOD, Material = Enum.Material.Wood }))
	end
end

-------------------------------------------------------------------------------
-- Beach
-------------------------------------------------------------------------------

local function onRing(deg: number, radius: number): (number, number)
	local a = math.rad(deg)
	return math.cos(a) * radius, math.sin(a) * radius
end

local function hut(deg: number)
	local x, z = onRing(deg, 226)
	local gy = groundY(x, z)
	local cf = CFrame.lookAt(Vector3.new(x, gy, z), Vector3.new(0, gy, 0))
	local floorY = 4
	for _, px in ipairs({ -3.5, 3.5 }) do
		for _, pz in ipairs({ -3.5, 3.5 }) do
			decor(part({ Name = "HutStilt", Size = Vector3.new(0.6, floorY + 1, 0.6), CFrame = cf * CFrame.new(px, (floorY + 1) / 2 - 1, pz), Color = DARK_WOOD, Material = Enum.Material.Wood }))
		end
	end
	decor(part({ Name = "HutFloor", Size = Vector3.new(9, 0.5, 9), CFrame = cf * CFrame.new(0, floorY, 0), Color = WOOD, Material = Enum.Material.WoodPlanks })).CanQuery = true
	-- Three walls, open at the front towards the island
	decor(part({ Name = "HutWall", Size = Vector3.new(8, 5, 0.4), CFrame = cf * CFrame.new(0, floorY + 2.75, 3.8), Color = Color3.fromRGB(230, 200, 150), Material = Enum.Material.WoodPlanks }))
	for _, side in ipairs({ -1, 1 }) do
		decor(part({ Name = "HutWall", Size = Vector3.new(0.4, 5, 8), CFrame = cf * CFrame.new(side * 3.8, floorY + 2.75, 0), Color = Color3.fromRGB(230, 200, 150), Material = Enum.Material.WoodPlanks }))
		-- Thatched roof halves
		decor(make("WedgePart", {
			Name = "HutRoof",
			Size = Vector3.new(10.5, 3, 5.5),
			CFrame = cf * CFrame.new(side * 2.6, floorY + 6.6, 0) * CFrame.Angles(0, math.rad(-side * 90), 0), -- slope faces outwards
			Color = Color3.fromRGB(200, 165, 90),
			Material = Enum.Material.Grass,
		}))
	end
	-- Steps up to the floor
	for s = 1, 3 do
		decor(part({ Name = "HutStep", Size = Vector3.new(3, 0.4, 1.2), CFrame = cf * CFrame.new(0, s * 1.2 - 0.4, -4.5 - (3 - s) * 1.2), Color = WOOD, Material = Enum.Material.WoodPlanks })).CanQuery = true
	end
end

local function umbrella(deg: number, radius: number, colour: Color3)
	local x, z = onRing(deg, radius)
	local gy = groundY(x, z)
	local tilt = rng:NextNumber(-0.12, 0.12)
	local pole = CFrame.new(x, gy, z) * CFrame.Angles(tilt, 0, tilt)
	decor(part({ Name = "UmbrellaPole", Size = Vector3.new(0.3, 8, 0.3), CFrame = pole * CFrame.new(0, 4, 0), Color = Color3.fromRGB(240, 240, 240) }))
	ball(pole * CFrame.new(0, 7.6, 0) :: any, Vector3.new(8, 1.8, 8), colour)
	ball(pole * CFrame.new(0, 7.75, 0) :: any, Vector3.new(4.5, 1.7, 4.5), Color3.fromRGB(255, 255, 255))
	ball(pole * CFrame.new(0, 8.5, 0) :: any, Vector3.new(0.6, 0.6, 0.6), colour)
	-- Towel and a deckchair underneath
	local yaw = math.rad(deg + 90)
	decor(part({
		Name = "Towel",
		Size = Vector3.new(2.6, 0.08, 5),
		CFrame = CFrame.new(x + 2, gy + 0.05, z) * CFrame.Angles(0, yaw, 0),
		Color = colour:Lerp(Color3.new(1, 1, 1), 0.3),
		Material = Enum.Material.Fabric,
		CanCollide = false,
	}))
	local chair = CFrame.new(x - 2.2, gy, z) * CFrame.Angles(0, yaw, 0)
	decor(part({ Name = "ChairSeat", Size = Vector3.new(2.2, 0.25, 3), CFrame = chair * CFrame.new(0, 1, 0), Color = colour, Material = Enum.Material.Fabric }))
	decor(part({ Name = "ChairBack", Size = Vector3.new(2.2, 0.25, 2.6), CFrame = chair * CFrame.new(0, 2, 2) * CFrame.Angles(math.rad(55), 0, 0), Color = colour, Material = Enum.Material.Fabric }))
	decor(part({ Name = "ChairFrame", Size = Vector3.new(2.4, 1, 0.2), CFrame = chair * CFrame.new(0, 0.5, -1.3), Color = Color3.fromRGB(240, 240, 240) }))
end

local function lifeguardTower(deg: number)
	local x, z = onRing(deg, 230)
	local gy = groundY(x, z)
	local cf = CFrame.lookAt(Vector3.new(x, gy, z), Vector3.new(x * 2, gy, z * 2)) -- faces the sea
	for _, px in ipairs({ -2, 2 }) do
		for _, pz in ipairs({ -2, 2 }) do
			decor(part({ Name = "TowerLeg", Size = Vector3.new(0.5, 9, 0.5), CFrame = cf * CFrame.new(px, 4.5, pz), Color = Color3.fromRGB(245, 245, 245), Material = Enum.Material.Wood }))
		end
	end
	decor(part({ Name = "TowerDeck", Size = Vector3.new(5, 0.4, 5), CFrame = cf * CFrame.new(0, 9, 0), Color = Color3.fromRGB(230, 80, 70), Material = Enum.Material.WoodPlanks }))
	decor(part({ Name = "TowerRoof", Size = Vector3.new(5.6, 0.3, 5.6), CFrame = cf * CFrame.new(0, 13, 0), Color = Color3.fromRGB(230, 80, 70), Material = Enum.Material.WoodPlanks }))
	for _, px in ipairs({ -2.5, 2.5 }) do
		decor(part({ Name = "TowerPost", Size = Vector3.new(0.3, 4, 0.3), CFrame = cf * CFrame.new(px, 11, -2.5), Color = Color3.fromRGB(245, 245, 245) }))
	end
	decor(part({ Name = "FlagPole", Size = Vector3.new(0.2, 4, 0.2), CFrame = cf * CFrame.new(2.6, 15, 2.6), Color = Color3.fromRGB(200, 200, 200), Material = Enum.Material.Metal }))
	decor(part({ Name = "Flag", Size = Vector3.new(0.05, 1.2, 2), CFrame = cf * CFrame.new(2.6, 16.3, 3.6), Color = Color3.fromRGB(255, 220, 60), Material = Enum.Material.Fabric, CanCollide = false }))
	-- Ladder
	for r = 1, 8 do
		decor(part({ Name = "LadderRung", Size = Vector3.new(1.6, 0.2, 0.2), CFrame = cf * CFrame.new(0, r * 1.1, 2.6), Color = Color3.fromRGB(245, 245, 245) }))
	end
	local ladder = make("TrussPart", {
		Name = "LadderClimb",
		Size = Vector3.new(2, 8, 2),
		CFrame = cf * CFrame.new(0, 4.5, 3), -- ladder faces the island
		Transparency = 1,
	})
	ladder.CanQuery = false
end

local function campfire(deg: number)
	local x, z = onRing(deg, 218)
	local gy = groundY(x, z)
	for i = 1, 9 do
		local a = (i / 9) * math.pi * 2
		ball(Vector3.new(x + math.cos(a) * 2.2, gy + 0.3, z + math.sin(a) * 2.2), Vector3.new(1, 0.7, 1), Color3.fromRGB(120, 115, 110))
	end
	for i = 1, 4 do
		decor(part({
			Name = "FireLog",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3, 0.6, 0.6),
			CFrame = CFrame.new(x, gy + 0.6, z) * CFrame.Angles(0, i * math.pi / 4, math.rad(25)),
			Color = Color3.fromRGB(90, 60, 40),
			Material = Enum.Material.Wood,
			CanCollide = false,
		}))
	end
	local core = decor(part({ Name = "FireCore", Size = Vector3.new(1, 0.5, 1), Position = Vector3.new(x, gy + 0.8, z), Transparency = 1, CanCollide = false }))
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 6
	fire.Color = Color3.fromRGB(255, 140, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
	fire.Parent = core
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 60)
	light.Range = 18
	light.Brightness = 2
	light.Shadows = false
	light.Parent = core
	-- Log seats around the fire
	for i = 1, 3 do
		local a = (i / 3) * math.pi * 2 + 0.5
		decor(part({
			Name = "LogSeat",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4.5, 1.6, 1.6),
			CFrame = CFrame.new(x + math.cos(a) * 5.5, gy + 0.6, z + math.sin(a) * 5.5) * CFrame.Angles(0, -a + math.pi / 2, 0),
			Color = Color3.fromRGB(120, 85, 60),
			Material = Enum.Material.Wood,
		}))
	end
end

local function sandcastle(deg: number)
	local x, z = onRing(deg, 233)
	local gy = groundY(x, z)
	local sand = Color3.fromRGB(230, 205, 150)
	decor(part({ Name = "CastleBase", Size = Vector3.new(6, 1.6, 6), Position = Vector3.new(x, gy + 0.8, z), Color = sand, Material = Enum.Material.Sand }))
	for _, dx in ipairs({ -2.5, 2.5 }) do
		for _, dz in ipairs({ -2.5, 2.5 }) do
			decor(part({ Name = "CastleTower", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 1.6, 1.6), CFrame = CFrame.new(x + dx, gy + 2.6, z + dz) * CFrame.Angles(0, 0, math.rad(90)), Color = sand, Material = Enum.Material.Sand }))
		end
	end
	decor(part({ Name = "CastleKeep", Size = Vector3.new(2.6, 3.4, 2.6), Position = Vector3.new(x, gy + 3.3, z), Color = sand, Material = Enum.Material.Sand }))
	decor(part({ Name = "CastleFlagPole", Size = Vector3.new(0.1, 2, 0.1), Position = Vector3.new(x, gy + 6, z), Color = Color3.fromRGB(240, 240, 240), CanCollide = false }))
	decor(part({ Name = "CastleFlag", Size = Vector3.new(0.05, 0.6, 1), Position = Vector3.new(x, gy + 6.6, z + 0.5), Color = Color3.fromRGB(255, 80, 80), CanCollide = false }))
	-- Bucket and spade
	decor(part({ Name = "Bucket", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 1.1, 1.1), CFrame = CFrame.new(x + 4.5, gy + 0.6, z + 1) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(80, 160, 255) }))
end

local function bobbingBoat(position: Vector3, yaw: number, colour: Color3)
	local base = part({
		Name = "BoatHull",
		Size = Vector3.new(5, 2, 11),
		CFrame = CFrame.new(position) * CFrame.Angles(0, yaw, 0),
		Color = colour,
		Material = Enum.Material.Wood,
		CanCollide = false,
	})
	decor(base)
	local function child(props)
		local p = decor(part(props))
		weldTo(base, p)
	end
	child({ Name = "BoatTrim", Size = Vector3.new(5.2, 0.3, 11.2), CFrame = base.CFrame * CFrame.new(0, 1.1, 0), Color = Color3.fromRGB(250, 245, 230), CanCollide = false })
	child({ Name = "BoatMast", Size = Vector3.new(0.4, 10, 0.4), CFrame = base.CFrame * CFrame.new(0, 6, 0), Color = Color3.fromRGB(120, 85, 60), CanCollide = false })
	child({ Name = "BoatSail", Size = Vector3.new(0.15, 7, 5), CFrame = base.CFrame * CFrame.new(0.3, 7, 2.8), Color = Color3.fromRGB(250, 245, 230), Material = Enum.Material.Fabric, CanCollide = false })
	CollectionService:AddTag(base, "Bobber")
end

local function buoy(position: Vector3)
	local base = decor(part({
		Name = "Buoy",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 2, 2),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(240, 70, 60),
		CanCollide = false,
	}))
	local top = decor(part({ Name = "BuoyTop", Size = Vector3.new(0.3, 2, 0.3), Position = position + Vector3.new(0, 2, 0), Color = Color3.fromRGB(250, 250, 250), CanCollide = false }))
	weldTo(base, top)
	local lamp = decor(part({ Name = "BuoyLight", Size = Vector3.new(0.5, 0.5, 0.5), Position = position + Vector3.new(0, 3.1, 0), Color = Color3.fromRGB(255, 220, 90), Material = Enum.Material.Neon, CanCollide = false }))
	weldTo(base, lamp)
	CollectionService:AddTag(base, "Bobber")
end

local function buildBeach()
	for _, deg in ipairs({ 101, 107, 113 }) do
		hut(deg)
	end
	local umbrellaColours = {
		Color3.fromRGB(255, 90, 90),
		Color3.fromRGB(80, 170, 255),
		Color3.fromRGB(255, 200, 60),
		Color3.fromRGB(140, 220, 120),
		Color3.fromRGB(220, 120, 240),
	}
	for i, deg in ipairs({ 62, 67, 72, 77, 84 }) do
		umbrella(deg, 230 + (i % 2) * 3, umbrellaColours[i])
	end
	lifeguardTower(80)
	campfire(128)
	sandcastle(95)

	-- Shells, starfish and driftwood all around the shore
	for _ = 1, 70 do
		local x, z = onRing(rng:NextNumber(0, 360), rng:NextNumber(222, 238))
		if not (z < -150 and x > -100 and x < 80) then
			shell(x, z)
		end
	end
	for _ = 1, 8 do
		local x, z = onRing(rng:NextNumber(0, 360), rng:NextNumber(228, 236))
		if not (z < -150 and x > -100 and x < 80) then
			log(x, z, rng:NextNumber(4, 7), rng:NextNumber(0, 6))
		end
	end

	bobbingBoat(Vector3.new(-120, 0.6, 270), math.rad(30), Color3.fromRGB(80, 140, 230))
	bobbingBoat(Vector3.new(230, 0.6, 150), math.rad(-60), Color3.fromRGB(250, 200, 70))
	for _, deg in ipairs({ 20, 75, 140, 200, 250, 320 }) do
		local x, z = onRing(deg, 285)
		buoy(Vector3.new(x, 0.4, z))
	end
end

-------------------------------------------------------------------------------
-- Meadow
-------------------------------------------------------------------------------

local function windmill(x: number, z: number)
	local gy = groundY(x, z)
	local cf = CFrame.lookAt(Vector3.new(x, gy, z), Vector3.new(0, gy, 0))
	-- Tapering tower
	for i = 0, 4 do
		local w = 7 - i * 0.9
		decor(part({
			Name = "WindmillTower",
			Size = Vector3.new(w, 3.2, w),
			CFrame = cf * CFrame.new(0, 1.6 + i * 3.2, 0),
			Color = if i % 2 == 0 then Color3.fromRGB(245, 240, 230) else Color3.fromRGB(235, 228, 215),
			Material = Enum.Material.Brick,
		}))
	end
	decor(make("WedgePart", { Name = "WindmillRoof", Size = Vector3.new(3.6, 3, 3.2), CFrame = cf * CFrame.new(0, 18.4, -1.6), Color = Color3.fromRGB(200, 80, 60) }))
	decor(make("WedgePart", { Name = "WindmillRoof", Size = Vector3.new(3.6, 3, 3.2), CFrame = cf * CFrame.new(0, 18.4, 1.6) * CFrame.Angles(0, math.pi, 0), Color = Color3.fromRGB(200, 80, 60) }))
	decor(part({ Name = "WindmillDoor", Size = Vector3.new(2, 3.4, 0.2), CFrame = cf * CFrame.new(0, 1.7, -3.5), Color = DARK_WOOD, Material = Enum.Material.Wood }))

	-- Hub (anchored, spun by the client) with four sails welded to it.
	local hub = decor(part({
		Name = "WindmillHub",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.4, 1.6, 1.6),
		CFrame = cf * CFrame.new(0, 14.5, -3.2) * CFrame.Angles(0, math.rad(90), 0),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
	}))
	hub:SetAttribute("Speed", 0.8)
	for i = 0, 3 do
		local arm = cf * CFrame.new(0, 14.5, -3.6) * CFrame.Angles(0, 0, i * math.pi / 2)
		local spar = decor(part({ Name = "WindmillSpar", Size = Vector3.new(0.4, 9, 0.3), CFrame = arm * CFrame.new(0, 4.6, 0), Color = DARK_WOOD, Material = Enum.Material.Wood, CanCollide = false }))
		weldTo(hub, spar)
		local sail = decor(part({ Name = "WindmillSail", Size = Vector3.new(2.4, 7, 0.1), CFrame = arm * CFrame.new(1.3, 5, 0), Color = Color3.fromRGB(250, 245, 235), Material = Enum.Material.Fabric, CanCollide = false }))
		weldTo(hub, sail)
	end
	CollectionService:AddTag(hub, "Spinner")
end

local function buildMeadowDetails()
	windmill(176, 92)
	for _ = 1, 90 do
		local x, z = rng:NextNumber(65, 200), rng:NextNumber(-110, 120)
		if (Vector2.new(x, z) - Vector2.new(110, 30)).Magnitude > 18 then
			grassTuft(x, z)
		end
	end
	-- Grass tufts around the plaza edge too
	for _ = 1, 40 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(36, 60)
		grassTuft(math.cos(a) * r, math.sin(a) * r)
	end
	-- Plain decorative bushes (no sparkles, so they don't look searchable)
	for _ = 1, 18 do
		local x, z = rng:NextNumber(-190, 200), rng:NextNumber(-140, 190)
		if math.abs(x) > 40 or math.abs(z) > 40 then
			local gy = groundY(x, z)
			local s = rng:NextNumber(2, 3.4)
			ball(Vector3.new(x, gy + s * 0.35, z), Vector3.new(s * 1.4, s, s * 1.2), Color3.fromRGB(70, 140, 70))
		end
	end
	-- Fireflies over the pond at night
	local fireflies = decor(part({ Name = "Fireflies", Size = Vector3.new(50, 6, 50), Position = Vector3.new(110, 6, 30), Transparency = 1, CanCollide = false }))
	local emitter = particles(fireflies, {
		Rate = 10,
		Lifetime = NumberRange.new(3, 6),
		Speed = NumberRange.new(0.2, 0.8),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(0.25),
		Color = ColorSequence.new(Color3.fromRGB(220, 255, 120)),
		LightEmission = 1,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})
	emitter.Enabled = false
	CollectionService:AddTag(emitter, "NightOnly")
end

-------------------------------------------------------------------------------
-- West woods
-------------------------------------------------------------------------------

local function ruinedArch(x: number, z: number)
	local gy = groundY(x, z)
	local cf = CFrame.new(x, gy, z) * CFrame.Angles(0, math.rad(20), 0)
	local mossy = Color3.fromRGB(150, 160, 140)
	for _, side in ipairs({ -1, 1 }) do
		for i = 0, 3 do
			decor(part({
				Name = "ArchBlock",
				Size = Vector3.new(2.6, 2.6, 2.6),
				CFrame = cf * CFrame.new(side * 5, 1.3 + i * 2.6, 0) * CFrame.Angles(0, rng:NextNumber(-0.08, 0.08), 0),
				Color = mossy:Lerp(Color3.fromRGB(120, 130, 110), rng:NextNumber()),
				Material = Enum.Material.Cobblestone,
			}))
		end
		ball(cf * CFrame.new(side * 5, 10.6, 0) :: any, Vector3.new(3, 0.8, 3), Color3.fromRGB(90, 160, 70))
	end
	-- Lintel, slightly fallen on one side
	decor(part({
		Name = "ArchLintel",
		Size = Vector3.new(13, 2.2, 2.8),
		CFrame = cf * CFrame.new(0, 11.4, 0) * CFrame.Angles(0, 0, math.rad(4)),
		Color = mossy,
		Material = Enum.Material.Cobblestone,
	}))
	local runes = decor(part({
		Name = "ArchRunes",
		Size = Vector3.new(9, 1.6, 0.1),
		CFrame = cf * CFrame.new(0, 11.4, -1.45) * CFrame.Angles(0, 0, math.rad(4)),
		Transparency = 1,
		CanCollide = false,
	}))
	surfaceText(runes, Enum.NormalId.Front, "ᚠ ᛟ ᛚ ᛚ ᛟ ᚹ  ᛏ ᚺ ᛖ  ᛊ ᛏ ᚨ ᚱ ᛊ", {
		color = Color3.fromRGB(140, 255, 220),
		font = Enum.Font.Arcade,
		padding = 2,
	})
	-- Fallen blocks
	for _ = 1, 4 do
		local p = cf * CFrame.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-6, 6))
		local s = rng:NextNumber(1.4, 2.4)
		decor(part({
			Name = "Rubble",
			Size = Vector3.new(s, s, s),
			CFrame = CFrame.new(p.Position + Vector3.new(0, s / 2 - 0.3, 0)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 6), rng:NextNumber(0, 1)),
			Color = mossy,
			Material = Enum.Material.Cobblestone,
		}))
	end
	return cf
end

local function glowMushroom(x: number, z: number)
	local gy = groundY(x, z)
	local s = rng:NextNumber(0.5, 0.9)
	decor(part({ Name = "GlowStem", Size = Vector3.new(0.3, 1.2, 0.3) * s, Position = Vector3.new(x, gy + 0.5 * s, z), Color = Color3.fromRGB(230, 230, 240), CanCollide = false }))
	ball(Vector3.new(x, gy + 1.1 * s, z), Vector3.new(1.2, 0.6, 1.2) * s, Color3.fromRGB(90, 200, 255), { Material = Enum.Material.Neon })
end

local function buildWoods()
	for _ = 1, 26 do
		local x, z = rng:NextNumber(-195, -60), rng:NextNumber(-110, 150)
		if (Vector2.new(x, z) - Vector2.new(-150, 40)).Magnitude > 14 and (Vector2.new(x, z).Magnitude < 205) then
			pine(x, z, rng:NextNumber(0.9, 1.4))
		end
	end
	for _ = 1, 8 do
		log(rng:NextNumber(-190, -70), rng:NextNumber(-100, 140), rng:NextNumber(5, 9), rng:NextNumber(0, 6))
	end
	for _ = 1, 10 do
		stump(rng:NextNumber(-190, -70), rng:NextNumber(-100, 140))
	end
	for _ = 1, 28 do
		fern(rng:NextNumber(-195, -60), rng:NextNumber(-110, 150))
	end
	for _ = 1, 22 do
		glowMushroom(rng:NextNumber(-185, -70), rng:NextNumber(-90, 140))
	end
	ruinedArch(-150, 40)

	local glow = decor(part({ Name = "WoodsFireflies", Size = Vector3.new(110, 8, 220), Position = Vector3.new(-128, 10, 20), Transparency = 1, CanCollide = false }))
	local emitter = particles(glow, {
		Rate = 14,
		Lifetime = NumberRange.new(4, 7),
		Speed = NumberRange.new(0.2, 0.6),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(0.22),
		Color = ColorSequence.new(Color3.fromRGB(160, 255, 200)),
		LightEmission = 1,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})
	emitter.Enabled = false
	CollectionService:AddTag(emitter, "NightOnly")

	local sign = part({
		Name = "WoodsSign",
		Size = Vector3.new(10, 2.4, 0.5),
		CFrame = CFrame.lookAt(Vector3.new(-58, groundY(-58, 30) + 4.5, 30), Vector3.new(0, groundY(-58, 30) + 4.5, 30)),
		Color = Color3.fromRGB(90, 140, 90),
		Material = Enum.Material.Wood,
		Parent = mapFolder,
	})
	surfaceText(sign, Enum.NormalId.Front, "Whispering Woods", { stroke = true, padding = 6 })
	surfaceText(sign, Enum.NormalId.Back, "Whispering Woods", { stroke = true, padding = 6 })
	decor(part({ Name = "WoodsSignPost", Size = Vector3.new(0.6, 6, 0.6), Position = sign.Position - Vector3.new(0, 2.5, 0), Color = DARK_WOOD, Material = Enum.Material.Wood }))
end

-------------------------------------------------------------------------------
-- Cliffs
-------------------------------------------------------------------------------

local function buildCliffDetails()
	for x = -82, 62, 3 do
		if x < -21 or x > 1 then
			if rng:NextNumber() < 0.65 then
				local length = rng:NextNumber(4, 14)
				decor(part({
					Name = "Vine",
					Size = Vector3.new(0.3, length, 0.3),
					Position = Vector3.new(x + rng:NextNumber(-1, 1), 32 - length / 2, -154.6),
					Color = Color3.fromRGB(60, 140, 60):Lerp(Color3.fromRGB(100, 170, 70), rng:NextNumber()),
					CanCollide = false,
					CastShadow = false,
				}))
				if rng:NextNumber() < 0.4 then
					ball(Vector3.new(x, 32 - length, -154.4), Vector3.new(0.6, 0.6, 0.6), Color3.fromRGB(255, 140, 180))
				end
			end
		end
	end
	-- Flowers along the cliff top edge
	for _ = 1, 30 do
		local x = rng:NextNumber(-80, 60)
		flower(x, rng:NextNumber(-162, -158))
	end
	for _ = 1, 8 do
		rock(rng:NextNumber(-80, 60), rng:NextNumber(-210, -165), rng:NextNumber(0.6, 1.4))
	end
	for _ = 1, 6 do
		mushroom(rng:NextNumber(-80, 50), rng:NextNumber(-210, -170), rng:NextNumber(0.6, 1))
	end
end

-------------------------------------------------------------------------------
-- Treasure chests
-------------------------------------------------------------------------------

local function chest(id: string, position: Vector3, yaw: number)
	local cf = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	local model = Instance.new("Model")
	model.Name = "TreasureChest_" .. id
	model.Parent = mapFolder
	local base = part({ Name = "ChestBase", Size = Vector3.new(3.2, 1.8, 2.2), CFrame = cf * CFrame.new(0, 0.9, 0), Color = Color3.fromRGB(140, 90, 50), Material = Enum.Material.WoodPlanks, Parent = model })
	decor(part({ Name = "ChestLid", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.2, 2.2, 2.2), CFrame = cf * CFrame.new(0, 1.8, 0), Color = Color3.fromRGB(150, 100, 55), Material = Enum.Material.WoodPlanks, Parent = model }))
	for _, x in ipairs({ -1.2, 1.2 }) do
		decor(part({ Name = "ChestBand", Size = Vector3.new(0.3, 2.9, 2.3), CFrame = cf * CFrame.new(x, 1.45, 0), Color = Color3.fromRGB(230, 190, 60), Material = Enum.Material.Metal, Parent = model }))
	end
	decor(part({ Name = "ChestLock", Size = Vector3.new(0.6, 0.7, 0.2), CFrame = cf * CFrame.new(0, 1.6, -1.15), Color = Color3.fromRGB(240, 200, 70), Material = Enum.Material.Metal, Parent = model }))
	base:SetAttribute("ChestId", id)
	CollectionService:AddTag(base, "TreasureChest")
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, 1.5, 0)
	attachment.Parent = base
	particles(attachment, {
		Rate = 1.5,
		Lifetime = NumberRange.new(1, 1.5),
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(40, 40),
		Size = NumberSequence.new(0.35, 0),
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 90)),
	})
end

local function buildChests()
	-- Under the ruined arch in Whispering Woods
	chest("WoodsArch", Vector3.new(-150, groundY(-150, 40), 40), math.rad(20))
	-- Far west end of the cliff top
	chest("CliffTop", Vector3.new(-78, groundY(-78, -200), -200), math.rad(-30))
	-- On the islet that sits furthest round to the south-west
	local best, bestPos = math.huge, nil
	for i = 1, 5 do
		local angle = (i / 5) * math.pi * 2 + 0.4
		local x, z = math.cos(angle) * 335, math.sin(angle) * 335
		local gy = groundY(x + 4, z + 4)
		local score = -z + x -- prefer south-west
		if gy > 0 and score < best then
			best, bestPos = score, Vector3.new(x + 4, gy, z + 4)
		end
	end
	if bestPos then
		chest("Islet", bestPos, 0)
	end
end

-------------------------------------------------------------------------------
-- Entry point
-------------------------------------------------------------------------------

function CoveDetails.Build(folder: Instance)
	mapFolder = folder
	buildPlaza()
	buildBeach()
	buildMeadowDetails()
	buildWoods()
	buildCliffDetails()
	buildChests()
end

return CoveDetails
