-- Step 1: Tìm inventory system
local function findInventory()
    -- Thử các nơi thường chứa inventory
    local player = game.Players.LocalPlayer
    
    -- Check PlayerGui
    for _, gui in pairs(player.PlayerGui:GetDescendants()) do
        if gui.Name:lower():find("inventory") or 
           gui.Name:lower():find("backpack") then
            return gui
        end
    end
    
    -- Check ReplicatedStorage
    for _, obj in pairs(game.ReplicatedStorage:GetDescendants()) do
        if obj.Name:lower():find("inventory") then
            return obj
        end
    end
end

-- Step 2: Lấy tất cả fishing rods
local function getAllFishingRods()
    local rods = {}
    
    -- Method 1: Scan qua tất cả objects có thể
    for _, obj in pairs(getgc(true)) do
        if typeof(obj) == "table" then
            -- Tìm tables có rod data
            if obj.Name and obj.ItemId and obj.Category == "Fishing Rods" then
                table.insert(rods, {
                    id = obj.ItemId,
                    name = obj.Name,
                    rarity = obj.Rarity or 0
                })
            end
        end
    end
    
    return rods
end

-- Step 3: Sort và equip best rod
local function equipBestRod()
    local rods = getAllFishingRods()
    
    -- Sort by rarity (cao nhất trước)
    table.sort(rods, function(a, b)
        return a.rarity > b.rarity
    end)
    
    -- Equip rod đầu tiên (best)
    if #rods > 0 then
        local bestRod = rods[1]
        print("Equipping:", bestRod.name, "ID:", bestRod.id)
        
        local args = {bestRod.id, "Fishing Rods"}
        game:GetService("ReplicatedStorage"):WaitForChild("Packages")
            :WaitForChild("_Index"):WaitForChild("sleitnick_net@0.2.0")
            :WaitForChild("net"):WaitForChild("RE/EquipItem")
            :FireServer(unpack(args))
    end
end
