local cjson = require("cjson");
local redis = require("resty.redis");
local tm = require("test_module");


local a = 1;
local b = 1;
ngx.say("sum:" .. tm.sum(a, b));
