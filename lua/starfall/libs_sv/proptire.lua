return function(instance)
	local types = instance.Types
	local E = types and types.Entity
	local V = types and types.Vector
	if not (E and E.Methods and E.Unwrap and V and V.Wrap) then return end
	local eunwrap, vwrap = E.Unwrap, V.Wrap
	local checkpermission = instance.player ~= SF.Superuser and SF.Permissions.check or function() end

	function E.Methods:getPropTireInfo()
		local ent = eunwrap(self)
		if not PropTire or not PropTire.Info then return nil end
		local info = PropTire.Info(ent)
		if not info then return nil end
		info.force = vwrap(info.force)
		return info
	end

	function E.Methods:setPropTireWarmer(temp)
		SF.CheckLuaType(temp, TYPE_NUMBER)
		local ent = eunwrap(self)
		if not PropTire or not PropTire.SetWarmer or not IsValid(ent) or not ent.PropTire then return false end
		checkpermission(instance, ent, "entities.applyForce")
		return PropTire.SetWarmer(ent, temp)
	end
end
