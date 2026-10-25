-- Greyscale remembered scenery while preserving silhouettes and bitmap detail.
local Fog = {}
local levels = { 32, 48, 64, 80, 96, 112, 144 }
function Fog.install(palette, terminal)
	for index, value in ipairs(levels) do
		palette[35 + index] = value * 0x010101
		terminal[35 + index] = index <= 3 and 128 or index <= 5 and 256 or 1
	end
end
function Fog.forUI(ui)
	if ui.fogCanvas ~= ui.r then
		ui.fogCanvas = ui.r
		ui.fogRenderer = Fog.renderer(ui.r)
	end
	return ui.fogRenderer
end
function Fog.renderer(renderer)
	local colors, characters = { [0] = 0, [255] = 255 }, {}
	for index, rgb in pairs(renderer.palette) do
		if index ~= 0 then
			local red = math.floor(rgb / 65536) % 256
			local green = math.floor(rgb / 256) % 256
			local blue = rgb % 256
			local target = 20 + 0.5 * (red * 0.2126 + green * 0.7152 + blue * 0.0722)
			local best, distance
			for shade, value in ipairs(levels) do
				local delta = math.abs(value - target)
				if not distance or delta < distance then
					best, distance = shade, delta
				end
			end
			colors[index] = 35 + best
		end
	end
	for index, mapped in pairs(colors) do
		characters[string.char(index)] = string.char(mapped)
	end
	local proxy, rows = {}, setmetatable({}, { __mode = "k" })
	function proxy:fill(x, y, w, h, color)
		return renderer:fill(x, y, w, h, colors[color or 0] or color)
	end
	function proxy:line(x, y, xx, yy, color)
		return renderer:line(x, y, xx, yy, colors[color or 0] or color)
	end
	function proxy:outline(x, y, w, h, color)
		return renderer:outline(x, y, w, h, colors[color or 0] or color)
	end
	function proxy:text(x, y, text, color, ...)
		return renderer:text(x, y, text, colors[color or 0] or color, ...)
	end
	function proxy:blit(sprite, x, y)
		local shaded = rows[sprite]
		if not shaded then
			shaded = {}
			for index, row in ipairs(sprite) do
				shaded[index] = row:gsub(".", characters)
			end
			rows[sprite] = shaded
		end
		return renderer:blit(shaded, x, y)
	end
	return setmetatable(proxy, {
		__index = function(_, field)
			local value = renderer[field]
			if type(value) == "function" then
				return function(_, ...)
					return value(renderer, ...)
				end
			end
			return value
		end,
	})
end
return Fog
