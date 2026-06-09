local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "ToggleGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 180, 0, 50)
frame.Position = UDim2.new(0, 10, 0.5, -25) -- kiri tengah
frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
frame.Parent = gui

local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 30, 0, 30)
button.Position = UDim2.new(0, 10, 0, 10)
button.Text = "☑"
button.Parent = frame

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, -50, 1, 0)
label.Position = UDim2.new(0, 45, 0, 0)
label.BackgroundTransparency = 1
label.TextColor3 = Color3.new(1, 1, 1)
label.Text = "Enabled"
label.Parent = frame

local enabled = true

local function updateState()
	local doubleStamina = player:FindFirstChild("DoubleStamina")
	local headCam = player:FindFirstChild("HeadCam")

	if doubleStamina then
		if doubleStamina:IsA("BoolValue") then
			doubleStamina.Value = enabled
		elseif doubleStamina:IsA("Script") or doubleStamina:IsA("LocalScript") then
			doubleStamina.Disabled = not enabled
		end
	end

	if headCam then
		if headCam:IsA("Script") or headCam:IsA("LocalScript") then
			headCam.Disabled = not enabled
		elseif headCam:IsA("BoolValue") then
			headCam.Value = enabled
		end
	end

	button.Text = enabled and "☑" or "☐"
	label.Text = enabled and "Enabled" or "Disabled"
end

button.MouseButton1Click:Connect(function()
	enabled = not enabled
	updateState()
end)

updateState()
