local RoomRules = {}

function RoomRules.sanitizeText(value: any, limit: number?): string
    local text = tostring(value or "")
    text = text:gsub("[%c]", " "):gsub("%s+", " ")
    text = text:match("^%s*(.-)%s*$") or ""
    return string.sub(text, 1, limit or 280)
end

function RoomRules.scoreDelta(value: any): number
    local delta = tonumber(value) or 0
    return math.clamp(math.floor(delta), -5000, 5000)
end

function RoomRules.cooldownReady(cooldowns: {[string]: number}, key: string, now: number, seconds: number): boolean
    local nextUse = cooldowns[key] or 0
    if now < nextUse then
        return false
    end
    cooldowns[key] = now + seconds
    return true
end

return RoomRules
