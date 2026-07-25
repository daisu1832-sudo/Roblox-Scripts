local Players = game:GetService("Players") 
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer 
local mouse = player:GetMouse()

local gui = Instance.new("ScreenGui") 
gui.Name = "RingGui" 
gui.ResetOnSpawn = false 
gui.Parent = player:WaitForChild("PlayerGui")

-- 背景フレーム 
local frame = Instance.new("Frame") 
frame.Size = UDim2.new(0, 150, 0, 70) 
frame.Position = UDim2.new(0, 15, 0, 15) 
frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35) 
frame.BorderSizePixel = 0 
frame.Parent = gui

local frameCorner = Instance.new("UICorner") 
frameCorner.CornerRadius = UDim.new(0, 16) 
frameCorner.Parent = frame

-- ON/OFFボタン 
local button = Instance.new("TextButton") 
button.Size = UDim2.new(0, 120, 0, 40) 
button.Position = UDim2.new(0.5, -60, 0.5, -20) 
button.BackgroundColor3 = Color3.fromRGB(220, 60, 60) 
button.TextColor3 = Color3.new(1, 1, 1) 
button.Text = "OFF" 
button.TextScaled = true 
button.BorderSizePixel = 0 
button.Parent = frame

local buttonCorner = Instance.new("UICorner") 
buttonCorner.CornerRadius = UDim.new(0, 12) 
buttonCorner.Parent = button

local enabled = false 
local parts = {} 
local angle = 0

button.MouseButton1Click:Connect(function() 
enabled = not enabled

if enabled then
    button.Text = "ON"
    button.BackgroundColor3 = Color3.fromRGB(60, 220, 60)
else
    button.Text = "OFF"
    button.BackgroundColor3 = Color3.fromRGB(220, 60, 60)

    for _, part in ipairs(parts) do
        if part and part.Parent then
            part.Anchored = false
        end
    end

    table.clear(parts)
end
end)

mouse.Button1Down:Connect(function() 
if not enabled then return end

local target = mouse.Target

if target and target:IsA("BasePart") then
    if not table.find(parts, target) then
        target.Anchored = true
        table.insert(parts, target)
    end
end
end)

RunService.RenderStepped:Connect(function(dt) 
if not enabled then return end

local character = player.Character
if not character then return end

local head = character:FindFirstChild("Head")
if not head then return end

angle += dt * 2

local radius = 1000
local height = 50

local count = #parts
if count == 0 then return end

for i, part in ipairs(parts) do
    if part and part.Parent then
        local theta = angle + ((i - 1) / count) * math.pi * 2

        local position = head.Position + Vector3.new(
            math.cos(theta) * radius,
            height,
            math.sin(theta) * radius
        )

        part.CFrame = CFrame.new(position)
    end
end
end)