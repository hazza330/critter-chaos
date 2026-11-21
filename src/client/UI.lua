--[[
	UI
	Small helpers so every panel shares one look: rounded corners, soft strokes,
	the same fonts, and buttons that react to hover and press.
]]

local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local UI = {}

UI.Colors = {
	Panel = Color3.fromRGB(32, 36, 58),
	PanelLight = Color3.fromRGB(48, 54, 84),
	Accent = Color3.fromRGB(255, 170, 60),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(170, 176, 200),
	Coin = Color3.fromRGB(255, 205, 60),
	Gem = Color3.fromRGB(120, 220, 255),
	Good = Color3.fromRGB(110, 220, 120),
	Bad = Color3.fromRGB(255, 100, 100),
}

UI.Font = Enum.Font.FredokaOne
UI.BodyFont = Enum.Font.GothamMedium

-- Create an instance with properties and children in one call.
function UI.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			(inst :: any)[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	inst.Parent = parent
	return inst
end

function UI.corner(radius: number?): UICorner
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function UI.stroke(color: Color3?, thickness: number?): UIStroke
	return UI.new("UIStroke", {
		Color = color or Color3.fromRGB(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = 0.6,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.padding(px: number): UIPadding
	local d = UDim.new(0, px)
	return UI.new("UIPadding", { PaddingLeft = d, PaddingRight = d, PaddingTop = d, PaddingBottom = d })
end

local clickSound = UI.new("Sound", {
	SoundId = "rbxasset://sounds/electronicpingshort.wav",
	Volume = 0.25,
	PlaybackSpeed = 1.6,
	Parent = SoundService,
})

function UI.playClick()
	SoundService:PlayLocalSound(clickSound)
end

-- Makes a button grow on hover and squash on press. Works for touch too.
function UI.animateButton(button: GuiButton)
	local scale = button:FindFirstChildOfClass("UIScale") or UI.new("UIScale", { Parent = button })
	local info = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local function to(value: number)
		TweenService:Create(scale, info, { Scale = value }):Play()
	end
	button.MouseEnter:Connect(function()
		to(1.06)
	end)
	button.MouseLeave:Connect(function()
		to(1)
	end)
	button.MouseButton1Down:Connect(function()
		to(0.94)
	end)
	button.MouseButton1Up:Connect(function()
		to(1.03)
	end)
	button.Activated:Connect(UI.playClick)
end

function UI.formatNumber(n: number): string
	if n >= 1e9 then
		return ("%.1fB"):format(n / 1e9)
	elseif n >= 1e6 then
		return ("%.1fM"):format(n / 1e6)
	elseif n >= 1e4 then
		return ("%.1fK"):format(n / 1e3)
	end
	-- Add thousands separators for smaller numbers.
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

return UI
