--[[
BLOXPT

By Noah E.
]]

local up, right, nullVec, tau = Vector3.new(0, 1, 0), Vector3.new(1, 0, 0), Vector3.new(), 2 * math.pi
local randVec = function() return Vector3.new(math.random() - .5, math.random() - .5, math.random() - .5) end
local sRGB = Vector3.new(0.2126, 0.7152, 0.0722)
local bloxpt = script.Parent
local params, util = require(bloxpt.Params), require(bloxpt.Util)

local tracer = {}
tracer.__call = function()
	local self = {x = nil, n = nil, d = nil, albedo = nil, e = nil, object = nil}
	return setmetatable(tracer, self)
end
function tracer:smithGGX(rough, n, v)
	local alpha, nv = rough ^ 2, n:Dot(v)
	return 2 / (nv + math.sqrt(alpha + (1 - alpha) * (nv ^ 2)))
end
function tracer:monteCarlo(d, n)
	local phi, r2 = tau * math.random(), math.random()
	local sint = math.sqrt(r2)
	local w = if n:Dot(d) < 0 then n else -n
	local u = if math.abs(w.x) > 0.1 then up:Cross(w) else right:Cross(w)
	local v = w:Cross(u)
	return u * math.cos(phi) * sint + v * math.sin(phi) * sint + w * math.sqrt(1 - r2)
end
function tracer:fresnelDielectric(cosi, eta)
	cosi = math.abs(cosi)
	local g = eta ^ 2 - 1 + cosi ^ 2
	local gr = math.sqrt(g)
	return if g > 0 then ((gr - cosi) / (gr + cosi)) ^ 2 * (1 + ((cosi * (gr + cosi) - 1) / (cosi * (gr - cosi) + 1)) ^ 2) / 2 else 1
end
function tracer:refract(d, n, cosi, ior)
	local eta = ior ^ -2
	if cosi < 0 then
		cosi = -cosi 
	else  
		eta ^= -1
		n = -n
	end
	local k = 1 - eta ^ 2 * (1 - cosi ^ 2)
	return if k < 0 then nullVec else eta * d + (eta * cosi - math.sqrt(k)) * n
end
function tracer:reflect(d, n)
	return d - n * 2 * n:Dot(d)
end
function tracer:sphereCoordinates(pos)
	return Vector2.new(math.atan2(pos.Z, pos.X) / tau + 0.5, math.asin(pos.Y / params.hdri_radius) / math.pi + 0.5)
end
function tracer:luma(clr)
	return clr:Dot(sRGB)
end
function tracer:mix(a, b, fac)
	return a * (1 - fac) + b * fac
end
function tracer:bsdf(material, depth)
	if material == "Plastic" then
		return self.e + self.albedo * self:trace(Ray.new(self.x, self:monteCarlo(self.d, self.n) * params.ray_dist), depth)
	elseif material == "Metal" then
		self.n += randVec() * (self.object:GetAttribute("Roughness") or 0)
		return self.e + self.albedo * self:trace(Ray.new(self.x, self:reflect(self.d, self.n) * params.ray_dist), depth)
	elseif material == "Marble" then
		local a = self:bsdf("Plastic", depth)
		local b = self:bsdf("Metal", depth)
		return self:mix(a, b, 0.15)
	elseif material == "Glass" then
		self.n += randVec() * (self.object:GetAttribute("Roughness") or 0)
		local cosi = self.d:Dot(self.n)
		local ior = self.object:GetAttribute("IOR") or params.ior
		local eta = if cosi > 0 then 1 / ior else ior
		local fr = self:fresnelDielectric(cosi, eta)
		local r, t = self:reflect(self.d, self.n), self:refract(self.d, self.n, cosi, ior)
		local bias, dist = params.glass_bias, params.ray_dist
		local rr, tr = Ray.new(self.x + r * bias, r * dist), Ray.new(self.x + t * bias, t * dist)
		return self.albedo * (self:trace(rr, depth) * fr + self:trace(tr, depth) * (1 - fr))
	end
end
function tracer:trace(r, depth)
	if depth > params.max_depth then return nullVec end
	self.object, self.x, self.n = util.raycast(r)
	if self.object then
		self.d = r.Direction.unit
		self.albedo = util.color3ToVector(self.object.Color) or nullVec
		local material = self.object.Material.Name
		local rr_prob = self:luma(self.albedo)
		self.e = self.albedo * (self.object:GetAttribute("Emission") or 0)
		if depth > params.rr_depth then
			if math.random() < rr_prob then
				self.albedo /= rr_prob
			else
				return self.e
			end
		end
		return tracer:bsdf(material, depth + 1)
	end
	return nullVec
end
return setmetatable({}, tracer)
