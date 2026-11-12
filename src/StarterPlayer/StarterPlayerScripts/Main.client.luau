local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SIGameRemotes")
local stateChanged = remotes:WaitForChild("StateChanged") :: RemoteEvent
local action = remotes:WaitForChild("Action") :: RemoteEvent

local COLORS = {
    ink = Color3.fromRGB(255, 239, 209),
    muted = Color3.fromRGB(211, 177, 153),
    wine = Color3.fromRGB(45, 25, 31),
    surface = Color3.fromRGB(70, 37, 41),
    surface2 = Color3.fromRGB(93, 48, 48),
    accent = Color3.fromRGB(220, 103, 67),
    gold = Color3.fromRGB(244, 190, 93),
    mint = Color3.fromRGB(134, 205, 169),
    danger = Color3.fromRGB(205, 82, 76),
}

local gui = Instance.new("ScreenGui")
gui.Name = "SIGameLounge"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function rounded(parent: Instance, radius: number, strokeColor: Color3?): Instance
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = parent
    if strokeColor then
        local stroke = Instance.new("UIStroke")
        stroke.Color = strokeColor
        stroke.Transparency = 0.35
        stroke.Thickness = 1
        stroke.Parent = parent
    end
    return parent
end

local function text(parent: Instance, value: string, size: number, color: Color3, bold: boolean?): TextLabel
    local item = Instance.new("TextLabel")
    item.BackgroundTransparency = 1
    item.Text = value
    item.TextColor3 = color
    item.TextSize = size
    item.Font = bold == false and Enum.Font.Gotham or Enum.Font.GothamBold
    item.TextWrapped = true
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.Parent = parent
    return item
end

local function button(parent: Instance, caption: string, color: Color3, size: UDim2, position: UDim2): TextButton
    local item = Instance.new("TextButton")
    item.Text = caption
    item.TextSize = 14
    item.TextColor3 = COLORS.ink
    item.Font = Enum.Font.GothamBold
    item.BackgroundColor3 = color
    item.Size = size
    item.Position = position
    item.AutoButtonColor = true
    rounded(item, 10, color:Lerp(Color3.new(1, 1, 1), 0.25))
    item.Parent = parent
    return item
end

local function clear(parent: Instance)
    for _, child in parent:GetChildren() do
        if not child:IsA("UICorner") and not child:IsA("UIStroke") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
end

local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = COLORS.wine
backdrop.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new(COLORS.wine, Color3.fromRGB(31, 20, 27))
gradient.Rotation = 90
gradient.Parent = backdrop

local header = rounded(Instance.new("Frame"), 0)
header.Size = UDim2.fromScale(1, 0.11)
header.BackgroundColor3 = Color3.fromRGB(58, 29, 35)
header.Parent = backdrop
local logo = text(header, "SIGAME  /  LOUNGE", 26, COLORS.gold)
logo.Position = UDim2.fromScale(0.035, 0.18)
logo.Size = UDim2.fromScale(0.38, 0.42)
local subtitle = text(header, "вопросы, чай и немного контролируемого хаоса", 13, COLORS.muted, false)
subtitle.Position = UDim2.fromScale(0.037, 0.58)
subtitle.Size = UDim2.fromScale(0.42, 0.25)
local phaseLabel = text(header, "КОМНАТА ГОТОВА", 14, COLORS.mint)
phaseLabel.AnchorPoint = Vector2.new(1, 0)
phaseLabel.Position = UDim2.fromScale(0.965, 0.3)
phaseLabel.Size = UDim2.fromScale(0.24, 0.3)
phaseLabel.TextXAlignment = Enum.TextXAlignment.Right

local board = rounded(Instance.new("Frame"), 22, COLORS.surface2)
board.AnchorPoint = Vector2.new(0.5, 0)
board.Position = UDim2.fromScale(0.49, 0.155)
board.Size = UDim2.fromScale(0.61, 0.69)
board.BackgroundColor3 = COLORS.surface
board.Parent = backdrop
local boardHeader = text(board, "ИГРОВОЕ ПОЛЕ", 20, COLORS.ink)
boardHeader.Position = UDim2.fromScale(0.04, 0.035)
boardHeader.Size = UDim2.fromScale(0.5, 0.08)
local boardHint = text(board, "Ведущий открывает вопрос — остальные отвечают со своих устройств", 12, COLORS.muted, false)
boardHint.Position = UDim2.fromScale(0.04, 0.105)
boardHint.Size = UDim2.fromScale(0.92, 0.06)

local cellsLayer = Instance.new("Frame")
cellsLayer.BackgroundTransparency = 1
cellsLayer.Position = UDim2.fromScale(0.04, 0.19)
cellsLayer.Size = UDim2.fromScale(0.92, 0.75)
cellsLayer.Parent = board

local side = rounded(Instance.new("Frame"), 18, COLORS.surface2)
side.AnchorPoint = Vector2.new(1, 0)
side.Position = UDim2.fromScale(0.965, 0.155)
side.Size = UDim2.fromScale(0.25, 0.69)
side.BackgroundColor3 = Color3.fromRGB(57, 31, 36)
side.Parent = backdrop
local sideTitle = text(side, "ЗАЛ  •  СЧЁТ", 17, COLORS.gold)
sideTitle.Position = UDim2.fromScale(0.08, 0.04)
sideTitle.Size = UDim2.fromScale(0.84, 0.08)
local scoreList = Instance.new("ScrollingFrame")
scoreList.BackgroundTransparency = 1
scoreList.BorderSizePixel = 0
scoreList.Position = UDim2.fromScale(0.06, 0.14)
scoreList.Size = UDim2.fromScale(0.88, 0.46)
scoreList.CanvasSize = UDim2.fromScale(0, 0)
scoreList.ScrollBarThickness = 3
scoreList.Parent = side
local scoreLayout = Instance.new("UIListLayout")
scoreLayout.Padding = UDim.new(0, 6)
scoreLayout.Parent = scoreList

local hostTools = rounded(Instance.new("Frame"), 12, COLORS.surface2)
hostTools.Position = UDim2.fromScale(0.06, 0.63)
hostTools.Size = UDim2.fromScale(0.88, 0.32)
hostTools.BackgroundColor3 = Color3.fromRGB(48, 27, 33)
hostTools.Visible = false
hostTools.Parent = side
local hostToolsTitle = text(hostTools, "МОДЕРАЦИЯ", 11, COLORS.gold)
hostToolsTitle.Position = UDim2.fromScale(0.06, 0.06)
hostToolsTitle.Size = UDim2.fromScale(0.88, 0.16)
local hostList = Instance.new("ScrollingFrame")
hostList.BackgroundTransparency = 1
hostList.BorderSizePixel = 0
hostList.Position = UDim2.fromScale(0.04, 0.23)
hostList.Size = UDim2.fromScale(0.92, 0.7)
hostList.CanvasSize = UDim2.fromScale(0, 0)
hostList.ScrollBarThickness = 2
hostList.Parent = hostTools
local hostLayout = Instance.new("UIListLayout")
hostLayout.Padding = UDim.new(0, 4)
hostLayout.Parent = hostList

local services = rounded(Instance.new("Frame"), 16, COLORS.surface2)
services.AnchorPoint = Vector2.new(0, 1)
services.Position = UDim2.fromScale(0.035, 0.95)
services.Size = UDim2.fromScale(0.42, 0.16)
services.BackgroundColor3 = Color3.fromRGB(58, 31, 36)
services.Parent = backdrop
local servicesTitle = text(services, "ЛАУНЖ-СЕРВИС", 13, COLORS.gold)
servicesTitle.Position = UDim2.fromScale(0.05, 0.08)
servicesTitle.Size = UDim2.fromScale(0.9, 0.2)
local serviceNames = { { "🍵  ЧАЙ", "tea" }, { "☕  КОФЕ", "coffee" }, { "〰  КАЛЬЯН", "hookah" }, { "✦  ОФИЦИАНТ", "waiter" } }
for index, service in serviceNames do
    local item = button(services, service[1], COLORS.surface2, UDim2.fromScale(0.22, 0.34), UDim2.fromScale(0.05 + ((index - 1) % 4) * 0.24, 0.46))
    item.Activated:Connect(function()
        action:FireServer({ type = "orderService", service = service[2] })
    end)
end

local items = rounded(Instance.new("Frame"), 16, COLORS.surface2)
items.AnchorPoint = Vector2.new(1, 1)
items.Position = UDim2.fromScale(0.965, 0.95)
items.Size = UDim2.fromScale(0.49, 0.16)
items.BackgroundColor3 = Color3.fromRGB(58, 31, 36)
items.Parent = backdrop
local itemsTitle = text(items, "МЕМ-ДЕК  •  КУЛДАУН 7с", 13, COLORS.gold)
itemsTitle.Position = UDim2.fromScale(0.05, 0.08)
itemsTitle.Size = UDim2.fromScale(0.9, 0.2)
local itemNames = { { "🍅  ТОМАТ", "tomato" }, { "💩  БРОСОК", "poop" }, { "✦  КОНФЕТТИ", "confetti" } }
for index, itemData in itemNames do
    local item = button(items, itemData[1], COLORS.accent, UDim2.fromScale(0.29, 0.34), UDim2.fromScale(0.05 + ((index - 1) % 3) * 0.32, 0.46))
    item.Activated:Connect(function()
        action:FireServer({ type = "useItem", itemId = itemData[2], targetUserId = nil })
    end)
end

local toast = rounded(Instance.new("Frame"), 12, COLORS.accent)
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.fromScale(0.5, 0.12)
toast.Size = UDim2.fromScale(0.42, 0.065)
toast.BackgroundColor3 = Color3.fromRGB(84, 42, 44)
toast.Visible = false
toast.Parent = backdrop
local toastText = text(toast, "", 14, COLORS.ink)
toastText.Position = UDim2.fromScale(0.06, 0.15)
toastText.Size = UDim2.fromScale(0.88, 0.7)
toastText.TextXAlignment = Enum.TextXAlignment.Center

local rolePanel = rounded(Instance.new("Frame"), 20, COLORS.accent)
rolePanel.AnchorPoint = Vector2.new(0.5, 0.5)
rolePanel.Position = UDim2.fromScale(0.5, 0.5)
rolePanel.Size = UDim2.fromScale(0.44, 0.34)
rolePanel.BackgroundColor3 = Color3.fromRGB(63, 32, 38)
rolePanel.Visible = false
rolePanel.ZIndex = 20
rolePanel.Parent = backdrop
local roleTitle = text(rolePanel, "КТО ТЫ В ЭТОЙ ИГРЕ?", 24, COLORS.gold)
roleTitle.Position = UDim2.fromScale(0.08, 0.12)
roleTitle.Size = UDim2.fromScale(0.84, 0.2)
roleTitle.TextXAlignment = Enum.TextXAlignment.Center
local roleHint = text(rolePanel, "Выбери роль перед началом партии", 14, COLORS.muted, false)
roleHint.Position = UDim2.fromScale(0.08, 0.34)
roleHint.Size = UDim2.fromScale(0.84, 0.14)
roleHint.TextXAlignment = Enum.TextXAlignment.Center
local playerRoleButton = button(rolePanel, "ИГРОК", COLORS.surface2, UDim2.fromScale(0.36, 0.24), UDim2.fromScale(0.1, 0.62))
local hostRoleButton = button(rolePanel, "ВЕДУЩИЙ", COLORS.accent, UDim2.fromScale(0.36, 0.24), UDim2.fromScale(0.54, 0.62))
playerRoleButton.ZIndex = 21
hostRoleButton.ZIndex = 21
playerRoleButton.Activated:Connect(function() action:FireServer({ type = "chooseRole", role = "player" }) end)
hostRoleButton.Activated:Connect(function() action:FireServer({ type = "chooseRole", role = "host" }) end)

local currentState
local function findQuestion(id)
    for _, question in currentState.questions do
        if question.id == id then return question end
    end
    return nil
end

local function showToast(message: string)
    toastText.Text = message
    toast.Visible = true
    task.delay(3, function()
        if toastText.Text == message then toast.Visible = false end
    end)
end

local function renderScores(state)
    clear(scoreList)
    for _, person in state.players do
        local row = rounded(Instance.new("Frame"), 9)
        row.Size = UDim2.new(1, -6, 0, 42)
        row.BackgroundColor3 = person.isHost and Color3.fromRGB(103, 60, 46) or COLORS.surface2
        row.Parent = scoreList
        local name = text(row, (person.isHost and "★ " or "") .. person.name, 12, COLORS.ink)
        name.Position = UDim2.fromScale(0.06, 0.12)
        name.Size = UDim2.fromScale(0.64, 0.34)
        local score = text(row, tostring(state.scores[tostring(person.userId)] or state.scores[person.userId] or 0), 15, COLORS.gold)
        score.Position = UDim2.fromScale(0.7, 0.12)
        score.Size = UDim2.fromScale(0.24, 0.34)
        score.TextXAlignment = Enum.TextXAlignment.Right
    end
    scoreList.CanvasSize = UDim2.new(0, 0, 0, scoreLayout.AbsoluteContentSize.Y + 8)
end

local function renderHostTools(state)
    hostTools.Visible = state.hostUserId == player.UserId
    if not hostTools.Visible then return end
    clear(hostList)
    for _, person in state.players do
        if person.userId ~= player.UserId then
            local row = rounded(Instance.new("Frame"), 7)
            row.Size = UDim2.new(1, -4, 0, 30)
            row.BackgroundColor3 = COLORS.surface2
            row.Parent = hostList
            local name = text(row, person.name, 10, COLORS.ink, false)
            name.Position = UDim2.fromScale(0.04, 0.15)
            name.Size = UDim2.fromScale(0.32, 0.7)
            local mute = button(row, "ТШ", COLORS.surface, UDim2.fromScale(0.18, 0.72), UDim2.fromScale(0.38, 0.14))
            mute.TextSize = 10
            mute.Activated:Connect(function() action:FireServer({ type = "moderate", userId = person.userId, moderation = "mute" }) end)
            local pit = button(row, "ЯМА", COLORS.danger, UDim2.fromScale(0.22, 0.72), UDim2.fromScale(0.58, 0.14))
            pit.TextSize = 10
            pit.Activated:Connect(function() action:FireServer({ type = "moderate", userId = person.userId, moderation = "pit" }) end)
            local kick = button(row, "OUT", COLORS.accent, UDim2.fromScale(0.18, 0.72), UDim2.fromScale(0.8, 0.14))
            kick.TextSize = 10
            kick.Activated:Connect(function() action:FireServer({ type = "moderate", userId = person.userId, moderation = "kick" }) end)
        end
    end
    hostList.CanvasSize = UDim2.new(0, 0, 0, hostLayout.AbsoluteContentSize.Y + 4)
end

local function renderBoard(state)
    clear(cellsLayer)
    local categories = {}
    for _, question in state.questions do
        categories[question.category] = categories[question.category] or {}
        table.insert(categories[question.category], question)
    end
    local names = {}
    for category in categories do table.insert(names, category) end
    table.sort(names)
    local columns = math.max(#names, 1)
    for index, category in names do
        local column = Instance.new("Frame")
        column.BackgroundTransparency = 1
        column.Size = UDim2.fromScale(0.96 / columns, 0.95)
        column.Position = UDim2.fromScale(0.02 + (index - 1) * (0.96 / columns), 0.02)
        column.Parent = cellsLayer
        local categoryLabel = text(column, category, 13, COLORS.muted)
        categoryLabel.Size = UDim2.fromScale(1, 0.14)
        categoryLabel.TextXAlignment = Enum.TextXAlignment.Center
        for rowIndex, question in categories[category] do
            local cell = button(column, question.answered and "—" or tostring(question.value), question.answered and Color3.fromRGB(63, 45, 47) or Color3.fromRGB(126, 62, 53), UDim2.fromScale(0.92, 0.14), UDim2.fromScale(0.04, 0.17 + (rowIndex - 1) * 0.18))
            cell.TextSize = 18
            cell.TextColor3 = question.answered and COLORS.muted or COLORS.gold
            cell.Activated:Connect(function()
                if state.hostUserId == player.UserId and not question.answered then
                    action:FireServer({ type = "selectQuestion", questionId = question.id })
                end
            end)
        end
    end
end

local function renderQuestion(state, question, isHost)
    local modal = rounded(Instance.new("Frame"), 18, COLORS.gold)
    modal.Name = "QuestionModal"
    modal.Position = UDim2.fromScale(0.04, 0.18)
    modal.Size = UDim2.fromScale(0.92, 0.76)
    modal.BackgroundColor3 = Color3.fromRGB(48, 27, 33)
    modal.ZIndex = 5
    modal.Parent = board
    local eyebrow = text(modal, question.category .. "  •  " .. question.value .. " очков", 13, COLORS.gold)
    eyebrow.Position = UDim2.fromScale(0.06, 0.06)
    eyebrow.Size = UDim2.fromScale(0.88, 0.08)
    eyebrow.ZIndex = 6
    local questionText = text(modal, question.text, 23, COLORS.ink)
    questionText.Position = UDim2.fromScale(0.06, 0.17)
    questionText.Size = UDim2.fromScale(0.88, 0.26)
    questionText.ZIndex = 6
    if isHost then
        local info = text(modal, "ОТВЕТЫ ИГРОКОВ", 13, COLORS.muted)
        info.Position = UDim2.fromScale(0.06, 0.47)
        info.Size = UDim2.fromScale(0.88, 0.08)
        info.ZIndex = 6
        local answers = state.answers or {}
        local y = 0.56
        for _, person in state.players do
            local answer = answers[tostring(person.userId)] or answers[person.userId]
            if answer then
                local row = rounded(Instance.new("Frame"), 8)
                row.Size = UDim2.fromScale(0.88, 0.11)
                row.Position = UDim2.fromScale(0.06, y)
                row.BackgroundColor3 = answer.graded and Color3.fromRGB(62, 85, 66) or COLORS.surface2
                row.ZIndex = 6
                row.Parent = modal
                local answerLabel = text(row, person.name .. ": " .. answer.text, 12, COLORS.ink, false)
                answerLabel.Position = UDim2.fromScale(0.03, 0.15)
                answerLabel.Size = UDim2.fromScale(0.54, 0.7)
                answerLabel.ZIndex = 7
                local plus = button(row, "+" .. question.value, COLORS.mint, UDim2.fromScale(0.18, 0.7), UDim2.fromScale(0.61, 0.15))
                plus.TextColor3 = COLORS.wine
                plus.ZIndex = 7
                plus.Activated:Connect(function() action:FireServer({ type = "gradeAnswer", userId = person.userId, delta = question.value }) end)
                local minus = button(row, "−" .. question.value, COLORS.danger, UDim2.fromScale(0.16, 0.7), UDim2.fromScale(0.81, 0.15))
                minus.ZIndex = 7
                minus.Activated:Connect(function() action:FireServer({ type = "gradeAnswer", userId = person.userId, delta = -question.value }) end)
                y += 0.13
            end
        end
        local finish = button(modal, "ЗАКРЫТЬ ВОПРОС", Color3.fromRGB(101, 79, 47), UDim2.fromScale(0.42, 0.12), UDim2.fromScale(0.29, 0.84))
        finish.ZIndex = 7
        finish.Activated:Connect(function() action:FireServer({ type = "finishQuestion" }) end)
    else
        local alreadyAnswered = state.myAnswer and state.myAnswer.questionId == question.id
        if question.kind == "choice" and question.choices then
            for index, choice in question.choices do
                local choiceButton = button(modal, choice, alreadyAnswered and Color3.fromRGB(71, 60, 58) or COLORS.accent, UDim2.fromScale(0.4, 0.14), UDim2.fromScale(0.08 + ((index - 1) % 2) * 0.46, 0.53 + math.floor((index - 1) / 2) * 0.17))
                choiceButton.ZIndex = 7
                choiceButton.Activated:Connect(function()
                    if not alreadyAnswered then action:FireServer({ type = "submitAnswer", answer = choice }) end
                end)
            end
        else
            local answerBox = Instance.new("TextBox")
            answerBox.PlaceholderText = alreadyAnswered and "Ответ уже отправлен" or "Напиши свой ответ…"
            answerBox.Text = ""
            answerBox.TextSize = 17
            answerBox.Font = Enum.Font.Gotham
            answerBox.TextColor3 = COLORS.wine
            answerBox.BackgroundColor3 = Color3.fromRGB(255, 231, 196)
            answerBox.Size = UDim2.fromScale(0.56, 0.16)
            answerBox.Position = UDim2.fromScale(0.08, 0.58)
            answerBox.ClearTextOnFocus = false
            answerBox.ZIndex = 7
            rounded(answerBox, 10)
            answerBox.Parent = modal
            local send = button(modal, alreadyAnswered and "ОТПРАВЛЕНО" or "ОТВЕТИТЬ", alreadyAnswered and Color3.fromRGB(71, 60, 58) or COLORS.accent, UDim2.fromScale(0.25, 0.16), UDim2.fromScale(0.68, 0.58))
            send.ZIndex = 7
            send.Activated:Connect(function()
                if not alreadyAnswered and answerBox.Text ~= "" then action:FireServer({ type = "submitAnswer", answer = answerBox.Text }) end
            end)
        end
        local hint = text(modal, alreadyAnswered and "Ведущий скоро проверит ответ" or "Ответ виден только тебе и ведущему", 12, COLORS.muted, false)
        hint.Position = UDim2.fromScale(0.08, 0.84)
        hint.Size = UDim2.fromScale(0.84, 0.08)
        hint.ZIndex = 7
    end
end

local function render(state)
    currentState = state
    local role = state.roles and (state.roles[tostring(player.UserId)] or state.roles[player.UserId])
    local isHost = state.hostUserId == player.UserId
    rolePanel.Visible = role == "undecided"
    if rolePanel.Visible then
        roleHint.Text = state.hostUserId ~= 0 and "Ведущий уже выбран — заходи игроком" or "Выбери роль перед началом партии"
        return
    end
    phaseLabel.Text = state.phase == "question" and (isHost and "ВЕДУЩИЙ • ПРОВЕРКА" or "ВОПРОС ОТКРЫТ") or "ЛОББИ • " .. tostring(#state.players) .. " В ЗАЛЕ"
    renderScores(state)
    renderHostTools(state)
    clear(cellsLayer)
    if state.selectedQuestionId then
        local question = findQuestion(state.selectedQuestionId)
        if question then renderQuestion(state, question, isHost) end
    else
        renderBoard(state)
    end
    if state.actionFeed and state.actionFeed.text then showToast(state.actionFeed.text) end
end

stateChanged.OnClientEvent:Connect(render)
