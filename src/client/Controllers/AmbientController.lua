--[[
	AmbientController
	Small client-side touches that make the world feel alive without costing
	the server anything.

	  * Scrolls every Texture tagged "ScrollingTexture" (the waterfall) downwards.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local SCROLL_SPEED = 12 -- studs per second

local AmbientController = {}

function AmbientController.Start()
	RunService.RenderStepped:Connect(function(dt)
		for _, texture in ipairs(CollectionService:GetTagged("ScrollingTexture")) do
			if texture:IsA("Texture") then
				texture.OffsetStudsV = (texture.OffsetStudsV - SCROLL_SPEED * dt) % texture.StudsPerTileV
			end
		end
	end)
end

return AmbientController
