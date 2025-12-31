-- ========================================
-- 🛡️ SCRIPT CHỐNG CRASH VỚI DEBUG
-- ========================================

print("🚀 Bắt đầu load script...")

-- ========================================
-- 📍 BƯỚC 1: SETUP NETWORK (CÓ ERROR HANDLING)
-- ========================================
local Network = {}
local networkSuccess = pcall(function()
    print("📡 Đang tìm Network handlers...")
    
    local GetEventHandler, GetFunctionHandler = nil, nil
    local foundCount = 0
    
    for _, object in next, getgc() do
        if type(object) == "function" and islclosure(object) and not isexecutorclosure(object) then
            local success, source = pcall(function()
                return debug.info(object, "s")
            end)
            
            if success and source and string.find(source, "Modules.Network") then
                local name = debug.info(object, "n")
                local upvalues = getupvalues(object)
                
                if name == "GetEventHandler" and #upvalues >= 5 and typeof(upvalues[1]) == "table" then
                    GetEventHandler = object
                    foundCount = foundCount + 1
                    print("✅ Tìm thấy GetEventHandler")
                end
                
                if name == "GetFunctionHandler" and #upvalues >= 5 and typeof(upvalues[1]) == "table" then
                    GetFunctionHandler = object
                    foundCount = foundCount + 1
                    print("✅ Tìm thấy GetFunctionHandler")
                end
            end
        end
    end
    
    if not GetEventHandler or not GetFunctionHandler then
        error("❌ Không tìm thấy Network handlers! Found: " .. foundCount)
    end
    
    print("🔧 Đang đổi tên remotes...")
    
    -- Đổi tên remote về tên thật (có error handling)
    pcall(function()
        for remoteName, remoteInfo in next, getupvalues(GetEventHandler)[1] do
            if remoteInfo.Remote then 
                remoteInfo.Remote.Name = remoteName 
            end
        end
    end)
    
    pcall(function()
        for remoteName, remoteInfo in next, getupvalues(GetFunctionHandler)[1] do
            if remoteInfo.Remote then 
                remoteInfo.Remote.Name = remoteName 
            end
        end
    end)
    
    print("📂 Đang tìm RemoteFolder...")
    local RemoteFolder = game:GetService("ReplicatedStorage"):WaitForChild(game.JobId, 10)
    
    if not RemoteFolder then
        error("❌ Không tìm thấy RemoteFolder!")
    end
    
    print("✅ RemoteFolder: " .. RemoteFolder:GetFullName())
    
    function Network:FireServer(eventName, ...)
        local remote = RemoteFolder:FindFirstChild(eventName, true)
        if remote then
            remote:FireServer(...)
            return true
        else
            warn("⚠️ Remote không tồn tại:", eventName)
            return false
        end
    end
    
    function Network:InvokeServer(eventName, ...)
        local remote = RemoteFolder:FindFirstChild(eventName, true)
        if remote then
            return table.unpack(table.pack(remote:InvokeServer(...)), 2)
        else
            warn("⚠️ Remote không tồn tại:", eventName)
            return nil
        end
    end
end)

if not networkSuccess then
    warn("❌ NETWORK SETUP FAILED!")
    warn("💡 Script sẽ tiếp tục nhưng Network không hoạt động")
else
    print("✅ Network setup thành công!")
end

-- ========================================
-- 📍 BƯỚC 2: LOAD EGG DATA (CÓ ERROR HANDLING)
-- ========================================
local EggsList = {}
local eggSuccess = pcall(function()
    print("🥚 Đang load Egg data...")
    
    local egg = require(game:GetService("ReplicatedStorage").Game.Eggs)
    
    for eggName, eggData in pairs(egg) do
        if type(eggData) == "table" and eggData.Price then
            if eggData.RobuxEgg ~= true then
                table.insert(EggsList, {
                    Name = eggName,
                    Price = eggData.Price,
                    Index = eggData.Index or 999,
                })
            end
        end
    end
    
    table.sort(EggsList, function(a, b)
        return a.Price < b.Price
    end)
    
    print("✅ Loaded " .. #EggsList .. " eggs")
    
    -- In ra 5 eggs đầu tiên
    for i = 1, math.min(5, #EggsList) do
        print(string.format("   %d. %s - %s", i, EggsList[i].Name, tostring(EggsList[i].Price)))
    end
end)

if not eggSuccess then
    warn("❌ EGG DATA LOAD FAILED!")
    warn("💡 Có thể path đến Eggs module sai")
end

-- ========================================
-- 📍 BƯỚC 3: AUTO OPEN EGG (AN TOÀN)
-- ========================================
print("\n" .. string.rep("=", 50))
print("🎮 SCRIPT ĐÃ LOAD XONG!")
print(string.rep("=", 50))

if not networkSuccess then
    warn("⚠️ Network không hoạt động - Script sẽ không chạy auto")
    return
end

-- CẤU HÌNH
local CONFIG = {
    EggName = "Basic",     -- Tên egg cần mở
    Amount = 1,            -- Số lượng (1, 3, 8)
    Delay = 3,             -- Delay giữa mỗi lần mở (giây)
    AutoTap = true,        -- Bật auto tap
}

print("\n⚙️ CẤU HÌNH:")
print("   Egg:", CONFIG.EggName)
print("   Amount:", CONFIG.Amount)
print("   Delay:", CONFIG.Delay, "giây")
print("   Auto Tap:", CONFIG.AutoTap)

-- AUTO TAP
if CONFIG.AutoTap then
    task.spawn(function()
        print("✅ Auto Tap: ON")
        while true do
            pcall(function()
                Network:FireServer("Tap", true, nil, false)
            end)
            task.wait(0.01)
        end
    end)
end

-- AUTO OPEN EGG
task.wait(2) -- Đợi game load

print("\n🥚 Bắt đầu Auto Open Egg...")

local openCount = 0
local errorCount = 0

while true do
    local success, result = pcall(function()
        -- Thử nhiều format khác nhau
        local formats = {
            function() Network:FireServer("OpenEgg", CONFIG.EggName, CONFIG.Amount, {}) end,
            function() Network:InvokeServer("OpenEgg", CONFIG.EggName, CONFIG.Amount, {}) end,
            function() Network:FireServer("PurchaseEgg", CONFIG.EggName, CONFIG.Amount) end,
            function() Network:InvokeServer("PurchaseEgg", CONFIG.EggName, CONFIG.Amount) end,
        }
        
        for i, format in ipairs(formats) do
            local ok, res = pcall(format)
            if ok then
                openCount = openCount + 1
                print(string.format("✅ #%d | Đã gửi request (format %d)", openCount, i))
                return true
            end
        end
        
        error("Tất cả formats đều thất bại")
    end)
    
    if not success then
        errorCount = errorCount + 1
        warn(string.format("❌ Lỗi #%d:", errorCount), result)
        
        if errorCount >= 5 then
            warn("⚠️ Quá nhiều lỗi! Dừng script.")
            warn("💡 Kiểm tra lại tên Egg hoặc remote name")
            break
        end
    end
    
    task.wait(CONFIG.Delay)
end

print("\n🛑 Script đã dừng")
