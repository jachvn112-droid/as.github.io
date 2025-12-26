--[[
    B4Hub Forge - Tween & Farm Module (Rewrite)
    Chỉ chứa các chức năng:
    - Hệ thống Tween (di chuyển)
    - Farm Ore (đào quặng)
    - Farm Mob (đánh quái)
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
    
    -- Ore Farm Settings
    oreFarmEnabled = false,
    selectedRockTypes = {"Boulder"},    -- ✅ Farm đá Boulder
    selectedOreTypes = {"Iron"},        -- ✅ Farm quặng Iron
    scanDistance = 500,         -- Phạm vi quét (studs)
    maxRockTime = 4,            -- Thời gian tối đa đào 1 đá (giây)
    mineInterval = 0.1,         -- Khoảng cách giữa các lần đập (giây)
    pickaxeDamage = 0,          -- Sát thương cuốc hiện tại
    
    -- Mob Farm Settings
    mobFarmEnabled = false,
    selectedMobs = {"Zombie"},          -- ✅ Farm mob Zombie
    attackInterval = 0.1,       -- Khoảng cách giữa các lần đánh
    safeHealthPercent = 30,     -- HP% thấp hơn sẽ rút lui
}

-- ═══════════════════════════════════════════════════════════════
-- BIẾN TRẠNG THÁI
-- ═══════════════════════════════════════════════════════════════
local movementBusy = false      -- Khóa di chuyển (ngăn xung đột)
local rockBlacklist = {}        -- Đá đã bỏ qua (ore sai)

-- ═══════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS (Hàm hỗ trợ)
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
local function listToSet(list)
    local set = {}
    for _, v in ipairs(list or {}) do
        set[tostring(v)] = true
    end
    return set
end

--- Chuẩn hóa tên mob (bỏ số cuối: "Zombie16" → "Zombie")
local function normalizeMobName(name)
    return (tostring(name):gsub("%d+$", ""))
end

-- ═══════════════════════════════════════════════════════════════
-- HỆ THỐNG TWEEN (DI CHUYỂN)
-- ═══════════════════════════════════════════════════════════════

--[[
    Di chuyển nhân vật đến vị trí mục tiêu bằng Tween
    @param targetPos (Vector3) - Vị trí đích
    @param speed (number) - Tốc độ di chuyển (studs/s), mặc định = Config.tweenSpeed
    
    Cách hoạt động:
    1. Kiểm tra xem có tween khác đang chạy không (movementBusy)
    2. Tính thời gian dựa trên khoảng cách và tốc độ
    3. Tạo tween di chuyển HumanoidRootPart
    4. Bay cao hơn mục tiêu 3 studs để tránh va chạm
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
    Rút lui lên cao khi HP thấp (dùng cho farm mob)
    Bay lên 60 studs, anchor tại chỗ, chờ hồi máu
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
    
    while Config.mobFarmEnabled and hum.Health > 0 and hum.MaxHealth > 0 do
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
    if Config.mobFarmEnabled and hum.Health > 0 then
        local returnPos = startPos + Vector3.new(0, 5, 0)
        pcall(function()
            tweenToPosition(returnPos, Config.tweenSpeed)
        end)
    end
end

-- ═══════════════════════════════════════════════════════════════
-- HỆ THỐNG FARM ORE (ĐÀO QUẶNG)
-- ═══════════════════════════════════════════════════════════════

--[[
    Kiểm tra đá đã bị phá hủy chưa
    @param rockModel - Model của đá
    @return boolean
]]
local function isRockDestroyed(rockModel)
    if not rockModel or not rockModel.Parent then
        return true
    end
    
    -- Tìm Health attribute
    local healthAttr = rockModel:GetAttribute("Health")
    if healthAttr == nil then
        local rockChild = rockModel:FindFirstChild("Rock") or rockModel:FindFirstChild("Boulder")
        if rockChild then
            healthAttr = rockChild:GetAttribute("Health")
        end
    end
    
    local numeric = tonumber(healthAttr)
    if numeric ~= nil then
        return numeric <= 0
    end
    return false
end

--[[
    Thu thập tất cả đá trong phạm vi
    @param maxDist (number) - Khoảng cách tối đa
    @param origin (Vector3) - Vị trí gốc để tính khoảng cách
    @return table - Danh sách đá: {model, core, rockType, requiredDamage, visual}
]]
local function collectAllRocks(maxDist, origin)
    local rocksRoot = workspace:FindFirstChild("Rocks")
    local result = {}
    if not rocksRoot then return result end
    
    local scanDistSq = maxDist and (maxDist * maxDist)
    
    for _, folder in ipairs(rocksRoot:GetChildren()) do
        for _, container in ipairs(folder:GetChildren()) do
            -- Kiểm tra tồn tại
            if not container or not container.Parent then continue end
            
            -- Tìm phần core (BasePart chính)
            local core = container:IsA("BasePart") and container
                or container.PrimaryPart
                or container:FindFirstChild("HumanoidRootPart")
                or container:FindFirstChildWhichIsA("BasePart")
            
            if not core then continue end
            
            -- Kiểm tra khoảng cách (dùng bình phương để tối ưu)
            if scanDistSq and origin then
                local pos = core.Position
                local distSq = (pos.X - origin.X)^2 + (pos.Y - origin.Y)^2 + (pos.Z - origin.Z)^2
                if distSq > scanDistSq then
                    continue
                end
            end
            
            -- Kiểm tra còn sống
            if isRockDestroyed(container) then
                continue
            end
            
            -- Tìm visual
            local visual = container:FindFirstChild("Boulder")
                or container:FindFirstChild("Rock")
            if not visual then
                for _, child in ipairs(container:GetChildren()) do
                    if child:IsA("Model") or child:IsA("BasePart") then
                        visual = child
                        break
                    end
                end
            end
            
            if visual then
                local rockTypeName = container:GetAttribute("RockType")
                    or visual:GetAttribute("RockType")
                    or visual.Name
                    or container.Name
                    
                local requiredDamage = tonumber(container:GetAttribute("RequiredDamage"))
                    or tonumber(visual:GetAttribute("RequiredDamage"))
                
                table.insert(result, {
                    model = container,
                    core = core,
                    rockType = rockTypeName,
                    requiredDamage = requiredDamage,
                    visual = visual,
                })
            end
        end
    end
    return result
end

--[[
    Lấy tên các loại ore trong một đá
    @param rockModel - Model của đá
    @return table - Set các tên ore: {["Iron"] = true, ["Gold"] = true}
]]
local function getOreNamesForRock(rockModel)
    local names = {}
    local rockFolder = rockModel:FindFirstChild("Rock")
    if not rockFolder then return names end
    
    for _, inst in ipairs(rockFolder:GetDescendants()) do
        local oreNameAttr = inst:GetAttribute("Ore")
        if oreNameAttr then
            local oreName = tostring(oreNameAttr)
            if oreName ~= "" then
                names[oreName] = true
            end
        end
    end
    return names
end

--[[
    Kiểm tra đá có chứa ore mong muốn không
    @param oreNames - Set tên ore trong đá
    @param desiredSet - Set tên ore muốn farm
    @return boolean
]]
local function hasDesiredOre(oreNames, desiredSet)
    for name, _ in pairs(oreNames) do
        if desiredSet[name] then
            return true
        end
    end
    return false
end

--[[
    Kiểm tra đá có chứa ore nào không
    @param oreNames - Set tên ore
    @return boolean
]]
local function rockHasAnyOre(oreNames)
    for _, _ in pairs(oreNames) do
        return true
    end
    return false
end

--[[
    Tìm đá gần nhất phù hợp với cấu hình
    @param filteredRockTypes - Set loại đá muốn farm
    @param blacklist - Set đá bị bỏ qua
    @return table|nil - Thông tin đá: {model, core, rockType, ...}
]]
local function getNearestRock(filteredRockTypes, blacklist)
    local hrp = getHumanoidRootPart()
    if not hrp then return nil end
    
    local scanDist = Config.scanDistance or 500
    local allRocks = collectAllRocks(scanDist, hrp.Position)
    
    if #allRocks == 0 then return nil end
    
    local best = nil
    local bestDist = math.huge
    local currentDmg = Config.pickaxeDamage or 0
    blacklist = blacklist or {}
    
    for _, info in ipairs(allRocks) do
        -- Bỏ qua đá trong blacklist
        if blacklist[info.model] then continue end
        
        -- Kiểm tra loại đá
        if not filteredRockTypes[info.rockType] then continue end
        
        -- Kiểm tra damage yêu cầu
        local req = tonumber(info.requiredDamage)
        if req and currentDmg < req then continue end
        
        -- Tìm gần nhất
        local dist = (info.core.Position - hrp.Position).Magnitude
        if dist < bestDist then
            bestDist = dist
            best = info
        end
    end
    
    return best
end

--[[
    Đào một đá
    @param rockInfo - Thông tin đá từ getNearestRock
    @param desiredOres - List ore muốn farm
    @return string - "destroyed" | "switch" | "timeout"
    
    Cách hoạt động:
    1. Gọi ToolService.ToolActivated("Pickaxe") liên tục
    2. Kiểm tra ore trong đá có đúng loại không
    3. Nếu ore sai → return "switch" để blacklist
]]
local function mineRock(rockInfo, desiredOres)
    local rockModel = rockInfo.model
    local startTick = tick()
    
    -- Lấy remote function
    local toolServiceRF = ReplicatedStorage:WaitForChild("Shared")
        :WaitForChild("Packages")
        :WaitForChild("Knit")
        :WaitForChild("Services")
        :WaitForChild("ToolService")
        :WaitForChild("RF")
    local toolActivated = toolServiceRF:WaitForChild("ToolActivated")
    
    local args = { "Pickaxe" }
    local desiredSet = listToSet(desiredOres)
    local maxTime = Config.maxRockTime or 4
    
    while Config.oreFarmEnabled and rockModel.Parent and tick() - startTick < maxTime do
        -- Kiểm tra đá đã chết
        if isRockDestroyed(rockModel) then
            return "destroyed"
        end
        
        -- Kiểm tra khoảng cách
        local core = rockInfo.core
        local hrp = getHumanoidRootPart()
        if core and hrp then
            local dist = (core.Position - hrp.Position).Magnitude
            if dist > 18 then
                return "switch" -- Quá xa
            end
        end
        
        -- Kiểm tra ore
        local oreNames = getOreNamesForRock(rockModel)
        if rockHasAnyOre(oreNames) then
            if hasDesiredOre(oreNames, desiredSet) then
                -- Ore đúng → đào tiếp
                pcall(function()
                    toolActivated:InvokeServer(unpack(args))
                end)
            else
                -- Ore sai → blacklist
                return "switch"
            end
        else
            -- Chưa thấy ore → cứ đào
            pcall(function()
                toolActivated:InvokeServer(unpack(args))
            end)
        end
        
        local interval = Config.mineInterval or 0.1
        if interval < 0.02 then interval = 0.02 end
        task.wait(interval)
    end
    
    return "timeout"
end

--[[
    Trang bị pickaxe từ Backpack
    @return Tool|nil
]]
local function ensurePickaxeEquipped()
    local char = getCharacter()
    local hum = getHumanoid()
    
    -- Kiểm tra đã trang bị chưa
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and (t.Name:lower():find("pickaxe") or t:GetAttribute("ItemName") and tostring(t:GetAttribute("ItemName")):lower():find("pickaxe")) then
            return t
        end
    end
    
    -- Tìm trong Backpack
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return nil end
    
    for _, t in ipairs(backpack:GetChildren()) do
        if t:IsA("Tool") and (t.Name:lower():find("pickaxe") or t:GetAttribute("ItemName") and tostring(t:GetAttribute("ItemName")):lower():find("pickaxe")) then
            pcall(function()
                if hum then
                    hum:EquipTool(t)
                else
                    t.Parent = char
                end
            end)
            task.wait(0.1)
            return t
        end
    end
    
    warn("[Farm] Không tìm thấy pickaxe!")
    return nil
end

-- ═══════════════════════════════════════════════════════════════
-- HỆ THỐNG FARM MOB (ĐÁNH QUÁI)
-- ═══════════════════════════════════════════════════════════════

--[[
    Kiểm tra mob đã chết chưa
    @param model - Model của mob
    @return boolean
]]
local function isMobDead(model)
    if not model then return false end
    local deadFlag = model:FindFirstChild("Dead", true)
    if deadFlag and deadFlag:IsA("BoolValue") then
        return deadFlag.Value == true
    end
    return false
end

--[[
    Thu thập tất cả mob theo loại đã chọn
    @param selectedSet - Set loại mob muốn farm
    @return table - Danh sách mob: {model, hrp, mobType}
]]
local function collectMobs(selectedSet)
    local living = workspace:FindFirstChild("Living")
    local result = {}
    if not living then return result end
    
    for _, inst in ipairs(living:GetChildren()) do
        if not inst:IsA("Model") then continue end
        
        -- Bỏ qua mob đã chết
        if isMobDead(inst) then continue end
        
        -- Chuẩn hóa tên (bỏ số cuối)
        local baseName = normalizeMobName(inst.Name)
        
        -- Kiểm tra có trong danh sách chọn
        if not selectedSet[baseName] then continue end
        
        -- Tìm HumanoidRootPart
        local hrp = inst:FindFirstChild("HumanoidRootPart") or inst:FindFirstChild("HRP")
        if hrp and hrp:IsA("BasePart") then
            table.insert(result, {
                model = inst,
                hrp = hrp,
                mobType = baseName,
            })
        end
    end
    
    return result
end

--[[
    Tìm mob gần nhất
    @param selectedSet - Set loại mob muốn farm
    @return table|nil - Thông tin mob: {model, hrp, mobType}
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
    @param mobInfo - Thông tin mob từ getNearestMob
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
    @return boolean
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
-- MAIN LOOPS (VÒNG LẶP CHÍNH)
-- ═══════════════════════════════════════════════════════════════

--[[
    Bắt đầu auto farm ore
    Gọi hàm này để bật farm
]]
local function startOreFarm()
    Config.oreFarmEnabled = true
    
    task.spawn(function()
        local blacklistCleanupTimer = 0
        
        while Config.oreFarmEnabled do
            -- Dọn blacklist mỗi 30 giây
            if tick() - blacklistCleanupTimer > 30 then
                table.clear(rockBlacklist)
                blacklistCleanupTimer = tick()
            end
            
            -- Trang bị pickaxe
            local pick = ensurePickaxeEquipped()
            if not pick then
                task.wait(0.1)
                continue
            end
            
            -- Tìm đá
            local rockSet = listToSet(Config.selectedRockTypes)
            local targetRock = getNearestRock(rockSet, rockBlacklist)
            
            if not targetRock then
                table.clear(rockBlacklist) -- Không có đá → xóa blacklist thử lại
                task.wait(0.5)
                continue
            end
            
            -- Di chuyển đến đá
            local core = targetRock.core
            if core and core:IsA("BasePart") then
                pcall(function()
                    tweenToPosition(core.Position, Config.tweenSpeed)
                end)
            end
            
            -- Kiểm tra còn bật và đá còn tồn tại
            if not Config.oreFarmEnabled then break end
            if not targetRock.model or not targetRock.model.Parent then continue end
            
            -- Đào
            local result = mineRock(targetRock, Config.selectedOreTypes)
            
            -- Nếu ore sai → blacklist
            if result == "switch" then
                rockBlacklist[targetRock.model] = true
                print("[Farm] Blacklist đá có ore sai")
            end
        end
    end)
end

--[[
    Dừng farm ore
]]
local function stopOreFarm()
    Config.oreFarmEnabled = false
end

--[[
    Bắt đầu auto farm mob
]]
local function startMobFarm()
    Config.mobFarmEnabled = true
    
    task.spawn(function()
        while Config.mobFarmEnabled do
            -- Kiểm tra HP thấp → rút lui
            if isLowHealth() then
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
            
            -- Di chuyển đến mob
            local mobHrp = target.hrp
            if mobHrp and mobHrp:IsA("BasePart") then
                pcall(function()
                    tweenToPosition(mobHrp.Position, Config.tweenSpeed)
                end)
            end
            
            -- Kiểm tra mob đã chết khi di chuyển
            if isMobDead(target.model) then continue end
            if not Config.mobFarmEnabled then break end
            if not target.model or not target.model.Parent then continue end
            
            -- Tấn công
            attackMob(target)
            
            local interval = Config.attackInterval or 0.1
            if interval < 0.02 then interval = 0.02 end
            task.wait(interval)
        end
    end)
end

--[[
    Dừng farm mob
]]
local function stopMobFarm()
    Config.mobFarmEnabled = false
end

-- ═══════════════════════════════════════════════════════════════
-- EXPORT MODULE
-- ═══════════════════════════════════════════════════════════════

return {
    -- Cấu hình
    Config = Config,
    
    -- Tween Functions
    tweenToPosition = tweenToPosition,
    retreatToSafety = retreatToSafety,
    
    -- Ore Farm Functions
    collectAllRocks = collectAllRocks,
    getNearestRock = getNearestRock,
    getOreNamesForRock = getOreNamesForRock,
    mineRock = mineRock,
    ensurePickaxeEquipped = ensurePickaxeEquipped,
    startOreFarm = startOreFarm,
    stopOreFarm = stopOreFarm,
    
    -- Mob Farm Functions
    collectMobs = collectMobs,
    getNearestMob = getNearestMob,
    attackMob = attackMob,
    ensureWeaponEquipped = ensureWeaponEquipped,
    startMobFarm = startMobFarm,
    stopMobFarm = stopMobFarm,
    
    -- Helpers
    isRockDestroyed = isRockDestroyed,
    isMobDead = isMobDead,
    isLowHealth = isLowHealth,
}

--[[
═══════════════════════════════════════════════════════════════
HƯỚNG DẪN SỬ DỤNG
═══════════════════════════════════════════════════════════════

-- 1. Load module
local FarmModule = loadstring(game:HttpGet("YOUR_URL"))()

-- 2. Cấu hình farm ore
FarmModule.Config.selectedRockTypes = {"Boulder", "Stone"}
FarmModule.Config.selectedOreTypes = {"Iron", "Gold", "Diamond"}
FarmModule.Config.scanDistance = 300
FarmModule.Config.tweenSpeed = 100

-- 3. Bật farm ore
FarmModule.startOreFarm()

-- 4. Tắt farm ore
FarmModule.stopOreFarm()

-- 5. Cấu hình farm mob
FarmModule.Config.selectedMobs = {"Zombie", "Skeleton", "Brute Zombie"}
FarmModule.Config.safeHealthPercent = 25

-- 6. Bật farm mob
FarmModule.startMobFarm()

-- 7. Tắt farm mob
FarmModule.stopMobFarm()

-- 8. Di chuyển thủ công
FarmModule.tweenToPosition(Vector3.new(100, 50, 200), 150)

═══════════════════════════════════════════════════════════════
]]

