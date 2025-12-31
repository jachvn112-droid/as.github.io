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
            end -- ✅ end if source
        end -- ✅ end if type
    end -- ✅ end for getgc
    
    if not GetEventHandler or not GetFunctionHandler then
        game.Players.LocalPlayer:Kick("Script cần update. Liên hệ @amazonek trên Discord")
    end -- ✅ end if check
    
    -- Đổi tên remote về tên thật
    for remoteName, remoteInfo in next, getupvalues(GetEventHandler)[1] do
        if remoteInfo.Remote then 
            remoteInfo.Remote.Name = remoteName 
        end
    end -- ✅ end for
    
    for remoteName, remoteInfo in next, getupvalues(GetFunctionHandler)[1] do
        if remoteInfo.Remote then 
            remoteInfo.Remote.Name = remoteName 
        end
    end -- ✅ end for
    
    local RemoteFolder = game:GetService("ReplicatedStorage"):WaitForChild(game.JobId)
    
    function Network:FireServer(eventName, ...)
        RemoteFolder:FindFirstChild(eventName, true):FireServer(...)
    end -- ✅ end function
    
    function Network:InvokeServer(eventName, ...)
        return table.unpack(table.pack(RemoteFolder:FindFirstChild(eventName, true):InvokeServer(...)), 2)
    end -- ✅ end function
end -- ✅ end do

-- 🥚 Egg Setup
local egg = require(game:GetService("ReplicatedStorage").Game.Eggs)
local EggsList = {}

for eggName, eggData in pairs(egg) do
    if type(eggData) == "table" and eggData.Price then
        if eggData.RobuxEgg == true then
            continue
        end
        
        table.insert(EggsList, {
            Name = eggName,
            Price = eggData.Price,
            Index = eggData.Index or 999,
            PetCount = eggData.Pets and #eggData.Pets or 0
        })
    end -- ✅ end if type
end -- ✅ end for eggs

table.sort(EggsList, function(a, b)
    return a.Price < b.Price
end)

-- ⚠️ LỖI NGHIÊM TRỌNG: THIẾU task.wait()
-- ❌ Code cũ sẽ CRASH game vì loop vô hạn không delay!
while true do
    local success, result = pcall(function()
        Network:FireServer("OpenEgg", "BasicEgg", 3, {})
    end) -- ✅ end function pcall
    
    if not success then
        warn("❌ Lỗi mở egg:", result)
    else
        print("✅ Đã gửi request mở egg")
    end
    
    -- ⚠️ CRITICAL: PHẢI CÓ task.wait() nếu không game sẽ crash!
    task.wait(3) -- ✅ Delay 3 giây giữa mỗi lần mở
end -- ✅ end while
