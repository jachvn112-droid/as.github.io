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

    -- Đổi tên remote về tên thật
    for remoteName, remoteInfo in next, getupvalues(GetEventHandler)[1] do
        if remoteInfo.Remote then remoteInfo.Remote.Name = remoteName end
    end
    for remoteName, remoteInfo in next, getupvalues(GetFunctionHandler)[1] do
        if remoteInfo.Remote then remoteInfo.Remote.Name = remoteName end
    end

    local RemoteFolder = game:GetService("ReplicatedStorage"):WaitForChild(game.JobId)

    function Network:FireServer(eventName, ...)
        RemoteFolder:FindFirstChild(eventName, true):FireServer(...)
    end

    function Network:InvokeServer(eventName, ...)
        return table.unpack(table.pack(RemoteFolder:FindFirstChild(eventName, true):InvokeServer(...)), 2)
    end
end

-- Auto Tap

local egg = require(game:GetService("ReplicatedStorage").Game.Eggs)
local EggsList = {}
local CONFIG = {
    EggName = "Basic",     -- Tên egg cần mở
    Amount = 1,            -- Số lượng (1, 3, 8)
    Delay = 3,             -- Delay giữa mỗi lần mở (giây)
    AutoTap = true,        -- Bật auto tap
}
-- 📦 Chuyển từ dictionary sang array để có thể sort
for eggName, eggData in pairs(egg) do
    if type(eggData) == "table" and eggData.Price then
        -- ❌ Skip Robux eggs
        if eggData.RobuxEgg == true then
            continue
        end
        
        table.insert(EggsList, {
            Name = eggName,
            Price = eggData.Price,
            Index = eggData.Index or 999,
            PetCount = eggData.Pets and #eggData.Pets or 0
        })
    end
end

-- 🔢 Sort theo giá (thấp -> cao)
table.sort(EggsList, function(a, b)
    return a.Price < b.Price
end)
while true do
    local success, result = pcall(function() 
        Network:FireServer("OpenEgg", "BasicEgg", 3, {})
    end)
    if not success then
        warn("Lỗi khi mở egg: " .. tostring(result)) else
        print("Đã mở egg thành công." .. tostring(result))
    end

    task.wait(CONFIG.Delay or 3)
end
