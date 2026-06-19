local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Vérification et attente du dossier cible
local targetFolder = Workspace:WaitForChild("Map", 5) and Workspace.Map:WaitForChild("SeedPackSpawnClient", 5)

if not targetFolder then
    warn("[GAG2] Dossier cible introuvable dans le Workspace.")
    return
end

-- Nettoyage d'un ancien GUI si existant
local oldGui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("GAG2_MiniMenu")
if oldGui then oldGui:Destroy() end

-- États par défaut
local espEnabled = true
local instantEnabled = true
local activeESP = {}

-- =====================================================================
--               SYSTÈME ESP 2D FIXE (ALWAYS VISIBLE)
-- =====================================================================

local function addESP(object)
    if not object:IsA("BasePart") then return end
    if activeESP[object] then return end

    local cache = {}

    -- 1. Création du BillboardGui (Reste à taille FIXE sur l'écran peu importe la distance)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_Billboard"
    billboard.Size = UDim2.new(0, 100, 0, 40) -- Taille fixe en pixels
    billboard.AlwaysOnTop = true
    billboard.ResetOnSpawn = false
    billboard.Adornee = object
    billboard.Enabled = espEnabled
    billboard.Parent = LocalPlayer:WaitForChild("PlayerGui")
    cache.Billboard = billboard

    -- Carré de repère visuel (au centre de l'objet)
    local boxPointer = Instance.new("Frame")
    boxPointer.Size = UDim2.new(0, 12, 0, 12)
    boxPointer.Position = UDim2.new(0.5, -6, 0.5, -6)
    boxPointer.BackgroundColor3 = Color3.fromRGB(0, 255, 140) -- Vert fluo
    boxPointer.BorderSizePixel = 0
    boxPointer.Parent = billboard
    
    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 3)
    boxCorner.Parent = boxPointer

    -- Texte pour la distance et le nom
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 0, 15)
    textLabel.Position = UDim2.new(0, 0, 0, -18)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = object.Name .. " [0m]"
    textLabel.TextColor3 = Color3.fromRGB(0, 255, 140)
    textLabel.TextSize = 13
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextStrokeTransparency = 0 -- Contour noir pour bien lire
    textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    textLabel.Parent = billboard

    -- 2. Ligne de traçage (Tracer Écran)
    local tracer = Instance.new("Frame")
    tracer.Name = "ESP_Tracer"
    tracer.BackgroundColor3 = Color3.fromRGB(0, 255, 140)
    tracer.BorderSizePixel = 0
    tracer.AnchorPoint = Vector2.new(0.5, 0.5)
    tracer.Visible = false
    tracer.Parent = LocalPlayer.PlayerGui:WaitForChild("GAG2_MiniMenu", 1) or ScreenGui
    cache.Tracer = tracer

    -- Boucle de mise à jour pour la distance et la ligne 2D
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not object or not object.Parent then
            if connection then connection:Disconnect() end
            return
        end

        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")

        if espEnabled and root then
            -- Calcul de la distance
            local distance = math.floor((object.Position - root.Position).Magnitude)
            textLabel.Text = string.format("%s [%dm]", object.Name, distance)

            -- Calcul de la position à l'écran pour la ligne
            local screenPos, onScreen = Camera:WorldToViewportPoint(object.Position)

            if onScreen then
                -- Ligne partant du BAS du centre de l'écran (Viewport)
                local startX = Camera.ViewportSize.X / 2
                local startY = Camera.ViewportSize.Y

                local endX = screenPos.X
                local endY = screenPos.Y

                local distanceX = endX - startX
                local distanceY = endY - startY
                local lineLength = math.sqrt(distanceX^2 + distanceY^2)

                tracer.Size = UDim2.new(0, lineLength, 0, 1.5) -- Épaisseur de la ligne
                tracer.Position = UDim2.new(0, (startX + endX) / 2, 0, (startY + endY) / 2)
                tracer.Rotation = math.deg(math.atan2(distanceY, distanceX))
                tracer.Visible = true
            else
                tracer.Visible = false
            end
        else
            tracer.Visible = false
        end
    end)

    cache.Connection = connection
    activeESP[object] = cache
end

local function removeESP(object)
    if activeESP[object] then
        if activeESP[object].Connection then activeESP[object].Connection:Disconnect() end
        if activeESP[object].Billboard then activeESP[object].Billboard:Destroy() end
        if activeESP[object].Tracer then activeESP[object].Tracer:Destroy() end
        activeESP[object] = nil
    end
end

targetFolder.ChildAdded:Connect(addESP)
targetFolder.ChildRemoved:Connect(removeESP)

for _, child in ipairs(targetFolder:GetChildren()) do
    addESP(child)
end

-- =====================================================================
--               INTERACTION INSTANTANÉE (HOLD DURATION)
-- =====================================================================

local originalDurations = {}

local function setupPrompt(desc)
    if desc:IsA("ProximityPrompt") then
        if not originalDurations[desc] then
            originalDurations[desc] = desc.HoldDuration
        end
        if instantEnabled then
            desc.HoldDuration = 0
        else
            desc.HoldDuration = originalDurations[desc] or 0
        end
    end
end

Workspace.DescendantAdded:Connect(setupPrompt)
for _, desc in ipairs(Workspace:GetDescendants()) do setupPrompt(desc) end

-- =====================================================================
--                      INTERFACE GRAPHIQUE (GUI)
-- =====================================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GAG2_MiniMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- On remet les traceurs dans ce conteneur principal
for _, cache in pairs(activeESP) do
    if cache.Tracer then cache.Tracer.Parent = ScreenGui end
end

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 190, 0, 100)
Frame.Position = UDim2.new(0.5, -95, 0.5, -50)
Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
Frame.BorderSizePixel = 0
Frame.Active = true
Frame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = Frame

local UIStroke = Instance.new("UIStroke")
UIStroke.Thickness = 1
UIStroke.Color = Color3.fromRGB(45, 45, 55)
UIStroke.Parent = Frame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Parent = Frame
UIListLayout.Padding = UDim.new(0, 6)
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center

-- Système Draggable
local dragging, dragInput, dragStart, startPos
Frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
Frame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        Frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Création boutons
local function createToggleButton(text, defaultState, onClick)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0, 170, 0, 34)
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 11
    Btn.BorderSizePixel = 0
    Btn.Parent = Frame

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = Btn

    local function updateVisuals(state)
        if state then
            Btn.Text = text .. " : ON"
            Btn.BackgroundColor3 = Color3.fromRGB(0, 150, 90)
            Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            Btn.Text = text .. " : OFF"
            Btn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
            Btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end

    local state = defaultState
    updateVisuals(state)
    Btn.MouseButton1Click:Connect(function()
        state = not state
        updateVisuals(state)
        onClick(state)
    end)
end

createToggleButton("ESP SEEDS", espEnabled, function(state)
    espEnabled = state
    for _, cache in pairs(activeESP) do
        if cache.Billboard then cache.Billboard.Enabled = espEnabled end
        if cache.Tracer then cache.Tracer.Visible = espEnabled end
    end
end)

createToggleButton("INSTANT PROMPT", instantEnabled, function(state)
    instantEnabled = state
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            if instantEnabled then
                desc.HoldDuration = 0
            else
                desc.HoldDuration = originalDurations[desc] or 0
            end
        end
    end
end)
