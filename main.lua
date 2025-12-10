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
    LockDistanceLeft = 5, -- 左方向の距離
    LockDistanceRight = 5, -- 右方向の距離
    LockDistanceFront = 5, -- 前方向の距離
    LockDistanceBack = 5, -- 後方向の距離
    LockDuration = 0.5, -- 固定時間（秒）
    CooldownTime = 1, -- 再作動までの時間（秒）
    TraceEnabled = false,
    TraceThickness = 1, -- Traceの太さ
    NameESPEnabled = false,
    TargetPlayer = nil, -- 固定する特定のプレイヤー
    WallCheckEnabled = true, -- 壁判定の有効/無効
    WallCheckDelay = 0 -- 壁判定の遅延（秒）
}

-- 状態管理
local isLocking = false
local lastLockTime = 0
local lockConnection = nil
local traceConnections = {}
local nameESPConnections = {}
local currentTarget = nil
local playerDropdown = nil
local wallCheckStartTime = 0
local wallCheckPassed = false

-- Rayfield ウィンドウの作成
local Window = Rayfield:CreateWindow({
    Name = "Syu_uhub",
    LoadingTitle = "Syu_uhub ロード中",
    LoadingSubtitle = "by Syu",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "SyuHub",
        FileName = "SyuHubConfig"
    }
})

-- メインタブ
local MainTab = Window:CreateTab("メイン", 4483362458)

-- 設定タブ
local SettingsTab = Window:CreateTab("設定", 4483345998)

-- プレイヤーリストを取得する関数
local function GetPlayerList()
    local playerList = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(playerList, player.Name)
        end
    end
    return playerList
end

-- 壁判定関数
local function CheckWallBetween(startPos, endPos)
    if not Settings.WallCheckEnabled then
        return false -- 壁判定無効なら常に壁なし
    end
    
    local direction = (endPos - startPos).Unit
    local distance = (endPos - startPos).Magnitude
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    
    local raycastResult = workspace:Raycast(startPos, direction * distance, raycastParams)
    
    if raycastResult then
        -- 敵のキャラクターに当たった場合は壁なしとみなす
        local hitPlayer = Players:GetPlayerFromCharacter(raycastResult.Instance.Parent)
        if hitPlayer and hitPlayer ~= LocalPlayer then
            return false
        end
        return true -- 壁あり
    end
    
    return false -- 壁なし
end

-- 方向による距離チェック関数
local function IsWithinDirectionalDistance(localPos, enemyPos, localLook)
    local offset = enemyPos - localPos
    local distance = offset.Magnitude
    
    -- 全体の距離チェック
    if distance > Settings.LockDistance then
        return false
    end
    
    -- 方向ベクトル
    local right = localLook:Cross(Vector3.new(0, 1, 0)).Unit
    local forward = localLook
    
    -- 各方向の距離を計算
    local rightDist = math.abs(offset:Dot(right))
    local forwardDist = offset:Dot(forward)
    
    -- 左右チェック
    if offset:Dot(right) > 0 then -- 右側
        if rightDist > Settings.LockDistanceRight then return false end
    else -- 左側
        if rightDist > Settings.LockDistanceLeft then return false end
    end
    
    -- 前後チェック
    if forwardDist > 0 then -- 前方
        if forwardDist > Settings.LockDistanceFront then return false end
    else -- 後方
        if math.abs(forwardDist) > Settings.LockDistanceBack then return false end
    end
    
    return true
end

-- 最も近い敵を取得する関数
local function GetClosestEnemy()
    local closestPlayer = nil
    local shortestDistance = math.huge
    
    -- 特定のプレイヤーが設定されている場合
    if Settings.TargetPlayer and Settings.TargetPlayer ~= "なし" then
        local targetPlayer = Players:FindFirstChild(Settings.TargetPlayer)
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") and targetPlayer.Character:FindFirstChild("Head") then
            local humanoid = targetPlayer.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local distance = (LocalPlayer.Character.HumanoidRootPart.Position - targetPlayer.Character.HumanoidRootPart.Position).Magnitude
                local lookVector = LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector
                if IsWithinDirectionalDistance(LocalPlayer.Character.HumanoidRootPart.Position, targetPlayer.Character.HumanoidRootPart.Position, lookVector) then
                    -- 壁判定
                    local hasWall = CheckWallBetween(LocalPlayer.Character.HumanoidRootPart.Position, targetPlayer.Character.Head.Position)
                    if not hasWall then
                        return targetPlayer, distance, false
                    else
                        return targetPlayer, distance, true
                    end
                end
            end
        end
        return nil, math.huge, false
    end
    
    -- 最も近い敵を探す
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Head") then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local distance = (LocalPlayer.Character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
                local lookVector = LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector
                if IsWithinDirectionalDistance(LocalPlayer.Character.HumanoidRootPart.Position, player.Character.HumanoidRootPart.Position, lookVector) and distance < shortestDistance then
                    -- 壁判定
                    local hasWall = CheckWallBetween(LocalPlayer.Character.HumanoidRootPart.Position, player.Character.Head.Position)
                    if not hasWall then
                        shortestDistance = distance
                        closestPlayer = player
                    end
                end
            end
        end
    end
    
    return closestPlayer, shortestDistance, false
end

-- 頭に視点を固定する関数
local function LockToHead()
    if not Settings.LockEnabled then return end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local currentTime = tick()
    if currentTime - lastLockTime < Settings.CooldownTime then return end
    if isLocking then return end
    
    local enemy, distance, hasWall = GetClosestEnemy()
    
    if enemy and distance <= Settings.LockDistance then
        -- 壁判定が無効の場合は即ロック
        if not Settings.WallCheckEnabled then
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
                    local lookVector = LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector
                    if currentDistance > Settings.LockDistance or not IsWithinDirectionalDistance(LocalPlayer.Character.HumanoidRootPart.Position, currentTarget.Character.HumanoidRootPart.Position, lookVector) then
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
        else
            -- 壁判定が有効の場合は遅延処理
            if not hasWall then
                -- 壁なしの場合、遅延時間経過後にロック
                if wallCheckStartTime == 0 then
                    wallCheckStartTime = currentTime
                end
                
                if currentTime - wallCheckStartTime >= Settings.WallCheckDelay then
                    isLocking = true
                    currentTarget = enemy
                    lastLockTime = currentTime
                    wallCheckStartTime = 0
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
                            local lookVector = LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector
                            if currentDistance > Settings.LockDistance or not IsWithinDirectionalDistance(LocalPlayer.Character.HumanoidRootPart.Position, currentTarget.Character.HumanoidRootPart.Position, lookVector) then
                                lockConnection:Disconnect()
                                isLocking = false
                                currentTarget = nil
                                return
                            end
                            
                            -- ロック中に壁ができた場合は解除
                            if Settings.WallCheckEnabled then
                                local wallCheck = CheckWallBetween(LocalPlayer.Character.HumanoidRootPart.Position, currentTarget.Character.Head.Position)
                                if wallCheck then
                                    lockConnection:Disconnect()
                                    isLocking = false
                                    currentTarget = nil
                                    return
                                end
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
            else
                -- 壁がある場合はタイマーリセット
                wallCheckStartTime = 0
            end
        end
    else
        wallCheckStartTime = 0
    end
end

-- Name ESPを作成する関数
local function CreateNameESP(player)
    if not player.Character or not player.Character:FindFirstChild("Head") then return end
    
    local nameTag = Drawing.new("Text")
    nameTag.Visible = false
    nameTag.Center = true
    nameTag.Outline = true
    nameTag.Font = 2
    nameTag.Size = 16
    nameTag.Color = Color3.new(1, 1, 1)
    
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not Settings.NameESPEnabled then
            nameTag.Visible = false
            return
        end
        
        if player.Character and player.Character:FindFirstChild("Head") then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local pos, onScreen = Camera:WorldToViewportPoint(player.Character.Head.Position + Vector3.new(0, 1, 0))
                if onScreen then
                    nameTag.Position = Vector2.new(pos.X, pos.Y)
                    nameTag.Text = player.Name
                    nameTag.Visible = true
                else
                    nameTag.Visible = false
                end
            else
                nameTag.Visible = false
            end
        else
            nameTag.Visible = false
        end
    end)
    
    nameESPConnections[player] = {nameTag = nameTag, connection = connection}
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

-- プレイヤー追加時の処理
local function SetupPlayer(player)
    if player ~= LocalPlayer then
        CreateTrace(player)
        CreateNameESP(player)
    end
end

local function SetupAllPlayers()
    for _, player in pairs(Players:GetPlayers()) do
        SetupPlayer(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    task.wait(1)
    SetupPlayer(player)
    if playerDropdown then
        playerDropdown:Refresh(GetPlayerList(), true)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if traceConnections[player] then
        traceConnections[player].connection:Disconnect()
        traceConnections[player].trace:Remove()
        traceConnections[player] = nil
    end
    if nameESPConnections[player] then
        nameESPConnections[player].connection:Disconnect()
        nameESPConnections[player].nameTag:Remove()
        nameESPConnections[player] = nil
    end
    if playerDropdown then
        playerDropdown:Refresh(GetPlayerList(), true)
    end
end)

-- メインタブの機能
local LockToggle = MainTab:CreateToggle({
    Name = "ヘッドロック",
    CurrentValue = false,
    Flag = "HeadLockToggle",
    Callback = function(Value)
        Settings.LockEnabled = Value
    end,
})

MainTab:CreateSection("ESP")

local NameESPToggle = MainTab:CreateToggle({
    Name = "ネームESP",
    CurrentValue = false,
    Flag = "NameESPToggle",
    Callback = function(Value)
        Settings.NameESPEnabled = Value
    end,
})

local TraceToggle = MainTab:CreateToggle({
    Name = "トレース（超薄赤線）",
    CurrentValue = false,
    Flag = "TraceToggle",
    Callback = function(Value)
        Settings.TraceEnabled = Value
    end,
})

-- 設定タブ
SettingsTab:CreateSection("ターゲット設定")

playerDropdown = SettingsTab:CreateDropdown({
    Name = "ターゲットプレイヤー",
    Options = {"なし"},
    CurrentOption = {"なし"},
    MultipleOptions = false,
    Flag = "TargetPlayerDropdown",
    Callback = function(Option)
        if Option[1] == "なし" then
            Settings.TargetPlayer = nil
        else
            Settings.TargetPlayer = Option[1]
        end
    end,
})

-- プレイヤーリストを更新
task.spawn(function()
    while task.wait(2) do
        if playerDropdown then
            local currentList = {"なし"}
            for _, name in ipairs(GetPlayerList()) do
                table.insert(currentList, name)
            end
            playerDropdown:Refresh(currentList, true)
        end
    end
end)

SettingsTab:CreateSection("ロック距離設定")

local LockDistanceSlider = SettingsTab:CreateSlider({
    Name = "全体距離（スタッド）",
    Range = {5, 25},
    Increment = 1,
    CurrentValue = 5,
    Flag = "LockDistanceSlider",
    Callback = function(Value)
        Settings.LockDistance = Value
    end,
})

local LockDistanceFrontSlider = SettingsTab:CreateSlider({
    Name = "前方距離（スタッド）",
    Range = {5, 25},
    Increment = 1,
    CurrentValue = 5,
    Flag = "LockDistanceFrontSlider",
    Callback = function(Value)
        Settings.LockDistanceFront = Value
    end,
})

local LockDistanceBackSlider = SettingsTab:CreateSlider({
    Name = "後方距離（スタッド）",
    Range = {5, 25},
    Increment = 1,
    CurrentValue = 5,
    Flag = "LockDistanceBackSlider",
    Callback = function(Value)
        Settings.LockDistanceBack = Value
    end,
})

local LockDistanceLeftSlider = SettingsTab:CreateSlider({
    Name = "左方向距離（スタッド）",
    Range = {5, 25},
    Increment = 1,
    CurrentValue = 5,
    Flag = "LockDistanceLeftSlider",
    Callback = function(Value)
        Settings.LockDistanceLeft = Value
    end,
})

local LockDistanceRightSlider = SettingsTab:CreateSlider({
    Name = "右方向距離（スタッド）",
    Range = {5, 25},
    Increment = 1,
    CurrentValue = 5,
    Flag = "LockDistanceRightSlider",
    Callback = function(Value)
        Settings.LockDistanceRight = Value
    end,
})

SettingsTab:CreateSection("ロックタイミング設定")

local WallCheckToggle = SettingsTab:CreateToggle({
    Name = "壁判定",
    CurrentValue = true,
    Flag = "WallCheckToggle",
    Callback = function(Value)
        Settings.WallCheckEnabled = Value
    end,
})

local WallCheckDelaySlider = SettingsTab:CreateSlider({
    Name = "壁判定遅延（秒）",
    Range = {0, 2},
    Increment = 0.1,
    CurrentValue = 0,
    Flag = "WallCheckDelaySlider",
    Callback = function(Value)
        Settings.WallCheckDelay = Value
    end,
})

local LockDurationSlider = SettingsTab:CreateSlider({
    Name = "ロック持続時間（秒）",
    Range = {0.1, 3},
    Increment = 0.1,
    CurrentValue = 0.5,
    Flag = "LockDurationSlider",
    Callback = function(Value)
        Settings.LockDuration = Value
    end,
})

local CooldownSlider = SettingsTab:CreateSlider({
    Name = "クールダウン時間（秒）",
    Range = {0.1, 5},
    Increment = 0.1,
    CurrentValue = 1,
    Flag = "CooldownSlider",
    Callback = function(Value)
        Settings.CooldownTime = Value
    end,
})

SettingsTab:CreateSection("トレース設定")

local TraceThicknessSlider = SettingsTab:CreateSlider({
    Name = "トレースの太さ",
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

-- 初期化
SetupAllPlayers()

Rayfield:LoadConfiguration()
