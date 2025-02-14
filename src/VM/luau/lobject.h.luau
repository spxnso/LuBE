-- Refer to: https://github.com/luau-lang/luau/blob/master/VM/src/lobject.h

function ttisnil(o)
	return type(o) == "nil"
end

function ttisnumber(o)
	return type(o) == "number"
end

function ttisstring(o)
	return type(o) == "string"
end

function ttistable(o)
	return type(o) == "table"
end

function ttisfunction(o)
	return type(o) == "function"
end

function ttisboolean(o)
	return type(o) == "boolean"
end

function ttisuserdata(o)
	return type(o) == "usersdata"
end

return {
	ttisnil = ttisnil,
	ttisnumber = ttisnumber,
	ttisstring = ttisstring,
	ttistable = ttistable,
	ttisfunction = ttisfunction,
	ttisboolean = ttisboolean,
	ttisuserdata = ttisuserdata,
}
