local util = {}
local ignore = {nil or workspace:FindFirstChild("Ignore")}
function util.color3ToVector(clr)
	return Vector3.new(clr.R, clr.G, clr.B)
end
function util.raycast(r)
	return workspace:FindPartOnRayWithIgnoreList(r, ignore)
end
return util

