-- Step 1: Lấy tất cả fishing rod templates và stats
local function getRodStats()
    local rodStats = {}
    
    for _, item in pairs(game:GetService("ReplicatedStorage").Items:GetChildren()) do
        local data = require(item)
        
        if data.Data and data.Data.Type == "Fishing Rods" then
            rodStats[data.Data.Name] = {
                tier = data.Data.Tier or 0,
                clickPower = data.ClickPower or 0,
                resilience = data.Resilience or 0,
                maxWeight = data.MaxWeight or 0,
                baseLuck = data.RollData and data.RollData.BaseLuck or 0,
                id = data.Data.Id
            }
        end
    end
    
    return rodStats
end

-- Step 2: Tìm player inventory (chứa UUIDs)
local function findPlayerInventory()
    local player = game.Players.LocalPlayer
    
    -- Thử các nơi thường có
    local possiblePaths = {
        player:WaitForChild("PlayerData"),
        player:WaitForChild("Data"),
        player:WaitForChild("Inventory"),
        game.ReplicatedStorage:FindFirstChild("PlayerData"),
    }
    
    for _, path in pairs(possiblePaths) do
        if path then
            for _, child in pairs(path:GetDescendants()) do
                if child.Name:lower():find("inventory") or 
                   child.Name:lower():find("items") then
                    return child
                end
            end
        end
    end
end

-- Step 3: Lấy rods từ inventory với UUIDs
local function getInventoryRods()
    local rods = {}
    
    -- Scan qua garbage collector tìm inventory data
    for _, obj in pairs(getgc(true)) do
        if typeof(obj) == "table" then
            -- Tìm tables có structure của inventory items
            if obj.ItemId and obj.Uuid and obj.Type == "Fishing Rods" then
                table.insert(rods, {
                    uuid = obj.Uuid,
                    itemId = obj.ItemId,
                    name = obj.Name
                })
            end
        end
    end
    
    return rods
end

-- Step 4: Equip best rod
local function equipBestRod()
    local rodStats = getRodStats()
    local inventoryRods = getInventoryRods()
    
    if #inventoryRods == 0 then
        warn("No rods found in inventory!")
        return
    end
    
    -- Sort inventory rods by stats
    table.sort(inventoryRods, function(a, b)
        local statsA = rodStats[a.name]
        local statsB = rodStats[b.name]
        
        if statsA and statsB then
            -- Compare by tier first
            if statsA.tier ~= statsB.tier then
                return statsA.tier > statsB.tier
            end
            -- Then by click power
            return statsA.clickPower > statsB.clickPower
        end
        
        return false
    end)
    
    -- Equip best rod
    local bestRod = inventoryRods[1]
    print("Equipping best rod:", bestRod.name)
    print("UUID:", bestRod.uuid)
    
    local args = {bestRod.uuid, "Fishing Rods"}
    game:GetService("ReplicatedStorage"):WaitForChild("Packages")
        :WaitForChild("_Index"):WaitForChild("sleitnick_net@0.2.0")
        :WaitForChild("net"):WaitForChild("RE/EquipItem")
        :FireServer(unpack(args))
end

equipBestRod()
```

**Method nhanh hơn: Dùng Dex Explorer**

1. Mở Dex Explorer
2. Tìm `Players.LocalPlayer` 
3. Tìm folder có tên như `PlayerData`, `Data`, hoặc `Inventory`
4. Trong đó sẽ có list items với structure:
```
   {
       Uuid = "b793a027-1a7e-4938-8da0-6259194a5ea8",
       ItemId = 85,
       Name = "Grass Rod",
       Type = "Fishing Rods"
   }
