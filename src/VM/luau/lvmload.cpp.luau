-- Refer to: https://github.com/luau-lang/luau/blob/master/VM/src/lvmload.cpp
local objects = require("./lobject.h")
local streamUtils = require("./streamUtils")
local bytecode = require("./bytecode.h")
local compileBytecode = require("./compiler")

function luaV_getimport(env, k, id, propagatenil)
	local count = bit32.rshift(id, 30)
	local res
	assert(count > 0, "Assertion failed: count must be greater than 0", debug.traceback(), 2)
	local id0 = (bit32.band(bit32.rshift(id, 20), 1023) + 1) or -1
	local id1 = (bit32.band(bit32.rshift(id, 10), 1023) + 1) or -1
	local id2 = (bit32.band(id, 1023) + 1) or -1
	res = env[k[id0]]
	if count > 2 then
		return
	end
	if (not propagatenil) or (not objects.ttisnil(res)) then
		res = env[k[id1]]
	end
	if count > 3 then
		return
	end
	if (not propagatenil) or (not objects.ttisnil(res)) then
		res = env[k[id2]]
	end
	return res
end

function luau_load(data, env)
	local env = env or getfenv()
	local streamUtils = streamUtils.new(data)
	local version = streamUtils:readByte()
	if version == 0 then
		error(string.format("lvm_load: %s", (streamUtils.bytecode:sub(2))))
		return 1
	end
	if version < bytecode.LBC_VERSION_MIN or version > bytecode.LBC_VERSION_MAX then
		error(
			string.format(
				"lvm_load: bytecode version mismatch (expected [%d..%d], got %d)",
				bytecode.LBC_VERSION_MIN,
				bytecode.LBC_VERSION_MAX,
				version
			)
		)
		return 1
	end

	local typesVersion = 0
	if version >= 4 then
		typesVersion = streamUtils:readByte()
		if (typesVersion < bytecode.LBC_TYPE_VERSION_MIN) or typesVersion > bytecode.LBC_TYPE_VERSION_MAX then
			error(
				string.format(
					"lvm_load: bytecode type version mismatch (expected [%d..%d], got %d)",
					bytecode.LBC_TYPE_VERSION_MIN,
					bytecode.LBC_TYPE_VERSION_MAX,
					typesVersion
				)
			)
			return 1
		end
	end

	local stringCount = streamUtils:readVarInt()
	local strings = table.create(stringCount)
	for i = 1, stringCount do
		local string, length = streamUtils:parseString()

		strings[i] = string
	end

	-- Userdata remapping
	if typesVersion == 3 then
		local index = streamUtils:readByte()

		while index ~= 0 do
			streamUtils:readVarInt()

			index = streamUtils:readByte()
		end
	end
	local protoCount = streamUtils:readVarInt()
	local protos = table.create(protoCount)

	for i = 1, protoCount do
		local bytecodeid = i -- - 1 for 0 indexing.
		local maxstacksize = streamUtils:readByte()
		local numparams = streamUtils:readByte()

		local nups = streamUtils:readByte()

		local is_vararg = streamUtils:readByte() == 1
		if version >= 4 then
			local flags = streamUtils:readByte()

			if typesVersion == 1 then
				local typesize = streamUtils:readVarInt()

				if typesize then
					local types = data:sub(streamUtils.pos + 1, streamUtils.pos + typesize)

					assert(typesize == (2 + numparams), "Assertion failed: typesize must be equal to 2 + numparams")
					assert(
						types:byte(1) == bytecode.LBC_TYPE_FUNCTION,
						"Assertion failed: types:byte(1) must be equal to bytecode.LBC_TYPE_FUNCTION"
					)
					assert(types:byte(2) == numparams, "Assertion failed: types:byte(2) must be equal to numparams")

					local headersize = (typesize > 127 and 4 or 3)
					local typeinfo = {}

					if headersize == 4 then
						typeinfo[1] = bit32.bor(bit32.band(typesize, 127), bit32.lshift(1, 7))
						typeinfo[2] = bit32.rshift(typesize, 7)
						typeinfo[3] = 0
						typeinfo[4] = 0
					else
						typeinfo[1] = typesize
						typeinfo[2] = 0
						typeinfo[3] = 0
					end
					for i = 1, typesize do
						typeinfo[headersize + i] = types:byte(i)
					end
				end

				streamUtils.pos = streamUtils.pos + typesize
			elseif typesVersion == 2 or typesVersion == 3 then
				local typesize = streamUtils:readVarInt()

				if typesize then
					local types = data:sub(streamUtils.pos + 1, streamUtils.pos + typesize)
					local typeinfo = {}

					for i = 1, typesize do
						typeinfo[i] = types:byte(i)
					end

					if typesVersion == 3 then
						-- userdata remap
					end
				end

				streamUtils.pos = streamUtils.pos + typesize
			end
		end

		local sizecode = streamUtils:readVarInt()
		local code = table.create(sizecode)
		local skipnext = false

		for j = 1, sizecode do
			if skipnext then
				streamUtils:read4Bytes()
				skipnext = false 
			else
				local op = streamUtils:read4Bytes()
				local useAux = bytecode.formattedOpcodes[bytecode.LUAU_INSN_OP(op)][4]
				code[j] = op

				if useAux then
					skipnext = true
				end
			end
		end

		local sizek = streamUtils:readVarInt()
		local k = table.create(sizek)
		local formatTable = table.create(sizek)

		for j = 1, sizek do
			local ct = streamUtils:readByte()
			local konstant
			for k, v in pairs(bytecode.LuauBytecodeTag) do
				if v == ct then
					konstant = tostring(k)
				end
			end
			formatTable[j] = {
				type = konstant,
				value = nil,
			}
			if ct == bytecode.LuauBytecodeTag.LBC_CONSTANT_NIL then
				k[j] = nil
			elseif ct == bytecode.LuauBytecodeTag.LBC_CONSTANT_BOOLEAN then
				k[j] = (streamUtils:readByte() == 1)
				formatTable[j].value = k[j]
			elseif ct == bytecode.LuauBytecodeTag.LBC_CONSTANT_NUMBER then
				k[j] = streamUtils:readDouble()
				formatTable[j].value = k[j]
			elseif ct == bytecode.LuauBytecodeTag.LBC_CONSTANT_STRING then
				k[j] = streamUtils:readString(strings)
				formatTable[j].value = k[j]
			elseif ct == bytecode.LuauBytecodeTag.LBC_CONSTANT_IMPORT then
				local importId = streamUtils:read4Bytes()
				k[j] = luaV_getimport(env, k, importId, true)
				formatTable[j].value = k[j]
			elseif ct == bytecode.LuauBytecodeTag.LBC_CONSTANT_TABLE then
				local keys = readVarInt()
				local t = table.create(keys)
				for i = 1, keys do
					local key = readVarInt()
					t[key] = k[key]
				end
			elseif ct == bytecode.LuauBytecodeTag.LBC_CONSTANT_CLOSURE then
				local protoId = streamUtils:readVarInt()
				k[j] = protos[protoId]
				formatTable[j].value = k[j]
			elseif ct == bytecode.LuauBytecodeTag.LBC_CONSTANT_VECTOR then
				local x, y, z, w =
					streamUtils:readFloat(), streamUtils:readFloat(), streamUtils:readFloat(), streamUtils:readFloat()
				k[j] = Vector4.new(x, y, z, w)
				formatTable[j].value = k[j]
			end
		end
		local sizep = streamUtils:readVarInt()
		local p = table.create(sizep)
		for j = 1, sizep do
			local fid = streamUtils:readVarInt()
			p[j] = protos[fid]
		end
		local linedefined = streamUtils:readVarInt()
		local debugname = streamUtils:readString(strings)
		if debugname == nil then
			debugname = "(??)"
		end

		local lineinfo = streamUtils:readByte()
		local lineinfoenabled = lineinfo == 1
		if lineinfoenabled then
			local linegaplog2 = streamUtils:readByte()
			local intervals = (bit32.rshift((sizecode - 1), linegaplog2)) + 1
			local absoffset = bit32.band((sizecode + 3), bit32.bnot(3))

			local sizelineinfo = absoffset + intervals
			lineinfo = table.create(sizelineinfo)
			local abslineinfo = table.create(intervals)

			local lastoffset = 0
			for j = 1, sizecode do
				lastoffset = lastoffset + streamUtils:readByte()
				lineinfo[j] = lastoffset + 1
			end

			local lastline = 0
			for j = 1, intervals do
				lastline = lastline + streamUtils:read4Bytes()
				abslineinfo[j] = lastline
			end
			-- Thanks Fiu
			local instrLineInfo = table.create(sizecode)
			for i = 1, sizecode do
				table.insert(instrLineInfo, abslineinfo[bit32.rshift(i - 1, linegaplog2) + 1] + lineinfo[i])
			end
		end

		local debuginfo = streamUtils:readByte()
		if debuginfo == 1 then
			local sizelocvars = streamUtils:readVarInt()
			local locvars = table.create(sizelocvars)

			for j = 1, sizelocvars do
				locvars[j] = {
					varname = streamUtils:readString(strings),
					startpc = streamUtils:readVarInt(),
					endpc = streamUtils:readVarInt(),
					reg = streamUtils:readByte(),
				}
			end
			local sizeupvalues = streamUtils:readVarInt()
			assert(sizeupvalues == nups, "Assertion failed: sizeupvalues must be equal to nups")
			local upvalues = table.create(sizeupvalues)
			for j = 1, sizeupvalues do
				upvalues[j] = streamUtils:readString(strings)
			end
		end
		protos[i] = {
			bytecodeid = bytecodeid,
			maxstacksize = maxstacksize,
			numparams = numparams,
			nups = nups,
			is_vararg = is_vararg,
			code = code,
			sizecode = sizecode,
			k = k,
			formatTable = formatTable,
			p = p,
			linedefined = linedefined,
			debugname = debugname,
			lineinfoenabled = lineinfoenabled,
			lineinfo = lineinfo,
			debuginfo = debuginfo,
		}
	end
	local mainId = streamUtils:readVarInt() + 1

	return {
		version = version,
		typesVersion = typesVersion,
		strings = {
			stringCount = stringCount,
			stringList = strings,
		},
		protos = {
			protoList = protos,
			protoCount = protoCount,
			mainId = mainId,
			mainProto = protos[mainId],
		},
	}
end

return {
	luau_load = luau_load,
}
