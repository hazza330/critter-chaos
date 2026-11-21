--[[
	PetController
	Draws and animates every player's equipped creatures on this client.

	The server publishes each player's equipped creature ids as the
	"EquippedPets" attribute. This controller builds local models from that
	and moves them every frame. Nothing here affects gameplay; it is visual.

	Behaviour
	  * Pets fan out in an arc behind their owner, so they never overlap.
	  * Smooth follow with exponential easing; teleport if they fall far behind.
	  * Ground found with a raycast so pets walk over hills instead of floating.
	  * Movement styles: walk (waddle), hop (bounces), float (bobs), fly (high, flapping).
	  * Idle: walkers look around, hoppers do the odd hop, floaters drift.
	  * Pets more than CULL_DISTANCE studs from the camera are hidden and skipped.
	  * Pets never collide, so they can't block anyone.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CreatureModels = require(game:GetService("ReplicatedStorage").Shared.CreatureModels)

local CULL_DISTANCE = 220
local FOLLOW_DISTANCE = 5
local ARC_SPACING = 0.75 -- radians between pets
local TELEPORT_DISTANCE = 60

local PetController = {}

type Flap = { weld: Weld, base: CFrame, side: number }
type Pet = {
	model: Model,
	root: BasePart,
	halfHeight: number,
	move: string,
	phase: number,
	position: Vector3,
	baseY: number,
	look: Vector3,
	flaps: { Flap },
}

local folder: Folder
local petsByPlayer: { [Player]: { Pet } } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false

local function clearPets(player: Player)
	local list = petsByPlayer[player]
	if list then
		for _, pet in ipairs(list) do
			pet.model:Destroy()
		end
	end
	petsByPlayer[player] = nil
end

local function decodeIds(player: Player): { number }
	local raw = player:GetAttribute("EquippedPets")
	if type(raw) ~= "string" then
		return {}
	end
	local ok, ids = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(ids) ~= "table" then
		return {}
	end
	return ids
end

local function rebuild(player: Player)
	clearPets(player)
	local ids = decodeIds(player)
	if #ids == 0 then
		return
	end

	local character = player.Character
	local ownerRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local start = if ownerRoot then ownerRoot.Position else Vector3.zero

	local list = {}
	for i, id in ipairs(ids) do
		local ok, model = pcall(CreatureModels.Build, id)
		if ok then
			local root = model.PrimaryPart :: BasePart
			local flaps = {}
			for _, part in ipairs(model:GetChildren()) do
				if part.Name == "Wing" then
					local weld = part:FindFirstChild("Joint") :: Weld
					table.insert(flaps, { weld = weld, base = weld.C0, side = part:GetAttribute("Side") or 1 })
				end
			end
			model.Name = player.Name .. "_Pet" .. i
			model:PivotTo(CFrame.new(start))
			model.Parent = folder
			table.insert(list, {
				model = model,
				root = root,
				halfHeight = model:GetAttribute("HalfHeight") or 1,
				move = model:GetAttribute("Move") or "walk",
				phase = (i * 1.7) % (math.pi * 2),
				position = start,
				baseY = start.Y,
				look = Vector3.new(0, 0, -1),
				flaps = flaps,
			})
		else
			warn("[PetController] Could not build creature " .. tostring(id))
		end
	end
	petsByPlayer[player] = list
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("EquippedPets"):Connect(function()
		rebuild(player)
	end)
	rebuild(player)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function update(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPos = camera.CFrame.Position
	local t = os.clock()
	local follow = 1 - math.exp(-9 * dt)
	local vertical = 1 - math.exp(-18 * dt)

	for player, list in pairs(petsByPlayer) do
		local character = player.Character
		local ownerRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local visible = ownerRoot ~= nil
			and humanoid ~= nil
			and (ownerRoot.Position - cameraPos).Magnitude < CULL_DISTANCE

		for _, pet in ipairs(list) do
			local shouldParent = if visible then folder else nil
			if pet.model.Parent ~= shouldParent then
				pet.model.Parent = shouldParent
			end
		end

		if visible and ownerRoot and humanoid then
			rayParams.FilterDescendantsInstances = { folder, character :: Model }
			local ownerCFrame = ownerRoot.CFrame
			local feetY = ownerRoot.Position.Y - (humanoid.HipHeight + ownerRoot.Size.Y / 2)
			local moving = flat(ownerRoot.AssemblyLinearVelocity).Magnitude > 1.5
			local count = #list

			for i, pet in ipairs(list) do
				local angle = (i - (count + 1) / 2) * ARC_SPACING
				local distance = FOLLOW_DISTANCE + pet.halfHeight
				local target = (ownerCFrame * CFrame.new(math.sin(angle) * distance, 0, math.cos(angle) * distance)).Position

				if (flat(target) - flat(pet.position)).Magnitude > TELEPORT_DISTANCE then
					pet.position = target
				end

				-- Ground height under the target spot.
				local hit = Workspace:Raycast(Vector3.new(target.X, feetY + 8, target.Z), Vector3.new(0, -24, 0), rayParams)
				local groundY = if hit then hit.Position.Y else feetY

				local wantY
				if pet.move == "fly" then
					wantY = math.max(groundY, feetY) + pet.halfHeight + 3
				elseif pet.move == "float" then
					wantY = groundY + pet.halfHeight + 1.2
				else
					wantY = groundY + pet.halfHeight
				end

				local newXZ = flat(pet.position):Lerp(flat(target), follow)
				pet.baseY += (wantY - pet.baseY) * vertical
				pet.position = Vector3.new(newXZ.X, pet.baseY, newXZ.Z)

				-- Animation offsets
				local phase = t + pet.phase
				local bob, roll, pitch = 0, 0, 0
				if pet.move == "hop" then
					if moving then
						bob = math.abs(math.sin(phase * 9)) * 1.0
					else
						bob = math.max(0, math.sin(phase * 2.5)) ^ 8 * 0.9
					end
				elseif pet.move == "float" then
					bob = math.sin(phase * 2.2) * 0.35
					roll = math.sin(phase * 1.3) * 0.08
				elseif pet.move == "fly" then
					bob = math.sin(phase * 3) * 0.45
					pitch = if moving then -0.15 else 0
				else -- walk
					if moving then
						bob = math.abs(math.sin(phase * 12)) * 0.15
						roll = math.sin(phase * 12) * 0.12
					end
				end

				-- Facing: travel direction while moving, otherwise copy the owner
				-- with a slow idle glance.
				local travel = flat(target - pet.position)
				local desired
				if travel.Magnitude > 0.4 then
					desired = travel.Unit
				else
					local glance = CFrame.Angles(0, math.sin(phase * 0.7) * 0.6, 0)
					desired = (glance * flat(ownerCFrame.LookVector)).Unit
				end
				pet.look = pet.look:Lerp(desired, follow)
				if pet.look.Magnitude < 0.01 then
					pet.look = desired
				end

				local position = pet.position + Vector3.new(0, bob, 0)
				pet.root.CFrame = CFrame.lookAt(position, position + pet.look) * CFrame.Angles(pitch, 0, roll)

				-- Wings and fins
				if #pet.flaps > 0 then
					local speed = if pet.move == "fly" then 16 else 6
					local swing = math.sin(phase * speed) * (if pet.move == "fly" then 0.6 else 0.3)
					for _, flap in ipairs(pet.flaps) do
						flap.weld.C0 = flap.base * CFrame.Angles(0, 0, flap.side * swing)
					end
				end
			end
		end
	end
end

function PetController.Start()
	folder = Instance.new("Folder")
	folder.Name = "ClientPets"
	folder.Parent = Workspace

	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clearPets)

	RunService.RenderStepped:Connect(update)
end

return PetController
