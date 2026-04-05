-- ==============================================================================
-- 🔥 KAITUN SAILOR 2 (BẢN ĐỘ ENDGAME SUKUNA - CHỐNG CRASH TUYỆT ĐỐI)
-- ==============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Player = Players.LocalPlayer

local questcheck = require(ReplicatedStorage.Modules.QuestConfig)
local checkmap = require(ReplicatedStorage.TravelConfig)
local portalCfg = require(ReplicatedStorage.PortalConfig)

local combatRemote = ReplicatedStorage:WaitForChild("CombatSystem"):WaitForChild("Remotes"):WaitForChild("RequestHit")
local questAcceptR = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("QuestAccept")
local questAbandonR = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("QuestAbandon")
local teleportRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TeleportToPortal")
local allocateRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("AllocateStat")
local resetStatsRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("ResetStats")
local fruitActionRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("FruitAction")
local dropFruitRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):FindFirstChild("DropFruit")
local rollRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):FindFirstChild("FruitReroll")

_G.IsRollingFruit = false
_G.HasLightFruit = false
_G.StatsResetDone = false
_G.EndgameStarted = _G.EndgameStarted or false 

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

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.new(1, -20, 0, 22)
	statusLabel.Position = UDim2.new(0, 10, 0, 8)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextSize = 14
	statusLabel.TextColor3 = Color3.fromRGB(0, 255, 180)
	statusLabel.Text = "Auto Farm: Starting..."
	statusLabel.Parent = frame

	local taskLabel = Instance.new("TextLabel")
	taskLabel.Name = "Task"
	taskLabel.Size = UDim2.new(1, -20, 0, 20)
	taskLabel.Position = UDim2.new(0, 10, 0, 30)
	taskLabel.BackgroundTransparency = 1
	taskLabel.Font = Enum.Font.Gotham
	taskLabel.TextSize = 12
	taskLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
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
	statsLabel.Parent = frame

	return gui
end

local hud = createHUD()

task.spawn(function()
	while task.wait(0.5) do
		pcall(function()
			local main = hud and hud:FindFirstChild("Main")
			if not main then hud = createHUD(); main = hud:FindFirstChild("Main") end

			local data = Player:FindFirstChild("Data")
			local level = data and data:FindFirstChild("Level") and data.Level.Value or "?"
			local money = data and data:FindFirstChild("Money") and data.Money.Value or 0

			main.Status.Text = _G.IsRollingFruit and "Auto Farm: PAUSED (Rolling Fruit)" or "Auto Farm: " .. farmStatus
			main.Task.Text = "Task: " .. taskStatus
			main.Info.Text = '<font color="#00FF99">Lv.'..tostring(level)..'</font> | <font color="#FFD700">Money: '..tostring(money)..'</font>'

			if _G.EndgameStarted then
			    main.Stats.Text = "Auto Stats: [ENDGAME] Max Melee & Pump Defense"
			elseif _G.HasLightFruit then
				main.Stats.Text = "Auto Stats: +10 Power & +10 Defense"
			else
				main.Stats.Text = "Auto Stats: +10 Melee & +10 Defense"
			end
		end)
	end
end)

local KILL_AURA_RANGE = 50
local FARM_HEIGHT = 20 
local NPC_ROLL_CFRAME = CFrame.new(408.244568, 2.82981968, 802.734131, -0.156446099, 0, 0.987686574, 0, 1, 0, -0.987686574, 0, -0.156446099)

-- FIX TUYỆT ĐỐI CHỐNG CRASH TẠI ĐÂY
local homeIsland, currentChoosenpc, currentTargetNPC, prevChoosenpc, lockedPos, homePortal
local lastAcceptTime = 0 

local mobConfig = {
	["Thief"] = { island = "Starter", zoneId = "StarterIsland" },
	["ThiefBoss"] = { island = "Starter", zoneId = "StarterIsland" },
	["Monkey"] = { island = "Jungle", zoneId = "JungleIsland" },
	["MonkeyBoss"] = { island = "Jungle", zoneId = "JungleIsland" },
	["DesertBandit"] = { island = "Desert", zoneId = "DesertIsland" },
	["DesertBoss"] = { island = "Desert", zoneId = "DesertIsland" },
	["FrostRogue"] = { island = "Snow", zoneId = "SnowIsland" },
	["SnowBoss"] = { island = "Snow", zoneId = "SnowIsland" },
	["Sorcerer"] = { island = "Shibuya", zoneId = "ShibuyaStation" },
	["PandaMiniBoss"] = { island = "Shibuya", zoneId = "ShibuyaStation" },
	["Hollow"] = { island = "HuecoMundo", zoneId = "HuecoMundo" },
	["StrongSorcerer"] = { island = "Shinjuku", zoneId = "ShinjukuIsland" },
	["Curse"] = { island = "Shinjuku", zoneId = "ShinjukuIsland" },
	["Slime"] = { island = "Slime", zoneId = "SlimeIsland" },
	["SlimeWarrior"] = { island = "Slime", zoneId = "SlimeIsland" },
	["AcademyTeacher"] = { island = "Academy", zoneId = "AcademyIsland" },
	["Swordsman"] = { island = "Judgement", zoneId = "JudgementIsland" },
	["Quincy"] = { island = "SoulSociety", zoneId = "SoulSocietyIsland" },
	["Ninja"] = { island = "Ninja", zoneId = "NinjaIsland" },
	["ArenaFighter"] = { island = "Lawless", zoneId = "LawlessIsland" },
}
local SKIP_MOBS = { ["Quincy"] = true }
local sortedIslands = (function() local list = {}; for _, portal in ipairs(portalCfg.GetSortedPortals()) do table.insert(list, portal.data.IslandFolder) end; return list end)()

local function getRoot() return Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") end

local function applyXenoStabilizers(root, goalCF)
	local bv = root:FindFirstChild("KaitunStabBV")
	if not bv then bv = Instance.new("BodyVelocity"); bv.Name = "KaitunStabBV"; bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge); bv.P = 1250; bv.Parent = root end
	bv.Velocity = Vector3.zero
	local bg = root:FindFirstChild("KaitunStabBG")
	if not bg then bg = Instance.new("BodyGyro"); bg.Name = "KaitunStabBG"; bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge); bg.P = 3000; bg.D = 500; bg.Parent = root end
	bg.CFrame = goalCF
end

local function cleanupXenoStabilizers() pcall(function() local root = getRoot(); if not root then return end; local bv = root:FindFirstChild("KaitunStabBV"); local bg = root:FindFirstChild("KaitunStabBG"); if bv then bv:Destroy() end; if bg then bg:Destroy() end end) end

local function getMobPos(npc)
	local hrp = npc:FindFirstChild("HumanoidRootPart")
	if hrp then return hrp.Position end
	if npc.PrimaryPart then return npc.PrimaryPart.Position end
	local ok, pivot = pcall(function() return npc:GetPivot().Position end)
	if ok and pivot then return pivot end
	for _, part in pairs(npc:GetDescendants()) do if part:IsA("BasePart") then return part.Position end end
	return nil
end

local function getTargetQuest()
	local data = Player:FindFirstChild("Data")
	if not data then return nil, -1, nil end
	local level = data:FindFirstChild("Level") and data.Level.Value or 0
	local bestNPC, maxLevelFound, choosenpc = nil, -1, nil
	for npcName, qData in pairs(questcheck.RepeatableQuests) do
		local req = tonumber(qData.recommendedLevel) or 0
		if level >= req and req > maxLevelFound then
			local mobType = qData.requirements and qData.requirements[1] and qData.requirements[1].npcType
			if mobType and SKIP_MOBS[mobType] then continue end
			maxLevelFound = req; bestNPC = npcName; choosenpc = mobType
		end
	end
	return bestNPC, maxLevelFound, choosenpc
end

local function findClosestMob(mobType)
	local npcsFolder = workspace:FindFirstChild("NPCs")
	local root = getRoot()
	if not npcsFolder or not root then return nil, math.huge end
	local closest, closestDist = nil, math.huge
	for _, npc in pairs(npcsFolder:GetChildren()) do
		if string.find(npc.Name, mobType) then
			local hum = npc:FindFirstChildOfClass("Humanoid")
			local pos = getMobPos(npc)
			if hum and hum.Health > 0 and pos then
				local dist = (root.Position - pos).Magnitude
				if dist < closestDist then closestDist = dist; closest = npc end
			end
		end
	end
	return closest, closestDist
end

local function checkHasLight()
	local bp = Player:FindFirstChild("Backpack")
	local char = Player.Character
	local found = false
	if bp then for _, v in pairs(bp:GetChildren()) do if v.Name == "Light Fruit" or v.Name == "Light" then found = true end end end
	if char then for _, v in pairs(char:GetChildren()) do if v.Name == "Light Fruit" or v.Name == "Light" then found = true end end end
	return found
end

-- TỰ ĐỘNG ĐI ROLL TRÁI (ĐÃ CHẶN KHI Ở ENDGAME)
task.spawn(function()
	while task.wait(3) do
		_G.HasLightFruit = checkHasLight()
		if _G.HasLightFruit or _G.EndgameStarted then continue end 

		local data = Player:FindFirstChild("Data")
		if not data then continue end
		local level = data:FindFirstChild("Level") and data.Level.Value or 0
		local money = data:FindFirstChild("Money") and data.Money.Value or 0

		if level >= 1000 and money >= 1000000 and not _G.IsRollingFruit and not _G.EndgameStarted then
			_G.IsRollingFruit = true
			taskStatus = "Going to Roll Fruit..."
			task.wait(1.5)
			cleanupXenoStabilizers()

			local root = getRoot()
			if not root then _G.IsRollingFruit = false continue end
			local startZoneId, _ = checkmap.GetZoneAt(root.Position)
			local isAtSailor = (root.Position - NPC_ROLL_CFRAME.Position).Magnitude < 5000

			if not isAtSailor then pcall(function() teleportRemote:FireServer("Sailor") end) repeat task.wait(0.5); root = getRoot() until root and (root.Position - NPC_ROLL_CFRAME.Position).Magnitude < 5000 end
			
			root.CFrame = NPC_ROLL_CFRAME
			task.wait(0.5)

			while _G.IsRollingFruit do
				root = getRoot()
				if not root then break end
				money = data:FindFirstChild("Money") and data.Money.Value or 0
				if money < 15000 then break end

				local bp = Player:FindFirstChild("Backpack")
				if bp and bp:FindFirstChild("Light Fruit") then
					pcall(function() fruitActionRemote:FireServer(unpack({"eat", "Light Fruit"})) end)
					_G.HasLightFruit = true; task.wait(1); break
				end

				if bp then for _, v in pairs(bp:GetChildren()) do if string.find(v.Name, "Fruit") and v.Name ~= "Light Fruit" then if dropFruitRemote then pcall(function() dropFruitRemote:FireServer() end) end; v:Destroy(); task.wait(0.2) end end end
				if rollRemote then pcall(function() rollRemote:FireServer() end) end
				for _, prompt in pairs(workspace:GetDescendants()) do if prompt:IsA("ProximityPrompt") and prompt.Parent and prompt.Parent:IsA("BasePart") then if (root.Position - prompt.Parent.Position).Magnitude <= 15 then fireproximityprompt(prompt) end end end
				task.wait(2)
			end

			if startZoneId and startZoneId ~= "SailorIsland" then
				taskStatus = "Returning to Farm..."
				local returnPortalArg = string.gsub(startZoneId, "Island", ""):gsub(" ", "")
				pcall(function() teleportRemote:FireServer(returnPortalArg) end)
				repeat task.wait(0.5); root = getRoot() until checkmap.GetZoneAt(root.Position) == startZoneId
			end
			_G.IsRollingFruit = false
			lockedPos = nil 
		end
	end
end)

-- VÒNG LẶP ĐÁNH QUÁI
task.spawn(function()
	while task.wait(0.5) do
		if _G.IsRollingFruit then task.wait(1); continue end

		pcall(function()
			if Player.Character then
				local bp = Player:FindFirstChild("Backpack")
				if bp then
				    -- ENDGAME EQUIP
				    if _G.EndgameStarted then
				        local class = bp:FindFirstChild("Strongest In History")
				        if class then Player.Character.Humanoid:EquipTool(class) end
				    else
    					local lightTool = bp:FindFirstChild("Light Fruit") or bp:FindFirstChild("Light")
    					if lightTool then Player.Character.Humanoid:EquipTool(lightTool)
    					elseif not Player.Character:FindFirstChildWhichIsA("Tool") then
    						for _, v in pairs(bp:GetChildren()) do if v:IsA("Tool") then Player.Character.Humanoid:EquipTool(v); break end end
    					end
    				end
				end
			end
		end)

		farmStatus = "Getting quest..."
		local targetNPC, _, choosenpc = getTargetQuest()
		if not (targetNPC and choosenpc) then continue end

		if choosenpc ~= prevChoosenpc then
			if prevChoosenpc then pcall(function() questAbandonR:FireServer("repeatable") end); task.wait(0.5); homeIsland = nil; homePortal = nil; lockedPos = nil; cleanupXenoStabilizers() end
			prevChoosenpc = choosenpc
		end

		currentTargetNPC = targetNPC; currentChoosenpc = choosenpc

		-- ĐÃ CÓ BẢO HIỂM lastAcceptTime
		if tick() - lastAcceptTime > 5 then pcall(function() questAcceptR:FireServer(targetNPC) end); lastAcceptTime = tick(); task.wait(0.5) end

		local hrp = getRoot()
		if not hrp then continue end
		local currentZoneId, currentZoneData = checkmap.GetZoneAt(hrp.Position)

		if homeIsland then
			if currentZoneId ~= homeIsland then farmStatus = "Teleporting..."; pcall(function() teleportRemote:FireServer(homePortal) end); task.wait(0.5) end

			farmStatus = "Farming " .. choosenpc
			local lastCheck = tick()

			while task.wait(0.1) do
				if _G.IsRollingFruit then cleanupXenoStabilizers(); break end
				local root = getRoot()
				if not root then break end

				root.Anchored = false; root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero
				local npc = findClosestMob(currentChoosenpc)
				if npc and getMobPos(npc) then
					local mobPos = getMobPos(npc)
					local targetCFrame = CFrame.lookAt(mobPos + Vector3.new(0, FARM_HEIGHT, 0), mobPos)
					applyXenoStabilizers(root, targetCFrame)
					if (root.Position - targetCFrame.Position).Magnitude > 10 then root.CFrame = targetCFrame else root.CFrame = CFrame.lookAt(root.Position, mobPos) end
				else
					farmStatus = "Waiting respawn..."
					if root then applyXenoStabilizers(root, root.CFrame) end
				end

				if tick() - lastCheck > 3 then
					lastCheck = tick()
					local _, _, newChoose = getTargetQuest()
					if newChoose ~= currentChoosenpc then pcall(function() questAbandonR:FireServer("repeatable") end); lockedPos = nil; homeIsland = nil; homePortal = nil; cleanupXenoStabilizers(); break end
					
					-- ĐÃ CÓ BẢO HIỂM lastAcceptTime
					if tick() - lastAcceptTime > 5 then pcall(function() questAcceptR:FireServer(currentTargetNPC) end); lastAcceptTime = tick() end
				end
			end
			cleanupXenoStabilizers()
			continue
		end

		local config = mobConfig[choosenpc]
		if config then homeIsland = config.zoneId; homePortal = config.island; pcall(function() teleportRemote:FireServer(config.island) end); task.wait(1.5) end
	end
end)

task.spawn(function()
	while task.wait(0.1) do
		if _G.IsRollingFruit then continue end
		local root = getRoot()
		if not root then continue end
		local npcsFolder = workspace:FindFirstChild("NPCs")
		if not npcsFolder then continue end
		for _, mob in pairs(npcsFolder:GetChildren()) do
			local hum = mob:FindFirstChildOfClass("Humanoid")
			if not (hum and hum.Health > 0) then continue end
			local pos = getMobPos(mob)
			if pos and (root.Position - pos).Magnitude <= KILL_AURA_RANGE then task.spawn(function() pcall(function() combatRemote:FireServer(pos) end) end) end
		end
	end
end)

task.spawn(function()
	local abilityRemote = ReplicatedStorage:WaitForChild("AbilitySystem"):WaitForChild("Remotes"):WaitForChild("RequestAbility")
	local fruitPowerRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("FruitPowerRemote")
	local lightKeys = { Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C }
	while task.wait(0.3) do
		if _G.IsRollingFruit then continue end
		local npcsFolder = workspace:FindFirstChild("NPCs")
		local root = getRoot()
		local mobPos = nil
		if npcsFolder and root then
			local closestDist = math.huge
			for _, npc in pairs(npcsFolder:GetChildren()) do
				local hum = npc:FindFirstChildOfClass("Humanoid")
				local pos = getMobPos(npc)
				if hum and hum.Health > 0 and pos then local dist = (root.Position - pos).Magnitude; if dist < closestDist then closestDist = dist; mobPos = pos end end
			end
		end

		for skillId = 1, 5 do pcall(function() if mobPos then abilityRemote:FireServer(skillId, mobPos) else abilityRemote:FireServer(skillId) end end) end

		if _G.HasLightFruit and not _G.EndgameStarted then
			for _, key in ipairs(lightKeys) do pcall(function() fruitPowerRemote:FireServer(unpack({"UseAbility", {FruitPower = "Light", KeyCode = key}})) end) end
		end
	end
end)

-- TỰ ĐỘNG CỘNG ĐIỂM 
task.spawn(function()
	local getStatsRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("GetPlayerStats")
	while task.wait(1.5) do
		if _G.IsRollingFruit or _G.EndgameStarted then continue end 

		if _G.HasLightFruit then
			local powerVal = nil
			pcall(function() local result = getStatsRemote:InvokeServer(); if result and type(result) == "table" and result.Stats then powerVal = tonumber(result.Stats.Power) end end)
			if powerVal == nil then continue end
			if powerVal < 1000 and not _G.StatsResetDone then pcall(function() resetStatsRemote:FireServer() end); _G.StatsResetDone = true; task.wait(1) end
			pcall(function() allocateRemote:FireServer("Power", 10) end)
			pcall(function() allocateRemote:FireServer("Defense", 10) end)
		else
			pcall(function() allocateRemote:FireServer("Melee", 10) end)
			pcall(function() allocateRemote:FireServer("Defense", 10) end)
		end
	end
end)

if _G.KaitunSailor2Loaded then warn("[Kaitun 2] Script đã chạy rồi!") else _G.KaitunSailor2Loaded = true end
