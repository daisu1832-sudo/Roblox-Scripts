local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local ROCKET_ENABLED = false
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
screenGui.Enabled = false

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
	if not ROCKET_ENABLED then return end
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
	if not ROCKET_ENABLED then return end
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
	if not ROCKET_ENABLED then return end
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
	if not ROCKET_ENABLED then return end
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

--==================================================
-- LEOPA HUB / ROCKET SWITCH INTEGRATION
--==================================================

local function SetRocketEnabled(enabled)
	ROCKET_ENABLED = enabled == true

	if ROCKET_ENABLED then
		if screenGui then
			screenGui.Enabled = true
		end
		return
	end

	-- Stop active object control and restore state.
	pcall(function()
		stopControl()
	end)

	-- Clear transient input state.
	isJumpRequested = false
	activeStickTouch = nil
	activeCameraTouch = nil
	lastCameraTouchPos = nil

	pcall(function()
		resetKnob()
	end)

	-- Ensure camera is returned to normal.
	pcall(function()
		camera.CameraType = Enum.CameraType.Custom
	end)

	-- Hide the rocket GUI while keeping the original event connections alive,
	-- which allows the feature to be switched on again safely.
	if screenGui then
		screenGui.Enabled = false
	end
end

-- Start disabled. The Orion toggle below controls this.
SetRocketEnabled(false)

--==================================================
-- LEOPA HUB UI
--==================================================

local OrionLib = loadstring(game:HttpGet(
	"https://pastebin.com/raw/tcRN62qd"
))()

local Window = OrionLib:MakeWindow({
	Name = "Leopa Hub",
	HidePremium = true,
	SaveConfig = false,
	IntroEnabled = false,
})

local RocketTab = Window:MakeTab({
	Name = "🚀 ロケット",
	Icon = "",
	PremiumOnly = false
})

local PlayerTab = Window:MakeTab({
	Name = "😎 プレイヤー",
	Icon = "",
	PremiumOnly = false
})

local KickTab = Window:MakeTab({
	Name = "💀 キック",
	Icon = "",
	PremiumOnly = false
})


--==================================================
-- PLAYER SPEED
--==================================================

local SpeedPlayers = game:GetService("Players")
local SpeedRunService = game:GetService("RunService")
local SpeedPlayer = SpeedPlayers.LocalPlayer

local SelectedSpeed = 16
local SpeedEnabled = false
local SavedWalkSpeed = 16
local SpeedConnection = nil
local HadAirMovement = false

local function GetSpeedCharacter()
	return SpeedPlayer.Character
end

local function GetSpeedHumanoid()
	local character = GetSpeedCharacter()
	if not character then return nil end
	return character:FindFirstChildOfClass("Humanoid")
end

local function GetSpeedRoot()
	local character = GetSpeedCharacter()
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

local function ApplySpeed()
	if not SpeedEnabled then return end

	local humanoid = GetSpeedHumanoid()
	local root = GetSpeedRoot()

	if not humanoid or not root then
		return
	end

	local effectiveSpeed = SelectedSpeed * 3
	humanoid.WalkSpeed = effectiveSpeed

	local moveDirection = humanoid.MoveDirection
	local currentVelocity = root.AssemblyLinearVelocity
	local inAir = humanoid.FloorMaterial == Enum.Material.Air

	if moveDirection.Magnitude > 0.001 then
		-- Allow movement on the ground and while jumping.
		root.AssemblyLinearVelocity = Vector3.new(
			moveDirection.X * effectiveSpeed,
			currentVelocity.Y,
			moveDirection.Z * effectiveSpeed
		)

		if inAir then
			HadAirMovement = true
		end
	else
		if inAir then
			if HadAirMovement then
				-- The player was moving in the air and released movement:
				-- stop horizontal motion and drop.
				root.AssemblyLinearVelocity = Vector3.new(
					0,
					math.min(currentVelocity.Y, -35),
					0
				)
				HadAirMovement = false
			else
				-- Stationary jump:
				-- do NOT touch Y, so jumping works without running.
				root.AssemblyLinearVelocity = Vector3.new(
					0,
					currentVelocity.Y,
					0
				)
			end
		else
			HadAirMovement = false

			-- Strong ground stop.
			root.AssemblyLinearVelocity = Vector3.new(
				0,
				currentVelocity.Y,
				0
			)
		end
	end
end

local function StartSpeed()
	if SpeedEnabled then return end

	local humanoid = GetSpeedHumanoid()
	if humanoid then
		SavedWalkSpeed = humanoid.WalkSpeed
	end

	SpeedEnabled = true

	if SpeedConnection then
		SpeedConnection:Disconnect()
		SpeedConnection = nil
	end

	-- Run after the normal character update so the selected speed wins locally.
	SpeedConnection = SpeedRunService.Heartbeat:Connect(function()
		ApplySpeed()
	end)

	ApplySpeed()
end

local function StopSpeed()
	SpeedEnabled = false
	HadAirMovement = false

	if SpeedConnection then
		SpeedConnection:Disconnect()
		SpeedConnection = nil
	end

	local humanoid = GetSpeedHumanoid()
	if humanoid then
		humanoid.WalkSpeed = SavedWalkSpeed
	end
end

PlayerTab:AddSlider({
	Name = "走るスピード",
	Min = 1,
	Max = 100,
	Default = 16,
	Increment = 1,

	Callback = function(Value)
		SelectedSpeed = math.clamp(
			tonumber(Value) or 16,
			1,
			100
		)

		if SpeedEnabled then
			ApplySpeed()
		end
	end
})

PlayerTab:AddToggle({
	Name = "スピードスイッチ",
	Default = false,

	Callback = function(Value)
		if Value then
			StartSpeed()
		else
			StopSpeed()
		end
	end
})

SpeedPlayer.CharacterAdded:Connect(function(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)

	if not humanoid or not root then
		return
	end

	task.wait(0.25)

	if SpeedEnabled then
		humanoid.WalkSpeed = SelectedSpeed
	else
		SavedWalkSpeed = humanoid.WalkSpeed
	end
end)


--==================================================
-- PLAYER JUMP POWER
--==================================================

local SelectedJumpPower = 50
local JumpEnabled = false
local SavedJumpPower = nil
local SavedJumpHeight = nil
local SavedUseJumpPower = nil
local JumpConnection = nil

local function ApplyJumpPower()
	if not JumpEnabled then
		return
	end

	local humanoid = GetSpeedHumanoid()
	if not humanoid then
		return
	end

	humanoid.UseJumpPower = true
	humanoid.JumpPower = SelectedJumpPower * 2.5
end

local function StartJumpPower()
	if JumpEnabled then
		return
	end

	local humanoid = GetSpeedHumanoid()
	if not humanoid then
		return
	end

	-- Save the game's current/default jump settings only when
	-- the user actually turns the jump switch ON.
	SavedUseJumpPower = humanoid.UseJumpPower
	SavedJumpPower = humanoid.JumpPower
	SavedJumpHeight = humanoid.JumpHeight

	JumpEnabled = true
	ApplyJumpPower()

	if JumpConnection then
		JumpConnection:Disconnect()
		JumpConnection = nil
	end

	JumpConnection = SpeedRunService.Heartbeat:Connect(function()
		if JumpEnabled then
			ApplyJumpPower()
		end
	end)
end

local function StopJumpPower()
	if not JumpEnabled then
		return
	end

	JumpEnabled = false

	if JumpConnection then
		JumpConnection:Disconnect()
		JumpConnection = nil
	end

	local humanoid = GetSpeedHumanoid()

	if humanoid then
		-- Restore exactly what was present before the switch was enabled.
		if SavedUseJumpPower ~= nil then
			humanoid.UseJumpPower = SavedUseJumpPower
		end

		if SavedJumpPower ~= nil then
			humanoid.JumpPower = SavedJumpPower
		end

		if SavedJumpHeight ~= nil then
			humanoid.JumpHeight = SavedJumpHeight
		end
	end

	SavedUseJumpPower = nil
	SavedJumpPower = nil
	SavedJumpHeight = nil
end

PlayerTab:AddSlider({
	Name = "ジャンプ力",
	Min = 1,
	Max = 100,
	Default = 50,
	Increment = 1,

	Callback = function(Value)
		SelectedJumpPower = math.clamp(
			tonumber(Value) or 50,
			1,
			100
		)

		-- Moving the slider alone does NOT change the player's jump.
		if JumpEnabled then
			ApplyJumpPower()
		end
	end
})

PlayerTab:AddToggle({
	Name = "ジャンプスイッチ",
	Default = false,

	Callback = function(Value)
		if Value then
			StartJumpPower()
		else
			StopJumpPower()
		end
	end
})

-- On respawn, leave the game's default jump settings untouched while OFF.
-- Only reapply the selected value if the jump switch was already ON.
SpeedPlayer.CharacterAdded:Connect(function(character)
	if not JumpEnabled then
		return
	end

	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	task.wait(0.25)

	SavedUseJumpPower = humanoid.UseJumpPower
	SavedJumpPower = humanoid.JumpPower
	SavedJumpHeight = humanoid.JumpHeight

	ApplyJumpPower()
end)


-- Keep the selected jump power effective even while the speed switch is ON.
-- This only adds vertical velocity; it does not alter horizontal speed.
UserInputService.JumpRequest:Connect(function()
	if not JumpEnabled then
		return
	end

	local humanoid = GetSpeedHumanoid()
	local root = GetSpeedRoot()

	if not humanoid or not root then
		return
	end

	humanoid.UseJumpPower = true
	humanoid.JumpPower = SelectedJumpPower

	if humanoid.FloorMaterial ~= Enum.Material.Air then
		local velocity = root.AssemblyLinearVelocity

		local effectiveJumpPower = SelectedJumpPower * 2.5

		root.AssemblyLinearVelocity = Vector3.new(
			velocity.X,
			effectiveJumpPower,
			velocity.Z
		)
	end
end)


--==================================================
-- INFINITE JUMP
--==================================================

local InfiniteJumpEnabled = false
local InfiniteJumpConnection = nil

local function StartInfiniteJump()
	if InfiniteJumpEnabled then
		return
	end

	InfiniteJumpEnabled = true

	if InfiniteJumpConnection then
		InfiniteJumpConnection:Disconnect()
		InfiniteJumpConnection = nil
	end

	InfiniteJumpConnection = UserInputService.JumpRequest:Connect(function()
		if not InfiniteJumpEnabled then
			return
		end

		local humanoid = GetSpeedHumanoid()
		local root = GetSpeedRoot()

		if not humanoid or not root then
			return
		end

		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

		-- If the jump-power switch is also enabled, use its selected power
		-- for every infinite jump instead of falling back to the game's default jump.
		if JumpEnabled then
			local effectiveJumpPower = SelectedJumpPower * 2.5

			humanoid.UseJumpPower = true
			humanoid.JumpPower = effectiveJumpPower

			local velocity = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(
				velocity.X,
				effectiveJumpPower,
				velocity.Z
			)
		end
	end)
end

local function StopInfiniteJump()
	InfiniteJumpEnabled = false

	if InfiniteJumpConnection then
		InfiniteJumpConnection:Disconnect()
		InfiniteJumpConnection = nil
	end
end

PlayerTab:AddToggle({
	Name = "無限ジャンプスイッチ",
	Default = false,

	Callback = function(Value)
		if Value then
			StartInfiniteJump()
		else
			StopInfiniteJump()
		end
	end
})


--==================================================
-- THIRD PERSON CAMERA
--==================================================

local ThirdPersonEnabled = false
local SavedCameraMode = nil
local SavedMinZoom = nil
local SavedMaxZoom = nil

local THIRD_PERSON_DISTANCE = 12

local function StartThirdPerson()
	if ThirdPersonEnabled then
		return
	end

	ThirdPersonEnabled = true

	-- Save the player's current camera settings so OFF can restore them.
	SavedCameraMode = SpeedPlayer.CameraMode
	SavedMinZoom = SpeedPlayer.CameraMinZoomDistance
	SavedMaxZoom = SpeedPlayer.CameraMaxZoomDistance

	-- Lock the player into a normal third-person distance.
	SpeedPlayer.CameraMode = Enum.CameraMode.Classic
	SpeedPlayer.CameraMinZoomDistance = THIRD_PERSON_DISTANCE
	SpeedPlayer.CameraMaxZoomDistance = THIRD_PERSON_DISTANCE
end

local function StopThirdPerson()
	if not ThirdPersonEnabled then
		return
	end

	ThirdPersonEnabled = false

	if SavedCameraMode ~= nil then
		SpeedPlayer.CameraMode = SavedCameraMode
	end

	if SavedMinZoom ~= nil then
		SpeedPlayer.CameraMinZoomDistance = SavedMinZoom
	end

	if SavedMaxZoom ~= nil then
		SpeedPlayer.CameraMaxZoomDistance = SavedMaxZoom
	end

	SavedCameraMode = nil
	SavedMinZoom = nil
	SavedMaxZoom = nil
end

PlayerTab:AddToggle({
	Name = "三人称スイッチ",
	Default = false,

	Callback = function(Value)
		if Value then
			StartThirdPerson()
		else
			StopThirdPerson()
		end
	end
})

RocketTab:AddToggle({
	Name = "ロケットスイッチ",
	Default = false,

	Callback = function(Value)
		SetRocketEnabled(Value)
	end
})


--==================================================
-- 💀 キックタブ - ドリフトキック機能
-- 元スクリプトの独立Window/チャット送信は作らず、
-- 既存Leopa Hubの 💀 キック タブへ機能を統合。
--==================================================

local Players2 = game:GetService("Players")
local LocalPlayer2 = Players2.LocalPlayer
local Workspace2 = game:GetService("Workspace")
local ReplicatedStorage2 = game:GetService("ReplicatedStorage")
local RunService2 = game:GetService("RunService")

local driftRunning = false
local selectedActionTargetName = ""
local playerMap = {}
local currentLoopId = 0

-- Drift Kick用変数
local driftRadius = 19
local driftSpeed = 12
local driftHeightOffset = 0
local driftAngle = 0

-- 上下キック用変数（相手のみ動かす）
local upDownKickEnabled = false
local upDownKickRange = 6
local upDownKickSpeed = 3
local upDownKickTime = 0

-- グラブ量（1秒あたりの実行回数）
local grabsPerSecond = 30

-- ==========================================
-- ラグ
-- ==========================================
local GrabEvents = ReplicatedStorage2:FindFirstChild("GrabEvents")

local lineLagThread = nil
local lineLagEnabled = false

local function startLineLag()
    if lineLagEnabled then return end
    lineLagEnabled = true
    lineLagThread = coroutine.create(function()
        if not GrabEvents then return end
        local createLine = GrabEvents:FindFirstChild("CreateGrabLine")
        if not createLine then return end
        while lineLagEnabled do
            local spawnLocation = Workspace2:FindFirstChild("SpawnLocation") or Workspace2:FindFirstChild("Spawn") or (LocalPlayer2.Character and LocalPlayer2.Character:FindFirstChild("HumanoidRootPart"))
            if spawnLocation then
                local randomX = math.random(-1e9, 1e9)
                local randomZ = math.random(-1e9, 1e9)
                local directions = {
                    CFrame.new(randomX, 0, randomZ),
                    CFrame.new(-randomX, 0, -randomZ),
                    CFrame.new(randomX, 0, -randomZ),
                    CFrame.new(-randomX, 0, randomZ)
                }
                for _, pos in pairs(directions) do
                    pcall(function() createLine:FireServer(spawnLocation, pos) end)
                end
            end
            task.wait()
        end
    end)
    coroutine.resume(lineLagThread)
end

local function stopLineLag()
    lineLagEnabled = false
    if lineLagThread then
        pcall(function() coroutine.close(lineLagThread) end)
        lineLagThread = nil
    end
end

-- ==========================================
-- プレイヤーリスト
-- ==========================================
local function getPlayerList()
    local names = {}
    playerMap = {}
    for _, player in ipairs(Players2:GetPlayers()) do
        if player ~= LocalPlayer2 then
            local displayStr = player.DisplayName .. " (@" .. player.Name .. ")"
            table.insert(names, displayStr)
            playerMap[displayStr] = player.Name
        end
    end
    if #names == 0 then table.insert(names, "(None)") end
    return names
end

-- ==========================================
-- ターゲット選択
-- ==========================================
local targetDropdown = KickTab:AddDropdown({
    Name = "ターゲット選択",
    Default = "",
    Options = getPlayerList(),
    Callback = function(val)
        selectedActionTargetName = playerMap[val] or ""
    end
})

-- ==========================================
-- プレイヤー更新
-- ==========================================
KickTab:AddButton({
    Name = "🔄 プレイヤー一覧を更新",
    Callback = function()
        targetDropdown:Refresh(getPlayerList(), true)
        OrionLib:MakeNotification({
            Name = "[drift kick by tanpopo]",
            Content = "プレイヤー一覧を更新しました",
            Time = 2
        })
    end
})

-- ==========================================
-- 回転速度スライダー
-- ==========================================
KickTab:AddSlider({
    Name = "回転速度",
    Min = 1,
    Max = 100,
    Default = 12,
    Color = Color3.fromRGB(255, 255, 255),
    Increment = 1,
    ValueName = "",
    Callback = function(value)
        driftSpeed = value
    end
})

-- ==========================================
-- グラブ量スライダー（最大150回/秒）
-- ==========================================
KickTab:AddSlider({
    Name = "グラブ量（最大150回/秒）",
    Min = 1,
    Max = 150,
    Default = 30,
    Color = Color3.fromRGB(255, 200, 0),
    Increment = 1,
    ValueName = "回/秒",
    Callback = function(value)
        grabsPerSecond = value
    end
})

-- ==========================================
-- 上下キック設定（相手のみ動かす）
-- ==========================================
KickTab:AddToggle({
    Name = "上下キック（相手を上下に動かす）",
    Default = false,
    Callback = function(Value)
        upDownKickEnabled = Value
        if Value then
            upDownKickTime = 0
        end
    end
})

KickTab:AddSlider({
    Name = "上下キックの振れ幅",
    Min = 1,
    Max = 50,
    Default = 6,
    Color = Color3.fromRGB(255, 255, 255),
    Increment = 1,
    ValueName = "",
    Callback = function(value)
        upDownKickRange = value
    end
})

KickTab:AddSlider({
    Name = "上下キックの速度",
    Min = 1,
    Max = 20,
    Default = 3,
    Color = Color3.fromRGB(255, 255, 255),
    Increment = 1,
    ValueName = "",
    Callback = function(value)
        upDownKickSpeed = value
    end
})

-- ==========================================
-- ドリフトキック
-- ==========================================
KickTab:AddToggle({
    Name = "ドリフトキック",
    Default = false,
    Callback = function(v)
        driftRunning = v
        currentLoopId = currentLoopId + 1
        local myLoopId = currentLoopId

        if not v then
            stopLineLag()
            return
        end

        startLineLag()

        local target = Players2:FindFirstChild(selectedActionTargetName)
        if target and target ~= LocalPlayer2 then
            local blobman = nil
            local spawned = Workspace2:FindFirstChild(LocalPlayer2.Name .. "SpawnedInToys")
            if spawned then blobman = spawned:FindFirstChild("CreatureBlobman") end

            if not blobman then
                local mt = ReplicatedStorage2:FindFirstChild("MenuToys")
                local st = mt and mt:FindFirstChild("SpawnToyRemoteFunction")
                if st then
                    local myRoot = LocalPlayer2.Character and LocalPlayer2.Character:FindFirstChild("HumanoidRootPart")
                    local spawnCF = myRoot and (myRoot.CFrame + Vector3.new(0, 5, 0)) or CFrame.new(0, 50, 0)
                    st:InvokeServer("CreatureBlobman", spawnCF, Vector3.zero)
                    task.wait(0.8)
                    spawned = Workspace2:FindFirstChild(LocalPlayer2.Name .. "SpawnedInToys")
                    if spawned then blobman = spawned:FindFirstChild("CreatureBlobman") end
                end
            end

            if not blobman then
                for _, obj in ipairs(Workspace2:GetChildren()) do
                    if obj.Name == "CreatureBlobman" and obj:FindFirstChild("VehicleSeat") then
                        blobman = obj
                        break
                    end
                end
            end

            if blobman then
                local scriptObj = blobman:FindFirstChild("BlobmanSeatAndOwnerScript") or blobman:FindFirstChild("BlobmanSeatAndOwnerScript[old]")
                local grabRemote = scriptObj and scriptObj:FindFirstChild("CreatureGrab") or blobman:FindFirstChild("CreatureGrab", true)
                local dropRemote = scriptObj and scriptObj:FindFirstChild("CreatureDrop") or blobman:FindFirstChild("CreatureDrop", true)
                local lDet = blobman:FindFirstChild("LeftDetector")
                local rDet = blobman:FindFirstChild("RightDetector")
                local lWeld = lDet and (lDet:FindFirstChild("LeftWeld") or lDet:FindFirstChildWhichIsA("Weld") or lDet:FindFirstChildWhichIsA("JointInstance") or lDet:FindFirstChild("RigidConstraint"))
                local rWeld = rDet and (rDet:FindFirstChild("RightWeld") or rDet:FindFirstChildWhichIsA("Weld") or rDet:FindFirstChildWhichIsA("JointInstance") or rDet:FindFirstChild("RigidConstraint"))
                local seat = blobman:FindFirstChild("VehicleSeat")
                local hum = LocalPlayer2.Character and LocalPlayer2.Character:FindFirstChild("Humanoid")

                if seat and hum then
                    if seat.Occupant ~= hum then
                        LocalPlayer2.Character.HumanoidRootPart.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
                        task.wait(0.2)
                        seat:Sit(hum)
                        task.wait(0.5)
                    end
                end

                local GE = ReplicatedStorage2:FindFirstChild("GrabEvents")
                if GE and grabRemote and dropRemote and ((lDet and lWeld) or (rDet and rWeld)) then
                    OrionLib:MakeNotification({
                        Name = "[drift kick by tanpopo]",
                        Content = "ドリフトキック開始（ラグ発動中）",
                        Time = 3
                    })

                    task.spawn(function()
                        local blobRoot = blobman:FindFirstChild("HumanoidRootPart") or blobman.PrimaryPart
                        local Det = rDet or lDet
                        local Weld = rWeld or lWeld

                        while driftRunning do
                            if myLoopId ~= currentLoopId then break end
                            if not target or not target.Parent then break end

                            local tChar = target.Character
                            local tHum = tChar and tChar:FindFirstChild("Humanoid")
                            local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")

                            if tChar and tRoot and tHum and tHum.Health > 0 then
                                local bringStart = tick()
                                while tick() - bringStart < 0.35 do
                                    if myLoopId ~= currentLoopId or not driftRunning or not blobman or not blobman.Parent then break end
                                    if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                                        local currentTRoot = target.Character.HumanoidRootPart
                                        blobRoot.CFrame = currentTRoot.CFrame
                                        blobRoot.AssemblyLinearVelocity = Vector3.zero
                                        pcall(function()
                                            if Det then grabRemote:FireServer(Det, currentTRoot, Weld) end
                                            if GE.CreateGrabLine then GE.CreateGrabLine:FireServer(currentTRoot, Vector3.zero, currentTRoot.Position, false) end
                                            if GE.SetNetworkOwner then GE.SetNetworkOwner:FireServer(currentTRoot, blobRoot.CFrame) end
                                        end)
                                    end
                                    RunService2.Heartbeat:Wait()
                                end

                                if myLoopId ~= currentLoopId or not driftRunning or not blobman or not blobman.Parent then break end

                                tChar = target.Character
                                tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
                                tHum = tChar and tChar:FindFirstChild("Humanoid")

                                if tChar and tRoot and tHum and tHum.Health > 0 then
                                    local SavedPos = tRoot.CFrame
                                    local targetCenterCFrame = SavedPos + Vector3.new(0, 30, 0)
                                    local lastTime = tick()
                                    local lastDropTime = tick()
                                    local dropCount = 0

                                    -- グラブ量制御用
                                    local grabAccumulator = 0
                                    local grabInterval = 1 / math.max(1, grabsPerSecond)

                                    while driftRunning and blobman and blobman.Parent do
                                        if myLoopId ~= currentLoopId then break end
                                        if not target or not target.Parent then break end

                                        tChar = target.Character
                                        tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
                                        tHum = tChar and tChar:FindFirstChild("Humanoid")

                                        if not tChar or not tRoot or not tHum or tHum.Health <= 0 then break end

                                        if dropCount < 2 and (tick() - lastDropTime) > 0.8 then
                                            dropCount = dropCount + 1
                                            pcall(function()
                                                local currentWeld = Det:FindFirstChild("RightWeld") or Det:FindFirstChild("LeftWeld") or Det:FindFirstChildWhichIsA("Weld") or Det:FindFirstChildWhichIsA("JointInstance") or Det:FindFirstChild("RigidConstraint")
                                                if currentWeld then dropRemote:FireServer(currentWeld) end
                                                if GE.DestroyGrabLine then GE.DestroyGrabLine:FireServer(tRoot) end
                                            end)
                                            blobRoot.CFrame = SavedPos
                                            blobRoot.AssemblyLinearVelocity = Vector3.zero
                                            RunService2.Heartbeat:Wait()

                                            if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                                                local currentTRoot = target.Character.HumanoidRootPart
                                                blobRoot.CFrame = currentTRoot.CFrame
                                                blobRoot.AssemblyLinearVelocity = Vector3.zero
                                                pcall(function()
                                                    if Det then grabRemote:FireServer(Det, currentTRoot, Weld) end
                                                    if GE.CreateGrabLine then GE.CreateGrabLine:FireServer(currentTRoot, Vector3.zero, currentTRoot.Position, false) end
                                                    if GE.SetNetworkOwner then GE.SetNetworkOwner:FireServer(currentTRoot, blobRoot.CFrame) end
                                                end)
                                            end
                                            lastTime = tick()
                                            lastDropTime = tick()
                                            continue
                                        end

                                        if tRoot and tHum and tHum.Health > 0 and blobRoot then
                                            local currentTime = tick()
                                            local dt = currentTime - lastTime
                                            lastTime = currentTime
                                            driftAngle = driftAngle + (driftSpeed * dt)

                                            -- ★ 上下キック計算（相手のみ）★
                                            local verticalOffset = 0
                                            if upDownKickEnabled then
                                                upDownKickTime = upDownKickTime + dt
                                                verticalOffset = math.sin(upDownKickTime * upDownKickSpeed) * upDownKickRange
                                            end

                                            -- Blobmanは固定位置（上下動かさない）
                                            local offsetX = math.cos(driftAngle) * driftRadius
                                            local offsetZ = math.sin(driftAngle) * driftRadius
                                            local blobPos = targetCenterCFrame.Position + Vector3.new(offsetX, driftHeightOffset, offsetZ)

                                            blobRoot.CFrame = CFrame.new(blobPos, targetCenterCFrame.Position)
                                            blobRoot.AssemblyLinearVelocity = Vector3.zero
                                            blobRoot.AssemblyAngularVelocity = Vector3.zero

                                            -- ★ 相手プレイヤーだけ上下に動かす ★
                                            local targetPos = targetCenterCFrame.Position + Vector3.new(0, verticalOffset, 0)
                                            tRoot.CFrame = CFrame.new(targetPos, targetPos + targetCenterCFrame.LookVector)
                                            tRoot.AssemblyLinearVelocity = Vector3.zero
                                            tRoot.AssemblyAngularVelocity = Vector3.zero

                                            -- グラブ量制御
                                            grabAccumulator = grabAccumulator + dt
                                            grabInterval = 1 / math.max(1, grabsPerSecond)

                                            local fireCount = 0
                                            while grabAccumulator >= grabInterval and fireCount < 150 do
                                                grabAccumulator = grabAccumulator - grabInterval
                                                fireCount = fireCount + 1
                                                pcall(function()
                                                    tHum.PlatformStand = true
                                                    tHum.Sit = true
                                                    if GE.SetNetworkOwner then GE.SetNetworkOwner:FireServer(tRoot, tRoot.CFrame) end
                                                    local currentWeld = Det:FindFirstChild("RightWeld") or Det:FindFirstChild("LeftWeld") or Det:FindFirstChildWhichIsA("Weld") or Det:FindFirstChildWhichIsA("JointInstance") or Det:FindFirstChild("RigidConstraint")
                                                    if currentWeld then dropRemote:FireServer(currentWeld) end
                                                    if GE.DestroyGrabLine then GE.DestroyGrabLine:FireServer(tRoot) end
                                                    if Det then grabRemote:FireServer(Det, tRoot, Weld) end
                                                    if GE.CreateGrabLine then GE.CreateGrabLine:FireServer(tRoot, Vector3.zero, tRoot.Position, false) end
                                                end)
                                            end
                                        else
                                            break
                                        end
                                        RunService2.Heartbeat:Wait()
                                    end

                                    if not driftRunning or myLoopId ~= currentLoopId then
                                        if blobRoot and SavedPos then
                                            pcall(function()
                                                local currentWeld = Det:FindFirstChild("RightWeld") or Det:FindFirstChild("LeftWeld") or Det:FindFirstChildWhichIsA("Weld") or Det:FindFirstChildWhichIsA("JointInstance") or Det:FindFirstChild("RigidConstraint")
                                                if currentWeld then dropRemote:FireServer(currentWeld) end
                                                if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") and GE.DestroyGrabLine then
                                                    GE.DestroyGrabLine:FireServer(target.Character.HumanoidRootPart)
                                                end
                                            end)
                                            blobRoot.CFrame = SavedPos
                                            blobRoot.AssemblyLinearVelocity = Vector3.zero
                                        end
                                        break
                                    end
                                end
                            end
                            RunService2.Heartbeat:Wait()
                        end
                    end)
                else
                    OrionLib:MakeNotification({
                        Name = "[drift kick by tanpopo]",
                        Content = "必要なRemoteEventやDetectorが見つかりません",
                        Time = 5
                    })
                    driftRunning = false
                    stopLineLag()
                end
            else
                OrionLib:MakeNotification({
                    Name = "[drift kick by tanpopo]",
                    Content = "Blobmanの取得・生成に失敗しました",
                    Time = 3
                })
                driftRunning = false
                stopLineLag()
            end
        else
            OrionLib:MakeNotification({
                Name = "[drift kick by tanpopo]",
                Content = "ターゲットが無効です",
                Time = 3
            })
            driftRunning = false
            stopLineLag()
        end
    end
})

-- ==========================================
-- 停止ボタン
-- ==========================================
KickTab:AddButton({
    Name = "🛑 ドリフトキック停止",
    Callback = function()
        local wasRunning = driftRunning
        if driftRunning then
            driftRunning = false
            currentLoopId = currentLoopId + 1
        end
        stopLineLag()

        if wasRunning then
            OrionLib:MakeNotification({
                Name = "[drift kick by tanpopo]",
                Content = "ドリフトキック停止 + ラグ停止",
                Time = 3
            })
        else
            OrionLib:MakeNotification({
                Name = "[drift kick by tanpopo]",
                Content = "ラグを停止しました（ドリフトキックは動作していません）",
                Time = 3
            })
        end
    end
})

OrionLib:Init()

task.wait(0.5)

local function StyleRocketTab()
	local gui =
		(gethui and gethui())
		or game:GetService("CoreGui")

	for _, object in ipairs(gui:GetDescendants()) do
		if (
			object:IsA("TextLabel")
			or object:IsA("TextButton")
		) then
			if object.Text == "🚀 ロケット"
				or object.Text == "😎 プレイヤー"
				or object.Text == "💀 キック" then
				object.TextSize = 22
				object.Position =
					object.Position
					+ UDim2.fromOffset(-9, 0)
			end
		end
	end
end

StyleRocketTab()
