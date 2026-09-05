-- StealAnEgg - Oxio UI
-- UI mock/test build
-- Gameplay logic intentionally removed; every control below is dummy/UI-only.

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
-- DUMMY STATE / HELPERS
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

local function testToggle(key, title)
    return function(value)
        set(key, value)
    end
end

local function testButton(title)
    return function()
        note("UI Test", "Button clicked: " .. title)
    end
end

local RARITY_NAMES = {
    "Common",
    "Uncommon",
    "Rare",
    "Epic",
    "Legendary",
    "Mythic",
    "Cosmic",
    "Secret",
    "Eternal",
    "Divine"
}

local MUTATION_NAMES = {
    "Golden",
    "Rainbow",
    "Silver"
}

local STEAL_PRIORITIES = {
    "Rarest",
    "Nearest",
    "Furthest",
    "Biggest Size"
}

local FUSE_TARGET_MODES = {
    "Highest Rarity",
    "Lowest Rarity",
    "Most Duplicates"
}

local UPGRADE_TYPES = {
    "Base",
    "Treadmill"
}

local PRIORITY_TASK_NAMES = {
    "Auto Steal Egg",
    "Auto Place Egg",
    "Auto Hatch",
    "Auto Treadmill"
}

local SERVER_HOP_MODES = {
    "No Matching Eggs",
    "Timed Interval",
    "After Steal Count"
}

local AREA_NAMES = {
    "Forest",
    "Lake",
    "Desert",
    "Jungle",
    "Snow",
    "Volcano",
    "Abyss Ocean",
    "Prehistoric",
    "Cosmic"
}

local WAYPOINT_NAMES = {
    "Base",
    "Forest",
    "Lake",
    "Desert",
    "Jungle",
    "Snow",
    "Volcano",
    "Abyss Ocean",
    "Prehistoric",
    "Cosmic"
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
-- HOME
-- Session / Account / Quick Actions / Quick Start
-- =============================================================================

local HomeTab = Window:CreateTab("Home", true, false)
local HomePage = HomeTab:CreatePage("Home")

local SessionSec = HomePage:CreateSection("Session")

SessionSec:AddButton("Automation: Ready", testButton("Automation: Ready"))
SessionSec:AddButton("Current Job: Idle", testButton("Current Job: Idle"))
SessionSec:AddButton("Stolen Eggs: 0", testButton("Stolen Eggs: 0"))
SessionSec:AddButton("Carrying Egg: No", testButton("Carrying Egg: No"))
SessionSec:AddButton("Runtime: 0m", testButton("Runtime: 0m"))
SessionSec:AddButton("Server: Session", testButton("Server: Session"))

local AccountSec = HomePage:CreateSection("Account")

AccountSec:AddButton("Egg Inventory: 0 / 100", testButton("Egg Inventory"))
AccountSec:AddButton("Money: 0", testButton("Money"))
AccountSec:AddButton("Speed Power: 0", testButton("Speed Power"))
AccountSec:AddButton("Rebirths: 0", testButton("Rebirths"))
AccountSec:AddButton("Pets Owned: 0", testButton("Pets Owned"))

local QuickSec = HomePage:CreateSection("Quick Actions")

QuickSec:AddButton("Return to Base", testButton("Return to Base"))
QuickSec:AddButton("Place Eggs", testButton("Place Eggs"))
QuickSec:AddButton("Server Hop", testButton("Server Hop"))
QuickSec:AddButton("Fuse Now", testButton("Fuse Now"))

local HelpSec = HomePage:CreateSection("Quick Start")

HelpSec:AddButton("Farm Flow", testButton("Farm Flow"))
HelpSec:AddButton("Filters", testButton("Filters"))

-- =============================================================================
-- FARM
-- Steal Eggs / Egg Handling / Server Hop / Task Order
-- =============================================================================

local FarmTab = Window:CreateTab("Farm", false, false)
local FarmPage = FarmTab:CreatePage("Farm")

local StealSec = FarmPage:CreateSection("Steal Eggs")

StealSec:AddToggle("Auto Steal Selected", false, testToggle("AutoStealSelected"))
StealSec:AddToggle("Auto Steal All", false, testToggle("AutoStealAll"))
StealSec:AddToggle("Steal Big Eggs", false, testToggle("StealBigEggs"))

StealSec:AddDropdown(
    "Areas",
    AREA_NAMES,
    true,
    function(v)
        set("StealZones", v)
    end
)

StealSec:AddDropdown(
    "Rarities",
    RARITY_NAMES,
    true,
    function(v)
        set("StealRarities", v)
    end
)

StealSec:AddDropdown(
    "Mutations",
    MUTATION_NAMES,
    true,
    function(v)
        set("StealMutations", v)
    end
)

StealSec:AddDropdown(
    "Target Priority",
    STEAL_PRIORITIES,
    false,
    function(v)
        set("StealPriority", v)
    end
)

StealSec:AddSlider("Steal Speed", 50, 1000, 300, function(v)
    set("StealSpeed", v)
end)

StealSec:AddSlider("Minimum Big Egg Size", 1, 50, 1.5, function(v)
    set("StealBigEggScale", v)
end)

StealSec:AddToggle("Auto Return to Base", true, testToggle("AutoReturn"))
StealSec:AddToggle("Auto Drop Held Egg", false, testToggle("AutoDropEgg"))

StealSec:AddButton("Steal Best Available Egg Once", function()
    note("UI Test", "Button clicked: Steal Best Available Egg Once")
end)

local LifeSec = FarmPage:CreateSection("Egg Handling")

LifeSec:AddToggle("Auto Place Selected", false, testToggle("AutoPlaceSelected"))
LifeSec:AddToggle("Auto Place All", false, testToggle("AutoPlaceAll"))
LifeSec:AddToggle("Auto Hatch Ready", false, testToggle("AutoOpenReadyEggs"))

LifeSec:AddDropdown(
    "Lifecycle Rarities",
    RARITY_NAMES,
    true,
    function(v)
        set("LifecycleRarities", v)
    end
)

LifeSec:AddDropdown(
    "Lifecycle Mutations",
    MUTATION_NAMES,
    true,
    function(v)
        set("LifecycleMutations", v)
    end
)

LifeSec:AddToggle("Auto Sell Eggs", false, testToggle("AutoSellEggs"))

LifeSec:AddDropdown(
    "Sell Egg Rarities",
    RARITY_NAMES,
    true,
    function(v)
        set("SellEggRarities", v)
    end
)

LifeSec:AddSlider("Sell Egg Interval", 1, 120, 8, function(v)
    set("SellEggInterval", v)
end)

LifeSec:AddButton("Place Eggs Now", testButton("Place Eggs Now"))
LifeSec:AddButton("Hatch Ready Eggs Now", testButton("Hatch Ready Eggs Now"))
LifeSec:AddButton("Sell Selected Eggs Now", testButton("Sell Selected Eggs Now"))

local ServerSec = FarmPage:CreateSection("Server Hop")

ServerSec:AddToggle("Auto Server Hop", false, testToggle("AutoServerHop"))

ServerSec:AddDropdown(
    "Hop When",
    SERVER_HOP_MODES,
    false,
    function(v)
        set("HopMode", v)
    end
)

ServerSec:AddSlider("Wait Before Hop", 1, 200, 15, function(v)
    set("HopValue", v)
end)

ServerSec:AddButton("Hop Now", testButton("Hop Now"))

local PrioritySec = FarmPage:CreateSection("Task Order")

PrioritySec:AddDropdown(
    "Priority 1",
    PRIORITY_TASK_NAMES,
    false,
    function(v)
        set("PrioritySlot1", v)
    end
)

PrioritySec:AddDropdown(
    "Priority 2",
    PRIORITY_TASK_NAMES,
    false,
    function(v)
        set("PrioritySlot2", v)
    end
)

PrioritySec:AddDropdown(
    "Priority 3",
    PRIORITY_TASK_NAMES,
    false,
    function(v)
        set("PrioritySlot3", v)
    end
)

PrioritySec:AddDropdown(
    "Priority 4",
    PRIORITY_TASK_NAMES,
    false,
    function(v)
        set("PrioritySlot4", v)
    end
)

-- =============================================================================
-- PETS
-- Pets / Auto Fuse / Auto Sell Pets
-- =============================================================================

local PetsTab = Window:CreateTab("Pets", false, false)
local PetsPage = PetsTab:CreatePage("Pets")

local PetsSec = PetsPage:CreateSection("Pets")

PetsSec:AddToggle("Auto Equip Best Pets", false, testToggle("AutoEquipBest"))
PetsSec:AddToggle("Hide Own Pet Renders", false, testToggle("AutoDeleteOwnPets"))

PetsSec:AddButton("Equip Best Pets Now", testButton("Equip Best Pets Now"))

local FuseSec = PetsPage:CreateSection("Auto Fuse")

FuseSec:AddToggle("Auto Fuse Pets", false, testToggle("AutoFusePets"))

FuseSec:AddDropdown(
    "Fuse Rarities",
    RARITY_NAMES,
    true,
    function(v)
        set("FuseRarities", v)
    end
)

FuseSec:AddDropdown(
    "Fuse Mutations",
    MUTATION_NAMES,
    true,
    function(v)
        set("FuseMutations", v)
    end
)

FuseSec:AddDropdown(
    "Pick Group By",
    FUSE_TARGET_MODES,
    false,
    function(v)
        set("FuseTarget", v)
    end
)

FuseSec:AddToggle("Never Fuse Mutated", true, testToggle("FuseKeepMutated"))
FuseSec:AddToggle("Never Fuse Equipped", true, testToggle("FuseKeepEquipped"))
FuseSec:AddToggle("Auto Complete Reveal", true, testToggle("FuseAutoReveal"))

FuseSec:AddSlider("Maximum Scale to Fuse", 0, 10, 10, function(v)
    set("FuseMaxScale", v)
end)

FuseSec:AddSlider("Keep Per Pet Type", 0, 20, 0, function(v)
    set("FuseKeepPerCategory", v)
end)

FuseSec:AddSlider("Fuse Interval", 1, 120, 8, function(v)
    set("FuseInterval", v)
end)

FuseSec:AddButton("Fuse Now", testButton("Fuse Now"))

local SellPetSec = PetsPage:CreateSection("Auto Sell Pets")

SellPetSec:AddToggle("Auto Sell Pets", false, testToggle("AutoSellPets"))

SellPetSec:AddDropdown(
    "Sell Rarities",
    RARITY_NAMES,
    true,
    function(v)
        set("SellRarities", v)
    end
)

SellPetSec:AddDropdown(
    "Sell Mutations",
    MUTATION_NAMES,
    true,
    function(v)
        set("SellMutations", v)
    end
)

SellPetSec:AddToggle("Never Sell Mutated", true, testToggle("SellKeepMutated"))
SellPetSec:AddToggle("Never Sell Equipped", true, testToggle("SellKeepEquipped"))

SellPetSec:AddSlider("Maximum Scale to Sell", 0, 10, 10, function(v)
    set("SellMaxScale", v)
end)

SellPetSec:AddSlider("Sell Interval", 1, 120, 6, function(v)
    set("SellInterval", v)
end)

SellPetSec:AddButton("Sell Selected Pets Now", testButton("Sell Selected Pets Now"))

-- =============================================================================
-- PROGRESS
-- Upgrades / Rewards / Equipment / Training
-- =============================================================================

local ProgressTab = Window:CreateTab("Progress", false, false)
local ProgressPage = ProgressTab:CreatePage("Progress")

local UpgradesSec = ProgressPage:CreateSection("Upgrades")

UpgradesSec:AddToggle("Auto Buy Upgrades", false, testToggle("AutoUpgrades"))

UpgradesSec:AddDropdown(
    "Upgrade Types",
    UPGRADE_TYPES,
    true,
    function(v)
        set("UpgradeTypes", v)
    end
)

UpgradesSec:AddButton("Upgrade Base Now", testButton("Upgrade Base Now"))
UpgradesSec:AddButton("Upgrade Treadmill Now", testButton("Upgrade Treadmill Now"))

local RewardsSec = ProgressPage:CreateSection("Rewards")

RewardsSec:AddToggle("Auto Claim Index", false, testToggle("AutoClaimIndex"))
RewardsSec:AddToggle("Auto Claim Group Reward", false, testToggle("AutoClaimGroupReward"))
RewardsSec:AddToggle("Claim Offline Earnings", false, testToggle("AutoClaimOffline"))

RewardsSec:AddButton("Claim Index Now", testButton("Claim Index Now"))
RewardsSec:AddButton("Claim Group Reward Now", testButton("Claim Group Reward Now"))
RewardsSec:AddButton("Claim Offline Earnings Now", testButton("Claim Offline Earnings Now"))

local EquipmentSec = ProgressPage:CreateSection("Equipment")

EquipmentSec:AddToggle("Auto Buy Trail", false, testToggle("AutoBuyTrail"))

EquipmentSec:AddDropdown(
    "Trails",
    {
        "Basic Trail",
        "Blue Trail",
        "Green Trail",
        "Purple Trail",
        "Rainbow Trail"
    },
    true,
    function(v)
        set("TrailWanted", v)
    end
)

EquipmentSec:AddToggle("Auto Equip Best Trail", false, testToggle("AutoEquipBestTrail"))
EquipmentSec:AddToggle("Auto Equip Best Gear", false, testToggle("AutoEquipBestGear"))

EquipmentSec:AddButton("Buy Selected Trail", testButton("Buy Selected Trail"))

local TrainingSec = ProgressPage:CreateSection("Training")

TrainingSec:AddToggle("Auto Treadmill Training", false, testToggle("AutoTreadmill"))

TrainingSec:AddSlider("Training Speed", 1, 400, 60, function(v)
    set("TrainingSpeed", v)
end)

TrainingSec:AddButton("Start Treadmill Training", testButton("Start Treadmill Training"))

-- =============================================================================
-- PLAYER
-- ESP / Movement / Teleports
-- =============================================================================

local PlayerTab = Window:CreateTab("Player", false, false)
local PlayerPage = PlayerTab:CreatePage("Player")

local EspSec = PlayerPage:CreateSection("ESP")

EspSec:AddToggle("World Egg ESP", false, testToggle("EspWorldEggs"))
EspSec:AddToggle("Carried and Dropped Egg ESP", false, testToggle("EspCarriedEggs"))
EspSec:AddToggle("Guard ESP", false, testToggle("EspGuards"))
EspSec:AddToggle("Pet ESP", false, testToggle("EspPets"))
EspSec:AddToggle("Player ESP", false, testToggle("EspPlayers"))
EspSec:AddToggle("Machine ESP", false, testToggle("EspMachines"))
EspSec:AddToggle("Plot ESP", false, testToggle("EspPlots"))

EspSec:AddSlider("Render Distance", 100, 6000, 2000, function(v)
    set("EspDistance", v)
end)

local MoveSec = PlayerPage:CreateSection("Movement")

MoveSec:AddToggle("Walk Speed Override", false, testToggle("WalkSpeedEnabled"))
MoveSec:AddSlider("Walk Speed", 16, 500, 32, function(v)
    set("WalkSpeed", v)
end)

MoveSec:AddToggle("Jump Power Override", false, testToggle("JumpPowerEnabled"))
MoveSec:AddSlider("Jump Power", 10, 500, 50, function(v)
    set("JumpPower", v)
end)

MoveSec:AddToggle("Infinite Jump", false, testToggle("InfJump"))
MoveSec:AddToggle("NoClip", false, testToggle("NoClip"))

MoveSec:AddToggle("Fly", false, testToggle("Fly"))
MoveSec:AddSlider("Fly Speed", 10, 400, 60, function(v)
    set("FlySpeed", v)
end)

local TeleportSec = PlayerPage:CreateSection("Teleports")

TeleportSec:AddDropdown(
    "Waypoint",
    WAYPOINT_NAMES,
    false,
    function(v)
        set("WaypointTarget", v)
    end
)

TeleportSec:AddButton("Teleport to Waypoint", testButton("Teleport to Waypoint"))

TeleportSec:AddDropdown(
    "Area",
    AREA_NAMES,
    false,
    function(v)
        set("AreaTarget", v)
    end
)

TeleportSec:AddButton("Teleport to Area", testButton("Teleport to Area"))

TeleportSec:AddDropdown(
    "Player",
    playerList(),
    false,
    function(v)
        set("PlayerTarget", v)
    end
)

TeleportSec:AddTextbox("Player Name", "Enter username...", function(v)
    set("PlayerName", v)
end)

TeleportSec:AddButton("Teleport to Player", testButton("Teleport to Player"))

-- =============================================================================
-- SYSTEM
-- Session / Performance / Webhooks / About
-- =============================================================================

local SystemTab = Window:CreateTab("System", false, false)
local SystemPage = SystemTab:CreatePage("System")

local SessionSysSec = SystemPage:CreateSection("Session")

SessionSysSec:AddToggle("Anti-AFK", true, testToggle("AntiAfk"))
SessionSysSec:AddToggle("No Gameplay Paused", true, testToggle("AntiGameplayPause"))
SessionSysSec:AddToggle("Auto Reconnect", false, testToggle("AutoReconnect"))

SessionSysSec:AddButton("Rejoin Server", testButton("Rejoin Server"))
SessionSysSec:AddButton("Copy Join Script", testButton("Copy Join Script"))

local PerformanceSec = SystemPage:CreateSection("Performance")

PerformanceSec:AddToggle("FPS Boost", false, testToggle("FpsBoost"))
PerformanceSec:AddToggle("Disable 3D Rendering", false, testToggle("DisableRendering"))

PerformanceSec:AddSlider("FPS Cap", 15, 360, 60, function(v)
    set("FpsCap", v)
end)

PerformanceSec:AddToggle("Fullbright (Daylight Visuals)", false, testToggle("Fullbright"))
PerformanceSec:AddButton("Delete Own Pet Renders", testButton("Delete Own Pet Renders"))

local WebhookSec = SystemPage:CreateSection("Webhooks")

WebhookSec:AddToggle("Enable Webhooks", false, testToggle("WebhookEnabled"))

WebhookSec:AddTextbox(
    "Webhook URL",
    "https://discord.com/api/webhooks/...",
    function(v)
        set("WebhookUrl", v)
    end
)

WebhookSec:AddTextbox(
    "Ping User ID",
    "123456789012345678",
    function(v)
        set("WebhookPingId", v)
    end
)

WebhookSec:AddSlider("Summary Interval", 1, 180, 15, function(v)
    set("WebhookInterval", v)
end)

WebhookSec:AddToggle("List Spawned Eggs", true, testToggle("WebhookEggSpawns"))

WebhookSec:AddDropdown(
    "Webhook Rarities",
    RARITY_NAMES,
    true,
    function(v)
        set("WebhookRarities", v)
    end
)

WebhookSec:AddToggle("Disconnect Alerts", false, testToggle("WebhookDisconnectAlerts"))

WebhookSec:AddButton("Send Summary Now", testButton("Send Summary Now"))

local AboutSec = SystemPage:CreateSection("About")

AboutSec:AddButton("Script Dev: Starvane", testButton("Script Dev: Starvane"))
AboutSec:AddButton("UI Library: OxioUI", testButton("UI Library: OxioUI"))
AboutSec:AddButton("Library Dev: starvane.com", testButton("Library Dev: starvane.com"))
AboutSec:AddButton("Search / Ctrl+K", testButton("Search / Ctrl+K"))
AboutSec:AddConfigManager("stealanegg_ui_test")

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
