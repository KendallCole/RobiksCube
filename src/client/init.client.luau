local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RobiksCube = require(ReplicatedStorage.Shared.RobiksCube)
local Trove = require(ReplicatedStorage.Shared.utills.Trove)
local UIS = game:GetService("UserInputService")
local mouse = game.Players.LocalPlayer:GetMouse() :: Mouse

local MOUSE_DELTA_THRESHOLD = 5 -- Minimum mouse movement to consider a drag action
local DEBUG_MODE = true

local HANDLE_TEMPLATE = Instance.new("Part")
HANDLE_TEMPLATE.Anchored = true    
HANDLE_TEMPLATE.CanCollide = false
HANDLE_TEMPLATE.Size = Vector3.new(1, 1, 1)
HANDLE_TEMPLATE.BrickColor = BrickColor.new("Bright red")
HANDLE_TEMPLATE.Transparency = 0.5
HANDLE_TEMPLATE.CanQuery = false

local myCube = RobiksCube.new(20)

local camera = workspace.CurrentCamera
camera.CameraSubject = myCube.model.PrimaryPart
camera.CameraType = Enum.CameraType.Custom

local function getMouseTarget(mousePosition: Vector3, raycastParams: RaycastParams?)
    local ray = camera:ViewportPointToRay(mousePosition.X, mousePosition.Y)
    local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
    
    if result then
        return result
    else
        return {Position = ray.Origin + ray.Direction * 1000} -- fallback position in the void
    end
end


local function getClosestPartFromList(parts: {BasePart}, position: Vector3): BasePart
    local closestPart = nil
    local closestDistance = math.huge

    for _, part in pairs(parts) do
        local distance = (part.Position - position).Magnitude
        if distance < closestDistance then
            closestDistance = distance
            closestPart = part
        end
    end

    return closestPart
end

local function snapVectorToGrid(vector: Vector3, gridSize: number): Vector3
    return Vector3.new(
        math.floor(vector.X / gridSize + 0.5) * gridSize,
        math.floor(vector.Y / gridSize + 0.5) * gridSize,
        math.floor(vector.Z / gridSize + 0.5) * gridSize
    )
end

local function spawnCenterAndHandles(): (Part, {Part})


    -- Step 2: We save the mouse's current distance from each handle. 
    -- This will be used to determine which handle the mouse has move towards the most.


    local center = Instance.new("Part")
    center.Size = Vector3.new(5, 5, 5)

    
    center.Position = if mouse.Target then mouse.Target.Position else Vector3.zero
    center.Anchored = true
    center.Anchored = true
    center.BrickColor = BrickColor.new("Bright blue")
    center.Parent = workspace
    center.Shape = Enum.PartType.Ball
    center.Transparency = if DEBUG_MODE then 0.5 else 1

    local function createDirectionHandle(offset: CFrame)
        local handle = HANDLE_TEMPLATE:Clone()
        handle.CFrame = center.CFrame * offset
        handle.Parent = workspace
        handle.Transparency = if DEBUG_MODE then 0.5 else 1
        return handle
    end

    local topPart = createDirectionHandle(CFrame.new(0, 6, 0))
    local bottomPart = createDirectionHandle(CFrame.new(0, -6, 0))
    local leftPart = createDirectionHandle(CFrame.new(-6, 0, 0))
    local rightPart = createDirectionHandle(CFrame.new(6, 0, 0))
    local frontPart = createDirectionHandle(CFrame.new(0, 0, 6))
    local backPart = createDirectionHandle(CFrame.new(0, 0, -6))

    return center, {topPart, bottomPart, leftPart, rightPart, frontPart, backPart}         
end

local function getDistancesFromOrigin(parts: {Part}, origin: Vector3): {{["Distance"]: number, ["Handle"]: Part}}
    local res = {}
    for _, handle in parts do
        table.insert(res, {
            Distance = (handle.Position - origin).Magnitude,
            Handle = handle
            })
        end
    return res
end

local function moduloKeepNegitives(n, mod)
	local dir = 1
	if n < 0 then
		dir = -1
	end

	return (math.abs(n) % mod) * dir
end


local function onMouseDown(trove: Trove.Trove)

    -- Step 1: Create a center point based on where the mouse is clicked
    local center, handles = spawnCenterAndHandles()  
    trove:Add(center)
    for _, handle in handles do
        trove:Add(handle)
    end

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Include
    raycastParams.FilterDescendantsInstances = {center}


    -- Step 2: We save the mouse's current distance from each handle. 
    -- This will be used to determine which handle the mouse has move towards the most.
    local mouseClickOrigin = getMouseTarget(UIS:GetMouseLocation(), raycastParams)
    local handleStartingDist = getDistancesFromOrigin(handles, mouseClickOrigin.Position)

    -- We'll just asume the first handle is the one we want to start with
    local selectedHandle1 = getClosestPartFromList(handles, mouseClickOrigin.Position)
    local mouseOrigin = UIS:GetMouseLocation()

    -- We wait for t player to move the mouse enough to help us establish this. 
    while true do
        local mouseDelta = mouseOrigin - UIS:GetMouseLocation()
        if mouseDelta.Magnitude > MOUSE_DELTA_THRESHOLD then
            break
        end
        RunService.Heartbeat:Wait() 
    end

    local handlesEndingDist = getDistancesFromOrigin(handles, getMouseTarget(UIS:GetMouseLocation(), raycastParams).Position)
    local closestEnding: {["Distance"]: number, ["Handle"]: Part} = {["Distance"] = math.huge, ["Handle"] = nil }
        
    for i, handle in handles do
        if handle == selectedHandle1 then
            continue
        end
        local deltaDist = handlesEndingDist[i].Distance - handleStartingDist[i].Distance

        if closestEnding.Handle == nil or deltaDist < closestEnding.Distance then
            closestEnding.Distance = deltaDist
            closestEnding.Handle = handle
        end
    end
    selectedHandle1.BrickColor = BrickColor.White()
    closestEnding.Handle.BrickColor = BrickColor.new("Bright blue")

  
    

    local cubeScale = myCube.model:GetExtentsSize().Y // 2
    local smallestAllowedSizeOnAxis = 1

    local A = selectedHandle1
    local B = closestEnding.Handle

    local regionWhereCubePartsAre = Instance.new("Part")
    regionWhereCubePartsAre.Anchored = true
    regionWhereCubePartsAre.Size = Vector3.new(
        math.max(math.abs(A.Position.X - B.Position.X) * cubeScale , smallestAllowedSizeOnAxis),
        math.max(math.abs(A.Position.Y - B.Position.Y) * cubeScale, smallestAllowedSizeOnAxis),
        math.max(math.abs(A.Position.Z - B.Position.Z) * cubeScale, smallestAllowedSizeOnAxis))
    regionWhereCubePartsAre.Position = center.Position
    regionWhereCubePartsAre.Color = Color3.fromRGB(1, 0, 0)
    regionWhereCubePartsAre.Material = Enum.Material.Neon
    regionWhereCubePartsAre.Name = "getPartsInthisRegion"
    regionWhereCubePartsAre.Parent = workspace
    regionWhereCubePartsAre.CanQuery = false
    regionWhereCubePartsAre.Transparency = if DEBUG_MODE then 0.5 else 1

    trove:Add(regionWhereCubePartsAre)
    
    -- Step 4: Get the cube parts in the region, and verify that its a real face
    local cubePartsOverlapFilter = OverlapParams.new()
    cubePartsOverlapFilter.FilterType = Enum.RaycastFilterType.Include
    cubePartsOverlapFilter.FilterDescendantsInstances = myCube.model:GetChildren()
    -- Whish that theres where interchangable lol 
    local cubePartsRaycastFilter = RaycastParams.new()
    cubePartsRaycastFilter.FilterType = Enum.RaycastFilterType.Include
    cubePartsRaycastFilter.FilterDescendantsInstances = myCube.model:GetChildren()


    local cubeSelectedParts = workspace:GetPartBoundsInBox(regionWhereCubePartsAre.CFrame, regionWhereCubePartsAre.Size, cubePartsOverlapFilter)


    if not myCube:isValidGroup(cubeSelectedParts) then
        warn(`Selected parts are not a valid group`)
        return
    end


    -- Theres I'm sure there are math-y ways to do this...but I'm dumb so enjoy some brute force :) 
    -- Step 5: Getting relationship between mouse delta and cube rotation delta. Complicated because of different camera / cube rotations 
    

    
    local lastPosition = UIS:GetMouseLocation()   
    while RunService.RenderStepped:Wait() do


        -- if getMouseTarget(UIS:GetMouseLocation(), raycastParams).Instance == nil then
        --     return
        -- end

        local cameraCubeCrossProduct = (camera.CFrame.Position:Cross(myCube.model.PrimaryPart.Position)).Unit
        local useCrossY = cameraCubeCrossProduct.Y
 

        if cameraCubeCrossProduct.Y ~= 0 and cameraCubeCrossProduct.Y > 0 then
            useCrossY = 1
        elseif cameraCubeCrossProduct.Y ~= 0 and cameraCubeCrossProduct.Y < 0 then
            useCrossY = -1
        end



        local currentPosition = UIS:GetMouseLocation()
        local delta = currentPosition - lastPosition

        -- Signed movement (X and Y separately)
        local deltaX = math.round(delta.X) --* math.round(cameraBlockCross.X)
        local deltaY = math.round(delta.Y * useCrossY)
        lastPosition = currentPosition
        myCube:rotateGroup(cubeSelectedParts, 
            if math.abs(deltaX) > math.abs(deltaY) then deltaX else deltaY
        )
    end

    return
end


UIS.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then

        local myTrove = Trove.new()
        local thread = task.spawn(function() 
            onMouseDown(myTrove) 
            myCube:tweenToNextSafeSpot(1) -- User may break early out of loop. We can do the tween here in that case...
            print("Made it here")
            
        end)
        UIS.InputEnded:Wait()
        task.cancel(thread)
        myTrove:Clean()
        myCube:tweenToNextSafeSpot() 
        
    end

    if input.KeyCode == Enum.KeyCode.R then
        myCube:reset()
    end
end)

local keyToRotation = {
    W = Vector3.new(1, 0, 0),   -- rotate around X
    S = Vector3.new(-1, 0, 0),
    A = Vector3.new(0, 1, 0),   -- rotate around Y
    D = Vector3.new(0, -1, 0),
}


local rotating = false 
local function onInput(input, gameProcessed)


    if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if rotating then return end

    local key = input.KeyCode.Name
    local axis = keyToRotation[key]


    if not axis then return end
    local rotating = true


    -- Convert degrees to radians
    local radians = math.rad(90)

    -- Build rotation CFrame
    local rotationCFrame = CFrame.fromAxisAngle(axis, radians)
    -- Rotate around cube's center

    
    -- myCube.model:PivotTo(myCube.model:GetPivot() * rotationCFrame)


    local duration = 0.1 -- seconds

    local startTime = tick()

    local startCFrame = myCube.model:GetPivot()
    local goalCFrame = startCFrame * CFrame.fromAxisAngle(axis, radians)


    -- Rotation loop
    RunService:BindToRenderStep("SmoothCubeRotation", Enum.RenderPriority.Camera.Value + 1, function()
        if not rotating then return end

        local alpha = math.clamp((tick() - startTime) / duration, 0, 1)
        local currentCFrame = startCFrame:Lerp(goalCFrame, alpha)
        myCube.model:PivotTo(currentCFrame)

        if alpha >= 1 then
            rotating = false
            RunService:UnbindFromRenderStep("SmoothCubeRotation")
            myCube.model.PrimaryPart.Rotation = Vector3.new()
        end
    end)
end

UIS.InputBegan:Connect(onInput)