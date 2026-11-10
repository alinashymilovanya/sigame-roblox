local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PackService = {}

local function request(path: string, method: string, body): (boolean, any)
    local options = {
        Url = config.CatalogUrl .. path,
        Method = method,
        Headers = { ["Content-Type"] = "application/json" },
    }
    if body then
        options.Body = HttpService:JSONEncode(body)
    end

    local ok, response = pcall(function()
        return HttpService:RequestAsync(options)
    end)
    if not ok or not response.Success then
        return false, { error = ok and response.StatusMessage or tostring(response) }
    end

    local decodeOk, payload = pcall(function()
        return HttpService:JSONDecode(response.Body)
    end)
    if not decodeOk then
        return false, { error = "catalog returned invalid JSON" }
    end
    return true, payload
end

function PackService.Search(query: string, tag: string, sort: string)
    local encodedQuery = HttpService:UrlEncode(query or "")
    local encodedTag = HttpService:UrlEncode(tag or "")
    local encodedSort = HttpService:UrlEncode(sort or "popular")
    return request("/workshop/search?q=" .. encodedQuery .. "&tag=" .. encodedTag .. "&sort=" .. encodedSort, "GET")
end

function PackService.Install(workshopId: string)
    return request("/workshop/install", "POST", { workshopId = workshopId })
end

return PackService

