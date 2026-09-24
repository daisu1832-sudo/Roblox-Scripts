local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local MAX_OBJECTS = 5
local RAY_DISTANCE = 60
local CURRENT_SPEED = 20
local CAMERA_DISTANCE = 20
local FORMATION_SPACING = 6
local MAX_FORCE = 100000
local STOP_FORCE = 10000000
local CAMERA_SMOOTHNESS = 30
local CAMERA_SENSITIVITY = 1.0
local PLAYER_FIXED_POSITION = Vector3.new(460.4,131.4,202.7)

local controlling = false
local flying = false
local selectedRoots = {}
local movers = {}
local flyFixedCFrames = {}
local formationSlots = {}
local savedPlayerCFrame = nil

local cameraYaw = 0
local cameraPitch = -20
local currentYaw = 0
local currentPitch = -20
local MIN_PITCH = -80
local MAX_PITCH = 80

local function findCenterTarget()
	local cam = workspace.CurrentCamera
	if not cam then return nil end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {player.Character}
	params.IgnoreWater = true

	local result = workspace:Raycast(
		cam.CFrame.Position,
		cam.CFrame.LookVector * RAY_DISTANCE,
		params
	)

	if not result then return nil end

	local part = result.Instance
	if not part or not part:IsA("BasePart") or part.Anchored then
		return nil
	end

	return part.AssemblyRootPart or part
end

local function getWholeObjectRoot(part)
	if not part or not part:IsA("BasePart") then
		return nil
	end

	return part.AssemblyRootPart or part
end

local function isAlreadySelected(root)
	for _, v in ipairs(selectedRoots) do
		if v == root then
			return true
		end
	end
	return false
end

local function getSelectionCenter()
	local total = Vector3.zero
	local count = 0

	for _, root in ipairs(selectedRoots) do
		if root and root.Parent then
			total += root.Position
			count += 1
		end
	end

	if count == 0 then return nil end
	return total / count
end

local function updateThirdPersonCamera(dt)
	local center = getSelectionCenter()
	if not center then return end

	currentYaw += (cameraYaw-currentYaw) * math.clamp(dt*CAMERA_SMOOTHNESS,0,1)
	currentPitch += (cameraPitch-currentPitch) * math.clamp(dt*CAMERA_SMOOTHNESS,0,1)

	local yawRad = math.rad(currentYaw)
	local pitchRad = math.rad(currentPitch)

	local offset = Vector3.new(
		math.cos(pitchRad)*math.sin(yawRad),
		math.sin(pitchRad),
		math.cos(pitchRad)*math.cos(yawRad)
	) * CAMERA_DISTANCE

	camera.CFrame = CFrame.lookAt(center + offset, center)
end

local function createMover(root)
	if movers[root] then return end

	local mover = Instance.new("BodyVelocity")
	mover.Name = "GrabMoveVelocity"
	mover.MaxForce = Vector3.new(MAX_FORCE,MAX_FORCE,MAX_FORCE)
	mover.P = 12500
	mover.Velocity = Vector3.zero
	mover.Parent = root
	movers[root] = mover
end

local function destroyMover(root)
	local mover = movers[root]
	if mover then
		mover:Destroy()
		movers[root] = nil
	end
end

local function destroyAllMovers()
	for _, mover in pairs(movers) do
		if mover then mover:Destroy() end
	end
	table.clear(movers)
end

local function movePlayerAway()
	if savedPlayerCFrame then return end

	local char = player.Character
	if not char then return end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	savedPlayerCFrame = hrp.CFrame
	hrp.CFrame = CFrame.new(PLAYER_FIXED_POSITION)
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
end

local function restorePlayer()
	if not savedPlayerCFrame then return end

	local char = player.Character
	if char then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CFrame = savedPlayerCFrame
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		end
	end

	savedPlayerCFrame = nil
end

local oldGui = playerGui:FindFirstChild("GrabMoveGui")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GrabMoveGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local selectButton = Instance.new("TextButton")
selectButton.Size = UDim2.new(0,130,0,40)
selectButton.Position = UDim2.new(1,-150,0,20)
selectButton.Text = "選択: 0/5"
selectButton.BackgroundColor3 = Color3.fromRGB(60,60,60)
selectButton.TextColor3 = Color3.fromRGB(255,255,255)
selectButton.Font = Enum.Font.GothamBold
selectButton.TextSize = 15
selectButton.Parent = screenGui

local selectCorner = Instance.new("UICorner")
selectCorner.CornerRadius = UDim.new(0,8)
selectCorner.Parent = selectButton

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0,110,0,40)
toggleButton.Position = UDim2.new(1,-270,0,20)
toggleButton.Text = "操作: OFF"
toggleButton.BackgroundColor3 = Color3.fromRGB(60,60,60)
toggleButton.TextColor3 = Color3.fromRGB(255,255,255)
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 15
toggleButton.Parent = screenGui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0,8)
toggleCorner.Parent = toggleButton

local subButtonContainer = Instance.new("Frame")
subButtonContainer.Size = UDim2.new(0,200,0,40)
subButtonContainer.Position = UDim2.new(1,-485,0,20)
subButtonContainer.BackgroundTransparency = 1
subButtonContainer.Visible = false
subButtonContainer.Parent = screenGui

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Horizontal
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0,10)
listLayout.Parent = subButtonContainer

local speedBox = Instance.new("TextBox")
speedBox.Size = UDim2.new(0,80,0,40)
speedBox.Text = tostring(CURRENT_SPEED)
speedBox.PlaceholderText = "速度"
speedBox.BackgroundColor3 = Color3.fromRGB(50,50,50)
speedBox.TextColor3 = Color3.fromRGB(255,255,255)
speedBox.Font = Enum.Font.GothamBold
speedBox.TextSize = 14
speedBox.ClearTextOnFocus = false
speedBox.LayoutOrder = 1
speedBox.Parent = subButtonContainer

local speedCorner = Instance.new("UICorner")
speedCorner.CornerRadius = UDim.new(0,8)
speedCorner.Parent = speedBox

speedBox.FocusLost:Connect(function()
	local val = tonumber(speedBox.Text)
	if val then
		CURRENT_SPEED = math.clamp(val,1,1000)
	end
	speedBox.Text = tostring(CURRENT_SPEED)
end)

local flyButton = Instance.new("TextButton")
flyButton.Size = UDim2.new(0,100,0,40)
flyButton.Text = "飛行: OFF"
flyButton.BackgroundColor3 = Color3.fromRGB(60,60,60)
flyButton.TextColor3 = Color3.fromRGB(255,255,255)
flyButton.Font = Enum.Font.GothamBold
flyButton.TextSize = 15
flyButton.LayoutOrder = 2
flyButton.Parent = subButtonContainer

local flyCorner = Instance.new("UICorner")
flyCorner.CornerRadius = UDim.new(0,8)
flyCorner.Parent = flyButton

local stickBase = Instance.new("Frame")
stickBase.Size = UDim2.new(0,90,0,90)
stickBase.Position = UDim2.new(0,40,1,-150)
stickBase.BackgroundColor3 = Color3.fromRGB(40,40,40)
stickBase.BackgroundTransparency = 0.4
stickBase.Visible = false
stickBase.Parent = screenGui

local baseCorner = Instance.new("UICorner")
baseCorner.CornerRadius = UDim.new(1,0)
baseCorner.Parent = stickBase

local stickKnob = Instance.new("Frame")
stickKnob.Size = UDim2.new(0,40,0,40)
stickKnob.Position = UDim2.new(0.5,-20,0.5,-20)
stickKnob.BackgroundColor3 = Color3.fromRGB(200,200,200)
stickKnob.Parent = stickBase

local knobCorner = Instance.new("UICorner")
knobCorner.CornerRadius = UDim.new(1,0)
knobCorner.Parent = stickKnob

local stickRadius = 45
local stickCenter = Vector2.new(45,45)
local stickInput = Vector2.zero
local activeStickTouch = nil

local function updateKnob(delta)
	local clamped = delta
	if clamped.Magnitude > stickRadius then
		clamped = clamped.Unit * stickRadius
	end

	stickKnob.Position = UDim2.new(0.5,clamped.X-20,0.5,clamped.Y-20)
	stickInput = Vector2.new(clamped.X/stickRadius,clamped.Y/stickRadius)
end

local function resetKnob()
	stickKnob.Position = UDim2.new(0.5,-20,0.5,-20)
	stickInput = Vector2.zero
end

stickBase.InputBegan:Connect(function(input)
	if not controlling then return end

	if input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1 then

		activeStickTouch = input
		local pos = input.Position
		local basePos = stickBase.AbsolutePosition

		updateKnob(
			Vector2.new(pos.X,pos.Y)
			- basePos
			- stickCenter
		)
	end
end)

local activeCameraTouch = nil
local lastCameraTouchPos = nil

UserInputService.InputBegan:Connect(function(input)
	if not controlling then return end

	if input.UserInputType ~= Enum.UserInputType.Touch
		and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end

	local screenWidth = camera.ViewportSize.X
	if input.Position.X < screenWidth*0.5 then return end

	activeCameraTouch = input
	lastCameraTouchPos = Vector2.new(input.Position.X,input.Position.Y)
end)

UserInputService.InputChanged:Connect(function(input)
	if not controlling then return end

	if activeStickTouch == input then
		local pos = input.Position
		local basePos = stickBase.AbsolutePosition
		updateKnob(Vector2.new(pos.X,pos.Y)-basePos-stickCenter)
	end

	if activeCameraTouch == input and lastCameraTouchPos then
		local pos = Vector2.new(input.Position.X,input.Position.Y)
		local delta = pos-lastCameraTouchPos
		lastCameraTouchPos = pos

		cameraYaw -= delta.X*CAMERA_SENSITIVITY
		cameraPitch = math.clamp(
			cameraPitch + delta.Y*CAMERA_SENSITIVITY,
			MIN_PITCH,
			MAX_PITCH
		)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if activeStickTouch == input then
		activeStickTouch = nil
		resetKnob()
	end

	if activeCameraTouch == input then
		activeCameraTouch = nil
		lastCameraTouchPos = nil
	end
end)

local isJumpRequested = false

ContextActionService:BindAction(
	"GrabMoveJumpKey",
	function(_,inputState)
		if not controlling then
			return Enum.ContextActionResult.Pass
		end

		if inputState == Enum.UserInputState.Begin then
			isJumpRequested = true
		elseif inputState == Enum.UserInputState.End then
			isJumpRequested = false
		end

		return Enum.ContextActionResult.Sink
	end,
	false,
	Enum.KeyCode.Space
)

local function getPlayerJumpPower()
	local char = player.Character
	if not char then return 50 end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if humanoid then return humanoid.JumpPower end

	return 50
end

local function isGrounded(part)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {player.Character,part}

	local result = workspace:Raycast(
		part.Position,
		Vector3.new(0,-(part.Size.Y*0.5+0.6),0),
		params
	)

	return result ~= nil
end

local function arrangeObjectsEvenly()
	local objects = {}

	for _, root in ipairs(selectedRoots) do
		if root and root.Parent then
			table.insert(objects,root)
		end
	end

	local count = #objects
	if count == 0 then return end

	local center = Vector3.zero
	for _, root in ipairs(objects) do
		center += root.Position
	end
	center /= count

	local right = camera.CFrame.RightVector
	if right.Magnitude < 0.001 then
		right = Vector3.new(1,0,0)
	else
		right = right.Unit
	end

	table.clear(formationSlots)

	local startOffset = -((count-1)*FORMATION_SPACING)/2

	for index,root in ipairs(objects) do
		local offset = startOffset + ((index-1)*FORMATION_SPACING)
		formationSlots[root] = offset

		local targetPosition = center + right*offset
		root.CFrame = CFrame.new(targetPosition) * root.CFrame.Rotation
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		flyFixedCFrames[root] = root.CFrame
	end
end

local function faceObjectCorrectly(root, camCF)
	if not root or not root.Parent then return end

	local fromCamera = root.Position - camCF.Position
	if fromCamera.Magnitude < 0.001 then return end

	local xDirection = -fromCamera.Unit
	local upReference = camCF.UpVector.Unit
	local zDirection = xDirection:Cross(upReference)

	if zDirection.Magnitude < 0.001 then
		upReference = camCF.RightVector.Unit
		zDirection = xDirection:Cross(upReference)
	end

	if zDirection.Magnitude > 0.001 then
		zDirection = zDirection.Unit
		local yDirection = zDirection:Cross(xDirection).Unit

		root.CFrame = CFrame.fromMatrix(
			root.Position,
			xDirection,
			yDirection,
			zDirection
		)
	end

	root.AssemblyAngularVelocity = Vector3.zero
end

selectButton.MouseButton1Click:Connect(function()
	if controlling then return end

	if #selectedRoots >= MAX_OBJECTS then
		selectButton.Text = "最大5個"
		task.delay(1,function()
			selectButton.Text = "選択: "..#selectedRoots.."/5"
		end)
		return
	end

	local root = findCenterTarget()

	if not root then
		selectButton.Text = "対象なし"
		task.delay(1,function()
			selectButton.Text = "選択: "..#selectedRoots.."/5"
		end)
		return
	end

	if isAlreadySelected(root) then
		selectButton.Text = "選択済み"
		task.delay(1,function()
			selectButton.Text = "選択: "..#selectedRoots.."/5"
		end)
		return
	end

	table.insert(selectedRoots,root)
	selectButton.Text = "選択: "..#selectedRoots.."/5"
end)

local function stopControl()
	destroyAllMovers()
	restorePlayer()

	controlling = false
	flying = false
	table.clear(flyFixedCFrames)
	table.clear(formationSlots)
	table.clear(selectedRoots)

	camera.CameraType = Enum.CameraType.Custom

	toggleButton.Text = "操作: OFF"
	selectButton.Text = "選択: 0/5"
	flyButton.Text = "飛行: OFF"
	flyButton.BackgroundColor3 = Color3.fromRGB(60,60,60)

	subButtonContainer.Visible = false
	stickBase.Visible = false
	resetKnob()
end

toggleButton.MouseButton1Click:Connect(function()
	if controlling then
		stopControl()
		return
	end

	if #selectedRoots == 0 then
		toggleButton.Text = "対象なし"
		task.wait(1)
		toggleButton.Text = "操作: OFF"
		return
	end

	movePlayerAway()

	for _,root in ipairs(selectedRoots) do
		if root and root.Parent then
			createMover(root)
		end
	end

	cameraYaw = 0
	cameraPitch = -20
	currentYaw = 0
	currentPitch = -20

	camera.CameraType = Enum.CameraType.Scriptable
	controlling = true

	toggleButton.Text = "操作: ON"
	subButtonContainer.Visible = true
	stickBase.Visible = true
end)

flyButton.MouseButton1Click:Connect(function()
	if not controlling then return end

	flying = not flying

	if flying then
		table.clear(flyFixedCFrames)

		flyButton.Text = "飛行: ON"
		flyButton.BackgroundColor3 = Color3.fromRGB(40,120,40)

		arrangeObjectsEvenly()

		local camCF = camera.CFrame
		for _, root in ipairs(selectedRoots) do
			if root and root.Parent then
				faceObjectCorrectly(root, camCF)
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			end
		end
	else
		table.clear(flyFixedCFrames)
		table.clear(formationSlots)

		flyButton.Text = "飛行: OFF"
		flyButton.BackgroundColor3 = Color3.fromRGB(60,60,60)
	end
end)

RunService.Heartbeat:Connect(function(dt)
	if not controlling then return end

	for i=#selectedRoots,1,-1 do
		local root = selectedRoots[i]

		if not root or not root.Parent then
			if root then
				destroyMover(root)
				flyFixedCFrames[root] = nil
			end

			table.remove(selectedRoots,i)
		end
	end

	if #selectedRoots == 0 then
		stopControl()
		return
	end

	updateThirdPersonCamera(dt)

	local camCF = camera.CFrame

	if flying and #selectedRoots > 1 then
		local formationCenter = getSelectionCenter()

		if formationCenter then
			local screenRight = camCF.RightVector

			if screenRight.Magnitude > 0.001 then
				screenRight = screenRight.Unit

				for _, root in ipairs(selectedRoots) do
					local slot = formationSlots[root]

					if root and root.Parent and slot then
						local targetPosition = formationCenter + screenRight * slot
						local rotation = root.CFrame.Rotation

						root.CFrame = CFrame.new(targetPosition) * rotation
						root.AssemblyAngularVelocity = Vector3.zero
					end
				end
			end
		end
	end

	local forward = Vector3.new(
		camCF.LookVector.X,
		0,
		camCF.LookVector.Z
	)

	if forward.Magnitude > 0 then
		forward = forward.Unit
	end

	local right = Vector3.new(
		camCF.RightVector.X,
		0,
		camCF.RightVector.Z
	)

	if right.Magnitude > 0 then
		right = right.Unit
	end

	local moveDir = (right*stickInput.X)+(forward*-stickInput.Y)

	if moveDir.Magnitude > 1 then
		moveDir = moveDir.Unit
	end

	for _,root in ipairs(selectedRoots) do
		local mover = movers[root]

		if mover and root.Parent then
			if flying then
				local flyDir =
					(camCF.LookVector*-stickInput.Y)
					+(camCF.RightVector*stickInput.X)

				if flyDir.Magnitude > 1 then
					flyDir = flyDir.Unit
				end

				faceObjectCorrectly(root, camCF)

				if stickInput.Magnitude < 0.05 then
					mover.MaxForce = Vector3.new(
						STOP_FORCE,
						STOP_FORCE,
						STOP_FORCE
					)
					mover.Velocity = Vector3.zero
				else
					mover.MaxForce = Vector3.new(
						MAX_FORCE,
						MAX_FORCE,
						MAX_FORCE
					)
					mover.Velocity = flyDir*CURRENT_SPEED
				end
			else
				if stickInput.Magnitude < 0.05 then
					mover.MaxForce = Vector3.new(
						STOP_FORCE,
						0,
						STOP_FORCE
					)
					mover.Velocity = Vector3.zero
				else
					local targetVel = moveDir*CURRENT_SPEED

					mover.MaxForce = Vector3.new(
						MAX_FORCE,
						0,
						MAX_FORCE
					)

					mover.Velocity = Vector3.new(
						targetVel.X,
						0,
						targetVel.Z
					)
				end
			end
		end
	end

	if isJumpRequested and not flying then
		local jumpPower = getPlayerJumpPower()
		local jumpVelocity = math.sqrt(jumpPower*2)*2.6

		for _,root in ipairs(selectedRoots) do
			if root and root.Parent and isGrounded(root) then
				root:ApplyImpulse(
					Vector3.new(
						0,
						root.AssemblyMass*jumpVelocity,
						0
					)
				)
			end
		end

		isJumpRequested = false
	end
end)
