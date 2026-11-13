-- Offline simulation of GameServer.server.luau (host + 2 players) with stubbed Roblox API.
-- Run: .tools\luau\luau.exe tests\sim_server.luau

local realRequire = require   -- captured before the Roblox-style require stub is installed

local failures = 0
local checks = 0
local function check(condition, label, detail)
    checks += 1
    if condition then
        print("  ok    " .. label)
    else
        failures += 1
        print("  FAIL  " .. label .. (detail ~= nil and ("   << " .. tostring(detail)) or ""))
    end
end
local function section(name) print("\n== " .. name .. " ==") end

----------------------------------------------------------------------
-- Vector3 / CFrame / Color3 / UDim2 / Enum stubs
----------------------------------------------------------------------
local V3 = {}
V3.__index = function(t, k)
    if k == "Unit" then
        local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
        if m == 0 then m = 1 end
        return V3.new(t.X / m, t.Y / m, t.Z / m)
    elseif k == "Magnitude" then
        return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
    end
    return V3[k]
end
function V3.new(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end
V3.__sub = function(a, b) return V3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__add = function(a, b) return V3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__mul = function(a, b)
    if type(b) == "number" then return V3.new(a.X * b, a.Y * b, a.Z * b) end
    return V3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__tostring = function(a) return string.format("(%.1f, %.1f, %.1f)", a.X, a.Y, a.Z) end
Vector3 = { new = V3.new }

local CF = {}
CF.__index = CF
function CF.new(x, y, z)
    return setmetatable({ Position = V3.new(x, y, z), LookVector = V3.new(0, 0, -1) }, CF)
end
CF.__add = function(cf, v) return CF.new(cf.Position.X + v.X, cf.Position.Y + v.Y, cf.Position.Z + v.Z) end
CFrame = { new = CF.new }

local C3 = {}
C3.__index = C3
function C3.new(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3) end
function C3.fromRGB(r, g, b) return C3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
function C3.__eq(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
C3.__tostring = function(a) return string.format("rgb(%.2f,%.2f,%.2f)", a.R, a.G, a.B) end
Color3 = C3

UDim2 = {
    fromOffset = function(x, y) return { X = x, Y = y, kind = "offset" } end,
    fromScale = function(x, y) return { X = x, Y = y, kind = "scale" } end,
}

local function enumGroup(names)
    local group = {}
    for _, name in ipairs(names) do group[name] = { Name = name } end
    return group
end
Enum = {
    PartType = enumGroup({ "Ball", "Cylinder", "Block" }),
    Material = enumGroup({ "SmoothPlastic", "Neon", "Plastic" }),
    Font = enumGroup({ "Gotham", "GothamBold", "GothamMedium" }),
}

----------------------------------------------------------------------
-- Instance stub
----------------------------------------------------------------------
local InstanceMT = {}
InstanceMT.__index = InstanceMT
Instance = {}
local remoteFactory = nil   -- set once the RemoteEvent stub exists
function Instance.new(className)
    if className == "RemoteEvent" and remoteFactory then
        return remoteFactory(className)
    end
    local created = setmetatable({ ClassName = className, Name = className, children = {} }, InstanceMT)
    rawset(created, "Position", V3.new(0, 0, 0))
    rawset(created, "CFrame", CF.new(0, 0, 0))
    return created
end
function InstanceMT.__newindex(self, key, value)
    if key == "Parent" then
        rawset(self, "Parent", value)
        if value and rawget(value, "children") then
            table.insert(value.children, self)
        end
        return
    end
    rawset(self, key, value)
    -- Roblox keeps Part.Position in sync with Part.CFrame
    if key == "CFrame" and type(value) == "table" and value.Position then
        rawset(self, "Position", value.Position)
    end
end
function InstanceMT.FindFirstChild(self, name)
    for _, child in ipairs(rawget(self, "children") or {}) do
        if child.Name == name then return child end
    end
    return nil
end
function InstanceMT.WaitForChild(self, name)
    return self:FindFirstChild(name) or Instance.new("Configuration")
end
function InstanceMT.GetChildren(self) return rawget(self, "children") or {} end
function InstanceMT.ClearAllChildren(self) rawset(self, "children", {}) end
function InstanceMT.Destroy(self) rawset(self, "children", {}) end
function InstanceMT.IsA(self, className) return rawget(self, "ClassName") == className end

----------------------------------------------------------------------
-- Signals / players
----------------------------------------------------------------------
local function newSignal()
    local signal = { handlers = {} }
    function signal:Connect(fn)
        table.insert(self.handlers, fn)
        return { Disconnect = function() end, Connected = true }
    end
    function signal:Fire(...)
        for _, fn in ipairs(self.handlers) do fn(...) end
    end
    function signal:Once(fn)
        local once = nil
        once = self:Connect(function(...)
            fn(...)
            for index, handler in ipairs(self.handlers) do
                if handler == once then table.remove(self.handlers, index) break end
            end
        end)
        return once
    end
    return signal
end

local PLAYERS = {}
local playerById = {}

local function makePlayer(userId, displayName)
    local player = {
        UserId = userId,
        DisplayName = displayName,
        Name = displayName,
        Character = nil,
        kicked = nil,
        color = nil,
    }
    local root = {
        CFrame = CF.new(0, 3, 0),
        Position = V3.new(0, 3, -15),
        Name = "HumanoidRootPart",
        children = {},
    }
    root.FindFirstChild = function(self, name) if name == "HumanoidRootPart" then return root end return nil end
    local character = {
        children = {},
        Name = displayName,
    }
    character.FindFirstChild = function(self, name)
        if name == "HumanoidRootPart" then return root end
        return nil
    end
    character.PivotTo = function(self, cframe) root.CFrame = cframe; root.Position = cframe.Position end
    player.Character = character
    player.root = root
    player.character = character
    function player:Kick(message) self.kicked = message end
    table.insert(PLAYERS, player)
    playerById[userId] = player
    return player
end

local PlayersService = {
    PlayerAdded = newSignal(),
    PlayerRemoving = newSignal(),
}
function PlayersService:GetPlayers()
    local copy = {}
    for _, player in ipairs(PLAYERS) do table.insert(copy, player) end
    return copy
end
function PlayersService:GetPlayerByUserId(userId)
    return playerById[userId]
end
function PlayersService:GetPlayerFromCharacter() return nil end

local DebrisService = { AddItem = function(self, item, lifetime) end }

----------------------------------------------------------------------
-- Remote stubs
----------------------------------------------------------------------
local RemoteMT = {}
RemoteMT.__index = RemoteMT
local RemoteEvent = {}
function RemoteEvent.new(name)
    local self = setmetatable({
        ClassName = "RemoteEvent",
        Name = name,
        children = {},
        sent = {},
    }, RemoteMT)
    self.OnServerEvent = newSignal()
    self.OnClientEvent = newSignal()
    return self
end
remoteFactory = RemoteEvent.new
RemoteMT.__newindex = function(self, key, value)
    rawset(self, key, value)
    if key == "Parent" and value and rawget(value, "children") then
        table.insert(value.children, self)
    end
end
function RemoteMT.FireClient(self, player, payload)
    table.insert(self.sent, { player = player, payload = payload })
end
function RemoteMT.FireAllClients(self, payload)
    for _, player in ipairs(PLAYERS) do
        self:FireClient(player, payload)
    end
end

----------------------------------------------------------------------
-- game / services wiring
----------------------------------------------------------------------
local Shared = { children = {}, Name = "Shared", ClassName = "Folder" }
Shared.FindFirstChild = InstanceMT.FindFirstChild
Shared.WaitForChild = InstanceMT.WaitForChild

local ConfigModule
local RoomRulesModule
do
    ConfigModule = {
        Name = "Config",
        ClassName = "ModuleScript",
        CatalogUrl = "http://127.0.0.1:8787",
        DefaultBuzzSeconds = 8,
        DefaultAnswerSeconds = 20,
        ItemCooldownSeconds = 7,
        PitSeconds = 60,
        DemoPackId = "demo-lounge",
    }
    -- inline copy of RoomRules (kept in sync with src/ReplicatedStorage/Shared/RoomRules.luau)
    RoomRulesModule = { Name = "RoomRules", ClassName = "ModuleScript" }
    function RoomRulesModule.sanitizeText(value, limit)
        local text = tostring(value or "")
        text = text:gsub("[%c]", " "):gsub("%s+", " ")
        text = text:match("^%s*(.-)%s*$") or ""
        return string.sub(text, 1, limit or 280)
    end
    function RoomRulesModule.scoreDelta(value)
        local delta = tonumber(value) or 0
        return math.clamp(math.floor(delta), -5000, 5000)
    end
    function RoomRulesModule.cooldownReady(cooldowns, key, now, seconds)
        local nextUse = cooldowns[key] or 0
        if now < nextUse then return false end
        cooldowns[key] = now + seconds
        return true
    end
    table.insert(Shared.children, ConfigModule)
    table.insert(Shared.children, RoomRulesModule)
    -- name-based lookup for WaitForChild
    setmetatable(Shared.children, {})
end
-- give Fast lookup by patching WaitForChild
local sharedLookup = { Config = ConfigModule, RoomRules = RoomRulesModule }
function Shared.WaitForChild(self, name)
    if sharedLookup[name] then return sharedLookup[name] end
    return Instance.new("Configuration")
end

local ReplicatedStorage = { children = {}, Name = "ReplicatedStorage", ClassName = "ReplicatedStorage" }
ReplicatedStorage.FindFirstChild = InstanceMT.FindFirstChild
ReplicatedStorage.WaitForChild = InstanceMT.WaitForChild
table.insert(ReplicatedStorage.children, Shared)
setmetatable(ReplicatedStorage, InstanceMT)   -- honours .Parent assignments

local Workspace = { children = {}, Name = "Workspace" }
Workspace.FindFirstChild = InstanceMT.FindFirstChild
Workspace.WaitForChild = InstanceMT.WaitForChild
setmetatable(Workspace, InstanceMT)

local HttpService = {
    HttpEnabled = false,
    GenerateGUID = function(self, wrap)
        local parts = {}
        for index = 1, 6 do parts[index] = string.format("%02x", (index * 37) % 256) end
        return table.concat(parts, "-") .. "-" .. tostring(math.random(1000, 9999))
    end,
    JSONEncode = function(self, value) return "{}" end,
    JSONDecode = function(self, value) return {} end,
    UrlEncode = function(self, value) return tostring(value) end,
    RequestAsync = function(self, options) error("HTTP disabled in simulation") end,
}

local SERVICES = {
    Players = PlayersService,
    ReplicatedStorage = ReplicatedStorage,
    Debris = DebrisService,
    Workspace = Workspace,
    HttpService = HttpService,
    RunService = { IsServer = function() return true end, IsClient = function() return false end },
}
game = {
    GetService = function(self, name)
        return SERVICES[name] or Instance.new(name)
    end,
    Workspace = Workspace,
}

----------------------------------------------------------------------
-- packService stub (mirrors PackService.luau behaviour: no HTTP -> demo)
----------------------------------------------------------------------
local searchCalls = {}
local installCalls = {}
local packService = {}
function packService.Search(query, tag, sort)
    table.insert(searchCalls, { query = query, tag = tag, sort = sort })
    return false, { error = "HTTP requests are disabled" }
end
function packService.Install(workshopId)
    table.insert(installCalls, workshopId)
    return false, { error = "HTTP requests are disabled" }
end

local scriptStub = {
    Parent = {
        WaitForChild = function(self, name)
            if name == "PackService" then return packService end
            return Instance.new("ModuleScript")
        end,
    },
}
script = scriptStub
require = function(module) return module end

-- task: spawn runs inline, defer is a no-op (avoids infinite background loops)
task = {
    spawn = function(fn) local ok, err = pcall(fn); if not ok then print("  [task.spawn error] " .. tostring(err)) end end,
    defer = function(fn) end,
    wait = function(seconds) return seconds end,
    delay = function(seconds, fn) return nil end,
}
wait = function(seconds) return seconds end

----------------------------------------------------------------------
-- load the real server script
----------------------------------------------------------------------
section("loading GameServer.server.luau")
local source = realRequire("./_server_source")
check(type(source) == "string" and #source > 1000, "server source embedded", type(source))
local chunk, loadError = loadstring(source, "GameServer")
check(chunk ~= nil, "server script compiles", loadError)
if not chunk then
    print("\nRESULT: " .. failures .. " failures / " .. checks .. " checks")
    error("harness aborted: server script does not compile")
end
local ran, runError = pcall(chunk)
check(ran, "server script boots without error", runError)
if not ran then
    print("\nRESULT: " .. failures .. " failures / " .. checks .. " checks")
    error("harness aborted: server script failed to boot")
end

local remotes = ReplicatedStorage:FindFirstChild("SIGameRemotes")
check(remotes ~= nil, "SIGameRemotes folder created")
local actionRemote = remotes and remotes:FindFirstChild("Action")
local stateRemote = remotes and remotes:FindFirstChild("StateChanged")
local catalogRemote = remotes and remotes:FindFirstChild("CatalogResult")
check(actionRemote ~= nil, "Action RemoteEvent exists")
check(stateRemote ~= nil, "StateChanged RemoteEvent exists")
check(catalogRemote ~= nil, "CatalogResult RemoteEvent exists")

local actionHandler = actionRemote and actionRemote.OnServerEvent.handlers[1]
check(type(actionHandler) == "function", "server wired an Action handler")

local function send(player, payload) actionHandler(player, payload) end
local function lastState(player)
    local found = nil
    for _, record in ipairs(stateRemote.sent) do
        if record.player == player then found = record.payload end
    end
    return found
end
local function lastCatalog(player)
    local found = nil
    for _, record in ipairs(catalogRemote.sent) do
        if record.player == player then found = record.payload end
    end
    return found
end
local function findQuestionIn(state, id)
    for _, question in ipairs(state.questions or {}) do
        if question.id == id then return question end
    end
    return nil
end

----------------------------------------------------------------------
-- 1. players join
----------------------------------------------------------------------
section("1. players join the lounge")
local host = makePlayer(1001, "Аня")
local playerA = makePlayer(1002, "Женя")
local playerB = makePlayer(1003, "Марк")
PlayersService.PlayerAdded:Fire(host)
PlayersService.PlayerAdded:Fire(playerA)
PlayersService.PlayerAdded:Fire(playerB)
local lobbyState = lastState(playerA)
check(lobbyState ~= nil, "joining players receive a state snapshot")
check(lobbyState and lobbyState.phase == "lobby", "match starts in lobby", lobbyState and lobbyState.phase)
check(lobbyState and lobbyState.hostUserId == 0, "no host until someone creates a room", lobbyState and lobbyState.hostUserId)
check(lobbyState and #lobbyState.questions == 4, "demo pack preloaded with 4 questions", lobbyState and #lobbyState.questions)
check(lobbyState and #lobbyState.players == 3, "all three players listed", lobbyState and #lobbyState.players)

----------------------------------------------------------------------
-- 2. room creation / roles
----------------------------------------------------------------------
section("2. room creation and role selection")
send(playerA, { type = "chooseRole", role = "player" })
send(host, { type = "createRoom" })
local stateHost = lastState(host)
check(stateHost and stateHost.hostUserId == 1001, "host owns the room", stateHost and stateHost.hostUserId)
check(stateHost and stateHost.roomCode:match("^SIA%-[%u%d][%u%d][%u%d][%u%d][%u%d]$") ~= nil, "room code looks like SIA-XXXXX", stateHost and stateHost.roomCode)

local thief = makePlayer(1004, "Кирилл")
PlayersService.PlayerAdded:Fire(thief)
send(thief, { type = "createRoom" })
local thiefState = lastState(thief)
check(thiefState and thiefState.hostUserId == 1001, "a second player cannot steal host", thiefState and thiefState.hostUserId)
PlayersService.PlayerRemoving:Fire(thief)
table.remove(PLAYERS, #PLAYERS)

-- 10. catalog search falls back to the demo pack offline
----------------------------------------------------------------------
section("10. catalog search fallback")
send(playerA, { type = "searchCatalog", query = "мемы" })
local searchReply = lastCatalog(playerA)
check(searchReply ~= nil, "search returns a result")
check(searchReply and searchReply.type == "search", "result typed as search")
check(searchReply and searchReply.offline == true, "offline fallback flagged", searchReply and tostring(searchReply.offline))
check(searchReply and searchReply.items and #searchReply.items >= 1, "offline fallback still lists the demo pack", searchReply and searchReply.items and #searchReply.items)

----------------------------------------------------------------------
-- 11. pack proposals and voting
----------------------------------------------------------------------
section("11. pack proposals and voting")
send(playerA, { type = "proposePack", workshopId = "demo-lounge", title = "Демо" })
local proposalState = lastState(host)
check(proposalState and proposalState.proposals["demo-lounge"] ~= nil, "proposal registered")
check(proposalState and proposalState.proposals["demo-lounge"].votes[1002] == true, "author auto-votes for their pack")

send(playerB, { type = "votePack", workshopId = "demo-lounge" })
local voted = lastState(host)
check(voted and voted.proposals["demo-lounge"].votes[1003] == true, "second player can vote")
send(playerB, { type = "votePack", workshopId = "demo-lounge" })
local unvoted = lastState(host)
check(unvoted and unvoted.proposals["demo-lounge"].votes[1003] == nil, "vote can be withdrawn")

send(playerA, { type = "proposePack", workshopId = "evil; rm -rf", title = "hack" })
local rejected = lastState(host)
check(rejected and rejected.proposals["evil; rm -rf"] == nil, "non-numeric workshop ids rejected")

send(playerA, { type = "startVote" })
local voteBlocked = lastState(host)
check(voteBlocked and voteBlocked.voteOpen == false, "only the host opens voting", tostring(voteBlocked and voteBlocked.voteOpen))
send(host, { type = "startVote" })
local voteOpen = lastState(playerA)
check(voteOpen and voteOpen.voteOpen == true, "host opens voting")
send(host, { type = "closeVote" })
local voteClosed = lastState(playerA)
check(voteClosed and voteClosed.voteOpen == false, "host closes voting")

----------------------------------------------------------------------
-- 12. installing the demo pack
----------------------------------------------------------------------
section("12. installing a pack")
send(playerA, { type = "installPack", workshopId = "demo-lounge" })
local blockedInstall = lastCatalog(playerA)
check(blockedInstall == nil or blockedInstall.type ~= "installStatus", "only the host installs packs")
send(host, { type = "installPack", workshopId = "demo-lounge" })
local ready = lastCatalog(host)
check(ready ~= nil and ready.type == "installStatus", "install status broadcast", ready and ready.type)
check(ready and ready.status == "ready", "demo pack installs offline", ready and ready.status)
local afterInstall = lastState(host)
check(afterInstall and afterInstall.phase == "board", "installing a pack switches the board", afterInstall and afterInstall.phase)
check(afterInstall and #afterInstall.questions == 4, "installed pack questions loaded", afterInstall and #afterInstall.questions)
local anyAnswered = false
for _, question in ipairs(afterInstall and afterInstall.questions or {}) do
    if question.answered then anyAnswered = true end
end
check(not anyAnswered, "installed pack starts unanswered")

send(host, { type = "installPack", workshopId = "demo-lounge" })
check(#installCalls == 0, "demo pack never hits the network", #installCalls)

----------------------------------------------------------------------
----------------------------------------------------------------------
-- 3. host opens a question; answers stay hidden
----------------------------------------------------------------------
section("3. opening a question hides the answer from players")
send(playerA, { type = "selectQuestion", questionId = "demo-1" })
local stillLobby = lastState(playerA)
check(stillLobby and stillLobby.phase == "board", "non-host cannot open a question", stillLobby and stillLobby.phase)

send(host, { type = "selectQuestion", questionId = "demo-1" })
local hostState = lastState(host)
local aState = lastState(playerA)
check(hostState and hostState.phase == "question", "host opens the question", hostState and hostState.phase)
check(hostState and hostState.selectedQuestionId == "demo-1", "selected question id propagates", hostState and hostState.selectedQuestionId)
local hostQuestion = hostState and findQuestionIn(hostState, "demo-1")
local aQuestion = aState and findQuestionIn(aState, "demo-1")
check(hostQuestion and hostQuestion.answer ~= nil, "host sees the correct answer", hostQuestion and hostQuestion.answer)
check(aQuestion ~= nil and aQuestion.answer == nil, "players never receive the answer field", aQuestion and aQuestion.answer)
check(aState and aState.answers == nil, "players do not receive the full answer table", aState and tostring(aState.answers))

----------------------------------------------------------------------
-- 4. submitting answers
----------------------------------------------------------------------
section("4. players submit answers, host grades")
send(host, { type = "submitAnswer", answer = "ведущий" })
local hostAfterSubmit = lastState(host)
check(hostAfterSubmit and hostAfterSubmit.myAnswer == nil, "host cannot answer their own question", hostAfterSubmit and tostring(hostAfterSubmit.myAnswer))

send(playerA, { type = "submitAnswer", answer = "  интернет  " })
local aAfterAnswer = lastState(playerA)
check(aAfterAnswer and aAfterAnswer.myAnswer ~= nil, "player answer stored", aAfterAnswer and tostring(aAfterAnswer.myAnswer))
check(aAfterAnswer and aAfterAnswer.myAnswer.text == "интернет", "answer text is trimmed", aAfterAnswer and aAfterAnswer.myAnswer.text)
check(aAfterAnswer and aAfterAnswer.myAnswer.questionId == "demo-1", "answer linked to the open question")

send(playerB, { type = "submitAnswer", answer = "   " })
local bBlank = lastState(playerB)
check(bBlank and bBlank.myAnswer == nil, "blank answers are rejected", bBlank and tostring(bBlank.myAnswer))

send(playerB, { type = "submitAnswer", answer = "что-то другое" })
send(playerA, { type = "gradeAnswer", userId = 1002, delta = 100 })
local aAfterCheat = lastState(playerA)
check(aAfterCheat and (aAfterCheat.scores[1002] or 0) == 0, "non-host cannot grade answers", aAfterCheat and aAfterCheat.scores[1002])

send(host, { type = "gradeAnswer", userId = 1002, delta = 100 })
local graded = lastState(host)
check(graded and graded.scores[1002] == 100, "host awards points", graded and graded.scores[1002])
check(graded and graded.answers[1002].graded == true, "answer marked as graded", graded and tostring(graded.answers[1002].graded))

send(host, { type = "gradeAnswer", userId = 1002, delta = 100 })
local doubleGrade = lastState(host)
check(doubleGrade and doubleGrade.scores[1002] == 100, "the same answer cannot be graded twice", doubleGrade and doubleGrade.scores[1002])

send(host, { type = "gradeAnswer", userId = 1003, delta = -50 })
local negative = lastState(host)
check(negative and negative.scores[1003] == -50, "host can deduct points", negative and negative.scores[1003])

send(host, { type = "setScore", userId = 1003, delta = 999999 })
local clamped = lastState(host)
check(clamped and clamped.scores[1003] == -50 + 5000, "manual score change is clamped", clamped and clamped.scores[1003])

----------------------------------------------------------------------
-- 5. finishing the question reveals the answer
----------------------------------------------------------------------
section("5. finishing the question reveals the answer")
send(playerA, { type = "finishQuestion" })
local notFinished = lastState(playerA)
check(notFinished and notFinished.phase == "question", "non-host cannot finish the question", notFinished and notFinished.phase)

send(host, { type = "finishQuestion" })
local finishedHost = lastState(host)
local finished = lastState(playerA)
check(finished and finished.phase == "board", "finishing returns to the board", finished and finished.phase)
check(finished and finished.selectedQuestionId == nil, "no question stays selected", finished and tostring(finished.selectedQuestionId))
local closedQuestion = finished and findQuestionIn(finished, "demo-1")
check(closedQuestion and closedQuestion.answered == true, "question marked as answered", closedQuestion and tostring(closedQuestion.answered))
check(finished and finished.actionFeed ~= nil, "reveal message broadcast", finished and finished.actionFeed and finished.actionFeed.text)
check(finished and finished.actionFeed and finished.actionFeed.text:find("интернет", 1, true) ~= nil, "reveal contains the correct answer", finished and finished.actionFeed and finished.actionFeed.text)
check(finishedHost and finishedHost.answers ~= nil and next(finishedHost.answers) == nil, "answer table cleared after the question", finishedHost and tostring(finishedHost.answers))

send(host, { type = "selectQuestion", questionId = "demo-1" })
local reopened = lastState(host)
check(reopened and reopened.phase == "board", "answered questions cannot be reopened", reopened and reopened.phase)

----------------------------------------------------------------------
-- 6. choice questions
----------------------------------------------------------------------
section("6. choice questions")
send(host, { type = "selectQuestion", questionId = "demo-2" })
local choiceState = lastState(playerA)
local choiceQuestion = choiceState and findQuestionIn(choiceState, "demo-2")
check(choiceQuestion and choiceQuestion.kind == "choice", "choice question kind preserved", choiceQuestion and choiceQuestion.kind)
check(choiceQuestion and #choiceQuestion.choices == 3, "choices reach the players", choiceQuestion and choiceQuestion.choices and #choiceQuestion.choices)
send(playerA, { type = "submitAnswer", answer = "Ведущий" })
local choiceAnswer = lastState(playerA)
check(choiceAnswer and choiceAnswer.myAnswer and choiceAnswer.myAnswer.text == "Ведущий", "choice answer recorded", choiceAnswer and choiceAnswer.myAnswer and choiceAnswer.myAnswer.text)
send(host, { type = "finishQuestion" })

----------------------------------------------------------------------
-- 7. moderation: mute
----------------------------------------------------------------------
section("7. moderation")
send(host, { type = "selectQuestion", questionId = "demo-4" })
send(host, { type = "moderate", userId = 1002, moderation = "mute" })
send(playerA, { type = "submitAnswer", answer = "да" })
local muted = lastState(host)
check(muted and muted.muted[1002] == true, "host muted the player", muted and tostring(muted.muted[1002]))
check(muted and muted.answers[1002] == nil, "muted player cannot answer", muted and tostring(muted.answers[1002]))
send(host, { type = "moderate", userId = 1002, moderation = "mute" })
send(playerA, { type = "submitAnswer", answer = "да" })
local unmuted = lastState(host)
check(unmuted and unmuted.answers[1002] ~= nil, "unmuting restores answering", unmuted and tostring(unmuted.answers[1002]))

----------------------------------------------------------------------
-- 8. the pit
----------------------------------------------------------------------
section("8. the pit")
send(host, { type = "moderate", userId = 1003, moderation = "pit" })
local pitState = lastState(playerB)
check(pitState and pitState.pitUntil[1003] ~= nil, "pit timer set", pitState and tostring(pitState.pitUntil[1003]))
check(playerB.root.Position.Y == -15, "player teleported into the pit", tostring(playerB.root.Position))
check(playerB.kicked == nil, "pit does not kick the player")

send(playerA, { type = "moderate", userId = 1003, moderation = "kick" })
local afterFakeKick = lastState(playerA)
check(playerB.kicked == nil, "non-host cannot kick", tostring(playerB.kicked))
send(host, { type = "moderate", userId = 1003, moderation = "kick" })
check(playerB.kicked ~= nil, "host can kick a player", tostring(playerB.kicked))
-- re-add playerB for later steps
playerB.kicked = nil
PlayersService.PlayerAdded:Fire(playerB)

----------------------------------------------------------------------
-- 9. lounge services and meme items
----------------------------------------------------------------------
section("9. lounge services and meme items")
send(playerA, { type = "orderService", service = "tea" })
local serviceProp = nil
for _, child in ipairs(Workspace.children) do
    if child.Name == "LoungeService_tea_1002" then serviceProp = child end
end
check(serviceProp ~= nil, "tea prop spawned in the world")
check(serviceProp and serviceProp.Material == Enum.Material.Neon, "tea prop glows")

send(playerA, { type = "orderService", service = "hack" })
local hackCount = 0
for _, child in ipairs(Workspace.children) do
    if child.Name == "LoungeService_hack_1002" then hackCount += 1 end
end
check(hackCount == 0, "unknown service is rejected")

local beforeItems = 0
for _, child in ipairs(Workspace.children) do
    if child.Name == "MemeProjectile" then beforeItems += 1 end
end
send(playerA, { type = "useItem", itemId = "tomato" })
local afterFirst = 0
for _, child in ipairs(Workspace.children) do
    if child.Name == "MemeProjectile" then afterFirst += 1 end
end
check(afterFirst == beforeItems + 1, "tomato spawns a projectile", afterFirst)
send(playerA, { type = "useItem", itemId = "tomato" })
local afterSecond = 0
for _, child in ipairs(Workspace.children) do
    if child.Name == "MemeProjectile" then afterSecond += 1 end
end
check(afterSecond == afterFirst, "item cooldown blocks spam", afterSecond)
send(playerA, { type = "useItem", itemId = "rocket" })
local afterUnknown = 0
for _, child in ipairs(Workspace.children) do
    if child.Name == "MemeProjectile" then afterUnknown += 1 end
end
check(afterUnknown == afterFirst, "unknown item is rejected", afterUnknown)

send(host, { type = "moderate", userId = 1002, moderation = "items" })
send(playerA, { type = "useItem", itemId = "poop" })
local afterDisabled = 0
for _, child in ipairs(Workspace.children) do
    if child.Name == "MemeProjectile" then afterDisabled += 1 end
end
check(afterDisabled == afterFirst, "host can revoke a player's items", afterDisabled)
send(host, { type = "moderate", userId = 1002, moderation = "items" })

----------------------------------------------------------------------
-- 13. malformed payloads
----------------------------------------------------------------------
section("13. malformed payloads are ignored")
local pcallOk = pcall(function()
    actionHandler(playerA, nil)
    actionHandler(playerA, "string")
    actionHandler(playerA, { type = 42 })
    actionHandler(playerA, { type = "selectQuestion" })
    actionHandler(playerA, { type = "gradeAnswer", userId = "abc", delta = "x" })
    actionHandler(playerA, { type = "unknownAction" })
end)
check(pcallOk, "garbage payloads do not crash the server")

----------------------------------------------------------------------
-- 14. leaving
----------------------------------------------------------------------
section("14. player leaving")
PlayersService.PlayerRemoving:Fire(playerA)
local leaveOk = pcall(function() actionHandler(playerA, { type = "submitAnswer", answer = "ещё" }) end)
check(leaveOk, "actions from a departed player are tolerated")

print("")
print(string.format("RESULT: %d checks, %d failures", checks, failures))
if failures > 0 then
    print("STATUS: FAIL")
    error(string.format("%d failing checks", failures))
end
print("STATUS: PASS")
