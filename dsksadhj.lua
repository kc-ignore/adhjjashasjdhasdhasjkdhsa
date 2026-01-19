local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

if getgenv().KuromiMinimalLoaded then return end
getgenv().KuromiMinimalLoaded = true

local function notify(t, x, d) 
    pcall(function() 
        StarterGui:SetCore("SendNotification", {Title=t, Text=x, Duration=d or 3}) 
    end) 
end

local GUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/kitty92pm/AirHub-V2/refs/heads/main/src/UI%20Library.lua"))()
local MainUI = GUI:Load()

local Combat = MainUI:Tab("Aim")
local World  = MainUI:Tab("Camera")
local SettingsTab = MainUI:Tab("Settings")

local aim = {
    enabled = false,
    holdToUse = false,
    holdButton = Enum.UserInputType.MouseButton2,
    teamCheck = false,
    wallCheck = true,
    targetPart = "Head",
    fov = 80,
    smooth = 1,
    maxDistance = 1200,
    minHPToLock = 1,
}

local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Thickness = 1.5
fovCircle.Color = Color3.fromRGB(255, 80, 80)
fovCircle.Filled = false
fovCircle.Radius = aim.fov
fovCircle.Transparency = 0.9
fovCircle.NumSides = 100
fovCircle.Position = Vector2.new(0,0)

local holding = false

UserInputService.InputBegan:Connect(function(i)
    if i.UserInputType == aim.holdButton then holding = true end
end)

UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == aim.holdButton then holding = false end
end)

local function canSee(part, char)
    if not aim.wallCheck then return true end
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character or game}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local result = Workspace:Raycast(Camera.CFrame.Position, (part.Position - Camera.CFrame.Position).Unit * 5000, rayParams)
    return not result or result.Instance:IsDescendantOf(char)
end

local function findBestTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local best, bestDist = nil, math.huge

    for _, plr in Players:GetPlayers() do
        if plr == LocalPlayer then continue end
        if aim.teamCheck and plr.Team == LocalPlayer.Team then continue end

        local char = plr.Character
        if not char then continue end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= aim.minHPToLock then continue end

        local part = char:FindFirstChild(aim.targetPart) or char:FindFirstChild("HumanoidRootPart")
        if not part then continue end

        local dist = (part.Position - Camera.CFrame.Position).Magnitude
        if dist > aim.maxDistance then continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end

        local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
        if screenDist < aim.fov and screenDist < bestDist and canSee(part, char) then
            best = part
            bestDist = screenDist
        end
    end

    return best
end

local aimConn
local function updateFOVCircle()
    if fovCircle then
        local mouse = UserInputService:GetMouseLocation()
        fovCircle.Position = Vector2.new(mouse.X, mouse.Y)
        fovCircle.Radius = aim.fov
        fovCircle.Visible = aim.enabled
    end
end

local function aimStep()
    updateFOVCircle()

    if not aim.enabled or (aim.holdToUse and not holding) then return end

    local targetPart = findBestTarget()
    if not targetPart then return end

    local goalCFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
    Camera.CFrame = Camera.CFrame:Lerp(goalCFrame, aim.smooth)
end

do
    local s = Combat:Section({Name = "Aimbot", Side = "Left"})

    s:Toggle({Name = "Enabled", Default = false, Callback = function(v)
        aim.enabled = v
        fovCircle.Visible = v
        if v and not aimConn then
            aimConn = RunService.RenderStepped:Connect(aimStep)
        elseif not v and aimConn then
            aimConn:Disconnect()
            aimConn = nil
            fovCircle.Visible = false
        end
    end})

    s:Toggle({Name = "Hold RMB to Aim", Default = true, Callback = function(v) aim.holdToUse = v end})
    s:Slider({Name = "FOV Size", Min = 30, Max = 800, Default = 90, Callback = function(v) aim.fov = v end})
	s:Slider({Name = "Max Distance", Min = 100, Max = 6000, Default = 1200, Callback = function(v) aim.maxDistance = v end})
    s:Dropdown({Name = "Target Part", Content = {"Head", "HumanoidRootPart"}, Default = "Head", Callback = function(v) aim.targetPart = v end})
    s:Toggle({Name = "Wall Check", Default = false, Callback = function(v) aim.wallCheck = v end})
end


local fovLock = {
    enabled = false,
    value = 70,
    connection = nil
}

local function updateLockedFOV()
    if Camera then
        Camera.FieldOfView = fovLock.value
    end
end

do
    local s = World:Section({Name = "FOV Changer", Side = "Left"})

    s:Toggle({Name = "Lock FOV", Default = false, Callback = function(v)
        fovLock.enabled = v
        if v then
            if not fovLock.connection then
                fovLock.connection = RunService.RenderStepped:Connect(updateLockedFOV)
            end
        else
            if fovLock.connection then
                fovLock.connection:Disconnect()
                fovLock.connection = nil
            end
        end
    end})

    s:Slider({Name = "FOV", Min = 50, Max = 120, Default = 70, Callback = function(v)
        fovLock.value = v
        if fovLock.enabled then updateLockedFOV() end
    end})
end


do
    local s = SettingsTab:Section({Name = "UI Controls", Side = "Left"})

    s:Keybind({
        Name = "Toggle Menu",
        Default = Enum.KeyCode.RightShift,
        Callback = function(_, pressed)
            if not pressed then  
                GUI:Close()      
            end
        end
    })

    s:Button({
        Name = "Unload Script",
        Callback = function()
            
            if aimConn then aimConn:Disconnect() end
            if fovLock.connection then fovLock.connection:Disconnect() end
            if fovCircle then fovCircle:Remove() end

            
            GUI:Unload()

            
            getgenv().KuromiMinimalLoaded = nil

            notify("KuromiWare", "Script unloaded successfully", 4)
        end
    })
end

GUI:Close()
