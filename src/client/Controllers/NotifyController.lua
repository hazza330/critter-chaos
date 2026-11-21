--[[
	NotifyController
	Toast messages at the top centre of the screen. Server sends them through
	the Notify remote; other client controllers can call NotifyController.Show.
	At most MAX_VISIBLE are shown at once; older ones are removed.
]]

local TweenService = game:GetService("TweenService")

local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)
local UI = require(script.Parent.Parent.UI)

local MAX_VISIBLE = 4
local DURATION = 3.5

local KIND_COLOURS = {
	info = Color3.fromRGB(48, 54, 84),
	error = Color3.fromRGB(170, 50, 60),
	success = Color3.fromRGB(50, 140, 80),
	levelup = Color3.fromRGB(220, 130, 30),
	rare = Color3.fromRGB(140, 60, 180),
}

local NotifyController = {}

local container: Frame

function NotifyController.Show(text: string, kind: string?)
	local toasts = {}
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts >= MAX_VISIBLE then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end

	local toast = UI.new("Frame", {
		LayoutOrder = math.floor(os.clock() * 1000),
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = KIND_COLOURS[kind or "info"] or KIND_COLOURS.info,
		BackgroundTransparency = 0.05,
		Parent = container,
	}, { UI.corner(12), UI.stroke() })
	UI.new("UIPadding", {
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
		Parent = toast,
	})
	local label = UI.new("TextLabel", {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = text,
		Font = UI.Font,
		TextSize = 20,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = toast,
	})

	local scale = UI.new("UIScale", { Scale = 0.6, Parent = toast })
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	task.delay(DURATION, function()
		if toast.Parent then
			local fade = TweenInfo.new(0.3)
			TweenService:Create(toast, fade, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
			task.wait(0.3)
			toast:Destroy()
		end
	end)
end

function NotifyController.Start(root: ScreenGui)
	container = UI.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(600, 200),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		UI.new("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	Remotes.Event("Notify").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.text) == "string" then
			NotifyController.Show(payload.text, payload.kind)
		end
	end)
end

return NotifyController
