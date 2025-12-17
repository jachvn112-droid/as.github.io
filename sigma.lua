-- Step 1: Lấy stats của tất cả rods từ ReplicatedStorage
local function getRodStats()
    local stats = {}
    
    for _, item in pairs(game:GetService("ReplicatedStorage").Items:GetChildren()) do
        local success, data = pcall(function() return require(item) end)
        
        if success and data.Data and data.Data.Type == "Fishing Rods" then
            stats[data.Data.Name] = {
                tier = data.Data.Tier or 0,
                clickPower = data.ClickPower or 0,
                resilience = data.Resilience or 0,
                maxWeight = data.MaxWeight or 0,
                baseLuck = data.RollData and data.RollData.BaseLuck or 0
            }
        end
    end
    
    return stats
end

-- Step 2: Scan inventory UI để lấy rod names + UUIDs
local function scanInventoryRods()
    local player = game.Players.LocalPlayer
    local rods = {}
    
    for _, gui in pairs(player.PlayerGui:GetDescendants()) do
        -- Tìm ItemName labels
        if gui.Name == "ItemName" and gui:IsA("TextLabel") then
            local itemName = gui.Text
            
            -- Check nếu là rod
            if itemName:lower():find("rod") then
                local tile = gui.Parent.Parent -- Inner → Tile
                
                -- Thử lấy UUID từ Tile.Name
                if tile.Name:match("%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x") then
                    table.insert(rods, {
                        name = itemName,
                        uuid = tile.Name
                    })
                    print("Found:", itemName, "UUID:", tile.Name)
                end
            end
        end
    end
    
    return rods
end

-- Step 3: Tìm và equip rod mạnh nhất
local function equipBestRod()
    print("===== FINDING BEST ROD =====")
    
    local rodStats = getRodStats()
    local inventoryRods = scanInventoryRods()
    
    if #inventoryRods == 0 then
        warn("No rods found in inventory! Make sure inventory is open.")
        return
    end
    
    -- Sort rods theo stats (Tier > ClickPower > MaxWeight)
    table.sort(inventoryRods, function(a, b)
        local statsA = rodStats[a.name]
        local statsB = rodStats[b.name]
        
        if not statsA then return false end
        if not statsB then return true end
        
        -- Compare tier trước
        if statsA.tier ~= statsB.tier then
            return statsA.tier > statsB.tier
        end
        
        -- Nếu tier bằng nhau, compare click power
        if statsA.clickPower ~= statsB.clickPower then
            return statsA.clickPower > statsB.clickPower
        end
        
        -- Cuối cùng compare max weight
        return statsA.maxWeight > statsB.maxWeight
    end)
    
    -- Equip best rod
    local bestRod = inventoryRods[1]
    local stats = rodStats[bestRod.name]
    
    print("\n===== EQUIPPING BEST ROD =====")
    print("Name:", bestRod.name)
    print("Tier:", stats.tier)
    print("Click Power:", stats.clickPower)
    print("Max Weight:", stats.maxWeight)
    print("UUID:", bestRod.uuid)
    
    local args = {bestRod.uuid, "Fishing Rods"}
    game:GetService("ReplicatedStorage"):WaitForChild("Packages")
        :WaitForChild("_Index"):WaitForChild("sleitnick_net@0.2.0")
        :WaitForChild("net"):WaitForChild("RE/EquipItem")
        :FireServer(unpack(args))
    
    print("Done!")
end

-- Chạy
equipBestRod()
-- Backup method: Dùng getgc để tìm inventory data
local function findRodsInMemory()
    local rods = {}
    
    for _, obj in pairs(getgc(true)) do
        if typeof(obj) == "table" then
            -- Tìm tables có inventory item structure
            if obj.Uuid and obj.ItemId and obj.Type == "Fishing Rods" then
                -- Match với ReplicatedStorage để lấy tên
                local itemData = game.ReplicatedStorage.Items:GetChildren()
                for _, item in pairs(itemData) do
                    local success, data = pcall(function() return require(item) end)
                    if success and data.Data and data.Data.Id == obj.ItemId then
                        table.insert(rods, {
                            name = data.Data.Name,
                            uuid = obj.Uuid,
                            tier = data.Data.Tier or 0,
                            clickPower = data.ClickPower or 0
                        })
                        break
                    end
                end
            end
        end
    end
    
    return rods
end

local function equipBestRodMemory()
    print("===== SCANNING MEMORY =====")
    
    local rods = findRodsInMemory()
    
    if #rods == 0 then
        warn("No rods found!")
        return
    end
    
    -- Sort
    table.sort(rods, function(a, b)
        if a.tier ~= b.tier then
            return a.tier > b.tier
        end
        return a.clickPower > b.clickPower
    end)
    
    -- Equip
    local bestRod = rods[1]
    print("Best rod:", bestRod.name, "Tier:", bestRod.tier)
    
    local args = {bestRod.uuid, "Fishing Rods"}
    game:GetService("ReplicatedStorage"):WaitForChild("Packages")
        :WaitForChild("_Index"):WaitForChild("sleitnick_net@0.2.0")
        :WaitForChild("net"):WaitForChild("RE/EquipItem")
        :FireServer(unpack(args))
end

equipBestRodMemory()
local function autoEquipBest()
    print("Method 1: Scanning UI...")
    local rods = scanInventoryRods()
    
    if #rods == 0 then
        print("Method 2: Scanning memory...")
        rods = findRodsInMemory()
    end
    
    if #rods > 0 then
        -- Sort and equip logic here
        equipBestRod()
    else
        warn("Could not find any rods! Try opening inventory first.")
    end
end

autoEquipBest()
