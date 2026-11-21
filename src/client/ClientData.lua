--[[
	ClientData
	Read-only local copy of the player's data, kept up to date by DataSync.
	The client never writes to this; it only displays it.
]]

local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)

local ClientData = {}

local current: { [string]: any }? = nil
local changed = Instance.new("BindableEvent")

ClientData.Changed = changed.Event

function ClientData.Get(): { [string]: any }?
	return current
end

function ClientData.Start()
	Remotes.Event("DataSync").OnClientEvent:Connect(function(data)
		current = data
		changed:Fire(data)
	end)

	-- In case the first sync arrived before we connected.
	task.spawn(function()
		local data = Remotes.Function("GetData"):InvokeServer()
		if data and not current then
			current = data
			changed:Fire(data)
		end
	end)
end

return ClientData
