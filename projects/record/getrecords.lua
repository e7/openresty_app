local cjson = require "cjson"
local lfs = require "lfs"
local base_dir = "/var/record"
local base_url = "http://120.76.155.45:8888/record"


function main()
    local rsp = {}
    local method = ngx.req.get_method()

    if "GET" ~= method then
        ngx.exit(ngx.HTTP_NOT_ALLOWED)
        return
    end

    local rid, date = nil, nil
    local args = ngx.req.get_uri_args()
    for key, val in pairs(args) do
        if "robotid" == key then
            rid = val
        end
        if "date" == key then
            date = val
        end
    end

    if nil == rid or nil == date then
        rsp["error_no"] = "401"
        rsp["error_msg"] = "missing argument"
        ngx.print(cjson.encode(rsp))
        return
    end

    local home_dir = base_dir .. "/" .. rid .. "/" .. date
    local status, gnrt, data = pcall(lfs.dir, home_dir)
    if not status then
        rsp["error_no"] = "404"
        rsp["error_msg"] = "not found"
        ngx.print(cjson.encode(rsp))
        return
    end

    local count = 0
    local filelist = {}
    rsp["error_no"] = "200"
    rsp["error_msg"] = "success"
    for file in gnrt, data do
        local path = home_dir .. "/" .. file

        local attr,err = lfs.attributes(path)
        if attr and "file" == attr.mode then
            count = count + 1
            local rfile = string.reverse(file)
            local _, i = string.find(rfile, "%.")
            table.insert(filelist, {
                desc=string.sub(file, 1, string.len(rfile) - i), url=base_url .. "/" .. rid .. "/" .. file
            })
        end
    end
    rsp["listcount"] = tostring(count)
    rsp["filelist"] = filelist

    cjson.encode_empty_table_as_object(false)
    ngx.print(cjson.encode(rsp))
end


main()
