-- Rayfield UIライブラリの読み込み
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- 変数の初期化
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- 設定値
local Settings = {
    LockEnabled = false,
    LockDistance = 5, -- 作動距離（スタッド）
    LockDuration = 0.5, -- 固定時間（秒）
    CooldownTime = 1, -- 再作動までの時間（秒）
    TraceEnabled = false,
    TraceThickness = 1 -- Traceの太さ
}

-- 状態管理
local isLocking = false
local lastLockTime = 0
local lockConnection = nil
local traceConnections = {}
local currentTarget = nil

-- Rayfield ウィンドウの作成
local Window = Rayfield:CreateWindow({
    Name = "Syu_uhub",
    LoadingTitle = "Syu_uhub Loading",
    LoadingSubtitle = "by Syu",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "SyuHub",
        FileName = "SyuHubConfig"
    }
})

-- Mainタブ
local MainTab = Window:CreateTab("Main", 4483362458)

-- 設定タブ
local SettingsTab = Window:CreateTab("Settings", 4483345998)

-- 最も近い敵を取得する関数
local function GetClosestEnemy()
    local closestPlayer = nil
    local shortestDistance = math.huge
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Head") then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local distance = (LocalPlayer.Character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    closestPlayer = player
                end
            end
        end
    end
    
    return closestPlayer, shortestDistance
end

-- 頭に視点を固定する関数
local function LockToHead()
    if not Settings.LockEnabled then return end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local currentTime = tick()
    if currentTime - lastLockTime < Settings.CooldownTime then return end
    if isLocking then return end
    
    local enemy, distance = GetClosestEnemy()
    
    if enemy and distance <= Settings.LockDistance then
        isLocking = true
        currentTarget = enemy
        lastLockTime = currentTime
        local lockStartTime = currentTime
        
        if lockConnection then
            lockConnection:Disconnect()
        end
        
        lockConnection = RunService.RenderStepped:Connect(function()
            if not Settings.LockEnabled or not currentTarget or not currentTarget.Character or not currentTarget.Character:FindFirstChild("Head") then
                lockConnection:Disconnect()
                isLocking = false
                currentTarget = nil
                return
            end
            
            -- 設定距離以上離れたら自動解除
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local currentDistance = (LocalPlayer.Character.HumanoidRootPart.Position - currentTarget.Character.HumanoidRootPart.Position).Magnitude
                if currentDistance > Settings.LockDistance then
                    lockConnection:Disconnect()
                    isLocking = false
                    currentTarget = nil
                    return
                end
            end
            
            -- 固定時間経過で解除
            if tick() - lockStartTime >= Settings.LockDuration then
                lockConnection:Disconnect()
                isLocking = false
                currentTarget = nil
                return
            end
            
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, currentTarget.Character.Head.Position)
        end)
    end
end

-- Traceを作成する関数
local function CreateTrace(player)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local trace = Drawing.new("Line")
    trace.Visible = false
    trace.Color = Color3.new(1, 0, 0)
    trace.Thickness = Settings.TraceThickness
    trace.Transparency = 0.1 -- 超薄い
    
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not Settings.TraceEnabled then
            trace.Visible = false
            return
        end
        
        trace.Thickness = Settings.TraceThickness
        
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local pos, onScreen = Camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
                if onScreen then
                    trace.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    trace.To = Vector2.new(pos.X, pos.Y)
                    trace.Visible = true
                else
                    trace.Visible = false
                end
            else
                trace.Visible = false
            end
        else
            trace.Visible = false
        end
    end)
    
    traceConnections[player] = {trace = trace, connection = connection}
end

-- プレイヤー追加時のTrace作成
local function SetupTraces()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            CreateTrace(player)
        end
    end
end

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        task.wait(1)
        CreateTrace(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if traceConnections[player] then
        traceConnections[player].connection:Disconnect()
        traceConnections[player].trace:Remove()
        traceConnections[player] = nil
    end
end)

-- Mainタブの機能
local LockToggle = MainTab:CreateToggle({
    Name = "Head Lock",
    CurrentValue = false,
    Flag = "HeadLockToggle",
    Callback = function(Value)
        Settings.LockEnabled = Value
    end,
})

MainTab:CreateSection("ESP")

local TraceToggle = MainTab:CreateToggle({
    Name = "Trace (Ultra Thin Red)",
    CurrentValue = false,
    Flag = "TraceToggle",
    Callback = function(Value)
        Settings.TraceEnabled = Value
    end,
})

-- 設定タブ
SettingsTab:CreateSection("Lock Settings")

local LockDistanceSlider = SettingsTab:CreateSlider({
    Name = "Lock Distance (Studs)",
    Range = {5, 25},
    Increment = 1,
    CurrentValue = 5,
    Flag = "LockDistanceSlider",
    Callback = function(Value)
        Settings.LockDistance = Value
    end,
})

local LockDurationSlider = SettingsTab:CreateSlider({
    Name = "Lock Duration (Seconds)",
    Range = {0.1, 3},
    Increment = 0.1,
    CurrentValue = 0.5,
    Flag = "LockDurationSlider",
    Callback = function(Value)
        Settings.LockDuration = Value
    end,
})

local CooldownSlider = SettingsTab:CreateSlider({
    Name = "Cooldown Time (Seconds)",
    Range = {0.1, 5},
    Increment = 0.1,
    CurrentValue = 1,
    Flag = "CooldownSlider",
    Callback = function(Value)
        Settings.CooldownTime = Value
    end,
})

SettingsTab:CreateSection("Trace Settings")

local TraceThicknessSlider = SettingsTab:CreateSlider({
    Name = "Trace Thickness",
    Range = {1, 10},
    Increment = 1,
    CurrentValue = 1,
    Flag = "TraceThicknessSlider",
    Callback = function(Value)
        Settings.TraceThickness = Value
    end,
})

-- メインループ
RunService.RenderStepped:Connect(function()
    LockToHead()
end)

-- Trace初期化
SetupTraces()

Rayfield:LoadConfiguration()
