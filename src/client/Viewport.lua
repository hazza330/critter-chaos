--[[
	Viewport
	Shows a creature model inside a GUI frame (inventory cards, collection book,
	discovery reveal). Models are cloned from a per-species template so each
	thumbnail costs one clone rather than a full rebuild.
]]

local RunService = game:GetService("RunService")

local CreatureModels = require(game:GetService("ReplicatedStorage").Shared.CreatureModels)

local Viewport = {}

local templates: { [number]: Model } = {}

local function getModel(creatureId: number): Model
	local template = templates[creatureId]
	if not template then
		template = CreatureModels.Build(creatureId)
		templates[creatureId] = template
	end
	return template:Clone()
end

export type Options = {
	silhouette: boolean?,
	spin: boolean?,
	zIndex: number?,
}

-- Fills `container` with a ViewportFrame showing the creature, three-quarter view.
function Viewport.Show(container: GuiObject, creatureId: number, options: Options?): ViewportFrame
	local opts = options or {}
	local frame = Instance.new("ViewportFrame")
	frame.Name = "CreatureView"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Ambient = Color3.fromRGB(170, 170, 185)
	frame.LightColor = Color3.fromRGB(255, 250, 240)
	frame.LightDirection = Vector3.new(-1, -1.5, -1)
	frame.ZIndex = opts.zIndex or container.ZIndex
	frame.Parent = container

	local model = getModel(creatureId)
	if opts.silhouette then
		CreatureModels.Silhouette(model)
	end
	model:PivotTo(CFrame.new())
	model.Parent = frame

	local boxCFrame, boxSize = model:GetBoundingBox()
	local centre = boxCFrame.Position
	local radius = boxSize.Magnitude / 2

	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.Parent = frame
	frame.CurrentCamera = camera

	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 0.95
	local function place(angle: number)
		local offset = CFrame.Angles(0, angle, 0) * Vector3.new(0, radius * 0.35, -distance)
		camera.CFrame = CFrame.lookAt(centre + offset, centre)
	end
	place(math.rad(-30))

	if opts.spin then
		local start = os.clock()
		local connection
		connection = RunService.RenderStepped:Connect(function()
			if not frame.Parent then
				connection:Disconnect()
				return
			end
			place(math.rad(-30) + (os.clock() - start) * 1.2)
		end)
	end

	return frame
end

return Viewport
