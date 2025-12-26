--[[
    ═══════════════════════════════════════════════════════════════
    FARM MOB MODULE - Đánh quái tự động
    ═══════════════════════════════════════════════════════════════
    
    Chức năng:
    - Tự động tìm mob gần nhất
    - Bay đến và tấn công mob
    - Rút lui khi HP thấp
    
    Sử dụng:
    local Farm = loadstring(game:HttpGet("YOUR_URL"))()
    Farm.Config.selectedMobs = {"Zombie", "Skeleton"}
    Farm.start()  -- Bật farm
    Farm.stop()   -- Tắt farm
]]

-- ═══════════════════════════════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════════════════════════════
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- ═══════════════════════════════════════════════════════════════
-- CẤU HÌNH
-- ═══════════════════════════════════════════════════════════════
local Config = {
    -- Tween Settings
    tweenSpeed = 120,           -- Tốc độ di chuyển (studs/giây)
    flyHeight = 3,              -- Độ cao bay so với mục tiêu
    
    -- Mob Farm Settings
    enabled = false,            -- Trạng thái farm
    selectedMobs = {"Zombie"},  -- Danh sách mob muốn farm
    attackInterval = 0.1,       -- Khoảng cách giữa các lần đánh (giây)
    safeHealthPercent = 30,     -- HP% thấp hơn sẽ rút lui hồi máu
    scanDistance = 500,         -- Phạm vi quét mob (studs)
    
    -- Positioning Settings
    attackFromBehind = true,    -- ✅ Đứng phía sau mob để đánh
    behindDistance = 5,         -- Khoảng cách phía sau mob (studs)
}

-- ═══════════════════════════════════════════════════════════════
-- BIẾN TRẠNG THÁI
-- ═══════════════════════════════════════════════════════════════
local movementBusy = false      -- Khóa di chuyển (ngăn xung đột tween)

-- ═══════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

--- Lấy Character của người chơi
local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

--- Lấy HumanoidRootPart
local function getHumanoidRootPart()
    local char = getCharacter()
    return char:WaitForChild("HumanoidRootPart")
end

--- Lấy Humanoid
local function getHumanoid()
    local char = getCharacter()
    return char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid")
end

--- Chuyển list thành set để tra cứu nhanh O(1)
-- Input: {"Zombie", "Skeleton"}
-- Output: {["Zombie"] = true, ["Skeleton"] = true}
local function listToSet(list)
    local set = {}
    for _, v in ipairs(list or {}) do
        set[tostring(v)] = true
    end
    return set
end

--- Chuẩn hóa tên mob (bỏ số cuối)
-- "Zombie16" → "Zombie"
-- "Skeleton123" → "Skeleton"
local function normalizeMobName(name)
    return (tostring(name):gsub("%d+$", ""))
end

-- ═══════════════════════════════════════════════════════════════
-- HỆ THỐNG TWEEN (DI CHUYỂN)
-- ═══════════════════════════════════════════════════════════════

--[[
    Di chuyển nhân vật đến vị trí mục tiêu bằng Tween
    
    @param targetPos (Vector3) - Vị trí đích
    @param speed (number) - Tốc độ di chuyển (studs/s)
    
    Cách hoạt động:
    1. Chờ nếu đang có tween khác chạy
    2. Tính thời gian = khoảng cách / tốc độ
    3. Tạo tween di chuyển HumanoidRootPart
    4. Bay cao hơn mục tiêu flyHeight studs để tránh va chạm
]]
local function tweenToPosition(targetPos, speed)
    local hrp = getHumanoidRootPart()
    if not hrp then return end
    
    -- Chờ nếu đang có tween khác chạy
    while movementBusy do
        RunService.Heartbeat:Wait()
    end
    movementBusy = true
    
    -- Tính toán thời gian di chuyển
    speed = speed or Config.tweenSpeed
    local distance = (targetPos - hrp.Position).Magnitude
    local time = math.max(0.1, distance / math.max(10, speed))
    
    -- Tạo và chạy tween
    local tween = TweenService:Create(
        hrp,
        TweenInfo.new(time, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        { CFrame = CFrame.new(targetPos + Vector3.new(0, Config.flyHeight, 0)) }
    )
    
    tween.Completed:Connect(function()
        movementBusy = false
    end)
    
    tween:Play()
    tween.Completed:Wait()
    movementBusy = false
end

--[[
    Rút lui lên cao khi HP thấp
    
    Cách hoạt động:
    1. Bay lên 60 studs
    2. Anchor tại chỗ (đứng yên trên không)
    3. Chờ hồi máu đến safeHealthPercent + 10%
    4. Bay trở lại vị trí cũ
]]
local function retreatToSafety()
    local hum = getHumanoid()
    local hrp = getHumanoidRootPart()
    if not hum or not hrp then return end
    
    local startPos = hrp.Position
    local safeHeight = 60
    local safePos = startPos + Vector3.new(0, safeHeight, 0)
    
    -- Lưu trạng thái cũ
    local previousAnchored = hrp.Anchored
    local previousPlatformStand = hum.PlatformStand
    
    -- Bay lên và anchor
    pcall(function()
        tweenToPosition(safePos, Config.tweenSpeed)
        hrp.Anchored = true
        hum.PlatformStand = true
        hrp.CFrame = CFrame.new(safePos)
    end)
    
    -- Chờ hồi máu
    local targetPercent = (Config.safeHealthPercent or 0) + 10
    if targetPercent > 100 then targetPercent = 100 end
    
    print("[MobFarm] 🛡️ Đang hồi máu... chờ đến", targetPercent, "%")
    
    while Config.enabled and hum.Health > 0 and hum.MaxHealth > 0 do
        local hpPercent = (hum.Health / hum.MaxHealth) * 100
        if hpPercent >= targetPercent then
            break
        end
        -- Giữ vị trí
        if (hrp.Position - safePos).Magnitude > 3 then
            hrp.CFrame = CFrame.new(safePos)
            hrp.AssemblyLinearVelocity = Vector3.new()
        end
        task.wait(0.1)
    end
    
    -- Khôi phục trạng thái
    hrp.Anchored = previousAnchored
    hum.PlatformStand = previousPlatformStand
    
    -- Bay trở lại
    if Config.enabled and hum.Health > 0 then
        print("[MobFarm] ✅ Hồi máu xong, tiếp tục farm")
        local returnPos = startPos + Vector3.new(0, 5, 0)
        pcall(function()
            tweenToPosition(returnPos, Config.tweenSpeed)
        end)
    end
end

-- ═══════════════════════════════════════════════════════════════
-- HỆ THỐNG FARM MOB
-- ═══════════════════════════════════════════════════════════════

--[[
    Kiểm tra mob đã chết chưa
    
    @param model - Model của mob
    @return boolean - true nếu đã chết
    
    Kiểm tra:
    - Tìm BoolValue tên "Dead" trong model
    - Nếu Dead.Value == true → mob đã chết
]]
local function isMobDead(model)
    if not model then return true end
    if not model.Parent then return true end
    
    local deadFlag = model:FindFirstChild("Dead", true)
    if deadFlag and deadFlag:IsA("BoolValue") then
        return deadFlag.Value == true
    end
    
    -- Kiểm tra Humanoid
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then
        return true
    end
    
    return false
end

--[[
    Thu thập tất cả mob theo loại đã chọn
    
    @param selectedSet - Set loại mob muốn farm: {["Zombie"] = true}
    @return table - Danh sách: {{model, hrp, mobType}, ...}
    
    Cách hoạt động:
    1. Quét workspace.Living
    2. Bỏ qua mob đã chết
    3. Chuẩn hóa tên (bỏ số cuối)
    4. Kiểm tra có trong selectedSet không
]]
local function collectMobs(selectedSet)
    local living = workspace:FindFirstChild("Living")
    local result = {}
    if not living then return result end
    
    local hrp = getHumanoidRootPart()
    local maxDistSq = Config.scanDistance * Config.scanDistance
    
    for _, inst in ipairs(living:GetChildren()) do
        if not inst:IsA("Model") then continue end
        
        -- Bỏ qua mob đã chết
        if isMobDead(inst) then continue end
        
        -- Chuẩn hóa tên (bỏ số cuối)
        local baseName = normalizeMobName(inst.Name)
        
        -- Kiểm tra có trong danh sách chọn
        if not selectedSet[baseName] then continue end
        
        -- Tìm HumanoidRootPart
        local mobHrp = inst:FindFirstChild("HumanoidRootPart") or inst:FindFirstChild("HRP")
        if mobHrp and mobHrp:IsA("BasePart") then
            -- Kiểm tra khoảng cách
            if hrp then
                local distSq = (mobHrp.Position - hrp.Position).Magnitude ^ 2
                if distSq > maxDistSq then continue end
            end
            
            table.insert(result, {
                model = inst,
                hrp = mobHrp,
                mobType = baseName,
            })
        end
    end
    
    return result
end

--[[
    Tìm mob gần nhất
    
    @param selectedSet - Set loại mob muốn farm
    @return table|nil - {model, hrp, mobType} hoặc nil
]]
local function getNearestMob(selectedSet)
    local mobs = collectMobs(selectedSet)
    if #mobs == 0 then return nil end
    
    local hrp = getHumanoidRootPart()
    if not hrp then return nil end
    
    local best = nil
    local bestDist = math.huge
    
    for _, info in ipairs(mobs) do
        local dist = (info.hrp.Position - hrp.Position).Magnitude
        if dist < bestDist then
            bestDist = dist
            best = info
        end
    end
    
    return best
end

--[[
    Tấn công một mob
    
    @param mobInfo - {model, hrp, mobType}
    
    Gọi RemoteFunction:
    ReplicatedStorage.Shared.Packages.Knit.Services.ToolService.RF.ToolActivated("Weapon")
]]
local function attackMob(mobInfo)
    local mobModel = mobInfo.model
    local hrp = getHumanoidRootPart()
    if not (mobModel and mobModel.Parent and hrp) then return end
    
    -- Gọi remote
    local toolServiceRF = ReplicatedStorage:WaitForChild("Shared")
        :WaitForChild("Packages")
        :WaitForChild("Knit")
        :WaitForChild("Services")
        :WaitForChild("ToolService")
        :WaitForChild("RF")
    local toolActivated = toolServiceRF:WaitForChild("ToolActivated")
    
    pcall(function()
        toolActivated:InvokeServer("Weapon")
    end)
end

--[[
    Kiểm tra HP có thấp không
    
    @return boolean - true nếu HP <= safeHealthPercent
]]
local function isLowHealth()
    local hum = getHumanoid()
    if not hum or hum.MaxHealth <= 0 then return false end
    local hpPercent = (hum.Health / hum.MaxHealth) * 100
    return hpPercent <= (Config.safeHealthPercent or 0)
end

--[[
    Trang bị weapon từ Backpack
    
    @return Tool|nil
    
    Tìm tool có tên "Weapon" trong Character hoặc Backpack
]]
local function ensureWeaponEquipped()
    local char = getCharacter()
    local hum = getHumanoid()
    
    -- Kiểm tra đã trang bị
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and t.Name == "Weapon" then
            return t
        end
    end
    
    -- Tìm trong Backpack
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return nil end
    
    local weapon = backpack:FindFirstChild("Weapon")
    if not (weapon and weapon:IsA("Tool")) then return nil end
    
    pcall(function()
        if hum then
            hum:EquipTool(weapon)
        else
            weapon.Parent = char
        end
    end)
    task.wait(0.1)
    return weapon
end

-- ═══════════════════════════════════════════════════════════════
-- MAIN LOOP
-- ═══════════════════════════════════════════════════════════════

--[[
    Bắt đầu auto farm mob
    
    Vòng lặp:
    1. Kiểm tra HP thấp → rút lui
    2. Trang bị vũ khí
    3. Tìm mob gần nhất
    4. Bay đến mob
    5. Tấn công
    6. Lặp lại
]]
local function start()
    if Config.enabled then
        print("[MobFarm] ⚠️ Đã đang chạy!")
        return
    end
    
    Config.enabled = true
    print("[MobFarm] ✅ BẬT farm mob")
    print("[MobFarm] 📋 Đang farm:", table.concat(Config.selectedMobs, ", "))
    
    task.spawn(function()
        while Config.enabled do
            -- Kiểm tra HP thấp → rút lui
            if isLowHealth() then
                print("[MobFarm] ⚠️ HP thấp! Rút lui...")
                retreatToSafety()
                continue
            end
            
            -- Trang bị vũ khí
            local weapon = ensureWeaponEquipped()
            if not weapon then
                task.wait(0.1)
                continue
            end
            
            -- Tìm mob
            local selectedSet = listToSet(Config.selectedMobs)
            local target = getNearestMob(selectedSet)
            
            if not target then
                task.wait(0.2)
                continue
            end
            
            -- Tính vị trí đứng để tấn công
            local mobHrp = target.hrp
            if mobHrp and mobHrp:IsA("BasePart") then
                local targetPos = mobHrp.Position
                
                -- Nếu bật chế độ đứng phía sau mob
                if Config.attackFromBehind then
                    -- Lấy hướng nhìn của mob (LookVector)
                    local lookVector = mobHrp.CFrame.LookVector
                    -- Vị trí phía sau = vị trí mob - (hướng nhìn * khoảng cách)
                    local behindDist = Config.behindDistance or 5
                    targetPos = mobHrp.Position - (lookVector * behindDist)
                end
                
                pcall(function()
                    tweenToPosition(targetPos, Config.tweenSpeed)
                end)
            end
            
            -- Kiểm tra mob đã chết khi di chuyển
            if isMobDead(target.model) then continue end
            if not Config.enabled then break end
            if not target.model or not target.model.Parent then continue end
            
            -- Tấn công
            attackMob(target)
            
            local interval = Config.attackInterval or 0.1
            if interval < 0.02 then interval = 0.02 end
            task.wait(interval)
        end
        
        print("[MobFarm] ❌ Đã TẮT farm mob")
    end)
end

--[[
    Dừng farm mob
]]
local function stop()
    Config.enabled = false
    print("[MobFarm] 🛑 Đang dừng farm...")
end

-- ═══════════════════════════════════════════════════════════════
-- DEBUG FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

--[[
    In danh sách mob trong game
]]
local function listAllMobs()
    local living = workspace:FindFirstChild("Living")
    if not living then
        print("[MobFarm] ❌ Không tìm thấy workspace.Living")
        return {}
    end
    
    local mobNames = {}
    print("\n═══ DANH SÁCH MOB ═══")
    for _, mob in ipairs(living:GetChildren()) do
        if mob:IsA("Model") then
            local baseName = normalizeMobName(mob.Name)
            if not mobNames[baseName] then
                mobNames[baseName] = true
                local hrp = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("HRP")
                local dead = isMobDead(mob)
                print(string.format("  %s | HRP: %s | Dead: %s", 
                    baseName, 
                    hrp and "✅" or "❌",
                    dead and "💀" or "✅"
                ))
            end
        end
    end
    print("═══════════════════════\n")
    
    local result = {}
    for name in pairs(mobNames) do
        table.insert(result, name)
    end
    return result
end

-- ═══════════════════════════════════════════════════════════════
-- EXPORT MODULE
-- ═══════════════════════════════════════════════════════════════

return {
    -- Cấu hình
    Config = Config,
    
    -- Main functions
    start = start,
    stop = stop,
    
    -- Tween
    tweenToPosition = tweenToPosition,
    retreatToSafety = retreatToSafety,
    
    -- Mob functions
    collectMobs = collectMobs,
    getNearestMob = getNearestMob,
    attackMob = attackMob,
    ensureWeaponEquipped = ensureWeaponEquipped,
    
    -- Helpers
    isMobDead = isMobDead,
    isLowHealth = isLowHealth,
    listAllMobs = listAllMobs,
}

--[[
═══════════════════════════════════════════════════════════════
HƯỚNG DẪN SỬ DỤNG
═══════════════════════════════════════════════════════════════

-- 1. Load module
local MobFarm = loadstring(game:HttpGet("YOUR_URL"))()

-- 2. Xem danh sách mob trong game
MobFarm.listAllMobs()

-- 3. Cấu hình mob muốn farm
MobFarm.Config.selectedMobs = {"Zombie", "Skeleton", "Goblin"}

-- 4. Cấu hình khác (tùy chọn)
MobFarm.Config.tweenSpeed = 150          -- Tốc độ bay
MobFarm.Config.attackInterval = 0.05     -- Tốc độ đánh
MobFarm.Config.safeHealthPercent = 25    -- HP% rút lui
MobFarm.Config.scanDistance = 300        -- Phạm vi quét

-- 5. Bật farm
MobFarm.start()

-- 6. Tắt farm
MobFarm.stop()

═══════════════════════════════════════════════════════════════
]]
