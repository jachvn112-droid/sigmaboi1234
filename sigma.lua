-- ==============================================================================
-- 👑 SCRIPT AUTOFARM SUKUNA V2 (V13 - AUTO EQUIP CLASS & STABLE TWEEN)
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
local TweenService = game:GetService("TweenService")
local Player = Players.LocalPlayer

-- ═══════════════════════════════════════
-- 🛡️ BYPASS ANTI-CHEAT (DashRemote)
-- ═══════════════════════════════════════
local RunService = game:GetService("RunService")
local dashRemote = ReplicatedStorage:FindFirstChild("RemoteEvents") and ReplicatedStorage.RemoteEvents:FindFirstChild("DashRemote")
if dashRemote then 
    print("[BYPASS] Đã bật khiên chống Rubber-Banding!")
    RunService.Heartbeat:Connect(function()
        task.spawn(function()
            pcall(function() dashRemote:FireServer(Vector3.new(0, 0, 0), 0, false) end)
        end)
    end)
end
task.wait(1)

-- ═══════════════════════════════════════
-- 🛡️ ANTI AFK & AUTO REJOIN
-- ═══════════════════════════════════════
Player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

local currentPlaceId = game.PlaceId
local currentJobId = game.JobId

pcall(function()
    local promptOverlay = CoreGui:FindFirstChild("RobloxPromptGui") and CoreGui.RobloxPromptGui:FindFirstChild("promptOverlay")
    if promptOverlay then
        promptOverlay.ChildAdded:Connect(function(child)
            if child.Name == "ErrorPrompt" then
                print("⚠️ [Auto-Rejoin] Phát hiện mất kết nối! Đang thử kết nối lại...")
                task.wait(5)
                TeleportService:TeleportToPlaceInstance(currentPlaceId, currentJobId, Player)
            end
        end)
    end
end)

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
local useItemRemote = Remotes:WaitForChild("UseItem")
local equipWeaponRemote = Remotes:WaitForChild("EquipWeapon") -- Lệnh Equip Class

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
local TARGET_CLASS_NAME = "Strongest In History"

_G.InventoryData = {}
_G.HasTitle = false
_G.BossRushMode = false
_G.AutoFingersEaten = nil 
_G.AutoCheckAttempts = 0
_G.HasStrongestClass = false -- Biến kiểm tra xem đã có Class chưa

local CurrentTarget = nil 
local lastDebugPrint = 0
local SAVE_FILE_NAME = "SukunaFarmSave.txt"

print("\n==================================================")
print("👑 AUTOFARM SUKUNA V2 (V13 - FULL AUTO EQUIP) 👑")
print("==================================================\n")

-- ═══════════════════════════════════════
-- HỆ THỐNG LƯU TRỮ (SAVE/LOAD SYSTEM)
-- ═══════════════════════════════════════
local function saveState(state)
    if type(writefile) == "function" then pcall(function() writefile(SAVE_FILE_NAME, state) end) end
end

if type(readfile) == "function" and type(isfile) == "function" then
    if pcall(function() return isfile(SAVE_FILE_NAME) end) and isfile(SAVE_FILE_NAME) then
        local savedState = pcall(function() return readfile(SAVE_FILE_NAME) end) and readfile(SAVE_FILE_NAME) or "FARMING"
        if savedState == "RUSHING" then
            _G.BossRushMode = true
            print("🔄 [KHÔI PHỤC] Khôi phục chế độ BOSS RUSH.")
        end
    end
end

-- ═══════════════════════════════════════
-- HELPERS CƠ BẢN
-- ═══════════════════════════════════════
local function getRoot() return Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") end

local function applyXenoStabilizers(root, goalCF)
    local bv = root:FindFirstChild("KaitunStabBV")
    if not bv then bv = Instance.new("BodyVelocity", root); bv.Name = "KaitunStabBV"; bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge); bv.P = 1250 end
    bv.Velocity = Vector3.zero
    local bg = root:FindFirstChild("KaitunStabBG")
    if not bg then bg = Instance.new("BodyGyro", root); bg.Name = "KaitunStabBG"; bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge); bg.P = 3000; bg.D = 500 end
    bg.CFrame = goalCF
end

local function cleanupXenoStabilizers()
    pcall(function() local root = getRoot(); if root and root:FindFirstChild("KaitunStabBV") then root.KaitunStabBV:Destroy() end; if root and root:FindFirstChild("KaitunStabBG") then root.KaitunStabBG:Destroy() end end)
end

local function getItemCount(itemName) return _G.InventoryData[itemName] or 0 end

local function findSpecificBoss(bossName)
    local npcsFolder = Workspace:FindFirstChild("NPCs") or Workspace
    for _, npc in pairs(npcsFolder:GetChildren()) do
        if string.find(npc.Name, bossName) or npc.Name == "Cursed King" then
            local hum = npc:FindFirstChildWhichIsA("Humanoid")
            if hum and hum.Health > 0 then return npc end
        end
    end return nil
end

local function findCurseMob()
    local root = getRoot() if not root then return nil end
    local closest, closestDist = nil, math.huge
    for _, npc in pairs((Workspace:FindFirstChild("NPCs") or Workspace):GetChildren()) do
        if string.find(npc.Name, CURSE_MOB_NAME) then
            local hum = npc:FindFirstChildWhichIsA("Humanoid")
            local pos = pcall(function() return npc:GetPivot().Position end) and npc:GetPivot().Position or nil
            if hum and hum.Health > 0 and pos then
                local dist = (root.Position - pos).Magnitude
                if dist < closestDist then closestDist = dist; closest = npc end
            end
        end
    end return closest
end

local function smartTeleport(targetPortalName, expectedZoneId)
    local root = getRoot() if not root then return false end
    local currentZoneId, _ = TravelConfig.GetZoneAt(root.Position)
    if currentZoneId ~= expectedZoneId then
        print(string.format("✈️ Đang nhảy đảo từ [%s] -> cổng [%s]", tostring(currentZoneId), tostring(targetPortalName)))
        pcall(function() teleportRemote:FireServer(targetPortalName) end)
        task.wait(4.5) return true 
    end return false 
end

-- ═══════════════════════════════════════
-- THREAD 1: FORENSIC INVENTORY (CẬP NHẬT KIỂM TRA CLASS)
-- ═══════════════════════════════════════
task.spawn(function()
    local inventoryRef = nil 
    while task.wait(3) do
        if not getgenv().TestSukunaFarm then break end
        
        pcall(function() reqInventory:FireServer() end)
        task.wait(1.5) 
        
        -- Khóa mục tiêu vào bảng Inventory
        if not inventoryRef and type(getconnections) == "function" then
            pcall(function()
                for _, conn in pairs(getconnections(updateInventory.OnClientEvent)) do
                    if conn.Function then
                        for _, v in pairs(getupvalues(conn.Function)) do
                            if type(v) == "table" and v["Melee"] ~= nil and v["Sword"] ~= nil then
                                inventoryRef = v
                                print("🔓 Đã khóa mục tiêu bảng Inventory gốc! Đảm bảo không bị tụt Key.")
                                break
                            end
                        end
                    end
                    if inventoryRef then break end
                end
            end)
        end

        -- Lọc dữ liệu chống x2 và KIỂM TRA SỞ HỮU CLASS
        if inventoryRef then
            local tempInv = {}
            _G.HasStrongestClass = false -- Reset để check lại
            
            -- Check tab Item/Material
            for _, items in pairs(inventoryRef) do
                if type(items) == "table" then
                    for _, item in pairs(items) do
                        if type(item) == "table" and item.name then
                            local currentQty = tempInv[item.name] or 0
                            tempInv[item.name] = math.max(currentQty, item.quantity or 1)
                        end
                    end
                end
            end
            
            -- Check tab Melee xem có Class chưa
            if inventoryRef["Melee"] then
                for _, item in pairs(inventoryRef["Melee"]) do
                    if type(item) == "table" and item.name and string.lower(item.name) == string.lower(TARGET_CLASS_NAME) then
                        _G.HasStrongestClass = true
                        break
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
            if _G.BossRushMode then print(string.format("⚔️ [Boss Rush] Đang xả đạn! Còn lại: %d Keys", currentKeys))
            else print(string.format("📡 [Cày Key] Đang gom: %d Keys | Mốc xả: 20", currentKeys)) end
            lastDebugPrint = tick()
        end

        if currentKeys >= 20 and not _G.BossRushMode then
            print("🔔 ĐÃ GOM ĐỦ 20 KEYS! BẬT CHẾ ĐỘ BOSS RUSH!")
            _G.BossRushMode = true; saveState("RUSHING")
        end
        if currentKeys <= 0 and _G.BossRushMode then
            print("📉 Hết Key. Tắt chế độ xả, chuyển về cày Curse.")
            _G.BossRushMode = false; saveState("FARMING")
        end
    end
end)

-- ═══════════════════════════════════════
-- THREAD 2: QUẢN LÝ TRẠNG THÁI & DI CHUYỂN
-- ═══════════════════════════════════════
task.spawn(function()
    while task.wait(0.1) do
        if not getgenv().TestSukunaFarm then break end
        
        local root = getRoot() if not root then continue end
        for _, part in pairs(Player.Character:GetChildren()) do if part:IsA("BasePart") then part.CanCollide = false end end

        -- ⚡ ƯU TIÊN TỐI THƯỢNG: ĐÃ CÓ CLASS THÌ TỰ TRANG BỊ VÀ TẮT SCRIPT
        if _G.HasStrongestClass then
            print("🎉 PHÁT HIỆN ĐÃ SỞ HỮU [" .. TARGET_CLASS_NAME .. "]!")
            CurrentTarget = nil
            applyXenoStabilizers(root, root.CFrame)
            
            print("⚔️ Đang tự động trang bị Class...")
            local args = {"Equip", TARGET_CLASS_NAME}
            pcall(function() equipWeaponRemote:FireServer(unpack(args)) end)
            
            task.wait(1.5)
            print("✅ Đã trang bị thành công! Hoàn thành sứ mệnh, tự động tắt Script.")
            
            getgenv().TestSukunaFarm = false
            cleanupXenoStabilizers()
            return
        end

        -- ⚡ ƯU TIÊN 0: KHỞI ĐỘNG - TWEEN ĐẾN NPC ĐỂ CHECK UI
        if _G.AutoFingersEaten == nil then
            CurrentTarget = nil
            if smartTeleport("Shinjuku", "ShinjukuIsland") then continue end
            
            local root = getRoot()
            if not root then continue end
            
            local dist = (root.Position - NPC_CFRAME.Position).Magnitude
            
            -- Nếu đứng xa NPC quá 15m -> Nhờ Bypass mà CFrame thẳng mặt
            if dist > 15 then
                print("🚶 Đang CFrame thẳng tới NPC...")
                root.CFrame = NPC_CFRAME
                root.AssemblyLinearVelocity = Vector3.new(0, 0.01, 0)
                root.AssemblyAngularVelocity = Vector3.zero
                task.wait(0.5) -- Nghỉ một nhịp cho Server cập nhật vị trí mới
            end
            
            -- Sau khi lướt tới nơi (hoặc đã đứng sát sẵn) -> Đọc UI
            if (root.Position - NPC_CFRAME.Position).Magnitude <= 15 then
                local npc = Workspace:FindFirstChild("ServiceNPCs") and Workspace.ServiceNPCs:FindFirstChild("StrongestinHistoryBuyerNPC")
                if npc then
                    _G.AutoCheckAttempts = _G.AutoCheckAttempts + 1
                    local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if prompt then
                        print("🤖 [Auto-Scanner] Đã sát NPC an toàn! Đang ép khai số ngón tay...")
                        local oldLoS = prompt.RequiresLineOfSight
                        prompt.RequiresLineOfSight = false
                        
                        fireproximityprompt(prompt)
                        task.wait(1.5)
                        
                        prompt.RequiresLineOfSight = oldLoS
                        
                        local foundFingers = false
                        for _, guiObj in pairs(Player.PlayerGui:GetDescendants()) do
                            if guiObj:IsA("TextLabel") or guiObj:IsA("TextButton") then
                                local text = guiObj.Text
                                if text and string.find(string.lower(text), "finger") and string.find(string.lower(text), "eaten") then
                                    local num = string.match(text, "(%d+)/20")
                                    if num then
                                        _G.AutoFingersEaten = tonumber(num)
                                        print("✅ THÀNH CÔNG: Đã ghi nhận sếp nuốt " .. num .. " ngón!")
                                        foundFingers = true
                                        break
                                    end
                                end
                            end
                        end
                        
                        if not foundFingers and _G.AutoCheckAttempts >= 3 then
                            print("⚠️ Không đọc được bảng UI. Mặc định gán = 0 ngón (Hoặc sếp đã tốt nghiệp).")
                            _G.AutoFingersEaten = 0
                        end
                    end
                end
            end
            continue
        end

        local keys = getItemCount("Malevolent Key")
        local rings = getItemCount("Vessel Ring")
        local souls = getItemCount("Malevolent Soul")
        local flesh = getItemCount("Cursed Flesh")
        local fingersInBag = getItemCount("Awakened Cursed Finger")
        local eaten = _G.AutoFingersEaten or 0
        local fingersNeeded = REQ_FINGER - eaten

        -- ⚡ ƯU TIÊN 1: TỐT NGHIỆP - NUỐT NGÓN TAY VÀ MUA CLASS
        if rings >= REQ_RING and souls >= REQ_SOUL and flesh >= REQ_FLESH and fingersInBag >= fingersNeeded and _G.HasTitle then
            print("🎓 TỐT NGHIỆP! Đã gom đủ 100% nguyên liệu. Bắt đầu thủ tục...")
            CurrentTarget = nil
            local targetZoneId, _ = TravelConfig.GetZoneAt(NPC_CFRAME.Position)
            local portalName = targetZoneId and string.gsub(targetZoneId, "Island", ""):gsub(" ", "") or "Shinjuku"
            
            if smartTeleport(portalName, targetZoneId) then continue end
            
            local root = getRoot()
            if not root then continue end
            
            -- Dùng CFrame thẳng thay cho Tween nhở có Bypass
            local dist = (root.Position - NPC_CFRAME.Position).Magnitude
            if dist > 15 then
                root.CFrame = NPC_CFRAME
                root.AssemblyLinearVelocity = Vector3.new(0, 0.01, 0)
                root.AssemblyAngularVelocity = Vector3.zero
                task.wait(0.5)
            end
            
            applyXenoStabilizers(root, NPC_CFRAME)
            root.CFrame = NPC_CFRAME
            task.wait(1)

            -- Vòng lặp tự động nuốt ngón tay
            while _G.AutoFingersEaten < REQ_FINGER do
                print("🍽️ Đang nuốt ngón thứ " .. (_G.AutoFingersEaten + 1) .. "...")
                local args = {"Use", "Awakened Cursed Finger", 1, false}
                pcall(function() useItemRemote:FireServer(unpack(args)) end)
                
                _G.AutoFingersEaten = _G.AutoFingersEaten + 1
                task.wait(1.5) -- Đợi server load đồ
            end
            
            print("✅ BỤNG ĐÃ NO 20 NGÓN! Đang gửi lệnh Mua Class...")
            
            local npc = Workspace:FindFirstChild("ServiceNPCs") and Workspace.ServiceNPCs:FindFirstChild("StrongestinHistoryBuyerNPC")
            if npc then
                local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt and type(fireproximityprompt) == "function" then
                    prompt.RequiresLineOfSight = false
                    prompt.HoldDuration = 0
                    fireproximityprompt(prompt)
                    print("🎉 HOÀN TẤT! ĐÃ GỬI LỆNH MUA CLASS SUKUNA THÀNH CÔNG!")
                    
                    task.wait(2.5) -- Đợi Server load class vào túi đồ
                    
                    print("⚔️ Đang tự động trang bị Class...")
                    local equipArgs = {"Equip", TARGET_CLASS_NAME}
                    pcall(function() equipWeaponRemote:FireServer(unpack(equipArgs)) end)
                    
                    print("✅ Đã trang bị thành công! Sếp ra test skill khè Server được rồi đó!")
                    
                    task.wait(1.5)
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
                if (root.Position - targetCF.Position).Magnitude > 15 then 
                    root.CFrame = targetCF 
                    root.AssemblyLinearVelocity = Vector3.new(0, 0.01, 0)
                    root.AssemblyAngularVelocity = Vector3.zero
                else root.CFrame = CFrame.lookAt(root.Position, mobPos) end
            else
                CurrentTarget = nil; applyXenoStabilizers(root, root.CFrame)
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
                if (root.Position - targetCF.Position).Magnitude > 15 then 
                    root.CFrame = targetCF 
                    root.AssemblyLinearVelocity = Vector3.new(0, 0.01, 0)
                    root.AssemblyAngularVelocity = Vector3.zero
                else root.CFrame = CFrame.lookAt(root.Position, mobPos) end
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
            if (root.Position - targetCF.Position).Magnitude > 15 then 
                root.CFrame = targetCF 
                root.AssemblyLinearVelocity = Vector3.new(0, 0.01, 0)
                root.AssemblyAngularVelocity = Vector3.zero
            else root.CFrame = CFrame.lookAt(root.Position, mobPos) end
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
                        for _, v in pairs(bp:GetChildren()) do if v:IsA("Tool") then Player.Character.Humanoid:EquipTool(v) break end end
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
