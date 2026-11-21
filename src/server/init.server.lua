--[[
	Server entry point.
	Builds the world first, then starts services in dependency order.
	DataService must start before anything that reads player data.
]]

local Services = script.Services

-- Remotes must exist before any client asks for them.
require(game:GetService("ReplicatedStorage").Shared.Remotes)

require(script.World.CritterCove).Build()

local DataService = require(Services.DataService)
local ProgressService = require(Services.ProgressService)
local DiscoveryService = require(Services.DiscoveryService)
local InventoryService = require(Services.InventoryService)
local IncomeService = require(Services.IncomeService)

ProgressService.Start() -- registers OnLoaded before players load
DiscoveryService.Start()
InventoryService.Start()
IncomeService.Start()
DataService.Start()

print("[Critter Chaos] Server started")
