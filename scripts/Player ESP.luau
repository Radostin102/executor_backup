local espConfig = {
	espToggleKeybind = Enum.KeyCode.F1,
	color = Color3.fromRGB(255, 255, 255),
	thickness = 2,
	boxOpacity = 1,
	strokeOpacity = 0.5,
	teamCheck = false,
	useTeamColor = true,
	textMargin = 0,
	textSize = 14,
	tracers = true,
	tracerOpacity = 0.5,
	tracerStrokeOpacity = 0.25
}

local BOX_SIZE = Vector2.new(3000, 3800)
local Y_OFFSET: number = 400
local CALIBRATED_FOV: number = 70
local CALIBRATED_TAN: number = math.tan(math.rad(CALIBRATED_FOV / 2))

local workspace = game:GetService("Workspace")
local players = game:GetService("Players")
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")

local localPlayer = players.LocalPlayer
local espEnabled: boolean = false
local playerData = {}

local camera = workspace.CurrentCamera
local viewportSize = camera.ViewportSize
local viewportConnection = nil

local function updateViewportSize()
	if camera then
		viewportSize = camera.ViewportSize
	end
end

local function updateCamera()
	local newCam = workspace.CurrentCamera
	if newCam then
		camera = newCam

		updateViewportSize()

		if viewportConnection then
			viewportConnection:Disconnect()
		end

		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateViewportSize)
	end
end

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateCamera)

local function hideBox(data)
	if data.box.Visible then data.box.Visible = false end
	if data.boxStroke.Visible then data.boxStroke.Visible = false end
	if data.nameText.Visible then data.nameText.Visible = false end
end

local function hideTracer(data)
	if data.tracer.Visible then data.tracer.Visible = false end
	if data.tracerStroke.Visible then data.tracerStroke.Visible = false end
end

local function hideAll(data)
	hideBox(data)
	hideTracer(data)
end

local function isTeammate(player): boolean
	return localPlayer.Team == player.Team
end

local function getColor(player)
	if espConfig.useTeamColor and player.Team then
		return player.TeamColor.Color
	end
	return espConfig.color
end

local function getPlayerNameText(player)
	if player.DisplayName == player.Name then
		return player.Name
	else
		return string.format("%s (@%s)", player.DisplayName, player.Name)
	end
end

local function createVisuals(player)
	local boxStroke = Drawing.new("Square")
	boxStroke.Visible = false
	boxStroke.Color = Color3.new(0, 0, 0)
	boxStroke.Thickness = espConfig.thickness + 2
	boxStroke.Filled = false
	boxStroke.Transparency = espConfig.strokeOpacity
	boxStroke.ZIndex = 1

	local box = Drawing.new("Square")
	box.Visible = false
	box.Color = espConfig.color
	box.Thickness = espConfig.thickness
	box.Filled = false
	box.Transparency = espConfig.boxOpacity
	box.ZIndex = 2

	local text = Drawing.new("Text")
	text.Visible = false
	text.Text = getPlayerNameText(player)
	text.Size = espConfig.textSize
	text.Center = true
	text.Outline = true
	text.OutlineColor = Color3.new(0.25, 0.25, 0.25)
	text.Color = espConfig.color
	text.ZIndex = 4

	local tracer = Drawing.new("Line")
	tracer.Visible = false
	tracer.Color = espConfig.color
	tracer.Thickness = espConfig.thickness
	tracer.Transparency = espConfig.tracerOpacity
	tracer.ZIndex = 3

	local tracerStroke = Drawing.new("Line")
	tracerStroke.Visible = false
	tracerStroke.Color = Color3.new(0, 0, 0)
	tracerStroke.Thickness = espConfig.thickness + 2
	tracerStroke.Transparency = espConfig.tracerStrokeOpacity
	tracerStroke.ZIndex = 1

	return box, boxStroke, text, tracer, tracerStroke
end

local function cleanupPlayer(player)
	local data = playerData[player]
	if not data then return end

	data.box:Remove()
	data.boxStroke:Remove()
	data.nameText:Remove()
	data.tracer:Remove()
	data.tracerStroke:Remove()

	for _, conn in data.connections do
		conn:Disconnect()
	end

	playerData[player] = nil
end

local function onCharacterAdded(player, character)
	local data = playerData[player]
	if not data then return end

	data.rootPart = nil
	data.humanoid = nil
	hideAll(data)

	if data.connections.died then
		data.connections.died:Disconnect()
		data.connections.died = nil
	end

	local humanoid = character:WaitForChild("Humanoid", 10)
	local rootPart = character:WaitForChild("HumanoidRootPart", 10)

	if not humanoid or not rootPart or player.Character ~= character then
		return
	end

	data.humanoid = humanoid
	data.rootPart = rootPart

	data.connections.died = humanoid.Died:Connect(function()
		data.rootPart = nil
		data.humanoid = nil
		hideAll(data)
	end)
end

local function setupPlayer(player)
	if player == localPlayer then return end

	cleanupPlayer(player)

	local box, boxStroke, text, tracer, tracerStroke = createVisuals(player)

	local data = {
		player = player,
		box = box,
		boxStroke = boxStroke,
		nameText = text,
		tracer = tracer,
		tracerStroke = tracerStroke,
		rootPart = nil,
		humanoid = nil,
		connections = {},
	}
	playerData[player] = data

	data.connections.characterAdded = player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

for _, player in players:GetPlayers() do
	setupPlayer(player)
end

players.PlayerAdded:Connect(setupPlayer)
players.PlayerRemoving:Connect(cleanupPlayer)

userInputService.InputBegan:Connect(function(input, gameProcessed: boolean)
	if gameProcessed then return end
	if input.KeyCode == espConfig.espToggleKeybind then
		espEnabled = not espEnabled
		if not espEnabled then
			for _, data in playerData do
				hideAll(data)
			end
		end
	end
end)

runService.RenderStepped:Connect(function()
	if not espEnabled then return end

	if not camera then
		for _, data in playerData do
			hideAll(data)
		end
		return
	end

	local currentViewport = camera.ViewportSize
	local fov: number = camera.FieldOfView
	local fovScale: number = CALIBRATED_TAN / math.tan(math.rad(fov / 2))
	local viewportX: number = currentViewport.X
	local viewportY: number = currentViewport.Y
	local teamCheck: boolean = espConfig.teamCheck
	local tracersEnabled: boolean = espConfig.tracers

	for _, data in playerData do
		local rootPart = data.rootPart
		local humanoid = data.humanoid
		local box = data.box
		local boxStroke = data.boxStroke
		local text = data.nameText
		local tracer = data.tracer
		local tracerStroke = data.tracerStroke

		if not rootPart or not rootPart.Parent or not humanoid or humanoid.Health <= 0 then
			hideAll(data)
			continue
		end

		if teamCheck and isTeammate(data.player) then
			hideAll(data)
			continue
		end

		local screenPos = camera:WorldToViewportPoint(rootPart.Position)
		local depth: number = screenPos.Z
		local playerColor = getColor(data.player)

		local posX: number, posY: number, sizeX: number, sizeY: number
		local showBox: boolean = false

		if depth > 0 then
			local scaledFov: number = fovScale / depth
			sizeX = BOX_SIZE.X * scaledFov
			sizeY = BOX_SIZE.Y * scaledFov
			local yOffset: number = Y_OFFSET * scaledFov

			posX = screenPos.X - (sizeX / 2)
			posY = screenPos.Y - (sizeY / 2) + yOffset

			if not ((posX + sizeX) < 0 or posX > viewportX or (posY + sizeY) < 0 or posY > viewportY) then
				showBox = true
			end
		end

		if showBox then
			box.Size = Vector2.new(sizeX, sizeY)
			box.Position = Vector2.new(posX, posY)
			box.Color = playerColor

			boxStroke.Size = Vector2.new(sizeX - 2, sizeY - 2)
			boxStroke.Position = Vector2.new(posX + 1, posY + 1)
			boxStroke.Thickness = espConfig.thickness + 2

			text.Position = Vector2.new(
				posX + (sizeX / 2),
				posY - espConfig.textMargin - text.TextBounds.Y - espConfig.thickness - 1
			)
			text.Color = playerColor

			if not box.Visible then
				box.Visible = true
				boxStroke.Visible = true
				text.Visible = true
			end
		else
			hideBox(data)
		end

		if tracersEnabled then
			local tracerFrom = Vector2.new(viewportX / 2, viewportY)
			local tracerTo = Vector2.new(posX + (sizeX / 2), posY + sizeY)

			if tracerFrom.Y < tracerTo.Y then
				hideTracer(data)
			else
				tracer.From = tracerFrom
				tracer.To = tracerTo
				tracer.Color = playerColor
				tracer.Visible = true

				tracerStroke.From = tracerFrom
				tracerStroke.To = tracerTo
				tracerStroke.Visible = true
			end
		else
			hideTracer(data)
		end
	end
end)
