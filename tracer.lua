local up, right, nullVec, tau = Vector3.new(0, 1, 0), Vector3.new(1, 0, 0), Vector3.new(), 2 * math.pi
local randVec = function() return Vector3.new(math.random() - .5, math.random() - .5, math.random() - .5) end
local sRGB = Vector3.new(0.2126, 0.7152, 0.0722)
local bloxpt = script.Parent
local params, util = require(bloxpt.Params), require(bloxpt.Util)
local tracer = { x = nil, n = nil, d = nil, albedo = nil, e = nil, object = nil, depth = 0 }
function tracer:sphereCoordinates(pos)
	local long = math.atan2(pos.Z, pos.X)
	local lat = math.asin(pos.Y / params.hdri_radius)
	return Vector2.new(long / tau + 0.5, lat / math.pi + 0.5)
end
function tracer:luma(clr)
	return clr:Dot(sRGB)
end
function tracer:hemisphere(d, n)
	local phi, r2 = tau * math.random(), math.random()
	local sint = math.sqrt(r2)
	local w = n:Dot(d) < 0 and n or n * -1
	local u = (math.abs(w.x) > 0.1 and up:Cross(w) or right:Cross(w)).unit
	local v = w:Cross(u)
	return u * math.cos(phi) * sint + v * math.sin(phi) * sint + w * math.sqrt(1 - r2)
end
function tracer:fresnel(cosi, eta)
	cosi = math.abs(cosi)
	local g = eta * eta - 1 + cosi * cosi
	if g > 0 then
		g = math.sqrt(g)
		local a = (g - cosi) / (g + cosi)
		local b = (cosi * (g + cosi) - 1) / (cosi * (g - cosi) + 1)
		return 0.5 * a * a * (1 + b * b)
	end
	return 1
end
function tracer:refract(d, n, cosi, ior)
	local etai, etat = 1, ior ^ 2
	if cosi < 0 then 
		cosi = -cosi 
	else  
		etai, etat = etat, etai
		n = -n
	end
	local eta = etai / etat
	local k = 1 - eta * eta * (1 - cosi * cosi)
	return k < 0 and nullVec or eta * d + (eta * cosi - math.sqrt(k)) * n
end
function tracer:reflect(d, n)
	return d - n * 2 * n:Dot(d)
end
function tracer:mix(a, b, fac)
	return a * (1 - fac) + b * fac
end
function tracer:roughness(object)
	return object:GetAttribute("Roughness") or 0
end
function tracer:ior(object)
	return object:GetAttribute("IOR") or params.ior
end
function tracer:bsdf(material, depth)
	if material == "Plastic" then
		local d = self:hemisphere(self.d, self.n)
		return self.e + self.albedo * self:trace(Ray.new(self.x, d * params.ray_dist), depth);
	elseif material == "Metal" then
		self.n += randVec() * self:roughness(self.object)
		return self.e + self.albedo * self:trace(Ray.new(self.x, self:reflect(self.d, self.n) * params.ray_dist), depth)
	elseif material == "Marble" then
		local a = self:bsdf("Plastic", depth)
		local b = self:bsdf("Metal", depth)
		return self:mix(a, b, 0.15)
	elseif material == "Glass" then
		self.n += randVec() * self:roughness(self.object)
		local cosi = self.d:Dot(self.n)
		local ior = self:ior(self.object)
		local eta = cosi > 0 and 1 / ior or ior
		local fr = self:fresnel(cosi, eta)
		local r = self:reflect(self.d, self.n).unit
		local t = self:refract(self.d, self.n, cosi, ior).unit
		local bias = params.glass_bias
		local dist = params.ray_dist
		local tr = Ray.new(self.x + t * bias, t * dist)
		local rr = Ray.new(self.x + r * bias, r * dist)
		return self.albedo * (self:trace(rr, depth) * fr + self:trace(tr, depth) * (1 - fr))
	end
end
function tracer:trace(r, depth)
	if depth > params.max_depth then return nullVec end
	self.object, self.x, self.n = util:raycast(r)
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
return tracer
