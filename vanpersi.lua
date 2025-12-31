-- ========================================
-- 🔧 NETWORK SETUP
-- ========================================
local Network = {}
do
    local GetEventHandler, GetFunctionHandler = nil, nil
    
    for _, object in next, getgc() do
        if type(object) == "function" and islclosure(object) and not isexecutorclosure(object) then
            local source = debug.info(object, "s")
            if source and string.find(source, "Modules.Network") then
                local name = debug.info(object, "n")
                local upvalues = getupvalues(object)
                if name == "GetEventHandler" and #upvalues >= 5 and typeof(upvalues[1]) == "table" then
                    GetEventHandler = object
                end
                if name == "GetFunctionHandler" and #upvalues >= 5 and typeof(upvalues[1]) == "table" then
                    GetFunctionHandler = object
                end
            end
        end
    end

    if not GetEventHandler or not GetFunctionHandler then
        game.Players.LocalPlayer:Kick("Script cần update. Liên hệ @amazonek trên Discord")
    end

    -- 🔍 IN RA TẤT CẢ CÁC REMOTES ĐỂ TÌM TÊN ĐÚNG
    print("\n🔍 DANH SÁCH REMOTES (FireServer):")
    for remoteName, remoteInfo in next, getupvalues(GetEventHandler)[1] do
        if remoteInfo.Remote then 
            remoteInfo.Remote.Name = remoteName 
            print("   📤 " .. remoteName)
        end
    end
    
    print("\n🔍 DANH SÁCH REMOTES (InvokeServer):")
    for remoteName, remoteInfo in next, getupvalues(GetFunctionHandler)[1] do
        if remoteInfo.Remote then 
            remoteInfo.Remote.Name = remoteName
            print("   📥 " .. remoteName)
        end
    end

    local RemoteFolder = game:GetService("ReplicatedStorage"):WaitForChild(game.JobId)

    function Network:FireServer(eventName, ...)
        local remote = RemoteFolder:FindFirstChild(eventName, true)
        if remote then
            remote:FireServer(...)
        else
            warn("❌ Remote not found: " .. eventName)
        end
    end

    function Network:InvokeServer(eventName, ...)
        local remote = RemoteFolder:FindFirstChild(eventName, true)
        if remote then
            return table.unpack(table.pack(remote:InvokeServer(...)), 2)
        else
            warn("❌ Remote not found: " .. eventName)
            return nil
        end
    end
end

-- ========================================
-- 🥚 EGG DATA
-- ========================================
local egg = require(game:GetService("ReplicatedStorage").Game.Eggs)
local EggsList = {}

for eggName, eggData in pairs(egg) do
    if type(eggData) == "table" and eggData.Price and not eggData.RobuxEgg then
        table.insert(EggsList, {
            Name = eggName,
            Price = eggData.Price,
            Index = eggData.Index or 999,
        })
    end
end

table.sort(EggsList, function(a, b)
    return a.Price < b.Price
end)

print("\n🥚 DANH SÁCH EGGS:")
for i, eggData in ipairs(EggsList) do
    print(string.format("#%d | %-20s | 💰 %s", i, eggData.Name, tostring(eggData.Price)))
end

-- ========================================
-- ⚙️ CẤU HÌNH AUTO EGG
-- ========================================
local CONFIG = {
    AutoTap = true,
    AutoEgg = true,
    EggName = "Basic",  -- Tên egg muốn mở
    EggAmount = 1,      -- Số lượng (1 = single, 3 = triple)
    DelayBetweenOpen = 3 -- Delay giữa mỗi lần mở (giây)
}

-- ========================================
-- 🔍 TÌM TÊN REMOTE ĐÚNG VÀ KIỂM TRA TYPE
-- ========================================
local possibleEggRemotes = {
    "OpenEgg",
    "PurchaseEgg",
    "HatchEgg",
    "BuyEgg",
    "Open",
    "Purchase",
    "Hatch"
}

local foundEggRemote = nil
local isRemoteFunction = false
local RemoteFolder = game:GetService("ReplicatedStorage"):WaitForChild(game.JobId)

for _, remoteName in ipairs(possibleEggRemotes) do
    local remote = RemoteFolder:FindFirstChild(remoteName, true)
    if remote then
        foundEggRemote = remoteName
        isRemoteFunction = remote:IsA("RemoteFunction")
        print(string.format("✅ Tìm thấy Egg Remote: %s (%s)", 
            remoteName, 
            isRemoteFunction and "RemoteFunction" or "RemoteEvent"
        ))
        break
    end
end

if not foundEggRemote then
    warn("❌ KHÔNG TÌM THẤY EGG REMOTE! Hãy check danh sách remotes ở trên.")
    warn("💡 Thử dùng remote có tên chứa 'egg', 'open', 'hatch', 'purchase'")
end

-- ========================================
-- 🚀 AUTO TAP
-- ========================================
if CONFIG.AutoTap then
    task.spawn(function()
        print("✅ Auto Tap: ON")
        while CONFIG.AutoTap do
            pcall(function()
                Network:FireServer("Tap", true, nil, false)
            end)
            task.wait(0.01)
        end
    end)
end

-- ========================================
-- 🥚 AUTO OPEN EGG (AUTO DETECT TYPE)
-- ========================================
if CONFIG.AutoEgg and foundEggRemote then
    task.spawn(function()
        print(string.format("✅ Auto Egg: ON | Egg: %s | Amount: %d | Type: %s", 
            CONFIG.EggName, 
            CONFIG.EggAmount,
            isRemoteFunction and "RemoteFunction (InvokeServer)" or "RemoteEvent (FireServer)"
        ))
        task.wait(2) -- Đợi 2s cho game load
        
        while CONFIG.AutoEgg do
            local success, result = pcall(function()
                if isRemoteFunction then
                    -- RemoteFunction → InvokeServer
                    return Network:InvokeServer(foundEggRemote, CONFIG.EggName, CONFIG.EggAmount, {})
                else
                    -- RemoteEvent → FireServer
                    Network:FireServer(foundEggRemote, CONFIG.EggName, CONFIG.EggAmount, {})
                    return nil
                end
            end)
            
            if success then
                if isRemoteFunction and result then
                    print("✅ Opened egg:", result)
                else
                    print("📤 Sent request:", foundEggRemote)
                end
            else
                warn("❌ Error:", result)
                
                -- Thử format khác (không có {})
                pcall(function()
                    if isRemoteFunction then
                        Network:InvokeServer(foundEggRemote, CONFIG.EggName, CONFIG.EggAmount)
                    else
                        Network:FireServer(foundEggRemote, CONFIG.EggName, CONFIG.EggAmount)
                    end
                end)
            end
            
            task.wait(CONFIG.DelayBetweenOpen)
        end
    end)
else
    print("❌ Auto Egg: OFF (Remote not found)")
end

print("\n✨ SCRIPT LOADED! Đang chạy...")
print("📋 Nếu không hoạt động, check danh sách remotes ở trên và đổi CONFIG.EggName")
