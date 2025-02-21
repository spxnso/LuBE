local bytecode = require("./bytecode.h")
local function beautify(lvm_load_out)
	local proto = lvm_load_out.protos.mainProto
	local function parseInstruction(instr)
        if instr == nil then return end
		local opcode = bytecode.LUAU_INSN_OP(instr)
		local opInfo = bytecode.formattedOpcodes[opcode]
		local opName = opInfo[1]
		local opMode = opInfo[2]
		local kMode = opInfo[3]
		local usesAux = opInfo[4]

		local Instruction = {
			info = {
				opcode = opcode,
				name = opName,
				opmode = opMode,
				kmode = kMode,
				usesAux = usesAux,
			},
			registers = {
				A = nil,
				B = nil,
				C = nil,
				D = nil,
				E = nil,
			},
		}

		-- Luau instructions has five modes:
		-- 1. A
		-- 2. AB
		-- 3. ABC
		-- 4. AD
		-- 5. AE
		--[[
            Instruction.registers.A = (opMode ~= 5 and bytecode.LUAU_INSN_A(instr) or nil)
			Instruction.registers.B = ((opMode == 2 or opMode == 3) and bytecode.LUAU_INSN_B(instr) or nil)
			Instruction.registers.C = (opMode == 3 and bytecode.LUAU_INSN_C(instr) or nil)
			Instruction.registers.D = (opMode == 4 and bytecode.LUAU_INSN_D(instr) or nil)
			Instruction.registers.E = (opMode == 5 and bytecode.LUAU_INSN_E(instr) or nil)
        -]]
		opMode = opMode - 1;
		if opMode == 0 then
			Instruction.registers.A = bytecode.LUAU_INSN_A(instr)
		elseif opMode == 1 then
			Instruction.registers.A = bytecode.LUAU_INSN_A(instr)
			Instruction.registers.B = bytecode.LUAU_INSN_B(instr)
		elseif opMode == 2 then
			Instruction.registers.A = bytecode.LUAU_INSN_A(instr)
			Instruction.registers.B = bytecode.LUAU_INSN_B(instr)
			Instruction.registers.C = bytecode.LUAU_INSN_C(instr)
		elseif opMode == 3 then
			Instruction.registers.A = bytecode.LUAU_INSN_A(instr)
			Instruction.registers.D = bytecode.LUAU_INSN_D(instr)
		elseif opMode == 4 then
			Instruction.registers.E = bytecode.LUAU_INSN_E(instr)
		end
		Instruction.info.opmode = bytecode.opmodeMap[opMode] or opMode
		return Instruction
	end
	local parsedInstructions = {}
	for i = 1, proto.sizecode do
		parsedInstructions[i] = parseInstruction(proto.code[i])
	end

	local colors = {
		reset = "\027[0m",
		red = "\027[31m",
		green = "\027[32m",
		yellow = "\027[33m",
		blue = "\027[34m",
		magenta = "\027[35m",
		cyan = "\027[36m",
		white = "\027[37m",
		bold = "\027[1m",
	}
	local function beautifyPrint(color, ...)
		print(colors[color] .. (...) .. colors.reset)
	end
	function printHeader()
		beautifyPrint(
			"cyan",
			"\n======================================== " .. "Header" .. " ========================================"
		)
		beautifyPrint("magenta", "Luau Version: " .. colors.green .. lvm_load_out.version .. colors.reset)
		beautifyPrint("magenta", "Types Version: " .. colors.green .. lvm_load_out.typesVersion .. colors.reset)
	end
	function printStrings()
		beautifyPrint(
			"cyan",
			"\n======================================== " .. "Strings" .. " ========================================"
		)
		beautifyPrint("yellow", "\n================ " .. "Informations" .. " ================")
		beautifyPrint(
			"magenta",
			"Number of Strings: " .. colors.green .. #lvm_load_out.strings.stringList .. colors.reset
		)
		beautifyPrint("yellow", "\n================ " .. "Values" .. " ================")
		for k, v in pairs(lvm_load_out.strings.stringList) do
			beautifyPrint(
				"magenta",
				"String " .. colors.green .. k .. colors.reset .. ": " .. colors.green .. v .. colors.reset
			)
		end
	end
	function printProtos()
		beautifyPrint(
			"cyan",
			"\n======================================== " .. "Prototypes" .. " ========================================"
		)
		beautifyPrint("yellow", "\n================ " .. "Informations" .. " ================")
		beautifyPrint("magenta", "Number of Protos: " .. colors.green .. lvm_load_out.protos.protoCount .. colors.reset)
		beautifyPrint("magenta", "Main Proto ID: " .. colors.green .. lvm_load_out.protos.mainId .. colors.reset)
		beautifyPrint("yellow", "\n================ " .. "Protos" .. " ================")
		for k, v in pairs(lvm_load_out.protos.protoList) do
			beautifyPrint("red", "\n==================== " .. "Proto: " .. k .. " ====================")
			local proto = lvm_load_out.protos.protoList[k]
			beautifyPrint("yellow", "\n================ " .. "Informations" .. " ================")
			beautifyPrint("magenta", "Bytecode ID: " .. colors.green .. proto.bytecodeid .. colors.reset)
			beautifyPrint("magenta", "Max Stack Size: " .. colors.green .. proto.maxstacksize .. colors.reset)
			beautifyPrint("magenta", "Num Params: " .. colors.green .. proto.numparams .. colors.reset)
			beautifyPrint("magenta", "Nups: " .. colors.green .. proto.nups .. colors.reset)
			beautifyPrint("magenta", "Is Vararg: " .. colors.green .. tostring(proto.is_vararg) .. colors.reset)
			beautifyPrint("magenta", "Code Size: " .. colors.green .. proto.sizecode .. colors.reset)
			beautifyPrint("magenta", "Line Defined: " .. colors.green .. proto.linedefined .. colors.reset)
			beautifyPrint("magenta", "Debug Name: " .. colors.green .. proto.debugname .. colors.reset)
			beautifyPrint(
				"magenta",
				"Line Info Enabled: " .. colors.green .. tostring(proto.lineinfoenabled) .. colors.reset
			)
			beautifyPrint("magenta", "Line Info: " .. colors.green .. tostring(proto.lineinfo) .. colors.reset)
			beautifyPrint("magenta", "Debug Info: " .. colors.green .. tostring(proto.debuginfo) .. colors.reset)
			beautifyPrint("yellow", "\n================ " .. "Instructions" .. " ================")
			beautifyPrint("magenta", "Mnemonic   Opcode   Opmode   KMode  Aux    A    B     C    D   E")
			for k, v in pairs(parsedInstructions) do
				local instr = parsedInstructions[k]
				beautifyPrint(
					"green",
					string.format(
						"%-12s %-7s %-6s %-7s %-6s %-4s %-4s %-4s %-4s %-4s",
						instr.info.name,
						instr.info.opcode,
						instr.info.opmode,
						instr.info.kmode,
						tostring(instr.info.usesAux),
						instr.registers.A and tostring(instr.registers.A) or "-",
						instr.registers.B and tostring(instr.registers.B) or "-",
						instr.registers.C and tostring(instr.registers.C) or "-",
						instr.registers.D and tostring(instr.registers.D) or "-",
						instr.registers.E and tostring(instr.registers.E) or "-"
					)
				)
			end
			beautifyPrint("yellow", "\n================ " .. "Constants" .. " ================")
			beautifyPrint("magenta", string.format("%-20s %-8s %-20s", "Type", "Pos", "Value"))
			for k, v in pairs(proto.formatTable) do
				beautifyPrint("green", string.format("%-20s %-8s %-20s", v.type, k, tostring(v.value)))
			end
		end
	end
	printHeader()
	printStrings()
	printProtos()
end

return beautify
