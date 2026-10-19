return function(instance)
	local types = instance.Types
	local E = types and types.Entity
	local V = types and types.Vector
	if not (E and E.Methods and E.Unwrap and V and V.Wrap) then return end
	local eunwrap, vwrap = E.Unwrap, V.Wrap

	function E.Methods:getPropTireInfo()
		local ent = eunwrap(self)
		if not PropTire or not PropTire.Info then return nil end
		local info = PropTire.Info(ent)
		if not info then return nil end
		info.force = vwrap(info.force)
		return info
	end
end
