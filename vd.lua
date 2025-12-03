local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local generatorESPHighlightEnabled = false
local generatorESPHighlights = {}
local generatorProgressTracking = {} -- Track progress over time for ETA calculation

local survivorESPEnabled = false
local killerESPEnabled = false
local spectatorInfoEnabled = false
local playerESPData = {}

local crosshairEnabled = false
local crosshairUI = nil

local longRangeHealEnabled = false
local healTarget = nil
local healTargetESP = nil
local healKeybind = Enum.KeyCode.F

local speedBoostEnabled = false
local currentSpeedBoost = 1.1
local speedBoostConnection = nil

local autoPerfectEnabled = false
local autoPerfectConnection = nil

local disableSkillCheckEnabled = false
local skillCheckConnections = {}

local aimbotEnabled = false
local aimbotConnection = nil
local isRightClickHeld = false

local generatorHighlightToggle
local survivorESPToggle
local killerESPToggle

-- Connection storage for cleanup
local activeConnections = {}

-- ===========================================
-- ESP Configuration Variables
-- ===========================================
local ESPConfig = {
    -- Generator ESP
    generatorFillTransparency = 0.75,
    generatorOutlineTransparency = 1,
    generatorTextSize = 18,
    
    -- Player ESP
    playerFillTransparency = 0.75,
    playerOutlineTransparency = 1,
    playerTextSize = 16,
    
    -- Colors
    survivorColor = Color3.fromRGB(0, 255, 0),
    killerColor = Color3.fromRGB(255, 0, 0),
    spectatorColor = Color3.fromRGB(255, 255, 255),
    healTargetColor = Color3.fromRGB(0, 255, 255),
}

-- ===========================================
-- Helper: Add Connection for Cleanup
-- ===========================================
local function addConnection(name, connection)
    if not activeConnections[name] then
        activeConnections[name] = {}
    end
    table.insert(activeConnections[name], connection)
end

local function disconnectAll(name)
    if activeConnections[name] then
        for _, conn in ipairs(activeConnections[name]) do
            if conn and conn.Connected then
                conn:Disconnect()
            end
        end
        activeConnections[name] = {}
    end
end

-- ===========================================
-- Generator ESP Functions (EVENT-BASED)
-- ===========================================
local function getGenerators()
    local generators = {}
    local map = Workspace:FindFirstChild("Map")
    
    if map then
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
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "Generator_ESP_Highlight"
    highlight.FillColor = Color3.fromRGB(255, 0, 0)
    highlight.OutlineColor = Color3.fromRGB(255, 165, 0)
    highlight.FillTransparency = ESPConfig.generatorFillTransparency
    highlight.OutlineTransparency = ESPConfig.generatorOutlineTransparency
    highlight.Parent = generator
    
    local primaryPart = generator.PrimaryPart or generator:FindFirstChildWhichIsA("BasePart")
    local attachmentPart = nil
    local billboardGui = nil
    
    if primaryPart then
        local size = primaryPart.Size
        local topOffset = size.Y / 2 + 2
        
        attachmentPart = Instance.new("Part")
        attachmentPart.Name = "TextAttachment"
        attachmentPart.Transparency = 1
        attachmentPart.CanCollide = false
        attachmentPart.Anchored = false
        attachmentPart.Size = Vector3.new(0.1, 0.1, 0.1)
        attachmentPart.CFrame = primaryPart.CFrame * CFrame.new(0, topOffset, 0)
        attachmentPart.Parent = generator
        
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = primaryPart
        weld.Part1 = attachmentPart
        weld.Parent = attachmentPart
        
        billboardGui = Instance.new("BillboardGui")
        billboardGui.Name = "GeneratorProgressESP"
        billboardGui.Adornee = attachmentPart
        billboardGui.Size = UDim2.new(0, 150, 0, 60)
        billboardGui.StudsOffset = Vector3.new(0, 0, 0)
        billboardGui.AlwaysOnTop = true
        billboardGui.Parent = attachmentPart
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
        textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = "Generator\n0%"
        textLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        textLabel.TextSize = ESPConfig.generatorTextSize
        textLabel.Font = Enum.Font.Gotham
        textLabel.TextStrokeTransparency = 0.5
        textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        textLabel.Parent = billboardGui
    end
    
    generatorESPHighlights[generator] = {
        highlight = highlight,
        attachmentPart = attachmentPart,
        billboard = billboardGui,
        textLabel = billboardGui and billboardGui:FindFirstChildOfClass("TextLabel") or nil
    }
    
    -- Initialize progress tracking
    generatorProgressTracking[generator] = {
        lastProgress = 0,
        lastTime = tick(),
        progressRate = 0
    }
    
    -- ✅ EVENT-BASED: Monitor attribute changes instead of while loop
    local attributeConnection = generator:GetAttributeChangedSignal("RepairProgress"):Connect(function()
        if not generatorESPHighlights[generator] or not generatorESPHighlightEnabled then return end
        
        local progress = generator:GetAttribute("RepairProgress") or 0
        progress = math.max(0, math.min(100, progress))
        
        -- Remove ESP when generator reaches 100% or is very close (99.5%+)
        if progress >= 99.5 then
            removeGeneratorESPHighlight(generator)
            return
        end
        
        local red = math.floor(255 * (1 - progress / 100))
        local green = math.floor(255 * (progress / 100))
        local color = Color3.fromRGB(red, green, 0)
        
        if generatorESPHighlights[generator] and generatorESPHighlights[generator].highlight then
            generatorESPHighlights[generator].highlight.FillColor = color
        end
        
        if generatorESPHighlights[generator] and generatorESPHighlights[generator].textLabel then
            -- Calculate progress rate and ETA
            local tracking = generatorProgressTracking[generator]
            if tracking then
                local currentTime = tick()
                local timeDiff = currentTime - tracking.lastTime
                local progressDiff = progress - tracking.lastProgress
                
                if timeDiff > 0.5 and progressDiff > 0 then
                    tracking.progressRate = progressDiff / timeDiff
                    tracking.lastProgress = progress
                    tracking.lastTime = currentTime
                end
                
                local displayText = string.format("Generator\n%.1f%%", progress)
                
                -- Show ETA only if generator is actively progressing
                if tracking.progressRate > 0.01 and progress < 100 then
                    local remainingProgress = 100 - progress
                    local etaSeconds = remainingProgress / tracking.progressRate
                    
                    if etaSeconds < 60 then
                        displayText = displayText .. string.format("\n~%ds", math.ceil(etaSeconds))
                    else
                        local minutes = math.floor(etaSeconds / 60)
                        local seconds = math.ceil(etaSeconds % 60)
                        displayText = displayText .. string.format("\n~%dm %ds", minutes, seconds)
                    end
                end
                
                generatorESPHighlights[generator].textLabel.Text = displayText
                generatorESPHighlights[generator].textLabel.TextColor3 = color
            end
        end
    end)
    
    -- Store connection for cleanup
    generatorESPHighlights[generator].attributeConnection = attributeConnection
    
    -- Trigger initial update
    if generator:GetAttribute("RepairProgress") then
        local progress = generator:GetAttribute("RepairProgress") or 0
        progress = math.max(0, math.min(100, progress))
        
        -- Don't create ESP if already at 100%
        if progress >= 100 then
            removeGeneratorESPHighlight(generator)
            return
        end
        
        local red = math.floor(255 * (1 - progress / 100))
        local green = math.floor(255 * (progress / 100))
        local color = Color3.fromRGB(red, green, 0)
        
        if generatorESPHighlights[generator].highlight then
            generatorESPHighlights[generator].highlight.FillColor = color
        end
        
        if generatorESPHighlights[generator].textLabel then
            generatorESPHighlights[generator].textLabel.Text = string.format("Generator\n%.1f%%", progress)
            generatorESPHighlights[generator].textLabel.TextColor3 = color
        end
    end
end

local function removeGeneratorESPHighlight(generator)
    if generatorESPHighlights[generator] then
        if generatorESPHighlights[generator].attributeConnection then
            generatorESPHighlights[generator].attributeConnection:Disconnect()
        end
        if generatorESPHighlights[generator].highlight then
            generatorESPHighlights[generator].highlight:Destroy()
        end
        if generatorESPHighlights[generator].attachmentPart then
            generatorESPHighlights[generator].attachmentPart:Destroy()
        end
        if generatorESPHighlights[generator].billboard then
            generatorESPHighlights[generator].billboard:Destroy()
        end
        generatorESPHighlights[generator] = nil
    end
    
    -- Clean up progress tracking
    if generatorProgressTracking[generator] then
        generatorProgressTracking[generator] = nil
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

-- ===========================================
-- Player ESP Functions
-- ===========================================
local function isSpectator(player)
    if not player then return false end
    return player.Team and player.Team.Name == "Spectator"
end

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
    
    local isLocalSpectator = isSpectator(Players.LocalPlayer)
    local isTargetSpectator = isSpectator(player)
    
    local highlight = nil
    -- Show ESP for Killer and Survivor (even if local player is spectator)
    if not isTargetSpectator then
        if (isKillerPlayer and killerESPEnabled) or (not isKillerPlayer and survivorESPEnabled) then
            highlight = Instance.new("Highlight")
            highlight.Name = "Player_ESP_Highlight"
            if isKillerPlayer then
                highlight.FillColor = ESPConfig.killerColor
            else
                highlight.FillColor = ESPConfig.survivorColor
            end
            highlight.FillTransparency = ESPConfig.playerFillTransparency
            highlight.OutlineTransparency = ESPConfig.playerOutlineTransparency
            highlight.Parent = character
        end
    end
    
    local attachmentPart = nil
    local billboardGui = nil
    local textLabel = nil
    
    local shouldShowBillboard = false
    
    if spectatorInfoEnabled and isTargetSpectator then
        shouldShowBillboard = true
    end
    
    -- Show billboard for Killer and Survivor (even if local player is spectator)
    if not isTargetSpectator then
        if (isKillerPlayer and killerESPEnabled) or (not isKillerPlayer and survivorESPEnabled) then
            shouldShowBillboard = true
        end
    end
    
    if shouldShowBillboard then
        attachmentPart = Instance.new("Part")
        attachmentPart.Name = "PlayerTextAttachment"
        attachmentPart.Transparency = 1
        attachmentPart.CanCollide = false
        attachmentPart.Anchored = false
        attachmentPart.Size = Vector3.new(0.1, 0.1, 0.1)
        attachmentPart.CFrame = humanoidRootPart.CFrame * CFrame.new(0, 3, 0)
        attachmentPart.Parent = character
        
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = humanoidRootPart
        weld.Part1 = attachmentPart
        weld.Parent = attachmentPart
        
        local gears = player:GetAttribute("Gears") or 0
        local screws = player:GetAttribute("Screws") or 0
        local selectedKiller = player:GetAttribute("SelectedKiller") or ""
        local equippedItem = player:GetAttribute("EquippedItem") or ""
        
        local displayText = ""
        
        if isTargetSpectator then
            local line1 = ""
            local killerPart = ""
            local itemPart = ""
            
            if selectedKiller ~= "" then
                killerPart = "[" .. selectedKiller .. "]"
            end
            
            if equippedItem ~= "" then
                itemPart = "[" .. equippedItem .. "]"
            end
            
            if killerPart ~= "" and itemPart ~= "" then
                line1 = killerPart .. " " .. itemPart
            elseif killerPart ~= "" then
                line1 = killerPart
            elseif itemPart ~= "" then
                line1 = itemPart
            end
            
            local line2 = string.format("[%d] [%d]", gears, screws)
            local line3 = player.Name
            
            if line1 ~= "" then
                displayText = line1 .. "\n" .. line2 .. "\n" .. line3
            else
                displayText = line2 .. "\n" .. line3
            end
        else
            local line1 = player.Name
            local line2 = ""
            
            if isKillerPlayer and selectedKiller ~= "" then
                line2 = "[" .. selectedKiller .. "]"
            elseif not isKillerPlayer and equippedItem ~= "" then
                line2 = "[" .. equippedItem .. "]"
            end
            
            displayText = line1
            if line2 ~= "" then
                displayText = displayText .. "\n" .. line2
            end
        end
        
        billboardGui = Instance.new("BillboardGui")
        billboardGui.Name = "PlayerNameESP"
        billboardGui.Adornee = attachmentPart
        billboardGui.Size = UDim2.new(0, 200, 0, 90)
        billboardGui.StudsOffset = Vector3.new(0, 0, 0)
        billboardGui.AlwaysOnTop = true
        billboardGui.Parent = attachmentPart
        
        textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
        textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = displayText
        
        if isTargetSpectator then
            textLabel.TextColor3 = ESPConfig.spectatorColor
        else
            if isKillerPlayer then
                textLabel.TextColor3 = ESPConfig.killerColor
            else
                textLabel.TextColor3 = ESPConfig.survivorColor
            end
        end
        
        textLabel.TextSize = ESPConfig.playerTextSize
        textLabel.Font = Enum.Font.Gotham
        textLabel.TextStrokeTransparency = 0.5
        textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        textLabel.Parent = billboardGui
    end
    
    playerESPData[player] = {
        highlight = highlight,
        attachmentPart = attachmentPart,
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
        if playerESPData[player].attachmentPart then
            playerESPData[player].attachmentPart:Destroy()
        end
        if playerESPData[player].billboard then
            playerESPData[player].billboard:Destroy()
        end
        playerESPData[player] = nil
    end
end

local function updateSpectatorInfo()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Players.LocalPlayer and player.Character then
            local isKillerPlayer = isKiller(player)
            createPlayerESP(player, isKillerPlayer)
        end
    end
end

local function updatePlayerESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Players.LocalPlayer then
            local isKillerPlayer = isKiller(player)
            local isTargetSpectator = isSpectator(player)
            
            local shouldShowESP = false
            
            if isTargetSpectator and spectatorInfoEnabled then
                shouldShowESP = true
            end
            
            if not isTargetSpectator then
                if (isKillerPlayer and killerESPEnabled) or (not isKillerPlayer and survivorESPEnabled) then
                    shouldShowESP = true
                end
            end
            
            if shouldShowESP then
                createPlayerESP(player, isKillerPlayer)
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

-- ===========================================
-- Crosshair Functions
-- ===========================================
local function createCrosshair()
    if crosshairUI then
        crosshairUI:Destroy()
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CrosshairUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local success = pcall(function()
        screenGui.Parent = CoreGui
    end)
    if not success then
        screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end
    
    local crosshairFrame = Instance.new("Frame")
    crosshairFrame.Name = "CrosshairFrame"
    crosshairFrame.Size = UDim2.new(0, 40, 0, 40)
    crosshairFrame.Position = UDim2.new(0.5, -20, 0.5, -20)
    crosshairFrame.BackgroundTransparency = 1
    crosshairFrame.Parent = screenGui
    
    local horizontalLine = Instance.new("Frame")
    horizontalLine.Name = "HorizontalLine"
    horizontalLine.Size = UDim2.new(0, 20, 0, 2)
    horizontalLine.Position = UDim2.new(0.5, -10, 0.5, -1)
    horizontalLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    horizontalLine.BorderSizePixel = 0
    horizontalLine.Parent = crosshairFrame
    
    local horizontalStroke = Instance.new("UIStroke")
    horizontalStroke.Color = Color3.fromRGB(0, 0, 0)
    horizontalStroke.Thickness = 1
    horizontalStroke.Parent = horizontalLine
    
    local verticalLine = Instance.new("Frame")
    verticalLine.Name = "VerticalLine"
    verticalLine.Size = UDim2.new(0, 2, 0, 20)
    verticalLine.Position = UDim2.new(0.5, -1, 0.5, -10)
    verticalLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    verticalLine.BorderSizePixel = 0
    verticalLine.Parent = crosshairFrame
    
    local verticalStroke = Instance.new("UIStroke")
    verticalStroke.Color = Color3.fromRGB(0, 0, 0)
    verticalStroke.Thickness = 1
    verticalStroke.Parent = verticalLine
    
    local centerDot = Instance.new("Frame")
    centerDot.Name = "CenterDot"
    centerDot.Size = UDim2.new(0, 4, 0, 4)
    centerDot.Position = UDim2.new(0.5, -2, 0.5, -2)
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
-- Speed Boost Functions (EVENT-BASED)
-- ===========================================
local function applySpeedBoost()
    local localPlayer = Players.LocalPlayer
    if not localPlayer.Character then return end
    
    local workspaceCharacter = Workspace:FindFirstChild(localPlayer.Name)
    if workspaceCharacter then
        workspaceCharacter:SetAttribute("speedboost", currentSpeedBoost)
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
    
    -- ✅ IMPROVED: Use GetAttributeChangedSignal to detect if speedboost gets reset
    local function monitorSpeedBoost()
        local workspaceChar = Workspace:FindFirstChild(Players.LocalPlayer.Name)
        if workspaceChar then
            local conn = workspaceChar:GetAttributeChangedSignal("speedboost"):Connect(function()
                if speedBoostEnabled then
                    local currentValue = workspaceChar:GetAttribute("speedboost")
                    if currentValue ~= currentSpeedBoost then
                        task.wait(0.1)
                        applySpeedBoost()
                    end
                end
            end)
            addConnection("speedboost", conn)
        end
    end
    
    monitorSpeedBoost()
    
    -- Monitor for new character
    local charConn = Players.LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        monitorSpeedBoost()
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
    
    local localPlayer = Players.LocalPlayer
    if localPlayer.Character then
        local workspaceCharacter = Workspace:FindFirstChild(localPlayer.Name)
        if workspaceCharacter then
            workspaceCharacter:SetAttribute("speedboost", 1)
        end
        
        local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:SetAttribute("speedboost", 1)
        end
    end
end

local function updateSpeedBoost(newValue)
    currentSpeedBoost = math.clamp(newValue, 1, 2)
    if speedBoostEnabled then
        applySpeedBoost()
    end
end

-- ===========================================
-- Auto Perfect Skill Check Functions
-- ===========================================
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
    
    local lineRotation = line.Rotation
    local goalRotation = goal.Rotation
    
    if goalRotation == 0 or lineRotation == 0 then
        if lastSkillCheckActive then
            pressedThisRound = false
            lastGoalRotationTracked = 0
            lastSkillCheckActive = false
        end
        return
    end
    
    if not lastSkillCheckActive then
        lastSkillCheckActive = true
        pressedThisRound = false
        lastGoalRotationTracked = goalRotation
    end
    
    if math.abs(goalRotation - lastGoalRotationTracked) > 10 then
        pressedThisRound = false
        lastGoalRotationTracked = goalRotation
    end
    
    local function normalizeRotation(rot)
        while rot < 0 do rot = rot + 360 end
        while rot >= 360 do rot = rot - 360 end
        return rot
    end
    
    lineRotation = normalizeRotation(lineRotation)
    goalRotation = normalizeRotation(goalRotation)
    
    local diff = lineRotation - goalRotation
    
    while diff > 180 do diff = diff - 360 end
    while diff < -180 do diff = diff + 360 end
    
    local offsetMin = 103
    local offsetMax = 115
    
    local inPerfectZone = (diff >= offsetMin and diff <= offsetMax)
    
    if inPerfectZone and not pressedThisRound then
        local currentTime = tick()
        if currentTime - lastPressTime >= 0.05 then
            task.wait(0.02)
            
            -- Support both keyboard and mobile touch
            local virtualInputManager = game:GetService("VirtualInputManager")
            
            -- Send keyboard Space event (for PC)
            virtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.01)
            virtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            
            -- Also trigger touch event for mobile
            pcall(function()
                local screenGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
                if screenGui then
                    local skillCheckGui = screenGui:FindFirstChild("SkillCheckPromptGui")
                    if skillCheckGui then
                        local check = skillCheckGui:FindFirstChild("Check")
                        if check then
                            -- Simulate touch tap at center of screen
                            local viewportSize = workspace.CurrentCamera.ViewportSize
                            local centerPos = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
                            
                            virtualInputManager:SendTouchEvent(Enum.UserInputType.Touch, Enum.UserInputState.Begin, centerPos)
                            task.wait(0.01)
                            virtualInputManager:SendTouchEvent(Enum.UserInputType.Touch, Enum.UserInputState.End, centerPos)
                        end
                    end
                end
            end)
            
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

-- ===========================================
-- Disable Skill Check Functions (EVENT-BASED)
-- ===========================================
local function setupSkillCheckDisabler(workspaceChar)
    if not workspaceChar then return end
    
    local function disableSkillCheckObject(skillCheck)
        if not skillCheck then return end
        skillCheck:SetAttribute("Disabled", true)
        skillCheck:SetAttribute("Enabled", false)
        
        -- ✅ EVENT-BASED: Monitor if attributes get changed back
        local conn1 = skillCheck:GetAttributeChangedSignal("Disabled"):Connect(function()
            if disableSkillCheckEnabled then
                if not skillCheck:GetAttribute("Disabled") then
                    skillCheck:SetAttribute("Disabled", true)
                end
            end
        end)
        
        local conn2 = skillCheck:GetAttributeChangedSignal("Enabled"):Connect(function()
            if disableSkillCheckEnabled then
                if skillCheck:GetAttribute("Enabled") then
                    skillCheck:SetAttribute("Enabled", false)
                end
            end
        end)
        
        table.insert(skillCheckConnections, conn1)
        table.insert(skillCheckConnections, conn2)
    end
    
    local skillCheckGen = workspaceChar:FindFirstChild("Skillcheck-gen")
    local skillCheckPlayer = workspaceChar:FindFirstChild("Skillcheck-player")
    
    if skillCheckGen then
        disableSkillCheckObject(skillCheckGen)
    end
    
    if skillCheckPlayer then
        disableSkillCheckObject(skillCheckPlayer)
    end
    
    -- ✅ EVENT-BASED: Monitor for new skill check objects
    local conn = workspaceChar.ChildAdded:Connect(function(child)
        if disableSkillCheckEnabled then
            if child.Name == "Skillcheck-gen" or child.Name == "Skillcheck-player" then
                task.wait(0.1)
                disableSkillCheckObject(child)
            end
        end
    end)
    
    table.insert(skillCheckConnections, conn)
end

local function enableDisableSkillCheck()
    disableSkillCheckEnabled = true
    
    if autoPerfectEnabled then
        disableAutoPerfect()
    end
    
    local localPlayer = Players.LocalPlayer
    if localPlayer.Character then
        local workspaceChar = Workspace:FindFirstChild(localPlayer.Name)
        if workspaceChar then
            setupSkillCheckDisabler(workspaceChar)
        end
    end
    
    -- ✅ Setup on character respawn
    local conn = localPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        if disableSkillCheckEnabled then
            local workspaceChar = Workspace:FindFirstChild(localPlayer.Name)
            if workspaceChar then
                setupSkillCheckDisabler(workspaceChar)
            end
        end
    end)
    
    table.insert(skillCheckConnections, conn)
end

local function disableDisableSkillCheck()
    disableSkillCheckEnabled = false
    
    -- Disconnect all monitoring connections
    for _, conn in ipairs(skillCheckConnections) do
        if conn and conn.Connected then
            conn:Disconnect()
        end
    end
    skillCheckConnections = {}
    
    -- Re-enable skill checks
    local localPlayer = Players.LocalPlayer
    if localPlayer.Character then
        local workspaceChar = Workspace:FindFirstChild(localPlayer.Name)
        if workspaceChar then
            local skillCheckGen = workspaceChar:FindFirstChild("Skillcheck-gen")
            if skillCheckGen then
                skillCheckGen:SetAttribute("Disabled", false)
                skillCheckGen:SetAttribute("Enabled", true)
            end
            
            local skillCheckPlayer = workspaceChar:FindFirstChild("Skillcheck-player")
            if skillCheckPlayer then
                skillCheckPlayer:SetAttribute("Disabled", false)
                skillCheckPlayer:SetAttribute("Enabled", true)
            end
        end
    end
end

-- ===========================================
-- Aimbot Functions
-- ===========================================
local function hasFlashlightEquipped()
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return false end
    
    local equippedItem = localPlayer:GetAttribute("EquippedItem")
    return equippedItem == "Flashlight"
end

local function getKillerTarget()
    local localPlayer = Players.LocalPlayer
    if not localPlayer or not localPlayer.Character then return nil end
    
    local closestKiller = nil
    local closestDistance = math.huge
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and isKiller(player) and player.Character then
            local killerRoot = player.Character:FindFirstChild("HumanoidRootPart")
            local localRoot = localPlayer.Character:FindFirstChild("HumanoidRootPart")
            
            if killerRoot and localRoot then
                local distance = (killerRoot.Position - localRoot.Position).Magnitude
                if distance < closestDistance then
                    closestDistance = distance
                    closestKiller = player
                end
            end
        end
    end
    
    return closestKiller
end

local function aimAtKiller()
    if not aimbotEnabled or not isRightClickHeld then return end
    if not hasFlashlightEquipped() then return end
    
    local localPlayer = Players.LocalPlayer
    if not localPlayer or not localPlayer.Character then return end
    
    local killer = getKillerTarget()
    if not killer or not killer.Character then return end
    
    local killerRoot = killer.Character:FindFirstChild("HumanoidRootPart")
    local killerHead = killer.Character:FindFirstChild("Head")
    if not killerRoot and not killerHead then return end
    
    local camera = Workspace.CurrentCamera
    local targetPosition = killerHead and killerHead.Position or killerRoot.Position
    
    local currentCFrame = camera.CFrame
    local targetCFrame = CFrame.new(camera.CFrame.Position, targetPosition)
    
    local lerpFactor = 0.3
    local newCFrame = currentCFrame:Lerp(targetCFrame, lerpFactor)
    
    camera.CFrame = newCFrame
end

local function enableAimbot()
    aimbotEnabled = true
    
    if aimbotConnection then
        aimbotConnection:Disconnect()
    end
    
    aimbotConnection = RunService.RenderStepped:Connect(function()
        if aimbotEnabled and isRightClickHeld then
            pcall(aimAtKiller)
        end
    end)
end

local function disableAimbot()
    aimbotEnabled = false
    
    if aimbotConnection then
        aimbotConnection:Disconnect()
        aimbotConnection = nil
    end
end

-- ===========================================
-- Long Range Heal Functions
-- ===========================================
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
    highlight.FillColor = ESPConfig.healTargetColor
    highlight.FillTransparency = ESPConfig.playerFillTransparency
    highlight.OutlineTransparency = ESPConfig.playerOutlineTransparency
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
    local maxAngle = 15
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character then
            if not isKiller(player) then
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
        local args = { humanoidRootPart, true }
        ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Healing"):WaitForChild("HealEvent"):FireServer(unpack(args))
    end)
    
    removeHealTargetESP()
    healTarget = nil
end



-- ===========================================
-- Auto Monitor ESP Functions (EVENT-BASED)
-- ===========================================
local lastMapInstance = nil

local function setupAutoMonitor()
    -- ✅ EVENT-BASED: Monitor map changes using ChildAdded/ChildRemoved
    local mapConnection = Workspace.ChildAdded:Connect(function(child)
        if child.Name == "Map" then
            lastMapInstance = child
            
            -- Wait for map to fully load, then scan for existing generators
            task.wait(1)
            if generatorESPHighlightEnabled then
                enableGeneratorESPHighlight()
            end
            
            -- ✅ Monitor generators being added to map (dynamic)
            local genConn = child.DescendantAdded:Connect(function(descendant)
                if descendant:IsA("Model") and descendant.Name == "Generator" then
                    task.wait(0.1)
                    if generatorESPHighlightEnabled and not generatorESPHighlights[descendant] then
                        createGeneratorESPHighlight(descendant)
                    end
                end
            end)
            addConnection("autorefresh", genConn)
        end
    end)
    addConnection("autorefresh", mapConnection)
    
    local mapRemoveConnection = Workspace.ChildRemoved:Connect(function(child)
        if child.Name == "Map" and child == lastMapInstance then
            lastMapInstance = nil
            -- Clean up ESP when map is removed
            disableGeneratorESPHighlight()
        end
    end)
    addConnection("autorefresh", mapRemoveConnection)
    
    -- ✅ EVENT-BASED: Monitor player ESP validity
    local function setupPlayerMonitoring()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= Players.LocalPlayer then
                -- Monitor character added
                local charConn = player.CharacterAdded:Connect(function(character)
                    task.wait(0.5)
                    
                    local anyFeatureEnabled = survivorESPEnabled or killerESPEnabled or spectatorInfoEnabled
                    
                    if anyFeatureEnabled then
                        local isKillerPlayer = isKiller(player)
                        removePlayerESP(player)
                        
                        local isTargetSpectator = isSpectator(player)
                        local shouldShow = false
                        
                        if isTargetSpectator and spectatorInfoEnabled then
                            shouldShow = true
                        end
                        
                        if not isTargetSpectator then
                            local shouldShowESP = (isKillerPlayer and killerESPEnabled) or (not isKillerPlayer and survivorESPEnabled)
                            if shouldShowESP then
                                shouldShow = true
                            end
                        end
                        
                        if shouldShow then
                            createPlayerESP(player, isKillerPlayer)
                        end
                    end
                end)
                addConnection("autorefresh", charConn)
                
                -- Monitor character removing
                local charRemoveConn = player.CharacterRemoving:Connect(function()
                    removePlayerESP(player)
                end)
                addConnection("autorefresh", charRemoveConn)
            end
        end
    end
    
    setupPlayerMonitoring()
    
    -- ✅ EVENT-BASED: Monitor new players joining
    local playerAddedConn = Players.PlayerAdded:Connect(function(player)
        task.wait(1)
        
        local charConn = player.CharacterAdded:Connect(function(character)
            task.wait(0.5)
            
            local anyFeatureEnabled = survivorESPEnabled or killerESPEnabled or spectatorInfoEnabled
            
            if anyFeatureEnabled then
                local isKillerPlayer = isKiller(player)
                removePlayerESP(player)
                
                local isTargetSpectator = isSpectator(player)
                local shouldShow = false
                
                if isTargetSpectator and spectatorInfoEnabled then
                    shouldShow = true
                end
                
                if not isTargetSpectator then
                    local shouldShowESP = (isKillerPlayer and killerESPEnabled) or (not isKillerPlayer and survivorESPEnabled)
                    if shouldShowESP then
                        shouldShow = true
                    end
                end
                
                if shouldShow then
                    createPlayerESP(player, isKillerPlayer)
                end
            end
        end)
        addConnection("autorefresh", charConn)
        
        local anyFeatureEnabled = survivorESPEnabled or killerESPEnabled or spectatorInfoEnabled
        if anyFeatureEnabled then
            updatePlayerESP()
        end
    end)
    addConnection("autorefresh", playerAddedConn)
    
    -- ✅ EVENT-BASED: Monitor players leaving
    local playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
        removePlayerESP(player)
    end)
    addConnection("autorefresh", playerRemovingConn)
    
    -- ✅ EVENT-BASED: Monitor local player team changes
    local function monitorLocalTeamChange()
        local localPlayer = Players.LocalPlayer
        if localPlayer then
            local lastTeam = localPlayer.Team
            
            local teamConn = localPlayer:GetPropertyChangedSignal("Team"):Connect(function()
                local currentTeam = localPlayer.Team
                if currentTeam ~= lastTeam then
                    lastTeam = currentTeam
                    if spectatorInfoEnabled then
                        task.wait(0.5)
                        updateSpectatorInfo()
                    end
                end
            end)
            addConnection("autorefresh", teamConn)
        end
    end
    
    monitorLocalTeamChange()
end

-- ===========================================
-- UI Sync Function
-- ===========================================
local function syncUI()
    if generatorHighlightToggle then pcall(function() generatorHighlightToggle:Set(generatorESPHighlightEnabled) end) end
    if survivorESPToggle then pcall(function() survivorESPToggle:Set(survivorESPEnabled) end) end
    if killerESPToggle then pcall(function() killerESPToggle:Set(killerESPEnabled) end) end
end

-- ===========================================
-- UI Window
-- ===========================================
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

-- ===========================================
-- Tab: ESP
-- ===========================================
local ESPTab = Window:Tab({
    Title = "ESP",
    Icon = "eye",
})

-- ===========================================
-- Object ESP Section
-- ===========================================
ESPTab:Section({
    Title = "Object ESP",
})

generatorHighlightToggle = ESPTab:Toggle({
    Title = "Generator ESP",
    Desc = "Show ESP on generators with progress",
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

ESPTab:Slider({
    Title = "Generator Transparency",
    Desc = "Adjust generator highlight transparency",
    Step = 0.05,
    Value = {
        Min = 0,
        Max = 1,
        Default = 0.75,
    },
    Callback = function(value)
        ESPConfig.generatorFillTransparency = value
        -- Update existing highlights
        for generator, data in pairs(generatorESPHighlights) do
            if data.highlight then
                data.highlight.FillTransparency = value
            end
        end
    end
})

-- ===========================================
-- Player ESP Section
-- ===========================================
ESPTab:Section({
    Title = "Player ESP",
})

survivorESPToggle = ESPTab:Toggle({
    Title = "Survivor ESP",
    Desc = "Show ESP for survivors with info",
    Icon = "user",
    Value = false,
    Callback = function(state)
        survivorESPEnabled = state
        updatePlayerESP()
    end
})

killerESPToggle = ESPTab:Toggle({
    Title = "Killer ESP",
    Desc = "Show ESP for killer with info",
    Icon = "user-x",
    Value = false,
    Callback = function(state)
        killerESPEnabled = state
        updatePlayerESP()
    end
})

ESPTab:Toggle({
    Title = "Spectator Info",
    Desc = "Show detailed info for lobby players",
    Icon = "info",
    Value = false,
    Callback = function(state)
        spectatorInfoEnabled = state
        updateSpectatorInfo()
    end
})

ESPTab:Slider({
    Title = "Player Transparency",
    Desc = "Adjust player highlight transparency",
    Step = 0.05,
    Value = {
        Min = 0,
        Max = 1,
        Default = 0.75,
    },
    Callback = function(value)
        ESPConfig.playerFillTransparency = value
        for player, data in pairs(playerESPData) do
            if data.highlight then
                data.highlight.FillTransparency = value
            end
        end
    end
})

-- ===========================================
-- ESP Actions Section
-- ===========================================
ESPTab:Section({
    Title = "Quick Actions",
})

ESPTab:Button({
    Title = "Enable All ESP",
    Desc = "Turn on all ESP features at once",
    Icon = "eye",
    Callback = function()
        generatorESPHighlightEnabled = true
        enableGeneratorESPHighlight()
        
        survivorESPEnabled = true
        killerESPEnabled = true
        updatePlayerESP()
        
        syncUI()
        
        WindUI:Notify({
            Title = "ESP Enabled",
            Content = "All ESP features are now active",
            Duration = 2
        })
    end
})

ESPTab:Button({
    Title = "Disable All ESP",
    Desc = "Turn off all ESP features at once",
    Icon = "eye-off",
    Callback = function()
        if generatorESPHighlightEnabled then
            generatorESPHighlightEnabled = false
            disableGeneratorESPHighlight()
        end
        
        if survivorESPEnabled then
            survivorESPEnabled = false
        end
        
        if killerESPEnabled then
            killerESPEnabled = false
        end
        
        spectatorInfoEnabled = false
        
        disableAllPlayerESP()
        syncUI()
        
        WindUI:Notify({
            Title = "ESP Disabled",
            Content = "All ESP features have been turned off",
            Duration = 2
        })
    end
})

-- ===========================================
-- Crosshair Section
-- ===========================================
ESPTab:Section({
    Title = "Crosshair",
})

ESPTab:Toggle({
    Title = "Show Crosshair",
    Desc = "Display custom crosshair in center of screen",
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

-- ===========================================
-- Tab: Survivor
-- ===========================================
local SurvivorTab = Window:Tab({
    Title = "Survivor",
    Icon = "heart",
})

SurvivorTab:Section({
    Title = "Speed Boost",
})

SurvivorTab:Toggle({
    Title = "Enable Speed Boost",
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
    Title = "Speed Multiplier",
    Desc = "Set speed boost multiplier",
    Step = 0.01,
    Value = {
        Min = 1,
        Max = 2,
        Default = 1.1,
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
    Title = "Disable Skill Check",
    Desc = "Remove skill check prompts completely",
    Value = false,
    Callback = function(state)
        if state then
            enableDisableSkillCheck()
        else
            disableDisableSkillCheck()
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
                    local args = { humanoidRootPart, false }
                    ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Healing"):WaitForChild("HealEvent"):FireServer(unpack(args))
                end)
            end
        end
        healTarget = nil
        removeHealTargetESP()
    end
})

SurvivorTab:Section({
    Title = "Aimbot (Flashlight)",
})

SurvivorTab:Toggle({
    Title = "Enable Aimbot",
    Desc = "Hold right-click to aim at killer (Flashlight required)",
    Icon = "target",
    Value = false,
    Callback = function(state)
        if state then
            enableAimbot()
        else
            disableAimbot()
            isRightClickHeld = false
        end
    end
})

-- ===========================================
-- Tab: Server
-- ===========================================
local ServerTab = Window:Tab({
    Title = "Server",
    Icon = "globe",
})

ServerTab:Section({
    Title = "Server Controls",
})

ServerTab:Button({
    Title = "Server Hop",
    Desc = "Join a different server",
    Icon = "refresh-cw",
    Callback = function()
        local TeleportService = game:GetService("TeleportService")
        local Players = game:GetService("Players")
        local HttpService = game:GetService("HttpService")
        
        local placeId = game.PlaceId
        local jobId = game.JobId
        
        local success, result = pcall(function()
            local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"))
            
            local serverList = {}
            for _, server in pairs(servers.data) do
                if server.id ~= jobId and server.playing < server.maxPlayers then
                    table.insert(serverList, server)
                end
            end
            
            if #serverList > 0 then
                local randomServer = serverList[math.random(1, #serverList)]
                TeleportService:TeleportToPlaceInstance(placeId, randomServer.id, Players.LocalPlayer)
            else
                WindUI:Notify({
                    Title = "Server Hop",
                    Content = "No available servers found",
                    Duration = 3
                })
            end
        end)
        
        if not success then
            WindUI:Notify({
                Title = "Server Hop",
                Content = "Failed to server hop: " .. tostring(result),
                Duration = 3
            })
        end
    end
})

ServerTab:Button({
    Title = "Rejoin Server",
    Desc = "Rejoin current server",
    Icon = "rotate-ccw",
    Callback = function()
        local TeleportService = game:GetService("TeleportService")
        local Players = game:GetService("Players")
        
        local success, result = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Players.LocalPlayer)
        end)
        
        if not success then
            WindUI:Notify({
                Title = "Rejoin Server",
                Content = "Failed to rejoin: " .. tostring(result),
                Duration = 3
            })
        end
    end
})

-- ===========================================
-- Event Listeners
-- ===========================================
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

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == healKeybind and longRangeHealEnabled and healTarget then
        processHeal()
    end
    
    if input.UserInputType == Enum.UserInputType.MouseButton2 and aimbotEnabled then
        isRightClickHeld = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        isRightClickHeld = false
    end
end)

RunService.Heartbeat:Connect(function()
    local anyFeatureEnabled = survivorESPEnabled or killerESPEnabled or spectatorInfoEnabled
    
    if anyFeatureEnabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= Players.LocalPlayer and player.Character then
                local isKillerPlayer = isKiller(player)
                local isTargetSpectator = isSpectator(player)
                local hasESP = playerESPData[player] ~= nil
                
                local shouldShow = false
                
                if isTargetSpectator and spectatorInfoEnabled then
                    shouldShow = true
                end
                
                if not isTargetSpectator then
                    local shouldShowESP = (isKillerPlayer and killerESPEnabled) or (not isKillerPlayer and survivorESPEnabled)
                    if shouldShowESP then
                        shouldShow = true
                    end
                end
                
                if shouldShow and not hasESP then
                    createPlayerESP(player, isKillerPlayer)
                elseif hasESP and not shouldShow then
                    removePlayerESP(player)
                end
            end
        end
    else
        for player, _ in pairs(playerESPData) do
            removePlayerESP(player)
        end
    end
end)

setupAutoMonitor()

-- ===========================================
-- Cleanup on Window Destroy
-- ===========================================
Window:OnDestroy(function()
    if generatorESPHighlightEnabled then
        generatorESPHighlightEnabled = false
        disableGeneratorESPHighlight()
    end
    
    if survivorESPEnabled then
        survivorESPEnabled = false
    end
    
    if killerESPEnabled then
        killerESPEnabled = false
    end

    if crosshairEnabled then
        disableCrosshair()
    end
    
    disableAllPlayerESP()
    
    if speedBoostEnabled then
        disableSpeedBoost()
    end
    
    if autoPerfectEnabled then
        disableAutoPerfect()
    end
    
    if disableSkillCheckEnabled then
        disableDisableSkillCheck()
    end
    
    if longRangeHealEnabled then
        longRangeHealEnabled = false
        healTarget = nil
        removeHealTargetESP()
    end
    
    if aimbotEnabled then
        disableAimbot()
        isRightClickHeld = false
    end
    
    autoRefreshEnabled = false
    
    -- Disconnect all connections
    for category, _ in pairs(activeConnections) do
        disconnectAll(category)
    end
    
    print("VD Helper: All features disabled and cleaned up")
end)
