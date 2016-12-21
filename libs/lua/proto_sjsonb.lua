-- sjsonb协议模块
local cjson = require("cjson");
local ltspack = require("ltspack")
local ngx_socket_tcp = ngx.socket.tcp

local _mod = {}


function _mod.new()
    local sock, err = ngx_socket_tcp()
    if not sock then
        return  nil, err
    end

    return setmetatable({_sock = sock}, {__index = _mod})
end


function _mod.connect(self, host, port)
    local ok, err = self._sock:connect(host, port)
    if not ok then
        return false
    end

    self._sock:settimeout(3000)

    return true
end


function _mod.send(self, contype, data)
    local package = string.pack(">I2S2I2A",
        0xE78F8A9D, 1000, contype, 20, #data, 0, data)

    return self._sock:send(package)
end


function _mod.receive(self)
    local MAGIC = string.char(0xE7, 0x8F, 0x8A, 0x9D)

    while true do
        local magic, err, _ = self._sock:receive(4)
        if err then
            ngx.print(err)
            return nil, nil, err
        end

        if MAGIC == magic then
            local hd, err, _ = self._sock:receive(16)
            if err then
                ngx.print(err)
                return nil, nil, err
            end

            local _, version, ent_type, ent_ofst, ent_len, checksum = string.unpack(hd, ">IS2I2", 1)
            if 1000 == version
                and ent_ofst >= 20 and ent_ofst <= 64
                and ent_len > 0 and ent_len < 12000 then
                local content, err, _ = self._sock:receive(ent_len)
                if err then
                    return nil, nil, err
                end

                return ent_type, content, nil
            end
        end
    end
end


function _mod.close(self)
    return self._sock:setkeepalive(0)
end


return _mod
