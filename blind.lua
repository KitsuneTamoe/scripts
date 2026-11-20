--[[
	WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!
]]
--[[
    Blind but Dangerous - Hub / Script AIO
    Version: 0.2.0
    UI: WindUI 1.6.66
]]

local VERSION = "0.2.0"
local WINDUI_VERSION = "1.6.66"

-- Single-instance cleanup
local ENV = (type(getgenv) == "function" and getgenv()) or _G
if ENV.__BBDHub and type(ENV.__BBDHub.Unload) == "function" then
    pcall(ENV.__BBDHub.Unload)
    task.wait(0.2)
end

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/download/" .. WINDUI_VERSION .. "/main.lua"))()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- Visual container
local Container = Instance.new("Folder")
Container.Name = "BBD_Visuals"
Container.Parent = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")

local Window = WindUI:CreateWindow({
    Title = "Blind but Dangerous | Hub",
    Author = "AIO v" .. VERSION,
    Icon = "eye-off",
    Theme = "Dark",
    Size = UDim2.fromOffset(650, 480),
    Resizable = true,
    Folder = "BlindButDangerousHub",
})

-- Tabs
local DashboardTab = Window:Tab({ Title = "Dashboard", Icon = "layout-dashboard" })
local ESPTab = Window:Tab({ Title = "ESP & Visuals", Icon = "eye" })
local UtilityTab = Window:Tab({ Title = "Utilities", Icon = "shield-alert" })
local DiagnosticsTab = Window:Tab({ Title = "Diagnostics", Icon = "scan-search" })
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })

-- State & Config
local Running = true
local Connections = {}
local Entries = {} -- [player] = { Highlight, Gui, Label }

local Config = {
    ESPEnabled = true,
    ShowHiders = true,
    ShowBlindMan = true,
    ShowDistance = true,
    Fullbright = false,
    FOV = 70,
    WalkSpeedBoost = false,
    CustomSpeed = 20,
}

local BLIND_MAN_TOOLS = { "batte", "shotgun" }
local COLOR_BLIND_MAN = Color3.fromRGB(255, 65, 65) -- Red
local COLOR_HIDER = Color3.fromRGB(80, 220, 120)    -- Green

--==================================================
-- ROLE DETECTION (Character Model + Backpack)
--==================================================

local function isBlindMan(player)
    if not player then return false end

    local function hasSeekerTool(parent)
        if not parent then return false end
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("Tool") then
                local lowered = child.Name:lower()
                for _, weapon in ipairs(BLIND_MAN_TOOLS) do
                    if lowered:find(weapon, 1, true) then
                        return true, child.Name
                    end
                end
            end
        end
        return false
    end

    -- 1. Check Workspace character model (equipped tool)
    local foundChar, toolName = hasSeekerTool(player.Character)
    if foundChar then return true, toolName end

    -- 2. Check Backpack (unequipped tool, in case they holster it)
    local foundBag, bagToolName = hasSeekerTool(player:FindFirstChildOfClass("Backpack"))
    if foundBag then return true, bagToolName end

    return false, nil
end

--==================================================
-- ESP ENGINE
--==================================================

local function removeEntry(player)
    local entry = Entries[player]
    if not entry then return end
    if entry.Highlight then pcall(function() entry.Highlight:Destroy() end) end
    if entry.Gui then pcall(function() entry.Gui:Destroy() end) end
    Entries[player] = nil
end

local function updateESP()
    if not Config.ESPEnabled then
        for p in pairs(Entries) do removeEntry(p) end
        return
    end

    local localChar = LocalPlayer.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if char and root and hum and hum.Health > 0 then
                local blind, weaponName = isBlindMan(player)
                local shouldShow = (blind and Config.ShowBlindMan) or (not blind and Config.ShowHiders)

                if shouldShow then
                    local entry = Entries[player]
                    if not entry or entry.Highlight.Adornee ~= char then
                        removeEntry(player)

                        local hl = Instance.new("Highlight")
                        hl.Adornee = char
                        hl.FillTransparency = 0.65
                        hl.OutlineTransparency = 0
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        hl.Parent = Container

                        local gui = Instance.new("BillboardGui")
                        gui.Adornee = root
                        gui.Size = UDim2.fromOffset(220, 24)
                        gui.StudsOffset = Vector3.new(0, 3.2, 0)
                        gui.AlwaysOnTop = true
                        gui.Parent = Container

                        local lbl = Instance.new("TextLabel")
                        lbl.Size = UDim2.fromScale(1, 1)
                        lbl.BackgroundTransparency = 1
                        lbl.Font = Enum.Font.GothamBold
                        lbl.TextSize = 14
                        lbl.TextStrokeTransparency = 0.3
                        lbl.Parent = gui

                        entry = { Highlight = hl, Gui = gui, Label = lbl }
                        Entries[player] = entry
                    end

                    local color = blind and COLOR_BLIND_MAN or COLOR_HIDER
                    entry.Highlight.FillColor = color
                    entry.Highlight.OutlineColor = color
                    entry.Label.TextColor3 = color

                    local roleTag = blind and ("[BLIND MAN" .. (weaponName and (" - " .. weaponName) or "") .. "]") or "[Hider]"
                    local distText = ""
                    if Config.ShowDistance and localRoot then
                        local dist = math.floor((root.Position - localRoot.Position).Magnitude)
                        distText = (" [%dm]"):format(dist)
                    end

                    entry.Label.Text = ("%s %s%s"):format(roleTag, player.DisplayName, distText)
                else
                    removeEntry(player)
                end
            else
                removeEntry(player)
            end
        end
    end
end

--==================================================
-- UI TABS
--==================================================

DashboardTab:Paragraph({
    Title = "Role Detector Active",
    Desc = "Scans Workspace character models and Backpacks for 'Batte' or 'Shotgun' to automatically flag the Blind Man in red.",
})

DashboardTab:Button({
    Title = "Identify Blind Man Now",
    Icon = "crosshair",
    Callback = function()
        local found = {}
        for _, p in ipairs(Players:GetPlayers()) do
            local blind, weapon = isBlindMan(p)
            if blind then
                table.insert(found, p.DisplayName .. " (" .. tostring(weapon) .. ")")
            end
        end

        if #found > 0 then
            WindUI:Notify({ Title = "Blind Man Found!", Content = table.concat(found, ", "), Duration = 5 })
        else
            WindUI:Notify({ Title = "Scan Result", Content = "No player currently holds Batte/Shotgun (might be in lobby).", Duration = 4 })
        end
    end,
})

-- ESP Tab
ESPTab:Toggle({
    Title = "Enable Player ESP",
    Value = Config.ESPEnabled,
    Callback = function(v) Config.ESPEnabled = v end,
})

ESPTab:Toggle({
    Title = "Highlight Blind Man (Red)",
    Value = Config.ShowBlindMan,
    Callback = function(v) Config.ShowBlindMan = v end,
})

ESPTab:Toggle({
    Title = "Highlight Hiders (Green)",
    Value = Config.ShowHiders,
    Callback = function(v) Config.ShowHiders = v end,
})

ESPTab:Toggle({
    Title = "Show Distance",
    Value = Config.ShowDistance,
    Callback = function(v) Config.ShowDistance = v end,
})

ESPTab:Toggle({
    Title = "Fullbright (Counter Blindness / Dark Maps)",
    Value = Config.Fullbright,
    Callback = function(v)
        Config.Fullbright = v
        if v then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 100000
        else
            Lighting.Brightness = 1
            Lighting.GlobalShadows = true
        end
    end,
})

ESPTab:Slider({
    Title = "Field of View (FOV)",
    Step = 5,
    Value = { Min = 50, Max = 120, Default = 70 },
    Callback = function(v)
        Workspace.CurrentCamera.FieldOfView = tonumber(v) or 70
    end,
})

-- Utilities Tab
UtilityTab:Toggle({
    Title = "WalkSpeed Override",
    Value = Config.WalkSpeedBoost,
    Callback = function(v) Config.WalkSpeedBoost = v end,
})

UtilityTab:Slider({
    Title = "Custom WalkSpeed",
    Step = 1,
    Value = { Min = 16, Max = 35, Default = 20 },
    Callback = function(v) Config.CustomSpeed = tonumber(v) or 20 end,
})

-- Diagnostics Tab (To find more game objects/folders)
DiagnosticsTab:Button({
    Title = "Dump Workspace Top-Level Folders",
    Icon = "folder-search",
    Callback = function()
        print("\n========== WORKSPACE STRUCTURE ==========")
        for _, child in ipairs(Workspace:GetChildren()) do
            print(child.Name, "[" .. child.ClassName .. "]", "Children:", #child:GetChildren())
        end
        print("=========================================\n")
        WindUI:Notify({ Title = "Diagnostics", Content = "Workspace folders printed to F9 console.", Duration = 3 })
    end,
})

DiagnosticsTab:Button({
    Title = "Inspect All Player Tools & Attributes",
    Icon = "wrench",
    Callback = function()
        print("\n========== PLAYER TOOLS & ATTRIBUTES ==========")
        for _, p in ipairs(Players:GetPlayers()) do
            print("Player:", p.Name)
            for k, v in pairs(p:GetAttributes()) do
                print("  Player Attr:", k, "=", v)
            end
            if p.Character then
                for _, item in ipairs(p.Character:GetChildren()) do
                    if item:IsA("Tool") then
                        print("  Equipped Tool:", item.Name)
                    end
                end
            end
            local bag = p:FindFirstChildOfClass("Backpack")
            if bag then
                for _, item in ipairs(bag:GetChildren()) do
                    if item:IsA("Tool") then
                        print("  Backpack Tool:", item.Name)
                    end
                end
            end
        end
        print("===============================================\n")
        WindUI:Notify({ Title = "Diagnostics", Content = "Player tools/attributes printed to F9 console.", Duration = 3 })
    end,
})

-- Settings & Unload
local function unload()
    Running = false
    for p in pairs(Entries) do removeEntry(p) end
    for _, conn in ipairs(Connections) do pcall(function() conn:Disconnect() end) end
    if Container then pcall(function() Container:Destroy() end) end
    pcall(function() Window:Destroy() end)
end

ENV.__BBDHub = { Unload = unload }

SettingsTab:Button({
    Title = "Unload UI",
    Icon = "power",
    Callback = unload,
})

-- RightShift / RightControl Toggle
table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gp)
    if not gp and (input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.RightControl) then
        Window:Toggle()
    end
end))

table.insert(Connections, Players.PlayerRemoving:Connect(removeEntry))

-- Background Loop
task.spawn(function()
    while Running do
        pcall(updateESP)

        if Config.WalkSpeedBoost and LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.WalkSpeed ~= Config.CustomSpeed then
                hum.WalkSpeed = Config.CustomSpeed
            end
        end

        task.wait(0.25)
    end
end)

WindUI:Notify({
    Title = "Blind but Dangerous",
    Content = "v" .. VERSION .. " loaded! Blind Man detection active.",
    Duration = 4,
})
