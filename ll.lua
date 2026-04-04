print("[MEGA WORD SEARCH PRO] Initializing...")

-- SERVICES ====================================================================
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local LogService = game:GetService("LogService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- CONFIGURATION ===============================================================
local CONFIG = {
    typingSpeed = 0.09,
    minLength = 3,
    maxLength = 100,
    idealLength = 6,
    autoResetTime = 600,
    wordsPerPage = 10,
}

-- Common words to ignore
local commonWords = {
    ["the"]=true,["and"]=true,["a"]=true,["an"]=true,
    ["is"]=true,["it"]=true,["to"]=true,["of"]=true,
    ["in"]=true,["for"]=true,["on"]=true,["with"]=true,
    ["as"]=true,["at"]=true,["by"]=true,["or"]=true,
}

-- DICTIONARY SOURCES ==========================================================
local DICTIONARY_SOURCES = {
    EN = {
        "https://raw.githubusercontent.com/dwyl/english-words/master/words_alpha.txt"
    },
    ID = {
        "https://raw.githubusercontent.com/louisowen6/NLP_bahasa_resources/master/combined_dict.txt"
    }
}

-- GLOBAL VARIABLES ===========================================================
local allWords = {}
local consoleAutoComplete = false
local collectedLetters = {}
local usedWords = {}
local lastWordTime = 0
local topWords = {}
local selectedIndex = 1
local currentPage = 1
local currentLanguage = "EN"

-- GUI SETUP ===================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MegaWordSearchPro"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local scaleFactor = 0.75
local marginX, marginY = 20, 20

-- SearchBox
local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(0, 540 * scaleFactor, 0, 90 * scaleFactor)
searchBox.Position = UDim2.new(1, -540*scaleFactor - marginX, 1, -90*scaleFactor - marginY)
searchBox.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
searchBox.BorderColor3 = Color3.fromRGB(0, 255, 255)
searchBox.BorderSizePixel = 4
searchBox.TextColor3 = Color3.fromRGB(0, 255, 255)
searchBox.PlaceholderText = "⏳ Loading dictionary..."
searchBox.Font = Enum.Font.GothamBold
searchBox.TextSize = 36 * scaleFactor
searchBox.ClearTextOnFocus = false
searchBox.TextEditable = true
searchBox.Parent = screenGui

-- LANGUAGE BUTTON (NEW) =======================================================
local langButton = Instance.new("TextButton")
langButton.Size = UDim2.new(0, 200 * scaleFactor, 0, 50 * scaleFactor)
langButton.Position = UDim2.new(1, -200*scaleFactor - marginX, 1, -210*scaleFactor - marginY)
langButton.BackgroundColor3 = Color3.fromRGB(20, 40, 80)
langButton.BorderColor3 = Color3.fromRGB(0, 150, 255)
langButton.BorderSizePixel = 3
langButton.TextColor3 = Color3.fromRGB(0, 200, 255)
langButton.Font = Enum.Font.GothamBold
langButton.TextSize = 20 * scaleFactor
langButton.Text = "🌐 Language: EN"
langButton.Parent = screenGui

-- Toggle Button
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 200 * scaleFactor, 0, 50 * scaleFactor)
toggleButton.Position = UDim2.new(1, -200*scaleFactor - marginX, 1, -150*scaleFactor - marginY)
toggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
toggleButton.BorderColor3 = Color3.fromRGB(255, 0, 0)
toggleButton.BorderSizePixel = 3
toggleButton.TextColor3 = Color3.fromRGB(255, 0, 0)
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 20 * scaleFactor
toggleButton.Text = "🔴 Console OFF"
toggleButton.Parent = screenGui

-- Troll Button
local trollButton = Instance.new("TextButton")
trollButton.Size = UDim2.new(0, 120 * scaleFactor, 0, 50 * scaleFactor)
trollButton.Position = UDim2.new(1, -330*scaleFactor - marginX, 1, -150*scaleFactor - marginY)
trollButton.BackgroundColor3 = Color3.fromRGB(50, 10, 50)
trollButton.BorderColor3 = Color3.fromRGB(255, 0, 255)
trollButton.BorderSizePixel = 3
trollButton.TextColor3 = Color3.fromRGB(255, 0, 255)
trollButton.Font = Enum.Font.GothamBold
trollButton.TextSize = 20 * scaleFactor
trollButton.Text = "😈 TROLL"
trollButton.Parent = screenGui

-- Reset Button
local resetButton = Instance.new("TextButton")
resetButton.Size = UDim2.new(0, 120 * scaleFactor, 0, 50 * scaleFactor)
resetButton.Position = UDim2.new(1, -460*scaleFactor - marginX, 1, -150*scaleFactor - marginY)
resetButton.BackgroundColor3 = Color3.fromRGB(50, 50, 10)
resetButton.BorderColor3 = Color3.fromRGB(255, 255, 0)
resetButton.BorderSizePixel = 3
resetButton.TextColor3 = Color3.fromRGB(255, 255, 0)
resetButton.Font = Enum.Font.GothamBold
resetButton.TextSize = 20 * scaleFactor
resetButton.Text = "🔄 RESET"
resetButton.Parent = screenGui

-- NOTIFICATION ================================================================
local function notify(msg)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "MegaWordSearch Pro",
            Text = msg,
            Duration = 3
        })
    end)
end

-- DICTIONARY LOADING ==========================================================
local function loadFromText(content)
    for word in content:gmatch("[^\r\n]+") do
        local len = #word
        if len >= CONFIG.minLength and len <= CONFIG.maxLength and not commonWords[word:lower()] then
            table.insert(allWords, word:lower())
        end
    end
    return #allWords > 0
end

local function loadDictionary()
    allWords = {} -- RESET PENTING

    notify("Loading " .. currentLanguage .. " dictionary...")

    for _, url in ipairs(DICTIONARY_SOURCES[currentLanguage]) do
        local ok, content = pcall(function()
            return game:HttpGet(url)
        end)

        if ok and loadFromText(content) then
            searchBox.PlaceholderText = "Type a word"
            notify("✅ " .. currentLanguage .. " loaded (" .. #allWords .. ")")
            return true
        end
    end

    notify("❌ Failed to load dictionary")
    return false
end

-- LANGUAGE SWITCH =============================================================
langButton.MouseButton1Click:Connect(function()
    currentLanguage = (currentLanguage == "EN") and "ID" or "EN"
    langButton.Text = "🌐 Language: " .. currentLanguage
    
    task.spawn(loadDictionary)
end)

-- START =======================================================================
task.spawn(function()
    if loadDictionary() then
        notify("🚀 Ready! " .. #allWords .. " words loaded")
    end
end)
