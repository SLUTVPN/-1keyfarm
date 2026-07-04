-- ============================================
-- ULTIMATE FLY (САМАЯ ПОСЛЕДНЯЯ ВЕРСИЯ)
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

repeat wait() until player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
local character = player.Character
local rootPart = character:FindFirstChild("HumanoidRootPart")
local camera = workspace.CurrentCamera
local humanoid = character:FindFirstChildOfClass("Humanoid")

-- ============================================
-- СОСТОЯНИЯ
-- ============================================
local state = {
    flying = false,
    noclip = true,
    godmode = true,
    farmActive = false,
    stepFarmActive = false,
    currentTab = "Главная",  -- ОТСЛЕЖИВАЕТ АКТИВНУЮ ВКЛАДКУ
    stepCount = 0,
    wPressCount = 0,
    speed = 80,
    isDragging = false,
    dragOffset = Vector2.new(0,0)
}

-- ============================================
-- ЗАЩИТА ОТ КИКА
-- ============================================
pcall(function()
    game.Kick = function() return nil end
    game.Shutdown = function() return nil end
end)

pcall(function()
    if game:GetService("VirtualUser") then
        game:GetService("VirtualUser"):CaptureController()
        game:GetService("VirtualUser"):ClickButton2(Vector2.new())
    end
end)

spawn(function()
    while wait(30) do
        pcall(function()
            local mouse = player:GetMouse()
            if mouse then mouse.Move(Vector2.new(mouse.X+1, mouse.Y+1)) end
        end)
    end
end)

-- ============================================
-- БАЗОВЫЕ ФУНКЦИИ
-- ============================================
local function toggleGodMode(enabled)
    if not humanoid then return end
    if enabled then
        humanoid.MaxHealth = 9e9
        humanoid.Health = 9e9
        humanoid.BreakJointsOnDeath = false
        pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end)
    else
        humanoid.MaxHealth = 100
        humanoid.Health = 100
        humanoid.BreakJointsOnDeath = true
        pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true) end)
    end
end

local noclipConnection = nil
local function toggleNoclip(enabled)
    if enabled then
        if noclipConnection then noclipConnection:Disconnect() end
        noclipConnection = RunService.Stepped:Connect(function()
            if not character or not character.Parent then return end
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    else
        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

local function teleportTo(pos)
    if not rootPart then return end
    pcall(function()
        rootPart.CFrame = CFrame.new(pos)
        rootPart.Velocity = Vector3.new(0,0,0)
    end)
end

local function autoWin()
    teleportTo(Vector3.new(2030.8, 544.2, -1628.5))
    print("🏆 АВТОПОБЕДА!")
end

-- ============================================
-- ФАРМ
-- ============================================
local farmCoroutine = nil
local function startFarm()
    if state.farmActive then return end
    state.farmActive = true
    if state.flying then disableFly() end
    
    farmCoroutine = spawn(function()
        local target = Vector3.new(2030.8, 544.2, -1628.5)
        while state.farmActive do
            teleportTo(target)
            wait(0.2)
            local mv = Instance.new("BodyVelocity")
            mv.MaxForce = Vector3.new(1e9,1e9,1e9)
            local fwd = camera.CFrame.LookVector
            fwd = Vector3.new(fwd.X,0,fwd.Z).Unit
            mv.Velocity = fwd * state.speed
            mv.Parent = rootPart
            wait(1)
            pcall(function() if mv then mv:Destroy() end end)
            wait(4)
        end
    end)
end

local function stopFarm()
    if not state.farmActive then return end
    state.farmActive = false
    if farmCoroutine then coroutine.close(farmCoroutine) farmCoroutine = nil end
    for _, v in ipairs(rootPart:GetChildren()) do
        if v:IsA("BodyVelocity") then v:Destroy() end
    end
end

-- ============================================
-- ШАГИ
-- ============================================
local wSpam = nil
local stepCor = nil

local function startStepFarm()
    if state.stepFarmActive then return end
    state.stepFarmActive = true
    state.stepCount = 0
    state.wPressCount = 0
    
    if state.flying then disableFly() end
    if not state.noclip then toggleNoclip(true) end
    
    if humanoid then
        humanoid.PlatformStand = true
        humanoid.WalkSpeed = 999
    end

    wSpam = RunService.Heartbeat:Connect(function()
        if not state.stepFarmActive then return end
        pcall(function()
            UserInputService:SetKeyDown(Enum.KeyCode.W)
            wait(0.005)
            UserInputService:SetKeyUp(Enum.KeyCode.W)
            wait(0.005)
            state.wPressCount = state.wPressCount + 1
            state.stepCount = state.stepCount + 1
        end)
    end)

    stepCor = spawn(function()
        while state.stepFarmActive do
            pcall(function()
                if humanoid then
                    humanoid:Move(Vector3.new(1,0,0), true)
                    wait(0.05)
                    humanoid:Move(Vector3.new(0,0,0), true)
                end
                state.stepCount = state.stepCount + 2
            end)
            wait(0.02)
        end
    end)
end

local function stopStepFarm()
    if not state.stepFarmActive then return end
    state.stepFarmActive = false
    if wSpam then wSpam:Disconnect() wSpam = nil end
    if stepCor then coroutine.close(stepCor) stepCor = nil end
    if humanoid then
        humanoid.WalkSpeed = 16
        humanoid.PlatformStand = false
        humanoid:Move(Vector3.new(0,0,0), true)
    end
end

-- ============================================
-- ПОЛЕТ
-- ============================================
local bv = nil
local bg = nil
local moveDir = Vector3.new(0,0,0)
local flyConn = nil
local keyConns = {}

function enableFly()
    if state.flying then return end
    state.flying = true
    
    bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e9,1e9,1e9)
    bv.Velocity = Vector3.new(0,0,0)
    bv.Parent = rootPart

    bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e9,1e9,1e9)
    bg.CFrame = rootPart.CFrame
    bg.Parent = rootPart

    if humanoid then humanoid.PlatformStand = true end

    flyConn = RunService.RenderStepped:Connect(function()
        if not state.flying or not rootPart then return end
        local fwd = camera.CFrame.LookVector
        local right = camera.CFrame.RightVector
        local up = camera.CFrame.UpVector
        fwd = Vector3.new(fwd.X,0,fwd.Z).Unit
        right = Vector3.new(right.X,0,right.Z).Unit
        local vec = Vector3.new(0,0,0)
        vec = vec + fwd * moveDir.Z * state.speed
        vec = vec + right * moveDir.X * state.speed
        vec = vec + up * moveDir.Y * state.speed
        bv.Velocity = bv.Velocity:Lerp(vec, 0.3)
        if bg then bg.CFrame = camera.CFrame end
    end)

    for _, c in ipairs(keyConns) do pcall(function() c:Disconnect() end) end
    keyConns = {}

    local function onKey(input, pressed)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if not state.flying then return end
        local k = input.KeyCode
        if k == Enum.KeyCode.W then
            moveDir = pressed and moveDir + Vector3.new(0,0,1) or moveDir - Vector3.new(0,0,1)
        elseif k == Enum.KeyCode.S then
            moveDir = pressed and moveDir + Vector3.new(0,0,-1) or moveDir - Vector3.new(0,0,-1)
        elseif k == Enum.KeyCode.A then
            moveDir = pressed and moveDir + Vector3.new(-1,0,0) or moveDir - Vector3.new(-1,0,0)
        elseif k == Enum.KeyCode.D then
            moveDir = pressed and moveDir + Vector3.new(1,0,0) or moveDir - Vector3.new(1,0,0)
        elseif k == Enum.KeyCode.Space then
            moveDir = pressed and moveDir + Vector3.new(0,1,0) or moveDir - Vector3.new(0,1,0)
        elseif k == Enum.KeyCode.LeftShift then
            moveDir = pressed and moveDir + Vector3.new(0,-1,0) or moveDir - Vector3.new(0,-1,0)
        end
    end

    table.insert(keyConns, UserInputService.InputBegan:Connect(function(i) onKey(i, true) end))
    table.insert(keyConns, UserInputService.InputEnded:Connect(function(i) onKey(i, false) end))
end

function disableFly()
    if not state.flying then return end
    state.flying = false
    if bv then bv:Destroy() bv = nil end
    if bg then bg:Destroy() bg = nil end
    if flyConn then flyConn:Disconnect() flyConn = nil end
    for _, c in ipairs(keyConns) do pcall(function() c:Disconnect() end) end
    keyConns = {}
    if humanoid then humanoid.PlatformStand = false end
    moveDir = Vector3.new(0,0,0)
end

-- ============================================
-- GUI
-- ============================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UltimatePro"
screenGui.ResetOnSpawn = false
pcall(function()
    screenGui.Parent = player:WaitForChild("PlayerGui", 5)
end)
if not screenGui.Parent then
    screenGui.Parent = game:GetService("CoreGui")
end

-- ============================================
-- ОСНОВНАЯ ПАНЕЛЬ
-- ============================================
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 780, 0, 420)
mainFrame.Position = UDim2.new(0.5, -390, 0.5, -210)
mainFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 16)
mainFrame.BackgroundTransparency = 0.05
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = mainFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(80, 80, 150)
stroke.Thickness = 1.5
stroke.Transparency = 0.3
stroke.Parent = mainFrame

-- ============================================
-- ШАПКА
-- ============================================
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 50)
header.Position = UDim2.new(0, 0, 0, 0)
header.BackgroundColor3 = Color3.fromRGB(15, 15, 30)
header.BackgroundTransparency = 0.3
header.BorderSizePixel = 0
header.Parent = mainFrame

local hCorner = Instance.new("UICorner")
hCorner.CornerRadius = UDim.new(0, 16)
hCorner.Parent = header

-- АВАТАРКА
local avatarFrame = Instance.new("Frame")
avatarFrame.Size = UDim2.new(0, 38, 0, 38)
avatarFrame.Position = UDim2.new(0, 8, 0, 6)
avatarFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
avatarFrame.BorderSizePixel = 2
avatarFrame.BorderColor3 = Color3.fromRGB(100, 100, 200)
avatarFrame.Parent = header

local avCorner = Instance.new("UICorner")
avCorner.CornerRadius = UDim.new(0, 19)
avCorner.Parent = avatarFrame

local avatarImage = Instance.new("ImageLabel")
avatarImage.Size = UDim2.new(1, -4, 1, -4)
avatarImage.Position = UDim2.new(0, 2, 0, 2)
avatarImage.BackgroundTransparency = 1
avatarImage.Image = "zumbí.jpg"
avatarImage.ScaleType = Enum.ScaleType.Fit
avatarImage.Parent = avatarFrame

local avCorner2 = Instance.new("UICorner")
avCorner2.CornerRadius = UDim.new(0, 17)
avCorner2.Parent = avatarImage

-- НИК
local nickLabel = Instance.new("TextLabel")
nickLabel.Size = UDim2.new(0, 200, 0, 25)
nickLabel.Position = UDim2.new(0, 55, 0, 3)
nickLabel.BackgroundTransparency = 1
nickLabel.Text = "👤 " .. string.upper(player.Name)
nickLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
nickLabel.TextScaled = true
nickLabel.Font = Enum.Font.GothamBold
nickLabel.TextXAlignment = Enum.TextXAlignment.Left
nickLabel.Parent = header

-- СЧЁТЧИК ШАГОВ
local stepLabel = Instance.new("TextLabel")
stepLabel.Size = UDim2.new(0, 150, 0, 20)
stepLabel.Position = UDim2.new(0, 55, 0, 28)
stepLabel.BackgroundTransparency = 1
stepLabel.Text = "👟 0"
stepLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
stepLabel.TextScaled = true
stepLabel.Font = Enum.Font.GothamBold
stepLabel.TextXAlignment = Enum.TextXAlignment.Left
stepLabel.Parent = header

-- КНОПКИ СВЕРНУТЬ/ЗАКРЫТЬ
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 28, 0, 28)
toggleBtn.Position = UDim2.new(1, -70, 0, 11)
toggleBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.BackgroundTransparency = 0.8
toggleBtn.Text = "−"
toggleBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
toggleBtn.TextScaled = true
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.BorderSizePixel = 0
toggleBtn.Parent = header

local tCorner = Instance.new("UICorner")
tCorner.CornerRadius = UDim.new(0, 6)
tCorner.Parent = toggleBtn

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -38, 0, 11)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.BackgroundTransparency = 0.8
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = header

local cCorner = Instance.new("UICorner")
cCorner.CornerRadius = UDim.new(0, 6)
cCorner.Parent = closeBtn

-- ============================================
-- МЕНЮ КАТЕГОРИЙ (СПРАВА)
-- ============================================
local rightMenu = Instance.new("Frame")
rightMenu.Size = UDim2.new(0, 130, 1, -50)
rightMenu.Position = UDim2.new(1, -130, 0, 50)
rightMenu.BackgroundColor3 = Color3.fromRGB(15, 15, 30)
rightMenu.BackgroundTransparency = 0.3
rightMenu.BorderSizePixel = 0
rightMenu.Parent = mainFrame

local rightCorner = Instance.new("UICorner")
rightCorner.CornerRadius = UDim.new(0, 0)
rightCorner.Parent = rightMenu

-- ============================================
-- КОНТЕЙНЕР КОНТЕНТА
-- ============================================
local container = Instance.new("Frame")
container.Size = UDim2.new(1, -150, 1, -60)
container.Position = UDim2.new(0, 10, 0, 55)
container.BackgroundTransparency = 1
container.Parent = mainFrame

-- ============================================
-- ФУНКЦИЯ ОТРИСОВКИ КОНТЕНТА
-- ============================================
local function renderContent(tabName)
    for _, child in ipairs(container:GetChildren()) do
        child:Destroy()
    end

    if tabName == "Главная" then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = "🔥 ГЛАВНАЯ\n\n👤 " .. player.Name .. "\n👟 ШАГОВ: " .. state.stepCount
        lbl.TextColor3 = Color3.fromRGB(200, 200, 255)
        lbl.TextScaled = true
        lbl.Font = Enum.Font.GothamBold
        lbl.Parent = container

    elseif tabName == "Полет" then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 30)
        lbl.BackgroundTransparency = 1
        lbl.Text = "🚀 ПОЛЕТ"
        lbl.TextColor3 = Color3.fromRGB(200, 200, 255)
        lbl.TextScaled = true
        lbl.Font = Enum.Font.GothamBold
        lbl.Parent = container

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.4, 0, 0, 40)
        btn.Position = UDim2.new(0.3, 0, 0.15, 0)
        btn.BackgroundColor3 = state.flying and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(0, 150, 200)
        btn.Text = state.flying and "⏹ ОСТАНОВИТЬ" or "🚀 ВКЛЮЧИТЬ"
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextScaled = true
        btn.Font = Enum.Font.GothamBold
        btn.BorderSizePixel = 0
        btn.Parent = container
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = btn
        
        btn.MouseButton1Down:Connect(function()
            if state.flying then disableFly() else enableFly() end
            renderContent(state.currentTab)
        end)

        local noclipBtn = Instance.new("TextButton")
        noclipBtn.Size = UDim2.new(0.3, 0, 0, 30)
        noclipBtn.Position = UDim2.new(0.35, 0, 0.35, 0)
        noclipBtn.BackgroundColor3 = state.noclip and Color3.fromRGB(200, 100, 0) or Color3.fromRGB(80, 80, 80)
        noclipBtn.Text = "🌀 NOCLIP " .. (state.noclip and "ON" or "OFF")
        noclipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        noclipBtn.TextScaled = true
        noclipBtn.Font = Enum.Font.GothamBold
        noclipBtn.BorderSizePixel = 0
        noclipBtn.Parent = container
        
        local noclipCorner = Instance.new("UICorner")
        noclipCorner.CornerRadius = UDim.new(0, 8)
        noclipCorner.Parent = noclipBtn
        
        noclipBtn.MouseButton1Down:Connect(function()
            state.noclip = not state.noclip
            toggleNoclip(state.noclip)
            renderContent(state.currentTab)
        end)

        local godBtn = Instance.new("TextButton")
        godBtn.Size = UDim2.new(0.3, 0, 0, 30)
        godBtn.Position = UDim2.new(0.35, 0, 0.45, 0)
        godBtn.BackgroundColor3 = state.godmode and Color3.fromRGB(150, 0, 200) or Color3.fromRGB(80, 80, 80)
        godBtn.Text = "🛡️ GOD " .. (state.godmode and "ON" or "OFF")
        godBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        godBtn.TextScaled = true
        godBtn.Font = Enum.Font.GothamBold
        godBtn.BorderSizePixel = 0
        godBtn.Parent = container
        
        local godCorner = Instance.new("UICorner")
        godCorner.CornerRadius = UDim.new(0, 8)
        godCorner.Parent = godBtn
        
        godBtn.MouseButton1Down:Connect(function()
            state.godmode = not state.godmode
            toggleGodMode(state.godmode)
            renderContent(state.currentTab)
        end)

        local winBtn = Instance.new("TextButton")
        winBtn.Size = UDim2.new(0.4, 0, 0, 35)
        winBtn.Position = UDim2.new(0.3, 0, 0.55, 0)
        winBtn.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
        winBtn.Text = "🏆 WIN"
        winBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
        winBtn.TextScaled = true
        winBtn.Font = Enum.Font.GothamBold
        winBtn.BorderSizePixel = 0
        winBtn.Parent = container
        
        local winCorner = Instance.new("UICorner")
        winCorner.CornerRadius = UDim.new(0, 8)
        winCorner.Parent = winBtn
        
        winBtn.MouseButton1Down:Connect(function()
            autoWin()
        end)

    elseif tabName == "Фарм" then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 30)
        lbl.BackgroundTransparency = 1
        lbl.Text = "🏆 ФАРМ КУБКОВ"
        lbl.TextColor3 = Color3.fromRGB(200, 200, 255)
        lbl.TextScaled = true
        lbl.Font = Enum.Font.GothamBold
        lbl.Parent = container

        local startBtn = Instance.new("TextButton")
        startBtn.Size = UDim2.new(0.4, 0, 0, 40)
        startBtn.Position = UDim2.new(0.05, 0, 0.15, 0)
        startBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        startBtn.Text = "▶ ЗАПУСТИТЬ"
        startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        startBtn.TextScaled = true
        startBtn.Font = Enum.Font.GothamBold
        startBtn.BorderSizePixel = 0
        startBtn.Parent = container
        
        local startCorner = Instance.new("UICorner")
        startCorner.CornerRadius = UDim.new(0, 8)
        startCorner.Parent = startBtn
        
        startBtn.MouseButton1Down:Connect(function()
            startFarm()
            renderContent(state.currentTab)
        end)

        local stopBtn = Instance.new("TextButton")
        stopBtn.Size = UDim2.new(0.4, 0, 0, 40)
        stopBtn.Position = UDim2.new(0.55, 0, 0.15, 0)
        stopBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        stopBtn.Text = "⏹ ОСТАНОВИТЬ"
        stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        stopBtn.TextScaled = true
        stopBtn.Font = Enum.Font.GothamBold
        stopBtn.BorderSizePixel = 0
        stopBtn.Parent = container
        
        local stopCorner = Instance.new("UICorner")
        stopCorner.CornerRadius = UDim.new(0, 8)
        stopCorner.Parent = stopBtn
        
        stopBtn.MouseButton1Down:Connect(function()
            stopFarm()
            renderContent(state.currentTab)
        end)

        local status = Instance.new("TextLabel")
        status.Size = UDim2.new(1, 0, 0, 30)
        status.Position = UDim2.new(0, 0, 0.35, 0)
        status.BackgroundTransparency = 1
        status.Text = "СТАТУС: " .. (state.farmActive and "🟢 РАБОТАЕТ" or "🔴 ОСТАНОВЛЕН")
        status.TextColor3 = state.farmActive and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 100, 100)
        status.TextScaled = true
        status.Font = Enum.Font.GothamBold
        status.Parent = container

    elseif tabName == "Шаги" then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 30)
        lbl.BackgroundTransparency = 1
        lbl.Text = "👟 ФАРМ ШАГОВ (СПАМ W)"
        lbl.TextColor3 = Color3.fromRGB(200, 200, 255)
        lbl.TextScaled = true
        lbl.Font = Enum.Font.GothamBold
        lbl.Parent = container

        local info = Instance.new("TextLabel")
        info.Size = UDim2.new(1, 0, 0, 40)
        info.Position = UDim2.new(0, 0, 0.08, 0)
        info.BackgroundColor3 = Color3.fromRGB(10, 10, 25)
        info.BackgroundTransparency = 0.5
        info.Text = "👟 НАКРУЧЕНО: " .. state.stepCount .. "\n⚡ W НАЖАТИЙ: " .. state.wPressCount
        info.TextColor3 = Color3.fromRGB(255, 215, 0)
        info.TextScaled = true
        info.Font = Enum.Font.GothamBold
        info.Parent = container
        
        local infoCorner = Instance.new("UICorner")
        infoCorner.CornerRadius = UDim.new(0, 8)
        infoCorner.Parent = info

        local startBtn = Instance.new("TextButton")
        startBtn.Size = UDim2.new(0.4, 0, 0, 40)
        startBtn.Position = UDim2.new(0.05, 0, 0.25, 0)
        startBtn.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
        startBtn.Text = "👟 ЗАПУСТИТЬ"
        startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        startBtn.TextScaled = true
        startBtn.Font = Enum.Font.GothamBold
        startBtn.BorderSizePixel = 0
        startBtn.Parent = container
        
        local startCorner = Instance.new("UICorner")
        startCorner.CornerRadius = UDim.new(0, 8)
        startCorner.Parent = startBtn
        
        startBtn.MouseButton1Down:Connect(function()
            startStepFarm()
            renderContent(state.currentTab)
        end)

        local stopBtn = Instance.new("TextButton")
        stopBtn.Size = UDim2.new(0.4, 0, 0, 40)
        stopBtn.Position = UDim2.new(0.55, 0, 0.25, 0)
        stopBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        stopBtn.Text = "⏹ ОСТАНОВИТЬ"
        stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        stopBtn.TextScaled = true
        stopBtn.Font = Enum.Font.GothamBold
        stopBtn.BorderSizePixel = 0
        stopBtn.Parent = container
        
        local stopCorner = Instance.new("UICorner")
        stopCorner.CornerRadius = UDim.new(0, 8)
        stopCorner.Parent = stopBtn
        
        stopBtn.MouseButton1Down:Connect(function()
            stopStepFarm()
            renderContent(state.currentTab)
        end)

        local status = Instance.new("TextLabel")
        status.Size = UDim2.new(1, 0, 0, 30)
        status.Position = UDim2.new(0, 0, 0.4, 0)
        status.BackgroundTransparency = 1
        status.Text = "СТАТУС: " .. (state.stepFarmActive and "🟢 РАБОТАЕТ" or "🔴 ОСТАНОВЛЕН")
        status.TextColor3 = state.stepFarmActive and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 100, 100)
        status.TextScaled = true
        status.Font = Enum.Font.GothamBold
        status.Parent = container

    elseif tabName == "Настройки" then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 30)
        lbl.BackgroundTransparency = 1
        lbl.Text = "⚙️ НАСТРОЙКИ"
        lbl.TextColor3 = Color3.fromRGB(200, 200, 255)
        lbl.TextScaled = true
        lbl.Font = Enum.Font.GothamBold
        lbl.Parent = container

        local speedLabel = Instance.new("TextLabel")
        speedLabel.Size = UDim2.new(0.3, 0, 0, 25)
        speedLabel.Position = UDim2.new(0, 0, 0.1, 0)
        speedLabel.BackgroundTransparency = 1
        speedLabel.Text = "⚡ СКОРОСТЬ: " .. state.speed
        speedLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
        speedLabel.TextScaled = true
        speedLabel.Font = Enum.Font.Gotham
        speedLabel.TextXAlignment = Enum.TextXAlignment.Left
        speedLabel.Parent = container

        local slider = Instance.new("Frame")
        slider.Size = UDim2.new(0.4, 0, 0, 6)
        slider.Position = UDim2.new(0.32, 0, 0.15, 0)
        slider.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
        slider.BorderSizePixel = 0
        slider.Parent = container
        
        local sliderCorner = Instance.new("UICorner")
        sliderCorner.CornerRadius = UDim.new(0, 3)
        sliderCorner.Parent = slider

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(state.speed / 200, 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
        fill.BorderSizePixel = 0
        fill.Parent = slider
        
        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(0, 3)
        fillCorner.Parent = fill

        local knob = Instance.new("TextButton")
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = UDim2.new(state.speed / 200, -8, 0.5, -8)
        knob.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
        knob.Text = ""
        knob.BorderSizePixel = 0
        knob.Parent = slider
        
        local knobCorner = Instance.new("UICorner")
        knobCorner.CornerRadius = UDim.new(0, 8)
        knobCorner.Parent = knob

        local dragging = false
        slider.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
            end
        end)

        slider.InputEnded:Connect(function()
            dragging = false
        end)

        RunService.RenderStepped:Connect(function()
            if dragging then
                local mouse = player:GetMouse()
                local pos = slider.AbsolutePosition.X
                local size = slider.AbsoluteSize.X
                local percent = math.clamp((mouse.X - pos) / size, 0, 1)
                local val = math.floor(percent * 200 + 10)
                state.speed = val
                speedLabel.Text = "⚡ СКОРОСТЬ: " .. val
                fill.Size = UDim2.new(percent, 0, 1, 0)
                knob.Position = UDim2.new(percent, -8, 0.5, -8)
            end
        end)
    end
end

-- ============================================
-- СОЗДАНИЕ КНОПОК В МЕНЮ
-- ============================================
local tabs = {"Главная", "Полет", "Фарм", "Шаги", "Настройки"}
local tabButtons = {}

for i, tabName in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 36)
    btn.Position = UDim2.new(0, 5, 0, 10 + (i-1) * 46)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 45)
    btn.Text = tabName
    btn.TextColor3 = Color3.fromRGB(180, 180, 220)
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.Parent = rightMenu
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn
    
    btn.MouseButton1Down:Connect(function()
        state.currentTab = tabName
        for _, b in ipairs(tabButtons) do
            b.BackgroundColor3 = Color3.fromRGB(25, 25, 45)
            b.TextColor3 = Color3.fromRGB(180, 180, 220)
        end
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        renderContent(tabName)
    end)
    
    table.insert(tabButtons, btn)
end

-- Подсветка первой
tabButtons[1].BackgroundColor3 = Color3.fromRGB(60, 60, 120)
tabButtons[1].TextColor3 = Color3.fromRGB(255, 255, 255)

-- ============================================
-- DRAG
-- ============================================
header.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        state.isDragging = true
        state.dragOffset = Vector2.new(
            i.Position.X - mainFrame.AbsolutePosition.X,
            i.Position.Y - mainFrame.AbsolutePosition.Y
        )
    end
end)

header.InputChanged:Connect(function(i)
    if state.isDragging then
        mainFrame.Position = UDim2.new(
            0, i.Position.X - state.dragOffset.X,
            0, i.Position.Y - state.dragOffset.Y
        )
    end
end)

header.InputEnded:Connect(function()
    state.isDragging = false
end)

-- ============================================
-- КНОПКИ СВЕРНУТЬ/ЗАКРЫТЬ
-- ============================================
toggleBtn.MouseButton1Down:Connect(function()
    local hidden = rightMenu.Visible == false
    rightMenu.Visible = hidden
    container.Visible = hidden
    mainFrame:TweenSize(hidden and UDim2.new(0, 780, 0, 420) or UDim2.new(0, 780, 0, 50), "Out", "Quad", 0.3)
    toggleBtn.Text = hidden and "−" or "+"
end)

closeBtn.MouseButton1Down:Connect(function()
    mainFrame:TweenSize(UDim2.new(0, 0, 0, 0), "Out", "Quad", 0.3)
    wait(0.3)
    screenGui.Enabled = false
end)

-- ============================================
-- ОБНОВЛЕНИЕ СЧЁТЧИКА
-- ============================================
spawn(function()
    while wait(0.5) do
        stepLabel.Text = "👟 " .. state.stepCount
        if state.currentTab == "Главная" or state.currentTab == "Шаги" then
            renderContent(state.currentTab)
        end
    end
end)

-- ============================================
-- ПЕРЕПОДКЛЮЧЕНИЕ
-- ============================================
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    rootPart = character:WaitForChild("HumanoidRootPart", 5)
    humanoid = character:FindFirstChildOfClass("Humanoid")
    if state.noclip then toggleNoclip(true) end
    if state.godmode then toggleGodMode(true) end
    if state.flying then
        disableFly()
        wait(0.5)
        enableFly()
    end
end)

-- ============================================
-- СТАРТ
-- ============================================
toggleNoclip(true)
toggleGodMode(true)
renderContent("Главная")

print("=========================================")
print("✅ ULTIMATE FLY (ФИНАЛЬНАЯ ВЕРСИЯ)")
print("📂 ВКЛАДКИ РАБОТАЮТ НА 100%")
print("👤 " .. string.upper(player.Name))
print("=========================================")
