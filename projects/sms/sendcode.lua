local cjson = require("cjson");
local redis = require("resty.redis");
local misc = require("misc");
local sms_conf = require("rongle.sms_conf");


local main = function ()
    local rsp = {};

    ngx.header.content_type = "application/json";
    -- ngx.header["Access-Control-Allow-Origin"] = "*";
    if "POST" ~= ngx.req.get_method() then
        rsp["result"] = "405";
        rsp["message"] = "method not allowed";
        ngx.print(cjson.encode(rsp));
        return;
    end

    local h = ngx.req.get_headers()
    for k, v in pairs(h) do
        ngx.log(ngx.DEBUG, k, ": ", v);
    end

    local data = ngx.req.get_body_data();

    local args, err = ngx.req.get_post_args();
    local token = args["token"];
    local phone = args["phone"];
    local verifycode = args["verifycode"];
    if string.is_empty(token) or string.is_empty(phone) or string.is_empty(verifycode) then
        rsp["result"] = "406";
        rsp["message"] = "missing argument";
        ngx.print(cjson.encode(rsp));
        return;
    end
    if token ~= "rongle_sms317" then -- 简单鉴权
        rsp["result"] = "407";
        rsp["message"] = "invalid argument";
        ngx.print(cjson.encode(rsp));
        return;
    end

    -- 连接缓存
    local ok, err;
    local rds = redis:new();
    local cache_key = "rongle.sms." .. phone;
    rds:set_timeout(1000); -- 设置连接redis服务的超时时间
    ok, err = rds:connect("127.0.0.1", 6379);
    if not ok then
        ngx.log(ngx.ERR, "failed to connect to redis:", err);
        rsp["result"] = "500";
        rsp["message"] = "server failed";
        ngx.print(cjson.encode(rsp));
        return;
    end

    ok, err = rds:auth("rongle@6379");
    if not ok then
        ngx.log(ngx.ERR, "failed to auth to redis:", err);
        rsp["result"] = "500";
        rsp["message"] = "server failed";
        ngx.print(cjson.encode(rsp));
        return;
    end

    -- 短信发送频率控制
    local base64_val;
    local send_deny = true;
    base64_val, err = rds:get(cache_key);
    if ngx.null == base64_val then
        send_deny = false;
    else
        local val = ngx.decode_base64(base64_val);
        if ngx.null == val then
            -- 解码失败，删除kv
            ngx.log(ngx.ERR, "decode failed:" .. cache_key .. "," .. base64_val);
            rds.del(cache_key);
            send_deny = false;
        end
        
    end
    if send_deny then
        rsp["result"] = "408";
        rsp["message"] = "slow down";
        ngx.print(cjson.encode(rsp));
        return;
    end

    -- 访问短信网关
    local sms_rsp = ngx.location.capture("/sms?username=" .. sms_conf.username .. "&password=" .. sms_conf.password .. "&message=" .. verifycode .. "&phone=" .. phone .. "&epid=" .. sms_conf.epid .. "&linkid=&subcode=" .. sms_conf.subcode);
    if tonumber(sms_rsp.status) ~= 200 or "00" ~= sms_rsp.body then
        -- 请求短信网关失败
        ngx.log(ngx.ERR, "failed to send message to sms:%s,%s", sms_rsp.status, sms_rsp.body);
        rsp["result"] = "500";
        rsp["message"] = "server failed";
        ngx.print(cjson.encode(rsp));
        return;
    end

    -- 缓存验证码待校验

    local cache_val = {};
    cache_val.verifycode = verifycode;
    cache_val.checked = "0"; -- 是否已被校验
    ok, err = rds:setex("rongle.sms." .. phone, "10", ngx.encode_base64(cjson.encode(cache_val)));
    if not ok then
        ngx.log(ngx.ERR, "failed to set to redis:", err);
        rsp["result"] = "500";
        rsp["message"] = "server failed";
        ngx.print(cjson.encode(rsp));
        return;
    end

    rds:set_keepalive(60 * 1000); -- 长连接

    rsp["result"] = "200";
    rsp["message"] = "success";
    ngx.print(cjson.encode(rsp));
end


main();
