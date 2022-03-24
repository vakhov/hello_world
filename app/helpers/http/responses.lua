local statuses = require('app.helpers.http.statuses')

local function json_response(req, json, status)
    local status = status or statuses.HTTP_200_OK
    local json = json or {}
    local resp = req:render({ json = json })

    resp.status = status
    return resp
end

local function key_create(req)
    local resp = json_response(req, {
        info = "Data has been recorded"
    }, statuses.HTTP_201_CREATED)

    return resp
end

local function key_update(req)
    local resp = json_response(req, {
        info = "Data has been update"
    }, statuses.HTTP_200_OK)

    return resp
end

local function bad_request(req)
    local resp = json_response(req, {
        info = "Bad request"
    }, statuses.HTTP_400_BAD_REQUEST)

    return resp
end

local function key_not_found_response(req)
    local resp = json_response(req, {
        info = "Key not found"
    }, statuses.HTTP_404_NOT_FOUND)

    return resp
end

local function key_exists(req, error)
    local resp = json_response(req, {
        info = "Conflict",
        error = error
    }, statuses.HTTP_409_CONFLICT)

    return resp
end

local function too_many_requests(req)
    local resp = json_response(req, {
        info = "Too many requests"
    }, statuses.HTTP_429_TOO_MANY_REQUESTS)

    return resp
end

local function internal_error_response(req, error)
    local resp = json_response(req, {
        info = "Internal error",
        error = error
    }, statuses.HTTP_500_INTERNAL_SERVER_ERROR)

    return resp
end

local function storage_error_response(req, error)
    if error.err == "Key exists" then
        return key_exists(req)
    elseif error.err == "Key not found" then
        return key_not_found_response(req)
    end

    return internal_error_response(req, error)
end

return {
    json_response = json_response,
    key_create = key_create,
    key_update = key_update,
    key_not_found_response = key_not_found_response,
    key_exists = key_not_found_response,
    too_many_requests = too_many_requests,
    internal_error_response = internal_error_response,
    storage_error_response = storage_error_response,
}
