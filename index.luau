-- LuBE requires Lune to be installed in order to read files.
-- Compile command: luau-compile --binary -g0 input.luau > output.bin
local LVM_L = require("./src/VM/luau/lvmload.cpp")
local Beautify = require("./src/VM/luau/beautify")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local COMPILE_WITH_LUNE = true -- false if you didn't compile with Lune

local Bytecode;
if COMPILED_WITH_LUNE then 
    local file = fs.readFile("./input.luau")
    Bytecode = luau.compile(file);
else
    Bytecode = fs.readFile("./output.bin")
end 

local proto = LVM_L.luau_load(Bytecode, { print = print })
Beautify(proto)
