-- Opening this file makes Zed auto-install the `lua` extension, whose
-- language server (lua-language-server) downloads in the background.
local function greet(name)
    return "hello from Lua, " .. name
end

print(greet("Zed"))
