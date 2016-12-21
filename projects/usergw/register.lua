local cjson = require "cjson"
local sjs = require "proto_sjsonb"
local sa = require "sqlagent"
local misc = require "misc"


function main()
    -- ngx.header["Access-Control-Allow-Origin"] = "*"
    if "POST" ~= ngx.req.get_method() then
        ngx.exit(ngx.HTTP_NOT_ALLOWED)
        return
    end

    local rsp = {}
    ngx.header.content_type = "application/json"

    -- 参数检查
    ngx.req.get_body_data()
    local args, err = ngx.req.get_post_args()
    local phone = args["phone"]
    local pswd = args["password"]
    local verifycode = args["verifycode"]
    if string.is_empty(phone) or string.is_empty(pswd) or string.is_empty(verifycode) then
        rsp["result"] = "406"
        rsp["message"] = "missing argument"
        ngx.print(cjson.encode(rsp))
        return
    end

    -- 验证码校验
    local sms_rsp = ngx.location.capture("/smsgateway",
        {method = ngx.HTTP_POST, body = string.format("token=%s&phone=%s&verifycode=%s", "rongle_sms317c", phone, verifycode)}
    )
    if tonumber(sms_rsp.status) ~= 200 then
        ngx.log(ngx.ERR, "sms gateway failed")
        rsp["result"] = "500"
        rsp["message"] = "server failed"
        ngx.print(cjson.encode(rsp))
        return
    end
    local jsn_sms = cjson.decode(sms_rsp.body)
    if tonumber(jsn_sms["result"]) ~= 200 then
        rsp["result"] = "407"
        rsp["message"] = "invalid verifycode"
        ngx.print(cjson.encode(rsp))
        return
    end

    -- 检测该用户是否已注册
    local uid, err = sa.getuidbyphone(phone)
    if err then
        ngx.log(ngx.ERR, err)
        rsp["error_no"] = "500"
        rsp["error_msg"] = "server failed"
        ngx.print(cjson.encode(rsp))
        return
    end

    if uid then
        rsp["error_no"] = "201"
        rsp["error_msg"] = "exists yet"
        ngx.print(cjson.encode(rsp))
        return
    end

    local sjsconn = nil

    local contype, content, err -- sjsonb协议响应

    -- 生成uid
    sjsconn = sjs.new()
    if not sjsconn:connect("218.77.58.32", 8397) then
        rsp["error_no"] = "500"
        rsp["error_msg"] = "server failed"
        ngx.print(cjson.encode(rsp))
        return
    end
    sjsconn:send(3, cjson.encode({interface="genuid", token="rongle_736491"}))
    contype, content, err = sjsconn:receive()
    if err then
        ngx.print(err)
        sjsconn:close()
    end
    sjsconn:close()
    local uid = cjson.decode(content).uid

    -- 注册
    if not sjsconn:connect("112.74.133.118", 3309) then
        ngx.log(ngx.ERR, "connect to sqlagent failed")
        rsp["error_no"] = "500"
        rsp["error_msg"] = "server failed"
        ngx.print(cjson.encode(rsp))
        return
    end
    sjsconn:send(3, cjson.encode({interface="register", token="rongle_736491", args={uid=uid, phone=phone, password=pswd}}))
    contype, content, err = sjsconn:receive()
    if err then
        ngx.log(ngx.ERR, err)
        rsp["error_no"] = "500"
        rsp["error_msg"] = "server failed"
        ngx.print(cjson.encode(rsp))
        return
    end
    ngx.print(content)
    sjsconn:close()
end


main()
