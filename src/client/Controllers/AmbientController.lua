--[[
	AmbientController
	Client-side movement that makes the world feel alive without costing the
	server anything. Everything here is purely visual.

	  * "ScrollingTexture" textures (the waterfall) scroll downwards
	  * "Spinner" parts (windmill hub) rotate about their own X axis
	  * "Bobber" parts (boats, buoys) bob and rock on the water
	  * Seagulls circle the island
	  * Butterflies flutter around the Creature Meadow

	Anything further than ANIMATE_DISTANCE from the camera isn't updated.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SCROLL_SPEED = 12 -- studs per second
local ANIMATE_DISTANCE = 350

local AmbientController = {}

local originals: { [BasePart]: CFrame } = {}
local folder: Folder

type Critter = {
	body: BasePart,
	wingL: BasePart,
	wingR: BasePart,
	centre: Vector3,
	radius: number,
	height: number,
	speed: number,
	phase: number,
	flapSpeed: number,
	wingSpan: number,
	wander: boolean,
}

local critters: { Critter } = {}

local function original(p: BasePart): CFrame
	local cf = originals[p]
	if not cf then
		cf = p.CFrame
		originals[p] = cf
	end
	return cf
end

local function newPart(size: Vector3, colour: Color3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.Color = colour
	p.Parent = folder
	return p
end

local function spawnCritter(kind: string, centre: Vector3, radius: number, height: number)
	local critter: Critter
	if kind == "gull" then
		critter = {
			body = newPart(Vector3.new(0.8, 0.7, 2.2), Color3.fromRGB(250, 250, 250)),
			wingL = newPart(Vector3.new(3, 0.12, 1), Color3.fromRGB(230, 232, 238)),
			wingR = newPart(Vector3.new(3, 0.12, 1), Color3.fromRGB(230, 232, 238)),
			centre = centre,
			radius = radius,
			height = height,
			speed = math.random(6, 10) / 100,
			phase = math.random() * math.pi * 2,
			flapSpeed = 5,
			wingSpan = 1.5,
			wander = false,
		}
	else
		local colours = {
			Color3.fromRGB(255, 170, 60),
			Color3.fromRGB(120, 180, 255),
			Color3.fromRGB(255, 120, 200),
			Color3.fromRGB(255, 240, 120),
		}
		local colour = colours[math.random(1, #colours)]
		critter = {
			body = newPart(Vector3.new(0.12, 0.12, 0.5), Color3.fromRGB(40, 30, 30)),
			wingL = newPart(Vector3.new(0.6, 0.05, 0.6), colour),
			wingR = newPart(Vector3.new(0.6, 0.05, 0.6), colour),
			centre = centre,
			radius = radius,
			height = height,
			speed = math.random(20, 40) / 100,
			phase = math.random() * math.pi * 2,
			flapSpeed = 18,
			wingSpan = 0.3,
			wander = true,
		}
	end
	table.insert(critters, critter)
end

local function updateCritter(c: Critter, t: number, cameraPos: Vector3)
	if (c.centre - cameraPos).Magnitude > ANIMATE_DISTANCE + c.radius then
		return
	end
	local a = t * c.speed + c.phase
	local position, ahead
	if c.wander then
		-- Lissajous-style loops: looks random but is cheap and smooth.
		local function at(time: number)
			local b = time * c.speed + c.phase
			return c.centre
				+ Vector3.new(
					math.sin(b * 1.3) * c.radius,
					c.height + math.sin(b * 3.1) * 1.2,
					math.cos(b * 0.9) * c.radius
				)
		end
		position = at(t)
		ahead = at(t + 0.1)
	else
		position = c.centre + Vector3.new(math.cos(a) * c.radius, c.height + math.sin(a * 2) * 4, math.sin(a) * c.radius)
		local b = a + 0.05
		ahead = c.centre + Vector3.new(math.cos(b) * c.radius, c.height + math.sin(b * 2) * 4, math.sin(b) * c.radius)
	end
	local cf = CFrame.lookAt(position, ahead)
	if not c.wander then
		cf = cf * CFrame.Angles(0, 0, math.rad(-15)) -- bank into the turn
	end
	local flap = math.sin(t * c.flapSpeed + c.phase) * 0.7
	c.body.CFrame = cf
	c.wingL.CFrame = cf * CFrame.Angles(0, 0, flap) * CFrame.new(-c.wingSpan, 0, 0)
	c.wingR.CFrame = cf * CFrame.Angles(0, 0, -flap) * CFrame.new(c.wingSpan, 0, 0)
end

function AmbientController.Start()
	folder = Instance.new("Folder")
	folder.Name = "AmbientLife"
	folder.Parent = Workspace

	for _ = 1, 7 do
		spawnCritter("gull", Vector3.new(math.random(-60, 60), 0, math.random(-60, 60)), math.random(150, 260), math.random(45, 75))
	end
	for _ = 1, 16 do
		spawnCritter("butterfly", Vector3.new(math.random(80, 180), 4, math.random(-70, 90)), math.random(6, 16), math.random(2, 5))
	end
	for _ = 1, 6 do
		spawnCritter("butterfly", Vector3.new(math.random(-20, 20), 4, math.random(-20, 30)), math.random(8, 14), math.random(3, 5))
	end

	RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local cameraPos = camera.CFrame.Position
		local t = os.clock()

		for _, texture in ipairs(CollectionService:GetTagged("ScrollingTexture")) do
			if texture:IsA("Texture") then
				texture.OffsetStudsV = (texture.OffsetStudsV - SCROLL_SPEED * dt) % texture.StudsPerTileV
			end
		end

		for _, hub in ipairs(CollectionService:GetTagged("Spinner")) do
			if hub:IsA("BasePart") and (hub.Position - cameraPos).Magnitude < ANIMATE_DISTANCE then
				local speed = tonumber(hub:GetAttribute("Speed")) or 1
				hub.CFrame = original(hub) * CFrame.Angles(t * speed, 0, 0)
			end
		end

		for _, base in ipairs(CollectionService:GetTagged("Bobber")) do
			if base:IsA("BasePart") and (base.Position - cameraPos).Magnitude < ANIMATE_DISTANCE then
				local seed = base.Position.X * 0.13 + base.Position.Z * 0.07
				local bob = math.sin(t * 1.4 + seed) * 0.35
				local roll = math.sin(t * 1.1 + seed) * 0.06
				local pitch = math.sin(t * 0.8 + seed * 2) * 0.04
				-- Bob in world space so rotated parts (like buoys) still move straight up.
				base.CFrame = CFrame.new(0, bob, 0) * original(base) * CFrame.Angles(pitch, 0, roll)
			end
		end

		for _, critter in ipairs(critters) do
			updateCritter(critter, t, cameraPos)
		end
	end)
end

return AmbientController
