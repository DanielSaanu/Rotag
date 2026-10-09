-- The client entry point. Will own input, movement feel, the side-on camera and the HUD.
-- Nothing is built yet; this stub proves the Rojo tree (default.project.json) syncs and sprites resolve.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sprites = require(Shared:WaitForChild("Sprites"))

local gui = Instance.new("ScreenGui")
gui.Name = "RotagSmoke"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

-- One sprite on screen at 4x. If it is blank, the sheet is not uploaded yet (docs/ROBLOX_SETUP.md §5).
local img = Sprites.New("runner_idle", gui)
img.Size = UDim2.fromOffset(64, 64)
img.Position = UDim2.fromOffset(16, 16)
print("[Rotag] client up; runner_idle on screen")
