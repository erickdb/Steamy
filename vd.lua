-- ═══════════════════════════════════════════════════════════════════════════
-- STEAMY ROBLOX - VD EDITION
-- Complete ESP & Script Executor
-- ═══════════════════════════════════════════════════════════════════════════

-- Load WindUI
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

--// Services
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ═══════════════════════════════════════════════════════════════════════════
-- GLOBAL STATE
-- ═══════════════════════════════════════════════════════════════════════════

--// Generator ESP State
local generatorESPHighlightEnabled = false
local generatorESPHighlights = {}

--// Pumpkin ESP State
local pumpkinESPHighlightEnabled = false
local pumpkinESPHighlights = {}

--// Lever ESP State
local leverESPEnabled = false
local leverESPHighlights = {}

--// Player ESP State
local survivorESPEnabled = false
local killerESPEnabled = false
local survivorItemESPEnabled = false
local playerESPData = {}

-- // Crosshair state
local crosshairEnabled = false
local crosshairUI = nil

--// Long Range Heal State
local longRangeHealEnabled = false
local healTarget = nil
local healTargetESP = nil
local healKeybind = Enum.KeyCode.F

--// Speed Boost State
local speedBoostEnabled = false
local currentSpeedBoost = 16

--// Auto Perfect Generator State
local autoPerfectEnabled = false
local autoPerfectConnection = nil

--// Debug Overlay State
local debugOverlayEnabled = false
local debugOverlayUI = nil
local lastLineRotation = 0
local lastGoalRotation = 0
local lastCircleRotation = 0
local lastShadowRotation = 0
local lastSpaceRotation = 0
local lastDifference = 0
local lastStatus = "Waiting..."
local lastStatusColor = Color3.fromRGB(150, 150, 150)

--// UI References
local generatorHighlightToggle
local pumpkinHighlightToggle
local leverESPToggle
local survivorESPToggle
local killerESPToggle
local survivorItemESPToggle

-- ═══════════════════════════════════════════════════════════════════════════
-- GENERATOR ESP FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

local function getGenerators()
    local generators = {}
    local map = Workspace:FindFirstChild("Map")
    
    if map then
        -- Search recursively through all descendants
        for _, descendant in ipairs(map:GetDescendants()) do
            if descendant:IsA("Model") and descendant.Name == "Generator" then
                table.insert(generators, descendant)
            end
        end
    end
    
    return generators
end

local function createGeneratorESPHighlight(generator)
    if generatorESPHighlights[generator] then return end
    
    -- Create Highlight
    local highlight = Instance.new("Highlight")
    highlight.Name = "Generator_ESP_Highlight"
    highlight.FillColor = Color3.fromRGB(255, 0, 0) -- Start with red
    highlight.OutlineColor = Color3.fromRGB(255, 165, 0)
    highlight.FillTransparency = 0.7
    highlight.OutlineTransparency = 1
    highlight.Parent = generator
    
    -- Create Billboard for Progress Display
    local primaryPart = generator.PrimaryPart or generator:FindFirstChildWhichIsA("BasePart")
    local billboardGui = nil
    
    if primaryPart then
        billboardGui = Instance.new("BillboardGui")
        billboardGui.Name = "GeneratorProgressESP"
        billboardGui.Adornee = primaryPart
        billboardGui.Size = UDim2.new(0, 120, 0, 50)
        billboardGui.StudsOffset = Vector3.new(0, 4, 0)
        billboardGui.AlwaysOnTop = false
        billboardGui.Parent = primaryPart
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = "Generator\n0%"
        textLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        textLabel.TextSize = 16
        textLabel.Font = Enum.Font.Gotham
        textLabel.TextStrokeTransparency = 0.3
        textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        textLabel.Parent = billboardGui
    end
    
    generatorESPHighlights[generator] = {
        highlight = highlight,
        billboard = billboardGui,
        textLabel = billboardGui and billboardGui:FindFirstChildOfClass("TextLabel") or nil
    }
    
    -- Update progress loop
    task.spawn(function()
        while generatorESPHighlights[generator] and generatorESPHighlightEnabled do
            local progress = generator:GetAttribute("RepairProgress") or 0
            progress = math.clamp(progress, 0, 100)
            
            -- Calculate color gradient from red to green
            local red = math.floor(255 * (1 - progress / 100))
            local green = math.floor(255 * (progress / 100))
            local color = Color3.fromRGB(red, green, 0)
            
            -- Update highlight color
            if generatorESPHighlights[generator] and generatorESPHighlights[generator].highlight then
                generatorESPHighlights[generator].highlight.FillColor = color
            end
            
            -- Update text label
            if generatorESPHighlights[generator] and generatorESPHighlights[generator].textLabel then
                generatorESPHighlights[generator].textLabel.Text = string.format("Generator\n%.1f%%", progress)
                generatorESPHighlights[generator].textLabel.TextColor3 = color
            end
            
            task.wait(0.1) -- Update every 0.1 seconds for smooth color transition
        end
    end)
end

local function removeGeneratorESPHighlight(generator)
    if generatorESPHighlights[generator] then
        if generatorESPHighlights[generator].highlight then
            generatorESPHighlights[generator].highlight:Destroy()
        end
        if generatorESPHighlights[generator].billboard then
            generatorESPHighlights[generator].billboard:Destroy()
        end
        generatorESPHighlights[generator] = nil
    end
end

local function enableGeneratorESPHighlight()
    local generators = getGenerators()
    for _, gen in ipairs(generators) do
        createGeneratorESPHighlight(gen)
    end
end

local function disableGeneratorESPHighlight()
    for generator, _ in pairs(generatorESPHighlights) do
        removeGeneratorESPHighlight(generator)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- PUMPKIN ESP FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

local function getPumpkins()
    local pumpkins = {}
    local map = Workspace:FindFirstChild("Map")
    
    if map then
        local pumpkinsFolder = map:FindFirstChild("Pumpkins")
        if pumpkinsFolder then
            for _, child in ipairs(pumpkinsFolder:GetChildren()) do
                if child:IsA("BasePart") or child:IsA("Model") then
                    table.insert(pumpkins, child)
                end
            end
        end
    end
    
    return pumpkins
end

local function createPumpkinESPHighlight(pumpkin)
    if pumpkinESPHighlights[pumpkin] then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "Pumpkin_ESP_Highlight"
    highlight.FillColor = Color3.fromRGB(255, 140, 0)
    highlight.OutlineColor = Color3.fromRGB(255, 69, 0)
    highlight.FillTransparency = 0.7
    highlight.OutlineTransparency = 1
    highlight.Parent = pumpkin
    
    pumpkinESPHighlights[pumpkin] = highlight
end

local function removePumpkinESPHighlight(pumpkin)
    if pumpkinESPHighlights[pumpkin] then
        pumpkinESPHighlights[pumpkin]:Destroy()
        pumpkinESPHighlights[pumpkin] = nil
    end
end

local function enablePumpkinESPHighlight()
    local pumpkins = getPumpkins()
    for _, pumpkin in ipairs(pumpkins) do
        createPumpkinESPHighlight(pumpkin)
    end
end

local function disablePumpkinESPHighlight()
    for pumpkin, _ in pairs(pumpkinESPHighlights) do
        removePumpkinESPHighlight(pumpkin)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- LEVER ESP FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

local function getLever()
    local map = Workspace:FindFirstChild("Map")
    if not map then return nil end
    
    -- Search recursively through all descendants to find ExitLever
    for _, descendant in ipairs(map:GetDescendants()) do
        if descendant.Name == "ExitLever" then
            local main = descendant:FindFirstChild("Main")
            if main then
                return main
            end
        end
    end
    
    return nil
end

local function createLeverESP(lever)
    if leverESPHighlights[lever] then return end
    
    -- Create Highlight
    local highlight = Instance.new("Highlight")
    highlight.Name = "Lever_ESP_Highlight"
    highlight.FillColor = Color3.fromRGB(255, 0, 0) -- Start with red
    highlight.OutlineColor = Color3.fromRGB(255, 165, 0)
    highlight.FillTransparency = 0.7
    highlight.OutlineTransparency = 1
    highlight.Parent = lever
    
    -- Create Billboard for Progress Display
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "LeverProgressESP"
    billboardGui.Adornee = lever
    billboardGui.Size = UDim2.new(0, 120, 0, 50)
    billboardGui.StudsOffset = Vector3.new(0, 4, 0)
    billboardGui.AlwaysOnTop = false
    billboardGui.Parent = lever
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = "Exit Lever\n0%"
    textLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
    textLabel.TextSize = 16
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextStrokeTransparency = 0.3
    textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    textLabel.Parent = billboardGui
    
    leverESPHighlights[lever] = {
        highlight = highlight,
        billboard = billboardGui,
        textLabel = textLabel
    }
    
    -- Update progress loop
    task.spawn(function()
        while leverESPHighlights[lever] and leverESPEnabled do
            local progress = lever:GetAttribute("ActivationProgress") or 0
            progress = math.clamp(progress, 0, 100)
            
            -- Calculate color gradient from red to green
            local red = math.floor(255 * (1 - progress / 100))
            local green = math.floor(255 * (progress / 100))
            local color = Color3.fromRGB(red, green, 0)
            
            -- Update highlight color
            if leverESPHighlights[lever] and leverESPHighlights[lever].highlight then
                leverESPHighlights[lever].highlight.FillColor = color
            end
            
            -- Update text label
            if leverESPHighlights[lever] and leverESPHighlights[lever].textLabel then
                leverESPHighlights[lever].textLabel.Text = string.format("Exit Lever\n%.1f%%", progress)
                leverESPHighlights[lever].textLabel.TextColor3 = color
            end
            
            task.wait(0.1) -- Update every 0.1 seconds for smooth color transition
        end
    end)
end

local function removeLeverESP(lever)
    if leverESPHighlights[lever] then
        if leverESPHighlights[lever].highlight then
            leverESPHighlights[lever].highlight:Destroy()
        end
        if leverESPHighlights[lever].billboard then
            leverESPHighlights[lever].billboard:Destroy()
        end
        leverESPHighlights[lever] = nil
    end
end

local function enableLeverESP()
    local lever = getLever()
    if lever then
        createLeverESP(lever)
    end
end

local function disableLeverESP()
    for lever, _ in pairs(leverESPHighlights) do
        removeLeverESP(lever)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- PLAYER ESP FUNCTIONS (SURVIVOR & KILLER)
-- ═══════════════════════════════════════════════════════════════════════════

local function isKiller(player)
    if not player then return false end
    return player.Team and player.Team.Name == "Killer"
end

local function isSurvivor(player)
    if not player then return false end
    return player.Team and player.Team.Name == "Survivors"
end

local function createPlayerESP(player, isKillerPlayer)
    if playerESPData[player] then
        removePlayerESP(player)
    end
    
    if not player.Character then return end
    
    local character = player.Character
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    -- Create Highlight
    local highlight = Instance.new("Highlight")
    highlight.Name = "Player_ESP_Highlight"
    if isKillerPlayer then
        highlight.FillColor = Color3.fromRGB(255, 0, 0) -- Red for Killer
    else
        highlight.FillColor = Color3.fromRGB(0, 255, 0) -- Green for Survivor
    end
    highlight.FillTransparency = 0.7
    highlight.OutlineTransparency = 1
    highlight.Parent = character
    
    -- Get killer type if player is killer
    local displayName = player.Name
    local itemText = ""
    
    if isKillerPlayer then
        -- Get killer type from player attributes
        local killerType = player:GetAttribute("SelectedKiller")
        
        if killerType and killerType ~= "" then
            itemText = "\n[" .. killerType .. "]"
        end
    else
        -- Get equipped item for survivor
        if survivorItemESPEnabled then
            local equippedItem = player:GetAttribute("EquippedItem")
            if equippedItem and equippedItem ~= "" then
                itemText = "\n[" .. equippedItem .. "]"
            end
        end
    end
    
    -- Create Name ESP
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "PlayerNameESP"
    billboardGui.Adornee = humanoidRootPart
    billboardGui.Size = UDim2.new(0, 150, 0, 60)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.Parent = humanoidRootPart
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = displayName .. itemText
    if isKillerPlayer then
        textLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
    else
        textLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    end
    textLabel.TextSize = 14
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextStrokeTransparency = 0.5
    textLabel.Parent = billboardGui
    
    playerESPData[player] = {
        highlight = highlight,
        billboard = billboardGui,
        textLabel = textLabel,
        isKiller = isKillerPlayer
    }
end

function removePlayerESP(player)
    if playerESPData[player] then
        if playerESPData[player].highlight then
            playerESPData[player].highlight:Destroy()
        end
        if playerESPData[player].billboard then
            playerESPData[player].billboard:Destroy()
        end
        playerESPData[player] = nil
    end
end

local function updateSurvivorItemESP()
    -- Update all survivor ESP to show/hide items
    for player, data in pairs(playerESPData) do
        if not data.isKiller and player.Character then
            -- Recreate ESP to update item display
            if survivorESPEnabled then
                createPlayerESP(player, false)
            end
        end
    end
end

local function updatePlayerESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Players.LocalPlayer then
            local isKillerPlayer = isKiller(player)
            
            if isKillerPlayer and killerESPEnabled then
                createPlayerESP(player, true)
            elseif not isKillerPlayer and survivorESPEnabled then
                createPlayerESP(player, false)
            else
                removePlayerESP(player)
            end
        end
    end
end

local function disableAllPlayerESP()
    for player, _ in pairs(playerESPData) do
        removePlayerESP(player)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- RESPONSIVE CROSSHAIR FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

local function createCrosshair()
    if crosshairUI then
        crosshairUI:Destroy()
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CrosshairUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true -- Penting untuk mobile agar tidak terpengaruh notch/safe area
    
    local success = pcall(function()
        screenGui.Parent = CoreGui
    end)
    if not success then
        screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end
    
    -- Deteksi platform
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local isTablet = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and workspace.CurrentCamera.ViewportSize.X > 600
    local isConsole = UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled
    
    -- Ukuran responsif berdasarkan platform
    local crosshairSize = 40
    local lineLength = 20
    local lineThickness = 2
    local centerDotSize = 4
    
    if isMobile and not isTablet then
        -- Mobile phone: crosshair lebih besar
        crosshairSize = 60
        lineLength = 30
        lineThickness = 3
        centerDotSize = 6
    elseif isTablet then
        -- Tablet: ukuran sedang
        crosshairSize = 50
        lineLength = 25
        lineThickness = 2.5
        centerDotSize = 5
    elseif isConsole then
        -- Console: ukuran standar dengan garis lebih tebal
        crosshairSize = 45
        lineLength = 22
        lineThickness = 2.5
        centerDotSize = 5
    end
    
    -- Main Crosshair Frame
    local crosshairFrame = Instance.new("Frame")
    crosshairFrame.Name = "CrosshairFrame"
    crosshairFrame.Size = UDim2.new(0, crosshairSize, 0, crosshairSize)
    crosshairFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    crosshairFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    crosshairFrame.BackgroundTransparency = 1
    crosshairFrame.Parent = screenGui
    
    -- UIAspectRatioConstraint untuk menjaga bentuk square
    local aspectRatio = Instance.new("UIAspectRatioConstraint")
    aspectRatio.AspectRatio = 1
    aspectRatio.Parent = crosshairFrame
    
    -- UISizeConstraint untuk mencegah crosshair terlalu besar/kecil
    local sizeConstraint = Instance.new("UISizeConstraint")
    sizeConstraint.MinSize = Vector2.new(30, 30)
    sizeConstraint.MaxSize = Vector2.new(100, 100)
    sizeConstraint.Parent = crosshairFrame
    
    -- Horizontal Line
    local horizontalLine = Instance.new("Frame")
    horizontalLine.Name = "HorizontalLine"
    horizontalLine.Size = UDim2.new(0.5, 0, 0, lineThickness)
    horizontalLine.AnchorPoint = Vector2.new(0.5, 0.5)
    horizontalLine.Position = UDim2.new(0.5, 0, 0.5, 0)
    horizontalLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    horizontalLine.BorderSizePixel = 0
    horizontalLine.Parent = crosshairFrame
    
    -- Horizontal Line Stroke
    local horizontalStroke = Instance.new("UIStroke")
    horizontalStroke.Color = Color3.fromRGB(0, 0, 0)
    horizontalStroke.Thickness = 1
    horizontalStroke.Parent = horizontalLine
    
    -- Vertical Line
    local verticalLine = Instance.new("Frame")
    verticalLine.Name = "VerticalLine"
    verticalLine.Size = UDim2.new(0, lineThickness, 0.5, 0)
    verticalLine.AnchorPoint = Vector2.new(0.5, 0.5)
    verticalLine.Position = UDim2.new(0.5, 0, 0.5, 0)
    verticalLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    verticalLine.BorderSizePixel = 0
    verticalLine.Parent = crosshairFrame
    
    -- Vertical Line Stroke
    local verticalStroke = Instance.new("UIStroke")
    verticalStroke.Color = Color3.fromRGB(0, 0, 0)
    verticalStroke.Thickness = 1
    verticalStroke.Parent = verticalLine
    
    -- Center Dot
    local centerDot = Instance.new("Frame")
    centerDot.Name = "CenterDot"
    centerDot.Size = UDim2.new(0.1, 0, 0.1, 0)
    centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
    centerDot.Position = UDim2.new(0.5, 0, 0.5, 0)
    centerDot.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    centerDot.BorderSizePixel = 0
    centerDot.Parent = crosshairFrame
    
    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = centerDot
    
    local dotStroke = Instance.new("UIStroke")
    dotStroke.Color = Color3.fromRGB(0, 0, 0)
    dotStroke.Thickness = 1
    dotStroke.Parent = centerDot
    
    -- UIAspectRatioConstraint untuk center dot
    local dotAspectRatio = Instance.new("UIAspectRatioConstraint")
    dotAspectRatio.AspectRatio = 1
    dotAspectRatio.Parent = centerDot
    
    -- Update crosshair saat viewport berubah (rotasi device, resize window)
    local function updateCrosshairSize()
        local viewportSize = workspace.CurrentCamera.ViewportSize
        local isMobileNow = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
        local isTabletNow = isMobileNow and viewportSize.X > 600
        local isConsoleNow = UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled
        
        -- Update ukuran berdasarkan platform dan orientasi
        local newCrosshairSize = 40
        local newLineLength = 20
        local newLineThickness = 2
        local newCenterDotSize = 4
        
        if isMobileNow and not isTabletNow then
            -- Cek orientasi untuk mobile
            if viewportSize.X > viewportSize.Y then
                -- Landscape: ukuran sedang
                newCrosshairSize = 50
                newLineLength = 25
                newLineThickness = 2.5
                newCenterDotSize = 5
            else
                -- Portrait: ukuran besar
                newCrosshairSize = 60
                newLineLength = 30
                newLineThickness = 3
                newCenterDotSize = 6
            end
        elseif isTabletNow then
            newCrosshairSize = 50
            newLineLength = 25
            newLineThickness = 2.5
            newCenterDotSize = 5
        elseif isConsoleNow then
            newCrosshairSize = 45
            newLineLength = 22
            newLineThickness = 2.5
            newCenterDotSize = 5
        end
        
        -- Apply perubahan ukuran dengan smooth transition
        crosshairFrame.Size = UDim2.new(0, newCrosshairSize, 0, newCrosshairSize)
        horizontalLine.Size = UDim2.new(0, newLineLength, 0, newLineThickness)
        verticalLine.Size = UDim2.new(0, newLineThickness, 0, newLineLength)
        centerDot.Size = UDim2.new(0, newCenterDotSize, 0, newCenterDotSize)
    end
    
    -- Monitor perubahan viewport
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateCrosshairSize)
    
    -- Monitor perubahan input device (untuk kasus user menghubungkan/melepas controller)
    UserInputService.GamepadConnected:Connect(updateCrosshairSize)
    UserInputService.GamepadDisconnected:Connect(updateCrosshairSize)
    
    crosshairUI = screenGui
end

local function enableCrosshair()
    crosshairEnabled = true
    createCrosshair()
end

local function disableCrosshair()
    crosshairEnabled = false
    if crosshairUI then
        crosshairUI:Destroy()
        crosshairUI = nil
    end
end

-- ===========================================
-- Speed Boost Functions (WALKSPEED-BASED)
-- ===========================================
local function getHumanoid()
    local player = Players.LocalPlayer
    if player and player.Character then
        return player.Character:FindFirstChildOfClass("Humanoid")
    end
    return nil
end

local function applySpeedBoost()
    local humanoid = getHumanoid()
    if humanoid then
        humanoid.WalkSpeed = currentSpeedBoost
    end
end

local function enableSpeedBoost()
    speedBoostEnabled = true
    applySpeedBoost()
    
    if speedBoostConnection then
        speedBoostConnection:Disconnect()
    end
    
    -- ✅ Apply on character respawn
    speedBoostConnection = Players.LocalPlayer.CharacterAdded:Connect(function(character)
        if speedBoostEnabled then
            task.wait(0.5)
            applySpeedBoost()
        end
    end)
    
    -- ✅ Monitor WalkSpeed changes to reapply if reset
    local function monitorWalkSpeed()
        local humanoid = getHumanoid()
        if humanoid then
            local conn = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
                if speedBoostEnabled then
                    local currentValue = humanoid.WalkSpeed
                    if currentValue ~= currentSpeedBoost then
                        task.wait(0.1)
                        applySpeedBoost()
                    end
                end
            end)
            addConnection("speedboost", conn)
        end
    end
    
    monitorWalkSpeed()
    
    -- Monitor for new character
    local charConn = Players.LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        monitorWalkSpeed()
    end)
    addConnection("speedboost", charConn)
end

local function disableSpeedBoost()
    speedBoostEnabled = false
    
    if speedBoostConnection then
        speedBoostConnection:Disconnect()
        speedBoostConnection = nil
    end
    
    disconnectAll("speedboost")
    
    local humanoid = getHumanoid()
    if humanoid then
        humanoid.WalkSpeed = 16 -- Reset ke default speed (sesuaikan dengan CFG.walk jika ada)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTO PERFECT GENERATOR FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

local lastPressTime = 0
local pressedThisRound = false
local lastGoalRotationTracked = 0
local lastSkillCheckActive = false

local function checkSkillCheck()
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return end
    
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end
    
    local skillCheckGui = playerGui:FindFirstChild("SkillCheckPromptGui")
    if not skillCheckGui then 
        -- Reset when skill check disappears
        pressedThisRound = false
        lastGoalRotationTracked = 0
        lastSkillCheckActive = false
        return 
    end
    
    local check = skillCheckGui:FindFirstChild("Check")
    if not check then 
        pressedThisRound = false
        lastGoalRotationTracked = 0
        lastSkillCheckActive = false
        return 
    end
    
    local line = check:FindFirstChild("Line")
    local goal = check:FindFirstChild("Goal")
    
    if not line or not goal then 
        lastSkillCheckActive = false
        return 
    end
    
    -- Get rotation values
    local lineRotation = line.Rotation
    local goalRotation = goal.Rotation
    
    -- Don't press if Goal or Line is at 0 (skill check not started yet)
    if goalRotation == 0 or lineRotation == 0 then
        -- Reset when skill check is not active
        if lastSkillCheckActive then
            pressedThisRound = false
            lastGoalRotationTracked = 0
            lastSkillCheckActive = false
        end
        return
    end
    
    -- Skill check is now active
    if not lastSkillCheckActive then
        lastSkillCheckActive = true
        pressedThisRound = false
        lastGoalRotationTracked = goalRotation
    end
    
    -- Detect new skill check (goal rotation changed significantly)
    if math.abs(goalRotation - lastGoalRotationTracked) > 10 then
        pressedThisRound = false
        lastGoalRotationTracked = goalRotation
    end
    
    -- Normalize rotation values (handle 360 degree wrap)
    local function normalizeRotation(rot)
        while rot < 0 do rot = rot + 360 end
        while rot >= 360 do rot = rot - 360 end
        return rot
    end
    
    lineRotation = normalizeRotation(lineRotation)
    goalRotation = normalizeRotation(goalRotation)
    
    -- Calculate difference (considering rotation direction)
    local diff = lineRotation - goalRotation
    
    -- Normalize difference to handle 360° wrap
    while diff > 180 do diff = diff - 360 end
    while diff < -180 do diff = diff + 360 end
    
    -- Line is moving clockwise, so we need to press BEFORE it reaches the goal
    -- Perfect zone: adjusted to be more accurate (reduced from 105° to 103°)
    local offsetBefore = 103 -- Fine-tuned offset
    local tolerance = 2 -- Tighter tolerance for more precision
    
    -- Check if line is in the perfect zone
    local inPerfectZone = (diff >= offsetBefore - tolerance and diff <= offsetBefore + tolerance)
   
    -- Only press if in perfect zone and haven't pressed this round
    if inPerfectZone and not pressedThisRound then
        local currentTime = tick()
        -- Prevent double pressing (minimum 0.05 second between presses)
        if currentTime - lastPressTime >= 0.05 then
            -- Add 0.02 second (20ms) delay before pressing
            task.wait(0.02)
            
            -- Simulate space key press
            local virtualInputManager = game:GetService("VirtualInputManager")
            virtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.01)
            virtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            
            lastPressTime = currentTime
            pressedThisRound = true
        end
    end
end

local function enableAutoPerfect()
    autoPerfectEnabled = true
    
    if autoPerfectConnection then
        autoPerfectConnection:Disconnect()
    end
    
    -- Monitor skill check continuously
    autoPerfectConnection = RunService.RenderStepped:Connect(function()
        if autoPerfectEnabled then
            pcall(checkSkillCheck)
        end
    end)
end

local function disableAutoPerfect()
    autoPerfectEnabled = false
    
    if autoPerfectConnection then
        autoPerfectConnection:Disconnect()
        autoPerfectConnection = nil
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- DEBUG OVERLAY FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

local function createDebugOverlay()
    if debugOverlayUI then
        debugOverlayUI:Destroy()
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SkillCheckDebugOverlay"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local success = pcall(function()
        screenGui.Parent = CoreGui
    end)
    if not success then
        screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end
    
    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "DebugFrame"
    mainFrame.Size = UDim2.new(0, 300, 0, 260)
    mainFrame.Position = UDim2.new(0, 10, 0.5, -130)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 8)
    mainCorner.Parent = mainFrame
    
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(255, 165, 0)
    mainStroke.Thickness = 2
    mainStroke.Parent = mainFrame
    
    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, -20, 0, 30)
    titleLabel.Position = UDim2.new(0, 10, 0, 5)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "⚙️ Skill Check Debug"
    titleLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
    titleLabel.TextSize = 16
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = mainFrame
    
    -- Line Rotation Label
    local lineRotationLabel = Instance.new("TextLabel")
    lineRotationLabel.Name = "LineRotationLabel"
    lineRotationLabel.Size = UDim2.new(1, -20, 0, 25)
    lineRotationLabel.Position = UDim2.new(0, 10, 0, 40)
    lineRotationLabel.BackgroundTransparency = 1
    lineRotationLabel.Text = "Line Rotation: N/A"
    lineRotationLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
    lineRotationLabel.TextSize = 14
    lineRotationLabel.Font = Enum.Font.GothamBold
    lineRotationLabel.TextXAlignment = Enum.TextXAlignment.Left
    lineRotationLabel.Parent = mainFrame
    
    -- Goal Rotation Label
    local goalRotationLabel = Instance.new("TextLabel")
    goalRotationLabel.Name = "GoalRotationLabel"
    goalRotationLabel.Size = UDim2.new(1, -20, 0, 25)
    goalRotationLabel.Position = UDim2.new(0, 10, 0, 70)
    goalRotationLabel.BackgroundTransparency = 1
    goalRotationLabel.Text = "Goal Rotation: N/A"
    goalRotationLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    goalRotationLabel.TextSize = 14
    goalRotationLabel.Font = Enum.Font.GothamBold
    goalRotationLabel.TextXAlignment = Enum.TextXAlignment.Left
    goalRotationLabel.Parent = mainFrame
    
    -- Circle Rotation Label
    local circleRotationLabel = Instance.new("TextLabel")
    circleRotationLabel.Name = "CircleRotationLabel"
    circleRotationLabel.Size = UDim2.new(1, -20, 0, 25)
    circleRotationLabel.Position = UDim2.new(0, 10, 0, 100)
    circleRotationLabel.BackgroundTransparency = 1
    circleRotationLabel.Text = "Circle Rotation: N/A"
    circleRotationLabel.TextColor3 = Color3.fromRGB(100, 255, 200)
    circleRotationLabel.TextSize = 14
    circleRotationLabel.Font = Enum.Font.Gotham
    circleRotationLabel.TextXAlignment = Enum.TextXAlignment.Left
    circleRotationLabel.Parent = mainFrame
    
    -- Shadow Rotation Label
    local shadowRotationLabel = Instance.new("TextLabel")
    shadowRotationLabel.Name = "ShadowRotationLabel"
    shadowRotationLabel.Size = UDim2.new(1, -20, 0, 25)
    shadowRotationLabel.Position = UDim2.new(0, 10, 0, 130)
    shadowRotationLabel.BackgroundTransparency = 1
    shadowRotationLabel.Text = "Shadow Rotation: N/A"
    shadowRotationLabel.TextColor3 = Color3.fromRGB(200, 150, 255)
    shadowRotationLabel.TextSize = 14
    shadowRotationLabel.Font = Enum.Font.Gotham
    shadowRotationLabel.TextXAlignment = Enum.TextXAlignment.Left
    shadowRotationLabel.Parent = mainFrame
    
    -- Space Rotation Label
    local spaceRotationLabel = Instance.new("TextLabel")
    spaceRotationLabel.Name = "SpaceRotationLabel"
    spaceRotationLabel.Size = UDim2.new(1, -20, 0, 25)
    spaceRotationLabel.Position = UDim2.new(0, 10, 0, 160)
    spaceRotationLabel.BackgroundTransparency = 1
    spaceRotationLabel.Text = "Space Rotation: N/A"
    spaceRotationLabel.TextColor3 = Color3.fromRGB(255, 150, 200)
    spaceRotationLabel.TextSize = 14
    spaceRotationLabel.Font = Enum.Font.Gotham
    spaceRotationLabel.TextXAlignment = Enum.TextXAlignment.Left
    spaceRotationLabel.Parent = mainFrame
    
    -- Difference Label
    local differenceLabel = Instance.new("TextLabel")
    differenceLabel.Name = "DifferenceLabel"
    differenceLabel.Size = UDim2.new(1, -20, 0, 25)
    differenceLabel.Position = UDim2.new(0, 10, 0, 190)
    differenceLabel.BackgroundTransparency = 1
    differenceLabel.Text = "Difference: N/A"
    differenceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    differenceLabel.TextSize = 14
    differenceLabel.Font = Enum.Font.Gotham
    differenceLabel.TextXAlignment = Enum.TextXAlignment.Left
    differenceLabel.Parent = mainFrame
    
    -- Status Label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, -20, 0, 25)
    statusLabel.Position = UDim2.new(0, 10, 0, 220)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Status: Waiting..."
    statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    statusLabel.TextSize = 14
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = mainFrame
    
    -- Info Label
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "InfoLabel"
    infoLabel.Size = UDim2.new(1, -20, 0, 20)
    infoLabel.Position = UDim2.new(0, 10, 0, 245)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "Perfect Zone: ~105° before Goal (±5°)"
    infoLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
    infoLabel.TextSize = 11
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.Parent = mainFrame
    
    debugOverlayUI = screenGui
    
    -- Update loop
    task.spawn(function()
        while debugOverlayUI and debugOverlayEnabled do
            local localPlayer = Players.LocalPlayer
            if localPlayer then
                local playerGui = localPlayer:FindFirstChild("PlayerGui")
                if playerGui then
                    local skillCheckGui = playerGui:FindFirstChild("SkillCheckPromptGui")
                    if skillCheckGui then
                        local check = skillCheckGui:FindFirstChild("Check")
                        if check then
                            local line = check:FindFirstChild("Line")
                            local goal = check:FindFirstChild("Goal")
                            local circle = check:FindFirstChild("Circle")
                            local shadow = check:FindFirstChild("Shadow")
                            local space = check:FindFirstChild("Space")
                            
                            if line and goal then
                                local lineRot = line.Rotation
                                local goalRot = goal.Rotation
                                local circleRot = circle and circle.Rotation or 0
                                local shadowRot = shadow and shadow.Rotation or 0
                                local spaceRot = space and space.Rotation or 0
                                
                                -- Check if skill check has started
                                if goalRot == 0 or lineRot == 0 then
                                    -- Display last saved values when reset
                                    if lastGoalRotation ~= 0 then
                                        lineRotationLabel.Text = string.format("Line Rotation: %.2f° (Last)", lastLineRotation)
                                        goalRotationLabel.Text = string.format("Goal Rotation: %.2f° (Last)", lastGoalRotation)
                                        circleRotationLabel.Text = string.format("Circle Rotation: %.2f° (Last)", lastCircleRotation)
                                        shadowRotationLabel.Text = string.format("Shadow Rotation: %.2f° (Last)", lastShadowRotation)
                                        spaceRotationLabel.Text = string.format("Space Rotation: %.2f° (Last)", lastSpaceRotation)
                                        differenceLabel.Text = string.format("Difference: %.2f° (Last)", lastDifference)
                                        statusLabel.Text = lastStatus
                                        statusLabel.TextColor3 = lastStatusColor
                                    else
                                        lineRotationLabel.Text = string.format("Line Rotation: %.2f°", lineRot)
                                        goalRotationLabel.Text = string.format("Goal Rotation: %.2f°", goalRot)
                                        circleRotationLabel.Text = string.format("Circle Rotation: %.2f°", circleRot)
                                        shadowRotationLabel.Text = string.format("Shadow Rotation: %.2f°", shadowRot)
                                        spaceRotationLabel.Text = string.format("Space Rotation: %.2f°", spaceRot)
                                        differenceLabel.Text = "Difference: N/A"
                                        statusLabel.Text = "Status: 🔄 Not Started"
                                        statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
                                    end
                                else
                                    local diff = lineRot - goalRot
                                    
                                    -- Normalize difference
                                    while diff > 180 do diff = diff - 360 end
                                    while diff < -180 do diff = diff + 360 end
                                    
                                    -- Save current values
                                    lastLineRotation = lineRot
                                    lastGoalRotation = goalRot
                                    lastCircleRotation = circleRot
                                    lastShadowRotation = shadowRot
                                    lastSpaceRotation = spaceRot
                                    lastDifference = diff
                                    
                                    -- Update labels
                                    lineRotationLabel.Text = string.format("Line Rotation: %.2f°", lineRot)
                                    goalRotationLabel.Text = string.format("Goal Rotation: %.2f°", goalRot)
                                    circleRotationLabel.Text = string.format("Circle Rotation: %.2f°", circleRot)
                                    shadowRotationLabel.Text = string.format("Shadow Rotation: %.2f°", shadowRot)
                                    spaceRotationLabel.Text = string.format("Space Rotation: %.2f°", spaceRot)
                                    differenceLabel.Text = string.format("Difference: %.2f°", diff)
                                    
                                    -- Calculate status
                                    local absDiff = math.abs(diff)
                                    if absDiff >= 100 and absDiff <= 110 then
                                        lastStatus = "Status: ✓ PERFECT ZONE!"
                                        lastStatusColor = Color3.fromRGB(0, 255, 0)
                                    elseif absDiff >= 95 and absDiff <= 115 then
                                        lastStatus = "Status: ⚠ Good Zone"
                                        lastStatusColor = Color3.fromRGB(255, 200, 0)
                                    elseif diff < 100 then
                                        lastStatus = "Status: ⏳ Too Early"
                                        lastStatusColor = Color3.fromRGB(100, 150, 255)
                                    else
                                        lastStatus = "Status: ❌ Too Late"
                                        lastStatusColor = Color3.fromRGB(255, 100, 100)
                                    end
                                    
                                    statusLabel.Text = lastStatus
                                    statusLabel.TextColor3 = lastStatusColor
                                end
                            else
                                -- Display last saved values if available
                                if lastGoalRotation ~= 0 then
                                    lineRotationLabel.Text = string.format("Line Rotation: %.2f° (Last)", lastLineRotation)
                                    goalRotationLabel.Text = string.format("Goal Rotation: %.2f° (Last)", lastGoalRotation)
                                    circleRotationLabel.Text = string.format("Circle Rotation: %.2f° (Last)", lastCircleRotation)
                                    shadowRotationLabel.Text = string.format("Shadow Rotation: %.2f° (Last)", lastShadowRotation)
                                    spaceRotationLabel.Text = string.format("Space Rotation: %.2f° (Last)", lastSpaceRotation)
                                    differenceLabel.Text = string.format("Difference: %.2f° (Last)", lastDifference)
                                    statusLabel.Text = lastStatus
                                    statusLabel.TextColor3 = lastStatusColor
                                else
                                    lineRotationLabel.Text = "Line Rotation: N/A"
                                    goalRotationLabel.Text = "Goal Rotation: N/A"
                                    circleRotationLabel.Text = "Circle Rotation: N/A"
                                    shadowRotationLabel.Text = "Shadow Rotation: N/A"
                                    spaceRotationLabel.Text = "Space Rotation: N/A"
                                    differenceLabel.Text = "Difference: N/A"
                                    statusLabel.Text = "Status: No Data"
                                    statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
                                end
                            end
                        else
                            -- Display last saved values if available
                            if lastGoalRotation ~= 0 then
                                lineRotationLabel.Text = string.format("Line Rotation: %.2f° (Last)", lastLineRotation)
                                goalRotationLabel.Text = string.format("Goal Rotation: %.2f° (Last)", lastGoalRotation)
                                circleRotationLabel.Text = string.format("Circle Rotation: %.2f° (Last)", lastCircleRotation)
                                shadowRotationLabel.Text = string.format("Shadow Rotation: %.2f° (Last)", lastShadowRotation)
                                spaceRotationLabel.Text = string.format("Space Rotation: %.2f° (Last)", lastSpaceRotation)
                                differenceLabel.Text = string.format("Difference: %.2f° (Last)", lastDifference)
                                statusLabel.Text = lastStatus
                                statusLabel.TextColor3 = lastStatusColor
                            else
                                lineRotationLabel.Text = "Line Rotation: N/A"
                                goalRotationLabel.Text = "Goal Rotation: N/A"
                                circleRotationLabel.Text = "Circle Rotation: N/A"
                                shadowRotationLabel.Text = "Shadow Rotation: N/A"
                                spaceRotationLabel.Text = "Space Rotation: N/A"
                                differenceLabel.Text = "Difference: N/A"
                                statusLabel.Text = "Status: No Check"
                                statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
                            end
                        end
                    else
                        -- Display last saved values if available
                        if lastGoalRotation ~= 0 then
                            lineRotationLabel.Text = string.format("Line Rotation: %.2f° (Last)", lastLineRotation)
                            goalRotationLabel.Text = string.format("Goal Rotation: %.2f° (Last)", lastGoalRotation)
                            circleRotationLabel.Text = string.format("Circle Rotation: %.2f° (Last)", lastCircleRotation)
                            shadowRotationLabel.Text = string.format("Shadow Rotation: %.2f° (Last)", lastShadowRotation)
                            spaceRotationLabel.Text = string.format("Space Rotation: %.2f° (Last)", lastSpaceRotation)
                            differenceLabel.Text = string.format("Difference: %.2f° (Last)", lastDifference)
                            statusLabel.Text = lastStatus
                            statusLabel.TextColor3 = lastStatusColor
                        else
                            lineRotationLabel.Text = "Line Rotation: N/A"
                            goalRotationLabel.Text = "Goal Rotation: N/A"
                            circleRotationLabel.Text = "Circle Rotation: N/A"
                            shadowRotationLabel.Text = "Shadow Rotation: N/A"
                            spaceRotationLabel.Text = "Space Rotation: N/A"
                            differenceLabel.Text = "Difference: N/A"
                            statusLabel.Text = "Status: Waiting..."
                            statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
                        end
                    end
                end
            end
            
            task.wait(0.016) -- Update at ~60 FPS
        end
    end)
end

local function enableDebugOverlay()
    debugOverlayEnabled = true
    createDebugOverlay()
end

local function disableDebugOverlay()
    debugOverlayEnabled = false
    if debugOverlayUI then
        debugOverlayUI:Destroy()
        debugOverlayUI = nil
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- LONG RANGE HEAL FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

local function removeHealTargetESP()
    if healTargetESP then
        healTargetESP:Destroy()
        healTargetESP = nil
    end
end

local function createHealTargetESP(character)
    removeHealTargetESP()
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "HealTarget_ESP"
    highlight.FillColor = Color3.fromRGB(0, 255, 255) -- Cyan
    highlight.FillTransparency = 0.7
    highlight.OutlineTransparency = 1
    highlight.Parent = character
    
    healTargetESP = highlight
end

local function getTargetInFOV()
    local localPlayer = Players.LocalPlayer
    local camera = Workspace.CurrentCamera
    
    if not localPlayer.Character then return nil end
    local localRoot = localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return nil end
    
    local cameraPos = camera.CFrame.Position
    local cameraLook = camera.CFrame.LookVector
    
    local closestPlayer = nil
    local smallestAngle = math.huge
    local maxAngle = 15 -- FOV angle in degrees
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character then
            -- Skip if player is a killer
            if isKiller(player) then
                continue
            end
            
            local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                local direction = (targetRoot.Position - cameraPos).Unit
                local angle = math.acos(cameraLook:Dot(direction))
                local angleDegrees = math.deg(angle)
                
                if angleDegrees < maxAngle and angleDegrees < smallestAngle then
                    smallestAngle = angleDegrees
                    closestPlayer = player
                end
            end
        end
    end
    
    return closestPlayer
end

local function processHeal()
    if not healTarget then return end
    
    if not healTarget.Character then
        healTarget = nil
        removeHealTargetESP()
        return
    end
    
    -- Skip if target is a killer
    if isKiller(healTarget) then
        healTarget = nil
        removeHealTargetESP()
        return
    end
    
    local humanoidRootPart = healTarget.Character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        healTarget = nil
        removeHealTargetESP()
        return
    end
    
    local success = pcall(function()
        local args = { humanoidRootPart, true } -- true to heal, false to cancel
        ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Healing"):WaitForChild("HealEvent"):FireServer(unpack(args))
    end)
    
    removeHealTargetESP()
    healTarget = nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTO REFRESH ESP SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════

local autoRefreshEnabled = true
local lastMapInstance = nil

local function refreshAllESP()
    if generatorESPHighlightEnabled then
        disableGeneratorESPHighlight()
        task.wait(0.1)
        enableGeneratorESPHighlight()
    end
    
    if pumpkinESPHighlightEnabled then
        disablePumpkinESPHighlight()
        task.wait(0.1)
        enablePumpkinESPHighlight()
    end
    
    if leverESPEnabled then
        disableLeverESP()
        task.wait(0.1)
        enableLeverESP()
    end
    
    -- Refresh Player ESP
    disableAllPlayerESP()
    task.wait(0.1)
    updatePlayerESP()
end

local function setupAutoRefresh()
    -- Monitor Map changes
    task.spawn(function()
        while autoRefreshEnabled do
            task.wait(1) -- Check every 10 seconds
            
            local currentMap = Workspace:FindFirstChild("Map")
            
            if currentMap ~= lastMapInstance then
                if currentMap then
                    lastMapInstance = currentMap
                    task.wait(0.5)
                    refreshAllESP()
                else
                    lastMapInstance = nil
                end
            end
        end
    end)
    
    -- Monitor new generators and pumpkins
    task.spawn(function()
        while autoRefreshEnabled do
            task.wait(10) -- Check every 10 seconds
            
            local map = Workspace:FindFirstChild("Map")
            if not map then continue end
            
            local generators = getGenerators()
            for _, gen in ipairs(generators) do
                if generatorESPHighlightEnabled and not generatorESPHighlights[gen] then
                    createGeneratorESPHighlight(gen)
                end
            end
            
            local pumpkins = getPumpkins()
            for _, pumpkin in ipairs(pumpkins) do
                if pumpkinESPHighlightEnabled and not pumpkinESPHighlights[pumpkin] then
                    createPumpkinESPHighlight(pumpkin)
                end
            end
            
            -- Check for lever
            if leverESPEnabled then
                local lever = getLever()
                if lever and not leverESPHighlights[lever] then
                    createLeverESP(lever)
                end
            end
        end
    end)
    
    -- Monitor player ESP refresh
    task.spawn(function()
        while autoRefreshEnabled do
            task.wait(2) -- Check every 2 seconds for faster refresh
            
            if survivorESPEnabled or killerESPEnabled then
                -- Check for players who left
                for player, _ in pairs(playerESPData) do
                    if not player.Parent or not Players:FindFirstChild(player.Name) then
                        removePlayerESP(player)
                    end
                end
                
                -- Check for new players or character respawns
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= Players.LocalPlayer then
                        local isKillerPlayer = isKiller(player)
                        local hasESP = playerESPData[player] ~= nil
                        
                        -- Refresh ESP if character changed or ESP is broken
                        if hasESP then
                            local needsRefresh = false
                            
                            -- Check if highlight is broken
                            if playerESPData[player].highlight then
                                if not playerESPData[player].highlight.Parent then
                                    needsRefresh = true
                                end
                            else
                                needsRefresh = true
                            end
                            
                            -- Check if character changed
                            if not player.Character then
                                needsRefresh = true
                            elseif playerESPData[player].highlight and playerESPData[player].highlight.Parent ~= player.Character then
                                needsRefresh = true
                            end
                            
                            -- Remove old ESP if broken
                            if needsRefresh then
                                removePlayerESP(player)
                                hasESP = false
                            end
                        end
                        
                        -- Create ESP if needed
                        if not hasESP and player.Character then
                            local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
                            if humanoidRootPart then
                                if (isKillerPlayer and killerESPEnabled) or (not isKillerPlayer and survivorESPEnabled) then
                                    createPlayerESP(player, isKillerPlayer)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    
    -- Monitor player character added (respawn detection)
    task.spawn(function()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= Players.LocalPlayer then
                player.CharacterAdded:Connect(function(character)
                    task.wait(0.5) -- Wait for character to fully load
                    
                    if survivorESPEnabled or killerESPEnabled then
                        local isKillerPlayer = isKiller(player)
                        
                        -- Remove old ESP first
                        removePlayerESP(player)
                        
                        -- Create new ESP
                        if (isKillerPlayer and killerESPEnabled) or (not isKillerPlayer and survivorESPEnabled) then
                            createPlayerESP(player, isKillerPlayer)
                        end
                    end
                end)
            end
        end
    end)
    
    -- Monitor player join/leave events
    Players.PlayerAdded:Connect(function(player)
        task.wait(1)
        
        -- Setup character added event for new player
        player.CharacterAdded:Connect(function(character)
            task.wait(0.5)
            
            if survivorESPEnabled or killerESPEnabled then
                local isKillerPlayer = isKiller(player)
                
                removePlayerESP(player)
                
                if (isKillerPlayer and killerESPEnabled) or (not isKillerPlayer and survivorESPEnabled) then
                    createPlayerESP(player, isKillerPlayer)
                end
            end
        end)
        
        if survivorESPEnabled or killerESPEnabled then
            updatePlayerESP()
        end
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        removePlayerESP(player)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UI SYNC FUNCTION
-- ═══════════════════════════════════════════════════════════════════════════

local function syncUI()
    if generatorHighlightToggle then pcall(function() generatorHighlightToggle:Set(generatorESPHighlightEnabled) end) end
    if pumpkinHighlightToggle then pcall(function() pumpkinHighlightToggle:Set(pumpkinESPHighlightEnabled) end) end
    if leverESPToggle then pcall(function() leverESPToggle:Set(leverESPEnabled) end) end
    if survivorESPToggle then pcall(function() survivorESPToggle:Set(survivorESPEnabled) end) end
    if killerESPToggle then pcall(function() killerESPToggle:Set(killerESPEnabled) end) end
    if survivorItemESPToggle then pcall(function() survivorItemESPToggle:Set(survivorItemESPEnabled) end) end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SCRIPT EXECUTOR UI (NATIVE ROBLOX)
-- ═══════════════════════════════════════════════════════════════════════════

local scriptExecutorUI = nil
local scriptExecutorVisible = false
local savedScripts = {}

local function createScriptExecutorUI()
    if scriptExecutorUI then
        scriptExecutorUI:Destroy()
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ScriptExecutorUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local success = pcall(function()
        screenGui.Parent = CoreGui
    end)
    if not success then
        screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 600, 0, 450)
    mainFrame.Position = UDim2.new(0.5, -300, 0.5, -225)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Visible = false
    mainFrame.Parent = screenGui
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = mainFrame
    
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(255, 165, 0)
    mainStroke.Thickness = 2
    mainStroke.Parent = mainFrame
    
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, -50, 1, 0)
    titleLabel.Position = UDim2.new(0, 15, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "⚡ Script Executor"
    titleLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
    titleLabel.TextSize = 18
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = titleBar
    
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 5)
    closeButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    closeButton.Text = "✕"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 16
    closeButton.Font = Enum.Font.GothamBold
    closeButton.BorderSizePixel = 0
    closeButton.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeButton
    
    closeButton.MouseButton1Click:Connect(function()
        mainFrame.Visible = false
        scriptExecutorVisible = false
    end)
    
    -- Line Numbers Frame
    local lineNumberFrame = Instance.new("Frame")
    lineNumberFrame.Name = "LineNumberFrame"
    lineNumberFrame.Size = UDim2.new(0, 40, 0, 280)
    lineNumberFrame.Position = UDim2.new(0, 15, 0, 55)
    lineNumberFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    lineNumberFrame.BorderSizePixel = 0
    lineNumberFrame.Parent = mainFrame
    
    local lineCorner = Instance.new("UICorner")
    lineCorner.CornerRadius = UDim.new(0, 6)
    lineCorner.Parent = lineNumberFrame
    
    local lineNumberBox = Instance.new("TextLabel")
    lineNumberBox.Name = "LineNumbers"
    lineNumberBox.Size = UDim2.new(1, -5, 1, -10)
    lineNumberBox.Position = UDim2.new(0, 5, 0, 5)
    lineNumberBox.BackgroundTransparency = 1
    lineNumberBox.TextColor3 = Color3.fromRGB(150, 150, 150)
    lineNumberBox.TextSize = 14
    lineNumberBox.Font = Enum.Font.Code
    lineNumberBox.Text = "1"
    lineNumberBox.TextXAlignment = Enum.TextXAlignment.Right
    lineNumberBox.TextYAlignment = Enum.TextYAlignment.Top
    lineNumberBox.Parent = lineNumberFrame
    
    -- Script Input with ScrollingFrame
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ScriptScroll"
    scrollFrame.Size = UDim2.new(1, -75, 0, 280)
    scrollFrame.Position = UDim2.new(0, 60, 0, 55)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.Parent = mainFrame
    
    local scrollCorner = Instance.new("UICorner")
    scrollCorner.CornerRadius = UDim.new(0, 6)
    scrollCorner.Parent = scrollFrame
    
    local scriptBox = Instance.new("TextBox")
    scriptBox.Name = "ScriptBox"
    scriptBox.Size = UDim2.new(1, -10, 1, 0)
    scriptBox.Position = UDim2.new(0, 5, 0, 0)
    scriptBox.BackgroundTransparency = 1
    scriptBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    scriptBox.TextSize = 14
    scriptBox.Font = Enum.Font.Code
    scriptBox.Text = "-- Enter your Lua script here\nprint('Hello World!')"
    scriptBox.TextXAlignment = Enum.TextXAlignment.Left
    scriptBox.TextYAlignment = Enum.TextYAlignment.Top
    scriptBox.MultiLine = true
    scriptBox.ClearTextOnFocus = false
    scriptBox.TextWrapped = true
    scriptBox.Parent = scrollFrame
    
    -- Update line numbers and canvas size
    local function updateLineNumbers()
        local text = scriptBox.Text
        local lines = 1
        for _ in text:gmatch("\n") do
            lines = lines + 1
        end
        
        local lineText = ""
        for i = 1, lines do
            lineText = lineText .. i .. "\n"
        end
        lineNumberBox.Text = lineText
        
        -- Update canvas size
        local textSize = game:GetService("TextService"):GetTextSize(
            text,
            scriptBox.TextSize,
            scriptBox.Font,
            Vector2.new(scriptBox.AbsoluteSize.X, math.huge)
        )
        scriptBox.Size = UDim2.new(1, -10, 0, math.max(textSize.Y + 10, scrollFrame.AbsoluteSize.Y))
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scriptBox.AbsoluteSize.Y)
    end
    
    scriptBox:GetPropertyChangedSignal("Text"):Connect(updateLineNumbers)
    updateLineNumbers()
    
    -- Save Script Name Input
    local saveNameBox = Instance.new("TextBox")
    saveNameBox.Name = "SaveNameBox"
    saveNameBox.Size = UDim2.new(0, 200, 0, 30)
    saveNameBox.Position = UDim2.new(0, 15, 0, 345)
    saveNameBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    saveNameBox.BorderSizePixel = 0
    saveNameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    saveNameBox.TextSize = 12
    saveNameBox.Font = Enum.Font.Gotham
    saveNameBox.PlaceholderText = "Script name..."
    saveNameBox.Text = ""
    saveNameBox.Parent = mainFrame
    
    local saveNameCorner = Instance.new("UICorner")
    saveNameCorner.CornerRadius = UDim.new(0, 6)
    saveNameCorner.Parent = saveNameBox
    
    -- Saved Scripts Dropdown
    local savedScriptFrame = Instance.new("Frame")
    savedScriptFrame.Name = "SavedScriptFrame"
    savedScriptFrame.Size = UDim2.new(0, 200, 0, 30)
    savedScriptFrame.Position = UDim2.new(0, 15, 0, 385)
    savedScriptFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    savedScriptFrame.BorderSizePixel = 0
    savedScriptFrame.Parent = mainFrame
    
    local savedCorner = Instance.new("UICorner")
    savedCorner.CornerRadius = UDim.new(0, 6)
    savedCorner.Parent = savedScriptFrame
    
    local savedLabel = Instance.new("TextLabel")
    savedLabel.Size = UDim2.new(1, -5, 1, 0)
    savedLabel.Position = UDim2.new(0, 5, 0, 0)
    savedLabel.BackgroundTransparency = 1
    savedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    savedLabel.TextSize = 12
    savedLabel.Font = Enum.Font.Gotham
    savedLabel.Text = "No saved scripts"
    savedLabel.TextXAlignment = Enum.TextXAlignment.Left
    savedLabel.Parent = savedScriptFrame
    
    -- Execute Button
    local executeButton = Instance.new("TextButton")
    executeButton.Name = "ExecuteButton"
    executeButton.Size = UDim2.new(0, 110, 0, 35)
    executeButton.Position = UDim2.new(0, 225, 0, 345)
    executeButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    executeButton.Text = "▶ Execute (H)"
    executeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    executeButton.TextSize = 14
    executeButton.Font = Enum.Font.GothamBold
    executeButton.BorderSizePixel = 0
    executeButton.Parent = mainFrame
    
    local execCorner = Instance.new("UICorner")
    execCorner.CornerRadius = UDim.new(0, 8)
    execCorner.Parent = executeButton
    
    -- Clear Button
    local clearButton = Instance.new("TextButton")
    clearButton.Name = "ClearButton"
    clearButton.Size = UDim2.new(0, 110, 0, 35)
    clearButton.Position = UDim2.new(0, 345, 0, 345)
    clearButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    clearButton.Text = "🗑 Clear"
    clearButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    clearButton.TextSize = 14
    clearButton.Font = Enum.Font.GothamBold
    clearButton.BorderSizePixel = 0
    clearButton.Parent = mainFrame
    
    local clearCorner = Instance.new("UICorner")
    clearCorner.CornerRadius = UDim.new(0, 8)
    clearCorner.Parent = clearButton
    
    -- Save Button
    local saveButton = Instance.new("TextButton")
    saveButton.Name = "SaveButton"
    saveButton.Size = UDim2.new(0, 110, 0, 35)
    saveButton.Position = UDim2.new(0, 465, 0, 345)
    saveButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
    saveButton.Text = "💾 Save"
    saveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    saveButton.TextSize = 14
    saveButton.Font = Enum.Font.GothamBold
    saveButton.BorderSizePixel = 0
    saveButton.Parent = mainFrame
    
    local saveCorner = Instance.new("UICorner")
    saveCorner.CornerRadius = UDim.new(0, 8)
    saveCorner.Parent = saveButton
    
    -- Load Button
    local loadButton = Instance.new("TextButton")
    loadButton.Name = "LoadButton"
    loadButton.Size = UDim2.new(0, 110, 0, 35)
    loadButton.Position = UDim2.new(0, 225, 0, 385)
    loadButton.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
    loadButton.Text = "📂 Load"
    loadButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    loadButton.TextSize = 14
    loadButton.Font = Enum.Font.GothamBold
    loadButton.BorderSizePixel = 0
    loadButton.Parent = mainFrame
    
    local loadCorner = Instance.new("UICorner")
    loadCorner.CornerRadius = UDim.new(0, 8)
    loadCorner.Parent = loadButton
    
    -- Delete Button
    local deleteButton = Instance.new("TextButton")
    deleteButton.Name = "DeleteButton"
    deleteButton.Size = UDim2.new(0, 110, 0, 35)
    deleteButton.Position = UDim2.new(0, 345, 0, 385)
    deleteButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    deleteButton.Text = "🗑 Delete"
    deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    deleteButton.TextSize = 14
    deleteButton.Font = Enum.Font.GothamBold
    deleteButton.BorderSizePixel = 0
    deleteButton.Parent = mainFrame
    
    local deleteCorner = Instance.new("UICorner")
    deleteCorner.CornerRadius = UDim.new(0, 8)
    deleteCorner.Parent = deleteButton
    
    -- List Button
    local listButton = Instance.new("TextButton")
    listButton.Name = "ListButton"
    listButton.Size = UDim2.new(0, 110, 0, 35)
    listButton.Position = UDim2.new(0, 465, 0, 385)
    listButton.BackgroundColor3 = Color3.fromRGB(100, 150, 100)
    listButton.Text = "📋 List All"
    listButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    listButton.TextSize = 14
    listButton.Font = Enum.Font.GothamBold
    listButton.BorderSizePixel = 0
    listButton.Parent = mainFrame
    
    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0, 8)
    listCorner.Parent = listButton
    
    -- Functions
    local function executeScript()
        local scriptText = scriptBox.Text
        
        if scriptText == "" or scriptText == nil then
            return
        end
        
        pcall(function()
            loadstring(scriptText)()
        end)
    end
    
    local function updateSavedLabel()
        if next(savedScripts) == nil then
            savedLabel.Text = "No saved scripts"
        else
            local names = {}
            for name, _ in pairs(savedScripts) do
                table.insert(names, name)
            end
            savedLabel.Text = table.concat(names, ", ")
        end
    end
    
    executeButton.MouseButton1Click:Connect(executeScript)
    
    clearButton.MouseButton1Click:Connect(function()
        scriptBox.Text = ""
    end)
    
    saveButton.MouseButton1Click:Connect(function()
        local name = saveNameBox.Text
        if name ~= "" and scriptBox.Text ~= "" then
            savedScripts[name] = scriptBox.Text
            saveNameBox.Text = ""
            updateSavedLabel()
        end
    end)
    
    loadButton.MouseButton1Click:Connect(function()
        local name = saveNameBox.Text
        if name ~= "" and savedScripts[name] then
            scriptBox.Text = savedScripts[name]
        end
    end)
    
    deleteButton.MouseButton1Click:Connect(function()
        local name = saveNameBox.Text
        if name ~= "" and savedScripts[name] then
            savedScripts[name] = nil
            saveNameBox.Text = ""
            updateSavedLabel()
        end
    end)
    
    listButton.MouseButton1Click:Connect(function()
        if next(savedScripts) == nil then return end
        for name, _ in pairs(savedScripts) do
            saveNameBox.Text = name
            break
        end
    end)
    
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.H and mainFrame.Visible then
            executeScript()
        end
    end)
    
    scriptExecutorUI = screenGui
    return mainFrame
end

local executorFrame = createScriptExecutorUI()

-- ═══════════════════════════════════════════════════════════════════════════
-- WINDOW CREATION
-- ═══════════════════════════════════════════════════════════════════════════

local Window = WindUI:CreateWindow({
    Title = "VD Helper",
    Icon = "zap",
    Author = "by Steamy",
    Folder = "VDHelper",
    Size = UDim2.fromOffset(520, 400),
    Theme = "Dark",
    Transparent = true,
    SideBarWidth = 160,
})

Window:SetToggleKey(Enum.KeyCode.RightShift)

-- ═══════════════════════════════════════════════════════════════════════════
-- TAB: ESP
-- ═══════════════════════════════════════════════════════════════════════════

local ESPTab = Window:Tab({
    Title = "ESP",
    Icon = "eye",
})

ESPTab:Section({
    Title = "Object ESP",
})

generatorHighlightToggle = ESPTab:Toggle({
    Title = "Generator Highlight",
    Desc = "Show glow around generators",
    Icon = "zap",
    Value = false,
    Callback = function(state)
        generatorESPHighlightEnabled = state
        if generatorESPHighlightEnabled then
            enableGeneratorESPHighlight()
        else
            disableGeneratorESPHighlight()
        end
    end
})

pumpkinHighlightToggle = ESPTab:Toggle({
    Title = "Pumpkin Highlight",
    Desc = "Show glow around pumpkins",
    Icon = "circle",
    Value = false,
    Callback = function(state)
        pumpkinESPHighlightEnabled = state
        if pumpkinESPHighlightEnabled then
            enablePumpkinESPHighlight()
        else
            disablePumpkinESPHighlight()
        end
    end
})

leverESPToggle = ESPTab:Toggle({
    Title = "Exit Lever ESP",
    Desc = "Show ESP for exit lever with progress",
    Icon = "toggle-right",
    Value = false,
    Callback = function(state)
        leverESPEnabled = state
        if leverESPEnabled then
            enableLeverESP()
        else
            disableLeverESP()
        end
    end
})

ESPTab:Section({
    Title = "Player ESP",
})

survivorESPToggle = ESPTab:Toggle({
    Title = "Survivor ESP",
    Desc = "Show green ESP for survivors",
    Icon = "user",
    Value = false,
    Callback = function(state)
        survivorESPEnabled = state
        updatePlayerESP()
    end
})

killerESPToggle = ESPTab:Toggle({
    Title = "Killer ESP",
    Desc = "Show red ESP for killer",
    Icon = "user-x",
    Value = false,
    Callback = function(state)
        killerESPEnabled = state
        updatePlayerESP()
    end
})

survivorItemESPToggle = ESPTab:Toggle({
    Title = "Show Survivor Items",
    Desc = "Show equipped items for survivors",
    Icon = "package",
    Value = false,
    Callback = function(state)
        survivorItemESPEnabled = state
        updateSurvivorItemESP()
    end
})

ESPTab:Section({
    Title = "Actions",
})

ESPTab:Button({
    Title = "Refresh All ESP",
    Desc = "Manually refresh all ESP",
    Callback = function()
        refreshAllESP()
    end
})

ESPTab:Button({
    Title = "Disable All ESP",
    Desc = "Turn off all ESP features",
    Callback = function()
        if generatorESPHighlightEnabled then
            generatorESPHighlightEnabled = false
            disableGeneratorESPHighlight()
        end
        
        if pumpkinESPHighlightEnabled then
            pumpkinESPHighlightEnabled = false
            disablePumpkinESPHighlight()
        end
        
        if leverESPEnabled then
            leverESPEnabled = false
            disableLeverESP()
        end
        
        if survivorESPEnabled then
            survivorESPEnabled = false
        end
        
        if killerESPEnabled then
            killerESPEnabled = false
        end
        
        disableAllPlayerESP()
        syncUI()
    end
})

ESPTab:Section({
    Title = "Crosshair",
})

ESPTab:Toggle({
    Title = "Show Crosshair",
    Desc = "Display crosshair in center of screen",
    Icon = "crosshair",
    Value = false,
    Callback = function(state)
        if state then
            enableCrosshair()
        else
            disableCrosshair()
        end
    end
})

-- ═══════════════════════════════════════════════════════════════════════════
-- TAB: SURVIVOR
-- ═══════════════════════════════════════════════════════════════════════════

local SurvivorTab = Window:Tab({
    Title = "Survivor",
    Icon = "heart",
})

SurvivorTab:Section({
    Title = "Speed Boost",
})

SurvivorTab:Toggle({
    Title = "Enable Speed Boost (Killer & Survivor)",
    Desc = "Boost your movement speed",
    Icon = "zap",
    Value = false,
    Callback = function(state)
        if state then
            enableSpeedBoost()
        else
            disableSpeedBoost()
        end
    end
})

SurvivorTab:Slider({
    Title = "Speed Boost Value (Default 16)",
    Desc = "Set speed boost value",
    Step = 1,
    Value = {
        Min = 1,
        Max = 100,
        Default = 16,
    },
    Callback = function(value)
        currentSpeedBoost = value
        if speedBoostEnabled then
            applySpeedBoost()
        end
    end
})

SurvivorTab:Section({
    Title = "Auto Perfect Generator",
})

SurvivorTab:Toggle({
    Title = "Auto Perfect",
    Desc = "Automatically hit perfect skill checks",
    Icon = "target",
    Value = false,
    Callback = function(state)
        if state then
            enableAutoPerfect()
        else
            disableAutoPerfect()
        end
    end
})

SurvivorTab:Toggle({
    Title = "Debug Overlay",
    Desc = "Show rotation values in real-time",
    Icon = "activity",
    Value = false,
    Callback = function(state)
        if state then
            enableDebugOverlay()
        else
            disableDebugOverlay()
        end
    end
})

SurvivorTab:Section({
    Title = "Long Range Heal",
})

SurvivorTab:Toggle({
    Title = "Enable Long Range Heal",
    Desc = "Look at survivor and press F to heal",
    Icon = "crosshair",
    Value = false,
    Callback = function(state)
        longRangeHealEnabled = state
        if not state then
            healTarget = nil
            removeHealTargetESP()
        end
    end
})

SurvivorTab:Button({
    Title = "Cancel Heal",
    Desc = "Cancel healing current target",
    Icon = "x",
    Callback = function()
        if healTarget and healTarget.Character then
            local humanoidRootPart = healTarget.Character:FindFirstChild("HumanoidRootPart")
            if humanoidRootPart then
                pcall(function()
                    local args = { humanoidRootPart, false } -- false to cancel heal
                    ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Healing"):WaitForChild("HealEvent"):FireServer(unpack(args))
                end)
            end
        end
        healTarget = nil
        removeHealTargetESP()
    end
})

-- ═══════════════════════════════════════════════════════════════════════════
-- TAB: EXECUTOR
-- ═══════════════════════════════════════════════════════════════════════════

local ExecutorTab = Window:Tab({
    Title = "Executor",
    Icon = "code",
})

ExecutorTab:Section({
    Title = "Script Executor",
})

ExecutorTab:Toggle({
    Title = "Show Script Executor",
    Desc = "Toggle script executor UI",
    Icon = "code",
    Value = false,
    Callback = function(state)
        scriptExecutorVisible = state
        if executorFrame then
            executorFrame.Visible = state
        end
    end
})

-- Long Range Heal Loop
RunService.RenderStepped:Connect(function()
    if longRangeHealEnabled then
        local target = getTargetInFOV()
        
        if target ~= healTarget then
            healTarget = target
            removeHealTargetESP()
            
            if healTarget and healTarget.Character then
                createHealTargetESP(healTarget.Character)
            end
        end
    else
        if healTarget then
            healTarget = nil
            removeHealTargetESP()
        end
    end
end)

-- Heal Keybind
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == healKeybind and longRangeHealEnabled and healTarget then
        processHeal()
    end
end)

-- Player ESP Update Loop
RunService.Heartbeat:Connect(function()
    if survivorESPEnabled or killerESPEnabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= Players.LocalPlayer then
                local isKillerPlayer = isKiller(player)
                local hasESP = playerESPData[player] ~= nil
                
                if isKillerPlayer and killerESPEnabled and not hasESP then
                    createPlayerESP(player, true)
                elseif not isKillerPlayer and survivorESPEnabled and not hasESP then
                    createPlayerESP(player, false)
                elseif hasESP then
                    if (isKillerPlayer and not killerESPEnabled) or (not isKillerPlayer and not survivorESPEnabled) then
                        removePlayerESP(player)
                    end
                end
            end
        end
    end
end)

-- Initialize Auto Refresh
setupAutoRefresh()

-- ═══════════════════════════════════════════════════════════════════════════
-- WINDOW DESTROY HANDLER
-- ═══════════════════════════════════════════════════════════════════════════

Window:OnDestroy(function()
    -- Disable Generator ESP
    if generatorESPHighlightEnabled then
        generatorESPHighlightEnabled = false
        disableGeneratorESPHighlight()
    end
    
    -- Disable Pumpkin ESP
    if pumpkinESPHighlightEnabled then
        pumpkinESPHighlightEnabled = false
        disablePumpkinESPHighlight()
    end
    
    -- Disable Lever ESP
    if leverESPEnabled then
        leverESPEnabled = false
        disableLeverESP()
    end
    
    -- Disable Player ESP (Survivor & Killer)
    if survivorESPEnabled then
        survivorESPEnabled = false
    end
    
    if killerESPEnabled then
        killerESPEnabled = false
    end

    -- Disable Crosshair
    if crosshairEnabled then
        disableCrosshair()
    end
    
    disableAllPlayerESP()
    
    -- Disable Speed Boost
    if speedBoostEnabled then
        disableSpeedBoost()
    end
    
    -- Disable Auto Perfect
    if autoPerfectEnabled then
        disableAutoPerfect()
    end
    
    -- Disable Debug Overlay
    if debugOverlayEnabled then
        disableDebugOverlay()
    end
    
    -- Disable Long Range Heal
    if longRangeHealEnabled then
        longRangeHealEnabled = false
        healTarget = nil
        removeHealTargetESP()
    end
    
    -- Disable Auto Refresh
    autoRefreshEnabled = false
    
    -- Destroy Script Executor UI
    if scriptExecutorUI then
        scriptExecutorUI:Destroy()
        scriptExecutorUI = nil
    end
    
    print("VD Helper: All features disabled")
end)
