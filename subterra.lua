-- [[ SUBTERRA PREMIUM CHEAT SCRIPT - FLUID ANDROID UI ]]
-- Updated by Antigravity for user iRyck1308
-- Supported OS: Android / PC (Fluent UI with Draggable Toggle Button)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")

local localPlayer = Players.LocalPlayer
local char = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local hum = char:WaitForChild("Humanoid")

-- Cleanup existing UI to prevent stacking
local oldGui = CoreGui:FindFirstChild("SubterraToggleGui")
if oldGui then
    oldGui:Destroy()
end

--PlayerData setup
local playerData = ReplicatedStorage:WaitForChild("playerData"):WaitForChild(tostring(localPlayer.UserId))

-- Module requiring
local chunkHandlerClient = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("chunkHandlerClient"))
local BufferEncoder = require(ReplicatedStorage.Shared:WaitForChild("BufferEncoder"))
local SharedUtils = require(ReplicatedStorage.Shared:WaitForChild("SharedUtils"))
local InventoryHandler = require(ReplicatedStorage.Shared:WaitForChild("InventoryHandler")).new()

-- Remotes
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local damageBlock = remotes:WaitForChild("Chunks"):WaitForChild("damageBlock")
local holdItem = remotes:WaitForChild("Player"):WaitForChild("holdItem")
local sellRemote = remotes:WaitForChild("NPCStore"):WaitForChild("Sell")
local upgradePickaxeRemote = remotes:WaitForChild("Blacksmith"):WaitForChild("UpgradePickaxe")
local upgradeBackpackRemote = remotes:WaitForChild("Backpack"):WaitForChild("UpgradeBackpack")

-- UI Library initialization
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Window = Fluent:CreateWindow({
    Title = "Subterra ⛏️",
    SubTitle = "Steamy By iRyck1308",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "home" }),
    AutoFarm = Window:AddTab({ Title = "Auto Farm", Icon = "hammer" }),
    AutoUpgrade = Window:AddTab({ Title = "Auto Upgrade", Icon = "settings" }),
    AutoSell = Window:AddTab({ Title = "Auto Sell", Icon = "shopping-cart" }),
    ESP = Window:AddTab({ Title = "ESP", Icon = "eye" })
}

-- System states
local wsEnabled = false
local wsValue = 16
local noclipEnabled = false
local infJumpEnabled = false

local autoFarmOresEnabled = false
local autoFarmMobsEnabled = false
local pickLevelCheckEnabled = false
local backpackCapCheckEnabled = false

local autoUpgradePickaxeEnabled = false
local autoUpgradeBackpackEnabled = false

local autoSellEnabled = false
local autoSellAllEnabled = false

local mobESPEnabled = false
local oreESPEnabled = false

local selectedOres = {}
local selectedSellItems = {}
local selectedMob = ""
local targetTeleportPlayer = ""

local selectedESPOres = {}
local selectedESPMobs = {}

-- Floating Toggle Button for Android
local toggleGui = Instance.new("ScreenGui")
toggleGui.Name = "SubterraToggleGui"
toggleGui.ResetOnSpawn = false
toggleGui.Parent = CoreGui

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.new(0, 60, 0, 60)
toggleButton.Position = UDim2.new(0, 15, 0, 200)
toggleButton.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.TextSize = 14
toggleButton.Text = "Menu"
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.Parent = toggleGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.5, 0)
corner.Parent = toggleButton

local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(255, 133, 34)
stroke.Parent = toggleButton

-- Make Toggle Button Draggable
local dragging = false
local dragInput, dragStart, startPos

local function updateDrag(input)
    local delta = input.Position - dragStart
    toggleButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

toggleButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = toggleButton.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

toggleButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        updateDrag(input)
    end
end)

toggleButton.MouseButton1Click:Connect(function()
    Window:Minimize()
end)

-- Main features: WalkSpeed, NoClip, InfJump, Player Teleport
Tabs.Main:AddSlider("WalkSpeedSlider", {
    Title = "WalkSpeed",
    Description = "Atur kecepatan berjalan karakter",
    Min = 16,
    Max = 150,
    Default = 16,
    Rounding = 0,
    Callback = function(Value)
        wsValue = Value
    end
})

Tabs.Main:AddToggle("WalkSpeedToggle", {
    Title = "Enable WalkSpeed",
    Default = false,
    Callback = function(Value)
        wsEnabled = Value
    end
})

Tabs.Main:AddToggle("NoClipToggle", {
    Title = "No Clip",
    Default = false,
    Callback = function(Value)
        noclipEnabled = Value
    end
})

Tabs.Main:AddToggle("InfJumpToggle", {
    Title = "Infinite Jump",
    Default = false,
    Callback = function(Value)
        infJumpEnabled = Value
    end
})

-- Player Teleport Setup
local function getPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer then
            table.insert(names, p.Name)
        end
    end
    return names
end

local PlayerDropdown = Tabs.Main:AddDropdown("PlayerTeleportDropdown", {
    Title = "Pilih Pemain untuk Teleport",
    Description = "Pilih pemain tujuan teleportasi",
    Values = getPlayerNames(),
    Default = "",
    Callback = function(Value)
        targetTeleportPlayer = Value
    end
})

Tabs.Main:AddButton({
    Title = "Teleport ke Pemain",
    Description = "Teleport langsung ke pemain yang dipilih",
    Callback = function()
        if targetTeleportPlayer ~= "" then
            local target = Players:FindFirstChild(targetTeleportPlayer)
            local targetChar = target and target.Character
            local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
            local myChar = localPlayer.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if targetHrp and myHrp then
                myHrp.CFrame = targetHrp.CFrame
            else
                Fluent:Notify({
                    Title = "Teleport",
                    Content = "Gagal menemukan target pemain atau karakter Anda!",
                    Duration = 3
                })
            end
        else
            Fluent:Notify({
                Title = "Teleport",
                Content = "Silakan pilih pemain terlebih dahulu!",
                Duration = 3
            })
        end
    end
})

local function updatePlayersList()
    PlayerDropdown:SetValues(getPlayerNames())
end

Players.PlayerAdded:Connect(updatePlayersList)
Players.PlayerRemoving:Connect(updatePlayersList)

RunService.Heartbeat:Connect(function()
    pcall(function()
        local c = localPlayer.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h and wsEnabled then
            h.WalkSpeed = wsValue
        end
    end)
end)

RunService.Stepped:Connect(function()
    if noclipEnabled then
        pcall(function()
            local c = localPlayer.Character
            if c then
                for _, part in ipairs(c:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end
end)

UserInputService.JumpRequest:Connect(function()
    if infJumpEnabled then
        pcall(function()
            local c = localPlayer.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            if h then
                h:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    end
end)

-- Helper Functions: Equip items
local function equipPickaxe()
    local c = localPlayer.Character
    if c then
        -- Cek apakah sudah equipped pickaxe (cek nama mengandung "Pickaxe" case-insensitive)
        local equipped = c:FindFirstChildOfClass("Tool")
        if equipped and equipped.Name:lower():find("pickaxe") then
            return true
        end
    end
    -- Cari di Hotbar
    for _, slot in ipairs(playerData.Hotbar:GetChildren()) do
        local slotVal = slot.Value or ""
        if slotVal:lower():find("pickaxe") then
            holdItem:FireServer(slot)
            task.wait(0.5)
            return true
        end
    end
    -- Fallback: cari di Inventory
    for _, v in ipairs(playerData.Inventory:GetChildren()) do
        if v.Name:lower():find("pickaxe") then
            -- Cari slot kosong / slot pertama
            local slots = playerData.Hotbar:GetChildren()
            if slots[1] then
                holdItem:FireServer(slots[1])
                task.wait(0.5)
                return true
            end
        end
    end
    return false
end

local function equipWeapon()
    local c = localPlayer.Character
    -- Cek sudah equipped weapon (bukan pickaxe, punya ToolRemote)
    local equippedTool = c and c:FindFirstChildOfClass("Tool")
    if equippedTool and not equippedTool.Name:lower():find("pickaxe") and equippedTool:FindFirstChild("ToolRemote") then
        return true
    end
    -- Cari weapon di Hotbar
    for _, slot in ipairs(playerData.Hotbar:GetChildren()) do
        local slotVal = slot.Value or ""
        if slotVal ~= "" and not slotVal:lower():find("pickaxe") then
            -- Cek via SharedUtils apakah weapon
            local itemInfo = pcall(function() return SharedUtils.getItemInfo(slotVal) end) and SharedUtils.getItemInfo(slotVal)
            if itemInfo and itemInfo._Type == "Weapon" then
                holdItem:FireServer(slot)
                task.wait(0.5)
                return true
            end
        end
    end
    -- Fallback: equip tool apapun yang punya ToolRemote (sword, dll)
    for _, slot in ipairs(playerData.Hotbar:GetChildren()) do
        local slotVal = slot.Value or ""
        if slotVal ~= "" and not slotVal:lower():find("pickaxe") then
            holdItem:FireServer(slot)
            task.wait(0.5)
            local myC = localPlayer.Character
            local tool = myC and myC:FindFirstChildOfClass("Tool")
            if tool and tool:FindFirstChild("ToolRemote") then
                return true
            end
        end
    end
    return false
end

-- Auto Sell Logic (With temporary Sell NPC teleport)
local function runAutoSell()
    local myChar = localPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local sellFocus = workspace.NPCs:FindFirstChild("SellFocus")
    if not myHrp or not sellFocus then return end
    
    local originalCF = myHrp.CFrame
    
    -- Teleport to NPC to bypass server-side distance check
    myHrp.CFrame = sellFocus.CFrame
    task.wait(0.35)
    
    local inventory = playerData.Inventory
    local soldAny = false
    for _, v in ipairs(inventory:GetChildren()) do
        if v:IsA("StringValue") and v.Name ~= "Pickaxe" then
            local success, data = pcall(function()
                return HttpService:JSONDecode(v.Value)
            end)
            if success and data and data.lock ~= true then
                local shouldSell = false
                if autoSellAllEnabled then
                    shouldSell = true
                elseif autoSellEnabled and selectedSellItems[v.Name] then
                    shouldSell = true
                end
                
                if shouldSell then
                    sellRemote:FireServer(v, data.Stack or 1)
                    soldAny = true
                    task.wait(0.08)
                end
            end
        end
    end
    
    if soldAny then
        task.wait(0.4)
    end
    
    -- Teleport back to mining/previous position
    myHrp.CFrame = originalCF
end

-- Auto Farm Ores & Mobs dropdowns
local oreList = {
    "CoalOre", "CopperOre", "TinOre", "IronOre", "SilverOre", "GoldOre", 
    "AmethystOre", "CitrineOre", "TopazOre", "SapphireOre", "RubyOre", 
    "EmeraldOre", "DiamondOre", "PlatinumOre", "TitaniumOre", "WolframiteOre", 
    "CobaltOre", "AzuriteOre", "MoonstoneOre", "SunstoneOre", "NocturniteOre", 
    "NiveliumOre", "EiskronOre", "BlackDiamondOre", "AuroraliteOre", "AquamarineOre"
}

Tabs.AutoFarm:AddToggle("AutoFarmOresToggle", {
    Title = "Auto Farm Ores",
    Default = false,
    Callback = function(Value)
        autoFarmOresEnabled = Value
    end
})

Tabs.AutoFarm:AddToggle("ReqPickaxeUpgradeToggle", {
    Title = "Require Pickaxe Upgrade",
    Description = "Lewati ore jika level pickaxe tidak mencukupi",
    Default = false,
    Callback = function(Value)
        pickLevelCheckEnabled = Value
    end
})

Tabs.AutoFarm:AddToggle("ReqBackpackCapToggle", {
    Title = "Require Backpack Upgrade / Stop when Full",
    Default = false,
    Callback = function(Value)
        backpackCapCheckEnabled = Value
    end
})

local OreDropdown = Tabs.AutoFarm:AddDropdown("OreDropdown", {
    Title = "Select Ores to Farm",
    Values = oreList,
    Multi = true,
    Default = {},
    Callback = function(Value)
        table.clear(selectedOres)
        if type(Value) == "table" then
            for k, v in pairs(Value) do
                if v == true then
                    selectedOres[k] = true
                elseif type(k) == "number" and type(v) == "string" then
                    selectedOres[v] = true
                end
            end
        end
    end
})

Tabs.AutoFarm:AddToggle("AutoFarmMobsToggle", {
    Title = "Auto Farm Mobs (Kill Mobs)",
    Default = false,
    Callback = function(Value)
        autoFarmMobsEnabled = Value
    end
})

local MobDropdown = Tabs.AutoFarm:AddDropdown("MobDropdown", {
    Title = "Select Mob to Farm",
    Values = {
        "Skeleton", "Zombie", "Slime", "Lava Slime", "Breathtaker", 
        "SkeletonPermafrost", "SkeletonDarkstone", "SkeletonDarkstoneMage", 
        "ZombieDarkstone", "ZombiePermafrost"
    },
    Default = "",
    Callback = function(Value)
        selectedMob = Value
    end
})

-- Auto Upgrade Tab
Tabs.AutoUpgrade:AddToggle("AutoUpgradePickaxeToggle", {
    Title = "Auto Upgrade Pickaxe",
    Default = false,
    Callback = function(Value)
        autoUpgradePickaxeEnabled = Value
    end
})

Tabs.AutoUpgrade:AddToggle("AutoUpgradeBackpackToggle", {
    Title = "Auto Upgrade Backpack",
    Default = false,
    Callback = function(Value)
        autoUpgradeBackpackEnabled = Value
    end
})

-- Auto Sell Tab
Tabs.AutoSell:AddToggle("AutoSellSelectedToggle", {
    Title = "Auto Sell Selected Items",
    Default = false,
    Callback = function(Value)
        autoSellEnabled = Value
    end
})

Tabs.AutoSell:AddToggle("AutoSellAllToggle", {
    Title = "Auto Sell All (Ignore Favorites)",
    Default = false,
    Callback = function(Value)
        autoSellAllEnabled = Value
    end
})

local sellDropdownItems = {
    "Coal", "Raw Copper", "Raw Tin", "Raw Iron", "Raw Silver", "Raw Gold",
    "Citrine", "Sapphire", "Topaz", "Emerald", "Ruby", "Diamond", "Amethyst",
    "Raw Platinum", "Raw Wolframite", "Raw Titanium", "Raw Cobalt", "Raw Nivelium",
    "Raw Eiskron", "Nocturnite", "Auroralite", "Aquamarine", "Black Diamond",
    "Wolframite Ingot", "Titanium Ingot", "Gold Ingot", "Copper Ingot", "Tin Ingot",
    "Iron Ingot", "Silver Ingot", "Platinum Ingot", "Cobalt Ingot", "Rock"
}

local SellDropdown = Tabs.AutoSell:AddDropdown("SellDropdown", {
    Title = "Select Items to Auto Sell",
    Values = sellDropdownItems,
    Multi = true,
    Default = {},
    Callback = function(Value)
        table.clear(selectedSellItems)
        if type(Value) == "table" then
            for k, v in pairs(Value) do
                if v == true then
                    selectedSellItems[k] = true
                elseif type(k) == "number" and type(v) == "string" then
                    selectedSellItems[v] = true
                end
            end
        end
    end
})

-- ESP Module setup
local espFolder = Instance.new("Folder")
espFolder.Name = "SubterraESPFolder"
espFolder.Parent = workspace

local oreESPMarkers = {}
local mobESPs = {}

local function getOreColor(name)
    local n = name:lower()
    if string.find(n, "coal") then return Color3.fromRGB(50, 50, 50)
    elseif string.find(n, "copper") then return Color3.fromRGB(184, 115, 51)
    elseif string.find(n, "tin") then return Color3.fromRGB(200, 200, 200)
    elseif string.find(n, "iron") then return Color3.fromRGB(218, 165, 32)
    elseif string.find(n, "silver") then return Color3.fromRGB(192, 192, 192)
    elseif string.find(n, "gold") then return Color3.fromRGB(255, 215, 0)
    elseif string.find(n, "ruby") then return Color3.fromRGB(255, 0, 0)
    elseif string.find(n, "emerald") then return Color3.fromRGB(0, 255, 0)
    elseif string.find(n, "diamond") then return Color3.fromRGB(0, 255, 255)
    elseif string.find(n, "sapphire") or string.find(n, "saphire") then return Color3.fromRGB(0, 0, 255)
    elseif string.find(n, "topaz") then return Color3.fromRGB(255, 165, 0)
    elseif string.find(n, "amethyst") then return Color3.fromRGB(128, 0, 128)
    elseif string.find(n, "platinum") then return Color3.fromRGB(229, 228, 226)
    elseif string.find(n, "titanium") then return Color3.fromRGB(112, 128, 144)
    elseif string.find(n, "wolframite") then return Color3.fromRGB(105, 105, 105)
    elseif string.find(n, "cobalt") then return Color3.fromRGB(70, 130, 180)
    elseif string.find(n, "nivelium") then return Color3.fromRGB(0, 128, 128)
    elseif string.find(n, "eiskron") then return Color3.fromRGB(240, 248, 255)
    else return Color3.fromRGB(255, 255, 255)
    end
end

local function updateOreESP()
    for _, marker in ipairs(oreESPMarkers) do
        if marker and marker.Parent then
            marker:Destroy()
        end
    end
    table.clear(oreESPMarkers)
    
    if not oreESPEnabled then return end
    
    local c = localPlayer.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    if not h then return end
    
    local currentPos = h.Position
    for chunkKey, chunk in pairs(chunkHandlerClient.getChunks()) do
        local cx, cy = string.match(chunkKey, "([^,]+),([^,]+)")
        cx = tonumber(cx)
        cy = tonumber(cy)
        if cx and cy then
            local chunkCenterX = cx * 64 + 32
            local chunkCenterY = cy * 64 + 32
            local distToChunk = math.sqrt((currentPos.X - chunkCenterX)^2 + (currentPos.Y - chunkCenterY)^2)
            
            if distToChunk < 250 then
                for blockKey, blockData in pairs(chunk.chunkData) do
                    if blockData.b and selectedESPOres[blockData.b] then
                        local bx, by, bz = string.match(blockKey, "([^,]+),([^,]+),([^,]+)")
                        bx = tonumber(bx)
                        by = tonumber(by)
                        bz = tonumber(bz)
                        if bx and by and bz == 0 then
                            local worldX = cx * 64 + bx * 4
                            local worldY = cy * 64 + by * 4
                            local pos = Vector3.new(worldX, worldY, -4)
                            local oreColor = getOreColor(blockData.b)

                            -- BoxHandleAdornment (highlight box)
                            local adornment = Instance.new("BoxHandleAdornment")
                            adornment.Size = Vector3.new(4, 4, 4)
                            adornment.AlwaysOnTop = true
                            adornment.ZIndex = 5
                            adornment.Color3 = oreColor
                            adornment.Transparency = 0.5
                            adornment.Adornee = workspace.Terrain
                            adornment.CFrame = CFrame.new(pos)
                            adornment.Parent = espFolder
                            table.insert(oreESPMarkers, adornment)

                            -- Anchor Part untuk BillboardGui
                            local anchorPart = Instance.new("Part")
                            anchorPart.Size = Vector3.new(0.1, 0.1, 0.1)
                            anchorPart.Anchored = true
                            anchorPart.CanCollide = false
                            anchorPart.Transparency = 1
                            anchorPart.CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0))
                            anchorPart.Parent = espFolder
                            table.insert(oreESPMarkers, anchorPart)

                            -- BillboardGui: nama + jarak
                            local bgui = Instance.new("BillboardGui")
                            bgui.Name = "OreESP_Gui"
                            bgui.AlwaysOnTop = true
                            bgui.Size = UDim2.new(0, 130, 0, 40)
                            bgui.StudsOffset = Vector3.new(0, 2, 0)
                            bgui.Adornee = anchorPart
                            bgui.Parent = anchorPart

                            local bg = Instance.new("Frame")
                            bg.Size = UDim2.new(1, 0, 1, 0)
                            bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                            bg.BackgroundTransparency = 0.45
                            bg.BorderSizePixel = 0
                            bg.Parent = bgui
                            Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)

                            local nameLabel = Instance.new("TextLabel")
                            nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
                            nameLabel.Position = UDim2.new(0, 0, 0, 0)
                            nameLabel.BackgroundTransparency = 1
                            nameLabel.TextColor3 = oreColor
                            nameLabel.TextStrokeTransparency = 0
                            nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                            nameLabel.TextSize = 13
                            nameLabel.Font = Enum.Font.SourceSansBold
                            nameLabel.Text = blockData.b:gsub("Ore", " ✦")
                            nameLabel.Parent = bg

                            local distLabel = Instance.new("TextLabel")
                            distLabel.Name = "DistLabel"
                            distLabel.Size = UDim2.new(1, 0, 0.45, 0)
                            distLabel.Position = UDim2.new(0, 0, 0.55, 0)
                            distLabel.BackgroundTransparency = 1
                            distLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
                            distLabel.TextStrokeTransparency = 0
                            distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                            distLabel.TextSize = 11
                            distLabel.Font = Enum.Font.SourceSans
                            distLabel.Text = "... m"
                            distLabel.Parent = bg

                            -- Update jarak setiap frame
                            local conn
                            conn = RunService.RenderStepped:Connect(function()
                                if not anchorPart.Parent then
                                    conn:Disconnect()
                                    return
                                end
                                local myC = localPlayer.Character
                                local myH = myC and myC:FindFirstChild("HumanoidRootPart")
                                if myH then
                                    local dist = math.round((myH.Position - pos).Magnitude)
                                    distLabel.Text = dist .. " m"
                                end
                            end)
                        end
                    end
                end
            end
        end
    end
end

local function shouldShowMobESP(mob)
    local realName = mob:GetAttribute("realName") or mob:GetAttribute("Mob") or mob.Name
    for selected in pairs(selectedESPMobs) do
        if string.find(realName:lower(), selected:lower()) then
            return true
        end
    end
    return false
end

local function createMobESP(mob)
    if not mob:IsA("Model") or not mob:FindFirstChild("HumanoidRootPart") then return end
    if mobESPs[mob] then return end
    if not shouldShowMobESP(mob) then return end
    
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.fromRGB(255, 0, 0)
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0.2
    highlight.Adornee = mob
    highlight.Parent = mob
    
    local bgui = Instance.new("BillboardGui")
    bgui.Name = "MobESP_Gui"
    bgui.AlwaysOnTop = true
    bgui.Size = UDim2.new(0, 120, 0, 30)
    bgui.StudsOffset = Vector3.new(0, 3, 0)
    bgui.Adornee = mob.HumanoidRootPart
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextStrokeTransparency = 0
    textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    textLabel.TextSize = 12
    textLabel.Font = Enum.Font.SourceSansBold
    
    local realName = mob:GetAttribute("realName") or mob:GetAttribute("Mob") or mob.Name
    textLabel.Text = realName
    textLabel.Parent = bgui
    bgui.Parent = mob
    
    mobESPs[mob] = {Highlight = highlight, Gui = bgui}
    
    local conn
    conn = RunService.RenderStepped:Connect(function()
        if not mob.Parent or not mob:FindFirstChild("HumanoidRootPart") or not mobESPs[mob] then
            conn:Disconnect()
            return
        end
        local myChar = localPlayer.Character
        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if myHrp then
            local dist = math.round((myHrp.Position - mob.HumanoidRootPart.Position).Magnitude)
            textLabel.Text = string.format("%s [%dm]", realName, dist)
        end
    end)
end

local function removeMobESP(mob)
    if mobESPs[mob] then
        pcall(function() mobESPs[mob].Highlight:Destroy() end)
        pcall(function() mobESPs[mob].Gui:Destroy() end)
        mobESPs[mob] = nil
    end
end

-- ESP Select Dropdowns
Tabs.ESP:AddToggle("MobESPToggle", {
    Title = "Mob ESP",
    Default = false,
    Callback = function(Value)
        mobESPEnabled = Value
        if not Value then
            for mob in pairs(mobESPs) do
                removeMobESP(mob)
            end
        else
            local mobFolder = workspace:FindFirstChild("Mobs") and workspace.Mobs:FindFirstChild("Alive")
            if mobFolder then
                for _, mob in ipairs(mobFolder:GetChildren()) do
                    createMobESP(mob)
                end
            end
        end
    end
})

Tabs.ESP:AddDropdown("MobESPFilter", {
    Title = "Select Mobs for ESP",
    Values = {
        "Skeleton", "Zombie", "Slime", "Lava Slime", "Breathtaker", 
        "SkeletonPermafrost", "SkeletonDarkstone", "SkeletonDarkstoneMage", 
        "ZombieDarkstone", "ZombiePermafrost"
    },
    Multi = true,
    Default = {},
    Callback = function(Value)
        table.clear(selectedESPMobs)
        if type(Value) == "table" then
            for k, v in pairs(Value) do
                if v == true then
                    selectedESPMobs[k] = true
                elseif type(k) == "number" and type(v) == "string" then
                    selectedESPMobs[v] = true
                end
            end
        end
        -- Refresh Mob ESP
        if mobESPEnabled then
            for mob in pairs(mobESPs) do
                removeMobESP(mob)
            end
            local mobFolder = workspace:FindFirstChild("Mobs") and workspace.Mobs:FindFirstChild("Alive")
            if mobFolder then
                for _, mob in ipairs(mobFolder:GetChildren()) do
                    createMobESP(mob)
                end
            end
        end
    end
})

Tabs.ESP:AddToggle("OreESPToggle", {
    Title = "Ore ESP",
    Default = false,
    Callback = function(Value)
        oreESPEnabled = Value
        if not Value then
            for _, marker in ipairs(oreESPMarkers) do
                marker:Destroy()
            end
            table.clear(oreESPMarkers)
        else
            task.spawn(updateOreESP)
        end
    end
})

Tabs.ESP:AddDropdown("OreESPFilter", {
    Title = "Select Ores for ESP",
    Values = oreList,
    Multi = true,
    Default = {},
    Callback = function(Value)
        table.clear(selectedESPOres)
        if type(Value) == "table" then
            for k, v in pairs(Value) do
                if v == true then
                    selectedESPOres[k] = true
                elseif type(k) == "number" and type(v) == "string" then
                    selectedESPOres[v] = true
                end
            end
        end
        if oreESPEnabled then
            task.spawn(updateOreESP)
        end
    end
})

-- Dynamic Mob ESP listener
local aliveMobs = workspace:WaitForChild("Mobs"):WaitForChild("Alive")
aliveMobs.ChildAdded:Connect(function(child)
    if mobESPEnabled then
        task.wait(0.5)
        createMobESP(child)
    end
end)
aliveMobs.ChildRemoved:Connect(function(child)
    removeMobESP(child)
end)

-- ESP loop
task.spawn(function()
    while true do
        task.wait(1.5)
        if oreESPEnabled then
            pcall(updateOreESP)
        end
    end
end)

-- Auto Farm loop (Ores)
task.spawn(function()
    while true do
        task.wait(0.1)
        if autoFarmOresEnabled then
            local myChar = localPlayer.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myHrp then continue end
            
            -- Check backpack capacity
            local total = playerData.TotalItems.Value
            local maxCap = playerData.MaxItems.Value
            if total >= maxCap then
                if backpackCapCheckEnabled then
                    if autoUpgradeBackpackEnabled then
                        upgradeBackpackRemote:FireServer()
                        task.wait(0.5)
                    elseif autoSellEnabled or autoSellAllEnabled then
                        runAutoSell()
                        task.wait(1)
                    else
                        task.wait(1)
                        continue
                    end
                end
            end
            
            -- Scan chunks for matching ores
            local closestBlock = nil
            local closestDist = math.huge
            local targetChunkKey = nil
            local targetBlockKey = nil
            local currentPos = myHrp.Position
            
            for chunkKey, chunk in pairs(chunkHandlerClient.getChunks()) do
                local cx, cy = string.match(chunkKey, "([^,]+),([^,]+)")
                cx = tonumber(cx)
                cy = tonumber(cy)
                if cx and cy then
                    local chunkCenterX = cx * 64 + 32
                    local chunkCenterY = cy * 64 + 32
                    local distToChunk = math.sqrt((currentPos.X - chunkCenterX)^2 + (currentPos.Y - chunkCenterY)^2)
                    
                    if distToChunk < 250 then
                        for blockKey, blockData in pairs(chunk.chunkData) do
                            if blockData.b and selectedOres[blockData.b] then
                                local bx, by, bz = string.match(blockKey, "([^,]+),([^,]+),([^,]+)")
                                bx = tonumber(bx)
                                by = tonumber(by)
                                bz = tonumber(bz)
                                if bx and by and bz == 0 then
                                    local itemInfo = SharedUtils.getItemInfo(blockData.b)
                                    local reqLevel = itemInfo and itemInfo.Level or 0
                                    local pickData = HttpService:JSONDecode(playerData.Pickaxe.Value)
                                    local pickLevel = pickData and pickData.Level or 1
                                    
                                    if not pickLevelCheckEnabled or reqLevel <= pickLevel then
                                        local worldX = cx * 64 + bx * 4
                                        local worldY = cy * 64 + by * 4
                                        local dist = math.sqrt((currentPos.X - worldX)^2 + (currentPos.Y - worldY)^2)
                                        if dist < closestDist then
                                            closestDist = dist
                                            closestBlock = {
                                                X = worldX,
                                                Y = worldY,
                                                Data = blockData,
                                                Name = blockData.b
                                            }
                                            targetChunkKey = chunkKey
                                            targetBlockKey = bx .. "," .. by .. ",0"
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            -- Mine closest block
            if closestBlock and targetBlockKey and targetChunkKey then
                -- Equip pickaxe dulu
                local equipped = equipPickaxe()
                if not equipped then
                    task.wait(0.5)
                    continue
                end

                -- Teleport ke ore
                myHrp.CFrame = CFrame.new(closestBlock.X, closestBlock.Y, -4)
                myHrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                task.wait(0.15)
                
                local chunk = chunkHandlerClient.getChunks()[targetChunkKey]
                local startTick = tick()
                while autoFarmOresEnabled and chunk and chunk.chunkData[targetBlockKey] and tick() - startTick < 5 do
                    myHrp.CFrame = CFrame.new(closestBlock.X, closestBlock.Y, -4)
                    myHrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    
                    damageBlock:FireServer(BufferEncoder.write({ targetBlockKey, targetChunkKey }))
                    task.wait(0.18)
                end
            end
        end
    end
end)

-- Auto Farm loop (Mobs)
task.spawn(function()
    while true do
        task.wait(0.1)
        if autoFarmMobsEnabled and selectedMob ~= "" then
            local myChar = localPlayer.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myHrp then continue end
            
            local closestMob = nil
            local closestMobDist = math.huge
            for _, mob in ipairs(aliveMobs:GetChildren()) do
                if mob:IsA("Model") and mob:FindFirstChild("HumanoidRootPart") and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
                    local realName = mob:GetAttribute("realName") or mob:GetAttribute("Mob") or mob.Name
                    if string.find(realName:lower(), selectedMob:lower()) then
                        local dist = (myHrp.Position - mob.HumanoidRootPart.Position).Magnitude
                        if dist < closestMobDist then
                            closestMobDist = dist
                            closestMob = mob
                        end
                    end
                end
            end
            
            if closestMob then
                -- Equip weapon dulu
                local weaponEquipped = equipWeapon()
                if not weaponEquipped then
                    task.wait(0.5)
                    continue
                end

                local myC = localPlayer.Character
                local weapon = myC and myC:FindFirstChildOfClass("Tool")
                if weapon and weapon:FindFirstChild("ToolRemote") then
                    local startTick = tick()
                    while autoFarmMobsEnabled 
                        and closestMob.Parent == aliveMobs 
                        and closestMob:FindFirstChild("Humanoid") 
                        and closestMob.Humanoid.Health > 0 
                        and tick() - startTick < 8 
                    do
                        -- Teleport ke depan mob
                        local mobHrp = closestMob:FindFirstChild("HumanoidRootPart")
                        if mobHrp then
                            myHrp.CFrame = mobHrp.CFrame * CFrame.new(0, 0, 2.5)
                            myHrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        end

                        -- Attack
                        weapon.ToolRemote:FireServer("a")
                        task.wait(0.08)
                    end
                end
            end
        end
    end
end)

-- Auto Upgrade loop
task.spawn(function()
    while true do
        task.wait(2)
        if autoUpgradePickaxeEnabled then
            upgradePickaxeRemote:FireServer()
        end
        if autoUpgradeBackpackEnabled then
            local total = playerData.TotalItems.Value
            local maxCap = playerData.MaxItems.Value
            if total >= maxCap or not backpackCapCheckEnabled then
                upgradeBackpackRemote:FireServer()
            end
        end
    end
end)

-- Auto Sell loop
task.spawn(function()
    while true do
        task.wait(2)
        if autoSellEnabled or autoSellAllEnabled then
            pcall(runAutoSell)
        end
    end
end)

-- Notify user of load
Fluent:Notify({
    Title = "Subterra ⛏️",
    Content = "Steamy Loaded Successfully!",
    Duration = 5
})
