local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

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
--                          SYSTÈME ESP (HIGHLIGHT)
-- =====================================================================

local function addESP(object)
    if not object:IsA("BasePart") then return end
    if activeESP[object] then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_" .. object.Name
    highlight.FillColor = Color3.fromRGB(0, 255, 140)
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0
    highlight.Adornee = object
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = espEnabled
    highlight.Parent = object

    activeESP[object] = highlight
end

local function removeESP(object)
    if activeESP[object] then
        activeESP[object]:Destroy()
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

for _, desc in ipairs(Workspace:GetDescendants()) do
    setupPrompt(desc)
end

-- =====================================================================
--                      INTERFACE GRAPHIQUE (GUI)
-- =====================================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GAG2_MiniMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Conteneur principal positionné au CENTRE de l'écran
local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 190, 0, 100)
Frame.Position = UDim2.new(0.5, -95, 0.5, -50) -- Centre absolu
Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
Frame.BorderSizePixel = 0
Frame.Active = true -- Permet de détecter les inputs pour le drag
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

-- =====================================================================
--                          SYSTÈME DE DRAG
-- =====================================================================

local dragging, dragInput, dragStart, startPos

Frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Frame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

Frame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        Frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- =====================================================================
--                        CRÉATION DES BOUTONS
-- =====================================================================

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

-- Bouton ESP
createToggleButton("ESP SEEDS", espEnabled, function(state)
    espEnabled = state
    for _, highlight in pairs(activeESP) do
        if highlight and highlight.Parent then
            highlight.Enabled = espEnabled
        end
    end
end)

-- Bouton ProximityPrompt
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
