-- ==============================================================================
-- 🔥 KAITUN SAILOR 2 - Auto Farm Max Level + KillAura + Auto Stats
-- Xeno-style: Teleport + CFrame lock trong cùng 1 coroutine (không bị kéo về)
-- Kill Aura: spawn thread riêng mỗi mob, fire đồng thời
-- Auto Quest: tự tìm quest/mob/đảo theo level
-- Auto Stats: +10 Melee & +10 Defense liên tục
-- ==============================================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Player            = Players.LocalPlayer

-- ═══════════════════════════════════════
-- MODULES
-- ═══════════════════════════════════════
local questcheck = require(ReplicatedStorage.Modules.QuestConfig)
local checkmap   = require(ReplicatedStorage.TravelConfig)
local portalCfg  = require(ReplicatedStorage.PortalConfig)

-- ═══════════════════════════════════════
-- REMOTES (cache 1 lần)
-- ═══════════════════════════════════════
local combatRemote   = ReplicatedStorage:WaitForChild("CombatSystem"):WaitForChild("Remotes"):WaitForChild("RequestHit")
local questAcceptR   = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("QuestAccept")
local questAbandonR  = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("QuestAbandon")
local teleportRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TeleportToPortal")
local allocateRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("AllocateStat")

-- ═══════════════════════════════════════
-- CUSTOM HUD
-- ═══════════════════════════════════════
local farmStatus = "Starting..."
local taskStatus = "Getting quest..."

local function createHUD()
    local old = Player.PlayerGui:FindFirstChild("KaitunHUD")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "KaitunHUD"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = Player.PlayerGui

    local frame = Instance.new("Frame")
    frame.Name = "Main"
    frame.Size = UDim2.new(0, 420, 0, 120)
    frame.Position = UDim2.new(0.5, -210, 0, 8)
    frame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Parent = frame

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 255)),
        ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 0, 255)),
        ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 255, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 255)),
    })
    gradient.Parent = stroke

    task.spawn(function()
        local t = 0
        while gui.Parent do
            t = (t + 0.005) % 1
            gradient.Offset = Vector2.new(t, 0)
            RunService.Heartbeat:Wait()
        end
    end)

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.Size = UDim2.new(1, -20, 0, 22)
    statusLabel.Position = UDim2.new(0, 10, 0, 8)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 14
    statusLabel.TextColor3 = Color3.fromRGB(0, 255, 180)
    statusLabel.Text = "Auto Farm: Starting..."
    statusLabel.TextXAlignment = Enum.TextXAlignment.Center
    statusLabel.Parent = frame

    local taskLabel = Instance.new("TextLabel")
    taskLabel.Name = "Task"
    taskLabel.Size = UDim2.new(1, -20, 0, 20)
    taskLabel.Position = UDim2.new(0, 10, 0, 30)
    taskLabel.BackgroundTransparency = 1
    taskLabel.Font = Enum.Font.Gotham
    taskLabel.TextSize = 12
    taskLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
    taskLabel.Text = "Task: Getting quest..."
    taskLabel.TextXAlignment = Enum.TextXAlignment.Center
    taskLabel.Parent = frame

    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(0.9, 0, 0, 1)
    sep.Position = UDim2.new(0.05, 0, 0, 55)
    sep.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    sep.BorderSizePixel = 0
    sep.Parent = frame

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "Info"
    infoLabel.Size = UDim2.new(1, -20, 0, 22)
    infoLabel.Position = UDim2.new(0, 10, 0, 62)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Font = Enum.Font.GothamBold
    infoLabel.TextSize = 13
    infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    infoLabel.Text = "Lv.0 | Money: 0 | Gems: 0"
    infoLabel.TextXAlignment = Enum.TextXAlignment.Center
    infoLabel.RichText = true
    infoLabel.Parent = frame

    local statsLabel = Instance.new("TextLabel")
    statsLabel.Name = "Stats"
    statsLabel.Size = UDim2.new(1, -20, 0, 20)
    statsLabel.Position = UDim2.new(0, 10, 0, 86)
    statsLabel.BackgroundTransparency = 1
    statsLabel.Font = Enum.Font.Gotham
    statsLabel.TextSize = 11
    statsLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
    statsLabel.Text = "Auto Stats: +10 Melee & +10 Defense"
    statsLabel.TextXAlignment = Enum.TextXAlignment.Center
    statsLabel.Parent = frame

    return gui
end

local hud = createHUD()

-- Cập nhật HUD mỗi 0.5s
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            local main = hud and hud:FindFirstChild("Main")
            if not main then hud = createHUD(); main = hud:FindFirstChild("Main") end

            local data = Player:FindFirstChild("Data")
            local level = data and data:FindFirstChild("Level") and data.Level.Value or "?"
            local money = data and data:FindFirstChild("Money") and data.Money.Value or 0
            local gems  = data and data:FindFirstChild("Gems") and data.Gems.Value or 0

            local function fmt(n)
                local s = tostring(n)
                local pos, result = #s, ""
                for i = #s, 1, -1 do
                    result = s:sub(i, i) .. result
                    pos = pos - 1
                    if pos > 0 and (#s - i + 1) % 3 == 0 then result = "," .. result end
                end
                return result
            end

            main.Status.Text = "Auto Farm: " .. farmStatus
            main.Task.Text = "Task: " .. taskStatus
            main.Info.Text = '<font color="#00FF99">Lv.' .. tostring(level) .. '</font>  |  <font color="#FFD700">Money: ' .. fmt(money) .. '</font>  |  <font color="#00BFFF">Gems: ' .. fmt(gems) .. '</font>'
        end)
    end
end)

Player.CharacterAdded:Connect(function()
    task.wait(1)
    hud = createHUD()
end)

-- ═══════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════
local KILL_AURA_RANGE = 50
local FARM_HEIGHT     = 6    -- bay trên mob bao nhiêu studs

-- ═══════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════
local homeIsland       = nil
local lastAcceptTime   = 0
local missCount        = 0
local MAX_MISS         = 5
local currentChoosenpc = nil
local currentTargetNPC = nil
local prevChoosenpc    = nil
local lockedPos        = nil
local homePortal       = nil   -- portal arg cho teleport (từ mobConfig)

-- ═══════════════════════════════════════
-- MOB CONFIG (mob → island trực tiếp, không cần scan)
-- ═══════════════════════════════════════
local mobConfig = {
    ["Thief"]          = { island = "Starter",     zoneId = "StarterIsland"     },
    ["ThiefBoss"]      = { island = "Starter",     zoneId = "StarterIsland"     },
    ["Monkey"]         = { island = "Jungle",      zoneId = "JungleIsland"      },
    ["MonkeyBoss"]     = { island = "Jungle",      zoneId = "JungleIsland"      },
    ["DesertBandit"]   = { island = "Desert",      zoneId = "DesertIsland"      },
    ["DesertBoss"]     = { island = "Desert",      zoneId = "DesertIsland"      },
    ["FrostRogue"]     = { island = "Snow",        zoneId = "SnowIsland"        },
    ["SnowBoss"]       = { island = "Snow",        zoneId = "SnowIsland"        },
    ["Sorcerer"]       = { island = "Shibuya",     zoneId = "ShibuyaStation"    },
    ["PandaMiniBoss"]  = { island = "Shibuya",     zoneId = "ShibuyaStation"    },
    ["Hollow"]         = { island = "HuecoMundo",  zoneId = "HuecoMundo"        },
    ["StrongSorcerer"] = { island = "Shinjuku",    zoneId = "ShinjukuIsland"    },
    ["Curse"]          = { island = "Shinjuku",    zoneId = "ShinjukuIsland"    },
    ["Slime"]          = { island = "Slime",       zoneId = "SlimeIsland"       },
    ["SlimeWarrior"]   = { island = "Slime",       zoneId = "SlimeIsland"       },
    ["AcademyTeacher"] = { island = "Academy",     zoneId = "AcademyIsland"     },
    ["Swordsman"]      = { island = "Judgement",   zoneId = "JudgementIsland"   },
    ["Quincy"]         = { island = "SoulSociety", zoneId = "SoulSocietyIsland" },
    ["Ninja"]          = { island = "Ninja",       zoneId = "NinjaIsland"       },
    ["ArenaFighter"]   = { island = "Lawless",     zoneId = "LawlessIsland"     },
}

-- Mob cần skip (Quincy phải làm nhiệm vụ mở cổng)
local SKIP_MOBS = { ["Quincy"] = true }

-- Fallback: sorted islands cho scan nếu mob không có trong mobConfig
local sortedIslands = (function()
    local list = {}
    for _, portal in ipairs(portalCfg.GetSortedPortals()) do
        table.insert(list, portal.data.IslandFolder)
    end
    return list
end)()

-- ═══════════════════════════════════════
-- XENO STABILIZERS
-- ═══════════════════════════════════════
local function applyXenoStabilizers(root, goalCF)
    local bv = root:FindFirstChild("KaitunStabBV")
    if not bv then
        bv = Instance.new("BodyVelocity")
        bv.Name = "KaitunStabBV"
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.P = 1250
        bv.Parent = root
    end
    bv.Velocity = Vector3.zero

    local bg = root:FindFirstChild("KaitunStabBG")
    if not bg then
        bg = Instance.new("BodyGyro")
        bg.Name = "KaitunStabBG"
        bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bg.P = 3000
        bg.D = 500
        bg.Parent = root
    end
    bg.CFrame = goalCF
end

local function cleanupXenoStabilizers()
    pcall(function()
        local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local bv = root:FindFirstChild("KaitunStabBV")
        local bg = root:FindFirstChild("KaitunStabBG")
        if bv then bv:Destroy() end
        if bg then bg:Destroy() end
    end)
end

-- ═══════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════
local function getRoot()
    return Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
end

local function getMobPos(npc)
    local hrp = npc:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.Position end
    if npc.PrimaryPart then return npc.PrimaryPart.Position end
    local ok, pivot = pcall(function() return npc:GetPivot().Position end)
    if ok and pivot then return pivot end
    for _, part in pairs(npc:GetDescendants()) do
        if part:IsA("BasePart") then return part.Position end
    end
    return nil
end

local function getTargetQuest()
    local level = Player.Data.Level.Value
    local bestNPC, maxLevelFound, choosenpc = nil, -1, nil
    for npcName, data in pairs(questcheck.RepeatableQuests) do
        local req = tonumber(data.recommendedLevel) or 0
        if level >= req and req > maxLevelFound then
            local mobType = data.requirements and data.requirements[1] and data.requirements[1].npcType
            -- Skip mob cần mở cổng (Quincy) → nhảy sang mob tiếp theo
            if mobType and SKIP_MOBS[mobType] then continue end
            maxLevelFound = req
            bestNPC = npcName
            choosenpc = mobType
        end
    end
    return bestNPC, maxLevelFound, choosenpc
end

local function findClosestMob(mobType)
    local npcsFolder = workspace:FindFirstChild("NPCs")
    if not npcsFolder then return nil end
    local root = getRoot()
    if not root then return nil end

    local closest, closestDist = nil, math.huge
    for _, npc in pairs(npcsFolder:GetChildren()) do
        if string.find(npc.Name, mobType) then
            local hum = npc:FindFirstChildOfClass("Humanoid")
            local pos = getMobPos(npc)
            if hum and hum.Health > 0 and pos then
                local dist = (root.Position - pos).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closest = npc
                end
            end
        end
    end
    return closest, closestDist
end

print("[Kaitun 2] Auto Farm ON — Kill Aura Range: " .. KILL_AURA_RANGE .. " | Height: " .. FARM_HEIGHT)

-- ═══════════════════════════════════════════════════════════
-- MAIN FARM LOOP (Xeno-style single thread)
-- Quest + Teleport + CFrame Lock đều trong 1 coroutine
-- KHÔNG có gap giữa teleport và lock → server không kéo về
-- ═══════════════════════════════════════════════════════════
task.spawn(function()
    while task.wait(0.5) do
        -- Auto Equip weapon
        pcall(function()
            if Player.Character and not Player.Character:FindFirstChildWhichIsA("Tool") then
                for _, v in pairs(Player.Backpack:GetChildren()) do
                    if v:IsA("Tool") then Player.Character.Humanoid:EquipTool(v) break end
                end
            end
        end)

        farmStatus = "Getting quest..."
        taskStatus = "Checking level & quest..."

        local targetNPC, _, choosenpc = getTargetQuest()
        if not (targetNPC and choosenpc) then continue end

        taskStatus = "Quest: " .. tostring(targetNPC) .. " | Mob: " .. tostring(choosenpc)

        -- Detect level-up → mob type thay đổi → reset
        if choosenpc ~= prevChoosenpc then
            if prevChoosenpc then
                print("[Kaitun 2] Level up! Mob đổi: " .. tostring(prevChoosenpc) .. " → " .. choosenpc)
                pcall(function() questAbandonR:FireServer("repeatable") end)
                task.wait(0.5)
                homeIsland = nil
                homePortal = nil
                lockedPos = nil
                missCount = 0
                cleanupXenoStabilizers()
            end
            prevChoosenpc = choosenpc
        end

        currentTargetNPC = targetNPC
        currentChoosenpc = choosenpc

        -- Nhận quest (cooldown 5s)
        if tick() - lastAcceptTime > 5 then
            pcall(function() questAcceptR:FireServer(targetNPC) end)
            lastAcceptTime = tick()
            task.wait(0.5)
        end

        local hrp = getRoot()
        if not hrp then continue end

        local currentZoneId, currentZoneData = checkmap.GetZoneAt(hrp.Position)

        -- ═══ Đã biết homeIsland ═══
        if homeIsland then
            -- Teleport nếu chưa ở đúng đảo
            if currentZoneId ~= homeIsland then
                farmStatus = "Teleporting to " .. (homePortal or homeIsland) .. "..."
                pcall(function() teleportRemote:FireServer(homePortal) end)
                task.wait()        -- 1 frame (giống Xeno)
                task.wait(0.5)     -- settle
            end

            -- Tìm mob nếu chưa có lockedPos
            if not lockedPos then
                local npc = findClosestMob(choosenpc)
                if npc then
                    local mobPos = getMobPos(npc)
                    if mobPos then
                        lockedPos = CFrame.lookAt(
                            mobPos + Vector3.new(0, FARM_HEIGHT, 0),
                            mobPos
                        )
                        print("[Kaitun 2] 1-Spot locked tại: " .. tostring(mobPos))
                    end
                end
            end

            -- ═══ XENO-STYLE CFrame LOCK LOOP ═══
            -- Set CFrame mỗi 0.1s TRONG CÙNG THREAD với teleport
            -- → Không có gap → server không kéo về
            if lockedPos then
                farmStatus = "Farming " .. choosenpc .. " (locked)"
                local lastCheck = tick()
                local lostMobCount = 0

                while task.wait(0.1) do
                    local root = getRoot()
                    if not root then break end

                    root.Anchored = false

                    -- Triệt tiêu gia tốc vật lý cũ (Chống văng do quán tính)
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero

                    -- Bật lực neo giữ TRƯỚC KHI set CFrame (Lớp bọc thép chống rơi)
                    applyXenoStabilizers(root, lockedPos)

                    -- Teleport cái rụp!
                    root.CFrame = lockedPos

                    -- Mỗi 3s: kiểm tra quest, level, equip, mob
                    if tick() - lastCheck > 3 then
                        lastCheck = tick()

                        -- Auto equip weapon
                        pcall(function()
                            if Player.Character and not Player.Character:FindFirstChildWhichIsA("Tool") then
                                for _, v in pairs(Player.Backpack:GetChildren()) do
                                    if v:IsA("Tool") then Player.Character.Humanoid:EquipTool(v) break end
                                end
                            end
                        end)

                        -- Check level up → break nếu mob đổi
                        local _, _, newChoose = getTargetQuest()
                        if newChoose ~= currentChoosenpc then
                            print("[Kaitun 2] Level up trong lock loop!")
                            lockedPos = nil
                            cleanupXenoStabilizers()
                            break
                        end

                        -- Re-accept quest (cooldown 5s)
                        if tick() - lastAcceptTime > 5 then
                            pcall(function() questAcceptR:FireServer(currentTargetNPC) end)
                            lastAcceptTime = tick()
                        end

                        -- Check mob còn tồn tại không
                        local mobExists = false
                        for _, v in pairs(workspace.NPCs:GetChildren()) do
                            if string.find(v.Name, currentChoosenpc) and getMobPos(v) then
                                mobExists = true
                                break
                            end
                        end

                        if not mobExists then
                            lostMobCount = lostMobCount + 1
                            farmStatus = "Waiting respawn... (" .. lostMobCount .. "/" .. MAX_MISS .. ")"
                            if lostMobCount >= MAX_MISS then
                                print("[Kaitun 2] Mob " .. currentChoosenpc .. " biến mất quá lâu. Reset.")
                                homeIsland = nil
                                homePortal = nil
                                lockedPos = nil
                                cleanupXenoStabilizers()
                                break
                            end
                            -- Mob tạm biến mất → giữ lockedPos, chờ respawn tại chỗ
                        else
                            lostMobCount = 0
                            farmStatus = "Farming " .. currentChoosenpc .. " (locked)"
                        end
                    end
                end
                -- Thoát lock loop → dọn stabilizers
                cleanupXenoStabilizers()
            else
                -- Không tìm thấy mob → chờ spawn
                farmStatus = "Waiting for " .. choosenpc .. " to spawn..."
                missCount = missCount + 1
                if missCount >= MAX_MISS then
                    homeIsland = nil
                    homePortal = nil
                    lockedPos = nil
                    missCount = 0
                    farmStatus = "Rescanning islands..."
                end
                task.wait(2)
            end
            continue
        end

        -- ═══ Chưa biết homeIsland → lookup mobConfig trước ═══
        local config = mobConfig[choosenpc]
        if config then
            -- Direct lookup: biết ngay đảo → nhảy thẳng tới
            homeIsland = config.zoneId
            homePortal = config.island
            farmStatus = "Teleporting to " .. config.island .. "..."
            print("[Kaitun 2] mobConfig → " .. choosenpc .. " ở " .. config.island .. ". Nhảy thẳng!")
            pcall(function() teleportRemote:FireServer(config.island) end)
            task.wait()
            task.wait(1)
        else
            -- Fallback: mob không có trong mobConfig → scan từng đảo
            farmStatus = "Scanning islands for " .. choosenpc .. "..."
            print("[Kaitun 2] Mob " .. choosenpc .. " không có trong mobConfig. Quét đảo...")

            if currentZoneId and currentZoneData and currentZoneData.Size then
                for _, v in pairs(workspace.NPCs:GetChildren()) do
                    local vPos = getMobPos(v)
                    if string.find(v.Name, choosenpc) and vPos then
                        if checkmap.IsInZone(vPos, currentZoneData) then
                            homeIsland = currentZoneId
                            print("[Kaitun 2] Tìm thấy " .. choosenpc .. " tại " .. currentZoneId .. "!")
                            break
                        end
                    end
                end
            end

            if not homeIsland then
                for _, islandId in ipairs(sortedIslands) do
                    if islandId == currentZoneId then continue end

                    local zoneData = checkmap.Zones[islandId]
                    if not zoneData or not zoneData.Size then continue end

                    farmStatus = "Scanning: " .. (zoneData.DisplayName or islandId)
                    local portalArg = string.gsub(islandId, "Island", ""):gsub(" ", "")
                    pcall(function() teleportRemote:FireServer(portalArg) end)
                    task.wait()
                    task.wait(2)

                    for _, v in pairs(workspace.NPCs:GetChildren()) do
                        local vPos = getMobPos(v)
                        if string.find(v.Name, choosenpc) and vPos then
                            if checkmap.IsInZone(vPos, zoneData) then
                                homeIsland = islandId
                                homePortal = portalArg
                                print("[Kaitun 2] Tìm thấy " .. choosenpc .. " tại " .. islandId .. "!")
                                break
                            end
                        end
                    end

                    if homeIsland then break end
                    task.wait(0.5)
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════
-- KILL AURA LOOP (thread riêng)
-- Spawn thread riêng mỗi mob → fire đồng thời tất cả trong range
-- ═══════════════════════════════════════════════════════════
task.spawn(function()
    while task.wait(0.1) do
        local root = getRoot()
        if not root then continue end

        local npcsFolder = workspace:FindFirstChild("NPCs")
        if not npcsFolder then continue end

        for _, mob in pairs(npcsFolder:GetChildren()) do
            local hum = mob:FindFirstChildOfClass("Humanoid")
            if not (hum and hum.Health > 0) then continue end
            local pos = getMobPos(mob)
            if pos and (root.Position - pos).Magnitude <= KILL_AURA_RANGE then
                task.spawn(function()
                    pcall(function() combatRemote:FireServer(pos) end)
                end)
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════
-- AUTO SKILL LOOP (Bao gồm Combat thường + Light Fruit Z, X, C)
-- ═══════════════════════════════════════════════════════════
task.spawn(function()
    local abilityRemote = ReplicatedStorage:WaitForChild("AbilitySystem"):WaitForChild("Remotes"):WaitForChild("RequestAbility")
    local fruitPowerRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("FruitPowerRemote")
    
    -- Chỉ xài Z, X, C (Tuyệt đối không xài V theo dặn dò)
    local lightKeys = {Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C} 

    while task.wait(0.3) do
        if _G.IsRollingFruit then continue end
        local npcsFolder = workspace:FindFirstChild("NPCs")
        local root = getRoot()
        local mobPos = nil

        -- Tìm mục tiêu gần nhất để định vị kỹ năng (Aim)
        if npcsFolder and root then
            local closestDist = math.huge
            for _, npc in pairs(npcsFolder:GetChildren()) do
                local hum = npc:FindFirstChildOfClass("Humanoid")
                local pos = getMobPos(npc)
                if hum and hum.Health > 0 and pos then
                    local dist = (root.Position - pos).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        mobPos = pos
                    end
                end
            end
        end

        -- 1. Xả 5 skill cơ bản (Melee/Sword)
        for skillId = 1, 5 do
            pcall(function()
                if mobPos then
                    abilityRemote:FireServer(skillId, mobPos)
                else
                    abilityRemote:FireServer(skillId)
                end
            end)
        end

        -- 2. Xả skill trái Light (Nếu đã sở hữu)
        if _G.HasLightFruit then
            for _, key in ipairs(lightKeys) do
                pcall(function()
                    local args = {
                        "UseAbility",
                        {
                            FruitPower = "Light",
                            KeyCode = key
                        }
                    }
                    fruitPowerRemote:FireServer(unpack(args))
                end)
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════
-- AUTO STATS LOOP (+10 Melee & +10 Defense liên tục)
-- ═══════════════════════════════════════════════════════════
task.spawn(function()
    while task.wait(0.5) do
        pcall(function() allocateRemote:FireServer("Melee", 10) end)
        pcall(function() allocateRemote:FireServer("Defense", 10) end)
    end
end)

-- ═══════════════════════════════════════════════════════════
-- SAFETY
-- ═══════════════════════════════════════════════════════════
if _G.KaitunSailor2Loaded then
    warn("[Kaitun 2] Script đã chạy rồi!")
else
    _G.KaitunSailor2Loaded = true
end

print("[Kaitun Sailor 2] Xeno-style Auto Farm started! ✅")
