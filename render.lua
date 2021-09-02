--Basic rendering code, intended to be edited.

local bloxpt = game.ReplicatedStorage.BloxPT
local tracer, params = require(bloxpt.Tracer), require(bloxpt.Params)

local Pathtracer = tracer()
local camera = workspace.CurrentCamera

function render()
	local samples = params.samples
	local viewportSize = camera.ViewportSize
	local result = Vector3.new()
	for y = 1, params.resy do
		for x = 1, params.resx do
			result = Vector3.new()
			for s = 0, samples do
				local unitRay = camera:ScreenPointToRay((x / params.resx) * viewportSize.X, (y / params.resy) * viewportSize.Y)
				local camDir = unitRay.Direction
				local origin = unitRay.Origin
				camDir = Vector3.new(camDir.X + (math.random() / 700), camDir.Y + (math.random() / 700), camDir.Z).unit
				local ray = Ray.new(origin, camDir * params.ray_dist)
				if params.dof then
					local dofo = origin + (Vector3.new(math.random() - .5, math.random() - .5, math.random() - .5) * params.aperture)
					local target = origin + camDir * params.focal_dist
					local dofd = CFrame.new(dofo, target).lookVector * params.ray_dist
					ray = Ray.new(dofo, dofd)
				end
				result += Pathtracer:trace(ray, 0) / samples
			end
			local color = vectorToColor3(result)
			--output(x, y, color)	
		end
	end
end
