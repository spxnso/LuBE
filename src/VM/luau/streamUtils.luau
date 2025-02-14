local streamUtils = {}
streamUtils.__index = streamUtils
function streamUtils.new(bytecode)
	local self = setmetatable({}, streamUtils)
	self.bytecode = bytecode
	self.pos = 1;
	return self
end

function streamUtils:readByte(deb)
	if self.pos > #self.bytecode then
		print(self.pos, #self.bytecode)
		error("Trying to read past end of stream")
	end
	if deb then
		print("Previous byte: ", self.bytecode:byte(self.pos - 1, self.pos - 1))
		print("Current byte: ", self.bytecode:byte(self.pos, self.pos))
		print("Nex byte: ", self.bytecode:byte(self.pos + 1, self.pos + 1))
	end
	local result = self.bytecode:byte(self.pos, self.pos)
	self.pos = self.pos + 1
	return result
end

function streamUtils:read4Bytes()
	local result = 0
	for i = 1, 4 do
		result = bit32.bor(result, bit32.lshift(self:readByte(), (i - 1) * 8))
	end
	return result
end

function streamUtils:read8Bytes()
	local result = 0
	for i = 1, 8 do
		result = bit32.bor(result, bit32.lshift(self:readByte(), (i - 1) * 8))
	end
	return result
end

function streamUtils:readVarInt()
	local result = 0
	local shift = 0
	local byte
	while true do
		byte = self:readByte()
		result = bit32.bor(result, bit32.lshift(bit32.band(byte, 127), shift))
		shift = shift + 7
		if bit32.band(byte, 128) == 0 then
			break
		end
	end
	return result
end

function streamUtils:parseString()
	local size = self:readVarInt()
	if size == 0 then
		return ""
	else
		local chars = {}
		for i = 1, size do
			local byte = self:readByte()
			table.insert(chars, string.char(byte))
		end
		return table.concat(chars)
	end
	return string, size
end

function streamUtils:readString(strings)
	local id = self:readVarInt()
	if id == 0 then
		return nil
	end
	return strings[id]
end

function streamUtils:readInt()
	local i = 0
	for j = 1, 4 do
		i = bit32.bor(i, bit32.lshift(self:readByte(), (j - 1) * 8))
	end
	return i
end

function streamUtils:readDouble()
    local lowInt = self:readInt()
    local highInt = self:readInt()

    local sign = bit32.band(highInt, 0x80000000) ~= 0 and -1 or 1
    local exponent = bit32.band(bit32.rshift(highInt, 20), 0x7FF)
    local fraction = bit32.band(highInt, 0xFFFFF) * 4294967296 + lowInt

    if exponent == 0 then
        fraction = fraction / (2 ^ 52)
        return sign * fraction
    end

    return sign * (2 ^ (exponent - 1023)) * (1 + fraction / (2 ^ 52))
end

function streamUtils:readFloat()
    local int = self:read4Bytes()

    local sign = bit32.band(int, 0x80000000) ~= 0 and -1 or 1
    local exponent = bit32.rshift(bit32.band(int, 0x7F800000), 23)
    local fraction = bit32.band(int, 0x007FFFFF)

    if exponent == 0 then
        return sign * (fraction / (2^23)) * (2^-126)
    elseif exponent == 255 then
        return fraction == 0 and (sign * math.huge) or (0/0)
    end
    return sign * (1 + (fraction / (2^23))) * (2^(exponent - 127))
end


return streamUtils
