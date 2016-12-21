local cjson = require "cjson"
local sjs = require "proto_sjsonb"


local _mod = {_VERSION="0.1"}
local mt = {__index = _mod}


-- 获取用户uid
function _mod.getuidbyphone(phone)
    local sjsconn = sjs.new()
    if not sjsconn:connect("112.74.133.118", 3309) then
        return nil, "connect failed"
    end

    sjsconn:send(3, cjson.encode({interface="getuseridbyphone", token="rongle_736491", args={phone=phone}}))
    local _, rsp, err = sjsconn:receive()
    sjsconn:close()

    if err then
        return nil, "connection broken"
    end

    ngx.log(ngx.ERR, rsp)
    local jsn_rsp = cjson.decode(rsp)
    if 200 == tonumber(jsn_rsp.error_no) then
        return cjson.decode(jsn_rsp.data).uid, nil
    end

    return nil, nil
end


return setmetatable({}, mt)
