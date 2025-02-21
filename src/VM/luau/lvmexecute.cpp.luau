-- Refer to: https://github.com/luau-lang/luau/blob/master/VM/src/lvmexecute.cpp
local objects = require("./lobject.h")
local streamUtils = require("./streamUtils")
local bytecode = require("./bytecode.h")

function lvm_execute(lvm_load_out)
	function luau_wrap(proto, env, upvalues)
		env = env or getfenv(1)
		return function(...)
			local stack, args, varargs = table.create(proto.maxstacksize), table.pack(...), {}
			local pc, top = 1, -1
			local run = true
			table.move(args, 1, proto.numparams, 0, stack)
			-- TODO: solve varargs
			local constants = proto.k
			local opcode, insn;
			while run do
				opcode = proto.code[pc]
                insn = bytecode.LUAU_INSN_OP(opcode) 
                if insn == 5 then -- [[ LOADK ]] --
                    pc += 1;
                    local a = bytecode.LUAU_INSN_A(opcode)
                    print("Register 1", a)
                elseif insn == 12 then 
                    pc += 1
				elseif insn == 65 then -- [[ PREPVARARGS ]] --
					pc += 1
					local numparams = bytecode.LUAU_INSN_A(opcode)
					if numparams < args.n then
						local start = numparams + 1
						local len = args.n - numparams

						varargs.n = len
						table.move(args, start, start + len, 1, varargs)
					end
				else
					print("Not handled", opcode)
					run = false
				end
			end
			print("Complete")
		end
	end
	local main = lvm_load_out.protos.mainProto
	luau_wrap(main, { print = print })()
	return
end

return {
	lvm_execute = lvm_execute,
}
