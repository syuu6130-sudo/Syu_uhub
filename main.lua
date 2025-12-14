--==================================================
-- Syu_uhub fling things and people top script
-- 完成統合版 / 日本語UI
--==================================================

-- Rayfield 読み込み
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--==================================================
-- 設定
--==================================================
local Settings = {

    -- 固定（ヘッドロック）
    LockEnabled = false,
    LockDuration = 0.5,
    CooldownTime = 1,

    -- 距離 ON / OFF
    UseGlobalDistance = false,
    UseFrontDistance = false,
    UseBackDistance = false,
    UseLeftDistance = false,
    UseRightDistance = false,

    LockDistance = 5,
    LockDistanceFront = 5,
    LockDistanceBack = 5,
    LockDistanceLeft = 5,
    LockDistanceRight = 5,

    -- 壁判定
    WallCheckEnabled = true,
    WallCheckDelay = 0,

    -- スムーズ
    SmoothLockEnabled = false,
    SmoothLockSpeed = 0.1, -- 0〜1（0.001可）

    -- ターゲット
    TargetPlayer = nil,
    TargetPlayerID = nil,
    LockPriority = "Closest",

    -- 通知
    NotificationEnabled = false,

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
    BoxESPColor = Color3.fromRGB(0,255,0),
    BoxESPScale = 1,
    BoxESPFullBody = false,
}

--==================================================
-- 状態
--==================================================
local isLocking = false
local lockConnection
local currentTarget
local lastLockTime = 0
local lockStartTime = 0

--==================================================
-- Rayfield Window
--==================================================
local Window = Rayfield:CreateWindow({
    Name = "Syu_uhub fling things and people top script",
    LoadingTitle = "Syu_uhub fling things and people top script",
    LoadingSubtitle = "by Syu",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "SyuHub",
        FileName = "MainConfig"
    }
})

--==================================================
-- タブ
--==================================================
local MainTab = Window:CreateTab("固定", 4483362458)
local SettingsTab = Window:CreateTab("設定", 4483345998)
local InfoTab = Window:CreateTab("情報", 4483345998)

--==================================================
-- Rayfield 最小化テキスト変更
--==================================================
task.spawn(function()
    task.wait(1)
    for _, v in pairs(game:GetService("CoreGui"):GetDescendants()) do
        if v:IsA("TextButton") and v.Text == "Show Rayfield" then
            v.Text = "Syu_uhub UI"
        end
    end
end)

--==================================================
-- 固定ロジック
--==================================================
local function GetBestTarget()
    local best
    local bestDist = math.huge

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Head") then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local dist = (LocalPlayer.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    best = p
                end
            end
        end
    end

    return best, bestDist
end

local function LockUpdate()
    if not Settings.LockEnabled then return end
    if isLocking then return end
    if tick() - lastLockTime < Settings.CooldownTime then return end

    local target, dist = GetBestTarget()
    if not target then return end

    isLocking = true
    currentTarget = target
    lastLockTime = tick()
    lockStartTime = tick()

    lockConnection = RunService.RenderStepped:Connect(function()
        if not currentTarget or not currentTarget.Character or not currentTarget.Character:FindFirstChild("Head") then
            lockConnection:Disconnect()
            isLocking = false
            return
        end

        if tick() - lockStartTime >= Settings.LockDuration then
            lockConnection:Disconnect()
            isLocking = false
            return
        end

        local headPos = currentTarget.Character.Head.Position
        if Settings.SmoothLockEnabled then
            local cf = CFrame.new(Camera.CFrame.Position, headPos)
            Camera.CFrame = Camera.CFrame:Lerp(cf, Settings.SmoothLockSpeed)
        else
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, headPos)
        end
    end)
end

RunService.RenderStepped:Connect(LockUpdate)

--==================================================
-- UI : メイン
--==================================================
MainTab:CreateToggle({
    Name = "固定（ヘッドロック）",
    CurrentValue = false,
    Callback = function(v)
        Settings.LockEnabled = v
    end
})

MainTab:CreateButton({
    Name = "固定リセット",
    Callback = function()
        if lockConnection then lockConnection:Disconnect() end
        isLocking = false
        currentTarget = nil
    end
})

--==================================================
-- UI : 設定
--==================================================
SettingsTab:CreateSection("距離設定（ONにしないと有効になりません）")

SettingsTab:CreateToggle({
    Name = "全体距離を使用",
    Callback = function(v) Settings.UseGlobalDistance = v end
})

SettingsTab:CreateSlider({
    Name = "全体距離",
    Range = {0,100},
    Increment = 0.1,
    CurrentValue = 5,
    Callback = function(v) Settings.LockDistance = v end
})

SettingsTab:CreateInput({
    Name = "全体距離（直接入力）",
    PlaceholderText = "例: 7.25",
    Callback = function(v)
        Settings.LockDistance = tonumber(v) or Settings.LockDistance
    end
})

SettingsTab:CreateSection("スムーズロック")

SettingsTab:CreateToggle({
    Name = "スムーズロック有効",
    Callback = function(v) Settings.SmoothLockEnabled = v end
})

SettingsTab:CreateSlider({
    Name = "スムーズ速度",
    Range = {0,1},
    Increment = 0.001,
    CurrentValue = 0.1,
    Callback = function(v) Settings.SmoothLockSpeed = v end
})

SettingsTab:CreateInput({
    Name = "スムーズ速度（直接入力）",
    PlaceholderText = "0 ～ 1",
    Callback = function(v)
        Settings.SmoothLockSpeed = math.max(0, tonumber(v) or 0)
    end
})

SettingsTab:CreateSection("壁判定")

SettingsTab:CreateToggle({
    Name = "壁判定",
    CurrentValue = true,
    Callback = function(v) Settings.WallCheckEnabled = v end
})

SettingsTab:CreateSlider({
    Name = "ロック接続時間（秒）",
    Range = {0,5},
    Increment = 0.1,
    CurrentValue = 0,
    Callback = function(v) Settings.WallCheckDelay = v end
})

SettingsTab:CreateParagraph({
    Title = "壁判定の説明",
    Content =
        "0秒 : 即ロック\n" ..
        "0.5秒以上 : 壁が無い状態がその秒数続いたらロック\n" ..
        "途中で壁が出たらカウントはリセットされます"
})

--==================================================
-- 情報
--==================================================
InfoTab:CreateLabel("UI名 : Syu_uhub")
InfoTab:CreateLabel("用途 : 学習・研究用")

--==================================================
-- 初期化
--==================================================
Rayfield:LoadConfiguration()
