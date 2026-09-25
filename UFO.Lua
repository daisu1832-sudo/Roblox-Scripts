-- UFO.Lua
-- UFO MERGE V9.2 - SLIM UI
-- MERGE + CROSSHAIR FOLLOW + HIGH SPEED WHEEL ROTATION

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local STACK_HEIGHT = 0
local AIM_DISTANCE = 50
local ROTATE_SPEED = 720

local GRAY = Color3.fromRGB(55, 55, 55)
local GREEN = Color3.fromRGB(35, 145, 55)

local root = workspace:WaitForChild("Map"):WaitForChild("AlwaysHereTweenedObjects")
local topUFO = root:WaitForChild("InnerUFO"):WaitForChild("Object"):WaitForChild("ObjectModel")

local bottomUFO
for _, obj in ipairs(root:GetDescendants()) do
	if obj:IsA("Model") and obj.Name == "ObjectModel" and obj ~= topUFO and not obj:IsDescendantOf(topUFO) then
		for _, child in ipairs(obj:GetDescendants()) do
			if child:IsA("BasePart") then
				bottomUFO = obj
				break
			end
		end
		if bottomUFO then break end
	end
end

if not bottomUFO then
	warn("[UFO V9.2] SECOND UFO NOT FOUND")
	return
end

local enabled = false
local rotating = false
local topHomePivot, bottomHomePivot
local baseTopRelative, baseBottomRelative
local rotationAngle = 0

local oldGui = playerGui:FindFirstChild("UFOMergeGUI")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "UFOMergeGUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Main"
panel.Size = UDim2.new(0, 280, 0, 32)
panel.Position = UDim2.new(0.5, -140, 0, 14)
panel.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
panel.BorderSizePixel = 0
panel.Parent = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 8)
panelCorner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = panel

local followButton = Instance.new("TextButton")
followButton.Name = "Follow"
followButton.Size = UDim2.new(0, 138, 1, 0)
followButton.BackgroundColor3 = GRAY
followButton.BorderSizePixel = 0
followButton.Text = "FOLLOW  OFF"
followButton.TextColor3 = Color3.new(1, 1, 1)
followButton.Font = Enum.Font.GothamBold
followButton.TextSize = 10
followButton.AutoButtonColor = false
followButton.Parent = panel

local followCorner = Instance.new("UICorner")
followCorner.CornerRadius = UDim.new(0, 8)
followCorner.Parent = followButton

local followFix = Instance.new("Frame")
followFix.Size = UDim2.new(0, 8, 1, 0)
followFix.Position = UDim2.new(1, -8, 0, 0)
followFix.BackgroundColor3 = GRAY
followFix.BorderSizePixel = 0
followFix.ZIndex = 2
followFix.Parent = followButton

local rotateButton = Instance.new("TextButton")
rotateButton.Name = "Rotate"
rotateButton.Size = UDim2.new(0, 138, 1, 0)
rotateButton.Position = UDim2.new(0, 142, 0, 0)
rotateButton.BackgroundColor3 = GRAY
rotateButton.BorderSizePixel = 0
rotateButton.Text = "ROTATE  OFF"
rotateButton.TextColor3 = Color3.new(1, 1, 1)
rotateButton.Font = Enum.Font.GothamBold
rotateButton.TextSize = 10
rotateButton.AutoButtonColor = false
rotateButton.Parent = panel

local rotateCorner = Instance.new("UICorner")
rotateCorner.CornerRadius = UDim.new(0, 8)
rotateCorner.Parent = rotateButton

local rotateFix = Instance.new("Frame")
rotateFix.Size = UDim2.new(0, 8, 1, 0)
rotateFix.BackgroundColor3 = GRAY
rotateFix.BorderSizePixel = 0
rotateFix.ZIndex = 2
rotateFix.Parent = rotateButton

local divider = Instance.new("Frame")
divider.Size = UDim2.new(0, 2, 1, 0)
divider.Position = UDim2.new(0.5, -1, 0, 0)
divider.BorderSizePixel = 0
divider.ZIndex = 5
divider.Parent = panel

local hue = 0
RunService.RenderStepped:Connect(function(dt)
	hue = (hue + dt * 0.15) % 1
	local rainbow = Color3.fromHSV(hue, 1, 1)
	stroke.Color = rainbow
	divider.BackgroundColor3 = rainbow
end)

local function updateUI()
	followButton.Text = enabled and "FOLLOW  ON" or "FOLLOW  OFF"
	followButton.BackgroundColor3 = enabled and GREEN or GRAY
	followFix.BackgroundColor3 = enabled and GREEN or GRAY

	rotateButton.Text = rotating and "ROTATE  ON" or "ROTATE  OFF"
	rotateButton.BackgroundColor3 = rotating and GREEN or GRAY
	rotateFix.BackgroundColor3 = rotating and GREEN or GRAY
end

local function getBox(model)
	return model:GetBoundingBox()
end

local function createMerge()
	topHomePivot = topUFO:GetPivot()
	bottomHomePivot = bottomUFO:GetPivot()

	local bottomPivot = bottomHomePivot
	bottomUFO:PivotTo(bottomPivot)

	local temporaryTopPivot =
		CFrame.new(topHomePivot.Position)
		* bottomPivot.Rotation
		* CFrame.Angles(math.rad(180), 0, 0)

	topUFO:PivotTo(temporaryTopPivot)

	local bottomBox, bottomSize = getBox(bottomUFO)
	local topBox, topSize = getBox(topUFO)

	local targetTopCenter = Vector3.new(
		bottomBox.Position.X,
		bottomBox.Position.Y + bottomSize.Y / 2 + topSize.Y / 2 + STACK_HEIGHT,
		bottomBox.Position.Z
	)

	local topPivot = temporaryTopPivot + (targetTopCenter - topBox.Position)
	topUFO:PivotTo(topPivot)

	local newBottomBox, newBottomSize = getBox(bottomUFO)
	local newTopBox, newTopSize = getBox(topUFO)

	local bottomMin = newBottomBox.Position - newBottomSize / 2
	local bottomMax = newBottomBox.Position + newBottomSize / 2
	local topMin = newTopBox.Position - newTopSize / 2
	local topMax = newTopBox.Position + newTopSize / 2

	local minimum = Vector3.new(
		math.min(bottomMin.X, topMin.X),
		math.min(bottomMin.Y, topMin.Y),
		math.min(bottomMin.Z, topMin.Z)
	)
	local maximum = Vector3.new(
		math.max(bottomMax.X, topMax.X),
		math.max(bottomMax.Y, topMax.Y),
		math.max(bottomMax.Z, topMax.Z)
	)

	local centerCF = CFrame.new((minimum + maximum) / 2)
	baseBottomRelative = centerCF:ToObjectSpace(bottomUFO:GetPivot())
	baseTopRelative = centerCF:ToObjectSpace(topUFO:GetPivot())
	rotationAngle = 0
end

local function updateUFO()
	if not enabled or not baseBottomRelative or not baseTopRelative then return end

	local camera = workspace.CurrentCamera
	if not camera then return end

	local target = camera.CFrame.Position + camera.CFrame.LookVector * AIM_DISTANCE
	local centerCF = CFrame.new(target)

	if rotating then
		centerCF = centerCF
			* CFrame.Angles(0, 0, math.rad(90))
			* CFrame.Angles(math.rad(rotationAngle), 0, 0)
	end

	bottomUFO:PivotTo(centerCF * baseBottomRelative)
	topUFO:PivotTo(centerCF * baseTopRelative)
end

local function restore()
	if topHomePivot and topUFO.Parent then topUFO:PivotTo(topHomePivot) end
	if bottomHomePivot and bottomUFO.Parent then bottomUFO:PivotTo(bottomHomePivot) end
end

followButton.MouseButton1Click:Connect(function()
	if not enabled then
		enabled = true
		rotating = false
		updateUI()

		local ok, err = pcall(function()
			createMerge()
			updateUFO()
		end)

		if not ok then
			warn("[UFO V9.2] MERGE ERROR:", err)
			enabled = false
			rotating = false
			updateUI()
		end
	else
		enabled = false
		rotating = false
		restore()
		baseTopRelative = nil
		baseBottomRelative = nil
		rotationAngle = 0
		updateUI()
	end
end)

rotateButton.MouseButton1Click:Connect(function()
	if not enabled then return end
	rotating = not rotating
	if not rotating then rotationAngle = 0 end
	updateUI()
end)

RunService.RenderStepped:Connect(function(dt)
	if not enabled then return end

	if rotating then
		rotationAngle = (rotationAngle + ROTATE_SPEED * dt) % 360
	end

	local ok, err = pcall(updateUFO)
	if not ok then
		warn("[UFO V9.2] UPDATE ERROR:", err)
	end
end)

updateUI()

print("================================")
print("[UFO V9.2] READY")
print("[UFO] SLIM UI = YES")
print("[UFO] DISTANCE:", AIM_DISTANCE)
print("[UFO] ROTATE SPEED:", ROTATE_SPEED)
print("================================")
