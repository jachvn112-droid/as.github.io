-- POSITION CAPTURE TOOL - MOBILE VERSION
local UserInputService = game:GetService("UserInputService")
local player = game.Players.LocalPlayer

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🎯 POSITION CAPTURE TOOL (MOBILE)")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("Tap CAPTURE button, then tap positions")
print("")

local capturing = false
local capturedPositions = {}

-- Create UI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PositionCapture"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = player.PlayerGui

-- Capture Button
local CaptureButton = Instance.new("TextButton")
CaptureButton.Size = UDim2.new(0, 150, 0, 60)
CaptureButton.Position = UDim2.new(0.5, -75, 0, 20)
CaptureButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
CaptureButton.Text = "START CAPTURE"
CaptureButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CaptureButton.TextSize = 20
CaptureButton.Font = Enum.Font.SourceSansBold
CaptureButton.ZIndex = 100
CaptureButton.Parent = ScreenGui

-- Stop Button
local StopButton = Instance.new("TextButton")
StopButton.Size = UDim2.new(0, 150, 0, 60)
StopButton.Position = UDim2.new(0.5, -75, 0, 90)
StopButton.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
StopButton.Text = "STOP & SHOW"
StopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
StopButton.TextSize = 20
StopButton.Font = Enum.Font.SourceSansBold
StopButton.Visible = false
StopButton.ZIndex = 100
StopButton.Parent = ScreenGui

-- Info Label
local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(0, 300, 0, 120)
InfoLabel.Position = UDim2.new(0.5, -150, 0, 160)
InfoLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
InfoLabel.BackgroundTransparency = 0.3
InfoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
InfoLabel.TextSize = 18
InfoLabel.Font = Enum.Font.SourceSansBold
InfoLabel.TextWrapped = true
InfoLabel.ZIndex = 100
InfoLabel.Parent = ScreenGui

-- Create marker function
local function createMarker(position, index)
    local marker = Instance.new("Frame")
    marker.Size = UDim2.new(0, 30, 0, 30)
    marker.Position = UDim2.new(0, position.X - 15, 0, position.Y - 15)
    marker.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    marker.BorderSizePixel = 3
    marker.BorderColor3 = Color3.fromRGB(255, 255, 255)
    marker.ZIndex = 99
    marker.Parent = ScreenGui
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = tostring(index)
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 20
    label.Font = Enum.Font.SourceSansBold
    label.ZIndex = 99
    label.Parent = marker
    
    return marker
end

-- Update info display
local function updateInfo()
    local text = "📍 Captured: " .. #capturedPositions .. "/3\n\n"
    
    if #capturedPositions == 0 then
        text = text .. "Next: Tap INVENTORY button"
    elseif #capturedPositions == 1 then
        text = text .. "Next: Tap ROD SLOT"
    elseif #capturedPositions == 2 then
        text = text .. "Next: Tap EXIT button"
    else
        text = text .. "✅ All positions captured!\nTap STOP to finish"
    end
    
    InfoLabel.Text = text
end

updateInfo()

-- Start capture button
CaptureButton.MouseButton1Click:Connect(function()
    capturing = true
    CaptureButton.Visible = false
    StopButton.Visible = true
    InfoLabel.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
    print("✅ Capture mode ACTIVE - Tap positions now!")
end)

-- Stop button
StopButton.MouseButton1Click:Connect(function()
    capturing = false
    StopButton.Visible = false
    
    print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("📊 CAPTURED POSITIONS:")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    for i, pos in ipairs(capturedPositions) do
        local name = ""
        if i == 1 then name = "(OPEN INVENTORY)"
        elseif i == 2 then name = "(ROD SLOT)"
        elseif i == 3 then name = "(EXIT BUTTON)" end
        
        print(string.format("%d. X=%d, Y=%d %s", i, pos.X, pos.Y, name))
    end
    
    print("\n📋 COPY THIS CODE:")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    if #capturedPositions >= 3 then
        local code = string.format([[
local positions = {
    openInventory = Vector2.new(%d, %d),
    rodSlot = Vector2.new(%d, %d),
    exitButton = Vector2.new(%d, %d),
}]], 
            capturedPositions[1].X, capturedPositions[1].Y,
            capturedPositions[2].X, capturedPositions[2].Y,
            capturedPositions[3].X, capturedPositions[3].Y
        )
        print(code)
        
        -- Show on screen
        InfoLabel.Text = "✅ DONE!\nCheck console (F9)\nfor code to copy"
        InfoLabel.TextSize = 16
        InfoLabel.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    else
        print("⚠️ Need 3 positions! Only got " .. #capturedPositions)
        InfoLabel.Text = "❌ Need 3 positions!\nOnly captured: " .. #capturedPositions
        InfoLabel.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
    end
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end)

-- Capture touch input
UserInputService.TouchTap:Connect(function(touchPositions, gameProcessed)
    if not capturing then return end
    if #capturedPositions >= 3 then return end
    
    -- Get first touch position
    local position = touchPositions[1]
    local x = math.floor(position.X)
    local y = math.floor(position.Y)
    
    -- Check if tapped on UI buttons (skip those)
    local isButton = false
    local mousePos = Vector2.new(x, y)
    
    if CaptureButton.Visible then
        local btnPos = CaptureButton.AbsolutePosition
        local btnSize = CaptureButton.AbsoluteSize
        if mousePos.X >= btnPos.X and mousePos.X <= btnPos.X + btnSize.X and
           mousePos.Y >= btnPos.Y and mousePos.Y <= btnPos.Y + btnSize.Y then
            isButton = true
        end
    end
    
    if StopButton.Visible then
        local btnPos = StopButton.AbsolutePosition
        local btnSize = StopButton.AbsoluteSize
        if mousePos.X >= btnPos.X and mousePos.X <= btnPos.X + btnSize.X and
           mousePos.Y >= btnPos.Y and mousePos.Y <= btnPos.Y + btnSize.Y then
            isButton = true
        end
    end
    
    if isButton then return end
    
    -- Capture position
    table.insert(capturedPositions, {X = x, Y = y})
    
    local name = ""
    if #capturedPositions == 1 then name = "(INVENTORY)"
    elseif #capturedPositions == 2 then name = "(ROD SLOT)"
    elseif #capturedPositions == 3 then name = "(EXIT)" end
    
    print(string.format("✓ #%d: X=%d, Y=%d %s", #capturedPositions, x, y, name))
    
    createMarker(Vector2.new(x, y), #capturedPositions)
    updateInfo()
end)
