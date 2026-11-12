local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SIGameRemotes")
local stateChanged = remotes:WaitForChild("StateChanged") :: RemoteEvent
local action = remotes:WaitForChild("Action") :: RemoteEvent
local catalogResult = remotes:WaitForChild("CatalogResult") :: RemoteEvent

local gui = Instance.new("ScreenGui")
gui.Name = "SIGameCatalog"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function rounded(parent: Instance, radius: number)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = parent
end

local function text(parent: Instance, value: string, size: number, color: Color3)
    local item = Instance.new("TextLabel")
    item.BackgroundTransparency = 1
    item.Text = value
    item.TextColor3 = color
    item.TextSize = size
    item.Font = Enum.Font.GothamBold
    item.TextWrapped = true
    item.Parent = parent
    return item
end

local openButton = Instance.new("TextButton")
openButton.Name = "OpenCatalog"
openButton.Text = "ПАКИ  •  КАТАЛОГ"
openButton.TextSize = 16
openButton.TextColor3 = Color3.fromRGB(255, 236, 198)
openButton.BackgroundColor3 = Color3.fromRGB(117, 57, 48)
openButton.AnchorPoint = Vector2.new(1, 0)
openButton.Position = UDim2.fromScale(0.98, 0.025)
openButton.Size = UDim2.fromScale(0.2, 0.055)
rounded(openButton, 10)
openButton.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "CatalogPanel"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.fromScale(0.98, 0.1)
panel.Size = UDim2.fromScale(0.48, 0.78)
panel.BackgroundColor3 = Color3.fromRGB(47, 29, 32)
rounded(panel, 18)
panel.Visible = false
panel.Parent = gui

local title = text(panel, "КАТАЛОГ ПАКОВ", 24, Color3.fromRGB(255, 229, 184))
title.Position = UDim2.fromScale(0.05, 0.04)
title.Size = UDim2.fromScale(0.65, 0.08)

local close = Instance.new("TextButton")
close.Text = "×"
close.TextSize = 28
close.TextColor3 = Color3.fromRGB(255, 229, 184)
close.BackgroundTransparency = 1
close.Position = UDim2.fromScale(0.9, 0.03)
close.Size = UDim2.fromScale(0.07, 0.08)
close.Parent = panel

local search = Instance.new("TextBox")
search.PlaceholderText = "Найти пак: мемы, Дота, кино…"
search.Text = ""
search.TextSize = 16
search.TextColor3 = Color3.fromRGB(48, 29, 31)
search.BackgroundColor3 = Color3.fromRGB(255, 235, 201)
search.Position = UDim2.fromScale(0.05, 0.14)
search.Size = UDim2.fromScale(0.66, 0.08)
rounded(search, 10)
search.Parent = panel

local find = Instance.new("TextButton")
find.Text = "ИСКАТЬ"
find.TextSize = 15
find.TextColor3 = Color3.fromRGB(255, 239, 210)
find.BackgroundColor3 = Color3.fromRGB(186, 77, 55)
find.Position = UDim2.fromScale(0.74, 0.14)
find.Size = UDim2.fromScale(0.21, 0.08)
rounded(find, 10)
find.Parent = panel

local tags = { "Все", "Memes", "Games", "Anime", "Music", "Humor" }
local activeTag = ""
local sortModes = { "popular", "newest", "title" }
local sortLabels = { popular = "ПОПУЛЯРНЫЕ", newest = "НОВЫЕ", title = "ПО НАЗВАНИЮ" }
local activeSort = "popular"
local tagButtons = {}
for index, tag in tags do
    local button = Instance.new("TextButton")
    button.Text = tag
    button.TextSize = 13
    button.TextColor3 = Color3.fromRGB(255, 232, 194)
    button.BackgroundColor3 = index == 1 and Color3.fromRGB(178, 76, 55) or Color3.fromRGB(94, 57, 52)
    button.Position = UDim2.fromScale(0.05 + ((index - 1) % 3) * 0.2, 0.25 + math.floor((index - 1) / 3) * 0.055)
    button.Size = UDim2.fromScale(0.17, 0.045)
    rounded(button, 8)
    button.Parent = panel
    tagButtons[tag] = button
    button.Activated:Connect(function()
        activeTag = tag == "Все" and "" or tag
        for name, tagButton in tagButtons do
            tagButton.BackgroundColor3 = name == (activeTag == "" and "Все" or activeTag) and Color3.fromRGB(178, 76, 55) or Color3.fromRGB(94, 57, 52)
        end
        action:FireServer({ type = "searchCatalog", query = search.Text, tag = activeTag, sort = activeSort })
    end)
end

local sortButton = Instance.new("TextButton")
sortButton.Text = sortLabels[activeSort]
sortButton.TextSize = 12
sortButton.TextColor3 = Color3.fromRGB(255, 232, 194)
sortButton.BackgroundColor3 = Color3.fromRGB(94, 57, 52)
sortButton.Position = UDim2.fromScale(0.7, 0.25)
sortButton.Size = UDim2.fromScale(0.25, 0.045)
rounded(sortButton, 8)
sortButton.Parent = panel
sortButton.Activated:Connect(function()
    local currentIndex = table.find(sortModes, activeSort) or 1
    activeSort = sortModes[currentIndex % #sortModes + 1]
    sortButton.Text = sortLabels[activeSort]
    action:FireServer({ type = "searchCatalog", query = search.Text, tag = activeTag, sort = activeSort })
end)

local status = text(panel, "Ищем паки Steam Workshop…", 14, Color3.fromRGB(225, 187, 157))
status.Position = UDim2.fromScale(0.05, 0.38)
status.Size = UDim2.fromScale(0.9, 0.06)

local list = Instance.new("ScrollingFrame")
list.Name = "PackList"
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Position = UDim2.fromScale(0.05, 0.45)
list.Size = UDim2.fromScale(0.9, 0.5)
list.ScrollBarThickness = 5
list.CanvasSize = UDim2.fromScale(0, 0)
list.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.Parent = list

local currentState = { hostUserId = 0, proposals = {} }
local lastItems = {}

local function clearList()
    for _, child in list:GetChildren() do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end

local function renderItems(items)
    lastItems = items
    clearList()
    status.Text = #items == 0 and "Ничего не нашли. Попробуй другой запрос." or ("Найдено паков: " .. #items)
    for _, item in items do
        local card = Instance.new("Frame")
        card.BackgroundColor3 = Color3.fromRGB(72, 42, 42)
        card.Size = UDim2.new(1, -8, 0, 92)
        rounded(card, 12)
        card.Parent = list

        local cardTitle = text(card, item.title or "Без названия", 16, Color3.fromRGB(255, 232, 194))
        cardTitle.Position = UDim2.fromScale(0.04, 0.12)
        cardTitle.Size = UDim2.fromScale(0.62, 0.27)

        local voteCount = 0
        if proposal and proposal.votes then
            for voted in proposal.votes do
                if voted then voteCount += 1 end
            end
        end
        local meta = table.concat(item.tags or {}, "  •  ")
        if proposal then meta ..= "  •  голосов: " .. voteCount end
        local cardMeta = text(card, meta, 12, Color3.fromRGB(210, 168, 143))
        cardMeta.Position = UDim2.fromScale(0.04, 0.48)
        cardMeta.Size = UDim2.fromScale(0.62, 0.25)

        local proposal = currentState.proposals and currentState.proposals[tostring(item.workshopId)]
        local isHost = currentState.hostUserId == player.UserId
        local install = Instance.new("TextButton")
        install.Text = isHost and "ВЫБРАТЬ" or (proposal and "ГОЛОСУЮ" or "ПРЕДЛОЖИТЬ")
        install.TextSize = 13
        install.TextColor3 = Color3.fromRGB(255, 241, 214)
        install.BackgroundColor3 = Color3.fromRGB(188, 76, 56)
        install.Position = UDim2.fromScale(0.7, 0.26)
        install.Size = UDim2.fromScale(0.25, 0.46)
        rounded(install, 9)
        install.Parent = card
        install.Activated:Connect(function()
            install.Text = isHost and "ЗАГРУЗКА…" or "ГОЛОС ЗАПИСАН"
            install.Active = false
            if isHost then
                action:FireServer({ type = "installPack", workshopId = item.workshopId })
            elseif proposal then
                action:FireServer({ type = "votePack", workshopId = item.workshopId })
            else
                action:FireServer({ type = "proposePack", workshopId = item.workshopId, title = item.title })
            end
        end)
    end
    list.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
end

stateChanged.OnClientEvent:Connect(function(state)
    currentState = state
    if panel.Visible and #lastItems > 0 then
        renderItems(lastItems)
    end
end)

local function searchCatalog()
    status.Text = "Ищем в Steam Workshop…"
    action:FireServer({ type = "searchCatalog", query = search.Text, tag = activeTag, sort = activeSort })
end

openButton.Activated:Connect(function()
    panel.Visible = not panel.Visible
    if panel.Visible then
        searchCatalog()
    end
end)
close.Activated:Connect(function()
    panel.Visible = false
end)
find.Activated:Connect(searchCatalog)
search.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        searchCatalog()
    end
end)

catalogResult.OnClientEvent:Connect(function(payload)
    if payload.type == "search" then
        if payload.success then
            renderItems(payload.items or {})
            if payload.offline then
                status.Text = "Локальный демо-каталог: можно играть сразу"
            end
        else
            status.Text = "Каталог временно недоступен: " .. tostring(payload.error or "ошибка")
        end
    elseif payload.type == "installStatus" then
        if payload.status == "downloading" then
            status.Text = "Пак скачивается и проверяется для всей комнаты…"
        elseif payload.status == "ready" then
            status.Text = "Готово: " .. tostring(payload.title or "пак загружен")
        elseif payload.status == "failed" then
            status.Text = "Не получилось установить: " .. tostring(payload.error or "ошибка")
        end
    end
end)

