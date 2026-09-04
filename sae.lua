-- StealAnEgg - ZyronX UI
-- UI mock/test build

local Library = loadstring(game:HttpGetAsync("https://pastefy.app/YoX4PJmf/raw"))()
assert(type(Library) == "table" and type(Library.CreateWindow) == "function", "ZyronX Library failed to load")

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

local Window = Library:CreateWindow({
    Title = "Oxio Hub",
    Subtitle = "Steal An Egg",
    SubtitleColor = Color3.fromRGB(190, 140, 255),
    Logo = "rbxassetid://98140353767645",
    LogoSize = 32,
    SphereText = false,
    SphereImage = "rbxassetid://98140353767645",
    SphereIconSize = 38,
})

-- Dummy state so callbacks do not depend on the gameplay script.
local state = {}
local function set(key, value) state[key] = value end
local function get(key, default) local v = state[key]; if v == nil then return default end; return v end
local function note(title, text, duration)
    pcall(function()
        Library:Notify({
            Title = title,
            Description = text,
            Duration = duration or 2.5,
        })
    end)
end

local RARITY_NAMES = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"}
local AREA_NAMES = {"Base / Plot", "Spawn", "Garden", "Beach", "Forest", "Mountain", "Cave"}
local MUTATION_FILTERS = {"None", "Gold", "Golden", "Silver", "Rainbow", "Parasite", "Monstrous"}
local areaKeys = table.clone(AREA_NAMES)
local plotOptions = {"Plot 1", "Plot 2", "Plot 3", "Plot 4", "Plot 5", "Plot 6", "Plot 7", "My Plot"}

local function playerList()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then table.insert(names, p.Name) end
    end
    table.sort(names)
    if #names == 0 then names = {"(no other players)"} end
    return names
end

-- =============================================================================
-- TAB 1: EGGS
-- =============================================================================
local EggsTab = Window:CreateTab("Eggs", true, false)

local StealPage = EggsTab:CreatePage("Auto Steal")
local StealMain = StealPage:CreateSection("Egg Stealing")
StealMain:AddToggle("Auto Steal Eggs", false, function(v) set("autoSteal", v); note("Auto Steal", v and "Enabled" or "Disabled", v and "Success" or "Error") end)
StealMain:AddDropdown("Steal Movement Method", {"Tween Glide", "Fly Glide", "Safe Walk", "Instant Safe TP"}, false, function(v) set("stealMovement", v) end)
StealMain:AddToggle("Steal Infested / Parasite Eggs Only", false, function(v) set("parasiteOnly", v) end)
StealMain:AddToggle("Instant Prompt Pickup", false, function(v) set("instantPickup", v) end)
StealMain:AddToggle("Rare Egg Hunter (Highest Rarity First)", true, function(v) set("rareHunter", v) end)
StealMain:AddDropdown("Filter by Rarity (Multi-Select)", RARITY_NAMES, true, function(v) set("stealRarities", v) end)
StealMain:AddDropdown("Filter by Area (Multi-Select)", AREA_NAMES, true, function(v) set("stealAreas", v) end)
StealMain:AddDropdown("Filter by Mutation (Multi-Select)", MUTATION_FILTERS, true, function(v) set("stealMutations", v) end)
StealMain:AddSlider("Glide / Travel Speed", 50, 750, 200, function(v) set("glideSpeed", v) end)
StealMain:AddSlider("Steal Delay Gap", 0.5, 10, 1.5, function(v) set("stealDelay", v) end)
StealMain:AddButton("Steal Best Available Egg Once", function() note("UI Test", "Button clicked: Steal Best Available Egg Once", "Info") end)

local HatchPage = EggsTab:CreatePage("Auto Hatch & Plant")
local HatchMain = HatchPage:CreateSection("Hatching & Planting")
HatchMain:AddToggle("Auto Hatch Ready Eggs", false, function(v) set("autoHatch", v) end)
HatchMain:AddToggle("Auto Place Egg (Base Pen)", false, function(v) set("autoPlant", v) end)
HatchMain:AddSlider("Hatch Check Delay", 0.5, 10, 2.0, function(v) set("hatchDelay", v) end)
HatchMain:AddButton("Hatch All Ready Eggs Now", function() note("UI Test", "Button clicked: Hatch All Ready Eggs Now", "Info") end)
HatchMain:AddButton("Place Carried Eggs in Pen Now", function() note("UI Test", "Button clicked: Place Carried Eggs in Pen Now", "Info") end)

local EspPage = EggsTab:CreatePage("Egg Tracker ESP")
local EspMain = EspPage:CreateSection("Egg Tracker")
EspMain:AddToggle("Egg ESP Enabled", false, function(v) set("eggEsp", v) end)
EspMain:AddToggle("Show 3D Pet Image Badges", true, function(v) set("petBadges", v) end)
EspMain:AddToggle("Trap ESP (Highlights Enemy Traps)", false, function(v) set("trapEsp", v) end)
EspMain:AddToggle("Show Mutated / Rare Eggs Only", false, function(v) set("rareOnly", v) end)
EspMain:AddSlider("Max ESP Distance", 100, 2500, 800, function(v) set("espDistance", v) end)

-- =============================================================================
-- TAB 2: BASE
-- =============================================================================
local BaseTab = Window:CreateTab("Base", false, false)

local UpgradesPage = BaseTab:CreatePage("Homestead & Treadmill")
local UpgradesMain = UpgradesPage:CreateSection("Homestead & Training")
UpgradesMain:AddToggle("Auto Upgrade Base / Plot", false, function(v) set("autoBase", v) end)
UpgradesMain:AddToggle("Auto Upgrade Treadmill Tier", false, function(v) set("autoTreadmill", v) end)
UpgradesMain:AddToggle("Auto Buy Speed Trails", false, function(v) set("autoTrails", v) end)
UpgradesMain:AddButton("Upgrade Base Now", function() note("UI Test", "Button clicked: Upgrade Base Now", "Info") end)
UpgradesMain:AddButton("Upgrade Treadmill Now", function() note("UI Test", "Button clicked: Upgrade Treadmill Now", "Info") end)

local PetsPage = BaseTab:CreatePage("Pets & Satchel")
local PetsMain = PetsPage:CreateSection("Pets")
PetsMain:AddToggle("Auto Equip Best Pets", false, function(v) set("autoBestPets", v) end)
PetsMain:AddButton("Equip Best Pets Now", function() note("UI Test", "Button clicked: Equip Best Pets Now", "Info") end)

local SalesPage = BaseTab:CreatePage("Auto Sell")
local SalesMain = SalesPage:CreateSection("Pet Sales")
SalesMain:AddToggle("Auto Sell Low-Tier Pets", false, function(v) set("sellPets", v) end)
SalesMain:AddDropdown("Filter Pet Sell Rarities", RARITY_NAMES, true, function(v) set("sellPetRarities", v) end)
SalesMain:AddButton("Sell Selected Pets Now", function() note("UI Test", "Button clicked: Sell Selected Pets Now", "Info") end)
local SalesEggs = SalesPage:CreateSection("Egg Sales")
SalesEggs:AddToggle("Auto Sell Low-Tier Eggs", false, function(v) set("sellEggs", v) end)
SalesEggs:AddDropdown("Filter Egg Sell Rarities", RARITY_NAMES, true, function(v) set("sellEggRarities", v) end)
SalesEggs:AddButton("Sell Selected Eggs Now", function() note("UI Test", "Button clicked: Sell Selected Eggs Now", "Info") end)

local EventsPage = BaseTab:CreatePage("Events & Bosses")
local EventsMain = EventsPage:CreateSection("Monster Event")
EventsMain:AddToggle("Auto Claim Monster Chests", false, function(v) set("autoChests", v) end)
EventsMain:AddToggle("Auto Feed Monster Parasite", false, function(v) set("autoFeed", v) end)
EventsMain:AddButton("Claim Monster Chest Now", function() note("UI Test", "Button clicked: Claim Monster Chest Now", "Info") end)
EventsMain:AddButton("Feed Monster Parasite Now", function() note("UI Test", "Button clicked: Feed Monster Parasite Now", "Info") end)

local RewardsPage = BaseTab:CreatePage("Claim Rewards")
local RewardsMain = RewardsPage:CreateSection("Rewards")
RewardsMain:AddToggle("Auto Claim Away Earnings & Codex", false, function(v) set("autoRewards", v) end)
RewardsMain:AddButton("Claim Away Earnings & Codex Now", function() note("UI Test", "Button clicked: Claim Away Earnings & Codex Now", "Info") end)

-- =============================================================================
-- TAB 3: COMBAT
-- =============================================================================
local CombatTab = Window:CreateTab("Combat", false, false)
local BatPage = CombatTab:CreatePage("Bat & Slap Aura")
local BatMain = BatPage:CreateSection("Bat / Slap Aura")
BatMain:AddToggle("Bat / Slap Aura", false, function(v) set("batAura", v) end)
BatMain:AddSlider("Aura Radius", 5, 50, 20, function(v) set("auraRadius", v) end)
BatMain:AddSlider("Swing Delay", 0.05, 1.0, 0.2, function(v) set("swingDelay", v) end)
BatMain:AddButton("Swing Bat Once (Manual)", function() note("UI Test", "Button clicked: Swing Bat Once (Manual)", "Info") end)

local GuardPage = CombatTab:CreatePage("Defense & Guards")
local GuardMain = GuardPage:CreateSection("Defense")
GuardMain:AddToggle("Anti-Trap (Full Immunity / Destroy Hitboxes)", false, function(v) set("antiTrap", v) end)
GuardMain:AddToggle("No Knockback / Ragdoll Immunity", false, function(v) set("noKnockback", v) end)
GuardMain:AddToggle("Anti-Ragdoll (Quick Standup)", false, function(v) set("antiRagdoll", v) end)

-- =============================================================================
-- TAB 4: PLAYER
-- =============================================================================
local PlayerTab = Window:CreateTab("Player", false, false)
local MovePage = PlayerTab:CreatePage("Movement")
local MoveMain = MovePage:CreateSection("Character Movement")
MoveMain:AddToggle("Enable WalkSpeed", false, function(v) set("walkSpeedEnabled", v) end)
MoveMain:AddSlider("WalkSpeed Value", 16, 10000, 24, function(v) set("walkSpeed", v) end)
MoveMain:AddToggle("Enable JumpPower", false, function(v) set("jumpPowerEnabled", v) end)
MoveMain:AddSlider("JumpPower Value", 50, 300, 60, function(v) set("jumpPower", v) end)
MoveMain:AddToggle("Infinite Jump", false, function(v) set("infiniteJump", v) end)
MoveMain:AddToggle("Smooth Fly (WASD + Space/Shift)", false, function(v) set("fly", v) end)
MoveMain:AddSlider("Fly Speed", 20, 250, 60, function(v) set("flySpeed", v) end)
MoveMain:AddToggle("Anti-AFK (Bypass 20min Kick)", false, function(v) set("antiAfk", v) end)

local AreaPage = PlayerTab:CreatePage("Area Travel")
local AreaMain = AreaPage:CreateSection("Area Travel")
AreaMain:AddDropdown("Select Area", areaKeys, false, function(v) set("selectedArea", v) end)
AreaMain:AddButton("Travel to Selected Area", function() note("UI Test", "Button clicked: Travel to Selected Area", "Info") end)

local PlotPage = PlayerTab:CreatePage("Plot Travel")
local PlotMain = PlotPage:CreateSection("Plot Travel")
PlotMain:AddDropdown("Select Plot", plotOptions, false, function(v) set("selectedPlot", v) end)
PlotMain:AddButton("Travel to Plot", function() note("UI Test", "Button clicked: Travel to Plot", "Info") end)

local PlayerTravelPage = PlayerTab:CreatePage("Player Travel")
local PlayerTravelMain = PlayerTravelPage:CreateSection("Player Travel")
PlayerTravelMain:AddDropdown("Select Player", playerList(), false, function(v) set("selectedPlayer", v) end)
PlayerTravelMain:AddTextbox("Player Name", "Enter username...", function(v) set("playerName", v) end)
PlayerTravelMain:AddButton("Travel to Player", function() note("UI Test", "Button clicked: Travel to Player", "Info") end)

local PerfPage = PlayerTab:CreatePage("Visuals & Performance")
local PerfMain = PerfPage:CreateSection("Visuals & Performance")
PerfMain:AddToggle("Fullbright (Daylight Visuals)", false, function(v) set("fullbright", v) end)
PerfMain:AddButton("Delete Own Pet Renders (FPS Boost)", function() note("UI Test", "Button clicked: Delete Own Pet Renders (FPS Boost)", "Info") end)

-- =============================================================================
-- TAB 5: SETTINGS
-- =============================================================================
local SettingsTab = Window:CreateTab("Settings", false, false)
local ConfigPage = SettingsTab:CreatePage("Configuration")
local ConfigMain = ConfigPage:CreateSection("Configuration")
ConfigMain:AddConfigManager("stealanegg_ui_test")
ConfigMain:AddButton("Toggle UI (Right Control)", function()
    local gui = Window.MainFrame and Window.MainFrame.Parent
    if gui and gui:IsA("ScreenGui") then gui.Enabled = not gui.Enabled end
end)
ConfigMain:AddButton("Unload UI", function()
    pcall(function() Window:Destroy() end)
end)
ConfigMain:AddButton("About Oxio Hub", function()
    note("Oxio Hub", "UI-only test build • gameplay logic intentionally removed", "Info", 4)
end)

UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightControl then
        local gui = Window.MainFrame and Window.MainFrame.Parent
        if gui and gui:IsA("ScreenGui") then gui.Enabled = not gui.Enabled end
    end
end)

print("[StealAnEgg] ZyronX UI test loaded")
