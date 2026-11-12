local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local lounge = Workspace:FindFirstChild("SIGameLounge")
if not lounge then
    lounge = Instance.new("Model")
    lounge.Name = "SIGameLounge"
    lounge.Parent = Workspace
end
lounge:ClearAllChildren()

local function part(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?): Part
    local item = Instance.new("Part")
    item.Name = name
    item.Size = size
    item.Position = position
    item.Color = color
    item.Material = material or Enum.Material.SmoothPlastic
    item.Anchored = true
    item.TopSurface = Enum.SurfaceType.Smooth
    item.BottomSurface = Enum.SurfaceType.Smooth
    item.Parent = lounge
    return item
end

local function cushion(name: string, position: Vector3, size: Vector3, color: Color3): Part
    return part(name, size, position, color, Enum.Material.Fabric)
end

local function sign(name: string, position: Vector3, size: Vector3, title: string, color: Color3)
    local panel = part(name, size, position, color, Enum.Material.Neon)
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.LightInfluence = 0
    gui.Parent = panel
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = title
    label.TextColor3 = Color3.fromRGB(255, 236, 192)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = gui
end

local floor = part("Floor", Vector3.new(56, 1, 38), Vector3.new(0, -0.5, 0), Color3.fromRGB(52, 32, 31), Enum.Material.WoodPlanks)
floor.CastShadow = false
part("BackWall", Vector3.new(56, 18, 1), Vector3.new(0, 8, 18), Color3.fromRGB(65, 34, 42), Enum.Material.Brick)
part("LeftWall", Vector3.new(1, 18, 38), Vector3.new(-28, 8, 0), Color3.fromRGB(52, 29, 35), Enum.Material.Brick)
part("RightWall", Vector3.new(1, 18, 38), Vector3.new(28, 8, 0), Color3.fromRGB(52, 29, 35), Enum.Material.Brick)

local tableTop = part("Table", Vector3.new(20, 1, 9), Vector3.new(0, 2.8, 0), Color3.fromRGB(106, 54, 42), Enum.Material.Wood)
tableTop.Shape = Enum.PartType.Block
part("TableRug", Vector3.new(24, 0.15, 13), Vector3.new(0, 0.05, 0), Color3.fromRGB(92, 47, 51), Enum.Material.Fabric)
part("HostDesk", Vector3.new(8, 1.2, 3.5), Vector3.new(0, 2.5, -8.2), Color3.fromRGB(117, 61, 46), Enum.Material.Wood)
part("HostBack", Vector3.new(7, 4, 0.7), Vector3.new(0, 4.5, -9.6), Color3.fromRGB(76, 39, 43), Enum.Material.Fabric)

local seatPositions = {
    Vector3.new(-8, 1.4, -2), Vector3.new(-8, 1.4, 3), Vector3.new(8, 1.4, -2),
    Vector3.new(8, 1.4, 3), Vector3.new(-3.5, 1.4, 7), Vector3.new(3.5, 1.4, 7),
}
for index, position in seatPositions do
    local seat = Instance.new("Seat")
    seat.Name = "PlayerSeat" .. index
    seat.Size = Vector3.new(3.5, 1.1, 2.6)
    seat.Position = position
    seat.Color = Color3.fromRGB(125, 68, 64)
    seat.Material = Enum.Material.Fabric
    seat.Anchored = true
    seat.Parent = lounge
    cushion("SeatBack" .. index, position + Vector3.new(0, 1.3, 0.9), Vector3.new(3.5, 2.4, 0.6), Color3.fromRGB(95, 48, 50))
end

local hostSeat = Instance.new("Seat")
hostSeat.Name = "HostSeat"
hostSeat.Size = Vector3.new(4, 1.1, 2.8)
hostSeat.Position = Vector3.new(0, 1.4, -11.2)
hostSeat.Color = Color3.fromRGB(190, 96, 62)
hostSeat.Material = Enum.Material.Fabric
hostSeat.Anchored = true
hostSeat.Parent = lounge

for index, position in { Vector3.new(-20, 5, 10), Vector3.new(20, 5, 10), Vector3.new(0, 5, 14) } do
    local lamp = part("Lamp" .. index, Vector3.new(1.2, 0.25, 1.2), position, Color3.fromRGB(248, 181, 85), Enum.Material.Neon)
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 171, 111)
    light.Brightness = 1.6
    light.Range = 16
    light.Parent = lamp
end

sign("SignTitle", Vector3.new(0, 10.8, 17.3), Vector3.new(15, 3, 0.25), "SIGAME LOUNGE", Color3.fromRGB(135, 55, 54))
sign("SignHint", Vector3.new(0, 7.8, 17.25), Vector3.new(11, 1.2, 0.2), "ВОПРОСЫ • ЧАЙ • ХАОС", Color3.fromRGB(89, 46, 60))

local spawn = Instance.new("SpawnLocation")
spawn.Name = "LoungeSpawn"
spawn.Size = Vector3.new(4, 1, 4)
spawn.Position = Vector3.new(0, 0.5, -15)
spawn.Transparency = 1
spawn.CanCollide = false
spawn.Neutral = true
spawn.Anchored = true
spawn.Parent = lounge

local atmosphere = Lighting:FindFirstChild("SIGameAtmosphere") or Instance.new("Atmosphere")
atmosphere.Name = "SIGameAtmosphere"
atmosphere.Density = 0.28
atmosphere.Offset = 0.25
atmosphere.Color = Color3.fromRGB(180, 117, 113)
atmosphere.Decay = Color3.fromRGB(45, 26, 38)
atmosphere.Glare = 0.15
atmosphere.Haze = 1.2
atmosphere.Parent = Lighting
Lighting.ClockTime = 19.5
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(104, 65, 66)
Lighting.OutdoorAmbient = Color3.fromRGB(48, 31, 42)
