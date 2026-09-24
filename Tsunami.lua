-- Tsunami.lua
-- Final English version

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local START_BELOW_PLAYER = 60
local RISE_SPEED = 35
local FLOOD_RADIUS = 5000
local RAINBOW_SPEED = 0.75

local oceanFolder = workspace
    :WaitForChild("Map")
    :WaitForChild("AlwaysHereTweenedObjects")
    :WaitForChild("Ocean")

local function findOceanTemplate()
    for _, object in ipairs(oceanFolder:GetDescendants()) do
        if object:IsA("BasePart") and object.Name == "Ocean" then
            return object
        end
    end
end

local template = findOceanTemplate()
if not template then
    error("Ocean Part not found")
end

local templateSize = template.Size
local templateRotation = template.CFrame.Rotation
local tileX = math.max(templateSize.X, 1)
local tileZ = math.max(templateSize.Z, 1)

local floodParts = {}
local enabled = false
local created = false
local rising = false
local currentSurfaceY = 0

local oldFlood = workspace:FindFirstChild("InfiniteFloodOcean")
if oldFlood then oldFlood:Destroy() end

local floodFolder = Instance.new("Folder")
floodFolder.Name = "InfiniteFloodOcean"
floodFolder.Parent = workspace

local function getRoot()
    local character = player.Character or player.CharacterAdded:Wait()
    return character:WaitForChild("HumanoidRootPart")
end

local function clearFlood()
    for _, data in ipairs(floodParts) do
        if data.part then data.part:Destroy() end
    end
    table.clear(floodParts)
    created = false
    rising = false
end

local function createFlood()
    if created then return end

    local root = getRoot()
    currentSurfaceY = root.Position.Y - START_BELOW_PLAYER

    local centerX = root.Position.X
    local centerZ = root.Position.Z
    local tilesX = math.max(1, math.ceil(FLOOD_RADIUS / tileX))
    local tilesZ = math.max(1, math.ceil(FLOOD_RADIUS / tileZ))

    for ix = -tilesX, tilesX do
        for iz = -tilesZ, tilesZ do
            local x = centerX + ix * tileX
            local z = centerZ + iz * tileZ
            local part = template:Clone()

            part.Name = "FloodOcean"
            part.Anchored = true
            part.CanCollide = false

            local centerY = currentSurfaceY - templateSize.Y / 2
            part.CFrame = CFrame.new(x, centerY, z) * templateRotation
            part.Parent = floodFolder

            table.insert(floodParts, {part = part, x = x, z = z})
        end
        task.wait()
    end

    created = true
end

local function setFloodHeight(surfaceY)
    local centerY = surfaceY - templateSize.Y / 2

    for _, data in ipairs(floodParts) do
        local part = data.part
        if part and part.Parent then
            part.CFrame = CFrame.new(data.x, centerY, data.z) * templateRotation
        end
    end
end

local oldGui = playerGui:FindFirstChild("TsunamiControlGUI")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "TsunamiControlGUI"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(230, 40)
panel.Position = UDim2.new(0.5, -115, 0, 15)
panel.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
panel.BorderSizePixel = 0
panel.ClipsDescendants = false
panel.Parent = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel

local rainbowStroke = Instance.new("UIStroke")
rainbowStroke.Thickness = 4
rainbowStroke.Transparency = 0
rainbowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
rainbowStroke.Color = Color3.fromRGB(255, 0, 0)
rainbowStroke.Parent = panel

local tsunamiButton = Instance.new("TextButton")
tsunamiButton.Size = UDim2.new(0.5, -3, 1, 0)
tsunamiButton.Position = UDim2.new(0, 0, 0, 0)
tsunamiButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
tsunamiButton.BorderSizePixel = 0
tsunamiButton.Text = "TSUNAMI: OFF"
tsunamiButton.TextColor3 = Color3.fromRGB(255, 255, 255)
tsunamiButton.Font = Enum.Font.GothamBold
tsunamiButton.TextSize = 12
tsunamiButton.Parent = panel

local tsunamiCorner = Instance.new("UICorner")
tsunamiCorner.CornerRadius = UDim.new(0, 9)
tsunamiCorner.Parent = tsunamiButton

local stopButton = Instance.new("TextButton")
stopButton.Size = UDim2.new(0.5, -3, 1, 0)
stopButton.Position = UDim2.new(0.5, 3, 0, 0)
stopButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
stopButton.BorderSizePixel = 0
stopButton.Text = "STOP"
stopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
stopButton.Font = Enum.Font.GothamBold
stopButton.TextSize = 13
stopButton.Parent = panel

local stopCorner = Instance.new("UICorner")
stopCorner.CornerRadius = UDim.new(0, 9)
stopCorner.Parent = stopButton

local divider = Instance.new("Frame")
divider.Size = UDim2.new(0, 6, 1, -6)
divider.Position = UDim2.new(0.5, -3, 0, 3)
divider.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
divider.BorderSizePixel = 0
divider.ZIndex = 10
divider.Parent = panel

local dividerCorner = Instance.new("UICorner")
dividerCorner.CornerRadius = UDim.new(1, 0)
dividerCorner.Parent = divider

local function updateTsunamiUI()
    if enabled then
        tsunamiButton.Text = "TSUNAMI: ON"
        tsunamiButton.BackgroundColor3 = Color3.fromRGB(35, 145, 55)
    else
        tsunamiButton.Text = "TSUNAMI: OFF"
        tsunamiButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    end
end

local flashNumber = 0

local function flashStopButton()
    flashNumber += 1
    local currentFlash = flashNumber
    stopButton.BackgroundColor3 = Color3.fromRGB(35, 145, 55)

    task.delay(0.25, function()
        if currentFlash ~= flashNumber then return end
        stopButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    end)
end

updateTsunamiUI()

tsunamiButton.MouseButton1Click:Connect(function()
    if enabled then
        enabled = false
        rising = false
        clearFlood()
        updateTsunamiUI()
        return
    end

    enabled = true
    updateTsunamiUI()

    if not created then
        tsunamiButton.Text = "LOADING..."
        createFlood()
    end

    rising = true
    updateTsunamiUI()
end)

stopButton.MouseButton1Click:Connect(function()
    if not enabled or not created then return end
    flashStopButton()
    rising = not rising
end)

local rainbowHue = 0

RunService.RenderStepped:Connect(function(deltaTime)
    rainbowHue = (rainbowHue + deltaTime * RAINBOW_SPEED) % 1

    local brightness = 0.85 + math.sin(time() * 7) * 0.15
    rainbowStroke.Color = Color3.fromHSV(rainbowHue, 1, brightness)

    if not enabled or not created then return end

    if rising then
        currentSurfaceY += RISE_SPEED * deltaTime
    end

    setFloodHeight(currentSurfaceY)
end)
