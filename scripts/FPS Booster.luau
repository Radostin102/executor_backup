--[[ FPS booster, anti-lag, potato graphics ]]

if getgenv().RanFpsBooster_k6CgMBWCW5y7Cv4GjSbq then
    warn("[FPS booster] The script was already run")
    return
end
getgenv().RanFpsBooster_k6CgMBWCW5y7Cv4GjSbq = true

local workspace = game:GetService("Workspace")
local lighting = game:GetService("Lighting")
local terrain = workspace:FindFirstChildOfClass("Terrain")

local deletedCount: number = 0
local changedCount: number = 0

local function optimizeObject(obj)
    if obj:IsA("Texture") or obj:IsA("Decal") or obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") or obj:IsA("Clouds") then
        obj:Destroy()
        deletedCount += 1
        return
    end

    local isChanged: boolean = false

    if obj:IsA("BasePart") and not obj:IsA("Terrain") then
        obj.Material = Enum.Material.SmoothPlastic
        obj.Reflectance = 0
        obj.CastShadow = false
        obj.TopSurface = Enum.SurfaceType.Smooth
        obj.BottomSurface = Enum.SurfaceType.Smooth
        obj.LeftSurface = Enum.SurfaceType.Smooth
        obj.RightSurface = Enum.SurfaceType.Smooth
        obj.FrontSurface = Enum.SurfaceType.Smooth
        obj.BackSurface = Enum.SurfaceType.Smooth
        isChanged = true
    end

    if obj:IsA("MeshPart") then
        obj.TextureID = ""
        isChanged = true
    elseif obj:IsA("SpecialMesh") then
        obj.TextureId = ""
        isChanged = true
    end

    if isChanged then
        changedCount += 1
    end
end

for _, obj in workspace:GetDescendants() do
    optimizeObject(obj)
end

if terrain then
    terrain.WaterReflectance = 0
    terrain.WaterWaveSize = 0
    terrain.WaterWaveSpeed = 0
end

lighting:ClearAllChildren()
lighting.EnvironmentDiffuseScale = 0
lighting.EnvironmentSpecularScale = 0
lighting.GlobalShadows = false
lighting.ShadowSoftness = 0
lighting.FogColor = Color3.new(0, 0, 0)
lighting.FogStart = 999999999
lighting.FogEnd = 999999999

pcall(function()
    lighting.Technology = Enum.Technology.Compatibility
end)

local stats: string = string.format(
    "\n[FPS booster]\n  - Deleted %d objects\n  - Changed %d objects",
    deletedCount, changedCount
)

print(stats)
workspace.DescendantAdded:Connect(optimizeObject)
