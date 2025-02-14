-- Uses lune to compile, feel free to use luau's default compiler.


local luau = require("@lune/luau")
local fs = require("@lune/fs")

local function formatBc(bytecode)
    local escaped = {}
    for i = 1, #bytecode do
        table.insert(escaped, "\\" .. string.byte(bytecode, i))
    end
    return '"' .. table.concat(escaped) .. '"'
end


function compile()
	local bytecode = luau.compile(fs.readFile("./input.luau"))
	print("Escaped", formatBc(bytecode))
	return bytecode
end
return compile
