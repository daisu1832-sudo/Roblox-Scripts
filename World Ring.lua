 -- RingGui (modified)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")

    local player = Players.LocalPlayer
    local mouse = player:GetMouse()

    local gui = Instance.new("ScreenGui")
    gui.Name = "RingGui"
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0,150,0,70)
    frame.Position = UDim2.new(0,15,0,15)
    frame.BackgroundColor3 = Color3.fromRGB(35,35,35)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    Instance.new("UICorner",frame).CornerRadius = UDim.new(0,16)

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0,120,0,40)
    button.Position = UDim2.new(0.5,-60,0.5,-20)
    button.BackgroundColor3 = Color3.fromRGB(220,60,60)
    button.Text = "OFF"
    button.TextScaled = true
    button.TextColor3 = Color3.new(1,1,1)
    button.BorderSizePixel = 0
    button.Parent = frame
    Instance.new("UICorner",button).CornerRadius = UDim.new(0,12)

    local enabled=false
    local parts={}
    local angle=0

    button.MouseButton1Click:Connect(function()
        enabled = not enabled
        if enabled then
            button.Text="ON"
            button.BackgroundColor3=Color3.fromRGB(60,220,60)
            angle=0
            for _,part in ipairs(parts) do
                if part and part.Parent then
                    part.Anchored=true
                end
            end
        else
            button.Text="OFF"
            button.BackgroundColor3=Color3.fromRGB(220,60,60)
            for _,part in ipairs(parts) do
                if part and part.Parent then
                    part.Anchored=true
                end
            end
        end
    end)

    mouse.Button1Down:Connect(function()
        if not enabled then return end

        local target = mouse.Target
        if not target or not target:IsA("BasePart") then return end

        local character = player.Character

        -- 自分自身は対象外
        if character and target:IsDescendantOf(character) then
            return
        end

        -- 乗り物に乗っている時だけ、その乗り物は対象外
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.SeatPart then
            local vehicle = humanoid.SeatPart:FindFirstAncestorOfClass("Model")
            if vehicle and target:IsDescendantOf(vehicle) then
                return
            end
        end

        if not table.find(parts,target) then
            target.Anchored=true
            table.insert(parts,target)
        end
    end)

    RunService.RenderStepped:Connect(function(dt)
        if not enabled then return end
        local character = player.Character
        if not character then return end
        local head = character:FindFirstChild("Head")
        if not head then return end

        angle += dt*2
        local radius=1000
        local height=50
        local count=#parts
        if count==0 then return end

        for i=#parts,1,-1 do
            local part=parts[i]
            if not part or not part.Parent then
                table.remove(parts,i)
            else
                local theta=angle+((i-1)/count)*math.pi*2
                part.CFrame=CFrame.new(
                    head.Position + Vector3.new(
                        math.cos(theta)*radius,
                        height,
                        math.sin(theta)*radius
                    )
                )
            end
        end
    end)
