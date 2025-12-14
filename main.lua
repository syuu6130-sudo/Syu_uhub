--==================================================
-- Syu_uhub fling things and people top script
--==================================================

-- Rayfield
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--====================
-- 設定
--====================
local Settings = {
    -- メイン
    LockEnabled = false,
    CooldownTime = 1,
    LockDuration = 0.5,

    -- 距離（ON/OFF）
    UseGlobalDistance = false,
    UseFrontDistance  = false,
    UseBackDistance   = false,
    UseLeftDistance   = false,
    UseRightDistance  = false,

    LockDistance = 5,
    LockDistanceFront = 5,
    LockDistanceBack  = 5,
    LockDistanceLeft  = 5,
    LockDistanceRight = 5,

    -- 壁判定
    WallCheckEnabled = true,
    WallCheckDelay = 0,

    -- スムーズ
    SmoothLockEnabled = false,
    SmoothLockSpeed = 0.1, -- 0～1

    -- トレース
    TraceEnabled = false,
    TraceThickness = 1,
    TraceTransparency = 0.05,
    TraceColor = Color3.fromRGB(255,50,50),
    TraceShape = "Line", -- Line / Dot

    -- ESP
    NameESPEnabled = false,
    NameESPFont = 2,
    NameESPSize = 16,
    NameESPTransparency = 0,
    NameESPColor = Color3.new(1,1,1),
    NameESPAboveHead = true,

    HealthESPEnabled = false,
    HealthESPMode = "横", -- 横 / 縦

    BoxESPEnabled = false,
    BoxESPColor = Color3.new(0,1,0),
    BoxESPScale = 1,
    BoxESPFullBody = false,

    -- ターゲット
    TargetPlayer = nil,
    TargetPlayerID = nil,

    -- その他
    NotificationEnabled = false,
    ResetOnDeath = true,
}

--====================
-- 状態
--====================
local isLocking = false
local lastLockTime = 0
local lockConnection
local currentTarget
local lockStartTime = 0

--====================
-- ウィンドウ
--====================
local Window = Rayfield:CreateWindow({
    Name = "Syu_uhub fling things and people top script",
    LoadingTitle = "Syu_uhub fling things and people top script",
    LoadingSubtitle = "by Syu",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "SyuHub",
        FileName = "SyuHubConfig"
    }
})

-- 最小化表示名変更
task.spawn(function()
    task.wait(1)
    for _, v in pairs(game:GetService("CoreGui"):GetDescendants()) do
        if v:IsA("TextButton") and v.Text == "Show Rayfield" then
            v.Text = "Syu_uhub UI"
        end
    end
end)

--====================
-- タブ
--====================
local MainTab = Window:CreateTab("メイン", 4483362458)
local SettingsTab = Window:CreateTab("設定", 4483345998)
local InfoTab = Window:CreateTab("情報", 4483345998)

--====================
-- 補助関数
--====================
local function GetPlayerList()
    local t = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(t, p.Name) end
    end
    return t
end

local function CheckWall(a, b)
    if not Settings.WallCheckEnabled then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    local r = workspace:Raycast(a, (b-a), params)
    return r ~= nil
end

local function DistanceCheck(localPos, enemyPos, look)
    local offset = enemyPos - localPos
    if Settings.UseGlobalDistance and offset.Magnitude > Settings.LockDistance then
        return false
    end

    local right = look:Cross(Vector3.new(0,1,0)).Unit
    local forward = look

    local r = offset:Dot(right)
    local f = offset:Dot(forward)

    if Settings.UseRightDistance and r > 0 and math.abs(r) > Settings.LockDistanceRight then return false end
    if Settings.UseLeftDistance  and r < 0 and math.abs(r) > Settings.LockDistanceLeft  then return false end
    if Settings.UseFrontDistance and f > 0 and f > Settings.LockDistanceFront then return false end
    if Settings.UseBackDistance  and f < 0 and math.abs(f) > Settings.LockDistanceBack then return false end

    return true
end

--====================
-- ロック処理
--====================
local function SmoothLook(pos)
    TweenService:Create(
        Camera,
        TweenInfo.new(Settings.SmoothLockSpeed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        {CFrame = CFrame.new(Camera.CFrame.Position, pos)}
    ):Play()
end

local function FindTarget()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Head") and p.Character:FindFirstChild("HumanoidRootPart") then
            local h = p.Character:FindFirstChild("Humanoid")
            if h and h.Health > 0 then
                local lp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if lp then
                    if DistanceCheck(lp.Position, p.Character.HumanoidRootPart.Position, lp.CFrame.LookVector) then
                        if not CheckWall(lp.Position, p.Character.Head.Position) then
                            return p
                        end
                    end
                end
            end
        end
    end
end

RunService.RenderStepped:Connect(function()
    if not Settings.LockEnabled or isLocking then return end
    if tick() - lastLockTime < Settings.CooldownTime then return end

    local target = FindTarget()
    if not target then return end

    isLocking = true
    currentTarget = target
    lastLockTime = tick()
    lockStartTime = tick()

    lockConnection = RunService.RenderStepped:Connect(function()
        if not Settings.LockEnabled or not currentTarget or not currentTarget.Character then
            isLocking = false
            lockConnection:Disconnect()
            return
        end

        if tick() - lockStartTime >= Settings.LockDuration then
            isLocking = false
            lockConnection:Disconnect()
            return
        end

        local head = currentTarget.Character:FindFirstChild("Head")
        if head then
            if Settings.SmoothLockEnabled then
                SmoothLook(head.Position)
            else
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position)
            end
        end
    end)
end)

--====================
-- メインUI
--====================
MainTab:CreateToggle({
    Name = "固定",
    CurrentValue = false,
    Callback = function(v)
        Settings.LockEnabled = v
    end
})

MainTab:CreateSection("ターゲット")

local playerDropdown = MainTab:CreateDropdown({
    Name = "プレイヤー選択",
    Options = {"なし"},
    CurrentOption = {"なし"},
    Callback = function(opt)
        if opt[1] == "なし" then
            Settings.TargetPlayer = nil
        else
            Settings.TargetPlayer = opt[1]
        end
    end
})

MainTab:CreateInput({
    Name = "プレイヤーID指定",
    PlaceholderText = "UserId",
    Callback = function(t)
        Settings.TargetPlayerID = tonumber(t)
    end
})

local serverList = MainTab:CreateLabel("サーバープレイヤー:")
task.spawn(function()
    while task.wait(2) do
        local txt = "サーバープレイヤー:\n"
        for _, p in pairs(Players:GetPlayers()) do
            txt ..= "- "..p.Name.."\n"
        end
        serverList:SetText(txt)
        playerDropdown:Refresh((function()
            local o = {"なし"}
            for _, n in ipairs(GetPlayerList()) do table.insert(o, n) end
            return o
        end)(), false)
    end
end)

--====================
-- 設定UI（要点）
--====================
SettingsTab:CreateSection("距離設定（ON/OFF＋入力）")

SettingsTab:CreateToggle({Name="全体距離を使用", Callback=function(v) Settings.UseGlobalDistance=v end})
SettingsTab:CreateSlider({Name="全体距離", Range={0,100}, Increment=0.1, CurrentValue=5, Callback=function(v) Settings.LockDistance=v end})
SettingsTab:CreateInput({Name="全体距離（直接入力）", PlaceholderText="数値", Callback=function(v) Settings.LockDistance=tonumber(v) or Settings.LockDistance end})

SettingsTab:CreateSection("壁判定")
SettingsTab:CreateToggle({Name="壁判定", CurrentValue=true, Callback=function(v) Settings.WallCheckEnabled=v end})
SettingsTab:CreateSlider({Name="ロック接続時間（秒）", Range={0,5}, Increment=0.1, CurrentValue=0, Callback=function(v) Settings.WallCheckDelay=v end})
SettingsTab:CreateParagraph({
    Title="詳細",
    Content="0秒：即ロック\n設定秒数：壁が無い状態が続いた後にロック\n途中で壁が出るとリセット"
})

SettingsTab:CreateSection("スムーズロック")
SettingsTab:CreateToggle({Name="スムーズロック", Callback=function(v) Settings.SmoothLockEnabled=v end})
SettingsTab:CreateSlider({Name="速度", Range={0,1}, Increment=0.001, CurrentValue=0.1, Callback=function(v) Settings.SmoothLockSpeed=v end})
SettingsTab:CreateInput({Name="速度（直接入力）", PlaceholderText="0～1", Callback=function(v) Settings.SmoothLockSpeed=math.max(0, tonumber(v) or 0) end})

SettingsTab:CreateSection("トレース")
SettingsTab:CreateToggle({Name="トレース有効", Callback=function(v) Settings.TraceEnabled=v end})
SettingsTab:CreateSlider({Name="太さ", Range={1,10}, Increment=1, CurrentValue=1, Callback=function(v) Settings.TraceThickness=v end})
SettingsTab:CreateSlider({Name="薄さ", Range={0,1}, Increment=0.01, CurrentValue=0.05, Callback=function(v) Settings.TraceTransparency=v end})
SettingsTab:CreateColorPicker({Name="色", Color=Settings.TraceColor, Callback=function(c) Settings.TraceColor=c end})
SettingsTab:CreateDropdown({Name="形", Options={"Line","Dot"}, CurrentOption={"Line"}, Callback=function(o) Settings.TraceShape=o[1] end})

--====================
-- 情報
--====================
InfoTab:CreateLabel("UI名：Syu_uhub fling things and people top script")
InfoTab:CreateLabel("すべて日本語対応")

Rayfield:LoadConfiguration()
