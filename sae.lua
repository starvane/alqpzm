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

-- =============================================================================
-- STATE / HELPERS
-- =============================================================================

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

local function addPlaceholderButton(section, title)
    section:AddButton(title, function()
        note("UI Test", "Button clicked: " .. title)
    end)
end

-- =============================================================================
-- TAB 1: HOME
-- One page -> Session / Account / Quick Actions / Quick Start
-- =============================================================================

local HomeTab = Window:CreateTab("Home", true, false)
local HomePage = HomeTab:CreatePage("Home")

local SessionSec = HomePage:CreateSection("Session")
SessionSec:AddButton("Automation Status", function()
    note("Session", "UI-only test build is running.")
end)
SessionSec:AddButton("Current Job", function()
    note("Session", "Current server/session status is mock-only.")
end)
SessionSec:AddButton("Runtime", function()
    note("Session", "Runtime display is mock-only.")
end)

local AccountSec = HomePage:CreateSection("Account")
AccountSec:AddButton("Egg Inventory", function()
    note("Account", "Egg inventory information is mock-only.")
end)
AccountSec:AddButton("Money", function()
    note("Account", "Money information is mock-only.")
end)
AccountSec:AddButton("Pets Owned", function()
    note("Account", "Pet count information is mock-only.")
end)
AccountSec:AddButton("Rebirths", function()
    note("Account", "Rebirth information is mock-only.")
end)

local QuickSec = HomePage:CreateSection("Quick Actions")
QuickSec:AddButton("Steal Best Available Egg Once", function()
    note("Quick Action", "Button clicked: Steal Best Available Egg Once")
end)
QuickSec:AddButton("Hatch All Ready Eggs Now", function()
    note("Quick Action", "Button clicked: Hatch All Ready Eggs Now")
end)
QuickSec:AddButton("Place Carried Eggs in Pen Now", function()
    note("Quick Action", "Button clicked: Place Carried Eggs in Pen Now")
end)
QuickSec:AddButton("Upgrade Base Now", function()
    note("Quick Action", "Button clicked: Upgrade Base Now")
end)
QuickSec:AddButton("Equip Best Pets Now", function()
    note("Quick Action", "Button clicked: Equip Best Pets Now")
end)
QuickSec:AddButton("Server Hop Now", function()
    note("Quick Action", "Button clicked: Server Hop Now")
end)

local HelpSec = HomePage:CreateSection("Quick Start")
HelpSec:AddButton("Farm", function()
    note("Quick Start", "Use Farm for stealing, egg handling and server-hop controls.")
end)
HelpSec:AddButton("Pets", function()
    note("Quick Start", "Use Pets for pet fusion and selling.")
end)
HelpSec:AddButton("Progress", function()
    note("Quick Start", "Use Progress for upgrades, rewards, equipment and training.")
end)
HelpSec:AddButton("Player", function()
    note("Quick Start", "Use Player for ESP, movement and teleports.")
end)
HelpSec:AddButton("System", function()
    note("Quick Start", "Use System for session, performance, webhooks and about.")
end)

-- =============================================================================
-- TAB 2: FARM
-- One page -> Steal Eggs / Egg Handling / Server Hop / Task Order
-- =============================================================================

local FarmTab = Window:CreateTab("Farm", false, false)
local FarmPage = FarmTab:CreatePage("Farm")

local StealSec = FarmPage:CreateSection("Steal Eggs")
StealSec:AddToggle("Auto Steal Eggs", false, function(v)
    set("autoSteal", v)
    note("Auto Steal", v and "Enabled" or "Disabled")
end)

StealSec:AddDropdown(
    "Steal Movement Method",
    {"Tween Glide", "Fly Glide", "Safe Walk", "Instant Safe TP"},
    false,
    function(v)
        set("stealMovement", v)
    end
)

StealSec:AddToggle("Steal Infested / Parasite Eggs Only", false, function(v)
    set("parasiteOnly", v)
end)

StealSec:AddToggle("Instant Prompt Pickup", false, function(v)
    set("instantPickup", v)
end)

StealSec:AddToggle("Rare Egg Hunter (Highest Rarity First)", true, function(v)
    set("rareHunter", v)
end)

StealSec:AddDropdown(
    "Filter by Rarity (Multi-Select)",
    RARITY_NAMES,
    true,
    function(v)
        set("stealRarities", v)
    end
)

StealSec:AddDropdown(
    "Filter by Area (Multi-Select)",
    AREA_NAMES,
    true,
    function(v)
        set("stealAreas", v)
    end
)

StealSec:AddDropdown(
    "Filter by Mutation (Multi-Select)",
    MUTATION_FILTERS,
    true,
    function(v)
        set("stealMutations", v)
    end
)

StealSec:AddSlider("Glide / Travel Speed", 50, 750, 200, function(v)
    set("glideSpeed", v)
end)

StealSec:AddSlider("Steal Delay Gap", 0.5, 10, 1.5, function(v)
    set("stealDelay", v)
end)

StealSec:AddButton("Steal Best Available Egg Once", function()
    note("UI Test", "Button clicked: Steal Best Available Egg Once")
end)

local HandlingSec = FarmPage:CreateSection("Egg Handling")
HandlingSec:AddToggle("Auto Hatch Ready Eggs", false, function(v)
    set("autoHatch", v)
end)

HandlingSec:AddToggle("Auto Place Egg (Base Pen)", false, function(v)
    set("autoPlant", v)
end)

HandlingSec:AddSlider("Hatch Check Delay", 0.5, 10, 2.0, function(v)
    set("hatchDelay", v)
end)

HandlingSec:AddButton("Hatch All Ready Eggs Now", function()
    note("UI Test", "Button clicked: Hatch All Ready Eggs Now")
end)

HandlingSec:AddButton("Place Carried Eggs in Pen Now", function()
    note("UI Test", "Button clicked: Place Carried Eggs in Pen Now")
end)

HandlingSec:AddToggle("Auto Sell Low-Tier Eggs", false, function(v)
    set("sellEggs", v)
end)

HandlingSec:AddDropdown(
    "Filter Egg Sell Rarities",
    RARITY_NAMES,
    true,
    function(v)
        set("sellEggRarities", v)
    end
)

HandlingSec:AddButton("Sell Selected Eggs Now", function()
    note("UI Test", "Button clicked: Sell Selected Eggs Now")
end)

local ServerSec = FarmPage:CreateSection("Server Hop")
ServerSec:AddToggle("Auto Server Hop", false, function(v)
    set("autoServerHop", v)
end)

ServerSec:AddDropdown(
    "Hop Condition",
    {"No Matching Eggs", "Timed Interval", "After Steal Count"},
    false,
    function(v)
        set("hopCondition", v)
    end
)

ServerSec:AddSlider("Hop Delay", 1, 200, 15, function(v)
    set("hopDelay", v)
end)

ServerSec:AddButton("Hop to New Server", function()
    note("UI Test", "Button clicked: Hop to New Server")
end)

local TaskSec = FarmPage:CreateSection("Task Order")
TaskSec:AddDropdown(
    "Priority Slot 1",
    {"Auto Steal", "Auto Place", "Auto Hatch", "Auto Treadmill"},
    false,
    function(v)
        set("priority1", v)
    end
)

TaskSec:AddDropdown(
    "Priority Slot 2",
    {"Auto Steal", "Auto Place", "Auto Hatch", "Auto Treadmill"},
    false,
    function(v)
        set("priority2", v)
    end
)

TaskSec:AddDropdown(
    "Priority Slot 3",
    {"Auto Steal", "Auto Place", "Auto Hatch", "Auto Treadmill"},
    false,
    function(v)
        set("priority3", v)
    end
)

-- =============================================================================
-- TAB 3: PETS
-- One page -> Auto Fuse / Auto Sell Pets
-- =============================================================================

local PetsTab = Window:CreateTab("Pets", false, false)
local PetsPage = PetsTab:CreatePage("Pets")

local FuseSec = PetsPage:CreateSection("Auto Fuse")
FuseSec:AddToggle("Auto Fuse Duplicate Pets", false, function(v)
    set("autoFuse", v)
end)

FuseSec:AddDropdown(
    "Fuse Target Priority",
    {"Highest Rarity", "Lowest Rarity", "Most Duplicates"},
    false,
    function(v)
        set("fusePriority", v)
    end
)

FuseSec:AddToggle("Fuse Only Selected Rarities", false, function(v)
    set("fuseSelected", v)
end)

FuseSec:AddDropdown(
    "Fuse Rarities",
    RARITY_NAMES,
    true,
    function(v)
        set("fuseRarities", v)
    end
)

FuseSec:AddButton("Fuse Selected Pets Now", function()
    note("UI Test", "Button clicked: Fuse Selected Pets Now")
end)

local SellPetsSec = PetsPage:CreateSection("Auto Sell Pets")
SellPetsSec:AddToggle("Auto Sell Low-Tier Pets", false, function(v)
    set("sellPets", v)
end)

SellPetsSec:AddDropdown(
    "Filter Pet Sell Rarities",
    RARITY_NAMES,
    true,
    function(v)
        set("sellPetRarities", v)
    end
)

SellPetsSec:AddButton("Sell Selected Pets Now", function()
    note("UI Test", "Button clicked: Sell Selected Pets Now")
end)

-- =============================================================================
-- TAB 4: PROGRESS
-- One page -> Upgrades / Rewards / Equipment / Training
-- =============================================================================

local ProgressTab = Window:CreateTab("Progress", false, false)
local ProgressPage = ProgressTab:CreatePage("Progress")

local UpgradeSec = ProgressPage:CreateSection("Upgrades")
UpgradeSec:AddToggle("Auto Upgrade Base / Plot", false, function(v)
    set("autoBase", v)
end)

UpgradeSec:AddToggle("Auto Upgrade Treadmill Tier", false, function(v)
    set("autoTreadmill", v)
end)

UpgradeSec:AddToggle("Auto Buy Speed Trails", false, function(v)
    set("autoTrails", v)
end)

UpgradeSec:AddButton("Upgrade Base Now", function()
    note("UI Test", "Button clicked: Upgrade Base Now")
end)

UpgradeSec:AddButton("Upgrade Treadmill Now", function()
    note("UI Test", "Button clicked: Upgrade Treadmill Now")
end)

local RewardsSec = ProgressPage:CreateSection("Rewards")
RewardsSec:AddToggle("Auto Claim Away Earnings & Codex", false, function(v)
    set("autoRewards", v)
end)

RewardsSec:AddToggle("Auto Claim Monster Chests", false, function(v)
    set("autoChests", v)
end)

RewardsSec:AddButton("Claim Away Earnings & Codex Now", function()
    note("UI Test", "Button clicked: Claim Away Earnings & Codex Now")
end)

RewardsSec:AddButton("Claim Monster Chest Now", function()
    note("UI Test", "Button clicked: Claim Monster Chest Now")
end)

RewardsSec:AddButton("Feed Monster Parasite Now", function()
    note("UI Test", "Button clicked: Feed Monster Parasite Now")
end)

local EquipmentSec = ProgressPage:CreateSection("Equipment")
EquipmentSec:AddToggle("Auto Equip Best Pets", false, function(v)
    set("autoBestPets", v)
end)

EquipmentSec:AddButton("Equip Best Pets Now", function()
    note("UI Test", "Button clicked: Equip Best Pets Now")
end)

EquipmentSec:AddButton("Equipment / Gear Upgrade", function()
    note("UI Test", "Button clicked: Equipment / Gear Upgrade")
end)

local TrainingSec = ProgressPage:CreateSection("Training")
TrainingSec:AddToggle("Enable Treadmill Training", false, function(v)
    set("training", v)
end)

TrainingSec:AddToggle("Auto Upgrade Treadmill Tier", false, function(v)
    set("autoTreadmillTraining", v)
end)

TrainingSec:AddSlider("Training Speed", 1, 1000, 60, function(v)
    set("trainingSpeed", v)
end)

TrainingSec:AddButton("Start Training Now", function()
    note("UI Test", "Button clicked: Start Training Now")
end)

-- =============================================================================
-- TAB 5: PLAYER
-- One page -> ESP / Movement / Teleports
-- =============================================================================

local PlayerTab = Window:CreateTab("Player", false, false)
local PlayerPage = PlayerTab:CreatePage("Player")

local EspSec = PlayerPage:CreateSection("ESP")
EspSec:AddToggle("Egg ESP Enabled", false, function(v)
    set("eggEsp", v)
end)

EspSec:AddToggle("Show 3D Pet Image Badges", true, function(v)
    set("petBadges", v)
end)

EspSec:AddToggle("Trap ESP (Highlights Enemy Traps)", false, function(v)
    set("trapEsp", v)
end)

EspSec:AddToggle("Show Mutated / Rare Eggs Only", false, function(v)
    set("rareOnly", v)
end)

EspSec:AddSlider("Max ESP Distance", 100, 2500, 800, function(v)
    set("espDistance", v)
end)

local MovementSec = PlayerPage:CreateSection("Movement")
MovementSec:AddToggle("Enable WalkSpeed", false, function(v)
    set("walkSpeedEnabled", v)
end)

MovementSec:AddSlider("WalkSpeed Value", 16, 10000, 24, function(v)
    set("walkSpeed", v)
end)

MovementSec:AddToggle("Enable JumpPower", false, function(v)
    set("jumpPowerEnabled", v)
end)

MovementSec:AddSlider("JumpPower Value", 50, 300, 60, function(v)
    set("jumpPower", v)
end)

MovementSec:AddToggle("Infinite Jump", false, function(v)
    set("infiniteJump", v)
end)

MovementSec:AddToggle("Smooth Fly (WASD + Space/Shift)", false, function(v)
    set("fly", v)
end)

MovementSec:AddSlider("Fly Speed", 20, 250, 60, function(v)
    set("flySpeed", v)
end)

MovementSec:AddToggle("Anti-AFK (Bypass 20min Kick)", false, function(v)
    set("antiAfk", v)
end)

local TeleportSec = PlayerPage:CreateSection("Teleports")

TeleportSec:AddDropdown(
    "Select Area",
    areaKeys,
    false,
    function(v)
        set("selectedArea", v)
    end
)

TeleportSec:AddButton("Travel to Selected Area", function()
    note("UI Test", "Button clicked: Travel to Selected Area")
end)

TeleportSec:AddDropdown(
    "Select Plot",
    plotOptions,
    false,
    function(v)
        set("selectedPlot", v)
    end
)

TeleportSec:AddButton("Travel to Plot", function()
    note("UI Test", "Button clicked: Travel to Plot")
end)

TeleportSec:AddDropdown(
    "Select Player",
    playerList(),
    false,
    function(v)
        set("selectedPlayer", v)
    end
)

TeleportSec:AddTextbox("Player Name", "Enter username...", function(v)
    set("playerName", v)
end)

TeleportSec:AddButton("Travel to Player", function()
    note("UI Test", "Button clicked: Travel to Player")
end)

-- =============================================================================
-- TAB 6: SYSTEM
-- One page -> Session / Performance / Webhooks / About
-- =============================================================================

local SystemTab = Window:CreateTab("System", false, false)
local SystemPage = SystemTab:CreatePage("System")

local SystemSessionSec = SystemPage:CreateSection("Session")
SystemSessionSec:AddButton("Toggle UI (Right Control)", function()
    local gui = Window.MainFrame and Window.MainFrame.Parent

    if gui and gui:IsA("ScreenGui") then
        gui.Enabled = not gui.Enabled
    end
end)

SystemSessionSec:AddButton("Refresh Player List", function()
    note("System", "Player list refresh is mock-only in this UI test.")
end)

local PerformanceSec = SystemPage:CreateSection("Performance")
PerformanceSec:AddToggle("Fullbright (Daylight Visuals)", false, function(v)
    set("fullbright", v)
end)

PerformanceSec:AddButton("Delete Own Pet Renders (FPS Boost)", function()
    note("UI Test", "Button clicked: Delete Own Pet Renders (FPS Boost)")
end)

PerformanceSec:AddButton("Performance Test", function()
    note("Performance", "Performance controls are currently mock-only.")
end)

local WebhookSec = SystemPage:CreateSection("Webhooks")
WebhookSec:AddToggle("Enable Webhooks", false, function(v)
    set("webhooks", v)
end)

WebhookSec:AddTextbox("Webhook URL", "https://discord.com/api/webhooks/...", function(v)
    set("webhookUrl", v)
end)

WebhookSec:AddTextbox("Ping User ID", "123456789012345678", function(v)
    set("webhookPingId", v)
end)

WebhookSec:AddSlider("Summary Interval", 1, 180, 15, function(v)
    set("webhookInterval", v)
end)

WebhookSec:AddToggle("List Spawned Eggs", true, function(v)
    set("webhookEggSpawns", v)
end)

WebhookSec:AddToggle("Disconnect Alerts", false, function(v)
    set("webhookDisconnect", v)
end)

WebhookSec:AddButton("Send Summary Now", function()
    note("Webhook", "Button clicked: Send Summary Now")
end)

local AboutSec = SystemPage:CreateSection("About")
AboutSec:AddButton("About Oxio Hub", function()
    note(
        "Oxio Hub",
        "UI-only test build • gameplay logic intentionally removed",
        4
    )
end)

AboutSec:AddButton("UI Library", function()
    note("Oxio UI", "Oxio UI Library")
end)

AboutSec:AddButton("Script Info", function()
    note("StealAnEgg", "single-page tab layout")
end)

AboutSec:AddButton("Unload UI", function()
    local gui = Window.MainFrame and Window.MainFrame.Parent

    if gui then
        gui:Destroy()
    end
end)

-- =============================================================================
-- RIGHT CONTROL
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
