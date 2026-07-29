local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))() 
local Players = game:GetService("Players") 
local ReplicatedStorage = game:GetService("ReplicatedStorage") 
local Workspace = game:GetService("Workspace") 
local LocalPlayer = Players.LocalPlayer

local Window = Rayfield:CreateWindow({Name = "Destroy Panel"}) 
local OmniTab = Window:CreateTab("Destroy Server", nil)

local selectedHeight = "Spawn"

-- 関数定義 
local function getAllPlayers() 
local players = {} 
for _, plr in pairs(Players:GetPlayers()) do 
if plr ~= LocalPlayer then table.insert(players, plr) end 
end 
return players 
end

local GrabEvents = ReplicatedStorage:FindFirstChild("GrabEvents")

local function spamOwnership(hrp) 
if not GrabEvents then return end 
local setOwner = GrabEvents:FindFirstChild("SetNetworkOwner") 
if setOwner and hrp then pcall(function() setOwner:FireServer(hrp, hrp.CFrame) end) end 
end

local function teleportToPlayer(myHrp, targetHrp) 
if not myHrp or not targetHrp then return end 
pcall(function() 
myHrp.CFrame = targetHrp.CFrame * CFrame.new(0, 5, 5) 
myHrp.AssemblyLinearVelocity = Vector3.zero 
end) 
end

local function destroyLineOnPlayer(hrp) 
if not GrabEvents then return end 
local createLine = GrabEvents:FindFirstChild("CreateGrabLine") 
local destroyLine = GrabEvents:FindFirstChild("DestroyGrabLine") 
if not createLine or not destroyLine then return end 
pcall(function() 
createLine:FireServer(hrp, CFrame.new(0, 1e9, 0)) 
task.wait() 
destroyLine:FireServer(hrp) 
end) 
end

-- ラインラグ制御 
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
local spawnLocation = Workspace:FindFirstChild("SpawnLocation") or Workspace:FindFirstChild("Spawn") or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) 
if spawnLocation then 
-- 9e -> 1e に変更済み 
local randomX = math.random(-1e9, 1e9) 
local randomZ = math.random(-1e9, 1e9) 
local directions = {CFrame.new(randomX, 0, randomZ), CFrame.new(-randomX, 0, -randomZ), CFrame.new(randomX, 0, -randomZ), CFrame.new(-randomX, 0, randomZ)} 
for _, pos in pairs(directions) do createLine:FireServer(spawnLocation, pos) end 
end 
task.wait() 
end 
end) 
coroutine.resume(lineLagThread) 
end

local function stopLineLag() 
lineLagEnabled = false 
if lineLagThread then coroutine.close(lineLagThread); lineLagThread = nil end 
end

-- UI部品 
OmniTab:CreateDropdown({ 
Name = "破壊の高さモード", 
Options = {"Spawn (地上)", "Heaven (天国)"}, 
CurrentOption = "Spawn (地上)", 
Callback = function(Value) 
selectedHeight = (Value  "Heaven (天国)") and "Heaven" or "Spawn" 
end 
})

OmniTab:CreateButton({ 
Name = "Destroy Server", 
Callback = function() 
task.spawn(function() 
local height = (selectedHeight  "Heaven") and 1e9 or 35 
startLineLag() 
task.wait(1)

        local players = getAllPlayers()
        if #players == 0 then
            stopLineLag()
            Rayfield:Notify({Title = "Destroy", Content = "対象プレイヤーがいません", Duration = 3})
            return
        end

        local myChar = LocalPlayer.Character
        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myHrp then stopLineLag(); return end

        local playerData = {}
        for _, plr in ipairs(players) do
            local char = plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then table.insert(playerData, {player = plr, hrp = hrp}) end
        end

        for _, data in ipairs(playerData) do
            teleportToPlayer(myHrp, data.hrp)
            task.wait(0.2)
            spamOwnership(data.hrp)
            task.wait()
        end

        local radius = 40
        local angleStep = (math.pi * 2) / #playerData
        for idx, data in ipairs(playerData) do
            local angle = (idx - 1) * angleStep
            local x = math.cos(angle) * radius
            local z = math.sin(angle) * radius

            pcall(function()
                data.hrp.CFrame = CFrame.new(x, height, z)
                data.hrp.AssemblyLinearVelocity = Vector3.zero
            end)

            local bp = Instance.new("BodyPosition")
            bp.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            -- P = 40000000 に変更済み
            bp.P = 40000000
            bp.Position = Vector3.new(x, height, z)
            bp.Parent = data.hrp
            task.delay(2, function() pcall(function() bp:Destroy() end) end)
            task.wait()
        end

        for i = 1, 8 do
            for _, data in ipairs(playerData) do destroyLineOnPlayer(data.hrp) end
            task.wait(0.3)
        end
        
        Rayfield:Notify({Title = "Destroy", Content = "完了！ラグは継続中です。", Duration = 2})
    end)
end
})

OmniTab:CreateButton({ 
Name = "Stop Lag (ラグを止める)", 
Callback = function() 
stopLineLag() 
Rayfield:Notify({Title = "Lag", Content = "ラグ処理を停止しました", Duration = 2}) 
end 
})