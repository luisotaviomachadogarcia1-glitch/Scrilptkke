-- ============================================================
-- Universal Script com Aimbot Lock + Scroll GUI + ESP MM2
-- Para Delta Executor
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ==================== CONFIGURAÇÕES ====================
local Config = {
    WalkSpeed = 16,
    JumpPower = 50,
    InfiniteJump = true,
    FullBright = false,
    NoClip = false,

    -- Aimbot
    AimbotEnabled = false,
    AimbotKey = Enum.KeyCode.E,
    AimbotSmoothness = 0.5,
    AimbotFOV = 500,
    TeamCheck = true,
    WallCheck = false,
    TargetPart = "Head",
    LockMode = true,

    -- ESP
    ESPEnabled = false,
    ESPBoxes = false,
    ESPNames = true,
    ESPTracers = false,
    ESPColors = {
        Murderer = Color3.fromRGB(255, 40, 40),      -- Vermelho
        Sheriff  = Color3.fromRGB(40, 120, 255),     -- Azul
        Innocent = Color3.fromRGB(40, 220, 80),      -- Verde
        Unknown  = Color3.fromRGB(255, 255, 255),    -- Branco
    },
}

-- ==================== VARIÁVEIS ====================
local CurrentTarget = nil
local CurrentTargetPart = nil
local ESPObjects = {} -- [player] = {highlight=, nameTag=, box=, tracer=, billboard=}
local ESPGui = nil

-- ==================== FUNÇÕES BÁSICAS ====================

local function setupInfiniteJump()
    UserInputService.JumpRequest:Connect(function()
        if Config.InfiniteJump then
            local character = LocalPlayer.Character
            if character then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end
    end)
end

local function setupNoClip()
    RunService.Stepped:Connect(function()
        if Config.NoClip and LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

local function setFullBright(state)
    Config.FullBright = state
    local lighting = game:GetService("Lighting")
    if state then
        lighting.Ambient = Color3.new(1, 1, 1)
        lighting.Brightness = 3
        lighting.FogEnd = 100000
        lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    else
        lighting.Ambient = Color3.new(0.5, 0.5, 0.5)
        lighting.Brightness = 2
        lighting.FogEnd = 1000
        lighting.OutdoorAmbient = Color3.new(0.5, 0.5, 0.5)
    end
end

-- ==================== DETECÇÃO DE ROLE (MM2) ====================

-- Tenta descobrir a role do player por heurísticas
local function detectRole(plr)
    if not plr or not plr.Character then return "Unknown" end
    local character = plr.Character
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return "Unknown" end

    -- 1) Procura tags/atributos diretos (alguns mods expõem)
    if plr:GetAttribute("Role") then return plr:GetAttribute("Role") end
    if character:GetAttribute("Role") then return character:GetAttribute("Role") end

    -- 2) Procura por ferramentas (Tools) no character
    for _, tool in ipairs(character:GetChildren()) do
        if tool:IsA("Tool") then
            local n = string.lower(tool.Name)
            if n:find("knife") or n:find("murder") or n:find("facão")
               or n:find("dagger") or n:find("sword") and not n:find("sheriff") then
                return "Murderer"
            end
            if n:find("gun") or n:find("revolver") or n:find("pistol")
               or n:find("sheriff") or n:find("firearm") then
                return "Sheriff"
            end
        end
    end

    -- 3) Procura na mochila (Backpack) também
    local backpack = plr:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local n = string.lower(tool.Name)
                if n:find("knife") or n:find("murder") or n:find("dagger") then
                    return "Murderer"
                end
                if n:find("gun") or n:find("revolver") or n:find("pistol") or n:find("sheriff") then
                    return "Sheriff"
                end
            end
        end
    end

    -- 4) Checa Team (alguns mods do MM2 usam Team para diferenciar)
    if plr.Team then
        local tn = string.lower(plr.Team.Name)
        if tn:find("murder") then return "Murderer" end
        if tn:find("sheriff") then return "Sheriff" end
        if tn:find("innocent") then return "Innocent" end
    end

    -- 5) Se não achou nada suspeito, é inocente
    return "Innocent"
end

local function getRoleColor(role)
    return Config.ESPColors[role] or Config.ESPColors.Unknown
end

-- ==================== ESP ====================

local function createESPGui()
    if ESPGui and ESPGui.Parent then return end
    ESPGui = Instance.new("ScreenGui")
    ESPGui.Name = "ESPGui"
    ESPGui.ResetOnSpawn = false
    ESPGui.IgnoreGuiInset = true
    ESPGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ESPGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local function removeESP(plr)
    local data = ESPObjects[plr]
    if not data then return end
    for _, obj in pairs(data) do
        if obj and obj.Parent then obj:Destroy() end
    end
    ESPObjects[plr] = nil
end

local function createESP(plr)
    if ESPObjects[plr] then return end
    if not plr.Character then return end
    if plr == LocalPlayer then return end

    local role = detectRole(plr)
    local color = getRoleColor(role)

    -- Highlight (contorno no corpo)
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Highlight"
    highlight.Adornee = plr.Character
    highlight.FillColor = color
    highlight.FillTransparency = 0.6
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = plr.Character

    -- BillboardGui com nome + role
    local head = plr.Character:FindFirstChild("Head")
    local billboard = nil
    if head then
        billboard = Instance.new("BillboardGui")
        billboard.Name = "ESP_Billboard"
        billboard.Adornee = head
        billboard.Size = UDim2.new(0, 160, 0, 40)
        billboard.StudsOffset = Vector3.new(0, 2.5, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = head

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
        nameLabel.Position = UDim2.new(0, 0, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = plr.Name
        nameLabel.TextColor3 = color
        nameLabel.TextStrokeTransparency = 0
        nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        nameLabel.TextSize = 14
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.Parent = billboard

        local roleLabel = Instance.new("TextLabel")
        roleLabel.Size = UDim2.new(1, 0, 0.5, 0)
        roleLabel.Position = UDim2.new(0, 0, 0.5, 0)
        roleLabel.BackgroundTransparency = 1
        roleLabel.Text = "[" .. role .. "]"
        roleLabel.TextColor3 = color
        roleLabel.TextStrokeTransparency = 0
        roleLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        roleLabel.TextSize = 12
        roleLabel.Font = Enum.Font.Gotham
        roleLabel.Parent = billboard
    end

    ESPObjects[plr] = {
        highlight = highlight,
        billboard = billboard,
        role = role,
    }
end

local function updateESP(plr)
    local data = ESPObjects[plr]
    if not data then return end
    if not plr.Character then
        removeESP(plr)
        return
    end

    local newRole = detectRole(plr)
    local newColor = getRoleColor(newRole)

    if newRole ~= data.role then
        data.role = newRole
        if data.highlight then
            data.highlight.FillColor = newColor
            data.highlight.OutlineColor = newColor
        end
        if data.billboard then
            local labels = data.billboard:GetChildren()
            for _, l in ipairs(labels) do
                if l:IsA("TextLabel") then
                    l.TextColor3 = newColor
                    if l.Text:find("%[") then
                        l.Text = "[" .. newRole .. "]"
                    end
                end
            end
        end
    end
end

local function refreshAllESP()
    -- Remove de quem saiu
    for plr, _ in pairs(ESPObjects) do
        if not plr.Parent or not plr.Character then
            removeESP(plr)
        end
    end
    -- Adiciona/atualiza
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            if ESPObjects[plr] then
                updateESP(plr)
                -- Aplica visibilidade
                local data = ESPObjects[plr]
                if data.highlight then data.highlight.Enabled = Config.ESPEnabled end
                if data.billboard then data.billboard.Enabled = Config.ESPEnabled and Config.ESPNames end
            else
                if Config.ESPEnabled then
                    createESP(plr)
                end
            end
        end
    end
end

local function setupESP()
    createESPGui()

    -- Aplica visibilidade em todos os ESPs existentes
    local function applyVisibility()
        for _, data in pairs(ESPObjects) do
            if data.highlight then data.highlight.Enabled = Config.ESPEnabled end
            if data.billboard then data.billboard.Enabled = Config.ESPEnabled and Config.ESPNames end
        end
    end

    -- Reage a mudanças de config
    RunService.Heartbeat:Connect(function()
        applyVisibility()
        refreshAllESP()
    end)

    -- Eventos de players
    Players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(function()
            task.wait(0.5)
            if Config.ESPEnabled then createESP(plr) end
        end)
    end)

    Players.PlayerRemoving:Connect(function(plr)
        removeESP(plr)
    end)

    -- Loop principal (atualiza roles a cada 1s)
    task.spawn(function()
        while true do
            task.wait(1)
            if Config.ESPEnabled then
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer and plr.Character then
                        if not ESPObjects[plr] then
                            createESP(plr)
                        else
                            updateESP(plr)
                        end
                    end
                end
            end
        end
    end)

    -- Aplica nos players já presentes
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if plr.Character then
                createESP(plr)
            end
            plr.CharacterAdded:Connect(function()
                task.wait(0.5)
                if Config.ESPEnabled then createESP(plr) end
            end)
        end
    end
end

-- ==================== AIMBOT ====================

local function isValidTarget(plr)
    if not plr or plr == LocalPlayer then return false end
    if not plr.Character then return false end

    local humanoid = plr.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end

    if Config.TeamCheck and plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then
        return false
    end

    local targetPart = plr.Character:FindFirstChild(Config.TargetPart)
    if not targetPart then return false end

    if Config.WallCheck then
        local rayOrigin = Camera.CFrame.Position
        local dir = (targetPart.Position - rayOrigin)
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {LocalPlayer.Character, plr.Character}
        local result = Workspace:Raycast(rayOrigin, dir, rayParams)
        if result then return false end
    end

    return true, targetPart
end

local function getClosestTarget()
    local closest, closestPart = nil, nil
    local shortestDist = math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, plr in ipairs(Players:GetPlayers()) do
        local valid, part = isValidTarget(plr)
        if valid then
            local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                if dist <= Config.AimbotFOV and dist < shortestDist then
                    shortestDist = dist
                    closest = plr
                    closestPart = part
                end
            end
        end
    end

    return closest, closestPart
end

local function setupAimbot()
    RunService.RenderStepped:Connect(function()
        if not Config.AimbotEnabled then
            CurrentTarget = nil
            CurrentTargetPart = nil
            return
        end

        local target, targetPart = getClosestTarget()
        CurrentTarget = target
        CurrentTargetPart = targetPart

        if not target or not targetPart then return end

        local shouldLock = Config.LockMode or UserInputService:IsKeyDown(Config.AimbotKey)
        if shouldLock then
            local targetPos = targetPart.Position
            local newCFrame = CFrame.new(Camera.CFrame.Position, targetPos)
            Camera.CFrame = Camera.CFrame:Lerp(newCFrame, Config.AimbotSmoothness)
        end
    end)
end

-- ==================== GUI ====================

local function createMenu()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "UniversalMenu"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 300, 0, 450)
    MainFrame.Position = UDim2.new(0.5, -150, 0.5, -225)
    MainFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.ClipsDescendants = true
    MainFrame.ZIndex = 5
    MainFrame.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 10)
    MainCorner.Parent = MainFrame

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(80, 130, 255)
    MainStroke.Thickness = 1.5
    MainStroke.Parent = MainFrame

    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 40)
    TitleBar.BackgroundColor3 = Color3.fromRGB(38, 48, 90)
    TitleBar.BorderSizePixel = 0
    TitleBar.ZIndex = 10
    TitleBar.Parent = MainFrame

    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 10)
    TitleCorner.Parent = TitleBar

    local TitleFix = Instance.new("Frame")
    TitleFix.Size = UDim2.new(1, 0, 0, 10)
    TitleFix.Position = UDim2.new(0, 0, 1, -10)
    TitleFix.BackgroundColor3 = Color3.fromRGB(38, 48, 90)
    TitleFix.BorderSizePixel = 0
    TitleFix.ZIndex = 10
    TitleFix.Parent = TitleBar

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -50, 1, 0)
    Title.Position = UDim2.new(0, 12, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "⚡ Universal Script"
    Title.TextColor3 = Color3.new(1, 1, 1)
    Title.TextSize = 16
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.ZIndex = 11
    Title.Parent = TitleBar

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 28, 0, 28)
    CloseBtn.Position = UDim2.new(1, -34, 0, 6)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Color3.new(1, 1, 1)
    CloseBtn.TextSize = 14
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.ZIndex = 12
    CloseBtn.Parent = TitleBar

    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseBtn

    local OpenBtn = Instance.new("TextButton")
    OpenBtn.Size = UDim2.new(0, 50, 0, 50)
    OpenBtn.Position = UDim2.new(0, 20, 0.5, -25)
    OpenBtn.BackgroundColor3 = Color3.fromRGB(38, 48, 90)
    OpenBtn.Text = "⚡"
    OpenBtn.TextColor3 = Color3.new(1, 1, 1)
    OpenBtn.TextSize = 24
    OpenBtn.Font = Enum.Font.GothamBold
    OpenBtn.Visible = false
    OpenBtn.ZIndex = 100
    OpenBtn.Parent = ScreenGui

    local OpenCorner = Instance.new("UICorner")
    OpenCorner.CornerRadius = UDim.new(1, 0)
    OpenCorner.Parent = OpenBtn

    local OpenStroke = Instance.new("UIStroke")
    OpenStroke.Color = Color3.fromRGB(80, 130, 255)
    OpenStroke.Thickness = 2
    OpenStroke.Parent = OpenBtn

    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Name = "Scroll"
    Scroll.Size = UDim2.new(1, 0, 1, -40)
    Scroll.Position = UDim2.new(0, 0, 0, 40)
    Scroll.BackgroundTransparency = 1
    Scroll.BorderSizePixel = 0
    Scroll.ScrollBarThickness = 6
    Scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 130, 255)
    Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    Scroll.ScrollingDirection = Enum.ScrollingDirection.Y
    Scroll.ZIndex = 5
    Scroll.Parent = MainFrame

    local ScrollLayout = Instance.new("UIListLayout")
    ScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ScrollLayout.Padding = UDim.new(0, 8)
    ScrollLayout.Parent = Scroll

    local ScrollPadding = Instance.new("UIPadding")
    ScrollPadding.PaddingTop = UDim.new(0, 10)
    ScrollPadding.PaddingBottom = UDim.new(0, 10)
    ScrollPadding.PaddingLeft = UDim.new(0, 10)
    ScrollPadding.PaddingRight = UDim.new(0, 10)
    ScrollPadding.Parent = Scroll

    ScrollLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        Scroll.CanvasSize = UDim2.new(0, 0, 0, ScrollLayout.AbsoluteContentSize.Y + 20)
    end)

    local function createToggle(text, initial, callback)
        local state = initial

        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(1, 0, 0, 36)
        Btn.BackgroundColor3 = state and Color3.fromRGB(0, 140, 60) or Color3.fromRGB(50, 55, 80)
        Btn.Text = ""
        Btn.AutoButtonColor = false
        Btn.ZIndex = 6
        Btn.Parent = Scroll

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = Btn

        local s = Instance.new("UIStroke")
        s.Color = Color3.fromRGB(90, 100, 140)
        s.Thickness = 1
        s.Parent = Btn

        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(1, -70, 1, 0)
        Label.Position = UDim2.new(0, 10, 0, 0)
        Label.BackgroundTransparency = 1
        Label.Text = text
        Label.TextColor3 = Color3.new(1, 1, 1)
        Label.TextSize = 14
        Label.Font = Enum.Font.GothamSemibold
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.ZIndex = 7
        Label.Parent = Btn

        local StateLabel = Instance.new("TextLabel")
        StateLabel.Size = UDim2.new(0, 55, 1, 0)
        StateLabel.Position = UDim2.new(1, -60, 0, 0)
        StateLabel.BackgroundTransparency = 1
        StateLabel.Text = state and "ON" or "OFF"
        StateLabel.TextColor3 = state and Color3.fromRGB(120, 255, 150) or Color3.fromRGB(200, 200, 200)
        StateLabel.TextSize = 13
        StateLabel.Font = Enum.Font.GothamBold
        StateLabel.TextXAlignment = Enum.TextXAlignment.Right
        StateLabel.ZIndex = 7
        StateLabel.Parent = Btn

        local function update()
            StateLabel.Text = state and "ON" or "OFF"
            StateLabel.TextColor3 = state and Color3.fromRGB(120, 255, 150) or Color3.fromRGB(200, 200, 200)
            Btn.BackgroundColor3 = state and Color3.fromRGB(0, 140, 60) or Color3.fromRGB(50, 55, 80)
        end

        Btn.MouseButton1Click:Connect(function()
            state = not state
            update()
            if callback then callback(state) end
        end)

        return Btn
    end

    local function createSection(text)
        local Sec = Instance.new("TextLabel")
        Sec.Size = UDim2.new(1, 0, 0, 24)
        Sec.BackgroundTransparency = 1
        Sec.Text = text
        Sec.TextColor3 = Color3.fromRGB(120, 180, 255)
        Sec.TextSize = 13
        Sec.Font = Enum.Font.GothamBold
        Sec.TextXAlignment = Enum.TextXAlignment.Left
        Sec.ZIndex = 6
        Sec.Parent = Scroll
        return Sec
    end

    -- ===== SEÇÃO ESP =====
    createSection("👁️ ESP (MM2)")

    createToggle("ESP Ativado", Config.ESPEnabled, function(v)
        Config.ESPEnabled = v
        if v then
            refreshAllESP()
        end
    end)

    createToggle("Mostrar Nome / Role", Config.ESPNames, function(v)
        Config.ESPNames = v
    end)

    -- Legenda de cores
    local Legend = Instance.new("TextLabel")
    Legend.Size = UDim2.new(1, 0, 0, 50)
    Legend.BackgroundTransparency = 1
    Legend.Text = "🔴 Murderer   🔵 Sheriff   🟢 Innocent   ⚪ Unknown"
    Legend.TextColor3 = Color3.fromRGB(200, 200, 200)
    Legend.TextSize = 11
    Legend.Font = Enum.Font.Gotham
    Legend.TextWrapped = true
    Legend.ZIndex = 6
    Legend.Parent = Scroll

    -- ===== SEÇÃO AIMBOT =====
    createSection("🎯 AIMBOT")

    createToggle("Aimbot", Config.AimbotEnabled, function(v)
        Config.AimbotEnabled = v
    end)

    createToggle("Lock Mode (grudar na cabeça)", Config.LockMode, function(v)
        Config.LockMode = v
    end)

    createToggle("Team Check", Config.TeamCheck, function(v)
        Config.TeamCheck = v
    end)

    createToggle("Wall Check", Config.WallCheck, function(v)
        Config.WallCheck = v
    end)

    local TargetBtn = Instance.new("TextButton")
    TargetBtn.Size = UDim2.new(1, 0, 0, 36)
    TargetBtn.BackgroundColor3 = Color3.fromRGB(50, 55, 80)
    TargetBtn.Text = ""
    TargetBtn.AutoButtonColor = false
    TargetBtn.ZIndex = 6
    TargetBtn.Parent = Scroll

    local TC = Instance.new("UICorner")
    TC.CornerRadius = UDim.new(0, 6)
    TC.Parent = TargetBtn

    local TS = Instance.new("UIStroke")
    TS.Color = Color3.fromRGB(90, 100, 140)
    TS.Thickness = 1
    TS.Parent = TargetBtn

    local TLabel = Instance.new("TextLabel")
    TLabel.Size = UDim2.new(1, -80, 1, 0)
    TLabel.Position = UDim2.new(0, 10, 0, 0)
    TLabel.BackgroundTransparency = 1
    TLabel.Text = "Target Part"
    TLabel.TextColor3 = Color3.new(1, 1, 1)
    TLabel.TextSize = 14
    TLabel.Font = Enum.Font.GothamSemibold
    TLabel.TextXAlignment = Enum.TextXAlignment.Left
    TLabel.ZIndex = 7
    TLabel.Parent = TargetBtn

    local TState = Instance.new("TextLabel")
    TState.Size = UDim2.new(0, 65, 1, 0)
    TState.Position = UDim2.new(1, -70, 0, 0)
    TState.BackgroundTransparency = 1
    TState.Text = Config.TargetPart
    TState.TextColor3 = Color3.fromRGB(255, 220, 120)
    TState.TextSize = 12
    TState.Font = Enum.Font.GothamBold
    TState.TextXAlignment = Enum.TextXAlignment.Right
    TState.ZIndex = 7
    TState.Parent = TargetBtn

    TargetBtn.MouseButton1Click:Connect(function()
        if Config.TargetPart == "Head" then
            Config.TargetPart = "HumanoidRootPart"
        else
            Config.TargetPart = "Head"
        end
        TState.Text = Config.TargetPart
    end)

    -- ===== SEÇÃO MOVIMENTO =====
    createSection("🏃 MOVIMENTO")

    createToggle("No Clip", Config.NoClip, function(v)
        Config.NoClip = v
    end)

    createToggle("Infinite Jump", Config.InfiniteJump, function(v)
        Config.InfiniteJump = v
    end)

    createToggle("Full Bright", Config.FullBright, function(v)
        setFullBright(v)
    end)

    -- ===== SEÇÃO AÇÕES =====
    createSection("⚙️ AÇÕES")

    local ResetBtn = Instance.new("TextButton")
    ResetBtn.Size = UDim2.new(1, 0, 0, 36)
    ResetBtn.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
    ResetBtn.Text = "Reset Character"
    ResetBtn.TextColor3 = Color3.new(1, 1, 1)
    ResetBtn.TextSize = 14
    ResetBtn.Font = Enum.Font.GothamSemibold
    ResetBtn.AutoButtonColor = false
    ResetBtn.ZIndex = 6
    ResetBtn.Parent = Scroll

    local RC = Instance.new("UICorner")
    RC.CornerRadius = UDim.new(0, 6)
    RC.Parent = ResetBtn

    ResetBtn.MouseButton1Click:Connect(function()
        if LocalPlayer.Character then
            LocalPlayer.Character:BreakJoints()
        end
    end)

    local Info = Instance.new("TextLabel")
    Info.Size = UDim2.new(1, 0, 0, 40)
    Info.BackgroundTransparency = 1
    Info.Text = "Aimbot Key: [E] • INSERT abre/fecha\nESP cores: 🔴Murder 🔵Sheriff 🟢Innocent ⚪?"
    Info.TextColor3 = Color3.fromRGB(160, 160, 180)
    Info.TextSize = 11
    Info.Font = Enum.Font.Gotham
    Info.TextWrapped = true
    Info.ZIndex = 6
    Info.Parent = Scroll

    CloseBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        OpenBtn.Visible = true
    end)

    OpenBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = true
        OpenBtn.Visible = false
    end)

    -- Drag da MainFrame
    local dragging, dragInput, dragStart, startPos

    local function updateDrag(input)
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end

    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    TitleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            updateDrag(input)
        end
    end)

    -- Drag do OpenBtn
    local openDrag = false
    local openDragStart, openStartPos

    OpenBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            openDrag = true
            openDragStart = input.Position
            openStartPos = OpenBtn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    openDrag = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if openDrag and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - openDragStart
            OpenBtn.Position = UDim2.new(
                openStartPos.X.Scale, openStartPos.X.Offset + delta.X,
                openStartPos.Y.Scale, openStartPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputBegan
