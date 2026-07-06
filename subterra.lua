-- [[ SUBTERRA PREMIUM CHEAT SCRIPT - FLUID ANDROID UI ]]
-- Updated by Antigravity for user iRyck1308
-- Supported OS: Android / PC (Fluent UI with Draggable Toggle Button)

_G.SubterraScriptID = (_G.SubterraScriptID or 0) + 1
local currentScriptID = _G.SubterraScriptID

-- Compatibility fallbacks for older executors
if not math.round then
    math.round = function(n)
        return math.floor(n + 0.5)
    end
end

if not table.clear then
    table.clear = function(t)
        for k in pairs(t) do
            t[k] = nil
        end
    end
end

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
for _, g in ipairs(CoreGui:GetChildren()) do
    if g:IsA("ScreenGui") and (g.Name == "ScreenGui" or g.Name:match("^SteamyUI_")) then
        local isSteamy = false
        for _, desc in ipairs(g:GetDescendants()) do
            if desc:IsA("TextLabel") and (desc.Text:find("Subterra") or desc.Text:find("Steamy")) then
                isSteamy = true
                break
            end
        end
        if isSteamy then
            pcall(function() g:Destroy() end)
        end
    end
end

local oldGui = CoreGui:FindFirstChild("SubterraToggleGui")
if oldGui then
    oldGui:Destroy()
end
local oldESPGui = CoreGui:FindFirstChild("SubterraESPGui")
if oldESPGui then
    oldESPGui:Destroy()
end

-- Global ESP tables
local activeTargets = {}
local espLabelsPool = {}

local yrsaESPEnabled = false
local yrsaTargets = {}
local yrsaMarkers = {}

local YrsaStatusLabel
local targetTpX = 0
local targetTpY = 0

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

local SteamyUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/erickdb/SteamyUI/refs/heads/main/SteamyUI.lua"))()

-- Register custom emojis in SteamyUI Icon registry
SteamyUI.Icons["⛏️"] = "⛏️"
SteamyUI.Icons["⚔️"] = "⚔️"
SteamyUI.Icons["💰"] = "💰"

local isMobile = UserInputService.TouchEnabled
local windowSize = isMobile and UDim2.fromOffset(460, 270) or UDim2.fromOffset(580, 460)

local Window = SteamyUI:CreateWindow({
    Title = "Subterra ⛏️",
    SubTitle = "v1.4.55 | Premium Script Hub",
    Logo = "⛏️", 
    LogoColor = "#00FFC8", -- Neon accent color (matches Subterra theme!)
    Size = windowSize,
    Theme = "Darker",
    Folder = "SubterraPremium",
    KeySystem = false, -- Tanpa key system
    HasSettings = true, -- Enable built-in settings tab (includes theme, keybind, configs, and unload!)
    ToggleKey = Enum.KeyCode.RightShift,
    ConfigSettings = {
        DefaultConfig = "Default"
    },
    FloatButton = {
        Enabled = true,
        Size = 60,
        BorderSize = 3
    }
})

local Tabs = {
    Main = Window:AddTab({ Title = "Home", Icon = "home" }),
    AutoFarm = Window:AddTab({ Title = "Auto Farm", Icon = "⛏️" }),
    Combat = Window:AddTab({ Title = "Combat", Icon = "⚔️" }),
    AutoSell = Window:AddTab({ Title = "Auto Sell", Icon = "💰" }),
    ESP = Window:AddTab({ Title = "ESP", Icon = "eye" })
}

-- Put Settings tab at the bottom of the sidebar
if Window.Tabs[1] and Window.Tabs[1].Title == "Settings" then
    Window.Tabs[1].Button.LayoutOrder = 999
    Window:SelectTab(2) -- Select Home tab by default on load
end

-- System states
local wsEnabled = false
local wsValue = 16
local noclipEnabled = false
local infJumpEnabled = false
local antiAfkEnabled = false
local idledConnection

local autoFarmOresEnabled = false
local autoFarmMobsEnabled = false

local killAuraEnabled = false
local killAuraRange = 15
local killAuraMultiHit = 3
local isCheatHit = false

-- Manual hit multiplier: detect mouse click and fire extra hits directly
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not killAuraEnabled then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
    
    local myChar = localPlayer.Character
    local weapon = myChar and myChar:FindFirstChildOfClass("Tool")
    local remote = weapon and weapon:FindFirstChild("ToolRemote")
    if not remote then return end
    
    -- Fire extra hits (the original game attack already sends 1, we add mult-1 more)
    local mult = killAuraMultiHit or 3
    for i = 1, mult - 1 do
        task.spawn(function()
            task.wait(i * 0.08)
            local c = localPlayer.Character
            local w = c and c:FindFirstChildOfClass("Tool")
            local r = w and w:FindFirstChild("ToolRemote")
            if r then r:FireServer(true) end
        end)
    end
end)

local autoBlockEnabled = false
local isBlocking = false

local autoHealEnabled = false
local selectedHealPotion = "Use Lowest Rarity"
local healHealthThreshold = 50
local lastHealTime = 0
local healCooldown = 2.5

local function getPotionScore(name)
    name = name:lower()
    if name:find("small") or name:find("minor") or name:find("lesser") or name:find("1") or name:find("small health") then
        return 1
    elseif name:find("medium") or name:find("regular") or name:find("normal") or name:find("2") or name:find("medium health") then
        return 2
    elseif name:find("large") or name:find("major") or name:find("greater") or name:find("super") or name:find("3") or name:find("large health") then
        return 3
    else
        return 4
    end
end



local autoSellEnabled = false
local autoSellAllEnabled = false

local mobESPEnabled = false
local oreESPEnabled = false

local selectedOres = {}
local selectedSellItems = {}
local selectedMobs = {}
local targetTeleportPlayer = ""

local selectedESPOres = {}
local selectedESPMobs = {}

-- =============================================================================
-- MAIN TAB ELEMENTS
-- =============================================================================
local movementSection = Tabs.Main:AddSection({ Title = "Movement Settings", DefaultOpen = true })

movementSection:AddSlider("WalkSpeedSlider", {
    Title = "WalkSpeed",
    Description = "Atur kecepatan berjalan karakter",
    Min = 16,
    Max = 150,
    Default = 16,
    Decimal = 0,
    Callback = function(Value)
        wsValue = Value
    end
})

movementSection:AddToggle("WalkSpeedToggle", {
    Title = "Enable WalkSpeed",
    Default = false,
    Callback = function(Value)
        wsEnabled = Value
    end
})

movementSection:AddToggle("NoClipToggle", {
    Title = "No Clip",
    Default = false,
    Callback = function(Value)
        noclipEnabled = Value
    end
})

movementSection:AddToggle("InfJumpToggle", {
    Title = "Infinite Jump",
    Default = false,
    Callback = function(Value)
        infJumpEnabled = Value
    end
})

local function setAntiAfk(state)
    antiAfkEnabled = state
    if state then
        if not idledConnection then
            idledConnection = localPlayer.Idled:Connect(function()
                local VirtualUser = game:GetService("VirtualUser")
                VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                task.wait(1)
                VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            end)
        end
    else
        if idledConnection then
            idledConnection:Disconnect()
            idledConnection = nil
        end
    end
end

movementSection:AddToggle("AntiAfkToggle", {
    Title = "Anti AFK",
    Description = "Cegah pemutusan koneksi karena tidak aktif (Idle)",
    Default = false,
    Callback = function(Value)
        setAntiAfk(Value)
    end
})

local playerTpSection = Tabs.Main:AddSection({ Title = "Player Teleport", DefaultOpen = true })

local function getPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer then
            table.insert(names, p.Name)
        end
    end
    return names
end

local PlayerDropdown = playerTpSection:AddDropdown("PlayerTeleportDropdown", {
    Title = "Pilih Pemain untuk Teleport",
    Description = "Pilih pemain tujuan teleportasi",
    Values = getPlayerNames(),
    Default = "",
    Callback = function(Value)
        targetTeleportPlayer = Value
    end
})

playerTpSection:AddButton({
    Title = "Teleport ke Pemain",
    Description = "Teleport langsung ke pemain yang dipilih",
    Icon = "play",
    Callback = function()
        if targetTeleportPlayer ~= "" then
            local target = Players:FindFirstChild(targetTeleportPlayer)
            local targetChar = target and target.Character
            local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
            local myChar = localPlayer.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if targetHrp and myHrp then
                myHrp.CFrame = targetHrp.CFrame
            end
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
        if h then
            if wsEnabled then
                h.WalkSpeed = wsValue
            else
                if h.WalkSpeed ~= 16 then
                    h.WalkSpeed = 16
                end
            end
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
local keyCodes = {
    [1] = Enum.KeyCode.One,
    [2] = Enum.KeyCode.Two,
    [3] = Enum.KeyCode.Three,
    [4] = Enum.KeyCode.Four,
    [5] = Enum.KeyCode.Five,
    [6] = Enum.KeyCode.Six,
    [7] = Enum.KeyCode.Seven,
    [8] = Enum.KeyCode.Eight,
    [9] = Enum.KeyCode.Nine,
    [0] = Enum.KeyCode.Zero
}
local function pressSlot(slotNum)
    local kc = keyCodes[slotNum]
    if kc then
        local setidentity = setthreadidentity or setidentity or (syn and syn.set_thread_identity)
        local getidentity = getthreadidentity or getidentity
        local oldIdentity = getidentity and getidentity() or 2
        
        if setidentity then setidentity(8) end
        
        local VirtualInputManager = game:GetService("VirtualInputManager")
        VirtualInputManager:SendKeyEvent(true, kc, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, kc, false, game)
        
        if setidentity then setidentity(oldIdentity) end
    end
end

local function equipPickaxe()
    local c = localPlayer.Character
    if c then
        local equipped = c:FindFirstChildOfClass("Tool")
        if equipped and equipped.Name:lower():find("pickaxe") then
            return true
        end
    end
    -- Cari di Hotbar
    for _, slot in ipairs(playerData.Hotbar:GetChildren()) do
        local slotVal = slot.Value or ""
        if slotVal:lower():find("pickaxe") then
            pressSlot(tonumber(slot.Name))
            task.wait(0.5)
            return true
        end
    end
    return false
end

local function equipWeapon()
    local c = localPlayer.Character
    local equippedTool = c and c:FindFirstChildOfClass("Tool")
    if equippedTool and not equippedTool.Name:lower():find("pickaxe") and equippedTool:FindFirstChild("ToolRemote") then
        return true
    end
    -- Cari weapon di Hotbar
    for _, slot in ipairs(playerData.Hotbar:GetChildren()) do
        local slotVal = slot.Value or ""
        if slotVal ~= "" and not slotVal:lower():find("pickaxe") then
            local itemInfo = pcall(function() return SharedUtils.getItemInfo(slotVal) end) and SharedUtils.getItemInfo(slotVal)
            if itemInfo and itemInfo._Type == "Weapon" then
                pressSlot(tonumber(slot.Name))
                task.wait(0.5)
                return true
            end
        end
    end
    -- Fallback: equip tool apapun yang punya ToolRemote (sword, dll)
    for _, slot in ipairs(playerData.Hotbar:GetChildren()) do
        local slotVal = slot.Value or ""
        if slotVal ~= "" and not slotVal:lower():find("pickaxe") then
            pressSlot(tonumber(slot.Name))
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

local shieldBlockRemote = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    and game:GetService("ReplicatedStorage").Remotes:FindFirstChild("Player")
    and game:GetService("ReplicatedStorage").Remotes.Player:FindFirstChild("ShieldBlock")

local function startBlock()
    if isBlocking then return end
    isBlocking = true
    if shieldBlockRemote then
        shieldBlockRemote:FireServer(true)
    end
end

local function stopBlock()
    if not isBlocking then return end
    isBlocking = false
    if shieldBlockRemote then
        shieldBlockRemote:FireServer(false)
    end
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
    "ApatiteOre", "ArgentiteOre", "AuroraliteOre", "AzuriteOre", "BioluxiteOre",
    "BloodmoonOre", "CelestiteOre", "ChalcedonyOre", "ChromiumOre", "CitrineOre",
    "CoalOre", "CobaltOre", "CopperOre", "CryoliumOre", "DiamondOre", "EiskronOre",
    "EmeraldOre", "GlacieliteOre", "GoldOre", "HalocryteOre", "IceCrystalOre",
    "IceShardOre", "IronOre", "MoonstoneOre", "MycoriaOre", "NephriteOre",
    "NiveliumOre", "NocturniteOre", "OrichalcumOre", "PlatinumOre", "RockOre",
    "RubyOre", "SaphrondOre", "SapphireOre", "SilverOre", "SlimeOre",
    "SunstoneOreLeft", "SunstoneOreRight", "SunstoneOreUp", "TearOfTheBloodMoonOre",
    "TenebronOre", "TinOre", "TitaniumOre", "TopazOre", "VerdaniteOre", "WolframiteOre",
    "agateCrystalBlock", "hogore"
}

-- =============================================================================
-- AUTO FARM TAB ELEMENTS
-- =============================================================================
local oresFarmSection = Tabs.AutoFarm:AddSection({ Title = "Ores Auto Farm", DefaultOpen = true })

oresFarmSection:AddToggle("AutoFarmOresToggle", {
    Title = "Auto Farm Ores",
    Default = false,
    Callback = function(Value)
        autoFarmOresEnabled = Value
    end
})

local currentFarmVisibleOres = oreList
local OreDropdown
local FarmOreSearch = oresFarmSection:AddInput("FarmOreSearch", {
    Title = "Search Ores to Farm",
    Placeholder = "Ketik nama ore untuk menyaring...",
    Default = "",
    Callback = function(Value)
        local filter = Value:lower()
        local filtered = {}
        for _, ore in ipairs(oreList) do
            if ore:lower():find(filter) then
                table.insert(filtered, ore)
            end
        end
        currentFarmVisibleOres = filtered
        OreDropdown:SetValues(filtered)
    end
})

OreDropdown = oresFarmSection:AddDropdown("OreDropdown", {
    Title = "Select Ores to Farm",
    Values = oreList,
    MultiSelect = true,
    Default = {},
    Callback = function(Value)
        local checked = {}
        if type(Value) == "table" then
            for _, v in ipairs(Value) do
                checked[v] = true
            end
        end
        for _, ore in ipairs(currentFarmVisibleOres) do
            if checked[ore] then
                selectedOres[ore] = true
            else
                selectedOres[ore] = nil
            end
        end
    end
})

local mobsFarmSection = Tabs.AutoFarm:AddSection({ Title = "Mobs Auto Farm", DefaultOpen = true })

mobsFarmSection:AddToggle("AutoFarmMobsToggle", {
    Title = "Auto Farm Mobs (Kill Mobs)",
    Default = false,
    Callback = function(Value)
        autoFarmMobsEnabled = Value
    end
})

local MobDropdown = mobsFarmSection:AddDropdown("MobDropdown", {
    Title = "Select Mob to Farm",
    Values = {
        "Breathtaker", "FlytrapMob", "Frosty", "IceElemental", "IceSlime", 
        "Lava Slime", "Mandrake", "Plunderer", "Shroomie", "Skeleton", 
        "SkeletonDarkstone", "SkeletonDarkstoneMage", "SkeletonPermafrost", 
        "Slime", "Spirit", "Yrsa", "Zombie", "ZombieDarkstone", 
        "ZombiePermafrost"
    },
    MultiSelect = true,
    Default = {},
    Callback = function(Value)
        table.clear(selectedMobs)
        if type(Value) == "table" then
            for _, v in ipairs(Value) do
                selectedMobs[v] = true
            end
        end
    end
})

-- =============================================================================
-- COMBAT TAB ELEMENTS
-- =============================================================================
local combatSection = Tabs.Combat:AddSection({ Title = "Combat Options", DefaultOpen = true })

combatSection:AddToggle("KillAuraToggle", {
    Title = "⚔️ Kill Aura",
    Default = false,
    Callback = function(Value)
        killAuraEnabled = Value
    end
})

combatSection:AddSlider("KillAuraRangeSlider", {
    Title = "Kill Aura Range",
    Min = 5,
    Max = 25,
    Default = 15,
    Decimal = 0,
    Callback = function(Value)
        killAuraRange = Value
    end
})

combatSection:AddSlider("KillAuraHitRateSlider", {
    Title = "Kill Aura Hit Speed (Damage Multiplier)",
    Min = 1,
    Max = 20,
    Default = 3,
    Decimal = 0,
    Callback = function(Value)
        killAuraMultiHit = Value
    end
})

combatSection:AddToggle("AutoBlockToggle", {
    Title = "🛡️ Auto Block (Shield)",
    Default = false,
    Callback = function(Value)
        autoBlockEnabled = Value
    end
})

local healingSection = Tabs.Combat:AddSection({ Title = "Auto Healing", DefaultOpen = true })

healingSection:AddToggle("AutoHealToggle", {
    Title = "❤️ Auto Heal",
    Description = "Otomatis menggunakan potion ketika darah Anda rendah",
    Default = false,
    Callback = function(Value)
        autoHealEnabled = Value
    end
})

healingSection:AddDropdown("HealPotionDropdown", {
    Title = "Select Potion Type",
    Values = {
        "Use Lowest Rarity", 
        "Small Potion", 
        "Medium Potion", 
        "Large Potion",
        "Small Health Potion",
        "Medium Health Potion",
        "Large Health Potion"
    },
    MultiSelect = false,
    Default = "Use Lowest Rarity",
    Callback = function(Value)
        selectedHealPotion = Value
    end
})

healingSection:AddSlider("HealHealthSlider", {
    Title = "Heal at Health %",
    Description = "Gunakan potion saat persentase darah di bawah nilai ini",
    Min = 10,
    Max = 90,
    Default = 50,
    Decimal = 0,
    Callback = function(Value)
        healHealthThreshold = Value
    end
})

-- =============================================================================
-- AUTO SELL TAB ELEMENTS
-- =============================================================================
local sellSection = Tabs.AutoSell:AddSection({ Title = "Auto Sell Settings", DefaultOpen = true })

sellSection:AddToggle("AutoSellSelectedToggle", {
    Title = "Auto Sell Selected Items",
    Default = false,
    Callback = function(Value)
        autoSellEnabled = Value
    end
})

sellSection:AddToggle("AutoSellAllToggle", {
    Title = "Auto Sell All (Ignore Favorites)",
    Default = false,
    Callback = function(Value)
        autoSellAllEnabled = Value
    end
})

local sellDropdownItems = {
    "AgateShard", "AmeShards", "Amethyst", "Aquamarine", "Auroralite", "AzuriteCrystal",
    "BioluxiteIngot", "Black Diamond", "Celestite", "Chalcedony", "Citrine", "Coal",
    "Cobalt Ingot", "CommonIcePot", "CommonPot", "Copper Ingot", "Diamond", "Emerald",
    "Gold Ingot", "Halocryte", "Ice Shard", "Iron Ingot", "Leaves", "MoonstoneShard",
    "MycoriaIngot", "Nephrite", "Nocturnite", "Platinum Ingot", "Raw Argentite",
    "Raw Bioluxite", "Raw Chromium", "Raw Cobalt", "Raw Copper", "Raw Cryolium",
    "Raw Eiskron", "Raw Glacielite", "Raw Gold", "Raw Iron", "Raw Mycoria",
    "Raw Nivelium", "Raw Orichalcum", "Raw Platinum", "Raw Saphrond", "Raw Silver",
    "Raw Tenebron", "Raw Tin", "Raw Titanium", "Raw Verdanite", "Raw Wolframite",
    "Rock", "Ruby", "Saphrond Ingot", "Sapphire", "Silver Ingot", "SunstoneCrystal",
    "TenebronIngot", "Tin Ingot", "Titanium Ingot", "Topaz", "VerdaniteIngot",
    "Wolframite Ingot", "argentiteIngot", "bDiamond", "chiceshard", "cryoliumIngot",
    "eiskronIngot", "glacieliteIngot", "hogfrag", "niveliumIngot", "orichalcumIngot",
    "rot", "vines"
}

local currentSellVisibleItems = sellDropdownItems
local SellDropdown
local SellSearch = sellSection:AddInput("SellSearch", {
    Title = "Search Items to Auto Sell",
    Placeholder = "Ketik nama item untuk menyaring...",
    Default = "",
    Callback = function(Value)
        local filter = Value:lower()
        local filtered = {}
        for _, item in ipairs(sellDropdownItems) do
            if item:lower():find(filter) then
                table.insert(filtered, item)
            end
        end
        currentSellVisibleItems = filtered
        SellDropdown:SetValues(filtered)
    end
})

SellDropdown = sellSection:AddDropdown("SellDropdown", {
    Title = "Select Items to Auto Sell",
    Values = sellDropdownItems,
    MultiSelect = true,
    Default = {},
    Callback = function(Value)
        local checked = {}
        if type(Value) == "table" then
            for _, v in ipairs(Value) do
                checked[v] = true
            end
        end
        for _, item in ipairs(currentSellVisibleItems) do
            if checked[item] then
                selectedSellItems[item] = true
            else
                selectedSellItems[item] = nil
            end
        end
    end
})

-- ESP Module setup
local espFolder = workspace:FindFirstChild("SubterraESPFolder")
if not espFolder then
    espFolder = Instance.new("Folder")
    espFolder.Name = "SubterraESPFolder"
    espFolder.Parent = workspace
end

local oreESPMarkers = {}
local mobESPs = {}

local espGui = Instance.new("ScreenGui")
espGui.Name = "SubterraESPGui"
espGui.ResetOnSpawn = false
espGui.Parent = CoreGui

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
    elseif string.find(n, "eiskron") or string.find(n, "bloodmoon") then return Color3.fromRGB(240, 248, 255)
    elseif string.find(n, "glacielite") then return Color3.fromRGB(130, 200, 255)
    elseif string.find(n, "charged") or string.find(n, "chrono") then return Color3.fromRGB(0, 255, 255)
    elseif string.find(n, "ice") or string.find(n, "snow") or string.find(n, "icicle") or string.find(n, "frost") then return Color3.fromRGB(173, 216, 230)
    elseif string.find(n, "auroralite") then return Color3.fromRGB(255, 105, 180)
    elseif string.find(n, "aquamarine") then return Color3.fromRGB(127, 255, 212)
    elseif string.find(n, "celestite") then return Color3.fromRGB(135, 206, 250)
    elseif string.find(n, "argentite") then return Color3.fromRGB(112, 128, 144)
    elseif string.find(n, "cryolium") then return Color3.fromRGB(176, 196, 222)
    elseif string.find(n, "bioluxite") then return Color3.fromRGB(50, 205, 50)
    elseif string.find(n, "chalcedony") then return Color3.fromRGB(230, 230, 250)
    elseif string.find(n, "mycoria") then return Color3.fromRGB(139, 69, 19)
    elseif string.find(n, "nephrite") then return Color3.fromRGB(0, 128, 0)
    elseif string.find(n, "saphrond") then return Color3.fromRGB(255, 140, 0)
    elseif string.find(n, "tenebron") then return Color3.fromRGB(75, 0, 130)
    elseif string.find(n, "verdanite") then return Color3.fromRGB(34, 139, 34)
    elseif string.find(n, "orichalcum") then return Color3.fromRGB(210, 105, 30)
    elseif string.find(n, "sunstone") then return Color3.fromRGB(255, 140, 0)
    elseif string.find(n, "moonstone") then return Color3.fromRGB(224, 240, 255)
    elseif string.find(n, "azurite") then return Color3.fromRGB(0, 128, 255)
    elseif string.find(n, "nocturnite") then return Color3.fromRGB(25, 25, 112)
    elseif string.find(n, "blackdiamond") then return Color3.fromRGB(30, 30, 30)
    elseif string.find(n, "agate") then return Color3.fromRGB(188, 143, 143)
    elseif string.find(n, "halocryte") then return Color3.fromRGB(255, 192, 203)
    elseif string.find(n, "present") then return Color3.fromRGB(255, 69, 0)
    elseif string.find(n, "candycane") then return Color3.fromRGB(255, 100, 100)
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
    
    -- Clear existing Ore targets from activeTargets
    local newActiveTargets = {}
    for _, target in ipairs(activeTargets) do
        if target.Type ~= "Ore" then
            table.insert(newActiveTargets, target)
        end
    end
    activeTargets = newActiveTargets
    
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

                            -- Add to activeTargets for 2D screen-space ESP label
                            local chunkKeyCopy = chunkKey
                            local blockKeyCopy = blockKey
                            table.insert(activeTargets, {
                                Type = "Ore",
                                Position = pos,
                                Name = blockData.b:gsub("Ore", ""),
                                Color = oreColor,
                                IsValid = function()
                                    if not oreESPEnabled then return false end
                                    local currentChunks = chunkHandlerClient.getChunks()
                                    local targetChunk = currentChunks[chunkKeyCopy]
                                    return targetChunk ~= nil and targetChunk.chunkData[blockKeyCopy] ~= nil
                                end
                            })
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
    
    local realName = mob:GetAttribute("realName") or mob:GetAttribute("Mob") or mob.Name
    local target = {
        Type = "Mob",
        GetPosition = function()
            return mob:FindFirstChild("HumanoidRootPart") and mob.HumanoidRootPart.Position or nil
        end,
        Name = realName,
        Color = Color3.fromRGB(255, 60, 60),
        IsValid = function()
            local hum = mob:FindFirstChildOfClass("Humanoid")
            return mobESPEnabled and mob.Parent == aliveMobs and mob:FindFirstChild("HumanoidRootPart") and hum and hum.Health > 0
        end
    }
    table.insert(activeTargets, target)
    mobESPs[mob] = {Highlight = highlight, Target = target}
end

local function removeMobESP(mob)
    if mobESPs[mob] then
        pcall(function() mobESPs[mob].Highlight:Destroy() end)
        local mobTarget = mobESPs[mob].Target
        for i, t in ipairs(activeTargets) do
            if t == mobTarget then
                table.remove(activeTargets, i)
                break
            end
        end
        mobESPs[mob] = nil
    end
end

local function updateESPLabels()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewportSize = camera.ViewportSize
    local screenCenter = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    
    local validTargets = {}
    for _, target in ipairs(activeTargets) do
        if target.IsValid() then
            local pos = target.GetPosition and target.GetPosition() or target.Position
            if pos then
                table.insert(validTargets, {
                    Position = pos,
                    Name = target.Name,
                    Color = target.Color,
                    Type = target.Type
                })
            end
        end
    end
    
    for i = #espLabelsPool + 1, #validTargets do
        local labelFrame = Instance.new("Frame")
        labelFrame.Size = UDim2.new(0, 120, 0, 32)
        labelFrame.BackgroundTransparency = 1
        labelFrame.Parent = espGui
        
        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        bg.BackgroundTransparency = 0.45
        bg.BorderSizePixel = 0
        bg.Parent = labelFrame
        Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)
        
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
        nameLabel.Position = UDim2.new(0, 0, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextStrokeTransparency = 0
        nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        nameLabel.TextSize = 11
        nameLabel.Font = Enum.Font.SourceSansBold
        nameLabel.Parent = bg
        
        local distLabel = Instance.new("TextLabel")
        distLabel.Size = UDim2.new(1, 0, 0.45, 0)
        distLabel.Position = UDim2.new(0, 0, 0.55, 0)
        distLabel.BackgroundTransparency = 1
        distLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        distLabel.TextStrokeTransparency = 0
        distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        distLabel.TextSize = 10
        distLabel.Font = Enum.Font.SourceSans
        distLabel.Parent = bg
        
        table.insert(espLabelsPool, {Frame = labelFrame, Bg = bg, NameLabel = nameLabel, DistLabel = distLabel})
    end
    
    for i = #validTargets + 1, #espLabelsPool do
        espLabelsPool[i].Frame.Visible = false
    end
    
    local localHrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    local myPos = localHrp and localHrp.Position or Vector3.new(0, 0, 0)
    
    for i, target in ipairs(validTargets) do
        local poolItem = espLabelsPool[i]
        local targetPos = target.Position
        
        local screenPos, onScreen = camera:WorldToViewportPoint(targetPos)
        local x, y = screenPos.X, screenPos.Y
        
        if screenPos.Z < 0 then
            local dir = (Vector2.new(x, y) - screenCenter).Unit
            if dir.Magnitude == 0 then
                dir = Vector2.new(0, 1)
            end
            local farPos = screenCenter - dir * 2000
            x, y = farPos.X, farPos.Y
            onScreen = false
        end
        
        local margin = 35
        local clampedX = math.clamp(x, margin, viewportSize.X - margin)
        local clampedY = math.clamp(y, margin, viewportSize.Y - margin)
        
        local isOffscreen = not onScreen or (x ~= clampedX or y ~= clampedY)
        
        local arrow = ""
        if isOffscreen then
            local dir = (Vector2.new(clampedX, clampedY) - screenCenter).Unit
            local angle = math.atan2(dir.Y, dir.X) * (180 / math.pi)
            if angle >= -45 and angle < 45 then
                arrow = " ▶"
            elseif angle >= 45 and angle < 135 then
                arrow = " ▼"
            elseif angle >= -135 and angle < -45 then
                arrow = " ▲"
            else
                arrow = " ◀"
            end
        end
        
        poolItem.Frame.Position = UDim2.new(0, clampedX - 60, 0, clampedY - 16)
        poolItem.Frame.Visible = true
        
        poolItem.NameLabel.TextColor3 = target.Color
        poolItem.NameLabel.Text = target.Name .. arrow
        
        local dist = math.round((myPos - targetPos).Magnitude)
        poolItem.DistLabel.Text = dist .. " m"
        
        if isOffscreen then
            poolItem.Bg.BackgroundTransparency = 0.65
            poolItem.NameLabel.TextTransparency = 0.2
            poolItem.DistLabel.TextTransparency = 0.2
        else
            poolItem.Bg.BackgroundTransparency = 0.45
            poolItem.NameLabel.TextTransparency = 0
            poolItem.DistLabel.TextTransparency = 0
        end
    end
end

local function getYrsaShipLocations()
    local locs = {}
    local possibleCFrames = {
        CFrame.new(2800, 42996, 0),
        CFrame.new(6000, 42996, 0),
        CFrame.new(12000, 42996, 0),
        CFrame.new(20000, 42996, 0),
        CFrame.new(-2800, 42996, 0),
        CFrame.new(-6000, 42996, 0),
        CFrame.new(-12000, 42996, 0),
        CFrame.new(-20000, 42996, 0)
    }
    
    local seed = workspace:GetAttribute("worldSeed")
    if not seed then return locs end
    
    for i = 1, 3 do
        local rand = Random.new(seed * i)
        local cframe = possibleCFrames[rand:NextInteger(1, #possibleCFrames)]
        if cframe then
            -- Teleport directly to exact X, set Y to ship deck (43080)
            local pos = Vector3.new(cframe.X, 43080, cframe.Z)
            table.insert(locs, pos)
        end
    end
    return locs
end


local function matchesCriteria(desc, modelNames)
    local descName = desc.Name:lower()
    for _, name in ipairs(modelNames) do
        if descName:find(name) then
            return true
        end
    end
    
    -- Check attributes
    local itemId = desc:GetAttribute("itemID") or desc:GetAttribute("itemName") or desc:GetAttribute("realName")
    if itemId then
        local itemIdLower = tostring(itemId):lower()
        for _, name in ipairs(modelNames) do
            if itemIdLower:find(name) then
                return true
            end
        end
    end
    
    -- Check children
    for _, child in ipairs(desc:GetChildren()) do
        local childName = child.Name:lower()
        for _, name in ipairs(modelNames) do
            if childName:find(name) then
                return true
            end
        end
    end
    
    return false
end

local function updateYrsaESP()
    -- 1. Check if Yrsa is physically spawned in Mobs.Alive
    local yrsaSpawnedModel = nil
    local mobFolder = workspace:FindFirstChild("Mobs") and workspace.Mobs:FindFirstChild("Alive")
    if mobFolder then
        for _, mob in ipairs(mobFolder:GetChildren()) do
            if mob:IsA("Model") and mob:FindFirstChild("HumanoidRootPart") then
                local realName = mob:GetAttribute("realName") or mob:GetAttribute("Mob") or mob.Name
                if realName:lower():find("yrsa") then
                    yrsaSpawnedModel = mob
                    break
                end
            end
        end
    end
    
    if YrsaStatusLabel then
        if yrsaSpawnedModel then
            local hrp = yrsaSpawnedModel.HumanoidRootPart
            local myChar = localPlayer.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local dist = myHrp and math.round((myHrp.Position - hrp.Position).Magnitude) or 0
            
            YrsaStatusLabel.Text = string.format("Yrsa Status: SPAWNED | Posisi: %d, %d, %d | Jarak: %d m", 
                math.round(hrp.Position.X), 
                math.round(hrp.Position.Y), 
                math.round(hrp.Position.Z), 
                dist
            )
        else
            YrsaStatusLabel.Text = "Yrsa Status: Belum Muncul / Belum Di-summon"
        end
    end

    -- 2. Clear old Yrsa targets
    for _, item in ipairs(yrsaTargets) do
        if item.Highlight and item.Highlight.Parent then 
            pcall(function() item.Highlight:Destroy() end) 
        end
        -- Remove from activeTargets
        for i, t in ipairs(activeTargets) do
            if t == item.Target then
                table.remove(activeTargets, i)
                break
            end
        end
    end
    table.clear(yrsaTargets)
    
    for _, marker in ipairs(yrsaMarkers) do
        if marker and marker.Parent then
            pcall(function() marker:Destroy() end)
        end
    end
    table.clear(yrsaMarkers)
    
    if not yrsaESPEnabled then return end
    
    local targetColor = Color3.fromRGB(255, 0, 127)
    
    local function isDuplicateYrsa(pos)
        for _, t in ipairs(yrsaTargets) do
            local tPos = t.Target.Position
            if tPos and (tPos - pos).Magnitude < 8 then
                return true
            end
        end
        return false
    end
    
    local function addYrsaTarget(pos, name, model)
        if isDuplicateYrsa(pos) then return end
        
        -- Create 3D Box Adornment
        local adornment = Instance.new("BoxHandleAdornment")
        adornment.Size = Vector3.new(6, 6, 6)
        adornment.AlwaysOnTop = true
        adornment.ZIndex = 6
        adornment.Color3 = targetColor
        adornment.Transparency = 0.4
        adornment.Adornee = workspace.Terrain
        adornment.CFrame = CFrame.new(pos)
        adornment.Parent = espFolder
        table.insert(yrsaMarkers, adornment)
        
        -- Create Highlight
        local highlight
        if model then
            highlight = Instance.new("Highlight")
            highlight.FillColor = targetColor
            highlight.FillTransparency = 0.4
            highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
            highlight.OutlineTransparency = 0.2
            highlight.Adornee = model
            highlight.Parent = model
        end
        
        -- Create 2D Label Target
        local target = {
            Type = "YrsaESP",
            Position = pos,
            Name = name,
            Color = targetColor,
            IsValid = function()
                return yrsaESPEnabled
            end
        }
        table.insert(activeTargets, target)
        table.insert(yrsaTargets, {Highlight = highlight, Target = target})
    end
    
    -- If Yrsa is spawned, track Yrsa boss directly
    if yrsaSpawnedModel then
        addYrsaTarget(yrsaSpawnedModel.HumanoidRootPart.Position, "👑 Yrsa of the Sunken", yrsaSpawnedModel)
    else
        -- If not physically spawned, track YrsaSpawner and calculated ship locations
        local foldersToScan = {}
        if workspace:FindFirstChild("Portals") then table.insert(foldersToScan, workspace.Portals) end
        if workspace:FindFirstChild("Debris") then table.insert(foldersToScan, workspace.Debris) end
        if workspace:FindFirstChild("Blocks") then table.insert(foldersToScan, workspace.Blocks) end
        table.insert(foldersToScan, workspace)
        
        for _, folder in ipairs(foldersToScan) do
            for _, desc in ipairs(folder:GetChildren()) do
                if desc:IsA("Model") and desc.Name ~= "PortalSurface" then
                    if matchesCriteria(desc, { "yrsaspawner", "yrsa" }) then
                        local part = desc.PrimaryPart or desc:FindFirstChild("Center") or desc:FindFirstChild("Base") or desc:FindFirstChildOfClass("BasePart")
                        if part then
                            local displayName = "👑 YrsaSpawner"
                            local childYrsa = desc:FindFirstChild("YrsaSpawner")
                            if childYrsa then
                                displayName = "👑 " .. childYrsa.Name
                            else
                                local itemId = desc:GetAttribute("itemID") or desc:GetAttribute("itemName")
                                displayName = itemId and ("👑 " .. tostring(itemId)) or displayName
                            end
                            addYrsaTarget(part.Position, displayName, desc)
                        end
                    end
                end
            end
        end
        
        -- Math calculations
        local shipLocs = getYrsaShipLocations()
        for _, pos in ipairs(shipLocs) do
            addYrsaTarget(pos, "👑 Yrsa / Sunken Ship", nil)
        end
        
        -- Scan chunk data for YrsaSpawner block
        for chunkKey, chunk in pairs(chunkHandlerClient.getChunks()) do
            for blockKey, blockData in pairs(chunk.chunkData) do
                if blockData.b == "YrsaSpawner" then
                    local bx, by, bz = string.match(blockKey, "([^,]+),([^,]+),([^,]+)")
                    bx = tonumber(bx)
                    by = tonumber(by)
                    bz = tonumber(bz)
                    if bx and by and bz == 0 then
                        local cx, cy = string.match(chunkKey, "([^,]+),([^,]+)")
                        cx = tonumber(cx)
                        cy = tonumber(cy)
                        local worldX = cx * 64 + bx * 4
                        local worldY = cy * 64 + by * 4
                        local pos = Vector3.new(worldX, worldY, -4)
                        addYrsaTarget(pos, "👑 YrsaSpawner", nil)
                    end
                end
            end
        end
    end
end



RunService.RenderStepped:Connect(function()
    pcall(updateESPLabels)
end)

-- =============================================================================
-- ESP TAB ELEMENTS
-- =============================================================================
local yrsaSection = Tabs.ESP:AddSection({ Title = "⚓ Yrsa Boss ESP", DefaultOpen = true })

yrsaSection:AddToggle("YrsaESPToggle", {
    Title = "Yrsa ESP",
    Description = "Lacak lokasi kapal karam dan boss Yrsa of the Sunken",
    Default = false,
    Callback = function(Value)
        yrsaESPEnabled = Value
        pcall(updateYrsaESP)
    end
})

yrsaSection:AddButton({
    Title = "Teleport to Yrsa Ship/Boss",
    Description = "Teleport langsung ke lokasi kapal karam Yrsa (atau ke boss jika sudah spawn)",
    Icon = "play",
    Callback = function()
        local myChar = localPlayer.Character
        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myHrp then
            return
        end
        
        local closestTarget = nil
        local closestDist = math.huge
        
        for _, item in ipairs(yrsaTargets) do
            local tPos = item.Target.Position
            if tPos then
                local dist = (myHrp.Position - tPos).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestTarget = item.Target
                end
            end
        end
        
        if closestTarget then
            -- Create local platform to prevent falling in unloaded chunks
            local platform = Instance.new("Part")
            platform.Size = Vector3.new(10, 1, 10)
            platform.Position = closestTarget.Position - Vector3.new(0, 2, 0)
            platform.Anchored = true
            platform.Transparency = 0.5
            platform.Material = Enum.Material.ForceField
            platform.Parent = workspace
            task.delay(5, function()
                pcall(function() platform:Destroy() end)
            end)
            
            myHrp.CFrame = CFrame.new(closestTarget.Position + Vector3.new(0, 3, 0))
            myHrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
    end
})

YrsaStatusLabel = yrsaSection:AddLabel({
    Text = "Yrsa Status: Menunggu pemindaian..."
})

local mobESPSection = Tabs.ESP:AddSection({ Title = "Mob ESP", DefaultOpen = true })

mobESPSection:AddToggle("MobESPToggle", {
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

local MobESPFilter = mobESPSection:AddDropdown("MobESPFilter", {
    Title = "Select Mobs for ESP",
    Values = {
        "Breathtaker", "FlytrapMob", "Frosty", "IceElemental", "IceSlime", 
        "Lava Slime", "Mandrake", "Plunderer", "Shroomie", "Skeleton", 
        "SkeletonDarkstone", "SkeletonDarkstoneMage", "SkeletonPermafrost", 
        "Slime", "Spirit", "Yrsa", "Zombie", "ZombieDarkstone", 
        "ZombiePermafrost"
    },
    MultiSelect = true,
    Default = {},
    Callback = function(Value)
        table.clear(selectedESPMobs)
        if type(Value) == "table" then
            for _, v in ipairs(Value) do
                selectedESPMobs[v] = true
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

local oreESPSection = Tabs.ESP:AddSection({ Title = "Ore ESP", DefaultOpen = true })

oreESPSection:AddToggle("OreESPToggle", {
    Title = "Ore ESP",
    Default = false,
    Callback = function(Value)
        oreESPEnabled = Value
        if not Value then
            for _, marker in ipairs(oreESPMarkers) do
                marker:Destroy()
            end
            table.clear(oreESPMarkers)
            
            -- Clear existing Ore targets from activeTargets
            local newActiveTargets = {}
            for _, target in ipairs(activeTargets) do
                if target.Type ~= "Ore" then
                    table.insert(newActiveTargets, target)
                end
            end
            activeTargets = newActiveTargets
        else
            task.spawn(updateOreESP)
        end
    end
})

local currentESPVisibleOres = oreList
local OreESPFilter
local OreESPSearch = oreESPSection:AddInput("OreESPSearch", {
    Title = "Search Ores for ESP",
    Placeholder = "Ketik nama ore untuk menyaring...",
    Default = "",
    Callback = function(Value)
        local filter = Value:lower()
        local filtered = {}
        for _, ore in ipairs(oreList) do
            if ore:lower():find(filter) then
                table.insert(filtered, ore)
            end
        end
        currentESPVisibleOres = filtered
        OreESPFilter:SetValues(filtered)
    end
})

OreESPFilter = oreESPSection:AddDropdown("OreESPFilter", {
    Title = "Select Ores for ESP",
    Values = oreList,
    MultiSelect = true,
    Default = {},
    Callback = function(Value)
        local checked = {}
        if type(Value) == "table" then
            for _, v in ipairs(Value) do
                checked[v] = true
            end
        end
        for _, ore in ipairs(currentESPVisibleOres) do
            if checked[ore] then
                selectedESPOres[ore] = true
            else
                selectedESPOres[ore] = nil
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
    while _G.SubterraScriptID == currentScriptID do
        task.wait(1.5)
        _G.LoopCounter = (_G.LoopCounter or 0) + 1
        _G.killAuraEnabled = killAuraEnabled
        _G.autoBlockEnabled = autoBlockEnabled
        _G.autoHealEnabled = autoHealEnabled
        _G.healHealthThreshold = healHealthThreshold
        _G.selectedHealPotion = selectedHealPotion
        pcall(updateOreESP)
        pcall(updateYrsaESP)
    end
end)

-- Auto Farm loop (Ores)
task.spawn(function()
    while _G.SubterraScriptID == currentScriptID do
        task.wait(0.1)
        if autoFarmOresEnabled then
            local myChar = localPlayer.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myHrp then continue end

            
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
    while _G.SubterraScriptID == currentScriptID do
        task.wait(0.1)
        local hasSelectedMobs = false
        for _, _ in pairs(selectedMobs) do
            hasSelectedMobs = true
            break
        end
        
        if autoFarmMobsEnabled and hasSelectedMobs then
            local myChar = localPlayer.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myHrp then continue end
            
            local closestMob = nil
            local closestMobDist = math.huge
            for _, mob in ipairs(aliveMobs:GetChildren()) do
                local hum = mob:FindFirstChildOfClass("Humanoid")
                local health = hum and hum.Health or mob:GetAttribute("Health") or (hum and 0 or 1)
                if mob:IsA("Model") and mob:FindFirstChild("HumanoidRootPart") and health > 0 then
                    local realName = mob:GetAttribute("realName") or mob:GetAttribute("Mob") or mob.Name
                    
                    local isTarget = false
                    for selectedName, _ in pairs(selectedMobs) do
                        if string.find(realName:lower(), selectedName:lower()) then
                            isTarget = true
                            break
                        end
                    end
                    
                    if isTarget then
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
                    local hum = closestMob:FindFirstChildOfClass("Humanoid")
                    while autoFarmMobsEnabled 
                        and closestMob.Parent == aliveMobs 
                        and (hum and hum.Health > 0 or closestMob:GetAttribute("Health") or 1)
                        and tick() - startTick < 8 
                    do
                        -- Teleport ke depan mob
                        local mobHrp = closestMob:FindFirstChild("HumanoidRootPart")
                        if mobHrp then
                            myHrp.CFrame = mobHrp.CFrame * CFrame.new(0, 0, 2.5)
                            myHrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        end

                        -- Attack
                        isCheatHit = true
                        weapon.ToolRemote:FireServer(true)
                        isCheatHit = false
                        task.wait(0.08)
                    end
                    -- Delay 0.7s setelah bunuh 1 monster
                    task.wait(0.7)
                end
            end
        end
    end
end)

local function getAnimator(mob)
    local animator = mob:FindFirstChildOfClass("Animator")
    if animator then return animator end
    
    local hum = mob:FindFirstChildOfClass("Humanoid")
    if hum then
        animator = hum:FindFirstChildOfClass("Animator")
        if animator then return animator end
    end
    
    local ac = mob:FindFirstChildOfClass("AnimationController")
    if ac then
        animator = ac:FindFirstChildOfClass("Animator")
        if animator then return animator end
    end
    
    return nil
end

local function getTargetMobs()
    local targets = {}
    local added = {}
    
    if aliveMobs then
        for _, mob in ipairs(aliveMobs:GetChildren()) do
            if mob:IsA("Model") and mob:FindFirstChild("HumanoidRootPart") then
                table.insert(targets, mob)
                added[mob] = true
            end
        end
    end
    
    local mobsFolder = workspace:FindFirstChild("Mobs")
    if mobsFolder then
        for _, desc in ipairs(mobsFolder:GetDescendants()) do
            if desc:IsA("Model") and desc:FindFirstChild("HumanoidRootPart") then
                if not added[desc] then
                    table.insert(targets, desc)
                    added[desc] = true
                end
            end
        end
    end
    
    return targets
end

-- Kill Aura loop (fires burst hits with 0.08s spacing to bypass server debounce)
task.spawn(function()
    while _G.SubterraScriptID == currentScriptID do
        task.wait(0.12)
        if killAuraEnabled then
            local myChar = localPlayer.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if myHrp then
                local weaponEquipped = equipWeapon()
                if weaponEquipped then
                    local weapon = myChar:FindFirstChildOfClass("Tool")
                    local remote = weapon and weapon:FindFirstChild("ToolRemote")
                    if remote then
                        for _, mob in ipairs(getTargetMobs()) do
                            local hum = mob:FindFirstChildOfClass("Humanoid")
                            local health = hum and hum.Health or mob:GetAttribute("Health") or (hum and 0 or 1)
                            if health > 0 then
                                local dist = (myHrp.Position - mob.HumanoidRootPart.Position).Magnitude
                                if dist <= killAuraRange then
                                    -- Burst hits with spacing
                                    for i = 1, killAuraMultiHit do
                                        remote:FireServer(true)
                                        if i < killAuraMultiHit then
                                            task.wait(0.08)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

local lastBlockTime = 0
local blockCooldown = 1.6

local function isMonsterAttacking(mob)
    local animator = getAnimator(mob)
    local hum = mob:FindFirstChildOfClass("Humanoid")
    local tracks = {}
    if animator then
        tracks = animator:GetPlayingAnimationTracks()
    elseif hum then
        tracks = hum:GetPlayingAnimationTracks()
    end
    
    for _, track in ipairs(tracks) do
        local animName = track.Animation and track.Animation.Name:lower() or ""
        local animId = track.Animation and track.Animation.AnimationId:lower() or ""
        local priority = track.Priority
        
        -- Cek keyword attack atau Priority Action (Action, Action2, Action3, Action4)
        if animName:find("attack") or animName:find("swing") or animName:find("slash") or animName:find("hit") or animName:find("strike") or animName:find("punch") or animId:find("attack") or animId:find("swing")
           or priority == Enum.AnimationPriority.Action 
           or (tostring(priority):find("Action")) then
            return true
        end
    end
    return false
end

-- Auto Block loop (reactive: hold block while monster attacks, release when it stops)
task.spawn(function()
    while _G.SubterraScriptID == currentScriptID do
        task.wait(0.08)
        if autoBlockEnabled then
            local myChar = localPlayer.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if myHrp then
                local monsterAttacking = false
                for _, mob in ipairs(getTargetMobs()) do
                    local hum = mob:FindFirstChildOfClass("Humanoid")
                    local health = hum and hum.Health or mob:GetAttribute("Health") or (hum and 0 or 1)
                    if health > 0 then
                        local mobHrp = mob:FindFirstChild("HumanoidRootPart")
                        if mobHrp then
                            local dist = (myHrp.Position - mobHrp.Position).Magnitude
                            if dist <= 12 and isMonsterAttacking(mob) then
                                monsterAttacking = true
                                break
                            end
                        end
                    end
                end
                
                if monsterAttacking then
                    startBlock()
                else
                    stopBlock()
                end
            end
        else
            -- Jika Auto Block dimatikan, pastikan block dilepas
            stopBlock()
        end
    end
end)

-- Auto Heal loop
task.spawn(function()
    while _G.SubterraScriptID == currentScriptID do
        task.wait(0.2)
        if autoHealEnabled and tick() - lastHealTime > healCooldown then
            local myChar = localPlayer.Character
            local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and hum.Health < hum.MaxHealth then
                local currentHpPercent = (hum.Health / hum.MaxHealth) * 100
                if currentHpPercent <= healHealthThreshold then
                    local myPd = game:GetService("ReplicatedStorage"):FindFirstChild("playerData")
                        and game:GetService("ReplicatedStorage").playerData:FindFirstChild(tostring(localPlayer.UserId))
                    local hotbar = myPd and myPd:FindFirstChild("Hotbar")
                    
                    local potionsFound = {}
                    if hotbar then
                        for _, slot in ipairs(hotbar:GetChildren()) do
                            local val = slot.Value or ""
                            if val ~= "" and (val:lower():find("potion") or val:lower():find("hpot") or val:lower():find("heal")) then
                                local slotNum = tonumber(slot.Name)
                                if slotNum then
                                    table.insert(potionsFound, {
                                        Slot = slotNum,
                                        Name = val,
                                        Score = getPotionScore(val)
                                    })
                                end
                            end
                        end
                    end
                    
                    local selectedPotion = nil
                    if #potionsFound > 0 then
                        if selectedHealPotion == "Use Lowest Rarity" then
                            table.sort(potionsFound, function(a, b)
                                return a.Score < b.Score
                            end)
                            selectedPotion = potionsFound[1]
                        else
                            for _, p in ipairs(potionsFound) do
                                if string.find(p.Name:lower(), selectedHealPotion:lower()) then
                                    selectedPotion = p
                                    break
                                end
                            end
                        end
                    end
                    
                    if selectedPotion then
                        lastHealTime = tick()
                        local oldTool = myChar:FindFirstChildOfClass("Tool")
                        
                        -- Equip slot
                        pressSlot(selectedPotion.Slot)
                        
                        -- Tunggu tool muncul di Character
                        local tool = myChar:WaitForChild(selectedPotion.Name, 1.5)
                        if tool then
                            tool:Activate()
                            local toolEvent = tool:FindFirstChild("ToolEvent")
                            if toolEvent then
                                toolEvent:FireServer()
                            else
                                local remote = tool:FindFirstChild("ToolRemote")
                                if remote then
                                    remote:FireServer("a")
                                    remote:FireServer("use")
                                    remote:FireServer()
                                end
                            end
                            task.wait(0.2)
                        end
                        
                        -- Kembalikan tool semula
                        if oldTool then
                            local oldSlotNum = nil
                            if hotbar then
                                for _, slot in ipairs(hotbar:GetChildren()) do
                                    if slot.Value == oldTool.Name or (oldTool:GetAttribute("id") and slot.Value == oldTool:GetAttribute("id")) then
                                        oldSlotNum = tonumber(slot.Name)
                                        break
                                    end
                                end
                            end
                            if oldSlotNum then
                                pressSlot(oldSlotNum)
                            end
                        else
                            pressSlot(selectedPotion.Slot) -- Toggle off
                        end
                    end
                end
            end
        end
    end
end)

-- Auto Sell loop
task.spawn(function()
    while _G.SubterraScriptID == currentScriptID do
        task.wait(2)
        if autoSellEnabled or autoSellAllEnabled then
            pcall(runAutoSell)
        end
    end
end)

