local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SIGameRemotes")
local stateChanged = remotes:WaitForChild("StateChanged") :: RemoteEvent
local action = remotes:WaitForChild("Action") :: RemoteEvent

local gui = Instance.new("ScreenGui")
gui.Name = "SIGameLounge"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function rounded(parent: Instance, radius: number)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = parent
end

local function label(parent: Instance, text: string, size: number, color: Color3)
    local item = Instance.new("TextLabel")
    item.BackgroundTransparency = 1
    item.Text = text
    item.TextColor3 = color
    item.TextSize = size
    item.Font = Enum.Font.GothamBold
    item.TextWrapped = true
    item.Parent = parent
    return item
end

local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.fromRGB(35, 22, 24)
backdrop.Parent = gui

local header = Instance.new("Frame")
header.Size = UDim2.fromScale(1, 0.1)
header.BackgroundColor3 = Color3.fromRGB(68, 35, 34)
header.Parent = backdrop
label(header, "SIGAME LOUNGE  •  тёплый вечер, сложные вопросы", 24, Color3.fromRGB(255, 224, 178)).Size = UDim2.fromScale(0.6, 1)

local board = Instance.new("Frame")
board.AnchorPoint = Vector2.new(0.5, 0.5)
board.Position = UDim2.fromScale(0.5, 0.55)
board.Size = UDim2.fromScale(0.68, 0.66)
board.BackgroundColor3 = Color3.fromRGB(91, 45, 42)
rounded(board, 22)
board.Parent = backdrop

local boardTitle = label(board, "ИГРОВОЕ ПОЛЕ", 22, Color3.fromRGB(255, 230, 191))
boardTitle.Position = UDim2.fromScale(0.03, 0.02)
boardTitle.Size = UDim2.fromScale(0.94, 0.1)

local cells = {}
local selectedQuestion

local function clearCells()
    for _, cell in cells do
        cell:Destroy()
    end
    table.clear(cells)
end

local function renderQuestion(question, host)
    local modal = board:FindFirstChild("QuestionModal") or Instance.new("Frame")
    modal.Name = "QuestionModal"
    modal.Size = UDim2.fromScale(0.9, 0.72)
    modal.Position = UDim2.fromScale(0.05, 0.16)
    modal.BackgroundColor3 = Color3.fromRGB(45, 27, 31)
    rounded(modal, 18)
    modal.Parent = board
    modal:ClearAllChildren()
    local questionText = label(modal, question.text, 28, Color3.fromRGB(255, 241, 214))
    questionText.Position = UDim2.fromScale(0.06, 0.1)
    questionText.Size = UDim2.fromScale(0.88, 0.48)

    local answerBox = Instance.new("TextBox")
    answerBox.PlaceholderText = "Твой ответ…"
    answerBox.Text = ""
    answerBox.TextSize = 20
    answerBox.TextColor3 = Color3.fromRGB(48, 27, 30)
    answerBox.BackgroundColor3 = Color3.fromRGB(255, 232, 194)
    answerBox.Size = UDim2.fromScale(0.52, 0.16)
    answerBox.Position = UDim2.fromScale(0.06, 0.66)
    rounded(answerBox, 12)
    answerBox.Parent = modal

    local send = Instance.new("TextButton")
    send.Text = "ОТВЕТИТЬ"
    send.TextSize = 18
    send.TextColor3 = Color3.fromRGB(255, 241, 214)
    send.BackgroundColor3 = Color3.fromRGB(188, 76, 56)
    send.Size = UDim2.fromScale(0.28, 0.16)
    send.Position = UDim2.fromScale(0.64, 0.66)
    rounded(send, 12)
    send.Parent = modal

    if host then
        local finish = Instance.new("TextButton")
        finish.Text = "ЗАКРЫТЬ ВОПРОС"
        finish.TextSize = 16
        finish.TextColor3 = Color3.fromRGB(255, 241, 214)
        finish.BackgroundColor3 = Color3.fromRGB(99, 85, 54)
        finish.Size = UDim2.fromScale(0.4, 0.12)
        finish.Position = UDim2.fromScale(0.3, 0.86)
        rounded(finish, 10)
        finish.Parent = modal
        finish.Activated:Connect(function()
            action:FireServer({ type = "finishQuestion" })
        end)
    end
end

local function render(state)
    local host = state.hostUserId == player.UserId
    local modal = board:FindFirstChild("QuestionModal")
    if state.selectedQuestionId then
        local question
        for _, candidate in state.questions do
            if candidate.id == state.selectedQuestionId then
                question = candidate
                break
            end
        end
        if question then
            renderQuestion(question, host)
        end
        return
    elseif modal then
        modal:Destroy()
    end

    clearCells()
    local categories = {}
    for _, question in state.questions do
        categories[question.category] = categories[question.category] or {}
        table.insert(categories[question.category], question)
    end
    local categoryNames = {}
    for category in categories do
        table.insert(categoryNames, category)
    end
    table.sort(categoryNames)
    for index, category in categoryNames do
        local column = Instance.new("Frame")
        column.BackgroundTransparency = 1
        column.Size = UDim2.fromScale(0.22, 0.8)
        column.Position = UDim2.fromScale(0.04 + (index - 1) * 0.24, 0.14)
        column.Parent = board
        table.insert(cells, column)
        local categoryLabel = label(column, category, 16, Color3.fromRGB(255, 241, 214))
        categoryLabel.Size = UDim2.fromScale(1, 0.16)
        for row, question in categories[category] do
            local button = Instance.new("TextButton")
            button.Text = question.answered and "—" or tostring(question.value)
            button.TextSize = 20
            button.TextColor3 = question.answered and Color3.fromRGB(130, 100, 93) or Color3.fromRGB(255, 214, 143)
            button.BackgroundColor3 = Color3.fromRGB(113, 57, 50)
            button.Size = UDim2.fromScale(1, 0.15)
            button.Position = UDim2.fromScale(0, 0.18 + (row - 1) * 0.18)
            rounded(button, 10)
            button.Parent = column
            button.Activated:Connect(function()
                if host and not question.answered then
                    action:FireServer({ type = "selectQuestion", questionId = question.id })
                end
            end)
        end
    end
end

stateChanged.OnClientEvent:Connect(render)

