local checks = require('checks')
local errors = require('errors')

local err_storage = errors.new_class("Storage error")

local function init_space()
    local kv = box.schema.space.create(
        'kv',
        {
            format = {
                { 'key', 'string' },
                { 'value', 'string' },
            },

            if_not_exists = true,
        }
    )

    kv:create_index('key', {
        parts = { 'key' },
        unique = true,
        if_not_exists = true,
    })
end

function kv_add(key, value)
    checks('string', 'string')

    local kv = box.space.kv:get(key)

    if kv ~= nil then
        return { kv = nil, error = err_storage:new("Key exists") }
    end

    box.space.kv:insert({ key, value })

    return { kv = kv, error = nil }
end

function kv_get(key)
    checks('string')

    local kv = box.space.kv:get(key)

    if kv == nil then
        return { kv = nil, error = err_storage:new("Key not found") }
    end

    return { kv = kv, error = nil }
end

function kv_update(key, value)
    checks('string', 'string')

    local kv = box.space.kv:get(key)

    if kv == nil then
        return { kv = nil, error = err_storage:new("Key not found") }
    end

    box.space.kv:update(key, { { '=', 'value', value } })
    return { kv = box.space.kv:get(key), error = nil }
end

function kv_delete(key)
    checks('string')

    local kv = box.space.kv:get(key)

    if kv == nil then
        return { ok = false, error = err_storage:new("Key not found") }
    end

    box.space.kv:delete(key)
    return { ok = true, error = nil }
end

local function init(opts)
    if opts.is_master then
        init_space()

        box.schema.func.create('kv_add', { if_not_exists = true })
        box.schema.func.create('kv_get', { if_not_exists = true })
        box.schema.func.create('kv_update', { if_not_exists = true })
        box.schema.func.create('kv_delete', { if_not_exists = true })
    end

    rawset(_G, 'kv_add', kv_add)
    rawset(_G, 'kv_get', kv_get)
    rawset(_G, 'kv_update', kv_update)
    rawset(_G, 'kv_delete', kv_delete)

    return true
end

return {
    role_name = 'kv_storage',
    init = init,
    utils = {
        kv_add = kv_add,
        kv_get = kv_get,
        kv_update = kv_update,
        kv_delete = kv_delete,
    },
    dependencies = {
        'cartridge.roles.vshard-storage'
    }
}
