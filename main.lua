-- Rayfield UIのセットアップ
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ウィンドウの作成
local Window = Rayfield:CreateWindow({
    Name = "Syu_uhub",
    LoadingTitle = "Syu_uhub",
    LoadingSubtitle = "by Syu_uhub",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "Syu_uhub",
        FileName = "Config"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    },
    KeySystem = false,
})

-- メインタブの作成
local MainTab = Window:CreateTab("Main", 4483362458)
local SettingsTab = Window:CreateTab("Settings", 4483362458)

-- グローバル変数
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CurrentCamera = Workspace.CurrentCamera

-- 設定変数
local Settings = {
    AimlockEnabled = false,
    AimlockDistance = 5,
    LockDuration = 3,
    ActivationDelay = 0.5,
    ESPEnabled = false,
    TracerColor = Color3.fromRGB(255, 0, 0),
    TracerThickness = 0.1,
    TracerTransparency = 0.8
}

-- ESP関連の変数
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "Syu_uhub_ESP"
ESPFolder.Parent = Workspace

local tracers = {}

-- ユーティリティ関数
function GetClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = Settings.AimlockDistance
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (LocalPlayer.Character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
            if distance <= shortestDistance then
                shortestDistance = distance
                closestPlayer = player
            end
        end
    end
    
    return closestPlayer, shortestDistance
end

function AimAtHead(player)
    if player and player.Character and player.Character:FindFirstChild("Head") then
        local head = player.Character.Head
        CurrentCamera.CFrame = CFrame.new(CurrentCamera.CFrame.Position, head.Position)
    end
end

function CreateTracer(player)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Color = Settings.TracerColor
    tracer.Thickness = Settings.TracerThickness
    tracer.Transparency = Settings.TracerTransparency
    
    tracers[player] = tracer
end

function UpdateTracer(player, tracer)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        tracer.Visible = false
        return
    end
    
    local rootPart = player.Character.HumanoidRootPart
    local screenPosition, onScreen = CurrentCamera:WorldToViewportPoint(rootPart.Position)
    
    if onScreen then
        tracer.From = Vector2.new(CurrentCamera.ViewportSize.X / 2, CurrentCamera.ViewportSize.Y)
        tracer.To = Vector2.new(screenPosition.X, screenPosition.Y)
        tracer.Visible = true
    else
        tracer.Visible = false
    end
end

-- メインタブの要素
local AimlockToggle = MainTab:CreateToggle({
    Name = "Aimlock",
    CurrentValue = false,
    Flag = "AimlockToggle",
    Callback = function(Value)
        Settings.AimlockEnabled = Value
    end,
})

local ESPToggle = MainTab:CreateToggle({
    Name = "ESP Tracer",
    CurrentValue = false,
    Flag = "ESPToggle",
    Callback = function(Value)
        Settings.ESPEnabled = Value
        
        if not Value then
            for player, tracer in pairs(tracers) do
                if tracer then
                    tracer:Remove()
                end
            end
            tracers = {}
        end
    end,
})

-- 設定タブの要素
local DistanceSlider = SettingsTab:CreateSlider({
    Name = "Aimlock Distance (Studs)",
    Range = {1, 50},
    Increment = 1,
    Suffix = "Studs",
    CurrentValue = 5,
    Flag = "DistanceSlider",
    Callback = function(Value)
        Settings.AimlockDistance = Value
    end,
})

local DurationSlider = SettingsTab:CreateSlider({
    Name = "Lock Duration (Seconds)",
    Range = {0.1, 10},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = 3,
    Flag = "DurationSlider",
    Callback = function(Value)
        Settings.LockDuration = Value
    end,
})

local DelaySlider = SettingsTab:CreateSlider({
    Name = "Activation Delay (Seconds)",
    Range = {0, 5},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = 0.5,
    Flag = "DelaySlider",
    Callback = function(Value)
        Settings.ActivationDelay = Value
    end,
})

local TracerColorPicker = SettingsTab:CreateColorPicker({
    Name = "Tracer Color",
    Color = Color3.fromRGB(255, 0, 0),
    Flag = "TracerColorPicker",
    Callback = function(Value)
        Settings.TracerColor = Value
        for _, tracer in pairs(tracers) do
            if tracer then
                tracer.Color = Value
            end
        end
    end
})

local TracerThicknessSlider = SettingsTab:CreateSlider({
    Name = "Tracer Thickness",
    Range = {0.1, 5},
    Increment = 0.1,
    Suffix = "",
    CurrentValue = 0.1,
    Flag = "TracerThicknessSlider",
    Callback = function(Value)
        Settings.TracerThickness = Value
        for _, tracer in pairs(tracers) do
            if tracer then
                tracer.Thickness = Value
            end
        end
    end,
})

local TracerTransparencySlider = SettingsTab:CreateSlider({
    Name = "Tracer Transparency",
    Range = {0, 1},
    Increment = 0.1,
    Suffix = "",
    CurrentValue = 0.8,
    Flag = "TracerTransparencySlider",
    Callback = function(Value)
        Settings.TracerTransparency = Value
        for _, tracer in pairs(tracers) do
            if tracer then
                tracer.Transparency = Value
            end
        end
    end,
})

-- メインループ
local aimlockActive = false
local aimlockStartTime = 0
local activationTimer = 0
local lastClosestPlayer = nil

RunService.RenderStepped:Connect(function(deltaTime)
    -- ESPの更新
    if Settings.ESPEnabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                if not tracers[player] then
                    CreateTracer(player)
                else
                    UpdateTracer(player, tracers[player])
                end
            end
        end
        
        -- 削除されたプレイヤーのトレーサーをクリーンアップ
        for player, tracer in pairs(tracers) do
            if not Players:FindFirstChild(player.Name) then
                if tracer then
                    tracer:Remove()
                end
                tracers[player] = nil
            end
        end
    else
        -- ESPが無効の時はトレーサーを非表示にする
        for _, tracer in pairs(tracers) do
            if tracer then
                tracer.Visible = false
            end
        end
    end
    
    -- Aimlockのロジック
    if Settings.AimlockEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local closestPlayer, distance = GetClosestPlayer()
        
        if closestPlayer then
            if lastClosestPlayer ~= closestPlayer then
                activationTimer = 0
            end
            
            activationTimer = activationTimer + deltaTime
            
            if activationTimer >= Settings.ActivationDelay then
                if not aimlockActive then
                    aimlockActive = true
                    aimlockStartTime = tick()
                end
                
                if aimlockActive then
                    AimAtHead(closestPlayer)
                    
                    -- ロック時間が経過したらリセット
                    if tick() - aimlockStartTime >= Settings.LockDuration then
                        aimlockActive = false
                        activationTimer = 0
                    end
                end
            end
        else
            aimlockActive = false
            activationTimer = 0
        end
        
        lastClosestPlayer = closestPlayer
    else
        aimlockActive = false
        activationTimer = 0
        lastClosestPlayer = nil
    end
end)

-- プレイヤーが追加された時の処理
Players.PlayerAdded:Connect(function(player)
    if Settings.ESPEnabled then
        CreateTracer(player)
    end
end)

-- プレイヤーが削除された時の処理
Players.PlayerRemoving:Connect(function(player)
    if tracers[player] then
        tracers[player]:Remove()
        tracers[player] = nil
    end
end)

-- 初期化時に既存のプレイヤー用のトレーサーを作成
for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        CreateTracer(player)
    end
end

-- 通知
Rayfield:Notify({
    Title = "Syu_uhub Loaded",
    Content = "Aimlock and ESP Tracer have been loaded successfully!",
    Duration = 5,
    Image = 4483362458,
})
