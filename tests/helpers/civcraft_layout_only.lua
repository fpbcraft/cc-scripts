-- Layout/interaction tests exercise the actual UI state and button geometry,
-- without allocating or rasterizing the full frame on every draw.
-- Keep pixel, clipping and animation-visual tests on the real renderer.
return function(UI)
	local create = UI.new
	UI.new = function(monitor, dispatch)
		return create(monitor, dispatch, { layoutOnly = true })
	end
end
