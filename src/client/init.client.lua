--[[
	Client entry point.
	Creates the single ScreenGui every controller draws into, scales it for the
	device's screen size, and starts each controller.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local UI = require(script.UI)
local ClientData = require(script.ClientData)
local Controllers = script.Controllers

local player = Players.LocalPlayer

local root = UI.new("ScreenGui", {
	Name = "CritterChaosHUD",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- One UIScale keeps every panel readable from phones to large monitors.
-- Designed at 1280x720; shrinks on small screens, never grows past 1.25.
local uiScale = UI.new("UIScale", { Parent = root })
local function rescale()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local size = camera.ViewportSize
	uiScale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 720), 0.55, 1.25)
end
rescale()
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(rescale)
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end

ClientData.Start()

local HudController = require(Controllers.HudController)
HudController.Start(root)
require(Controllers.NotifyController).Start(root)
require(Controllers.RevealController).Start(root)
require(Controllers.CollectionController).Start(root, HudController)
