local Players = game:GetService("Players")
local player = Players.LocalPlayer

local enabled = false -- awal OFF

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "ToggleGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 180, 0, 50)
frame.Position = UDim2.new(0, 10, 0.5, -25)
frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
frame.BorderSizePixel = 0
frame.Parent = gui

local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 30, 0, 30)
button.Position = UDim2.new(0, 10, 0, 10)
button.BorderSizePixel = 0
button.AutoButtonColor = false
button.TextColor3 = Color3.new(1, 1, 1)
button.Parent = frame

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, -50, 1, 0)
label.Position = UDim2.new(0, 45, 0, 0)
label.BackgroundTransparency = 1
label.TextColor3 = Color3.new(1, 1, 1)
label.Font = Enum.Font.SourceSansBold
label.TextSize = 18
label.Parent = frame

local function updateState()
	local doubleStamina = player:FindFirstChild("DoubleStamina")
	local NightVision = player:FindFirstChild("NightVision")

	if doubleStamina then
		if doubleStamina:IsA("BoolValue") then
			doubleStamina.Value = enabled
		elseif doubleStamina:IsA("Script") or doubleStamina:IsA("LocalScript") then
			doubleStamina.Disabled = not enabled
		end
	end

	if NightVision then
		if NightVision:IsA("Script") or NightVision:IsA("LocalScript") then
			NightVision.Disabled = not enabled
		elseif NightVision:IsA("BoolValue") then
			NightVision.Value = enabled
		end
	end

	if enabled then
		button.Text = "☑"
		button.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
		label.Text = "Enabled"
	else
		button.Text = "☐"
		button.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
		label.Text = "Disabled"
	end
end

button.MouseButton1Click:Connect(function()
	enabled = not enabled
	updateState()
end)

updateState()
