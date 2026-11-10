local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:FindFirstChild("Shared")
local config = require(shared:WaitForChild("Config"))

local remotes = ReplicatedStorage:FindFirstChild("SIGameRemotes") or Instance.new("Folder")
remotes.Name = "SIGameRemotes"
remotes.Parent = ReplicatedStorage

local function remote(name: string): RemoteEvent
    local item = remotes:FindFirstChild(name) or Instance.new("RemoteEvent")
    item.Name = name
    item.Parent = remotes
    return item :: RemoteEvent
end

local stateChanged = remote("StateChanged")
local action = remote("Action")

local demoQuestions = {
    { id = "demo-1", category = "Мемы", value = 100, text = "Кто обычно говорит: 'это база'?", answer = "интернет", answered = false },
    { id = "demo-2", category = "Игры", value = 100, text = "Как называется роль ведущего в этой игре?", answer = "ведущий", answered = false },
    { id = "demo-3", category = "Дота", value = 200, text = "Какой предмет чаще всего покупают на первую сотню?", answer = "вопрос для пака", answered = false },
    { id = "demo-4", category = "Компания", value = 300, text = "Кто из игроков сейчас первым кинет помидор?", answer = "тот, кто нажмёт кнопку", answered = false },
}

local state = {
    hostUserId = 0,
    roles = {},
    packId = config.DemoPackId,
    phase = "lobby",
    selectedQuestionId = nil,
    scores = {},
    players = {},
    questions = demoQuestions,
    muted = {},
    itemDisabled = {},
    pitUntil = {},
}

local function snapshot()
    local players = {}
    for _, player in Players:GetPlayers() do
        table.insert(players, { userId = player.UserId, name = player.DisplayName, isHost = player.UserId == state.hostUserId })
    end
    return {
        hostUserId = state.hostUserId,
        packId = state.packId,
        phase = state.phase,
        selectedQuestionId = state.selectedQuestionId,
        scores = state.scores,
        players = players,
        roles = state.roles,
        questions = state.questions,
        muted = state.muted,
        itemDisabled = state.itemDisabled,
        pitUntil = state.pitUntil,
    }
end

local function broadcast()
    stateChanged:FireAllClients(snapshot())
end

local function isHost(player: Player): boolean
    return player.UserId == state.hostUserId
end

local function findQuestion(id: string)
    for _, question in state.questions do
        if question.id == id then
            return question
        end
    end
    return nil
end

local function sendToPit(player: Player)
    state.pitUntil[player.UserId] = os.time() + config.PitSeconds
    local character = player.Character
    if character then
        character:PivotTo(CFrame.new(0, -18, 0))
    end
end

local function handleAction(player: Player, payload)
    if type(payload) ~= "table" or type(payload.type) ~= "string" then
        return
    end

    if payload.type == "selectQuestion" and isHost(player) then
        local question = findQuestion(payload.questionId)
        if question and not question.answered then
            state.selectedQuestionId = question.id
            state.phase = "question"
            broadcast()
        end
    elseif payload.type == "finishQuestion" and isHost(player) then
        local question = findQuestion(state.selectedQuestionId)
        if question then
            question.answered = true
        end
        state.selectedQuestionId = nil
        state.phase = "board"
        broadcast()
    elseif payload.type == "setScore" and isHost(player) then
        local targetId = tonumber(payload.userId)
        local delta = math.clamp(tonumber(payload.delta) or 0, -1000, 1000)
        if targetId then
            state.scores[targetId] = (state.scores[targetId] or 0) + delta
            broadcast()
        end
    elseif payload.type == "chooseRole" and state.phase == "lobby" then
        local role = tostring(payload.role or "")
        if role == "host" and (state.hostUserId == 0 or state.hostUserId == player.UserId) then
            state.hostUserId = player.UserId
            state.roles[player.UserId] = "host"
            broadcast()
        elseif role == "player" then
            if state.hostUserId == player.UserId then
                state.hostUserId = 0
            end
            state.roles[player.UserId] = "player"
            broadcast()
        end
    elseif payload.type == "useItem" then
        local itemId = tostring(payload.itemId or "")
        if state.itemDisabled[player.UserId] then
            return
        end
        if itemId == "pit" then
            local target = Players:GetPlayerByUserId(tonumber(payload.targetUserId) or 0)
            if target and target ~= player then
                sendToPit(target)
                broadcast()
            end
        end
    elseif payload.type == "moderate" and isHost(player) then
        local targetId = tonumber(payload.userId)
        local moderation = tostring(payload.moderation or "")
        if targetId and moderation == "items" then
            state.itemDisabled[targetId] = not state.itemDisabled[targetId]
        elseif targetId and moderation == "mute" then
            state.muted[targetId] = not state.muted[targetId]
        elseif targetId and moderation == "pit" then
            local target = Players:GetPlayerByUserId(targetId)
            if target then
                sendToPit(target)
            end
        elseif targetId and moderation == "kick" then
            local target = Players:GetPlayerByUserId(targetId)
            if target then
                target:Kick("Ведущий отправил тебя из комнаты")
            end
        end
        broadcast()
    end
end

Players.PlayerAdded:Connect(function(player)
    state.roles[player.UserId] = "undecided"
    state.scores[player.UserId] = state.scores[player.UserId] or 0
    broadcast()
end)

Players.PlayerRemoving:Connect(function(player)
    if player.UserId == state.hostUserId then
        state.hostUserId = 0
    end
    state.roles[player.UserId] = nil
    broadcast()
end)

action.OnServerEvent:Connect(handleAction)

task.defer(function()
    while true do
        task.wait(5)
        broadcast()
    end
end)

