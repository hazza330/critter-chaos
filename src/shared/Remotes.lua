--[[
	Remotes
	Single place that creates (server) or waits for (client) every RemoteEvent and
	RemoteFunction. Add new remotes to the NAMES tables only.

	Direction notes
	  DataSync      server -> client  snapshot of the player's own public data
	  Discovered    server -> client  a creature was just discovered (plays reveal)
	  Notify        server -> client  toast message {text, kind}
	  GetData       client -> server  RemoteFunction, returns the same snapshot as DataSync
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENT_NAMES = { "DataSync", "Discovered", "Notify" }
local FUNCTION_NAMES = { "GetData" }

local Remotes = {}

local folder: Folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(EVENT_NAMES) do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in ipairs(FUNCTION_NAMES) do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.Event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.Function(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
