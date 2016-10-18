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

    ngx.req.get_body_data();

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

    -- 参数有效性检查
    if string.len(phone) > 20 or string.len(verifycode) > 16 then
        rsp["result"] = "407";
        rsp["message"] = "invalid argument";
        ngx.print(cjson.encode(rsp));
        return;
    end
    if token ~= "rongle_sms317c" then -- 简单鉴权
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

    -- 验证码校验
    local base64_val;
    base64_val, err = rds:get(cache_key);
    if ngx.null == base64_val then
        rsp["result"] = "404";
        rsp["message"] = "not exist";
        ngx.print(cjson.encode(rsp));
        return;
    end

    local val = ngx.decode_base64(base64_val);
    if ngx.null == val then
        -- 解码失败，删除kv
        ngx.log(ngx.ERR, "decode base64 failed:" .. cache_key .. "," .. base64_val);
        rds:del(cache_key);

        rsp["result"] = "404";
        rsp["message"] = "not exist";
        ngx.print(cjson.encode(rsp));
        return;
    end

    local t_val = cjson.decode(val)
    if ngx.null == t_val then
        -- 非json格式
        ngx.log(ngx.ERR, "decode json failed:" .. val)
        rds:del(cache_key);

        rsp["result"] = "404";
        rsp["message"] = "not exist";
        ngx.print(cjson.encode(rsp));
        return;
    end

    if verifycode ~= t_val.verifycode then
        rsp["result"] = "404";
        rsp["message"] = "not exist";
        ngx.print(cjson.encode(rsp));
        return;
    end

    rds:del(cache_key); -- 校验成功，删除kv   
    rds:set_keepalive(60 * 1000); -- 长连接

    rsp["result"] = "200";
    rsp["message"] = "success";
    ngx.print(cjson.encode(rsp));
end


main();
