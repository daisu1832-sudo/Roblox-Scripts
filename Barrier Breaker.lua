-- Barrier Compact V16 - fixed width on minimize and restore
-- Centered minus / plus minimize button

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

for _, oldName in ipairs({"BarrierCompactV5", "BarrierCompactV6Fixed", "BarrierCompactV7Fixed", "BarrierCompactV8Fixed", "BarrierCompactV9Fixed", "BarrierCompactV10Fixed", "BarrierCompactV11Fixed", "BarrierCompactV13Fixed", "BarrierCompactV14Fixed", "BarrierCompactV15Fixed", "BarrierCompactV16Fixed"}) do
    local previous = pg:FindFirstChild(oldName)
    if previous then previous:Destroy() end
end

local busy = false
local broken = false
local savedCollision = {}

local menu = RS:WaitForChild("MenuToys")
local spawnRemote = menu:WaitForChild("SpawnToyRemoteFunction")
local destroyRemote = menu:WaitForChild("DestroyToy")

local toys = workspace:WaitForChild(
    player.Name .. "SpawnedInToys"
)

local waypoint = workspace
    :WaitForChild("Waypoints")
    :WaitForChild("BlueHouse")

local inPlot = player:WaitForChild("InPlot")
local inOwnedPlot = player:WaitForChild("InOwnedPlot")
local canSpawn = player:WaitForChild("CanSpawnToy")

-- ==========================================
-- UI
-- ==========================================

local gui = Instance.new("ScreenGui")
gui.Name = "BarrierCompactV16Fixed"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = pg

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(190, 92)
frame.AnchorPoint = Vector2.new(1, 0)
frame.Position = UDim2.new(1, -18, 0, 44)
frame.BackgroundColor3 = Color3.fromRGB(27, 22, 40)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui

-- Shrink the entire UI uniformly by 5%, preserving the original layout.
local uiScale = Instance.new("UIScale")
uiScale.Scale = 0.95
uiScale.Parent = frame

Instance.new("UICorner", frame).CornerRadius =
    UDim.new(0, 10)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(170, 90, 255)
stroke.Thickness = 2
stroke.Parent = frame

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 26)
titleBar.BackgroundTransparency = 1
titleBar.Active = true
titleBar.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -45, 1, 0)
title.Position = UDim2.fromOffset(7, 0)
title.BackgroundTransparency = 1
title.Text = "🔨 バリア破壊"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local minimize = Instance.new("TextButton")
minimize.Name = "MinimizeButton"
minimize.Size = UDim2.fromOffset(27, 22)
minimize.Position = UDim2.new(1, -31, 0, 2)
minimize.BackgroundColor3 =
    Color3.fromRGB(65, 55, 85)
minimize.TextColor3 = Color3.new(1, 1, 1)
minimize.Font = Enum.Font.GothamBold
minimize.TextSize = 18
minimize.Text = "−"
minimize.TextXAlignment = Enum.TextXAlignment.Center
minimize.TextYAlignment = Enum.TextYAlignment.Center
minimize.TextScaled = false
minimize.TextWrapped = false
minimize.BorderSizePixel = 0
minimize.AutoButtonColor = true
minimize.Parent = titleBar

Instance.new("UICorner", minimize).CornerRadius =
    UDim.new(0, 6)

local button = Instance.new("TextButton")
button.Size = UDim2.new(1, -16, 0, 30)
button.AnchorPoint = Vector2.new(0.5, 0)
button.Position = UDim2.new(0.5, 0, 0, 29)
button.BackgroundColor3 =
    Color3.fromRGB(135, 75, 220)
button.TextColor3 = Color3.new(1, 1, 1)
button.Font = Enum.Font.GothamBold
button.TextSize = 12
button.Text = "バリア破壊開始"
button.BorderSizePixel = 0
button.Parent = frame

Instance.new("UICorner", button).CornerRadius =
    UDim.new(0, 7)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -10, 0, 27)
status.Position = UDim2.fromOffset(5, 62)
status.BackgroundTransparency = 1
status.TextColor3 =
    Color3.fromRGB(215, 190, 255)
status.Font = Enum.Font.Gotham
status.TextSize = 10
status.TextWrapped = true
status.Text = "準備完了"
status.Parent = frame

local function notify(message)
    status.Text = tostring(message)
    print("[Barrier V5]", message)
end

-- ==========================================
-- MINIMIZE / RESTORE
-- ==========================================

local minimized = false

minimize.MouseButton1Click:Connect(function()
    minimized = not minimized

    button.Visible = not minimized
    status.Visible = not minimized

    frame.Size = minimized
        and UDim2.fromOffset(190, 26)
        or UDim2.fromOffset(190, 92)

    minimize.Text = minimized and "+" or "−"

    -- Keep the symbol centered in the button.
    minimize.TextXAlignment = Enum.TextXAlignment.Center
    minimize.TextYAlignment = Enum.TextYAlignment.Center
end)

-- ==========================================
-- CHARACTER
-- ==========================================

local function getCharacter()
    local c = player.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    return c, root, hum
end

local function teleport(root, cf)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.CFrame = typeof(cf) == "Instance"
        and cf.CFrame or cf
end

-- ==========================================
-- DESTROY TOY
-- ==========================================

local function destroyToy(toy)
    if toy then
        pcall(function()
            destroyRemote:FireServer(toy)
        end)
    end
end

-- ==========================================
-- SPAWN TOY
-- ==========================================

local function spawnToy(name, at)
    local c, root = getCharacter()

    if not root then
        return nil, "Character unavailable"
    end

    local startTime = os.clock()

    while not canSpawn.Value
        and os.clock() - startTime < 8 do
        task.wait()
    end

    if not canSpawn.Value then
        return nil, "CanSpawnToy=false"
    end

    local foreignPlot =
        inPlot.Value and not inOwnedPlot.Value

    local base = foreignPlot
        and CFrame.new(0, 25, 0)
        or root.CFrame + Vector3.new(0, 15, 0)

    local target = CFrame.new(
        (at or base).Position
    ) + Vector3.new(0, 0, 20)

    local rotate = workspace:FindFirstChild(
        "RotateOrientPart"
    )

    local rotation = rotate
        and rotate.Rotation
        or Vector3.zero

    local found

    local connection = toys.ChildAdded:Connect(function(child)
        if child.Name == name then
            found = child
        end
    end)

    local saved = root.CFrame
    local hb
    local bindName = "BarrierV5Spawn"

    if foreignPlot then
        RunService:BindToRenderStep(
            bindName,
            Enum.RenderPriority.Camera.Value - 1,
            function()
                if root.Parent then
                    root.CFrame = saved
                end
            end
        )

        hb = RunService.Heartbeat:Connect(function()
            if root.Parent then
                saved = root.CFrame
                root.CFrame = CFrame.new(0, 10, 0)
            end
        end)
    end

    local function invoke()
        task.spawn(function()
            pcall(function()
                spawnRemote:InvokeServer(
                    name,
                    target,
                    rotation
                )
            end)
        end)
    end

    invoke()

    local t = os.clock()

    while not found and os.clock() - t < 1.3 do
        RunService.Heartbeat:Wait()

        if foreignPlot then
            invoke()
        end
    end

    if foreignPlot then
        RunService:UnbindFromRenderStep(bindName)

        if hb then hb:Disconnect() end

        if root.Parent then
            root.CFrame = saved
        end
    end

    connection:Disconnect()

    return found,
        found and nil or ("Spawn failed: " .. name)
end

-- ==========================================
-- CHECK BARRIER
-- ==========================================

local function isBroken()
    if broken then return true end

    local box, err = spawnToy(
        "Boombox",
        waypoint.CFrame
    )

    if not box then
        notify(err)
        return false
    end

    task.wait(2)

    local result = box.Parent ~= nil

    destroyToy(box)

    if result then
        broken = true
    end

    return result
end

-- ==========================================
-- BARRIER COLLISION
-- ==========================================

local function noclipBarriers()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return end

    for _, plot in ipairs(plots:GetChildren()) do
        local barrier = plot:FindFirstChild("Barrier")

        if barrier then
            for _, part in ipairs(barrier:GetDescendants()) do
                if part:IsA("BasePart")
                    and part.Name == "PlotBarrier" then

                    if savedCollision[part] == nil then
                        savedCollision[part] = part.CanCollide
                    end

                    part.CanCollide = false
                end
            end
        end
    end
end

-- ==========================================
-- HAMBURGER ATTEMPT
-- ==========================================

local function attempt()
    local c, root, hum = getCharacter()

    if not c or not root or not hum
        or hum.Health <= 0 then
        return false, "Character unavailable"
    end

    local hamburger, err = spawnToy("FoodHamburger")

    if not hamburger then
        return false, err
    end

    local holdPart = hamburger:WaitForChild(
        "HoldPart", 0.35
    )

    local remote = holdPart and
        holdPart:WaitForChild(
            "HoldItemRemoteFunction", 0.35
        )

    local rigid = holdPart and
        holdPart:WaitForChild(
            "RigidConstraint", 0.35
        )

    if not remote or not rigid then
        destroyToy(hamburger)
        return false, "Hold components missing"
    end

    local original = root.CFrame

    teleport(root, waypoint)

    local t = os.clock()

    while not inPlot.Value
        and os.clock() - t < 0.7 do
        task.wait()
    end

    if not inPlot.Value then
        teleport(root, original)
        destroyToy(hamburger)
        return false, "InPlot=false"
    end

    task.spawn(function()
        pcall(function()
            remote:InvokeServer(hamburger, c)
        end)
    end)

    t = os.clock()

    while rigid.Parent
        and not rigid.Attachment1
        and os.clock() - t < 0.7 do
        task.wait()
    end

    if not rigid.Parent or not rigid.Attachment1 then
        teleport(root, original)
        destroyToy(hamburger)
        return false, "Hold failed"
    end

    destroyToy(hamburger)

    task.wait(0.5)

    teleport(root, original)

    task.wait(1)

    if isBroken() then
        noclipBarriers()
        return true, "完了"
    end

    return false, "Verification failed"
end

-- ==========================================
-- EXECUTE
-- ==========================================

button.MouseButton1Click:Connect(function()
    if busy then return end

    busy = true
    button.Text = "実行中..."

    task.spawn(function()
        local ok, err = pcall(function()
            notify("バリア確認中...")

            if isBroken() then
                noclipBarriers()
                notify("バリア無効化済み")
                return
            end

            for i = 1, 15 do
                notify("試行 " .. i .. "/15")

                local success, message = attempt()

                if success then
                    notify("バリア処理完了")
                    return
                end

                notify(message)
                task.wait(0.5)
            end

            notify("15回試行しました")
        end)

        if not ok then
            notify("エラー: " .. tostring(err))
        end

        busy = false
        button.Text = "バリア破壊開始"
    end)
end)

notify("準備完了")
