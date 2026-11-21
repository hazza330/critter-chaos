--[[
	IncomeService
	Pays every player for their equipped creatures once per
	Economy.IncomeInterval seconds. Runs as one server loop, so a payout can
	never be counted twice, and the amount is worked out from saved data only.

	Offline earnings arrive with the rest of the economy in Stage 3.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local CreatureStats = require(Shared.CreatureStats)
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)
local ProgressService = require(script.Parent.ProgressService)

local IncomeService = {}

function IncomeService.TotalIncome(data): number
	local total = 0
	for _, uid in ipairs(data.equipped) do
		local entry = data.creatures[uid]
		if entry then
			total += CreatureStats.Income(entry)
		end
	end
	return total
end

local function payout()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.Get(player)
		if data then
			local amount = IncomeService.TotalIncome(data)
			if amount > 0 and ProgressService.AddCoins(player, amount) then
				Remotes.Event("Income"):FireClient(player, amount)
				DataService.Sync(player)
			end
		end
	end
end

function IncomeService.Start()
	task.spawn(function()
		while true do
			task.wait(Economy.IncomeInterval)
			payout()
		end
	end)
end

return IncomeService
