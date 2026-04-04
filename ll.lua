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
    typingSpeed = 0.08,        -- Typing speed (seconds between each letter)
    minLength = 3,             -- Minimum word length
    maxLength = 100,            -- Maximum word length
    idealLength = 5,           -- Ideal length for prioritization
    autoResetTime = 600,       -- 10 minutes in seconds
    wordsPerPage = 10,         -- Words per page
}

-- Common words to ignore
local commonWords = {
    ["the"] = true, ["and"] = true, ["a"] = true, ["an"] = true,
    ["is"] = true, ["it"] = true, ["to"] = true, ["of"] = true,
    ["in"] = true, ["for"] = true, ["on"] = true, ["with"] = true,
    ["as"] = true, ["at"] = true, ["by"] = true, ["or"] = true,
}

-- Dictionary URLs (fallback)
local DICTIONARY_URLS = {
    "https://raw.githubusercontent.com/dwyl/english-words/master/words_alpha.txt"
    "https://raw.githubusercontent.com/first20hours/google-10000-english/master/google-10000-english-usa-no-swears.txt"
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

-- Results Frame
local resultsFrame = Instance.new("Frame")
resultsFrame.Size = UDim2.new(0, 540 * scaleFactor, 0, 400 * scaleFactor)
resultsFrame.Position = UDim2.new(1, -540*scaleFactor - marginX, 1, -490*scaleFactor - marginY)
resultsFrame.BackgroundTransparency = 1
resultsFrame.Parent = screenGui

-- Selection Box
local selectionBox = Instance.new("Frame")
selectionBox.BackgroundTransparency = 0.5
selectionBox.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
selectionBox.BorderSizePixel = 2
selectionBox.Visible = false
selectionBox.Parent = resultsFrame

-- Pagination Arrows
local arrowMargin = 5

local leftArrow = Instance.new("TextButton")
leftArrow.Size = UDim2.new(0, 40*scaleFactor, 0, 40*scaleFactor)
leftArrow.Text = "<"
leftArrow.Font = Enum.Font.GothamBold
leftArrow.TextSize = 32*scaleFactor
leftArrow.BackgroundColor3 = Color3.fromRGB(15,15,15)
leftArrow.TextColor3 = Color3.fromRGB(0,255,150)
leftArrow.Parent = screenGui
leftArrow.Position = UDim2.new(0, searchBox.AbsolutePosition.X, 0, searchBox.AbsolutePosition.Y - 40*scaleFactor - arrowMargin)

local rightArrow = leftArrow:Clone()
rightArrow.Text = ">"
rightArrow.Parent = screenGui
rightArrow.Position = UDim2.new(0, searchBox.AbsolutePosition.X + 50*scaleFactor, 0, searchBox.AbsolutePosition.Y - 40*scaleFactor - arrowMargin)

-- NOTIFICATION SYSTEM =========================================================
local function notify(message)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "MegaWordSearch Pro",
            Text = message,
            Duration = 3
        })
    end)
end

-- CONSOLE LISTENER ============================================================
local function extractLetters(message)
    local pattern = "Word:%s*([A-Z][A-Z]?[A-Z]?[A-Z]?)"
    return string.match(message, pattern)
end

LogService.MessageOut:Connect(function(message, messageType)
    if string.find(message, "Word:") then
        local letters = extractLetters(message)
        
        if letters and consoleAutoComplete then
            lastWordTime = tick()
            table.insert(collectedLetters, letters)
            print("[CONSOLE] Letters detected: " .. letters)
            notify("📝 " .. letters .. " detected!")
            searchBox.Text = letters
        end
    end
end)

-- AUTO-RESET SYSTEM ===========================================================
task.spawn(function()
    while task.wait(10) do
        if lastWordTime > 0 and tick() - lastWordTime > CONFIG.autoResetTime then
            usedWords = {}
            lastWordTime = 0
            print("[AUTO-RESET] Used words list reset (5 min inactivity)")
            notify("🔄 Auto-reset performed!")
        end
    end
end)

-- DICTIONARY LOADING ==========================================================
local function loadFromJSON(content)
    local success, wordsJson = pcall(function()
        return HttpService:JSONDecode(content)
    end)
    
    if not success then return false end
    
    for word, _ in pairs(wordsJson) do
        local len = #word
        if len >= CONFIG.minLength and len <= CONFIG.maxLength and not commonWords[word:lower()] then
            table.insert(allWords, word:lower())
        end
    end
    return true
end

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
    print("[INFO] Downloading dictionary...")
    notify("Loading dictionary...")

    for i, url in ipairs(DICTIONARY_URLS) do
        local ok, content = pcall(function()
            return game:HttpGet(url)
        end)

        if ok then
            local loaded = false
            
            -- Detect JSON or text format
            if content:match("^%s*{") then
                loaded = loadFromJSON(content)
            else
                loaded = loadFromText(content)
            end
            
            if loaded then
                print("[✓] " .. #allWords .. " words loaded from source #" .. i)
                searchBox.PlaceholderText = "Type a word"
                notify("✅ Dictionary loaded! (" .. #allWords .. " words)")
                return true
            end
        else
            warn("[WARN] Source #" .. i .. " failed, trying next...")
        end
    end

    warn("[ERROR] All dictionary sources failed")
    searchBox.PlaceholderText = "❌ Dictionary unavailable"
    notify("❌ Failed to load dictionary")
    return false
end

-- WORD LABEL CREATION =========================================================
local function createWordLabel(parent, text, size, offsetY)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, size + 5)
    lbl.Position = UDim2.new(0, 0, 0, offsetY)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(0, 255, 150)
    lbl.Font = Enum.Font.Arcade
    lbl.TextSize = size
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    lbl.Text = text
    lbl.Parent = parent
    return lbl
end

-- AUTO-TYPE FUNCTION ==========================================================
local function autoTypeWord(word, currentInput)
    local remaining = word:sub(#currentInput + 1)
    task.spawn(function()
        local cam = workspace.CurrentCamera
        local size = cam.ViewportSize
        local x, y = size.X/2, size.Y/2
        
        -- Triple click to select all
        for _ = 1,3 do
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
            task.wait(0.05)
        end

        -- Type remaining letters
        for c in remaining:upper():gmatch(".") do
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode[c], false, game)
            task.wait(CONFIG.typingSpeed)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode[c], false, game)
        end

        -- Submit with Enter
        task.wait(0.15)
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
    end)
end

-- PAGINATION DISPLAY ==========================================================
local function displayPage()
    for _, c in ipairs(resultsFrame:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end

    local startIdx = (currentPage-1)*CONFIG.wordsPerPage + 1
    local endIdx = math.min(currentPage*CONFIG.wordsPerPage, #topWords)
    
    for i = startIdx, endIdx do
        local size = (i == startIdx) and 68*scaleFactor or 33*scaleFactor
        local offsetY = (i == startIdx) and 0 or 68*scaleFactor + (i-startIdx-1)*33*scaleFactor
        local lbl = createWordLabel(resultsFrame, topWords[i]:upper(), size, offsetY)

        lbl.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local word = topWords[i]
                if word then
                    usedWords[word] = true
                    notify("✅ Selected: " .. word)
                    autoTypeWord(word, searchBox.Text)
                    searchBox.Text = ""
                    selectionBox.Visible = false
                end
            end
        end)
    end

    if endIdx-startIdx+1 > 0 then
        local firstLabel = resultsFrame:GetChildren()[1]
        if firstLabel and firstLabel:IsA("TextLabel") then
            selectionBox.Position = firstLabel.Position
            selectionBox.Size = firstLabel.Size
            selectionBox.Visible = true
        end
    else
        selectionBox.Visible = false
    end
end

-- SEARCH LOGIC WITH SMART PRIORITIZATION ======================================
local function updateTopWords(input)
    topWords = {}
    input = input:lower()
    
    if input == "" then
        selectionBox.Visible = false
        for _, c in ipairs(resultsFrame:GetChildren()) do
            if c:IsA("TextLabel") then c:Destroy() end
        end
        return
    end

    -- Collect unused matching words
    for _, w in ipairs(allWords) do
        if w:sub(1, #input) == input and w ~= input and not usedWords[w] then
            table.insert(topWords, w)
        end
    end

    -- Smart sorting by ideal length
    table.sort(topWords, function(a, b)
        local lenA, lenB = #a, #b
        local distA = math.abs(lenA - CONFIG.idealLength)
        local distB = math.abs(lenB - CONFIG.idealLength)
        
        if distA == distB then
            if lenA == lenB then
                return a < b
            end
            return lenA < lenB
        end
        return distA < distB
    end)

    currentPage = 1
    displayPage()
end

-- BUTTON EVENTS ===============================================================
toggleButton.MouseButton1Click:Connect(function()
    consoleAutoComplete = not consoleAutoComplete
    
    if consoleAutoComplete then
        toggleButton.Text = "🟢 Console ON"
        toggleButton.TextColor3 = Color3.fromRGB(0, 255, 0)
        toggleButton.BorderColor3 = Color3.fromRGB(0, 255, 0)
        notify("✅ Console enabled!")
    else
        toggleButton.Text = "🔴 Console OFF"
        toggleButton.TextColor3 = Color3.fromRGB(255, 0, 0)
        toggleButton.BorderColor3 = Color3.fromRGB(255, 0, 0)
        notify("❌ Console disabled")
    end
end)

trollButton.MouseButton1Click:Connect(function()
    if searchBox.Text == "" then
        notify("⚠️ Type some letters first!")
        return
    end
    
    local input = searchBox.Text:lower()
    local longWords = {}
    
    for _, w in ipairs(allWords) do
        if w:sub(1, #input) == input and not usedWords[w] and #w >= 7 then
            table.insert(longWords, w)
        end
    end
    
    if #longWords == 0 then
        notify("😅 No more long words!")
        return
    end
    
    table.sort(longWords, function(a, b) return #a > #b end)
    
    local trollWord = longWords[1]
    usedWords[trollWord] = true
    notify("😈 TROLL: " .. trollWord:upper())
    autoTypeWord(trollWord, searchBox.Text)
    searchBox.Text = ""
end)

resetButton.MouseButton1Click:Connect(function()
    usedWords = {}
    lastWordTime = 0
    notify("🔄 Used words list reset!")
    print("[RESET] Used words cleared")
end)

-- PAGINATION
leftArrow.MouseButton1Click:Connect(function()
    if currentPage > 1 then
        currentPage = currentPage - 1
        displayPage()
    end
end)

rightArrow.MouseButton1Click:Connect(function()
    if currentPage < math.ceil(#topWords/CONFIG.wordsPerPage) then
        currentPage = currentPage + 1
        displayPage()
    end
end)

-- TEXT EVENTS
searchBox.Focused:Connect(function()
    searchBox.Text = ""
    selectionBox.Visible = false
end)

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    updateTopWords(searchBox.Text)
end)

-- START =======================================================================
task.spawn(function()
    if loadDictionary() then
        print("[MEGA WORD SEARCH PRO – READY]")
        notify("🚀 Ready! " .. #allWords .. " words loaded")
    end
end)
