local cartridge = require('cartridge')
local json = require('json')
local log = require('log')

local config = require('app.config')
local list = require('app.helpers.list')
local response = require('app.helpers.http.responses')
local storage = require('app.storage')

local list_limit = {}

function check_ups_limit()
    local now = os.time()

    list.List.pushright(list_limit, now)
    if list_limit.last - list_limit.first >= config.ups_limit then
        if now - list.List.popleft(list_limit) < 1 then
            return true
        end
    end
    return false
end

local function http_kv_get(req)
    if check_ups_limit() == true then
        return response.too_many_requests(req)
    end

    local key = req:stash('key')

    log.info('\n\nMethod: GET\nKey: %s\n\n', key)

    local result = storage.utils.kv_get(key)

    if result.error == nil then
        return response.json_response(req, result.kv)
    end

    return response.storage_error_response(req, result.error)
end

local function http_kv_add(req)
    if check_ups_limit() == true then
        return response.too_many_requests(req)
    end

    local body = req:json()
    local key = body.key
    local value = body.value

    if key == nil or value == nil then
        response.bad_request(req)
    end

    value = json.encode(value)

    log.info('\n\nMethod: POST\nKey: %s\n\nValue: %s', key, value)

    local result = storage.utils.kv_add(key, value)

    if result.error == nil then
        return response.key_create(req, result.kv)
    end

    return response.storage_error_response(req, result.error)
end

local function http_kv_update(req)
    if check_ups_limit() == true then
        return response.too_many_requests(req)
    end

    local key = req:stash('key')

    local body = req:json()
    local value = body.value

    if value == nil then
        response.bad_request(req)
    end

    value = json.encode(value)

    log.info('\n\nMethod: PUT\nKey: %s\n\nValue: %s', key, value)

    local result = storage.utils.kv_update(key, value)

    if result.error == nil then
        return response.key_update(req)
    end

    return response.storage_error_response(req, result.error)
end

local function http_kv_delete(req)
    if check_ups_limit() == true then
        return response.too_many_requests(req)
    end

    local key = req:stash('key')

    log.info('\n\nMethod: DELETE\nKey: %s', key)

    local result = storage.utils.kv_delete(key)

    if result.error == nil then
        return response.json_response(req)
    end

    return response.storage_error_response(req, result.error)
end

local function init(opts)
    if opts.is_master then
        box.schema.user.grant('guest',
            'read,write',
            'universe',
            nil, { if_not_exists = true }
        )
    end

    box.cfg { log_level = 5 }

    list_limit = list.List.new()

    local httpd = assert(cartridge.service_get('httpd'), "Failed to get httpd service")

    log.info("Starting httpd")
    httpd:route(
        { method = 'GET', path = '/kv/:key', public = true },
        http_kv_get
    )
    httpd:route(
        { method = 'POST', path = '/kv', public = true },
        http_kv_add
    )
    httpd:route(
        { method = 'PUT', path = '/kv/:key', public = true },
        http_kv_update
    )
    httpd:route(
        { method = 'DELETE', path = '/kv/:key', public = true },
        http_kv_delete
    )

    log.info("Created httpd")
    return true
end

return {
    role_name = 'api',
    init = init,
    dependencies = { 'cartridge.roles.vshard-router' },
}
