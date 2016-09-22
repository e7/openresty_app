-- sjsonb协议模块
local cjson = require("cjson");
local _mod = {}


function _mod.new(val)
    return setmetatable({value = val}, {__index = _mod})
end


function _mod.printf(self)
    print(self.value)
end

return _mod
