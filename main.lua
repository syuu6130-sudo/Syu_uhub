-- Rayfield UIライブラリの読み込み
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- 変数の初期化
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- 設定値
local Settings = {
    LockEnabled = false,
    LockDistanceEnabled = false,
    LockDistance = 5,
    LockDistanceLeftEnabled = false,
    LockDistanceLeft = 5,
    LockDistanceRightEnabled = false,
    LockDistanceRight = 5,
    LockDistanceFrontEnabled = false,
    LockDistanceFront = 5,
    LockDistanceBackEnabled = false,
    LockDistanceBack = 5,
    LockDuration = 0.5,
    CooldownTime = 1,
    TraceEnabled = false,
    TraceThickness = 1,
    TraceTransparency = 0.1,
    TraceSize = 1,
    TraceColor = Color3.fromRGB(255, 50, 50),
    TraceShape = "Line", -- "Line", "Circle", "Square"
    NameESPEnabled = false,
    NameESPFont = 2,
    NameESPColor = Color3.fromRGB(255, 255, 255),
    NameESPSize = 16,
    NameESPTransparency = 0,
    NameESPPosition = "AboveHead", -- "AboveHead", "OnHead"
    HealthESPEnabled = false,
    HealthESPStyle = "Horizontal", -- "Horizontal", "Vertical"
    HealthESPColor = Color3.fromRGB(0, 255, 0),
    HealthESPSize = 14,
    BoxESPEnabled = false,
    BoxESPColor = Color3.fromRGB(0, 255, 0),
    BoxESPThickness = 1,
    BoxESPStyle = "Normal", -- "Normal", "FullBody"
    TargetPlayer = nil,
    TargetPlayerID = nil,
    WallCheckEnabled = true,
    WallCheckDelay = 0,
    SmoothLockEnabled = false,
    SmoothLockSpeed = 0.1,
    NotificationEnabled = false,
    AutoUpdateTarget = true,
    ShowLockIndicator = true,
    LockSoundEnabled = true,
    UnlockSoundEnabled = true,
    ResetOnDeath = true,
    LockPriority = "Closest"
}

-- 状態管理
local isLocking = false
local lastLockTime = 0
local lockConnection = nil
local traceConnections = {}
local nameESPConnections = {}
local healthESPConnections = {}
local boxESPConnections = {}
local currentTarget = nil
local playerDropdown = nil
local wallCheckStartTime = 0
local wallCheckPassed = false
local lockStartTime = 0
local targetHistory = {}
local lockIndicator = nil

-- 音声設定
local lockSound = Instance.new("Sound")
lockSound.SoundId = "rbxassetid://9128736210"
lockSound.Volume = 0.5
lockSound.Parent = workspace

local unlockSound = Instance.new("Sound")
unlockSound.SoundId = "rbxassetid://9128736804"
unlockSound.Volume = 0.5
unlockSound.Parent = workspace

-- Rayfield ウィンドウの作成
local Window = Rayfield:CreateWindow({
    Name = "Syu_uhub fling things and people top script",
    LoadingTitle = "Syu_uhub ロード中",
    LoadingSubtitle = "by Syu - fling things and people top script",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "SyuHub",
        FileName = "SyuHubConfig"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    }
})

-- UIタイトル変更
Rayfield.Notify({
    Title = "Syu_uhub UI",
    Content = "UIがロードされました",
    Duration = 3,
    Image = 4483362458
})

-- メインタブ
local MainTab = Window:CreateTab("メイン", 4483362458)

-- 設定タブ
local SettingsTab = Window:CreateTab("設定", 4483345998)

-- ESP設定タブ
local ESPTab = Window:CreateTab("ESP設定", 4483345998)

-- 情報タブ
local InfoTab = Window:CreateTab("情報", 4483345998)

-- 通知関数
local function Notify(title, message, duration)
    if Settings.NotificationEnabled then
        Rayfield:Notify({
            Title = title,
            Content = message,
            Duration = duration or 3,
            Image = 4483362458,
            Actions = {
                Ignore = {
                    Name = "OK"
                }
            }
        })
    end
end

-- ロックインジケーター作成
local function CreateLockIndicator()
    if lockIndicator then
        lockIndicator:Remove()
    end
    
    lockIndicator = Instance.new("BillboardGui")
    lockIndicator.Name = "LockIndicator"
    lockIndicator.AlwaysOnTop = true
    lockIndicator.Size = UDim2.new(4, 0, 4, 0)
    lockIndicator.StudsOffset = Vector3.new(0, 3, 0)
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    frame.BackgroundTransparency = 0.7
    frame.BorderSizePixel = 0
    frame.Parent = lockIndicator
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    lockIndicator.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

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

-- プレイヤーIDからプレイヤーを取得
local function GetPlayerByID(userId)
    for _, player in pairs(Players:GetPlayers()) do
        if player.UserId == userId then
            return player
        end
    end
    return nil
end

-- 壁判定関数
local function CheckWallBetween(startPos, endPos)
    if not Settings.WallCheckEnabled then
        return false
    end
    
    local direction = (endPos - startPos).Unit
    local distance = (endPos - startPos).Magnitude
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    raycastParams.IgnoreWater = true
    
    local raycastResult = workspace:Raycast(startPos, direction * distance, raycastParams)
    
    if raycastResult then
        local hitModel = raycastResult.Instance
        while hitModel and hitModel ~= workspace do
            local hitPlayer = Players:GetPlayerFromCharacter(hitModel)
            if hitPlayer and hitPlayer ~= LocalPlayer then
                return false
            end
            hitModel = hitModel.Parent
        end
        return true
    end
    
    return false
end

-- 方向による距離チェック関数
local function IsWithinDirectionalDistance(localPos, enemyPos, localLook)
    local offset = enemyPos - localPos
    local distance = offset.Magnitude
    
    -- 全体距離チェック
    if Settings.LockDistanceEnabled and distance > Settings.LockDistance then
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
        if Settings.LockDistanceRightEnabled and rightDist > Settings.LockDistanceRight then
            return false
        end
    else -- 左側
        if Settings.LockDistanceLeftEnabled and rightDist > Settings.LockDistanceLeft then
            return false
        end
    end
    
    -- 前後チェック
    if forwardDist > 0 then -- 前方
        if Settings.LockDistanceFrontEnabled and forwardDist > Settings.LockDistanceFront then
            return false
        end
    else -- 後方
        if Settings.LockDistanceBackEnabled and math.abs(forwardDist) > Settings.LockDistanceBack then
            return false
        end
    end
    
    return true
end

-- プレイヤーの健康状態を取得
local function GetPlayerHealth(player)
    if player.Character then
        local humanoid = player.Character:FindFirstChild("Humanoid")
        if humanoid then
            return humanoid.Health, humanoid.MaxHealth
        end
    end
    return 0, 100
end

-- ターゲットの優先度を計算
local function CalculateTargetPriority(player, distance)
    if Settings.LockPriority == "LowestHealth" then
        local health, maxHealth = GetPlayerHealth(player)
        return health / maxHealth
    elseif Settings.LockPriority == "Random" then
        return math.random()
    else -- "Closest"
        return 1 / (distance + 1)
    end
end

-- 最も適切な敵を取得する関数
local function GetBestEnemy()
    local bestPlayer = nil
    local bestPriority = -math.huge
    local bestDistance = math.huge
    local hasWall = false
    
    -- 特定のプレイヤーIDが設定されている場合
    if Settings.TargetPlayerID and Settings.TargetPlayerID ~= 0 then
        local targetPlayer = GetPlayerByID(Settings.TargetPlayerID)
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") and targetPlayer.Character:FindFirstChild("Head") then
            local humanoid = targetPlayer.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local distance = (LocalPlayer.Character.HumanoidRootPart.Position - targetPlayer.Character.HumanoidRootPart.Position).Magnitude
                local lookVector = LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector
                if IsWithinDirectionalDistance(LocalPlayer.Character.HumanoidRootPart.Position, targetPlayer.Character.HumanoidRootPart.Position, lookVector) then
                    local wallCheck = CheckWallBetween(LocalPlayer.Character.HumanoidRootPart.Position, targetPlayer.Character.Head.Position)
                    if not wallCheck then
                        return targetPlayer, distance, false
                    else
                        return targetPlayer, distance, true
                    end
                end
            end
        end
        return nil, math.huge, false
    end
    
    -- 特定のプレイヤー名が設定されている場合
    if Settings.TargetPlayer and Settings.TargetPlayer ~= "なし" then
        local targetPlayer = Players:FindFirstChild(Settings.TargetPlayer)
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") and targetPlayer.Character:FindFirstChild("Head") then
            local humanoid = targetPlayer.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local distance = (LocalPlayer.Character.HumanoidRootPart.Position - targetPlayer.Character.HumanoidRootPart.Position).Magnitude
                local lookVector = LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector
                if IsWithinDirectionalDistance(LocalPlayer.Character.HumanoidRootPart.Position, targetPlayer.Character.HumanoidRootPart.Position, lookVector) then
                    local wallCheck = CheckWallBetween(LocalPlayer.Character.HumanoidRootPart.Position, targetPlayer.Character.Head.Position)
                    if not wallCheck then
                        return targetPlayer, distance, false
                    else
                        return targetPlayer, distance, true
                    end
                end
            end
        end
        return nil, math.huge, false
    end
    
    -- 自動で最適な敵を探す
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Head") then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local distance = (LocalPlayer.Character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
                local lookVector = LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector
                if IsWithinDirectionalDistance(LocalPlayer.Character.HumanoidRootPart.Position, player.Character.HumanoidRootPart.Position, lookVector) then
                    local wallCheck = CheckWallBetween(LocalPlayer.Character.HumanoidRootPart.Position, player.Character.Head.Position)
                    if not wallCheck then
                        local priority = CalculateTargetPriority(player, distance)
                        if priority > bestPriority then
                            bestPriority = priority
                            bestPlayer = player
                            bestDistance = distance
                            hasWall = false
                        end
                    end
                end
            end
        end
    end
    
    return bestPlayer, bestDistance, hasWall
end

-- スムーズなカメラ移動
local function SmoothLookAt(targetPosition)
    local currentCFrame = Camera.CFrame
    local targetCFrame = CFrame.new(Camera.CFrame.Position, targetPosition)
    
    local tweenInfo = TweenInfo.new(
        Settings.SmoothLockSpeed,
        Enum.EasingStyle.Sine,
        Enum.EasingDirection.Out
    )
    
    local tween = TweenService:Create(Camera, tweenInfo, {CFrame = targetCFrame})
    tween:Play()
end

-- 頭に視点を固定する関数
local function LockToHead()
    if not Settings.LockEnabled then return end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    
    -- 死亡時リセット
    if Settings.ResetOnDeath then
        local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        if humanoid and humanoid.Health <= 0 then
            if lockConnection then
                lockConnection:Disconnect()
                isLocking = false
                currentTarget = nil
                wallCheckStartTime = 0
            end
            return
        end
    end
    
    local currentTime = tick()
    if currentTime - lastLockTime < Settings.CooldownTime then return end
    if isLocking then return end
    
    local enemy, distance, hasWall = GetBestEnemy()
    
    if enemy and (not Settings.LockDistanceEnabled or distance <= Settings.LockDistance) then
        -- ロックインジケーター更新
        if Settings.ShowLockIndicator and lockIndicator and enemy.Character and enemy.Character:FindFirstChild("Head") then
            lockIndicator.Adornee = enemy.Character.Head
            lockIndicator.Enabled = true
        end
        
        -- 壁判定が無効の場合は即ロック
        if not Settings.WallCheckEnabled then
            isLocking = true
            currentTarget = enemy
            lastLockTime = currentTime
            lockStartTime = currentTime
            
            -- ロック音
            if Settings.LockSoundEnabled then
                lockSound:Play()
            end
            
            -- 通知
            Notify("🔒 ロック成功", enemy.Name .. " をロックしました", 2)
            
            -- ターゲット履歴に追加
            table.insert(targetHistory, 1, {
                player = enemy,
                time = os.date("%H:%M:%S"),
                duration = Settings.LockDuration
            })
            if #targetHistory > 10 then
                table.remove(targetHistory, 11)
            end
            
            if lockConnection then
                lockConnection:Disconnect()
            end
            
            lockConnection = RunService.RenderStepped:Connect(function()
                if not Settings.LockEnabled or not currentTarget or not currentTarget.Character or not currentTarget.Character:FindFirstChild("Head") then
                    lockConnection:Disconnect()
                    isLocking = false
                    currentTarget = nil
                    
                    -- ロックインジケーター無効化
                    if lockIndicator then
                        lockIndicator.Enabled = false
                    end
                    return
                end
                
                -- 設定距離以上離れたら自動解除
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local currentDistance = (LocalPlayer.Character.HumanoidRootPart.Position - currentTarget.Character.HumanoidRootPart.Position).Magnitude
                    local lookVector = LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector
                    if (Settings.LockDistanceEnabled and currentDistance > Settings.LockDistance) or not IsWithinDirectionalDistance(LocalPlayer.Character.HumanoidRootPart.Position, currentTarget.Character.HumanoidRootPart.Position, lookVector) then
                        lockConnection:Disconnect()
                        isLocking = false
                        currentTarget = nil
                        
                        -- アンロック音
                        if Settings.UnlockSoundEnabled then
                            unlockSound:Play()
                        end
                        
                        -- ロックインジケーター無効化
                        if lockIndicator then
                            lockIndicator.Enabled = false
                        end
                        return
                    end
                end
                
                -- 固定時間経過で解除
                if tick() - lockStartTime >= Settings.LockDuration then
                    lockConnection:Disconnect()
                    isLocking = false
                    currentTarget = nil
                    
                    -- アンロック音
                    if Settings.UnlockSoundEnabled then
                        unlockSound:Play()
                    end
                    
                    -- ロックインジケーター無効化
                    if lockIndicator then
                        lockIndicator.Enabled = false
                    end
                    return
                end
                
                -- カメラをターゲットに向ける
                if Settings.SmoothLockEnabled then
                    SmoothLookAt(currentTarget.Character.Head.Position)
                else
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, currentTarget.Character.Head.Position)
                end
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
                    lockStartTime = currentTime
                    
                    -- ロック音
                    if Settings.LockSoundEnabled then
                        lockSound:Play()
                    end
                    
                    -- 通知
                    Notify("🔒 ロック成功", enemy.Name .. " をロックしました", 2)
                    
                    -- ターゲット履歴に追加
                    table.insert(targetHistory, 1, {
                        player = enemy,
                        time = os.date("%H:%M:%S"),
                        duration = Settings.LockDuration
                    })
                    if #targetHistory > 10 then
                        table.remove(targetHistory, 11)
                    end
                    
                    if lockConnection then
                        lockConnection:Disconnect()
                    end
                    
                    lockConnection = RunService.RenderStepped:Connect(function()
                        if not Settings.LockEnabled or not currentTarget or not currentTarget.Character or not currentTarget.Character:FindFirstChild("Head") then
                            lockConnection:Disconnect()
                            isLocking = false
                            currentTarget = nil
                            
                            -- ロックインジケーター無効化
                            if lockIndicator then
                                lockIndicator.Enabled = false
                            end
                            return
                        end
                        
                        -- 設定距離以上離れたら自動解除
                        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            local currentDistance = (LocalPlayer.Character.HumanoidRootPart.Position - currentTarget.Character.HumanoidRootPart.Position).Magnitude
                            local lookVector = LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector
                            if (Settings.LockDistanceEnabled and currentDistance > Settings.LockDistance) or not IsWithinDirectionalDistance(LocalPlayer.Character.HumanoidRootPart.Position, currentTarget.Character.HumanoidRootPart.Position, lookVector) then
                                lockConnection:Disconnect()
                                isLocking = false
                                currentTarget = nil
                                
                                -- アンロック音
                                if Settings.UnlockSoundEnabled then
                                    unlockSound:Play()
                                end
                                
                                -- ロックインジケーター無効化
                                if lockIndicator then
                                    lockIndicator.Enabled = false
                                end
                                return
                            end
                            
                            -- ロック中に壁ができた場合は解除
                            if Settings.WallCheckEnabled then
                                local wallCheck = CheckWallBetween(LocalPlayer.Character.HumanoidRootPart.Position, currentTarget.Character.Head.Position)
                                if wallCheck then
                                    lockConnection:Disconnect()
                                    isLocking = false
                                    currentTarget = nil
                                    
                                    -- アンロック音
                                    if Settings.UnlockSoundEnabled then
                                        unlockSound:Play()
                                    end
                                    
                                    -- 通知
                                    Notify("🚫 壁検出", "壁が検出されたためロック解除", 2)
                                    
                                    -- ロックインジケーター無効化
                                    if lockIndicator then
                                        lockIndicator.Enabled = false
                                    end
                                    return
                                end
                            end
                        end
                        
                        -- 固定時間経過で解除
                        if tick() - lockStartTime >= Settings.LockDuration then
                            lockConnection:Disconnect()
                            isLocking = false
                            currentTarget = nil
                            
                            -- アンロック音
                            if Settings.UnlockSoundEnabled then
                                unlockSound:Play()
                            end
                            
                            -- ロックインジケーター無効化
                            if lockIndicator then
                                lockIndicator.Enabled = false
                            end
                            return
                        end
                        
                        -- カメラをターゲットに向ける
                        if Settings.SmoothLockEnabled then
                            SmoothLookAt(currentTarget.Character.Head.Position)
                        else
                            Camera.CFrame = CFrame.new(Camera.CFrame.Position, currentTarget.Character.Head.Position)
                        end
                    end)
                end
            else
                -- 壁がある場合はタイマーリセット
                wallCheckStartTime = 0
                
                -- ロックインジケーター無効化
                if lockIndicator then
                    lockIndicator.Enabled = false
                end
            end
        end
    else
        wallCheckStartTime = 0
        
        -- ロックインジケーター無効化
        if lockIndicator then
            lockIndicator.Enabled = false
        end
    end
end

-- Name ESPを作成する関数
local function CreateNameESP(player)
    if not player.Character or not player.Character:FindFirstChild("Head") then return end
    
    local nameTag = Drawing.new("Text")
    nameTag.Visible = false
    nameTag.Center = true
    nameTag.Outline = true
    nameTag.Font = Settings.NameESPFont
    nameTag.Size = Settings.NameESPSize
    nameTag.Color = Settings.NameESPColor
    nameTag.Transparency = Settings.NameESPTransparency
    
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not Settings.NameESPEnabled then
            nameTag.Visible = false
            return
        end
        
        if player.Character and player.Character:FindFirstChild("Head") then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local offset = Vector3.new(0, 1.5, 0)
                if Settings.NameESPPosition == "OnHead" then
                    offset = Vector3.new(0, 0.5, 0)
                end
                
                local pos, onScreen = Camera:WorldToViewportPoint(player.Character.Head.Position + offset)
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

-- Health ESPを作成する関数
local function CreateHealthESP(player)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local healthBar = Drawing.new("Line")
    local healthText = Drawing.new("Text")
    
    healthBar.Visible = false
    healthBar.Color = Settings.HealthESPColor
    healthBar.Thickness = 2
    
    healthText.Visible = false
    healthText.Center = true
    healthText.Outline = true
    healthText.Font = 2
    healthText.Size = Settings.HealthESPSize
    healthText.Color = Color3.new(1, 1, 1)
    
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not Settings.HealthESPEnabled then
            healthBar.Visible = false
            healthText.Visible = false
            return
        end
        
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local pos, onScreen = Camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
                if onScreen then
                    local healthPercent = humanoid.Health / humanoid.MaxHealth
                    
                    if Settings.HealthESPStyle == "Horizontal" then
                        -- 横型: 名前の上に表示
                        local barLength = 50
                        local filledLength = barLength * healthPercent
                        local yOffset = -30 -- 名前の上に表示
                        
                        healthBar.From = Vector2.new(pos.X - barLength/2, pos.Y + yOffset)
                        healthBar.To = Vector2.new(pos.X - barLength/2 + filledLength, pos.Y + yOffset)
                        
                        if healthPercent > 0.5 then
                            healthBar.Color = Color3.new(0, 1, 0)
                        elseif healthPercent > 0.25 then
                            healthBar.Color = Color3.new(1, 1, 0)
                        else
                            healthBar.Color = Color3.new(1, 0, 0)
                        end
                        
                        healthText.Position = Vector2.new(pos.X, pos.Y + yOffset - 15)
                        healthText.Text = math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth)
                        
                    else -- Vertical
                        -- 縦型: キャラクターの横に表示
                        local barHeight = 50
                        local filledHeight = barHeight * healthPercent
                        local xOffset = 40 -- キャラクターの右側
                        
                        healthBar.From = Vector2.new(pos.X + xOffset, pos.Y + barHeight/2)
                        healthBar.To = Vector2.new(pos.X + xOffset, pos.Y + barHeight/2 - filledHeight)
                        
                        if healthPercent > 0.5 then
                            healthBar.Color = Color3.new(0, 1, 0)
                        elseif healthPercent > 0.25 then
                            healthBar.Color = Color3.new(1, 1, 0)
                        else
                            healthBar.Color = Color3.new(1, 0, 0)
                        end
                        
                        healthText.Position = Vector2.new(pos.X + xOffset + 15, pos.Y)
                        healthText.Text = math.floor(humanoid.Health)
                    end
                    
                    healthBar.Visible = true
                    healthText.Visible = true
                else
                    healthBar.Visible = false
                    healthText.Visible = false
                end
            else
                healthBar.Visible = false
                healthText.Visible = false
            end
        else
            healthBar.Visible = false
            healthText.Visible = false
        end
    end)
    
    healthESPConnections[player] = {healthBar = healthBar, healthText = healthText, connection = connection}
end

-- Box ESPを作成する関数
local function CreateBoxESP(player)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = Settings.BoxESPColor
    box.Thickness = Settings.BoxESPThickness
    box.Filled = false
    
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not Settings.BoxESPEnabled then
            box.Visible = false
            return
        end
        
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local rootPos, onScreen = Camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
                
                if onScreen then
                    if Settings.BoxESPStyle == "Normal" then
                        -- 通常ボックス
                        local headPos = Camera:WorldToViewportPoint(player.Character.Head.Position)
                        local height = math.abs(headPos.Y - rootPos.Y) * 1.5
                        local width = height * 0.6
                        
                        box.Size = Vector2.new(width, height)
                        box.Position = Vector2.new(rootPos.X - width/2, rootPos.Y - height/2)
                    else -- FullBody
                        -- 全身ボックス
                        local torso = player.Character:FindFirstChild("Torso") or player.Character:FindFirstChild("UpperTorso")
                        local leftLeg = player.Character:FindFirstChild("Left Leg") or player.Character:FindFirstChild("LeftLowerLeg")
                        local rightLeg = player.Character:FindFirstChild("Right Leg") or player.Character:FindFirstChild("RightLowerLeg")
                        
                        if torso and leftLeg and rightLeg then
                            local torsoPos = Camera:WorldToViewportPoint(torso.Position)
                            local leftLegPos = Camera:WorldToViewportPoint(leftLeg.Position)
                            local rightLegPos = Camera:WorldToViewportPoint(rightLeg.Position)
                            
                            local minX = math.min(torsoPos.X, leftLegPos.X, rightLegPos.X)
                            local maxX = math.max(torsoPos.X, leftLegPos.X, rightLegPos.X)
                            local minY = math.min(torsoPos.Y, leftLegPos.Y, rightLegPos.Y)
                            local maxY = math.max(torsoPos.Y, leftLegPos.Y, rightLegPos.Y)
                            
                            box.Size = Vector2.new(maxX - minX + 20, maxY - minY + 20)
                            box.Position = Vector2.new(minX - 10, minY - 10)
                        end
                    end
                    
                    box.Visible = true
                else
                    box.Visible = false
                end
            else
                box.Visible = false
            end
        else
            box.Visible = false
        end
    end)
    
    boxESPConnections[player] = {box = box, connection = connection}
end

-- Traceを作成する関数
local function CreateTrace(player)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local trace
    if Settings.TraceShape == "Circle" then
        trace = Drawing.new("Circle")
    elseif Settings.TraceShape == "Square" then
        trace = Drawing.new("Square")
    else
        trace = Drawing.new("Line")
    end
    
    trace.Visible = false
    trace.Color = Settings.TraceColor
    trace.Thickness = Settings.TraceThickness
    trace.Transparency = Settings.TraceTransparency
    
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not Settings.TraceEnabled then
            trace.Visible = false
            return
        end
        
        trace.Thickness = Settings.TraceThickness
        trace.Color = Settings.TraceColor
        trace.Transparency = Settings.TraceTransparency
        
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local pos, onScreen = Camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
            if onScreen then
                if Settings.TraceShape == "Circle" then
                    trace.Position = Vector2.new(pos.X, pos.Y)
                    trace.Radius = Settings.TraceSize * 10
                    trace.Visible = true
                elseif Settings.TraceShape == "Square" then
                    trace.Size = Vector2.new(Settings.TraceSize * 20, Settings.TraceSize * 20)
                    trace.Position = Vector2.new(pos.X - Settings.TraceSize * 10, pos.Y - Settings.TraceSize * 10)
                    trace.Visible = true
                else -- Line
                    trace.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    trace.To = Vector2.new(pos.X, pos.Y)
                    trace.Visible = true
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
        CreateHealthESP(player)
        CreateBoxESP(player)
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
    if healthESPConnections[player] then
        healthESPConnections[player].connection:Disconnect()
        healthESPConnections[player].healthBar:Remove()
        healthESPConnections[player].healthText:Remove()
        healthESPConnections[player] = nil
    end
    if boxESPConnections[player] then
        boxESPConnections[player].connection:Disconnect()
        boxESPConnections[player].box:Remove()
        boxESPConnections[player] = nil
    end
    if playerDropdown then
        playerDropdown:Refresh(GetPlayerList(), true)
    end
end)

-- リセット関数
local function ResetLock()
    if lockConnection then
        lockConnection:Disconnect()
    end
    isLocking = false
    currentTarget = nil
    wallCheckStartTime = 0
    lastLockTime = 0
    
    if lockIndicator then
        lockIndicator.Enabled = false
    end
    
    Notify("🔄 リセット", "ロックシステムをリセットしました", 2)
end

-- ターゲットを手動設定
local function SetManualTarget(playerName)
    local player = Players:FindFirstChild(playerName)
    if player and player ~= LocalPlayer then
        Settings.TargetPlayer = playerName
        Settings.TargetPlayerID = nil
        Notify("🎯 ターゲット設定", playerName .. " をターゲットに設定しました", 3)
    else
        Notify("⚠️ エラー", "プレイヤーが見つかりません: " .. playerName, 3)
    end
end

-- メインタブの機能
MainTab:CreateSection("🔒 固定システム")

local LockToggle = MainTab:CreateToggle({
    Name = "固定 メイン",
    CurrentValue = false,
    Flag = "HeadLockToggle",
    Callback = function(Value)
        Settings.LockEnabled = Value
        if Value then
            Notify("✅ 有効化", "固定システムが有効になりました", 2)
        else
            Notify("❌ 無効化", "固定システムが無効になりました", 2)
            ResetLock()
        end
    end,
})

MainTab:CreateButton({
    Name = "🔄 固定リセット",
    Callback = function()
        ResetLock()
    end,
})

MainTab:CreateSection("🎯 ターゲット設定")

-- プレイヤーリスト表示用ラベル
local playerListLabel = MainTab:CreateLabel("サーバープレイヤーリスト: 読み込み中...")

playerDropdown = MainTab:CreateDropdown({
    Name = "ターゲットプレイヤー選択",
    Options = {"なし"},
    CurrentOption = {"なし"},
    MultipleOptions = false,
    Flag = "TargetPlayerDropdown",
    Callback = function(Option)
        if Option[1] == "なし" then
            Settings.TargetPlayer = nil
            Settings.TargetPlayerID = nil
            Notify("🎯 ターゲット解除", "全プレイヤーを対象にします", 2)
        else
            SetManualTarget(Option[1])
        end
    end,
})

MainTab:CreateInput({
    Name = "プレイヤーIDで指定",
    PlaceholderText = "ユーザーIDを入力",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        local userId = tonumber(Text)
        if userId then
            Settings.TargetPlayerID = userId
            Settings.TargetPlayer = nil
            Notify("🎯 ID設定", "ユーザーID: " .. userId .. " をターゲットに設定", 3)
        else
            Notify("⚠️ エラー", "有効なユーザーIDを入力してください", 3)
        end
    end,
})

-- プレイヤーリスト更新
task.spawn(function()
    while task.wait(2) do
        local playerNames = GetPlayerList()
        local playerListText = "サーバープレイヤーリスト:\n"
        
        if #playerNames > 0 then
            for i, name in ipairs(playerNames) do
                playerListText = playerListText .. i .. ". " .. name .. "\n"
            end
        else
            playerListText = playerListText .. "プレイヤーがいません"
        end
        
        playerListLabel:SetText(playerListText)
        
        -- ドロップダウンも更新
        if playerDropdown then
            local currentList = {"なし"}
            for _, name in ipairs(playerNames) do
                table.insert(currentList, name)
            end
            playerDropdown:Refresh(currentList, true)
        end
    end
end)

MainTab:CreateSection("👁️ ESPシステム")

local NameESPToggle = MainTab:CreateToggle({
    Name = "ネームESP",
    CurrentValue = false,
    Flag = "NameESPToggle",
    Callback = function(Value)
        Settings.NameESPEnabled = Value
    end,
})

local HealthESPToggle = MainTab:CreateToggle({
    Name = "ヘルスESP",
    CurrentValue = false,
    Flag = "HealthESPToggle",
    Callback = function(Value)
        Settings.HealthESPEnabled = Value
    end,
})

local BoxESPToggle = MainTab:CreateToggle({
    Name = "ボックスESP",
    CurrentValue = false,
    Flag = "BoxESPToggle",
    Callback = function(Value)
        Settings.BoxESPEnabled = Value
    end,
})

local TraceToggle = MainTab:CreateToggle({
    Name = "🔴 トレース",
    CurrentValue = false,
    Flag = "TraceToggle",
    Callback = function(Value)
        Settings.TraceEnabled = Value
    end,
})

-- 設定タブ
SettingsTab:CreateSection("📏 ロック距離設定")

local LockDistanceToggle = SettingsTab:CreateToggle({
    Name = "全体距離を有効化",
    CurrentValue = false,
    Flag = "LockDistanceToggle",
    Callback = function(Value)
        Settings.LockDistanceEnabled = Value
    end,
})

SettingsTab:CreateSlider({
    Name = "全体距離（スタッド）",
    Range = {1, 100},
    Increment = 1,
    CurrentValue = 5,
    Flag = "LockDistanceSlider",
    Callback = function(Value)
        Settings.LockDistance = Value
    end,
})

SettingsTab:CreateInput({
    Name = "全体距離（直接入力）",
    PlaceholderText = "数値を入力",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        local value = tonumber(Text)
        if value and value >= 1 and value <= 100 then
            Settings.LockDistance = value
        end
    end,
})

local LockDistanceFrontToggle = SettingsTab:CreateToggle({
    Name = "前方距離を有効化",
    CurrentValue = false,
    Flag = "LockDistanceFrontToggle",
    Callback = function(Value)
        Settings.LockDistanceFrontEnabled = Value
    end,
})

SettingsTab:CreateSlider({
    Name = "前方距離（スタッド）",
    Range = {1, 50},
    Increment = 1,
    CurrentValue = 5,
    Flag = "LockDistanceFrontSlider",
    Callback = function(Value)
        Settings.LockDistanceFront = Value
    end,
})

SettingsTab:CreateInput({
    Name = "前方距離（直接入力）",
    PlaceholderText = "数値を入力",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        local value = tonumber(Text)
        if value and value >= 1 and value <= 50 then
            Settings.LockDistanceFront = value
        end
    end,
})

local LockDistanceBackToggle = SettingsTab:CreateToggle({
    Name = "後方距離を有効化",
    CurrentValue = false,
    Flag = "LockDistanceBackToggle",
    Callback = function(Value)
        Settings.LockDistanceBackEnabled = Value
    end,
})

SettingsTab:CreateSlider({
    Name = "後方距離（スタッド）",
    Range = {1, 50},
    Increment = 1,
    CurrentValue = 5,
    Flag = "LockDistanceBackSlider",
    Callback = function(Value)
        Settings.LockDistanceBack = Value
    end,
})

SettingsTab:CreateInput({
    Name = "後方距離（直接入力）",
    PlaceholderText = "数値を入力",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        local value = tonumber(Text)
        if value and value >= 1 and value <= 50 then
            Settings.LockDistanceBack = value
        end
    end,
})

local LockDistanceLeftToggle = SettingsTab:CreateToggle({
    Name = "左方向距離を有効化",
    CurrentValue = false,
    Flag = "LockDistanceLeftToggle",
    Callback = function(Value)
        Settings.LockDistanceLeftEnabled = Value
    end,
})

SettingsTab:CreateSlider({
    Name = "左方向距離（スタッド）",
    Range = {1, 50},
    Increment = 1,
    CurrentValue = 5,
    Flag = "LockDistanceLeftSlider",
    Callback = function(Value)
        Settings.LockDistanceLeft = Value
    end,
})

SettingsTab:CreateInput({
    Name = "左方向距離（直接入力）",
    PlaceholderText = "数値を入力",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        local value = tonumber(Text)
        if value and value >= 1 and value <= 50 then
            Settings.LockDistanceLeft = value
        end
    end,
})

local LockDistanceRightToggle = SettingsTab:CreateToggle({
    Name = "右方向距離を有効化",
    CurrentValue = false,
    Flag = "LockDistanceRightToggle",
    Callback = function(Value)
        Settings.LockDistanceRightEnabled = Value
    end,
})

SettingsTab:CreateSlider({
    Name = "右方向距離（スタッド）",
    Range = {1, 50},
    Increment = 1,
    CurrentValue = 5,
    Flag = "LockDistanceRightSlider",
    Callback = function(Value)
        Settings.LockDistanceRight = Value
    end,
})

SettingsTab:CreateInput({
    Name = "右方向距離（直接入力）",
    PlaceholderText = "数値を入力",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        local value = tonumber(Text)
        if value and value >= 1 and value <= 50 then
            Settings.LockDistanceRight = value
        end
    end,
})

SettingsTab:CreateSection("⏱️ ロックタイミング設定")

local WallCheckToggle = SettingsTab:CreateToggle({
    Name = "🧱 壁判定",
    CurrentValue = true,
    Flag = "WallCheckToggle",
    Callback = function(Value)
        Settings.WallCheckEnabled = Value
        if not Value then
            Notify("💪 強力モード", "壁判定無効 - 壁越しロック可能", 3)
        end
    end,
})

SettingsTab:CreateSlider({
    Name = "壁判定遅延（秒）",
    Range = {0, 5},
    Increment = 0.1,
    CurrentValue = 0,
    Flag = "WallCheckDelaySlider",
    Callback = function(Value)
        Settings.WallCheckDelay = Value
    end,
})

SettingsTab:CreateParagraph({
    Title = "壁判定遅延の詳細",
    Content = "壁がない状態が設定秒数続いた後にロック開始\n0 = 即時ロック\n高い値 = より確実な壁判定"
})

SettingsTab:CreateSlider({
    Name = "ロック接続時間（秒）",
    Range = {0.1, 10},
    Increment = 0.1,
    CurrentValue = 0.5,
    Flag = "LockDurationSlider",
    Callback = function(Value)
        Settings.LockDuration = Value
    end,
})

SettingsTab:CreateSlider({
    Name = "クールダウン時間（秒）",
    Range = {0.1, 10},
    Increment = 0.1,
    CurrentValue = 1,
    Flag = "CooldownSlider",
    Callback = function(Value)
        Settings.CooldownTime = Value
    end,
})

SettingsTab:CreateSection("🎮 高度な設定")

local SmoothLockToggle = SettingsTab:CreateToggle({
    Name = "🌀 スムーズロック",
    CurrentValue = false,
    Flag = "SmoothLockToggle",
    Callback = function(Value)
        Settings.SmoothLockEnabled = Value
    end,
})

SettingsTab:CreateSlider({
    Name = "スムーズ速度",
    Range = {0.001, 1},
    Increment = 0.001,
    CurrentValue = 0.1,
    Flag = "SmoothLockSpeedSlider",
    Callback = function(Value)
        Settings.SmoothLockSpeed = Value
    end,
})

SettingsTab:CreateInput({
    Name = "スムーズ速度（直接入力）",
    PlaceholderText = "0.001～1",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        local value = tonumber(Text)
        if value and value >= 0.001 and value <= 1 then
            Settings.SmoothLockSpeed = value
        end
    end,
})

local LockPriorityDropdown = SettingsTab:CreateDropdown({
    Name = "ターゲット優先度",
    Options = {"最近", "低HP", "ランダム"},
    CurrentOption = {"最近"},
    MultipleOptions = false,
    Flag = "LockPriorityDropdown",
    Callback = function(Option)
        if Option[1] == "最近" then
            Settings.LockPriority = "Closest"
        elseif Option[1] == "低HP" then
            Settings.LockPriority = "LowestHealth"
        elseif Option[1] == "ランダム" then
            Settings.LockPriority = "Random"
        end
    end,
})

SettingsTab:CreateSection("🔧 トレース設定")

SettingsTab:CreateSlider({
    Name = "トレースの太さ",
    Range = {1, 10},
    Increment = 1,
    CurrentValue = 1,
    Flag = "TraceThicknessSlider",
    Callback = function(Value)
        Settings.TraceThickness = Value
    end,
})

SettingsTab:CreateSlider({
    Name = "トレースの薄さ",
    Range = {0, 1},
    Increment = 0.1,
    CurrentValue = 0.1,
    Flag = "TraceTransparencySlider",
    Callback = function(Value)
        Settings.TraceTransparency = Value
    end,
})

SettingsTab:CreateSlider({
    Name = "トレースの大きさ",
    Range = {0.5, 5},
    Increment = 0.1,
    CurrentValue = 1,
    Flag = "TraceSizeSlider",
    Callback = function(Value)
        Settings.TraceSize = Value
    end,
})

local TraceColorPicker = SettingsTab:CreateColorPicker({
    Name = "トレースの色",
    Color = Color3.fromRGB(255, 50, 50),
    Flag = "TraceColorPicker",
    Callback = function(Value)
        Settings.TraceColor = Value
    end
})

local TraceShapeDropdown = SettingsTab:CreateDropdown({
    Name = "トレースの形",
    Options = {"線", "円", "四角"},
    CurrentOption = {"線"},
    MultipleOptions = false,
    Flag = "TraceShapeDropdown",
    Callback = function(Option)
        if Option[1] == "線" then
            Settings.TraceShape = "Line"
        elseif Option[1] == "円" then
            Settings.TraceShape = "Circle"
        elseif Option[1] == "四角" then
            Settings.TraceShape = "Square"
        end
    end,
})

SettingsTab:CreateSection("🔔 通知設定")

local NotificationToggle = SettingsTab:CreateToggle({
    Name = "通知表示",
    CurrentValue = false,
    Flag = "NotificationToggle",
    Callback = function(Value)
        Settings.NotificationEnabled = Value
    end,
})

local LockSoundToggle = SettingsTab:CreateToggle({
    Name = "ロック音",
    CurrentValue = true,
    Flag = "LockSoundToggle",
    Callback = function(Value)
        Settings.LockSoundEnabled = Value
    end,
})

local UnlockSoundToggle = SettingsTab:CreateToggle({
    Name = "アンロック音",
    CurrentValue = true,
    Flag = "UnlockSoundToggle",
    Callback = function(Value)
        Settings.UnlockSoundEnabled = Value
    end,
})

local LockIndicatorToggle = SettingsTab:CreateToggle({
    Name = "ロックインジケーター",
    CurrentValue = true,
    Flag = "LockIndicatorToggle",
    Callback = function(Value)
        Settings.ShowLockIndicator = Value
        if Value and not lockIndicator then
            CreateLockIndicator()
        end
    end,
})

local ResetOnDeathToggle = SettingsTab:CreateToggle({
    Name = "死亡時リセット",
    CurrentValue = true,
    Flag = "ResetOnDeathToggle",
    Callback = function(Value)
        Settings.ResetOnDeath = Value
    end,
})

-- ESP設定タブ
ESPTab:CreateSection("📝 ネームESP設定")

local NameESPFontDropdown = ESPTab:CreateDropdown({
    Name = "フォント",
    Options = {"UI", "System", "Monospace", "Legacy", "Arcade", "Fantasy", "SciFi", "Cursive", "Script", "Small", "Medium", "Large"},
    CurrentOption = {"System"},
    MultipleOptions = false,
    Flag = "NameESPFontDropdown",
    Callback = function(Option)
        local fontMap = {
            ["UI"] = 0,
            ["System"] = 1,
            ["Monospace"] = 2,
            ["Legacy"] = 3,
            ["Arcade"] = 4,
            ["Fantasy"] = 5,
            ["SciFi"] = 6,
            ["Cursive"] = 7,
            ["Script"] = 8,
            ["Small"] = 9,
            ["Medium"] = 10,
            ["Large"] = 11
        }
        Settings.NameESPFont = fontMap[Option[1]] or 2
    end,
})

local NameESPColorPicker = ESPTab:CreateColorPicker({
    Name = "ネームESPの色",
    Color = Color3.fromRGB(255, 255, 255),
    Flag = "NameESPColorPicker",
    Callback = function(Value)
        Settings.NameESPColor = Value
    end
})

ESPTab:CreateSlider({
    Name = "ネームESPの大きさ",
    Range = {8, 32},
    Increment = 1,
    CurrentValue = 16,
    Flag = "NameESPSizeSlider",
    Callback = function(Value)
        Settings.NameESPSize = Value
    end,
})

ESPTab:CreateSlider({
    Name = "ネームESPの薄さ",
    Range = {0, 1},
    Increment = 0.1,
    CurrentValue = 0,
    Flag = "NameESPTransparencySlider",
    Callback = function(Value)
        Settings.NameESPTransparency = Value
    end,
})

local NameESPPositionDropdown = ESPTab:CreateDropdown({
    Name = "ネームESP表示位置",
    Options = {"頭の上", "頭に表示"},
    CurrentOption = {"頭の上"},
    MultipleOptions = false,
    Flag = "NameESPPositionDropdown",
    Callback = function(Option)
        if Option[1] == "頭の上" then
            Settings.NameESPPosition = "AboveHead"
        else
            Settings.NameESPPosition = "OnHead"
        end
    end,
})

ESPTab:CreateSection("❤️ ヘルスESP設定")

local HealthESPStyleDropdown = ESPTab:CreateDropdown({
    Name = "ヘルスESPスタイル",
    Options = {"横型", "縦型"},
    CurrentOption = {"横型"},
    MultipleOptions = false,
    Flag = "HealthESPStyleDropdown",
    Callback = function(Option)
        if Option[1] == "横型" then
            Settings.HealthESPStyle = "Horizontal"
        else
            Settings.HealthESPStyle = "Vertical"
        end
    end,
})

local HealthESPColorPicker = ESPTab:CreateColorPicker({
    Name = "ヘルスESPの色",
    Color = Color3.fromRGB(0, 255, 0),
    Flag = "HealthESPColorPicker",
    Callback = function(Value)
        Settings.HealthESPColor = Value
    end
})

ESPTab:CreateSlider({
    Name = "ヘルスESPの大きさ",
    Range = {8, 24},
    Increment = 1,
    CurrentValue = 14,
    Flag = "HealthESPSizeSlider",
    Callback = function(Value)
        Settings.HealthESPSize = Value
    end,
})

ESPTab:CreateSection("📦 ボックスESP設定")

local BoxESPColorPicker = ESPTab:CreateColorPicker({
    Name = "ボックスESPの色",
    Color = Color3.fromRGB(0, 255, 0),
    Flag = "BoxESPColorPicker",
    Callback = function(Value)
        Settings.BoxESPColor = Value
    end
})

ESPTab:CreateSlider({
    Name = "ボックスESPの太さ",
    Range = {1, 5},
    Increment = 1,
    CurrentValue = 1,
    Flag = "BoxESPThicknessSlider",
    Callback = function(Value)
        Settings.BoxESPThickness = Value
    end,
})

local BoxESPStyleDropdown = ESPTab:CreateDropdown({
    Name = "ボックスESPスタイル",
    Options = {"通常", "全身ボックス"},
    CurrentOption = {"通常"},
    MultipleOptions = false,
    Flag = "BoxESPStyleDropdown",
    Callback = function(Option)
        if Option[1] == "通常" then
            Settings.BoxESPStyle = "Normal"
        else
            Settings.BoxESPStyle = "FullBody"
        end
    end,
})

-- 情報タブ
InfoTab:CreateSection("📊 システム情報")

local currentTargetLabel = InfoTab:CreateLabel("現在のターゲット: " .. (currentTarget and currentTarget.Name or "なし"))
local lockStatusLabel = InfoTab:CreateLabel("ロック状態: " .. (isLocking and "🔒 ロック中" or "🔓 未ロック"))
local wallCheckLabel = InfoTab:CreateLabel("壁判定: " .. (Settings.WallCheckEnabled and "有効" or "無効"))

task.spawn(function()
    while task.wait(1) do
        currentTargetLabel:SetText("現在のターゲット: " .. (currentTarget and currentTarget.Name or "なし"))
        lockStatusLabel:SetText("ロック状態: " .. (isLocking and "🔒 ロック中" or "🔓 未ロック"))
        wallCheckLabel:SetText("壁判定: " .. (Settings.WallCheckEnabled and "有効" or "無効"))
    end
end)

InfoTab:CreateSection("📈 ターゲット履歴")

local historyLabel = InfoTab:CreateLabel("履歴は最大10件保存されます")

InfoTab:CreateButton({
    Name = "履歴を更新",
    Callback = function()
        local historyText = "ターゲット履歴:\n"
        if #targetHistory > 0 then
            for i, entry in ipairs(targetHistory) do
                historyText = historyText .. string.format("%d. %s - %s (%s秒)\n", 
                    i, entry.player.Name, entry.time, entry.duration)
            end
        else
            historyText = historyText .. "履歴はありません"
        end
        historyLabel:SetText(historyText)
    end,
})

InfoTab:CreateSection("ℹ️ 使い方")

InfoTab:CreateParagraph({
    Title = "基本操作",
    Content = "1. メインタブで固定を有効化\n2. 設定タブで各種パラメータを調整\n3. 特定のプレイヤーをターゲットにする場合はドロップダウンから選択\n4. リセットボタンでロック状態をクリア"
})

InfoTab:CreateParagraph({
    Title = "壁判定機能",
    Content = "有効時: 壁がない場合のみロック\n無効時: 壁を無視して即座にロック（強力モード）\n遅延設定: 壁がない状態が設定秒数続いた後にロック"
})

InfoTab:CreateParagraph({
    Title = "ESP機能",
    Content = "ネームESP: プレイヤー名を表示\nヘルスESP: HPバーと数値を表示\nボックスESP: プレイヤー周囲にボックスを表示\nトレース: プレイヤーへの視覚的ガイド"
})

-- メインループ
RunService.RenderStepped:Connect(function()
    LockToHead()
end)

-- キーバインド設定（オプション）
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.RightControl then
        Settings.LockEnabled = not Settings.LockEnabled
        Notify("キーバインド", "固定: " .. (Settings.LockEnabled and "有効" or "無効"), 2)
    end
    
    if input.KeyCode == Enum.KeyCode.RightShift then
        ResetLock()
    end
end)

-- 初期化
task.spawn(function()
    task.wait(2)
    SetupAllPlayers()
    CreateLockIndicator()
    Notify("🎉 Syu_uhub 起動", "fling things and people top script が起動しました", 5)
    Notify("💡 ヒント", "右Ctrlキーで固定ON/OFF、右Shiftでリセット", 5)
end)

Rayfield:LoadConfiguration()

-- 終了時のクリーンアップ
game:GetService("CoreGui").ChildRemoved:Connect(function(child)
    if child.Name == "Rayfield" then
        -- すべての接続を切断
        if lockConnection then
            lockConnection:Disconnect()
        end
        
        -- すべてのDrawingオブジェクトを削除
        for _, connectionData in pairs(traceConnections) do
            connectionData.connection:Disconnect()
            connectionData.trace:Remove()
        end
        
        for _, connectionData in pairs(nameESPConnections) do
            connectionData.connection:Disconnect()
            connectionData.nameTag:Remove()
        end
        
        for _, connectionData in pairs(healthESPConnections) do
            connectionData.connection:Disconnect()
            connectionData.healthBar:Remove()
            connectionData.healthText:Remove()
        end
        
        for _, connectionData in pairs(boxESPConnections) do
            connectionData.connection:Disconnect()
            connectionData.box:Remove()
        end
        
        -- ロックインジケーターを削除
        if lockIndicator then
            lockIndicator:Destroy()
        end
    end
end)
