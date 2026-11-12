local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:FindFirstChild("Shared")
local config = require(shared:WaitForChild("Config"))
local roomRules = require(shared:WaitForChild("RoomRules"))
local packService = require(script.Parent:WaitForChild("PackService"))

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
local catalogResult = remote("CatalogResult")

local demoQuestions = {
    { id = "demo-1", category = "Мемы", value = 100, kind = "text", text = "Кто обычно говорит: «это база»?", answer = "интернет", answered = false },
    { id = "demo-2", category = "Игры", value = 100, kind = "choice", choices = { "Ведущий", "Игрок", "Официант" }, text = "Как называется роль, которая открывает вопросы?", answer = "ведущий", answered = false },
    { id = "demo-3", category = "Дота", value = 200, kind = "text", text = "Какой предмет чаще всего покупают на первую сотню?", answer = "вопрос для пака", answered = false },
    { id = "demo-4", category = "Компания", value = 300, kind = "choice", choices = { "Да", "Нет" }, text = "Кто из игроков сейчас первым кинет помидор?", answer = "да", answered = false },
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
    answers = {},
    itemCooldowns = {},
    serviceOrders = {},
    proposals = {},
    actionFeed = nil,
}
local installInProgress = false

local demoCatalog = {
    { workshopId = "demo-lounge", title = "SIGame Lounge • демо-пак", tags = { "demo", "memes", "dota" }, description = "Встроенный пак для первого запуска без ручной подготовки." },
}

local function isHost(player: Player): boolean
    return player.UserId == state.hostUserId
end

local function snapshot(viewer: Player)
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
        answers = isHost(viewer) and state.answers or nil,
        myAnswer = state.answers[viewer.UserId],
        serviceOrders = state.serviceOrders,
        proposals = state.proposals,
        actionFeed = state.actionFeed,
    }
end

local function broadcast()
    for _, player in Players:GetPlayers() do
        stateChanged:FireClient(player, snapshot(player))
    end
    state.actionFeed = nil
end

local function findQuestion(id: string)
    for _, question in state.questions do
        if question.id == id then
            return question
        end
    end
    return nil
end

local function applyPack(pack)
    local questions = {}
    for index, source in pack.questions or {} do
        table.insert(questions, {
            id = tostring(source.id or (pack.id .. "-" .. index)),
            category = tostring(source.category or "Новый пак"),
            value = tonumber(source.value) or index * 100,
            kind = tostring(source.kind or "text"),
            choices = source.choices,
            media = source.media or {},
            text = tostring(source.text or "Вопрос без текста"),
            answer = tostring(source.answer or ""),
            answered = false,
        })
    end
    if #questions == 0 then
        return false
    end
    state.packId = tostring(pack.id or "unknown-pack")
    state.questions = questions
    state.selectedQuestionId = nil
    state.answers = {}
    state.phase = "board"
    return true
end

local function sendToPit(player: Player)
    state.pitUntil[player.UserId] = os.time() + config.PitSeconds
    local character = player.Character
    if character then
        character:PivotTo(CFrame.new(0, -18, 0))
    end
end

local function firstOtherPlayer(player: Player): Player?
    for _, candidate in Players:GetPlayers() do
        if candidate ~= player then
            return candidate
        end
    end
    return nil
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
        state.answers = {}
        state.phase = "board"
        broadcast()
    elseif payload.type == "submitAnswer" and state.phase == "question" then
        local question = findQuestion(state.selectedQuestionId)
        if question and not isHost(player) and not state.muted[player.UserId] then
            local answerText = roomRules.sanitizeText(payload.answer, 280)
            if answerText ~= "" then
                state.answers[player.UserId] = {
                    questionId = question.id,
                    text = answerText,
                    submittedAt = os.time(),
                    graded = false,
                }
                broadcast()
            end
        end
    elseif payload.type == "gradeAnswer" and isHost(player) then
        local targetId = tonumber(payload.userId)
        local answer = targetId and state.answers[targetId]
        local question = findQuestion(state.selectedQuestionId)
        if targetId and answer and question and answer.questionId == question.id and not answer.graded then
            local delta = roomRules.scoreDelta(payload.delta)
            answer.graded = true
            answer.correct = delta > 0
            state.scores[targetId] = (state.scores[targetId] or 0) + delta
            broadcast()
        end
    elseif payload.type == "setScore" and isHost(player) then
        local targetId = tonumber(payload.userId)
        local delta = roomRules.scoreDelta(payload.delta)
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
    elseif payload.type == "searchCatalog" then
        task.spawn(function()
            local success, result = packService.Search(
                tostring(payload.query or ""),
                tostring(payload.tag or ""),
                tostring(payload.sort or "popular")
            )
            if not success then
                success = true
                result = { items = demoCatalog, offline = true }
            end
            catalogResult:FireClient(player, {
                type = "search",
                success = success,
                items = success and result.items or {},
                error = success and nil or result.error,
                offline = result.offline,
            })
        end)
    elseif payload.type == "proposePack" and state.phase == "lobby" then
        local workshopId = tostring(payload.workshopId or "")
        if string.match(workshopId, "^%d+$") or workshopId == "demo-lounge" then
            local proposal = state.proposals[workshopId] or { title = roomRules.sanitizeText(payload.title, 80), votes = {} }
            proposal.title = proposal.title ~= "" and proposal.title or "Пак " .. workshopId
            proposal.votes[player.UserId] = true
            state.proposals[workshopId] = proposal
            state.actionFeed = { text = player.DisplayName .. " предложил пак «" .. proposal.title .. "»", kind = "catalog" }
            broadcast()
        end
    elseif payload.type == "votePack" and state.phase == "lobby" then
        local workshopId = tostring(payload.workshopId or "")
        local proposal = state.proposals[workshopId]
        if proposal then
            proposal.votes[player.UserId] = not proposal.votes[player.UserId]
            broadcast()
        end
    elseif payload.type == "installPack" and isHost(player) and state.phase == "lobby" and not installInProgress then
        local workshopId = tostring(payload.workshopId or "")
        if not string.match(workshopId, "^%d+$") and workshopId ~= "demo-lounge" then
            catalogResult:FireClient(player, { type = "installStatus", status = "failed", error = "Неверный ID пака" })
            return
        end
        installInProgress = true
        catalogResult:FireAllClients({ type = "installStatus", status = "downloading", workshopId = workshopId })
        task.spawn(function()
            local success, result
            if workshopId == "demo-lounge" then
                success, result = true, { pack = { id = config.DemoPackId, title = "SIGame Lounge • демо-пак", questions = demoQuestions } }
            else
                success, result = packService.Install(workshopId)
            end
            if success and result.pack and applyPack(result.pack) then
                catalogResult:FireAllClients({ type = "installStatus", status = "ready", workshopId = workshopId, title = result.pack.title })
                broadcast()
            else
                catalogResult:FireAllClients({
                    type = "installStatus",
                    status = "failed",
                    workshopId = workshopId,
                    error = success and "В паке не найдено игровых вопросов" or result.error,
                })
            end
            installInProgress = false
        end)
    elseif payload.type == "orderService" then
        local service = roomRules.sanitizeText(payload.service, 32)
        if table.find({ "tea", "coffee", "hookah", "waiter" }, service) then
            state.serviceOrders[player.UserId] = service
            state.actionFeed = { text = player.DisplayName .. " заказал " .. service, kind = "service" }
            broadcast()
        end
    elseif payload.type == "useItem" then
        local itemId = tostring(payload.itemId or "")
        if state.itemDisabled[player.UserId] then
            return
        end
        local allowedItems = { tomato = true, poop = true, confetti = true }
        local cooldownKey = tostring(player.UserId) .. ":" .. itemId
        if not allowedItems[itemId] or not roomRules.cooldownReady(state.itemCooldowns, cooldownKey, os.clock(), config.ItemCooldownSeconds) then
            return
        end
        if itemId == "tomato" or itemId == "poop" or itemId == "confetti" then
            local target = Players:GetPlayerByUserId(tonumber(payload.targetUserId) or 0) or firstOtherPlayer(player)
            if target and target ~= player then
                state.actionFeed = { text = player.DisplayName .. " бросил " .. itemId .. " в " .. target.DisplayName, kind = "item" }
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
    state.answers[player.UserId] = nil
    broadcast()
end)

Players.PlayerRemoving:Connect(function(player)
    if player.UserId == state.hostUserId then
        state.hostUserId = 0
    end
    state.roles[player.UserId] = nil
    state.answers[player.UserId] = nil
    state.serviceOrders[player.UserId] = nil
    broadcast()
end)

action.OnServerEvent:Connect(handleAction)

task.defer(function()
    while true do
        task.wait(5)
        broadcast()
    end
end)

