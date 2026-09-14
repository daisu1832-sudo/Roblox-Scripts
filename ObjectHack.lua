local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local TweenService=game:GetService("TweenService")
local TextChatService=game:GetService("TextChatService")

local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local camera=workspace.CurrentCamera

task.spawn(function()
	local textChannels=TextChatService:WaitForChild("TextChannels")
	local generalChannel=textChannels:WaitForChild("RBXGeneral")
	task.wait(1)
	for i=1,5 do
		generalChannel:SendAsync("ObjectHackが起動しました。")
		task.wait(1)
	end
end)

local controlling=false
local flying=false
local currentRoot=nil
local mover=nil
local flyFixedCFrame=nil

local RAY_DISTANCE=60
local CURRENT_SPEED=20
local CAMERA_DISTANCE=20

local cameraYaw=0
local cameraPitch=-20
local currentYaw=0
local currentPitch=-20

local CAMERA_SMOOTHNESS=30
local CAMERA_SENSITIVITY=1.0

local PLAYER_FIXED_POSITION=Vector3.new(460.4,131.4,202.7)
local savedPlayerCFrame=nil

local function findCenterTarget()
	local cam=workspace.CurrentCamera
	if not cam then
		return nil
	end

	local origin=cam.CFrame.Position
	local direction=cam.CFrame.LookVector*RAY_DISTANCE

	local params=RaycastParams.new()
	params.FilterType=Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances={player.Character}
	params.IgnoreWater=true

	local result=workspace:Raycast(origin,direction,params)

	if not result then
		return nil
	end

	local part=result.Instance

	if not part or not part:IsA("BasePart") then
		return nil
	end

	if part.Anchored then
		return nil
	end

	return part
end

local function updateThirdPersonCamera(dt)
	if not currentRoot then
		return
	end

	currentYaw=currentYaw+(cameraYaw-currentYaw)*math.clamp(dt*CAMERA_SMOOTHNESS,0,1)
	currentPitch=currentPitch+(cameraPitch-currentPitch)*math.clamp(dt*CAMERA_SMOOTHNESS,0,1)

	local yawRad=math.rad(currentYaw)
	local pitchRad=math.rad(currentPitch)

	local offset=Vector3.new(
		math.cos(pitchRad)*math.sin(yawRad),
		math.sin(pitchRad),
		math.cos(pitchRad)*math.cos(yawRad)
	)*CAMERA_DISTANCE

	local targetPos=currentRoot.Position

	camera.CFrame=CFrame.lookAt(
		targetPos+offset,
		targetPos
	)
end

local MAX_FORCE=100000
local STOP_FORCE=10000000

local function destroyMover()
	if mover then
		mover:Destroy()
		mover=nil
	end
end

local function startControl()
	local target=findCenterTarget()

	if not target then
		return false
	end

	currentRoot=target.AssemblyRootPart or target

	local char=player.Character

	if char then
		local hrp=char:FindFirstChild("HumanoidRootPart")

		if hrp then
			savedPlayerCFrame=hrp.CFrame
			hrp.CFrame=CFrame.new(PLAYER_FIXED_POSITION)
			hrp.AssemblyLinearVelocity=Vector3.zero
			hrp.AssemblyAngularVelocity=Vector3.zero
		end
	end

	destroyMover()

	mover=Instance.new("BodyVelocity")
	mover.Name="GrabMoveVelocity"
	mover.MaxForce=Vector3.new(MAX_FORCE,MAX_FORCE,MAX_FORCE)
	mover.P=12500
	mover.Velocity=Vector3.zero
	mover.Parent=currentRoot

	flyFixedCFrame=nil

	cameraYaw=0
	cameraPitch=-20
	currentYaw=0
	currentPitch=-20

	camera.CameraType=Enum.CameraType.Scriptable

	updateThirdPersonCamera(0)

	controlling=true

	return true
end

local function stopControl()
	destroyMover()

	if savedPlayerCFrame then
		local char=player.Character

		if char then
			local hrp=char:FindFirstChild("HumanoidRootPart")

			if hrp then
				hrp.CFrame=savedPlayerCFrame
				hrp.AssemblyLinearVelocity=Vector3.zero
				hrp.AssemblyAngularVelocity=Vector3.zero
			end
		end

		savedPlayerCFrame=nil
	end

	controlling=false
	flying=false
	flyFixedCFrame=nil
	currentRoot=nil

	camera.CameraType=Enum.CameraType.Custom
end

local screenGui=Instance.new("ScreenGui")
screenGui.Name="GrabMoveGui"
screenGui.ResetOnSpawn=false
screenGui.Parent=playerGui

local toggleButton=Instance.new("TextButton")
toggleButton.Size=UDim2.new(0,110,0,40)
toggleButton.Position=UDim2.new(1,-130,0,20)
toggleButton.Text="操作: OFF"
toggleButton.BackgroundColor3=Color3.fromRGB(60,60,60)
toggleButton.TextColor3=Color3.fromRGB(255,255,255)
toggleButton.Font=Enum.Font.GothamBold
toggleButton.TextSize=15

local btnCorner=Instance.new("UICorner")
btnCorner.CornerRadius=UDim.new(0,8)
btnCorner.Parent=toggleButton
toggleButton.Parent=screenGui

local subButtonContainer=Instance.new("Frame")
subButtonContainer.Size=UDim2.new(0,200,0,40)
subButtonContainer.Position=UDim2.new(1,-345,0,20)
subButtonContainer.BackgroundTransparency=1
subButtonContainer.Visible=false
subButtonContainer.Parent=screenGui

local listLayout=Instance.new("UIListLayout")
listLayout.FillDirection=Enum.FillDirection.Horizontal
listLayout.HorizontalAlignment=Enum.HorizontalAlignment.Right
listLayout.VerticalAlignment=Enum.VerticalAlignment.Center
listLayout.SortOrder=Enum.SortOrder.LayoutOrder
listLayout.Padding=UDim.new(0,10)
listLayout.Parent=subButtonContainer

local speedBox=Instance.new("TextBox")
speedBox.Size=UDim2.new(0,80,0,40)
speedBox.Text=tostring(CURRENT_SPEED)
speedBox.PlaceholderText="速度"
speedBox.BackgroundColor3=Color3.fromRGB(50,50,50)
speedBox.TextColor3=Color3.fromRGB(255,255,255)
speedBox.Font=Enum.Font.GothamBold
speedBox.TextSize=14
speedBox.ClearTextOnFocus=false
speedBox.LayoutOrder=1

local sBoxCorner=Instance.new("UICorner")
sBoxCorner.CornerRadius=UDim.new(0,8)
sBoxCorner.Parent=speedBox
speedBox.Parent=subButtonContainer

speedBox.FocusLost:Connect(function()
	local val=tonumber(speedBox.Text)

	if val then
		CURRENT_SPEED=math.clamp(val,1,1000)
		speedBox.Text=tostring(CURRENT_SPEED)
	else
		speedBox.Text=tostring(CURRENT_SPEED)
	end
end)

local flyButton=Instance.new("TextButton")
flyButton.Size=UDim2.new(0,100,0,40)
flyButton.Text="飛行: OFF"
flyButton.BackgroundColor3=Color3.fromRGB(60,60,60)
flyButton.TextColor3=Color3.fromRGB(255,255,255)
flyButton.Font=Enum.Font.GothamBold
flyButton.TextSize=15
flyButton.LayoutOrder=2

local flyCorner=Instance.new("UICorner")
flyCorner.CornerRadius=UDim.new(0,8)
flyCorner.Parent=flyButton
flyButton.Parent=subButtonContainer

local flyInputBlock=Instance.new("Frame")
flyInputBlock.Name="FlyInputBlock"
flyInputBlock.Size=UDim2.new(0,180,0,180)
flyInputBlock.Position=UDim2.new(1,-200,1,-200)
flyInputBlock.BackgroundTransparency=1
flyInputBlock.BorderSizePixel=0
flyInputBlock.Active=true
flyInputBlock.Selectable=false
flyInputBlock.ZIndex=100
flyInputBlock.Visible=false
flyInputBlock.Parent=screenGui

local stickBase=Instance.new("Frame")
stickBase.Size=UDim2.new(0,90,0,90)
stickBase.Position=UDim2.new(0,40,1,-150)
stickBase.BackgroundColor3=Color3.fromRGB(40,40,40)
stickBase.BackgroundTransparency=0.4
stickBase.Visible=false

local baseCorner=Instance.new("UICorner")
baseCorner.CornerRadius=UDim.new(1,0)
baseCorner.Parent=stickBase
stickBase.Parent=screenGui

local stickKnob=Instance.new("Frame")
stickKnob.Size=UDim2.new(0,40,0,40)
stickKnob.Position=UDim2.new(0.5,-20,0.5,-20)
stickKnob.BackgroundColor3=Color3.fromRGB(200,200,200)

local knobCorner=Instance.new("UICorner")
knobCorner.CornerRadius=UDim.new(1,0)
knobCorner.Parent=stickKnob
stickKnob.Parent=stickBase

local stickRadius=45
local stickCenter=Vector2.new(45,45)
local stickInput=Vector2.new(0,0)
local activeStickTouch=nil

local function updateKnob(delta)
	local clamped=delta

	if clamped.Magnitude>stickRadius then
		clamped=clamped.Unit*stickRadius
	end

	stickKnob.Position=UDim2.new(
		0.5,
		clamped.X-20,
		0.5,
		clamped.Y-20
	)

	stickInput=Vector2.new(
		clamped.X/stickRadius,
		clamped.Y/stickRadius
	)
end

local function resetKnob()
	stickKnob.Position=UDim2.new(0.5,-20,0.5,-20)
	stickInput=Vector2.new(0,0)
end

stickBase.InputBegan:Connect(function(input)
	if not controlling then
		return
	end

	if input.UserInputType==Enum.UserInputType.Touch
		or input.UserInputType==Enum.UserInputType.MouseButton1 then

		activeStickTouch=input

		local pos=input.Position
		local basePos=stickBase.AbsolutePosition

		updateKnob(
			Vector2.new(pos.X,pos.Y)
			-basePos
			-stickCenter
		)
	end
end)

local activeCameraTouch=nil
local lastCameraTouchPos=nil
local MIN_PITCH=-80
local MAX_PITCH=80

UserInputService.InputBegan:Connect(function(input,gameProcessed)
	if not controlling then
		return
	end

	if input.UserInputType~=Enum.UserInputType.Touch
		and input.UserInputType~=Enum.UserInputType.MouseButton1 then
		return
	end

	local screenWidth=camera.ViewportSize.X

	if input.Position.X<screenWidth*0.5 then
		return
	end

	activeCameraTouch=input

	lastCameraTouchPos=Vector2.new(
		input.Position.X,
		input.Position.Y
	)
end)

UserInputService.InputChanged:Connect(function(input)
	if not controlling then
		return
	end

	if activeStickTouch==input
		and (
			input.UserInputType==Enum.UserInputType.Touch
			or input.UserInputType==Enum.UserInputType.MouseMovement
		) then

		local pos=input.Position
		local basePos=stickBase.AbsolutePosition

		updateKnob(
			Vector2.new(pos.X,pos.Y)
			-basePos
			-stickCenter
		)
	end

	if activeCameraTouch==input
		and (
			input.UserInputType==Enum.UserInputType.Touch
			or input.UserInputType==Enum.UserInputType.MouseMovement
		) then

		local pos=Vector2.new(
			input.Position.X,
			input.Position.Y
		)

		local delta=pos-lastCameraTouchPos

		lastCameraTouchPos=pos

		cameraYaw=cameraYaw-delta.X*CAMERA_SENSITIVITY

		cameraPitch=math.clamp(
			cameraPitch+delta.Y*CAMERA_SENSITIVITY,
			MIN_PITCH,
			MAX_PITCH
		)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if activeStickTouch==input then
		activeStickTouch=nil
		resetKnob()
	end

	if activeCameraTouch==input then
		activeCameraTouch=nil
		lastCameraTouchPos=nil
	end
end)

local isJumpRequested=false

ContextActionService:BindAction(
	"GrabMoveJumpKey",
	function(actionName,inputState,inputObject)
		if not controlling then
			return Enum.ContextActionResult.Pass
		end

		if inputState==Enum.UserInputState.Begin then
			isJumpRequested=true
		elseif inputState==Enum.UserInputState.End then
			isJumpRequested=false
		end

		return Enum.ContextActionResult.Sink
	end,
	false,
	Enum.KeyCode.Space
)

local function getPlayerJumpPower()
	local char=player.Character

	if not char then
		return 50
	end

	local humanoid=char:FindFirstChildOfClass("Humanoid")

	if humanoid then
		return humanoid.JumpPower
	end

	return 50
end

local function isGrounded(part)
	local params=RaycastParams.new()
	params.FilterType=Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances={
		player.Character,
		part
	}

	local result=workspace:Raycast(
		part.Position,
		Vector3.new(0,-(part.Size.Y*0.5+0.6),0),
		params
	)

	return result~=nil
end

toggleButton.MouseButton1Click:Connect(function()
	if not controlling then
		local ok=startControl()

		if ok then
			toggleButton.Text="操作: ON"
			subButtonContainer.Visible=true
			stickBase.Visible=true

			flyInputBlock.Visible=true
		else
			toggleButton.Text="対象なし"
			task.wait(1)
			toggleButton.Text="操作: OFF"
		end
	else
		stopControl()

		toggleButton.Text="操作: OFF"
		flyButton.Text="飛行: OFF"
		flyButton.BackgroundColor3=Color3.fromRGB(60,60,60)

		flyInputBlock.Visible=false

		subButtonContainer.Visible=false
		stickBase.Visible=false

		resetKnob()
	end
end)

flyButton.MouseButton1Click:Connect(function()
	if not controlling then
		return
	end

	flying=not flying

	if flying then
		flyFixedCFrame=currentRoot.CFrame
		currentRoot.AssemblyAngularVelocity=Vector3.zero

		flyButton.Text="飛行: ON"
		flyButton.BackgroundColor3=Color3.fromRGB(40,120,40)

		flyInputBlock.Visible=true
	else
		flyFixedCFrame=nil

		flyButton.Text="飛行: OFF"
		flyButton.BackgroundColor3=Color3.fromRGB(60,60,60)

		flyInputBlock.Visible=true
	end
end)

RunService.Heartbeat:Connect(function(dt)
	if not controlling
		or not mover
		or not currentRoot
		or not currentRoot.Parent then

		if controlling then
			stopControl()

			toggleButton.Text="操作: OFF"
			flyButton.Text="飛行: OFF"
			flyButton.BackgroundColor3=Color3.fromRGB(60,60,60)

			flyInputBlock.Visible=false

			subButtonContainer.Visible=false
			stickBase.Visible=false

			resetKnob()
		end

		return
	end

	updateThirdPersonCamera(dt)

	local camCF=camera.CFrame

	local forward=Vector3.new(
		camCF.LookVector.X,
		0,
		camCF.LookVector.Z
	)

	if forward.Magnitude>0 then
		forward=forward.Unit
	end

	local right=Vector3.new(
		camCF.RightVector.X,
		0,
		camCF.RightVector.Z
	)

	if right.Magnitude>0 then
		right=right.Unit
	end

	local moveDir=(right*stickInput.X)+(forward*-stickInput.Y)

	if moveDir.Magnitude>1 then
		moveDir=moveDir.Unit
	end

	if flying then
		local lookVec=camCF.LookVector

		local flyDir=
			(lookVec*-stickInput.Y)
			+(camCF.RightVector*stickInput.X)

		if flyDir.Magnitude>1 then
			flyDir=flyDir.Unit
		end

		if flyFixedCFrame then
			currentRoot.CFrame=
				CFrame.new(currentRoot.Position)
				*(flyFixedCFrame-flyFixedCFrame.Position)

			currentRoot.AssemblyAngularVelocity=Vector3.zero
		end

		if stickInput.Magnitude<0.05 then
			mover.MaxForce=Vector3.new(
				STOP_FORCE,
				STOP_FORCE,
				STOP_FORCE
			)

			mover.Velocity=Vector3.zero
		else
			local targetVel=flyDir*CURRENT_SPEED

			mover.MaxForce=Vector3.new(
				MAX_FORCE,
				MAX_FORCE,
				MAX_FORCE
			)

			mover.Velocity=targetVel
		end
	else
		if stickInput.Magnitude<0.05 then
			mover.MaxForce=Vector3.new(
				STOP_FORCE,
				0,
				STOP_FORCE
			)

			mover.Velocity=Vector3.zero
		else
			local targetVel=moveDir*CURRENT_SPEED

			mover.MaxForce=Vector3.new(
				MAX_FORCE,
				0,
				MAX_FORCE
			)

			mover.Velocity=Vector3.new(
				targetVel.X,
				0,
				targetVel.Z
			)
		end

		if isJumpRequested
			and isGrounded(currentRoot) then

			local jumpPower=getPlayerJumpPower()

			local jumpVelocity=
				math.sqrt(jumpPower*2)*2.6

			currentRoot:ApplyImpulse(
				Vector3.new(
					0,
					currentRoot.AssemblyMass*jumpVelocity,
					0
				)
			)

			isJumpRequested=false
		end
	end
end)