-- StealAnEgg - Oxio UI
-- UI mock/test build

local Library = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/starvane/alqpzm/refs/heads/main/zxasqw.lua"))()
assert(type(Library) == "table" and type(Library.CreateWindow) == "function", "Oxio Library failed to load")

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

local function set(key, value)
    state[key] = value
end

local function get(key, default)
    local value = state[key]
    if value == nil then
        return default
    end
    return value
end

local function note(title, text, duration)
    Library:Notify({
        Title = title,
        Description = text,
        Duration = duration or 2.5,
    })
end

local RARITY_NAMES = {
    "Common",
    "Uncommon",
    "Rare",
    "Epic",
    "Legendary",
    "Mythic",
    "Secret"
}

local AREA_NAMES = {
    "Base / Plot",
    "Spawn",
    "Garden",
    "Beach",
    "Forest",
    "Mountain",
    "Cave"
}

local MUTATION_FILTERS = {
    "None",
    "Gold",
    "Golden",
    "Silver",
    "Rainbow",
    "Parasite",
    "Monstrous"
}

local areaKeys = table.clone(AREA_NAMES)

local plotOptions = {
    "Plot 1",
    "Plot 2",
    "Plot 3",
    "Plot 4",
    "Plot 5",
    "Plot 6",
    "Plot 7",
    "My Plot"
}

local function playerList()
    local names = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP then
            table.insert(names, player.Name)
        end
    end

    table.sort(names)

    if #names == 0 then
        names = {"(no other players)"}
    end

    return names
end

-- =============================================================================
-- TAB 1: HOME
-- =============================================================================

local HomeTab = Window:CreateTab("Home", true, false)

local SessionMain = HomeTab:CreatePage("Session")
local SessionSec = SessionMain:CreateSection("Session")
SessionSec:AddButton("UI Status", function()
    note("Oxio Hub", "UI-only test build is running normally.")
end)

local QuickMain = HomeTab:CreatePage("Quick Actions")
local QuickSec = QuickMain:CreateSection("Quick Actions")
QuickSec:AddButton("Steal Best Available Egg Once", function()
    note("Quick Action", "Steal Best Available Egg Once")
end)
QuickSec:AddButton("Hatch All Ready Eggs Now", function()
    note("Quick Action", "Hatch All Ready Eggs Now")
end)
QuickSec:AddButton("Place Carried Eggs in Pen Now", function()
    note("Quick Action", "Place Carried Eggs in Pen Now")
end)
QuickSec:AddButton("Upgrade Base Now", function()
    note("Quick Action", "Upgrade Base Now")
end)
QuickSec:AddButton("Upgrade Treadmill Now", function()
    note("Quick Action", "Upgrade Treadmill Now")
end)
QuickSec:AddButton("Equip Best Pets Now", function()
    note("Quick Action", "Equip Best Pets Now")
end)

local OverviewMain = HomeTab:CreatePage("Overview")
local OverviewSec = OverviewMain:CreateSection("What is where")
OverviewSec:AddButton("Farm", function()
    note("Navigation", "Farm contains stealing, hatching, planting and egg tracking.")
end)
OverviewSec:AddButton("Pets", function()
    note("Navigation", "Pets contains pet management and selling.")
end)
OverviewSec:AddButton("Progress", function()
    note("Navigation", "Progress contains upgrades, events and rewards.")
end)
OverviewSec:AddButton("Player", function()
    note("Navigation", "Player contains movement, travel, combat and visuals.")
end)
OverviewSec:AddButton("System", function()
    note("Navigation", "System contains performance, configuration and about.")
end)

-- =============================================================================
-- TAB 2: FARM
-- =============================================================================

local FarmTab = Window:CreateTab("Farm", false, false)

local FarmStealPage = FarmTab:CreatePage("Steal")
local StealMain = FarmStealPage:CreateSection("Steal Eggs")

StealMain:AddToggle("Auto Steal Eggs", false, function(v)
    set("autoSteal", v)
    note("Auto Steal", v and "Enabled" or "Disabled")
end)

StealMain:AddDropdown(
    "Steal Movement Method",
    {"Tween Glide", "Fly Glide", "Safe Walk", "Instant Safe TP"},
    false,
    function(v)
        set("stealMovement", v)
    end
)

StealMain:AddToggle("Steal Infested / Parasite Eggs Only", false, function(v)
    set("parasiteOnly", v)
end)

StealMain:AddToggle("Instant Prompt Pickup", false, function(v)
    set("instantPickup", v)
end)

StealMain:AddToggle("Rare Egg Hunter (Highest Rarity First)", true, function(v)
    set("rareHunter", v)
end)

StealMain:AddDropdown(
    "Filter by Rarity (Multi-Select)",
    RARITY_NAMES,
    true,
    function(v)
        set("stealRarities", v)
    end
)

StealMain:AddDropdown(
    "Filter by Area (Multi-Select)",
    AREA_NAMES,
    true,
    function(v)
        set("stealAreas", v)
    end
)

StealMain:AddDropdown(
    "Filter by Mutation (Multi-Select)",
    MUTATION_FILTERS,
    true,
    function(v)
        set("stealMutations", v)
    end
)

StealMain:AddSlider("Glide / Travel Speed", 50, 750, 200, function(v)
    set("glideSpeed", v)
end)

StealMain:AddSlider("Steal Delay Gap", 0.5, 10, 1.5, function(v)
    set("stealDelay", v)
end)

StealMain:AddButton("Steal Best Available Egg Once", function()
    note("UI Test", "Button clicked: Steal Best Available Egg Once")
end)

local FarmHandlingPage = FarmTab:CreatePage("Egg Handling")

local HatchSec = FarmHandlingPage:CreateSection("Hatching & Planting")
HatchSec:AddToggle("Auto Hatch Ready Eggs", false, function(v)
    set("autoHatch", v)
end)

HatchSec:AddToggle("Auto Place Egg (Base Pen)", false, function(v)
    set("autoPlant", v)
end)

HatchSec:AddSlider("Hatch Check Delay", 0.5, 10, 2.0, function(v)
    set("hatchDelay", v)
end)

HatchSec:AddButton("Hatch All Ready Eggs Now", function()
    note("UI Test", "Button clicked: Hatch All Ready Eggs Now")
end)

HatchSec:AddButton("Place Carried Eggs in Pen Now", function()
    note("UI Test", "Button clicked: Place Carried Eggs in Pen Now")
end)

local EggSellSec = FarmHandlingPage:CreateSection("Egg Sales")
EggSellSec:AddToggle("Auto Sell Low-Tier Eggs", false, function(v)
    set("sellEggs", v)
end)

EggSellSec:AddDropdown(
    "Filter Egg Sell Rarities",
    RARITY_NAMES,
    true,
    function(v)
        set("sellEggRarities", v)
    end
)

EggSellSec:AddButton("Sell Selected Eggs Now", function()
    note("UI Test", "Button clicked: Sell Selected Eggs Now")
end)

local FarmEspPage = FarmTab:CreatePage("Tracker")
local EspMain = FarmEspPage:CreateSection("Egg Tracker")

EspMain:AddToggle("Egg ESP Enabled", false, function(v)
    set("eggEsp", v)
end)

EspMain:AddToggle("Show 3D Pet Image Badges", true, function(v)
    set("petBadges", v)
end)

EspMain:AddToggle("Trap ESP (Highlights Enemy Traps)", false, function(v)
    set("trapEsp", v)
end)

EspMain:AddToggle("Show Mutated / Rare Eggs Only", false, function(v)
    set("rareOnly", v)
end)

EspMain:AddSlider("Max ESP Distance", 100, 2500, 800, function(v)
    set("espDistance", v)
end)

-- =============================================================================
-- TAB 3: PETS
-- =============================================================================

local PetsTab = Window:CreateTab("Pets", false, false)

local PetsMainPage = PetsTab:CreatePage("Management")
local PetsManageSec = PetsMainPage:CreateSection("Pets")

PetsManageSec:AddToggle("Auto Equip Best Pets", false, function(v)
    set("autoBestPets", v)
end)

PetsManageSec:AddButton("Equip Best Pets Now", function()
    note("UI Test", "Button clicked: Equip Best Pets Now")
end)

local PetsSellPage = PetsTab:CreatePage("Selling")
local PetsSellSec = PetsSellPage:CreateSection("Pet Sales")

PetsSellSec:AddToggle("Auto Sell Low-Tier Pets", false, function(v)
    set("sellPets", v)
end)

PetsSellSec:AddDropdown(
    "Filter Pet Sell Rarities",
    RARITY_NAMES,
    true,
    function(v)
        set("sellPetRarities", v)
    end
)

PetsSellSec:AddButton("Sell Selected Pets Now", function()
    note("UI Test", "Button clicked: Sell Selected Pets Now")
end)

local PetsFusePage = PetsTab:CreatePage("Fuse")
local FuseSec = PetsFusePage:CreateSection("Pet Fusion")

FuseSec:AddButton("Fuse Selected Pets", function()
    note("UI Test", "Button clicked: Fuse Selected Pets")
end)

FuseSec:AddButton("Auto Fuse Duplicates", function()
    note("UI Test", "Button clicked: Auto Fuse Duplicates")
end)

-- =============================================================================
-- TAB 4: PROGRESS
-- =============================================================================

local ProgressTab = Window:CreateTab("Progress", false, false)

local ProgressUpgradePage = ProgressTab:CreatePage("Upgrades")
local UpgradesSec = ProgressUpgradePage:CreateSection("Homestead & Training")

UpgradesSec:AddToggle("Auto Upgrade Base / Plot", false, function(v)
    set("autoBase", v)
end)

UpgradesSec:AddToggle("Auto Upgrade Treadmill Tier", false, function(v)
    set("autoTreadmill", v)
end)

UpgradesSec:AddToggle("Auto Buy Speed Trails", false, function(v)
    set("autoTrails", v)
end)

UpgradesSec:AddButton("Upgrade Base Now", function()
    note("UI Test", "Button clicked: Upgrade Base Now")
end)

UpgradesSec:AddButton("Upgrade Treadmill Now", function()
    note("UI Test", "Button clicked: Upgrade Treadmill Now")
end)

local ProgressEventsPage = ProgressTab:CreatePage("Events")
local EventsSec = ProgressEventsPage:CreateSection("Monster Event")

EventsSec:AddToggle("Auto Claim Monster Chests", false, function(v)
    set("autoChests", v)
end)

EventsSec:AddToggle("Auto Feed Monster Parasite", false, function(v)
    set("autoFeed", v)
end)

EventsSec:AddButton("Claim Monster Chest Now", function()
    note("UI Test", "Button clicked: Claim Monster Chest Now")
end)

EventsSec:AddButton("Feed Monster Parasite Now", function()
    note("UI Test", "Button clicked: Feed Monster Parasite Now")
end)

local ProgressRewardsPage = ProgressTab:CreatePage("Rewards")
local RewardsSec = ProgressRewardsPage:CreateSection("Rewards")

RewardsSec:AddToggle("Auto Claim Away Earnings & Codex", false, function(v)
    set("autoRewards", v)
end)

RewardsSec:AddButton("Claim Away Earnings & Codex Now", function()
    note("UI Test", "Button clicked: Claim Away Earnings & Codex Now")
end)

-- =============================================================================
-- TAB 5: PLAYER
-- =============================================================================

local PlayerTab = Window:CreateTab("Player", false, false)

local MovementPage = PlayerTab:CreatePage("Movement")
local MoveMain = MovementPage:CreateSection("Character Movement")

MoveMain:AddToggle("Enable WalkSpeed", false, function(v)
    set("walkSpeedEnabled", v)
end)

MoveMain:AddSlider("WalkSpeed Value", 16, 10000, 24, function(v)
    set("walkSpeed", v)
end)

MoveMain:AddToggle("Enable JumpPower", false, function(v)
    set("jumpPowerEnabled", v)
end)

MoveMain:AddSlider("JumpPower Value", 50, 300, 60, function(v)
    set("jumpPower", v)
end)

MoveMain:AddToggle("Infinite Jump", false, function(v)
    set("infiniteJump", v)
end)

MoveMain:AddToggle("Smooth Fly (WASD + Space/Shift)", false, function(v)
    set("fly", v)
end)

MoveMain:AddSlider("Fly Speed", 20, 250, 60, function(v)
    set("flySpeed", v)
end)

MoveMain:AddToggle("Anti-AFK (Bypass 20min Kick)", false, function(v)
    set("antiAfk", v)
end)

local TravelPage = PlayerTab:CreatePage("Travel")

local AreaSec = TravelPage:CreateSection("Area Travel")
AreaSec:AddDropdown(
    "Select Area",
    areaKeys,
    false,
    function(v)
        set("selectedArea", v)
    end
)

AreaSec:AddButton("Travel to Selected Area", function()
    note("UI Test", "Button clicked: Travel to Selected Area")
end)

local PlotSec = TravelPage:CreateSection("Plot Travel")
PlotSec:AddDropdown(
    "Select Plot",
    plotOptions,
    false,
    function(v)
        set("selectedPlot", v)
    end
)

PlotSec:AddButton("Travel to Plot", function()
    note("UI Test", "Button clicked: Travel to Plot")
end)

local PlayerTravelSec = TravelPage:CreateSection("Player Travel")
PlayerTravelSec:AddDropdown(
    "Select Player",
    playerList(),
    false,
    function(v)
        set("selectedPlayer", v)
    end
)

PlayerTravelSec:AddTextbox("Player Name", "Enter username...", function(v)
    set("playerName", v)
end)

PlayerTravelSec:AddButton("Travel to Player", function()
    note("UI Test", "Button clicked: Travel to Player")
end)

local CombatPage = PlayerTab:CreatePage("Combat")

local BatSec = CombatPage:CreateSection("Bat / Slap Aura")
BatSec:AddToggle("Bat / Slap Aura", false, function(v)
    set("batAura", v)
end)

BatSec:AddSlider("Aura Radius", 5, 50, 20, function(v)
    set("auraRadius", v)
end)

BatSec:AddSlider("Swing Delay", 0.05, 1.0, 0.2, function(v)
    set("swingDelay", v)
end)

BatSec:AddButton("Swing Bat Once (Manual)", function()
    note("UI Test", "Button clicked: Swing Bat Once (Manual)")
end)

local GuardSec = CombatPage:CreateSection("Defense")

GuardSec:AddToggle("Anti-Trap (Full Immunity / Destroy Hitboxes)", false, function(v)
    set("antiTrap", v)
end)

GuardSec:AddToggle("No Knockback / Ragdoll Immunity", false, function(v)
    set("noKnockback", v)
end)

GuardSec:AddToggle("Anti-Ragdoll (Quick Standup)", false, function(v)
    set("antiRagdoll", v)
end)

local VisualPage = PlayerTab:CreatePage("Visuals")
local VisualSec = VisualPage:CreateSection("Visuals & Performance")

VisualSec:AddToggle("Fullbright (Daylight Visuals)", false, function(v)
    set("fullbright", v)
end)

VisualSec:AddButton("Delete Own Pet Renders (FPS Boost)", function()
    note("UI Test", "Button clicked: Delete Own Pet Renders (FPS Boost)")
end)

-- =============================================================================
-- TAB 6: SYSTEM
-- =============================================================================

local SystemTab = Window:CreateTab("System", false, false)

local ConfigPage = SystemTab:CreatePage("Configuration")
local ConfigMain = ConfigPage:CreateSection("Configuration")

ConfigMain:AddConfigManager("stealanegg_ui_test")

ConfigMain:AddButton("Toggle UI (Right Control)", function()
    local gui = Window.MainFrame and Window.MainFrame.Parent

    if gui and gui:IsA("ScreenGui") then
        gui.Enabled = not gui.Enabled
    end
end)

ConfigMain:AddButton("Unload UI", function()
    local gui = Window.MainFrame and Window.MainFrame.Parent

    if gui then
        gui:Destroy()
    end
end)

local PerfPage = SystemTab:CreatePage("Performance")
local PerfMain = PerfPage:CreateSection("Performance")

PerfMain:AddButton("Performance Test", function()
    note("Performance", "UI performance controls are currently mock-only.")
end)

local AboutPage = SystemTab:CreatePage("About")
local AboutMain = AboutPage:CreateSection("About Oxio Hub")

AboutMain:AddButton("About Oxio Hub", function()
    note(
        "Oxio Hub",
        "UI-only test build • gameplay logic intentionally removed",
        4
    )
end)

AboutMain:AddButton("Library Info", function()
    note(
        "Oxio UI",
        "Oxio UI Library • feature grouping",
        4
    )
end)

-- =============================================================================
-- KEYBIND
-- =============================================================================

UIS.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end

    if input.KeyCode == Enum.KeyCode.RightControl then
        local gui = Window.MainFrame and Window.MainFrame.Parent

        if gui and gui:IsA("ScreenGui") then
            gui.Enabled = not gui.Enabled
        end
    end
end)

print("[StealAnEgg] Oxio UI test loaded")
