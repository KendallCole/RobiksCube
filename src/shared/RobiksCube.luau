local RubiksCube = {}


local DISTANCE_FOR_TWEENING_TO_GO_TOWARDS_TREND = 15 -- The threhold for tweenToNextSafeSpot() to rotate towards the next 90'th degree
local PART_SCALE = 2 
local TWEEN_DEFAULT_STEPS = 6
local RunService = game:GetService("RunService")

local RubiksCubeClass = {}
RubiksCubeClass.__index = RubiksCubeClass

local DirectionEnums = {
	X = "X",
	Y = "Y",
	Z = "Z",
}

local SurfaceGuiEnums = {
	Front = Enum.NormalId.Front,
	Back = Enum.NormalId.Back,
	Top = Enum.NormalId.Top,
	Bottom = Enum.NormalId.Bottom,
	Left = Enum.NormalId.Left,
	Right = Enum.NormalId.Right,
}

export type DirectionType = "X" | "Y" | "Z"
export type FaceType = "Front"  | "Back" | "Top" | "Bottom" | "Left" | "Right"

local faceTemplate = Instance.new("Part")
faceTemplate.Anchored = true
faceTemplate.CanCollide = false
faceTemplate.Size = Vector3.new(2, 2, 2) -- Size of each cube faceTemplate
faceTemplate.BrickColor = BrickColor.Random() -- Random color for each faceTemplate
faceTemplate.Material = Enum.Material.SmoothPlastic -- Material of the cube parts

local function addSurface(toPart: Part, color: Color3, face: Enum.NormalId)
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = face
	surfaceGui.Adornee = toPart
	surfaceGui.Parent = toPart
	surfaceGui.Name = face.Name

	local label = Instance.new("TextLabel")
	label.Text = ""
	label.Parent = surfaceGui
	label.BackgroundColor3 = color
	label.Size = UDim2.new(1, 0, 1, 0)
end

addSurface(faceTemplate, Color3.new(1,1,1), Enum.NormalId.Front)
addSurface(faceTemplate, Color3.new(1,1,0), Enum.NormalId.Back)
addSurface(faceTemplate, Color3.new(0, 1, 0), Enum.NormalId.Top)
addSurface(faceTemplate, Color3.new(0,0,1), Enum.NormalId.Bottom)
addSurface(faceTemplate, Color3.new(1,.5,0), Enum.NormalId.Left)
addSurface(faceTemplate, Color3.new(1,0,0), Enum.NormalId.Right)


function RubiksCube.new(n: number)

    local self = setmetatable({}, RubiksCubeClass )
	

    self.n = n or 3


	local model = Instance.new("Model")
    for x = 1, n do
        for y = 1, n do
            for z = 1, n do
                -- Only create parts on the outer layer (hollow cube)
                if x == 1 or x == n or y == 1 or y == n or z == 1 or z == n then
                    local part = faceTemplate:Clone()
                    part.Parent = model -- Add to the workspace
                    part.Name = "CubePart_" .. x .. "_" .. y .. "_" .. z
                    part.Position = Vector3.new(x * PART_SCALE, y * PART_SCALE, z * PART_SCALE)
					part.Size = Vector3.new(PART_SCALE, PART_SCALE, PART_SCALE) -- Scale the part

					
                end
            end
        end
    end
	-- Create primary part at center of the cube
	local centerPart = Instance.new("Part")
	centerPart.Anchored = true
	centerPart.CanCollide = false
	centerPart.CanQuery = false
	centerPart.Size = Vector3.new(1, 1, 1) -- Small size
	centerPart.BrickColor = BrickColor.new("Bright blue")
	centerPart.Transparency = 0 -- Make it invisible
	centerPart.Parent = model
	centerPart.Name = "CenterPart"
	local centerPos = Vector3.new(
		(1 + n) * PART_SCALE / 2,
		(1 + n) * PART_SCALE / 2,
		(1 + n) * PART_SCALE / 2
	)
	centerPart.CFrame = CFrame.new(centerPos)
	model.PrimaryPart = centerPart -- Set the primary part for the model	
	

	local basePositions = makeSnapshot(model:GetChildren())

	model.Name = "RubiksCube_" .. n .. "x" .. n .. "x" .. n
	model.Parent = workspace
	self.model = model
	self.__scale = PART_SCALE
	self.__basePositions = basePositions
	self.__lastStableSnapshot = basePositions
	-- GroupHashId is so we can verify if an arbitrary list of parts are the same 
	self.__activeGroup = nil :: { groupHashId: string, rotation: number, prevRotation: number, group: {Part} } | nil

    return self
end

function makeSnapshot(parts: {Part}):  {Part: Vector3}
	local res = {}
	for _, part in parts do
		res[part] = part.CFrame 
	end
	return res
end
--@TODO Cache array address? 
local function makeGroupHashkey(group: {Part}): string
	local parts = {}
	for _, part in group do
		table.insert(parts, part.Name)
	end
	table.sort(parts)
	return table.concat(parts, ",")
end

--@TODO Rename, use enums youi know the deal 
function RubiksCubeClass:getGroup(dir: DirectionType, idx: number)
    -- dir: "VERT" for vertical (X), "HOR" for horizontal (Y), "DEPTH" for Z axis
    -- idx: index of the row, column, or depth (1 to n)
    local parts = {}
    local modelCFrame = self.model:GetModelCFrame()
    local half = (self.n + 1) / 2 * self.__scale
    for _, part in pairs(self.model:GetChildren()) do
        if part:IsA("Part") and part.CanQuery == true then -- Can query to ignore center part. Can adjust later if needed 
            -- Get the part's position relative to the model's origin, then shift so (1,1,1) is at the corner
            local relPos = modelCFrame:PointToObjectSpace(part.Position)
            local relX = math.round((relPos.X + half) / self.__scale)
            local relY = math.round((relPos.Y + half) / self.__scale)
            local relZ = math.round((relPos.Z + half) / self.__scale)
            if dir == DirectionEnums.X and relX == idx then
                table.insert(parts, part)
            elseif dir == DirectionEnums.Y and relY == idx then
                table.insert(parts, part)
            elseif dir == DirectionEnums.Z and relZ == idx then
                table.insert(parts, part)
            end
        end
    end
    return parts
end


function RubiksCubeClass:getAllGroups(): {string: {Part}}
	local groups = {}
	for x = 1, self.n do
		groups[`X{tostring(x)}`] = self:getGroup(DirectionEnums.X, x)
	end
	for y = 1, self.n do
		groups[`Y{tostring(y)}`] = self:getGroup(DirectionEnums.Y, y)
	end
	for z = 1, self.n do
		groups[`Z{tostring(z)}`] = self:getGroup(DirectionEnums.Z, z)
	end
	return groups
end

function RubiksCubeClass:isValidGroup(group: {Part}): boolean
	local possibleGroups = self:getAllGroups()
	local groupHash = makeGroupHashkey(group) -- @Optimization Might just be better to do array eq method?
	for _, parts in pairs(possibleGroups) do 
		if makeGroupHashkey(parts) == groupHash then
			return true	
		end
	end
	return false
end

function RubiksCubeClass:setCFrame(cframe: CFrame)
	self.model:PivotTo(cframe)
end
function RubiksCubeClass:getCFrame()
	return self.model:GetModelCFrame()
end


function restoreFromSnapshot(snapshot: {Part: CFrame})
	for part, cframe in pairs(snapshot) do
		part.CFrame = cframe
	end
end

function RubiksCubeClass:reset()
	self.__activeGroup = nil
	restoreFromSnapshot(self.__basePositions)
end

function RubiksCubeClass:restoreFromLastSafeSnapshot()
	restoreFromSnapshot(self.__lastStableSnapshot)
end
local function getRotationWithFaceInMind(angle: number, group, face: string)
	-- Get the rotation based on the face orientation
	if face == DirectionEnums.X then
		return CFrame.Angles(math.rad(angle), 0, 0) -- Rotate around X axis
	elseif face == DirectionEnums.Y then
		return CFrame.Angles(0, math.rad(angle), 0) -- Rotate around Y axis
	elseif face == DirectionEnums.Z then
		return CFrame.Angles(0, 0, math.rad(angle)) -- Rotate around Z axis
	else
		return CFrame.new() -- No rotation if face is not recognized
	end
end


function roundToNearestN(n, roundTo)
    return math.floor((n + roundTo*.5) / roundTo) * roundTo
end

local function moduloKeepNegitives(n, mod)
	local dir = 1
	if n < 0 then
		dir = -1
	end

	return (math.abs(n) % mod) * dir
end

function RubiksCubeClass:tweenToNextSafeSpot(steps: number?)
	if self.__tweenThread then
		task.cancel(self.__tweenThread)
		-- restoreFromSnapshot(self.__lastStableSnapshot)
	end


	self.__tweenThread = task.spawn(function()
		steps = steps or TWEEN_DEFAULT_STEPS
		if self.__activeGroup == nil then
			warn("Already in a good spot, no need")
			return 
		end

		local rotation = self.__activeGroup.rotation
		local prevRotation = self.__activeGroup.prevRotation
		local group = self.__activeGroup.group

		if rotation % 90 == 0 then
			return
		end

		local goal = roundToNearestN(rotation + 45, 90)
		if prevRotation >= rotation then
			goal = roundToNearestN(rotation -45, 90)
		end

		local distance = goal - rotation

		if 90 - math.abs(distance) < DISTANCE_FOR_TWEENING_TO_GO_TOWARDS_TREND then
			self:rotateGroup(group, moduloKeepNegitives(-self.__activeGroup.rotation, 360)) -- Back from whence you came
		else
			for i = 1, TWEEN_DEFAULT_STEPS do
				if self.__activeGroup == nil then
					return
				end
				self:rotateGroup(group, math.floor(distance/TWEEN_DEFAULT_STEPS))
				RunService.RenderStepped:Wait()
			end
			-- Sometimes due to divisor rounding we'll need to do this
			if self.__activeGroup ~= nil then
				local remainingDist = goal - self.__activeGroup.rotation
				self:rotateGroup(group, remainingDist)
			end
		end
		self.__tweenThread = nil
	end)
end

function RubiksCubeClass:scramble(animationSteps: number?)
	local animationSteps = animationSteps or 1

	local dir = ({
		DirectionEnums.X,
		DirectionEnums.Y,
		DirectionEnums.Z,
	})[math.random(1,3)]

	local selectedGroup = math.random(1, self.n)
	local group = self:getGroup(dir, selectedGroup)
	local distance = (90) * ((math.random(0, 1) * 2) - 1)

	if animationSteps <= 1 then
		self:rotateGroup(group, distance)
	else
		for i = 1, animationSteps do
			self:rotateGroup(group, math.floor(distance/animationSteps))
			RunService.RenderStepped:Wait()
		end
		-- Sometimes due to divisor rounding we'll need to do this
		if self.__activeGroup ~= nil then
			local remainingDist = distance - self.__activeGroup.rotation
			self:rotateGroup(group, remainingDist)
		end
	end
end

function RubiksCubeClass:rotateGroup(group: {Part}, angle: number)
	if angle == 0 then
		return
	end
	assert(angle <= 360 and angle >= -360, "angle provided must be between -360 and 360, provided")
	assert(math.floor(angle+.99) == angle, "Angle must be a whole number")
	local groupHash = makeGroupHashkey(group)
	if self.__activeGroup ~= nil and self.__activeGroup.groupHashId ~= groupHash then
		warn(`Group is already active (rotation: {self.__activeGroup.rotation}: {self.__activeGroup.groupHashId}`)
		return
	end

	if self.__activeGroup == nil then
		self.__activeGroup = { group = group, groupHashId = groupHash, rotation = 0, prevRotation = 0 }
	end

	

	local pivot = self.model:GetModelCFrame() -- Get the model's CFrame as pivo
	local rotation = getRotationWithFaceInMind(
		angle, 
		group, 
		self:getGroupOrientationLocal(group))

	for _, part in pairs(group) do
		-- Move part to pivot space, rotate, then move back
		part.CFrame = pivot * rotation * pivot:Inverse() * part.CFrame
	end

	self.__activeGroup.prevRotation = self.__activeGroup.rotation
	self.__activeGroup.rotation = (self.__activeGroup.rotation + angle)
	if self.__activeGroup.rotation % 90 == 0 then
		self.__activeGroup = nil
		self.__lastStableSnapshot = makeSnapshot(self.model:GetChildren())
	end
end

function RubiksCubeClass:getGroupOrientationLocal(group: {Part}): string?
    if #group == 0 then return nil end
    local EPSILON = 0.01
    local modelCFrame = self.model:GetModelCFrame()
    local firstLocal = modelCFrame:PointToObjectSpace(group[1].Position)
    local sameX, sameY, sameZ = true, true, true

    for _, part in group do
        local localPos = modelCFrame:PointToObjectSpace(part.Position)
        if math.abs(localPos.X - firstLocal.X) > EPSILON then
            sameX = false
        end
        if math.abs(localPos.Y - firstLocal.Y) > EPSILON then
            sameY = false
        end
        if math.abs(localPos.Z - firstLocal.Z) > EPSILON then
            sameZ = false
        end
    end

    if sameX then
        return DirectionEnums.X
    elseif sameY then
        return DirectionEnums.Y
    elseif sameZ then
        return DirectionEnums.Z
    else
		restoreFromSnapshot(self.__lastStableSnapshot)
		error(`Group {group} Not a single-axis group`)
        return nil -- Not a single-axis group
    end
end

-- Returns all parts on a given face ("Front", "Back", "Top", "Bottom", "Left", "Right")
function RubiksCubeClass:getFaceParts(face: FaceType): {Part}
    local parts = {}
    local modelCFrame = self.model:GetModelCFrame()
    local half = (self.n + 1) / 2 * self.__scale
    local idx = nil

    if face == "Front" then
        idx = self.n
        for _, part in pairs(self.model:GetChildren()) do
            if part:IsA("Part") and part.CanQuery == true then
                local relPos = modelCFrame:PointToObjectSpace(part.Position)
                local relZ = math.round((relPos.Z + half) / self.__scale)
                if relZ == idx then
                    table.insert(parts, part)
                end
            end
        end
    elseif face == "Back" then
        idx = 1
        for _, part in pairs(self.model:GetChildren()) do
            if part:IsA("Part") and part.CanQuery == true then
                local relPos = modelCFrame:PointToObjectSpace(part.Position)
                local relZ = math.round((relPos.Z + half) / self.__scale)
                if relZ == idx then
                    table.insert(parts, part)
                end
            end
        end
    elseif face == "Top" then
        idx = self.n
        for _, part in pairs(self.model:GetChildren()) do
            if part:IsA("Part") and part.CanQuery == true then
                local relPos = modelCFrame:PointToObjectSpace(part.Position)
                local relY = math.round((relPos.Y + half) / self.__scale)
                if relY == idx then
                    table.insert(parts, part)
                end
            end
        end
    elseif face == "Bottom" then
        idx = 1
        for _, part in pairs(self.model:GetChildren()) do
            if part:IsA("Part") and part.CanQuery == true then
                local relPos = modelCFrame:PointToObjectSpace(part.Position)
                local relY = math.round((relPos.Y + half) / self.__scale)
                if relY == idx then
                    table.insert(parts, part)
                end
            end
        end
    elseif face == "Left" then
        idx = 1
        for _, part in pairs(self.model:GetChildren()) do
            if part:IsA("Part") and part.CanQuery == true then
                local relPos = modelCFrame:PointToObjectSpace(part.Position)
                local relX = math.round((relPos.X + half) / self.__scale)
                if relX == idx then
                    table.insert(parts, part)
                end
            end
        end
    elseif face == "Right" then
        idx = self.n
        for _, part in pairs(self.model:GetChildren()) do
            if part:IsA("Part") and part.CanQuery == true then
                local relPos = modelCFrame:PointToObjectSpace(part.Position)
                local relX = math.round((relPos.X + half) / self.__scale)
                if relX == idx then
                    table.insert(parts, part)
                end
            end
        end
    else
        error("Invalid face: " .. tostring(face))
    end

    return parts
end

return RubiksCube