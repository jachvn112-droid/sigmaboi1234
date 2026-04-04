-- ==============================================================================
-- 👑 SCRIPT AUTOFARM SUKUNA V2 (SAVE DATA + ANTI AFK + AUTO REJOIN VIP)
-- ==============================================================================

if getgenv().TestSukunaFarm then
    warn("⚠️ Script đang chạy rồi! Vui lòng tắt/khởi động lại game nếu muốn chạy lại.")
    return
end
getgenv().TestSukunaFarm = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")
local Player = Players.LocalPlayer

-- ═══════════════════════════════════════
-- 🛡️ ANTI AFK & AUTO REJOIN (HỖ TRỢ VIP)
-- ═══════════════════════════════════════
-- 1. Chống Kick 20 phút
Player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- 2. Tự động Rejoin đúng Server (VIP/Public) khi bị văng
local currentPlaceId = game.PlaceId
local currentJobId = game.JobId

pcall(function()
    local promptOverlay = CoreGui:FindFirstChild("RobloxPromptGui") and CoreGui.RobloxPromptGui:FindFirstChild("promptOverlay")
    if promptOverlay then
        promptOverlay.ChildAdded:Connect(function(child)
            if child.Name == "ErrorPrompt" then
                print("⚠️ [Auto-Rejoin] Phát hiện mất kết nối! Đang thử kết nối lại đúng Server hiện tại...")
                task.wait(5) -- Chờ 5s cho ổn định mạng rồi rejoin
                TeleportService:TeleportToPlaceInstance(currentPlaceId, currentJobId, Player)
            end
        end)
    end
end)

-- Phương án dự phòng (phòng khi Executor không cho đụng vào CoreGui)
pcall(function()
    game:GetService("GuiService").ErrorMessageChanged:Connect(function()
        task.wait(5)
        TeleportService:TeleportToPlaceInstance(currentPlaceId, currentJobId, Player)
    end)
end)

-- ═══════════════════════════════════════
-- MODULES & REMOTES
-- ═══════════════════════════════════════
local TravelConfig = require(ReplicatedStorage:WaitForChild("TravelConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CombatRemotes = ReplicatedStorage:WaitForChild("CombatSystem"):WaitForChild("Remotes")
local AbilityRemotes = ReplicatedStorage:WaitForChild("AbilitySystem"):WaitForChild("Remotes")
local GlobalRemotes = ReplicatedStorage:WaitForChild("RemoteEvents")

local teleportRemote = Remotes:WaitForChild("TeleportToPortal")
local reqInventory = Remotes:WaitForChild("RequestInventory")
local updateInventory = Remotes:WaitForChild("UpdateInventory")
local getTitlesData = Remotes:WaitForChild("GetTitlesData")
local spawnBossRemote = Remotes:WaitForChild("RequestSpawnStrongestBoss")
local combatHit = CombatRemotes:WaitForChild("RequestHit")
local abilityReq = AbilityRemotes:WaitForChild("RequestAbility")
local fruitPowerReq = GlobalRemotes:WaitForChild("FruitPowerRemote")

-- ═══════════════════════════════════════
-- CONSTANTS & VARIABLES
-- ═══════════════════════════════════════
local NATURAL_BOSS_NAME = "SukunaBoss" 
local SPAWNED_BOSS_NAME = "StrongestinHistoryBoss" 
local CURSE_MOB_NAME = "Curse"
local FARM_HEIGHT = 15
local NPC_CFRAME = CFrame.new(756.397949, 89.1463165, -1952.93628, -0.779544473, 0.100432858, -0.618242443, -0.0122024417, 0.984438181, 0.175307095, 0.626228034, 0.144203752, -0.766187787)

local REQ_RING, REQ_SOUL, REQ_FLESH, REQ_FINGER = 7, 3, 1, 20
local REQ_TITLE = "Disgraced One"

_G.InventoryData = {}
_G.HasTitle = false
_G.BossRushMode = false
local CurrentTarget = nil 
local lastDebugPrint = 0
local SAVE_FILE_NAME = "SukunaFarmSave.txt"

print("\n==================================================")
print("👑 ĐÃ KHỞI ĐỘNG AUTOFARM SUKUNA V2 (SAVE DATA + REJOIN) 👑")
print("==================================================\n")

-- ═══════════════════════════════════════
-- HỆ THỐNG LƯU TRỮ (SAVE/LOAD SYSTEM)
-- ═══════════════════════════════════════
local function saveState(state)
    if type(writefile) == "function" then
        pcall(function() writefile(SAVE_FILE_NAME, state) end)
    end
end

if type(readfile) == "function" and type(isfile) == "function" then
    if pcall(function() return isfile(SAVE_FILE_NAME) end) and isfile(SAVE_FILE_NAME) then
        local savedState = pcall(function() return readfile(SAVE_FILE_NAME) end) and readfile(SAVE_FILE_NAME) or "FARMING"
        if savedState == "RUSHING" then
            _G.BossRushMode = true
            print("🔄 [KHÔI PHỤC] Phát hiện tiến trình cũ bị Crash! Khôi phục chế độ BOSS RUSH.")
        end
    end
end

-- ═══════════════════════════════════════
-- HELPERS CƠ BẢN
-- ═══════════════════════════════════════
local function getRoot() return Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") end

local function applyXenoStabilizers(root, goalCF)
    local bv = root:FindFirstChild("KaitunStabBV")
    if not bv then
        bv = Instance.new("BodyVelocity", root)
        bv.Name = "KaitunStabBV"
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.P = 1250
    end
    bv.Velocity = Vector3.zero

    local bg = root:FindFirstChild("KaitunStabBG")
    if not bg then
        bg = Instance.new("BodyGyro", root)
        bg.Name = "KaitunStabBG"
        bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bg.P = 3000
        bg.D = 500
    end
    bg.CFrame = goalCF
end

local function cleanupXenoStabilizers()
    pcall(function()
        local root = getRoot()
        if not root then return end
        if root:FindFirstChild("KaitunStabBV") then root.KaitunStabBV:Destroy() end
        if root:FindFirstChild("KaitunStabBG") then root.KaitunStabBG:Destroy() end
    end)
end

local function getItemCount(itemName) return _G.InventoryData[itemName] or 0 end

local function findSpecificBoss(bossName)
    local npcsFolder = Workspace:FindFirstChild("NPCs") or Workspace
    for _, npc in pairs(npcsFolder:GetChildren()) do
        if string.find(npc.Name, bossName) or npc.Name == "Cursed King" then
            local hum = npc:FindFirstChildWhichIsA("Humanoid")
            if hum and hum.Health > 0 then return npc end
        end
    end
    return nil
end

local function findCurseMob()
    local npcsFolder = Workspace:FindFirstChild("NPCs")
    if not npcsFolder then return nil end
    local root = getRoot()
    if not root then return nil end

    local closest, closestDist = nil, math.huge
    for _, npc in pairs(npcsFolder:GetChildren()) do
        if string.find(npc.Name, CURSE_MOB_NAME) then
            local hum = npc:FindFirstChildWhichIsA("Humanoid")
            local pos = pcall(function() return npc:GetPivot().Position end) and npc:GetPivot().Position or nil
            if hum and hum.Health > 0 and pos then
                local dist = (root.Position - pos).Magnitude
                if dist < closestDist then closestDist = dist; closest = npc end
            end
        end
    end
    return closest
end

local function smartTeleport(targetPortalName, expectedZoneId)
    local root = getRoot()
    if not root then return false end
    local currentZoneId, _ = TravelConfig.GetZoneAt(root.Position)
    if currentZoneId ~= expectedZoneId then
        print(string.format("✈️ Đang nhảy đảo từ [%s] -> cổng [%s]", tostring(currentZoneId), tostring(targetPortalName)))
        pcall(function() teleportRemote:FireServer(targetPortalName) end)
        task.wait(4.5) 
        return true 
    end
    return false 
end

-- ═══════════════════════════════════════
-- THREAD 1: FORENSIC INVENTORY & TITLE
-- ═══════════════════════════════════════
task.spawn(function()
    local inventoryRef = nil 
    while task.wait(3) do
        if not getgenv().TestSukunaFarm then break end
        
        pcall(function() reqInventory:FireServer() end)
        task.wait(1.5) 
        
        if not inventoryRef and type(getconnections) == "function" then
            pcall(function()
                for _, conn in pairs(getconnections(updateInventory.OnClientEvent)) do
                    if conn.Function then
                        for _, v in pairs(getupvalues(conn.Function)) do
                            if type(v) == "table" and v["Melee"] ~= nil and v["Sword"] ~= nil then
                                inventoryRef = v
                                print("🔓 Đã khóa mục tiêu bảng Inventory gốc!")
                                break
                            end
                        end
                    end
                    if inventoryRef then break end
                end
            end)
        end

        if inventoryRef then
            local tempInv = {}
            for _, items in pairs(inventoryRef) do
                if type(items) == "table" then
                    for _, item in pairs(items) do
                        if type(item) == "table" and item.name then
                            tempInv[item.name] = (tempInv[item.name] or 0) + (item.quantity or 1)
                        end
                    end
                end
            end
            _G.InventoryData = tempInv
        end

        pcall(function()
            local tData = getTitlesData:InvokeServer()
            if type(tData) == "table" then
                _G.HasTitle = false
                for _, t in pairs(tData) do
                    if t == REQ_TITLE or (type(t) == "table" and t.name == REQ_TITLE) then _G.HasTitle = true break end
                end
            end
        end)
        
        local currentKeys = getItemCount("Malevolent Key")
        
        if tick() - lastDebugPrint > 15 then
            if _G.BossRushMode then
                print(string.format("⚔️ [Boss Rush] Đang trong chuỗi xả đạn! Còn lại: %d Keys", currentKeys))
            else
                print(string.format("📡 [Cày Key] Đang gom: %d Malevolent Keys | Mốc xả: 20", currentKeys))
            end
            lastDebugPrint = tick()
        end

        if currentKeys >= 20 and not _G.BossRushMode then
            print("🔔 ĐÃ GOM ĐỦ 20 MALEVOLENT KEYS! CHUYỂN SANG CHẾ ĐỘ BOSS RUSH!")
            _G.BossRushMode = true
            saveState("RUSHING")
        end
        
        if currentKeys <= 0 and _G.BossRushMode then
            print("📉 Nhận diện Key = 0. Tắt chế độ xả, chuyển về cày Curse.")
            _G.BossRushMode = false
            saveState("FARMING")
        end
    end
end)

-- ═══════════════════════════════════════
-- THREAD 2: QUẢN LÝ TRẠNG THÁI & DI CHUYỂN
-- ═══════════════════════════════════════
task.spawn(function()
    while task.wait(0.1) do
        if not getgenv().TestSukunaFarm then break end
        
        local root = getRoot()
        if not root then continue end
        
        for _, part in pairs(Player.Character:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end

        local keys = getItemCount("Malevolent Key")
        local rings = getItemCount("Vessel Ring")
        local souls = getItemCount("Malevolent Soul")
        local flesh = getItemCount("Cursed Flesh")
        local fingers = getItemCount("Awakened Cursed Finger")

        -- ⚡ ƯU TIÊN 1: MUA CLASS
        if rings >= REQ_RING and souls >= REQ_SOUL and flesh >= REQ_FLESH and fingers >= REQ_FINGER and _G.HasTitle then
            print("🎓 TỐT NGHIỆP! Đã đủ nguyên liệu, tiến hành đi mua class...")
            CurrentTarget = nil
            local targetZoneId, _ = TravelConfig.GetZoneAt(NPC_CFRAME.Position)
            local portalName = targetZoneId and string.gsub(targetZoneId, "Island", ""):gsub(" ", "") or "Shinjuku"
            
            if smartTeleport(portalName, targetZoneId) then continue end
            
            root = getRoot()
            if not root then continue end
            applyXenoStabilizers(root, NPC_CFRAME)
            root.CFrame = NPC_CFRAME
            task.wait(1)

            local npc = Workspace:FindFirstChild("ServiceNPCs") and Workspace.ServiceNPCs:FindFirstChild("StrongestinHistoryBuyerNPC")
            if npc then
                local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt and type(fireproximityprompt) == "function" then
                    prompt.RequiresLineOfSight = false
                    prompt.HoldDuration = 0
                    fireproximityprompt(prompt)
                    print("✅ ĐÃ GỬI LỆNH MUA CLASS THÀNH CÔNG!")
                    task.wait(2)
                    getgenv().TestSukunaFarm = false
                    cleanupXenoStabilizers()
                    return
                end
            end
            continue
        end

        -- ⚡ ƯU TIÊN 2: BOSS RUSH (Ở Shinjuku)
        if _G.BossRushMode and keys > 0 then
            if smartTeleport("Shinjuku", "ShinjukuIsland") then continue end 
            
            local spawnedBoss = findSpecificBoss(SPAWNED_BOSS_NAME)
            
            if spawnedBoss then
                local mobPos = spawnedBoss:GetPivot().Position
                CurrentTarget = spawnedBoss
                local targetCF = CFrame.lookAt(mobPos + Vector3.new(0, FARM_HEIGHT, 0), mobPos)
                applyXenoStabilizers(root, targetCF)
                if (root.Position - targetCF.Position).Magnitude > 15 then root.CFrame = targetCF else root.CFrame = CFrame.lookAt(root.Position, mobPos) end
            else
                CurrentTarget = nil
                applyXenoStabilizers(root, root.CFrame)
                print("⚔️ Đang gọi Boss (Còn " .. keys .. " Key)...")
                pcall(function() spawnBossRemote:FireServer("StrongestHistory", "Normal") end)
                task.wait(6) 
            end
            continue
        end

        -- ⚡ ƯU TIÊN 3: SĂN BOSS TỰ NHIÊN (Ở Shibuya)
        local naturalBoss = findSpecificBoss(NATURAL_BOSS_NAME)
        if naturalBoss then
            print("🌟 Phát hiện Sukuna tự nhiên ở Shibuya! Bay qua húp đồ...")
            if smartTeleport("Shibuya", "ShibuyaStation") then continue end
            
            naturalBoss = findSpecificBoss(NATURAL_BOSS_NAME)
            if naturalBoss then
                local mobPos = naturalBoss:GetPivot().Position
                CurrentTarget = naturalBoss
                local targetCF = CFrame.lookAt(mobPos + Vector3.new(0, FARM_HEIGHT, 0), mobPos)
                applyXenoStabilizers(root, targetCF)
                if (root.Position - targetCF.Position).Magnitude > 15 then root.CFrame = targetCF else root.CFrame = CFrame.lookAt(root.Position, mobPos) end
            end
            continue
        end

        -- ⚡ ƯU TIÊN 4: FARM KEY BẰNG BÃI QUÁI CURSE (Ở Shinjuku)
        CurrentTarget = nil
        if smartTeleport("Shinjuku", "ShinjukuIsland") then continue end

        local curseMob = findCurseMob()
        if curseMob then
            local mobPos = curseMob:GetPivot().Position
            CurrentTarget = curseMob
            local targetCF = CFrame.lookAt(mobPos + Vector3.new(0, FARM_HEIGHT, 0), mobPos)
            applyXenoStabilizers(root, targetCF)
            if (root.Position - targetCF.Position).Magnitude > 15 then root.CFrame = targetCF else root.CFrame = CFrame.lookAt(root.Position, mobPos) end
        else
            applyXenoStabilizers(root, root.CFrame)
        end
    end
end)

-- ═══════════════════════════════════════
-- THREAD 3: COMBAT (KILLAURA & SKILLS)
-- ═══════════════════════════════════════
task.spawn(function()
    local lightKeys = {Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C}
    while task.wait(0.2) do
        if not getgenv().TestSukunaFarm then break end
        
        pcall(function()
            if Player.Character and not Player.Character:FindFirstChildWhichIsA("Tool") then
                local bp = Player:FindFirstChild("Backpack")
                if bp then
                    local lightTool = bp:FindFirstChild("Light Fruit") or bp:FindFirstChild("Light")
                    if lightTool then Player.Character.Humanoid:EquipTool(lightTool)
                    else
                        for _, v in pairs(bp:GetChildren()) do
                            if v:IsA("Tool") then Player.Character.Humanoid:EquipTool(v) break end
                        end
                    end
                end
            end
        end)

        if CurrentTarget and CurrentTarget.Parent then
            local mobPos = pcall(function() return CurrentTarget:GetPivot().Position end) and CurrentTarget:GetPivot().Position or nil
            if mobPos then
                pcall(function() combatHit:FireServer(mobPos) end)
                for i = 1, 5 do pcall(function() abilityReq:FireServer(i, mobPos) end) end
                for _, key in ipairs(lightKeys) do pcall(function() fruitPowerReq:FireServer("UseAbility", {FruitPower = "Light", KeyCode = key}) end) end
            end
        end
    end
end)
