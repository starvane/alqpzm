local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

if not isfolder("OxioHub") then
    makefolder("OxioHub")
end
if not isfolder("OxioHub/Config") then
    makefolder("OxioHub/Config")
end

local placeId = game.PlaceId
local nameCacheFile = "OxioHub/GameName_" .. tostring(placeId) .. ".txt"
local gameName = ""
if isfile and isfile(nameCacheFile) then
    local ok, savedName = pcall(readfile, nameCacheFile)
    if ok and savedName and savedName ~= "" then
        gameName = savedName
    end
end
if gameName == "" then
    local function FetchGameName()
        local success, productInfo = pcall(function()
            return MarketplaceService:GetProductInfo(placeId)
        end)
        if success and productInfo and productInfo.Name then
            return tostring(productInfo.Name)
        end
        return nil
    end
    gameName = FetchGameName()
    if not gameName then
        task.wait(3)
        gameName = FetchGameName() or "Unknown_Game"
    end
    if writefile and gameName ~= "Unknown_Game" then
        pcall(writefile, nameCacheFile, gameName)
    end
end

gameName = gameName:gsub("[^%w_ ]", "")
gameName = gameName:gsub("%s+", "_")

local function SanitizeConfigName(name)
    name = tostring(name or "")
    name = name:gsub("[^%w_ ]", "")
    name = name:gsub("%s+", "_")
    return name
end

local function EnsureFolderForFile(path)
    local parts = {}
    for part in string.gmatch(path, "[^/\\]+") do
        table.insert(parts, part)
    end
    table.remove(parts)
    local current = ""
    for _, part in ipairs(parts) do
        current = (current == "" and part) or (current .. "/" .. part)
        if not isfolder(current) then
            makefolder(current)
        end
    end
end

ConfigFile = "OxioHub/Config/" .. gameName .. ".json"
ConfigFolder = "OxioHub/Configs"
GameConfigFolder = ConfigFolder .. "/" .. gameName

ConfigData       = {}
Elements         = {}
CURRENT_VERSION  = nil
ActiveConfigName = nil
ActiveConfigPath = nil
ActiveConfigMode = nil
AutoSaveEnabled = true
ApplyingConfig = false
SaveQueued = false

local InternalConfigKeys = {
    ["Input_Config Name"] = true,
    ["Dropdown_Saved Configs"] = true,
    ["Toggle_Auto Load"] = true,
}

local function CopyConfigValue(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end

    local copy = {}
    seen[value] = copy
    for k, v in pairs(value) do
        copy[CopyConfigValue(k, seen)] = CopyConfigValue(v, seen)
    end
    return copy
end

function GetConfigSnapshot()
    local snapshot = {}

    for key, value in pairs(ConfigData or {}) do
        if key ~= "_version" and not InternalConfigKeys[key] then
            snapshot[key] = CopyConfigValue(value)
        end
    end

    snapshot._version = CURRENT_VERSION
    return snapshot
end

function SetActiveConfig(name, path, autoSave, mode)
    ActiveConfigName = name
    ActiveConfigPath = path
    if mode ~= nil then
        ActiveConfigMode = mode
    elseif name == nil then
        ActiveConfigMode = nil
    end
    if autoSave ~= nil then
        AutoSaveEnabled = autoSave
    end
end

function SaveConfig(force)
    if not writefile or not CURRENT_VERSION then return false end
    if ApplyingConfig and not force then return false end
    if not force and not AutoSaveEnabled then return false end

    local target = ActiveConfigPath or ConfigFile
    if not target or target == "" then return false end

    local snapshot = GetConfigSnapshot()
    local ok, encoded = pcall(function() return HttpService:JSONEncode(snapshot) end)
    if not ok then
        warn("SaveConfig failed to encode config:", encoded)
        return false
    end

    ConfigData = snapshot
    writefile(target, encoded)
    return true
end

function QueueSaveConfig(force)
    if force then return SaveConfig(true) end
    if ApplyingConfig or not AutoSaveEnabled then return false end
    if SaveQueued then return true end

    SaveQueued = true
    task.delay(0.35, function()
        SaveQueued = false
        SaveConfig(false)
    end)
    return true
end

function LoadConfigFromFile()
    if not CURRENT_VERSION then return end
    ConfigData = { _version = CURRENT_VERSION }
    SetActiveConfig(nil, nil, false, nil)

    local autoPath = GameConfigFolder .. "/_autoload.json"
    if not (isfile and isfile(autoPath)) then return end

    local ok, auto = pcall(function()
        return HttpService:JSONDecode(readfile(autoPath))
    end)
    local autoName = ok and type(auto) == "table" and tostring(auto.Name or "") or ""
    if autoName == "" then return end

    local configPath = GameConfigFolder .. "/" .. autoName .. ".json"
    if isfile and isfile(configPath) then
        local success, result = pcall(function()
            return HttpService:JSONDecode(readfile(configPath))
        end)
        if success and type(result) == "table" then
            ConfigData = result
            ConfigData._version = CURRENT_VERSION
        end
    end
end

function LoadConfigElements()
    ApplyingConfig = true
    for key, element in pairs(Elements) do
        if ConfigData[key] ~= nil and element.Set then
            local ok, err = pcall(function()
                element:Set(ConfigData[key], true)
            end)
            if not ok then
                warn("[OxioUi] Gagal menerapkan config untuk elemen '" .. tostring(key) .. "': " .. tostring(err))
            end
        end
    end
    ApplyingConfig = false
end

local lucide_source_url = "https://github.com/latte-soft/lucide-roblox/releases/latest/download/lucide-roblox.luau"

local Lucide
do
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(lucide_source_url))()
    end)
    if ok and result then
        Lucide = result
    else
        warn("[OxioUi] Gagal memuat library resmi Lucide Icons dari " .. lucide_source_url .. " -- " .. tostring(result))
        Lucide = nil
    end
end

local LucideAssetCache = {}

local function GetLucideAsset(iconName, size)
    if not Lucide then return nil end

    local cacheKey = iconName .. ":" .. tostring(size or 256)
    local cached = LucideAssetCache[cacheKey]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end

    local ok, asset = pcall(function()
        return Lucide.GetAsset(iconName, size)
    end)

    if ok and asset then
        LucideAssetCache[cacheKey] = asset
        return asset
    end

    LucideAssetCache[cacheKey] = false
    return nil
end

local function ApplyIcon(imageLabel, name, size)
    if not imageLabel then return end

    if name == nil or name == "" then
        imageLabel.Image = ""
        imageLabel.ImageRectOffset = Vector2.new(0, 0)
        imageLabel.ImageRectSize = Vector2.new(0, 0)
        return
    end

    if type(name) ~= "string" then
        imageLabel.Image = tostring(name)
        imageLabel.ImageRectOffset = Vector2.new(0, 0)
        imageLabel.ImageRectSize = Vector2.new(0, 0)
        return
    end

    if name:match("^rbxassetid://") or name:match("^rbxthumb://") or name:match("^https?://") or name:match("^%d+$") then
        local finalImage = name
        if name:match("^%d+$") then
            finalImage = "rbxassetid://" .. name
        end
        imageLabel.Image = finalImage
        imageLabel.ImageRectOffset = Vector2.new(0, 0)
        imageLabel.ImageRectSize = Vector2.new(0, 0)
        return
    end

    local asset = GetLucideAsset(name, size)
    if asset then
        imageLabel.Image = asset.Url
        imageLabel.ImageRectOffset = asset.ImageRectOffset
        imageLabel.ImageRectSize = asset.ImageRectSize
    else
        warn("[OxioUi] Ikon Lucide tidak ditemukan atau library gagal dimuat: \"" .. name .. "\"")
        imageLabel.Image = ""
        imageLabel.ImageRectOffset = Vector2.new(0, 0)
        imageLabel.ImageRectSize = Vector2.new(0, 0)
    end
end

local function CreateLockOverlay(Parent, DefaultText)
    local Overlay = Instance.new("TextButton")
    Overlay.Name = "LockOverlay"
    Overlay.Text = ""
    Overlay.AutoButtonColor = false
    Overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Overlay.BackgroundTransparency = 0.45
    Overlay.BorderSizePixel = 0
    Overlay.Size = UDim2.new(1, 0, 1, 0)
    Overlay.ZIndex = 50
    Overlay.Visible = false
    Overlay.Active = true
    Overlay.Selectable = false
    Overlay.Parent = Parent

    local OverlayCorner = Instance.new("UICorner")
    OverlayCorner.CornerRadius = UDim.new(0, 4)
    OverlayCorner.Parent = Overlay

    local LockContent = Instance.new("Frame")
    LockContent.Name = "LockContent"
    LockContent.BackgroundTransparency = 1
    LockContent.AutomaticSize = Enum.AutomaticSize.X
    LockContent.Size = UDim2.new(0, 0, 0, 16)
    LockContent.AnchorPoint = Vector2.new(0.5, 0.5)
    LockContent.Position = UDim2.new(0.5, 0, 0.5, 0)
    LockContent.ZIndex = 51
    LockContent.Parent = Overlay

    local LockLayout = Instance.new("UIListLayout")
    LockLayout.FillDirection = Enum.FillDirection.Horizontal
    LockLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    LockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    LockLayout.Padding = UDim.new(0, 6)
    LockLayout.SortOrder = Enum.SortOrder.LayoutOrder
    LockLayout.Parent = LockContent

    local LockIcon = Instance.new("ImageLabel")
    LockIcon.Name = "LockIcon"
    LockIcon.BackgroundTransparency = 1
    LockIcon.Size = UDim2.new(0, 16, 0, 16)
    LockIcon.LayoutOrder = 1
    LockIcon.ZIndex = 51
    LockIcon.Parent = LockContent
    ApplyIcon(LockIcon, "lock", 32)

    local LockLabel = Instance.new("TextLabel")
    LockLabel.Name = "LockLabel"
    LockLabel.BackgroundTransparency = 1
    LockLabel.AutomaticSize = Enum.AutomaticSize.X
    LockLabel.Size = UDim2.new(0, 0, 0, 16)
    LockLabel.LayoutOrder = 2
    LockLabel.Font = Enum.Font.GothamBold
    LockLabel.Text = DefaultText or "Locked"
    LockLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    LockLabel.TextSize = 12
    LockLabel.TextTransparency = 0.05
    LockLabel.ZIndex = 51
    LockLabel.Parent = LockContent

    local Api = { Frame = Overlay, Locked = false }

    function Api:Lock(text)
        LockLabel.Text = text or LockLabel.Text
        Overlay.Visible = true
        Api.Locked = true
    end

    function Api:Unlock()
        Overlay.Visible = false
        Api.Locked = false
    end

    function Api:SetText(text)
        LockLabel.Text = text or LockLabel.Text
    end

    return Api
end

local discord_logo_asset_id = "rbxassetid://95644421757953"

local WebImageCacheFolder = "OxioHub/ImageCache"
if not isfolder(WebImageCacheFolder) then
    makefolder(WebImageCacheFolder)
end

local MAX_CACHE_FILES = 5
local ManifestPath = WebImageCacheFolder .. "/_manifest.json"
local WebImageAssetCache = {}
local PendingImageEvents = {}
local CacheManifest = {}
local ManifestSaveQueued = false

local function LoadImageCacheManifest()
    if not (isfile and readfile and isfile(ManifestPath)) then return end
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(readfile(ManifestPath))
    end)
    if ok and type(decoded) == "table" then
        CacheManifest = decoded
    end
end
LoadImageCacheManifest()

local function SaveImageCacheManifest()
    if ManifestSaveQueued or not writefile then return end
    ManifestSaveQueued = true
    task.delay(0.5, function()
        ManifestSaveQueued = false
        local ok, encoded = pcall(function()
            return HttpService:JSONEncode(CacheManifest)
        end)
        if ok then
            pcall(writefile, ManifestPath, encoded)
        end
    end)
end

local function HashUrl(str)
    local hash = 5381
    for i = 1, #str do
        hash = (hash * 33 + string.byte(str, i)) % 4294967296
    end
    return string.format("%08x", hash)
end

local function TrimImageCache()
    if not delfile then return end

    local count = 0
    for _ in pairs(CacheManifest) do count = count + 1 end
    if count <= MAX_CACHE_FILES then return end

    local entries = {}
    for hash, info in pairs(CacheManifest) do
        entries[#entries + 1] = { hash = hash, info = info }
    end
    table.sort(entries, function(a, b)
        return (a.info.lastUsed or 0) < (b.info.lastUsed or 0)
    end)

    local toRemove = count - MAX_CACHE_FILES
    for i = 1, toRemove do
        local entry = entries[i]
        if entry and entry.info and entry.info.file then
            local path = WebImageCacheFolder .. "/" .. entry.info.file
            if isfile and isfile(path) then
                pcall(delfile, path)
            end
            CacheManifest[entry.hash] = nil
            if entry.info.url then
                WebImageAssetCache[entry.info.url] = nil
            end
        end
    end

    SaveImageCacheManifest()
end

local function GetWebImageAsset(url)
    if not url or url == "" then return "" end
    if WebImageAssetCache[url] ~= nil then return WebImageAssetCache[url] end

    local existingEvent = PendingImageEvents[url]
    if existingEvent then
        return existingEvent.Event:Wait()
    end

    local getAsset = getcustomasset or getsynasset
    if not (writefile and getAsset and game.HttpGet) then
        warn("[OxioUi] Executor tidak mendukung getcustomasset/getsynasset, gambar dari url web mungkin tidak tampil.")
        return ""
    end

    local event = Instance.new("BindableEvent")
    PendingImageEvents[url] = event

    local ext = ".png"
    if url:match("%.jpe?g") then
        ext = ".jpg"
    elseif url:match("%.gif") then
        ext = ".gif"
    elseif url:match("%.webp") then
        ext = ".webp"
    end

    local hash = HashUrl(url)
    local filename = hash .. ext
    local path = WebImageCacheFolder .. "/" .. filename

    local result = ""

    if isfile and isfile(path) then
        local ok, assetId = pcall(getAsset, path)
        if ok and assetId and assetId ~= "" then
            result = assetId
        end
    end

    if result == "" then
        local ok, res = pcall(function()
            local data = game:HttpGet(url)
            if not data or data == "" then return nil end
            writefile(path, data)
            return getAsset(path)
        end)
        if ok and res and res ~= "" then
            result = res
        else
            warn("[OxioUi] Gagal memuat gambar dari url: " .. tostring(url) .. " -- " .. tostring(res))
        end
    end

    if result ~= "" then
        CacheManifest[hash] = { url = url, file = filename, lastUsed = os.time() }
        SaveImageCacheManifest()
        TrimImageCache()
    end

    WebImageAssetCache[url] = result
    PendingImageEvents[url] = nil
    event:Fire(result)
    event:Destroy()

    return result
end

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local CoreGui = game:GetService("CoreGui")
local viewport = workspace.CurrentCamera.ViewportSize

local function isMobileDevice()
    return UserInputService.TouchEnabled
        and not UserInputService.KeyboardEnabled
        and not UserInputService.MouseEnabled
end

local isMobile = isMobileDevice()

local function safeSize(pxWidth, pxHeight)
    local scaleX = pxWidth / viewport.X
    local scaleY = pxHeight / viewport.Y

    if isMobile then
        if scaleX > 0.5 then scaleX = 0.5 end
        if scaleY > 0.3 then scaleY = 0.3 end
    end

    return UDim2.new(scaleX, 0, scaleY, 0)
end

local function MakeDraggable(topbarobject, object)
    local function CustomPos(topbarobject, object)
        local Dragging, DragInput, DragStart, StartPosition

        local function UpdatePos(input)
            local Delta = input.Position - DragStart
            local pos = UDim2.new(
                StartPosition.X.Scale,
                StartPosition.X.Offset + Delta.X,
                StartPosition.Y.Scale,
                StartPosition.Y.Offset + Delta.Y
            )
            object.Position = pos
        end

        topbarobject.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                Dragging = true
                DragStart = input.Position
                StartPosition = object.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        Dragging = false
                    end
                end)
            end
        end)

        topbarobject.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                DragInput = input
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if input == DragInput and Dragging then
                UpdatePos(input)
            end
        end)
    end

    local function CustomSize(object)
        local Dragging, DragInput, DragStart, StartSize

        local minSizeX, minSizeY
        local defSizeX, defSizeY

        if isMobile then
            minSizeX, minSizeY = 100, 100
            defSizeX, defSizeY = 490, 315
        else
            minSizeX, minSizeY = 100, 100
            defSizeX, defSizeY = 640, 400
        end

        object.Size = UDim2.new(0, defSizeX, 0, defSizeY)

        local changesizeobject = Instance.new("Frame")
        changesizeobject.AnchorPoint = Vector2.new(1, 1)
        changesizeobject.BackgroundTransparency = 1
        changesizeobject.Size = UDim2.new(0, 26, 0, 26)
        changesizeobject.Position = UDim2.new(1, 11, 1, 10)
        changesizeobject.Name = "changesizeobject"
        changesizeobject.Parent = object

        local ResizeIcon = Instance.new("ImageLabel")
        ResizeIcon.Name = "ResizeIcon"
        ResizeIcon.BackgroundTransparency = 1
        ResizeIcon.Size = UDim2.new(1, 0, 1, 0)
        ResizeIcon.Image = "rbxassetid://124384748391701"
        ResizeIcon.ImageTransparency = 0.55
        ResizeIcon.Parent = changesizeobject

        local function UpdateSize(input)
            local Delta = input.Position - DragStart
            local newWidth = StartSize.X.Offset + Delta.X
            local newHeight = StartSize.Y.Offset + Delta.Y

            newWidth = math.max(newWidth, minSizeX)
            newHeight = math.max(newHeight, minSizeY)

            object.Size = UDim2.new(0, newWidth, 0, newHeight)
        end

        changesizeobject.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                Dragging = true
                DragStart = input.Position
                StartSize = object.Size
                ResizeIcon.ImageTransparency = 0
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        Dragging = false
                        ResizeIcon.ImageTransparency = 0.55
                    end
                end)
            end
        end)

        changesizeobject.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                DragInput = input
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if input == DragInput and Dragging then
                UpdateSize(input)
            end
        end)
    end

    CustomSize(object)
    CustomPos(topbarobject, object)
end

function CircleClick(Button, X, Y)
    task.spawn(function()
        Button.ClipsDescendants = true
        local Circle = Instance.new("ImageLabel")
        Circle.Image = "rbxassetid://266543268"
        Circle.ImageColor3 = Color3.fromRGB(80, 80, 80)
        Circle.ImageTransparency = 0.8999999761581421
        Circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Circle.BackgroundTransparency = 1
        Circle.ZIndex = 10
        Circle.Name = "Circle"
        Circle.Parent = Button

        local NewX = X - Circle.AbsolutePosition.X
        local NewY = Y - Circle.AbsolutePosition.Y
        Circle.Position = UDim2.new(0, NewX, 0, NewY)
        local Size = 0
        if Button.AbsoluteSize.X > Button.AbsoluteSize.Y then
            Size = Button.AbsoluteSize.X * 1.5
        elseif Button.AbsoluteSize.X < Button.AbsoluteSize.Y then
            Size = Button.AbsoluteSize.Y * 1.5
        elseif Button.AbsoluteSize.X == Button.AbsoluteSize.Y then
            Size = Button.AbsoluteSize.X * 1.5
        end

        local Time = 0.5
        local SizeTween = TweenService:Create(Circle, TweenInfo.new(Time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Size = UDim2.new(0, Size, 0, Size), Position = UDim2.new(0.5, -Size / 2, 0.5, -Size / 2) })
        local FadeTween = TweenService:Create(Circle, TweenInfo.new(Time, Enum.EasingStyle.Linear),
            { ImageTransparency = 1 })
        SizeTween:Play()
        FadeTween:Play()
        FadeTween.Completed:Wait()
        Circle:Destroy()
    end)
end

local Chloex = {}
function Chloex:MakeNotify(NotifyConfig)
    local NotifyConfig = NotifyConfig or {}
    NotifyConfig.Title = NotifyConfig.Title or "OxioHub"
    NotifyConfig.Description = NotifyConfig.Description or "Notification"
    NotifyConfig.Content = NotifyConfig.Content or "Content"
    NotifyConfig.Color = NotifyConfig.Color or Color3.fromRGB(235, 235, 235)
    NotifyConfig.Time = NotifyConfig.Time or 0.5
    NotifyConfig.Delay = NotifyConfig.Delay or 5
    NotifyConfig.Icon = NotifyConfig.Icon or ""
    local NotifyFunction = {}
    task.spawn(function()
        if not CoreGui:FindFirstChild("NotifyGui") then
            local NotifyGui = Instance.new("ScreenGui");
            NotifyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            NotifyGui.Name = "NotifyGui"
            NotifyGui.Parent = CoreGui
        end
        if not CoreGui.NotifyGui:FindFirstChild("NotifyLayout") then
            local NotifyLayout = Instance.new("Frame");
            NotifyLayout.AnchorPoint = Vector2.new(1, 1)
            NotifyLayout.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            NotifyLayout.BackgroundTransparency = 0.9990000128746033
            NotifyLayout.BorderColor3 = Color3.fromRGB(27, 27, 27)
            NotifyLayout.BorderSizePixel = 0
            NotifyLayout.Position = UDim2.new(1, -30, 1, -30)
            NotifyLayout.Size = UDim2.new(0, 320, 1, 0)
            NotifyLayout.Name = "NotifyLayout"
            NotifyLayout.Parent = CoreGui.NotifyGui
            local Count = 0
            CoreGui.NotifyGui.NotifyLayout.ChildRemoved:Connect(function()
                Count = 0
                for i, v in CoreGui.NotifyGui.NotifyLayout:GetChildren() do
                    TweenService:Create(
                        v,
                        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                        { Position = UDim2.new(0, 0, 1, -((v.Size.Y.Offset + 12) * Count)) }
                    ):Play()
                    Count = Count + 1
                end
            end)
        end
        local NotifyPosHeigh = 0
        for i, v in CoreGui.NotifyGui.NotifyLayout:GetChildren() do
            NotifyPosHeigh = -(v.Position.Y.Offset) + v.Size.Y.Offset + 12
        end
        local NotifyFrame = Instance.new("Frame");
        local NotifyFrameReal = Instance.new("Frame");
        local UICorner = Instance.new("UICorner");
        local DropShadowHolder = Instance.new("Frame");
        local DropShadow = Instance.new("ImageLabel");
        local Top = Instance.new("Frame");
        local TextLabel = Instance.new("TextLabel");
        local UICorner1 = Instance.new("UICorner");
        local TextLabel1 = Instance.new("TextLabel");
        local Close = Instance.new("TextButton");
        local ImageLabel = Instance.new("ImageLabel");
        local TextLabel2 = Instance.new("TextLabel");

        NotifyFrame.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
        NotifyFrame.BorderColor3 = Color3.fromRGB(27, 27, 27)
        NotifyFrame.BorderSizePixel = 0
        NotifyFrame.Size = UDim2.new(1, 0, 0, 150)
        NotifyFrame.Name = "NotifyFrame"
        NotifyFrame.BackgroundTransparency = 1
        NotifyFrame.Parent = CoreGui.NotifyGui.NotifyLayout
        NotifyFrame.AnchorPoint = Vector2.new(0, 1)
        NotifyFrame.Position = UDim2.new(0, 0, 1, -(NotifyPosHeigh))

        NotifyFrameReal.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
        NotifyFrameReal.BorderColor3 = Color3.fromRGB(27, 27, 27)
        NotifyFrameReal.BorderSizePixel = 0
        NotifyFrameReal.Position = UDim2.new(0, 400, 0, 0)
        NotifyFrameReal.Size = UDim2.new(1, 0, 1, 0)
        NotifyFrameReal.Name = "NotifyFrameReal"
        NotifyFrameReal.Parent = NotifyFrame

        UICorner.Parent = NotifyFrameReal
        UICorner.CornerRadius = UDim.new(0, 8)

        DropShadowHolder.BackgroundTransparency = 1
        DropShadowHolder.BorderSizePixel = 0
        DropShadowHolder.Size = UDim2.new(1, 0, 1, 0)
        DropShadowHolder.ZIndex = 0
        DropShadowHolder.Name = "DropShadowHolder"
        DropShadowHolder.Parent = NotifyFrameReal

        Top.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
        Top.BackgroundTransparency = 0.9990000128746033
        Top.BorderColor3 = Color3.fromRGB(27, 27, 27)
        Top.BorderSizePixel = 0
        Top.Size = UDim2.new(1, 0, 0, 36)
        Top.Name = "Top"
        Top.Parent = NotifyFrameReal

        TextLabel.Font = Enum.Font.GothamBold
        TextLabel.Text = NotifyConfig.Title
        TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        TextLabel.TextSize = 14
        TextLabel.TextXAlignment = Enum.TextXAlignment.Left
        TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        TextLabel.BackgroundTransparency = 0.9990000128746033
        TextLabel.BorderColor3 = Color3.fromRGB(27, 27, 27)
        TextLabel.BorderSizePixel = 0
        TextLabel.Size = UDim2.new(1, 0, 1, 0)
        TextLabel.Parent = Top
        TextLabel.Position = UDim2.new(0, 10, 0, 0)

        UICorner1.Parent = Top
        UICorner1.CornerRadius = UDim.new(0, 5)

        TextLabel1.Font = Enum.Font.GothamBold
        TextLabel1.Text = NotifyConfig.Description
        TextLabel1.TextColor3 = NotifyConfig.Color
        TextLabel1.TextSize = 14
        TextLabel1.TextXAlignment = Enum.TextXAlignment.Left
        TextLabel1.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        TextLabel1.BackgroundTransparency = 0.9990000128746033
        TextLabel1.BorderColor3 = Color3.fromRGB(27, 27, 27)
        TextLabel1.BorderSizePixel = 0
        TextLabel1.Size = UDim2.new(1, 0, 1, 0)
        TextLabel1.Position = UDim2.new(0, 10 + TextLabel.TextBounds.X + 5, 0, 0)
        TextLabel1.Parent = Top

        Close.Font = Enum.Font.SourceSans
        Close.Text = ""
        Close.TextColor3 = Color3.fromRGB(27, 27, 27)
        Close.TextSize = 14
        Close.AnchorPoint = Vector2.new(1, 0.5)
        Close.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Close.BackgroundTransparency = 0.9990000128746033
        Close.BorderColor3 = Color3.fromRGB(27, 27, 27)
        Close.BorderSizePixel = 0
        Close.Position = UDim2.new(1, -5, 0.5, 0)
        Close.Size = UDim2.new(0, 25, 0, 25)
        Close.Name = "Close"
        Close.Parent = Top

        ImageLabel.Image = "rbxassetid://9886659671"
        ImageLabel.AnchorPoint = Vector2.new(0.5, 0.5)
        ImageLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ImageLabel.BackgroundTransparency = 0.9990000128746033
        ImageLabel.BorderColor3 = Color3.fromRGB(27, 27, 27)
        ImageLabel.BorderSizePixel = 0
        ImageLabel.Position = UDim2.new(0.49000001, 0, 0.5, 0)
        ImageLabel.Size = UDim2.new(1, -8, 1, -8)
        ImageLabel.Parent = Close

        TextLabel2.Font = Enum.Font.GothamBold
        TextLabel2.TextColor3 = Color3.fromRGB(255, 255, 255)
        TextLabel2.TextSize = 13
        TextLabel2.Text = NotifyConfig.Content
        TextLabel2.TextXAlignment = Enum.TextXAlignment.Left
        TextLabel2.TextYAlignment = Enum.TextYAlignment.Top
        TextLabel2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        TextLabel2.BackgroundTransparency = 0.9990000128746033
        TextLabel2.TextColor3 = Color3.fromRGB(150.0000062584877, 150.0000062584877, 150.0000062584877)
        TextLabel2.BorderColor3 = Color3.fromRGB(27, 27, 27)
        TextLabel2.BorderSizePixel = 0
        TextLabel2.Position = UDim2.new(0, 10, 0, 27)
        TextLabel2.Parent = NotifyFrameReal
        TextLabel2.Size = UDim2.new(1, -20, 0, 13)

        TextLabel2.Size = UDim2.new(1, -20, 0, 13 + (13 * (TextLabel2.TextBounds.X // TextLabel2.AbsoluteSize.X)))
        TextLabel2.TextWrapped = true

        if TextLabel2.AbsoluteSize.Y < 27 then
            NotifyFrame.Size = UDim2.new(1, 0, 0, 65)
        else
            NotifyFrame.Size = UDim2.new(1, 0, 0, TextLabel2.AbsoluteSize.Y + 40)
        end

        -- Icon besar di sisi kiri, tingginya menyesuaikan tinggi notify (sedikit lebih kecil),
        -- konten (Top + TextLabel2) digeser ke kanan icon.
        if NotifyConfig.Icon ~= "" then
            local FrameHeight = NotifyFrame.Size.Y.Offset
            local IconSize = FrameHeight - 16

            local NotifyIcon = Instance.new("ImageLabel")
            NotifyIcon.Name = "NotifyIcon"
            NotifyIcon.BackgroundTransparency = 1
            NotifyIcon.AnchorPoint = Vector2.new(0, 0.5)
            NotifyIcon.Position = UDim2.new(0, 8, 0.5, 0)
            NotifyIcon.Size = UDim2.new(0, IconSize, 0, IconSize)
            NotifyIcon.ZIndex = 2
            NotifyIcon.Parent = NotifyFrameReal
            ApplyIcon(NotifyIcon, NotifyConfig.Icon, 64)

            local ContentOffsetX = 8 + IconSize + 10

            TextLabel.Position = UDim2.new(0, ContentOffsetX, 0, 0)
            TextLabel1.Position = UDim2.new(0, ContentOffsetX + TextLabel.TextBounds.X + 5, 0, 0)

            TextLabel2.Position = UDim2.new(0, ContentOffsetX, 0, 27)
            TextLabel2.Size = UDim2.new(1, -(ContentOffsetX + 10), 0, TextLabel2.Size.Y.Offset)
            TextLabel2.TextWrapped = false
            local NewContentHeight = 13 + (13 * (TextLabel2.TextBounds.X // TextLabel2.AbsoluteSize.X))
            TextLabel2.Size = UDim2.new(1, -(ContentOffsetX + 10), 0, NewContentHeight)
            TextLabel2.TextWrapped = true

            local NeededHeight = math.max(FrameHeight, NewContentHeight + 40, IconSize + 16)
            if NeededHeight ~= FrameHeight then
                NotifyFrame.Size = UDim2.new(1, 0, 0, NeededHeight)
                IconSize = NeededHeight - 16
                NotifyIcon.Size = UDim2.new(0, IconSize, 0, IconSize)
            end
        end
        local waitbruh = false
        function NotifyFunction:Close()
            if waitbruh then
                return false
            end
            waitbruh = true
            TweenService:Create(
                NotifyFrameReal,
                TweenInfo.new(tonumber(NotifyConfig.Time), Enum.EasingStyle.Back, Enum.EasingDirection.InOut),
                { Position = UDim2.new(0, 400, 0, 0) }
            ):Play()
            task.wait(tonumber(NotifyConfig.Time) / 1.2)
            NotifyFrame:Destroy()
        end

        Close.Activated:Connect(function()
            NotifyFunction:Close()
        end)
        TweenService:Create(
            NotifyFrameReal,
            TweenInfo.new(tonumber(NotifyConfig.Time), Enum.EasingStyle.Back, Enum.EasingDirection.InOut),
            { Position = UDim2.new(0, 0, 0, 0) }
        ):Play()
        task.wait(tonumber(NotifyConfig.Delay))
        NotifyFunction:Close()
    end)
    return NotifyFunction
end

local function than(msg, delay, color, title, desc, icon)
    return Chloex:MakeNotify({
        Title = title or "OxioHub",
        Description = desc or "Notification",
        Content = msg or "Content",
        Color = color or Color3.fromRGB(235, 235, 235),
        Delay = delay or 4,
        Icon = icon or ""
    })
end

-- ==============================
-- Key System (menyatu dengan Chloex:Window lewat field `KeySystem`)
-- ==============================
-- local Window = Chloex:Window({
--     Title   = "BOLONG-HUB",
--     Image   = "84034353458936",
--     Footer  = "Violence District",
--     Author  = "Discord.gg/pWpgqVGxNK",
--     Color   = ACCENT_COLOR,
--     Version = 1,
--     Search  = true,
--     Folder  = "MyScriptName",  -- (opsional) nama unik config folder script ini.
--                                 -- Kalau kosong, default-nya pakai nama game (bisa tabrakan
--                                 -- kalau kamu punya beberapa script buat game yang sama).
--     KeySystem = {
--         Title      = "OxioHub",
--         Note       = "Masukkan key kamu di bawah ini untuk melanjutkan.",
--         Keys       = {"KEY-1234", "KEY-5678"},   -- daftar key statis (opsional)
--         Validate   = function(key) return true end, -- validator custom, mis. panggil API sendiri (opsional)
--         GetKeyLink = "https://link-kamu.com",     -- link yang di-copy saat tombol "Get Key" ditekan
--         SaveKey    = true,                        -- simpan key yang valid supaya tidak perlu input ulang
--         FileName   = "OxioHub/Config/key.txt",  -- (opsional) kalau dikosongkan/tidak diisi,
--                                                    -- otomatis jadi "OxioHub/Config/<Folder>_key.txt"
--                                                    -- sehingga key antar-script tidak tabrakan
--                                                    -- walau berada di folder/game yang sama.
--         OnFail     = function(key) end,            -- dipanggil tiap kali percobaan key gagal
--     },
-- })
local function RunKeySystemGate(KeyConfig, AccentColor, ScopeName)
    KeyConfig          = KeyConfig or {}
    KeyConfig.Title    = KeyConfig.Title or "OxioHub"
    KeyConfig.Note     = KeyConfig.Note or "Masukkan key kamu di bawah ini untuk melanjutkan."
    KeyConfig.SaveKey  = (KeyConfig.SaveKey ~= false)
    if not KeyConfig.FileName or KeyConfig.FileName == "" then
        local scope = SanitizeConfigName(ScopeName)
        if scope ~= "" then
            KeyConfig.FileName = "OxioHub/Config/" .. scope .. "_key.txt"
        else
            KeyConfig.FileName = "OxioHub/Config/key.txt"
        end
    end
    AccentColor        = KeyConfig.Color or AccentColor or Color3.fromRGB(150, 153, 160)

    local function Trim(s)
        return (tostring(s or ""):gsub("^%s*(.-)%s*$", "%1"))
    end

    local function IsValidKey(key)
        if key == "" then return false end
        if type(KeyConfig.Validate) == "function" then
            local ok, result = pcall(KeyConfig.Validate, key)
            return ok and result == true
        end
        if type(KeyConfig.Keys) == "table" then
            for _, k in ipairs(KeyConfig.Keys) do
                if tostring(k) == key then return true end
            end
        end
        return false
    end

    local function SaveValidKey(key)
        if not KeyConfig.SaveKey then return end
        local ok = pcall(function()
            EnsureFolderForFile(KeyConfig.FileName)
            writefile(KeyConfig.FileName, key)
        end)
        if not ok then
            warn("[OxioUi] Gagal menyimpan key ke " .. tostring(KeyConfig.FileName))
        end
    end

    if KeyConfig.SaveKey and isfile and isfile(KeyConfig.FileName) then
        local ok, saved = pcall(readfile, KeyConfig.FileName)
        if ok and IsValidKey(Trim(saved)) then
            return true
        end
    end

    local BKey = Instance.new("ScreenGui")
    BKey.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    BKey.Name = "BKeySystem"
    BKey.ResetOnSpawn = false
    BKey.Parent = CoreGui

    local CardSize = isMobile and safeSize(272, 178) or safeSize(300, 178)

    local ShadowHolder = Instance.new("Frame")
    ShadowHolder.BackgroundTransparency = 1
    ShadowHolder.BorderSizePixel = 0
    ShadowHolder.AnchorPoint = Vector2.new(0.5, 0.5)
    ShadowHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
    ShadowHolder.Size = CardSize
    ShadowHolder.Name = "ShadowHolder"
    ShadowHolder.Parent = BKey

    local Shadow = Instance.new("ImageLabel")
    Shadow.Image = "rbxassetid://6015897843"
    Shadow.ImageColor3 = Color3.fromRGB(22, 22, 22)
    Shadow.ImageTransparency = 0.25
    Shadow.ScaleType = Enum.ScaleType.Slice
    Shadow.SliceCenter = Rect.new(49, 49, 450, 450)
    Shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    Shadow.BackgroundTransparency = 1
    Shadow.BorderSizePixel = 0
    Shadow.Position = UDim2.new(0.5, 0, 0.5, 0)
    Shadow.Size = UDim2.new(1, 40, 1, 40)
    Shadow.Name = "Shadow"
    Shadow.Parent = ShadowHolder

    local KeyMain = Instance.new("Frame")
    KeyMain.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
    KeyMain.BorderSizePixel = 0
    KeyMain.ClipsDescendants = true
    KeyMain.AnchorPoint = Vector2.new(0.5, 0.5)
    KeyMain.Position = UDim2.new(0.5, 0, 0.5, 0)
    KeyMain.Size = UDim2.new(1, 0, 1, 0)
    KeyMain.Name = "KeyMain"
    KeyMain.Parent = Shadow

    local KeyMainCorner = Instance.new("UICorner")
    KeyMainCorner.CornerRadius = UDim.new(0, 10)
    KeyMainCorner.Parent = KeyMain

    local KeyTop = Instance.new("Frame")
    KeyTop.BackgroundTransparency = 1
    KeyTop.BorderSizePixel = 0
    KeyTop.Position = UDim2.new(0, 0, 0, 0)
    KeyTop.Size = UDim2.new(1, 0, 0, 34)
    KeyTop.Name = "Top"
    KeyTop.Parent = KeyMain

    local KeyIconHolder = Instance.new("Frame")
    KeyIconHolder.BackgroundColor3 = AccentColor
    KeyIconHolder.BackgroundTransparency = 0.85
    KeyIconHolder.BorderSizePixel = 0
    KeyIconHolder.AnchorPoint = Vector2.new(0, 0.5)
    KeyIconHolder.Position = UDim2.new(0, 10, 0.5, 0)
    KeyIconHolder.Size = UDim2.new(0, 20, 0, 20)
    KeyIconHolder.Name = "IconHolder"
    KeyIconHolder.Parent = KeyTop

    local KeyIconHolderCorner = Instance.new("UICorner")
    KeyIconHolderCorner.CornerRadius = UDim.new(0, 6)
    KeyIconHolderCorner.Parent = KeyIconHolder

    local KeyIcon = Instance.new("ImageLabel")
    KeyIcon.BackgroundTransparency = 1
    KeyIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    KeyIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    KeyIcon.Size = UDim2.new(1, -6, 1, -6)
    KeyIcon.ImageColor3 = AccentColor
    KeyIcon.Name = "Icon"
    KeyIcon.Parent = KeyIconHolder
    ApplyIcon(KeyIcon, "key-round", 64)

    local KeyTitle = Instance.new("TextLabel")
    KeyTitle.Font = Enum.Font.GothamBold
    KeyTitle.Text = KeyConfig.Title
    KeyTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
    KeyTitle.TextSize = 13
    KeyTitle.TextXAlignment = Enum.TextXAlignment.Left
    KeyTitle.TextYAlignment = Enum.TextYAlignment.Center
    KeyTitle.BackgroundTransparency = 1
    KeyTitle.AnchorPoint = Vector2.new(0, 0.5)
    KeyTitle.Position = UDim2.new(0, 38, 0.5, 0)
    KeyTitle.Size = UDim2.new(1, -74, 1, 0)
    KeyTitle.Name = "Title"
    KeyTitle.Parent = KeyTop

    local KeyClose = Instance.new("TextButton")
    KeyClose.Font = Enum.Font.SourceSans
    KeyClose.Text = ""
    KeyClose.AutoButtonColor = false
    KeyClose.BackgroundTransparency = 1
    KeyClose.BorderSizePixel = 0
    KeyClose.AnchorPoint = Vector2.new(1, 0.5)
    KeyClose.Position = UDim2.new(1, -8, 0.5, 0)
    KeyClose.Size = UDim2.new(0, 22, 0, 22)
    KeyClose.Name = "Close"
    KeyClose.Parent = KeyTop

    local KeyCloseIcon = Instance.new("ImageLabel")
    KeyCloseIcon.Image = "rbxassetid://9886659671"
    KeyCloseIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
    KeyCloseIcon.ImageTransparency = 0.25
    KeyCloseIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    KeyCloseIcon.BackgroundTransparency = 1
    KeyCloseIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    KeyCloseIcon.Size = UDim2.new(1, -8, 1, -8)
    KeyCloseIcon.Parent = KeyClose

    local closedByUser = false
    KeyClose.Activated:Connect(function()
        closedByUser = true
        BKey:Destroy()
    end)

    MakeDraggable(KeyTop, ShadowHolder)
    local KeyNote = Instance.new("TextLabel")
    KeyNote.Font = Enum.Font.Gotham
    KeyNote.Text = KeyConfig.Note
    KeyNote.TextColor3 = Color3.fromRGB(165, 165, 165)
    KeyNote.TextSize = 12
    KeyNote.TextWrapped = true
    KeyNote.TextXAlignment = Enum.TextXAlignment.Left
    KeyNote.TextYAlignment = Enum.TextYAlignment.Top
    KeyNote.BackgroundTransparency = 1
    KeyNote.Position = UDim2.new(0, 12, 0, 40)
    KeyNote.Size = UDim2.new(1, -24, 0, 32)
    KeyNote.Name = "Note"
    KeyNote.Parent = KeyMain

    local InputHolder = Instance.new("Frame")
    InputHolder.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    InputHolder.BorderSizePixel = 0
    InputHolder.Position = UDim2.new(0, 12, 0, 78)
    InputHolder.Size = UDim2.new(1, -24, 0, 32)
    InputHolder.Name = "InputHolder"
    InputHolder.Parent = KeyMain

    local InputHolderCorner = Instance.new("UICorner")
    InputHolderCorner.CornerRadius = UDim.new(0, 6)
    InputHolderCorner.Parent = InputHolder

    local InputStroke = Instance.new("UIStroke")
    InputStroke.Color = Color3.fromRGB(57, 57, 57)
    InputStroke.Thickness = 1
    InputStroke.Parent = InputHolder

    local KeyInput = Instance.new("TextBox")
    KeyInput.Font = Enum.Font.Gotham
    KeyInput.PlaceholderText = "Masukkan key..."
    KeyInput.PlaceholderColor3 = Color3.fromRGB(110, 110, 110)
    KeyInput.Text = ""
    KeyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    KeyInput.TextSize = 12
    KeyInput.ClearTextOnFocus = false
    KeyInput.TextXAlignment = Enum.TextXAlignment.Left
    KeyInput.BackgroundTransparency = 1
    KeyInput.Position = UDim2.new(0, 10, 0, 0)
    KeyInput.Size = UDim2.new(1, -20, 1, 0)
    KeyInput.Name = "KeyInput"
    KeyInput.Parent = InputHolder

    local GetKeyBtn = Instance.new("TextButton")
    GetKeyBtn.Font = Enum.Font.GothamBold
    GetKeyBtn.Text = "Get Key"
    GetKeyBtn.TextColor3 = Color3.fromRGB(230, 230, 230)
    GetKeyBtn.TextSize = 12
    GetKeyBtn.AutoButtonColor = false
    GetKeyBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    GetKeyBtn.BorderSizePixel = 0
    GetKeyBtn.Position = UDim2.new(0, 12, 0, 118)
    GetKeyBtn.Size = UDim2.new(0.5, -16, 0, 30)
    GetKeyBtn.Name = "GetKeyBtn"
    GetKeyBtn.Parent = KeyMain

    local GetKeyBtnCorner = Instance.new("UICorner")
    GetKeyBtnCorner.CornerRadius = UDim.new(0, 6)
    GetKeyBtnCorner.Parent = GetKeyBtn

    local SubmitBtn = Instance.new("TextButton")
    SubmitBtn.Font = Enum.Font.GothamBold
    SubmitBtn.Text = "Verify"
    SubmitBtn.TextColor3 = Color3.fromRGB(27, 27, 27)
    SubmitBtn.TextSize = 12
    SubmitBtn.AutoButtonColor = false
    SubmitBtn.BackgroundColor3 = AccentColor
    SubmitBtn.BorderSizePixel = 0
    SubmitBtn.Position = UDim2.new(0.5, 4, 0, 118)
    SubmitBtn.Size = UDim2.new(0.5, -16, 0, 30)
    SubmitBtn.Name = "SubmitBtn"
    SubmitBtn.Parent = KeyMain

    local SubmitBtnCorner = Instance.new("UICorner")
    SubmitBtnCorner.CornerRadius = UDim.new(0, 6)
    SubmitBtnCorner.Parent = SubmitBtn

    GetKeyBtn.MouseEnter:Connect(function()
        TweenService:Create(GetKeyBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(50, 50, 50) }):Play()
    end)
    GetKeyBtn.MouseLeave:Connect(function()
        TweenService:Create(GetKeyBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(40, 40, 40) }):Play()
    end)

    GetKeyBtn.Activated:Connect(function()
        if KeyConfig.GetKeyLink and KeyConfig.GetKeyLink ~= "" then
            if setclipboard then
                setclipboard(KeyConfig.GetKeyLink)
                than("Link disalin ke clipboard, buka di browser untuk mendapatkan key.", 5, AccentColor,
                    KeyConfig.Title, "Key System")
            else
                than("Executor kamu tidak mendukung setclipboard.", 4, Color3.fromRGB(255, 90, 90), KeyConfig.Title,
                    "Key System")
            end
        else
            than("Belum ada link key yang diatur.", 4, Color3.fromRGB(255, 90, 90), KeyConfig.Title, "Key System")
        end
    end)

    local resolved, checking = false, false
    local function AttemptSubmit()
        if checking then return end
        local key = Trim(KeyInput.Text)
        if key == "" then
            than("Masukkan key terlebih dahulu.", 3, Color3.fromRGB(255, 170, 0), KeyConfig.Title, "Key System")
            return
        end

        checking = true
        SubmitBtn.Text = "..."
        local valid = IsValidKey(key)
        checking = false
        SubmitBtn.Text = "Verify"

        if valid then
            than("Key valid, selamat datang!", 4, AccentColor, KeyConfig.Title, "Key System")
            SaveValidKey(key)
            resolved = true
            BKey:Destroy()
        else
            than("Key salah atau sudah tidak berlaku.", 4, Color3.fromRGB(255, 90, 90), KeyConfig.Title, "Key System")
            if type(KeyConfig.OnFail) == "function" then
                pcall(KeyConfig.OnFail, key)
            end
        end
    end

    SubmitBtn.Activated:Connect(AttemptSubmit)
    KeyInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then AttemptSubmit() end
    end)

    KeyMain.BackgroundTransparency = 1
    ShadowHolder.Size = UDim2.new(CardSize.X.Scale, CardSize.X.Offset * 0.94, CardSize.Y.Scale, CardSize.Y.Offset * 0.94)
    TweenService:Create(ShadowHolder, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = CardSize }):Play()
    TweenService:Create(KeyMain, TweenInfo.new(0.18), { BackgroundTransparency = 0 }):Play()

    repeat
        task.wait()
    until resolved or closedByUser

    return resolved
end

function Chloex:Window(GuiConfig)
    GuiConfig              = GuiConfig or {}
    GuiConfig.Title        = GuiConfig.Title or "OxioHub"
    GuiConfig.Image        = GuiConfig.Image or "98140353767645"
    GuiConfig.Footer       = GuiConfig.Footer or ""
    GuiConfig.Author       = GuiConfig.Author or ""
    GuiConfig.Color        = GuiConfig.Color or Color3.fromRGB(150, 153, 160)
    GuiConfig["Tab Width"] = GuiConfig["Tab Width"] or 120
    GuiConfig.Version      = GuiConfig.Version or 1
    GuiConfig.LogoButtonSize = GuiConfig.LogoButtonSize or 50
    if GuiConfig.Search == nil then GuiConfig.Search = true end
    if GuiConfig.ShowInfo == nil then GuiConfig.ShowInfo = false end

    local FolderScope = SanitizeConfigName(GuiConfig.Folder)
    if FolderScope == "" then FolderScope = gameName end
    GuiConfig.Folder = FolderScope

    ConfigFile        = "OxioHub/Config/" .. FolderScope .. ".json"
    GameConfigFolder  = ConfigFolder .. "/" .. FolderScope

    if GuiConfig.KeySystem then
        local passed = RunKeySystemGate(GuiConfig.KeySystem, GuiConfig.Color, GuiConfig.Folder)
        if not passed then
            return nil
        end
    end

    CURRENT_VERSION        = GuiConfig.Version
    LoadConfigFromFile()

    local GuiFunc = {}

    local SearchRegistry = {}
    local TabRegistry = {}

    local function SmartMatch(query, target)
        if query == "" then return 0 end
        local q, t = string.lower(query), string.lower(target)
        if q == t then return 1000 end
        if string.sub(t, 1, #q) == q then return 800 end
        local idx = string.find(t, q, 1, true)
        if idx then return 600 - idx end
        local qi, ti, lastIdx = 1, 1, 0
        while qi <= #q and ti <= #t do
            if string.sub(q, qi, qi) == string.sub(t, ti, ti) then
                lastIdx = ti
                qi = qi + 1
            end
            ti = ti + 1
        end
        if qi > #q then
            return 200 - (lastIdx - #q) * 2
        end
        return 0
    end

    local function RegisterSearch(entry)
        table.insert(SearchRegistry, entry)
    end

    local function ExtractConfigPayload(payload)
        local data = payload
        if type(payload.Data) == "table" then
            data = payload.Data
        elseif type(payload.Config) == "table" then
            data = payload.Config
        elseif type(payload.Settings) == "table" then
            data = payload.Settings
        end

        if type(data) ~= "table" then return nil end

        local cleaned = {}
        for key, value in pairs(data) do
            if key ~= "_version"
                and key ~= "Game"
                and key ~= "Version"
                and key ~= "PlaceId"
                and key ~= "Hub"
                and key ~= "SavedAt"
                and key ~= "ActiveConfig"
                and key ~= "AutoLoad"
                and not InternalConfigKeys[key] then
                cleaned[key] = value
            end
        end

        return cleaned
    end

    local function ApplyConfigData(data)
        ApplyingConfig = true
        ConfigData = { _version = CURRENT_VERSION }

        for key, value in pairs(data) do
            ConfigData[key] = value
            if Elements[key] and Elements[key].Set then
                local ok, err = pcall(function()
                    Elements[key]:Set(value, true)
                end)
                if not ok then
                    warn("ApplyConfigData failed for '" .. tostring(key) .. "':", err)
                end
            end
        end

        ConfigData._version = CURRENT_VERSION
        ApplyingConfig = false
    end

    function GuiFunc:ExportConfig()
        local payload = HttpService:JSONEncode({
            Hub = "OxioHub",
            Game = gameName,
            PlaceId = game.PlaceId,
            Version = CURRENT_VERSION,
            ActiveConfig = ActiveConfigName or "",
            AutoLoad = GuiFunc:GetAutoLoad(),
            Data = GetConfigSnapshot(),
        })
        if setclipboard then
            setclipboard(payload)
            than("Config copied to clipboard", 4, GuiConfig.Color, "OxioHub", "Export")
        end
        return payload
    end

    function GuiFunc:ImportConfig(str)
        if not str or str == "" then
            than("Paste a config string first", 4, Color3.fromRGB(255, 90, 90), "OxioHub", "Import")
            return false
        end
        local ok, dec = pcall(function() return HttpService:JSONDecode(str) end)
        if not ok or type(dec) ~= "table" then
            than("Invalid config format", 4, Color3.fromRGB(255, 90, 90), "OxioHub", "Import")
            return false
        end
        local data = ExtractConfigPayload(dec)
        if not data then
            than("Config data is empty", 4, Color3.fromRGB(255, 90, 90), "OxioHub", "Import")
            return false
        end

        ApplyConfigData(data)
        QueueSaveConfig(AutoSaveEnabled)
        than("Config imported", 4, GuiConfig.Color, "OxioHub", "Import")
        return true
    end

    local function EnsureConfigFolder()
        if not isfolder("OxioHub") then makefolder("OxioHub") end
        if not isfolder(ConfigFolder) then makefolder(ConfigFolder) end
        if not isfolder(GameConfigFolder) then makefolder(GameConfigFolder) end
    end

    function GuiFunc:GetConfigs()
        local out = {}
        if not listfiles then return out end
        EnsureConfigFolder()
        for _, f in ipairs(listfiles(GameConfigFolder)) do
            local n = string.match(f, "([^/\\]+)%.json$")
            if n and n ~= "_autoload" then
                table.insert(out, n)
            end
        end
        return out
    end

    function GuiFunc:SaveConfigAs(name)
        if not name or name == "" then
            than("Enter a config name first", 4, Color3.fromRGB(255, 90, 90), "OxioHub", "Config")
            return false
        end
        if not writefile then return false end
        EnsureConfigFolder()
        local path = GameConfigFolder .. "/" .. name .. ".json"

        local ok, encoded = pcall(function() return HttpService:JSONEncode(GetConfigSnapshot()) end)
        if not ok then
            warn("SaveConfigAs failed to encode config:", encoded)
            than("Failed to save config", 4, Color3.fromRGB(255, 90, 90), "OxioHub", "Config")
            return false
        end

        writefile(path, encoded)
        SetActiveConfig(name, path, false, "saved")
        than("Saved '" .. name .. "'", 4, GuiConfig.Color, "OxioHub", "Config")
        return true
    end

    function GuiFunc:LoadConfigByName(name)
        if not name or name == "" then return false end
        local path = GameConfigFolder .. "/" .. name .. ".json"
        if not (isfile and isfile(path)) then
            than("Config '" .. tostring(name) .. "' not found", 4, Color3.fromRGB(255, 90, 90), "OxioHub", "Config")
            return false
        end
        local ok, dec = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
        if not ok or type(dec) ~= "table" then
            than("Failed to read config", 4, Color3.fromRGB(255, 90, 90), "OxioHub", "Config")
            return false
        end
        local data = ExtractConfigPayload(dec)
        if not data then
            than("Config data is empty", 4, Color3.fromRGB(255, 90, 90), "OxioHub", "Config")
            return false
        end

        ApplyConfigData(data)
        SetActiveConfig(name, path, false, "manual")
        than("Loaded '" .. name .. "'", 4, GuiConfig.Color, "OxioHub", "Config")
        return true
    end

    function GuiFunc:DeleteConfig(name)
        local path = GameConfigFolder .. "/" .. name .. ".json"
        if isfile and isfile(path) and delfile then
            delfile(path)
            if ActiveConfigName == name then
                SetActiveConfig(nil, nil, false, nil)
            end
            if GuiFunc:GetAutoLoad() == name then
                GuiFunc:SetAutoLoad("")
            end
            than("Deleted '" .. name .. "'", 4, Color3.fromRGB(255, 170, 0), "OxioHub", "Config")
            return true
        end
        return false
    end

    function GuiFunc:SetAutoLoad(name)
        if not writefile then return end
        EnsureConfigFolder()
        name = name or ""
        writefile(GameConfigFolder .. "/_autoload.json", HttpService:JSONEncode({ Name = name }))
    end

    function GuiFunc:GetAutoLoad()
        local path = GameConfigFolder .. "/_autoload.json"
        if isfile and isfile(path) then
            local ok, dec = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
            if ok and type(dec) == "table" then return dec.Name or "" end
        end
        return ""
    end

    local BHub = Instance.new("ScreenGui");
    local DropShadowHolder = Instance.new("Frame");
    local DropShadow = Instance.new("ImageLabel");
    local Main = Instance.new("Frame");
    local UICorner = Instance.new("UICorner");
    local Top = Instance.new("Frame");
    local TextLabel = Instance.new("TextLabel");
    local UICorner1 = Instance.new("UICorner");
    local TextLabel1 = Instance.new("TextLabel");
    local Close = Instance.new("TextButton");
    local ImageLabel1 = Instance.new("ImageLabel");
    local Min = Instance.new("TextButton");
    local ImageLabel2 = Instance.new("ImageLabel");
    local LayersTab = Instance.new("Frame");
    local UICorner2 = Instance.new("UICorner");
    local DecideFrame = Instance.new("Frame");
    local Layers = Instance.new("Frame");
    local UICorner6 = Instance.new("UICorner");
    local NameTab = Instance.new("TextLabel");
    local LayersReal = Instance.new("Frame");
    local LayersFolder = Instance.new("Folder");
    local LayersPageLayout = Instance.new("UIPageLayout");

    BHub.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    BHub.Name = "BHub"
    BHub.ResetOnSpawn = false
    BHub.Parent = game:GetService("CoreGui")

    DropShadowHolder.BackgroundTransparency = 1
    DropShadowHolder.BorderSizePixel = 0
    DropShadowHolder.AnchorPoint = Vector2.new(0.5, 0.5)
    DropShadowHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
    if isMobile then
        DropShadowHolder.Size = safeSize(470, 270)
    else
        DropShadowHolder.Size = safeSize(640, 400)
    end
    DropShadowHolder.ZIndex = 0
    DropShadowHolder.Name = "DropShadowHolder"
    DropShadowHolder.Parent = BHub

    DropShadowHolder.Position = UDim2.new(0, (BHub.AbsoluteSize.X // 2 - DropShadowHolder.Size.X.Offset // 2), 0,
        (BHub.AbsoluteSize.Y // 2 - DropShadowHolder.Size.Y.Offset // 2))
    DropShadow.Image = "rbxassetid://6015897843"
    DropShadow.ImageColor3 = Color3.fromRGB(22, 22, 22)
    DropShadow.ImageTransparency = 1
    DropShadow.ScaleType = Enum.ScaleType.Slice
    DropShadow.SliceCenter = Rect.new(49, 49, 450, 450)
    DropShadow.AnchorPoint = Vector2.new(0.5, 0.5)
    DropShadow.BackgroundTransparency = 1
    DropShadow.BorderSizePixel = 0
    DropShadow.Position = UDim2.new(0.5, 0, 0.5, 0)
    DropShadow.Size = UDim2.new(1, 47, 1, 47)
    DropShadow.ZIndex = 0
    DropShadow.Name = "DropShadow"
    DropShadow.Parent = DropShadowHolder

    if GuiConfig.Theme then
        Main:Destroy()
        Main = Instance.new("ImageLabel")
        Main.Image = "rbxassetid://" .. GuiConfig.Theme
        Main.ScaleType = Enum.ScaleType.Crop
        Main.BackgroundTransparency = 1
        Main.ImageTransparency = GuiConfig.ThemeTransparency or 0.15
    else
        Main.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
        Main.BackgroundTransparency = 0.12
    end

    Main.AnchorPoint = Vector2.new(0.5, 0.5)
    Main.BorderColor3 = Color3.fromRGB(27, 27, 27)
    Main.BorderSizePixel = 0
    Main.Position = UDim2.new(0.5, 0, 0.5, 0)
    Main.Size = UDim2.new(1, -47, 1, -47)
    Main.Name = "Main"
    Main.Parent = DropShadow

    UICorner.Parent = Main

    Top.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
    Top.BackgroundTransparency = 0.9990000128746033
    Top.BorderColor3 = Color3.fromRGB(27, 27, 27)
    Top.BorderSizePixel = 0
    Top.Size = UDim2.new(1, 0, 0, 38)
    Top.Name = "Top"
    Top.Parent = Main

    local HeaderRow1Y = 14
    local HeaderRow2Y = 27

    TextLabel.Font = Enum.Font.GothamBold
    TextLabel.Text = GuiConfig.Title
    TextLabel.TextColor3 = GuiConfig.Color
    TextLabel.TextSize = 14
    TextLabel.TextXAlignment = Enum.TextXAlignment.Left
    TextLabel.TextYAlignment = Enum.TextYAlignment.Center
    TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    TextLabel.BackgroundTransparency = 0.9990000128746033
    TextLabel.BorderColor3 = Color3.fromRGB(27, 27, 27)
    TextLabel.BorderSizePixel = 0
    TextLabel.AnchorPoint = Vector2.new(0, 0.5)
    TextLabel.Size = UDim2.new(1, -100, 0, 16)
    TextLabel.Position = UDim2.new(0, 10, 0, HeaderRow1Y)
    TextLabel.Parent = Top

    UICorner1.Parent = Top

    local DiscordDivider, DiscordImg, DiscordBtn
    local discordOffset = 0
    local DiscordButtonRef = nil
    if GuiConfig.Discord and GuiConfig.Discord ~= "" then
        DiscordDivider = Instance.new("Frame")
        DiscordDivider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        DiscordDivider.BackgroundTransparency = 0.75
        DiscordDivider.BorderSizePixel = 0
        DiscordDivider.AnchorPoint = Vector2.new(0, 0.5)
        DiscordDivider.Size = UDim2.new(0, 1, 0, 16)
        DiscordDivider.Name = "DiscordDivider"
        DiscordDivider.Parent = Top

        local DividerCorner = Instance.new("UICorner")
        DividerCorner.CornerRadius = UDim.new(1, 0)
        DividerCorner.Parent = DiscordDivider

        DiscordImg = Instance.new("ImageLabel")
        DiscordImg.Image = discord_logo_asset_id
        DiscordImg.ImageColor3 = Color3.fromRGB(88, 101, 242)
        DiscordImg.BackgroundTransparency = 1
        DiscordImg.ScaleType = Enum.ScaleType.Fit
        DiscordImg.AnchorPoint = Vector2.new(0, 0.5)
        DiscordImg.Size = UDim2.new(0, 16, 0, 16)
        DiscordImg.Name = "DiscordImg"
        DiscordImg.Parent = Top

        DiscordBtn = Instance.new("TextButton")
        DiscordBtn.Text = ""
        DiscordBtn.AutoButtonColor = false
        DiscordBtn.BackgroundTransparency = 1
        DiscordBtn.BorderSizePixel = 0
        DiscordBtn.AnchorPoint = Vector2.new(0, 0.5)
        DiscordBtn.Size = UDim2.new(0, 0, 0, 16)
        DiscordBtn.Name = "DiscordBtn"
        DiscordBtn.Parent = Top

        DiscordBtn.MouseEnter:Connect(function()
            TweenService:Create(DiscordImg, TweenInfo.new(0.2), { ImageColor3 = Color3.fromRGB(120, 132, 255) }):Play()
            TweenService:Create(DiscordDivider, TweenInfo.new(0.2), { BackgroundTransparency = 0.5 }):Play()
        end)
        DiscordBtn.MouseLeave:Connect(function()
            TweenService:Create(DiscordImg, TweenInfo.new(0.2), { ImageColor3 = Color3.fromRGB(88, 101, 242) }):Play()
            TweenService:Create(DiscordDivider, TweenInfo.new(0.2), { BackgroundTransparency = 0.75 }):Play()
        end)
        DiscordBtn.Activated:Connect(function()
            if setclipboard then
                setclipboard(GuiConfig.Discord)
                than("Discord invite copied", 4, GuiConfig.Color, "OxioHub", "Community")
            end
        end)

        discordOffset = 36
        DiscordButtonRef = DiscordBtn
    end

    local TitleAuthorDivider
    local authorOffset = 0
    if GuiConfig.Author and GuiConfig.Author ~= "" then
        TitleAuthorDivider = Instance.new("Frame")
        TitleAuthorDivider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        TitleAuthorDivider.BackgroundTransparency = 0.75
        TitleAuthorDivider.BorderSizePixel = 0
        TitleAuthorDivider.AnchorPoint = Vector2.new(0, 0.5)
        TitleAuthorDivider.Size = UDim2.new(0, 1, 0, 16)
        TitleAuthorDivider.Name = "TitleAuthorDivider"
        TitleAuthorDivider.Parent = Top

        local TitleAuthorDividerCorner = Instance.new("UICorner")
        TitleAuthorDividerCorner.CornerRadius = UDim.new(1, 0)
        TitleAuthorDividerCorner.Parent = TitleAuthorDivider

        authorOffset = 7.5
    end

    TextLabel1.Font = Enum.Font.GothamBold
    TextLabel1.Text = GuiConfig.Author
    TextLabel1.TextColor3 = Color3.fromRGB(255, 255, 255)
    TextLabel1.TextSize = 14
    TextLabel1.TextTransparency = 0
    TextLabel1.TextXAlignment = Enum.TextXAlignment.Left
    TextLabel1.TextYAlignment = Enum.TextYAlignment.Center
    TextLabel1.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    TextLabel1.BackgroundTransparency = 0.9990000128746033
    TextLabel1.BorderColor3 = Color3.fromRGB(27, 27, 27)
    TextLabel1.BorderSizePixel = 0
    TextLabel1.AnchorPoint = Vector2.new(0, 0.5)
    TextLabel1.Size = UDim2.new(1, -(TextLabel.TextBounds.X + 104 + discordOffset + authorOffset), 0, 16)
    TextLabel1.Name = "AuthorLabel"
    TextLabel1.Parent = Top

    -- Fungsi untuk merapikan posisi Title, Author, dan Divider secara dinamis
    local function UpdateHeaderLayout()
        local titleBoundsX = TextLabel.TextBounds.X
        local authorBoundsX = TextLabel1.TextBounds.X

        if GuiConfig.Discord and GuiConfig.Discord ~= "" then
            local discordBaseX = titleBoundsX + 18
            DiscordDivider.Position = UDim2.new(0, discordBaseX, 0, HeaderRow1Y)
            DiscordImg.Position = UDim2.new(0, discordBaseX + 10, 0, HeaderRow1Y)
            DiscordBtn.Position = UDim2.new(0, discordBaseX + 8, 0, HeaderRow1Y)
            DiscordBtn.Size = UDim2.new(0, discordOffset + authorBoundsX + 6, 0, 16)
        end

        if GuiConfig.Author and GuiConfig.Author ~= "" then
            local titleAuthorDividerX = titleBoundsX + 15 + discordOffset
            TitleAuthorDivider.Position = UDim2.new(0, titleAuthorDividerX, 0, HeaderRow1Y)
        end

        TextLabel1.Size = UDim2.new(1, -(titleBoundsX + 104 + discordOffset + authorOffset), 0, 16)
        TextLabel1.Position = UDim2.new(0, titleBoundsX + 15 + discordOffset + authorOffset, 0, HeaderRow1Y)

        -- Atur lebar dan tinggi dinamis sesuai device
        local defHeight = isMobile and 315 or 400
        local targetWidth = 115 + titleBoundsX + 1 + authorBoundsX
        if not isMobile then
            if targetWidth < 500 then targetWidth = 500 end -- Minimal lebar PC
        else
            if targetWidth < 490 then targetWidth = 490 end -- Minimal lebar Mobile
        end
        
        DropShadowHolder.Size = UDim2.new(0, targetWidth, 0, defHeight)
    end

    TextLabel:GetPropertyChangedSignal("TextBounds"):Connect(UpdateHeaderLayout)
    TextLabel1:GetPropertyChangedSignal("TextBounds"):Connect(UpdateHeaderLayout)
    
    task.spawn(function()
        task.wait()
        UpdateHeaderLayout()
    end)

    local FooterLabel = Instance.new("TextLabel")
    FooterLabel.Font = Enum.Font.GothamBold
    FooterLabel.Text = GuiConfig.Footer
    FooterLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    FooterLabel.TextTransparency = 0.4
    FooterLabel.TextSize = 12
    FooterLabel.TextXAlignment = Enum.TextXAlignment.Left
    FooterLabel.TextYAlignment = Enum.TextYAlignment.Center
    FooterLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    FooterLabel.BackgroundTransparency = 1
    FooterLabel.BorderColor3 = Color3.fromRGB(27, 27, 27)
    FooterLabel.BorderSizePixel = 0
    FooterLabel.AnchorPoint = Vector2.new(0, 0.5)
    FooterLabel.Size = UDim2.new(1, -100, 0, 14)
    FooterLabel.Position = UDim2.new(0, 10, 0, HeaderRow2Y)
    FooterLabel.Name = "FooterLabel"
    FooterLabel.Parent = Top

    Close.Font = Enum.Font.SourceSans
    Close.Text = ""
    Close.TextColor3 = Color3.fromRGB(27, 27, 27)
    Close.TextSize = 14
    Close.AnchorPoint = Vector2.new(1, 0.5)
    Close.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Close.BackgroundTransparency = 0.9990000128746033
    Close.BorderColor3 = Color3.fromRGB(27, 27, 27)
    Close.BorderSizePixel = 0
    Close.Position = UDim2.new(1, -8, 0.5, 0)
    Close.Size = UDim2.new(0, 25, 0, 25)
    Close.Name = "Close"
    Close.Parent = Top

    ImageLabel1.Image = "rbxassetid://9886659671"
    ImageLabel1.AnchorPoint = Vector2.new(0.5, 0.5)
    ImageLabel1.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ImageLabel1.BackgroundTransparency = 0.9990000128746033
    ImageLabel1.BorderColor3 = Color3.fromRGB(27, 27, 27)
    ImageLabel1.BorderSizePixel = 0
    ImageLabel1.Position = UDim2.new(0.49, 0, 0.5, 0)
    ImageLabel1.Size = UDim2.new(1, -8, 1, -8)
    ImageLabel1.Parent = Close

    Min.Font = Enum.Font.SourceSans
    Min.Text = ""
    Min.TextColor3 = Color3.fromRGB(27, 27, 27)
    Min.TextSize = 14
    Min.AnchorPoint = Vector2.new(1, 0.5)
    Min.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Min.BackgroundTransparency = 0.9990000128746033
    Min.BorderColor3 = Color3.fromRGB(27, 27, 27)
    Min.BorderSizePixel = 0
    Min.Position = UDim2.new(1, -38, 0.5, 0)
    Min.Size = UDim2.new(0, 25, 0, 25)
    Min.Name = "Min"
    Min.Parent = Top

    ImageLabel2.Image = "rbxassetid://9886659276"
    ImageLabel2.AnchorPoint = Vector2.new(0.5, 0.5)
    ImageLabel2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ImageLabel2.BackgroundTransparency = 0.9990000128746033
    ImageLabel2.ImageTransparency = 0.2
    ImageLabel2.BorderColor3 = Color3.fromRGB(27, 27, 27)
    ImageLabel2.BorderSizePixel = 0
    ImageLabel2.Position = UDim2.new(0.5, 0, 0.5, 0)
    ImageLabel2.Size = UDim2.new(1, -9, 1, -9)
    ImageLabel2.Parent = Min

    LayersTab.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    LayersTab.BackgroundTransparency = 0.9990000128746033
    LayersTab.BorderColor3 = Color3.fromRGB(27, 27, 27)
    LayersTab.BorderSizePixel = 0
    LayersTab.Position = UDim2.new(0, 9, 0, 50)
    LayersTab.Size = UDim2.new(0, GuiConfig["Tab Width"], 1, -59)
    LayersTab.Name = "LayersTab"
    LayersTab.Parent = Main

    UICorner2.CornerRadius = UDim.new(0, 2)
    UICorner2.Parent = LayersTab

    DecideFrame.AnchorPoint = Vector2.new(0.5, 0)
    DecideFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    DecideFrame.BackgroundTransparency = 0.85
    DecideFrame.BorderColor3 = Color3.fromRGB(27, 27, 27)
    DecideFrame.BorderSizePixel = 0
    DecideFrame.Position = UDim2.new(0.5, 0, 0, 38)
    DecideFrame.Size = UDim2.new(1, 0, 0, 1)
    DecideFrame.Name = "DecideFrame"
    DecideFrame.Parent = Main

    Layers.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Layers.BackgroundTransparency = 0.9990000128746033
    Layers.BorderColor3 = Color3.fromRGB(27, 27, 27)
    Layers.BorderSizePixel = 0
    Layers.Position = UDim2.new(0, GuiConfig["Tab Width"] + 18, 0, 50)
    Layers.Size = UDim2.new(1, -(GuiConfig["Tab Width"] + 9 + 18), 1, -59)
    Layers.Name = "Layers"
    Layers.Parent = Main

    UICorner6.CornerRadius = UDim.new(0, 2)
    UICorner6.Parent = Layers

    NameTab.Font = Enum.Font.GothamBold
    NameTab.Text = ""
    NameTab.TextColor3 = Color3.fromRGB(255, 255, 255)
    NameTab.TextSize = 24
    NameTab.TextWrapped = true
    NameTab.TextXAlignment = Enum.TextXAlignment.Left
    NameTab.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    NameTab.BackgroundTransparency = 0.9990000128746033
    NameTab.BorderColor3 = Color3.fromRGB(27, 27, 27)
    NameTab.BorderSizePixel = 0
    NameTab.Size = UDim2.new(1, 0, 0, 30)
    NameTab.Name = "NameTab"
    NameTab.Parent = Layers

    LayersReal.AnchorPoint = Vector2.new(0, 1)
    LayersReal.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    LayersReal.BackgroundTransparency = 0.9990000128746033
    LayersReal.BorderColor3 = Color3.fromRGB(27, 27, 27)
    LayersReal.BorderSizePixel = 0
    LayersReal.ClipsDescendants = true
    LayersReal.Position = UDim2.new(0, 0, 1, 0)
    LayersReal.Size = UDim2.new(1, 0, 1, -33)
    LayersReal.Name = "LayersReal"
    LayersReal.Parent = Layers

    LayersFolder.Name = "LayersFolder"
    LayersFolder.Parent = LayersReal

    LayersPageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    LayersPageLayout.Name = "LayersPageLayout"
    LayersPageLayout.Parent = LayersFolder
    LayersPageLayout.TweenTime = 0.5
    LayersPageLayout.EasingDirection = Enum.EasingDirection.InOut
    LayersPageLayout.EasingStyle = Enum.EasingStyle.Quad

    local ScrollTab = Instance.new("ScrollingFrame");
    local UIListLayout = Instance.new("UIListLayout");

    ScrollTab.CanvasSize = UDim2.new(0, 0, 1.10000002, 0)
    ScrollTab.ScrollBarImageColor3 = Color3.fromRGB(27, 27, 27)
    ScrollTab.ScrollBarThickness = 0
    ScrollTab.Active = true
    ScrollTab.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ScrollTab.BackgroundTransparency = 0.9990000128746033
    ScrollTab.BorderColor3 = Color3.fromRGB(27, 27, 27)
    ScrollTab.BorderSizePixel = 0
    if GuiConfig.Search then
        ScrollTab.Position = UDim2.new(0, 0, 0, 34)
        ScrollTab.Size = UDim2.new(1, 0, 1, -34 - (GuiConfig.ShowInfo and 44 or 0))
    else
        ScrollTab.Size = UDim2.new(1, 0, 1, -(GuiConfig.ShowInfo and 44 or 0))
    end
    ScrollTab.Name = "ScrollTab"
    ScrollTab.Parent = LayersTab

    UIListLayout.Padding = UDim.new(0, 3)
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Parent = ScrollTab

    local function UpdateSize1()
        local OffsetY = 0
        for _, child in ScrollTab:GetChildren() do
            if child.Name ~= "UIListLayout" then
                OffsetY = OffsetY + 3 + child.Size.Y.Offset
            end
        end
        ScrollTab.CanvasSize = UDim2.new(0, 0, 0, OffsetY)
    end
    ScrollTab.ChildAdded:Connect(UpdateSize1)
    ScrollTab.ChildRemoved:Connect(UpdateSize1)

    if GuiConfig.ShowInfo then
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer

        local DisplayName = LocalPlayer.DisplayName
        local UserName = LocalPlayer.Name

        local InfoTitle
        if DisplayName == UserName then
            InfoTitle = string.sub(UserName, 1, 2) .. "****"
        else
            InfoTitle = DisplayName
        end

        local InfoPanel = Instance.new("Frame")
        InfoPanel.Name = "UserInfoPanel"
        InfoPanel.AnchorPoint = Vector2.new(0, 1)
        InfoPanel.Position = UDim2.new(0, 0, 1, 0)
        InfoPanel.Size = UDim2.new(1, 0, 0, 44)
        InfoPanel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        InfoPanel.BackgroundTransparency = 0.9990000128746033
        InfoPanel.BorderSizePixel = 0
        InfoPanel.Parent = LayersTab

        local InfoDivider = Instance.new("Frame")
        InfoDivider.Name = "InfoDivider"
        InfoDivider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        InfoDivider.BackgroundTransparency = 0.9
        InfoDivider.BorderSizePixel = 0
        InfoDivider.Size = UDim2.new(1, -12, 0, 1)
        InfoDivider.Position = UDim2.new(0, 6, 0, 0)
        InfoDivider.Parent = InfoPanel

        local InfoAvatar = Instance.new("ImageLabel")
        InfoAvatar.Name = "InfoAvatar"
        InfoAvatar.AnchorPoint = Vector2.new(0, 0.5)
        InfoAvatar.Position = UDim2.new(0, 8, 0.5, 2)
        InfoAvatar.Size = UDim2.new(0, 30, 0, 30)
        InfoAvatar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        InfoAvatar.BorderSizePixel = 0
        InfoAvatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150"
        InfoAvatar.Parent = InfoPanel

        local InfoAvatarCorner = Instance.new("UICorner")
        InfoAvatarCorner.CornerRadius = UDim.new(1, 0)
        InfoAvatarCorner.Parent = InfoAvatar

        local InfoTitleLabel = Instance.new("TextLabel")
        InfoTitleLabel.Name = "InfoTitle"
        InfoTitleLabel.Font = Enum.Font.GothamBold
        InfoTitleLabel.Text = InfoTitle
        InfoTitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        InfoTitleLabel.TextSize = 13
        InfoTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        InfoTitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
        InfoTitleLabel.BackgroundTransparency = 1
        InfoTitleLabel.AnchorPoint = Vector2.new(0, 0.5)
        InfoTitleLabel.Position = UDim2.new(0, 46, 0.5, -8)
        InfoTitleLabel.Size = UDim2.new(1, -54, 0, 16)
        InfoTitleLabel.Parent = InfoPanel

        local InfoSubLabel = Instance.new("TextLabel")
        InfoSubLabel.Name = "InfoSub"
        InfoSubLabel.Font = Enum.Font.Gotham
        InfoSubLabel.Text = "Welcome"
        InfoSubLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        InfoSubLabel.TextSize = 11
        InfoSubLabel.TextXAlignment = Enum.TextXAlignment.Left
        InfoSubLabel.TextTruncate = Enum.TextTruncate.AtEnd
        InfoSubLabel.BackgroundTransparency = 1
        InfoSubLabel.AnchorPoint = Vector2.new(0, 0.5)
        InfoSubLabel.Position = UDim2.new(0, 46, 0.5, 8)
        InfoSubLabel.Size = UDim2.new(1, -54, 0, 14)
        InfoSubLabel.Parent = InfoPanel
    end

    local SearchResults, SearchResultsLayout, SearchBox
    if GuiConfig.Search then
        local SearchBar = Instance.new("Frame")
        SearchBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        SearchBar.BackgroundTransparency = 0.93
        SearchBar.BorderSizePixel = 0
        SearchBar.Position = UDim2.new(0, 0, 0, 0)
        SearchBar.Size = UDim2.new(1, 0, 0, 28)
        SearchBar.Name = "SearchBar"
        SearchBar.Parent = LayersTab

        local SearchCorner = Instance.new("UICorner")
        SearchCorner.CornerRadius = UDim.new(0, 4)
        SearchCorner.Parent = SearchBar

        local SearchIcon = Instance.new("ImageLabel")
        ApplyIcon(SearchIcon, "search", 24)
        SearchIcon.ImageColor3 = Color3.fromRGB(200, 200, 200)
        SearchIcon.BackgroundTransparency = 1
        SearchIcon.ScaleType = Enum.ScaleType.Fit
        SearchIcon.Position = UDim2.new(0, 7, 0.5, 0)
        SearchIcon.AnchorPoint = Vector2.new(0, 0.5)
        SearchIcon.Size = UDim2.new(0, 14, 0, 14)
        SearchIcon.Name = "SearchIcon"
        SearchIcon.Parent = SearchBar

        SearchBox = Instance.new("TextBox")
        SearchBox.Font = Enum.Font.GothamBold
        SearchBox.PlaceholderText = "Search..."
        SearchBox.PlaceholderColor3 = Color3.fromRGB(130, 130, 130)
        SearchBox.Text = ""
        SearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        SearchBox.TextSize = 12
        SearchBox.TextXAlignment = Enum.TextXAlignment.Left
        SearchBox.ClearTextOnFocus = false
        SearchBox.BackgroundTransparency = 1
        SearchBox.AnchorPoint = Vector2.new(0, 0.5)
        SearchBox.Position = UDim2.new(0, 28, 0.5, 0)
        SearchBox.Size = UDim2.new(1, -34, 1, -6)
        SearchBox.Name = "SearchBox"
        SearchBox.Parent = SearchBar

        SearchResults = Instance.new("ScrollingFrame")
        SearchResults.Active = true
        SearchResults.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
        SearchResults.BackgroundTransparency = 0.05
        SearchResults.BorderSizePixel = 0
        SearchResults.ScrollBarThickness = 2
        SearchResults.ScrollBarImageColor3 = GuiConfig.Color
        SearchResults.CanvasSize = UDim2.new(0, 0, 0, 0)
        SearchResults.Position = UDim2.new(0, 0, 0, 34)
        SearchResults.Size = UDim2.new(1, 0, 1, -34)
        SearchResults.Visible = false
        SearchResults.ZIndex = 20
        SearchResults.Name = "SearchResults"
        SearchResults.Parent = LayersTab

        local SearchResultsCorner = Instance.new("UICorner")
        SearchResultsCorner.CornerRadius = UDim.new(0, 4)
        SearchResultsCorner.Parent = SearchResults

        SearchResultsLayout = Instance.new("UIListLayout")
        SearchResultsLayout.Padding = UDim.new(0, 4)
        SearchResultsLayout.SortOrder = Enum.SortOrder.LayoutOrder
        SearchResultsLayout.Parent = SearchResults

        local SearchPad = Instance.new("UIPadding")
        SearchPad.PaddingTop = UDim.new(0, 4)
        SearchPad.PaddingBottom = UDim.new(0, 4)
        SearchPad.PaddingLeft = UDim.new(0,4)
        SearchPad.PaddingRight = UDim.new(0, 4)
        SearchPad.Parent = SearchResults

        SearchResultsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            SearchResults.CanvasSize = UDim2.new(0, 0, 0, SearchResultsLayout.AbsoluteContentSize.Y + 8)
        end)

        local function RunSearch()
            local q = string.gsub(string.gsub(string.lower(SearchBox.Text), "^%s+", ""), "%s+$", "")
            for _, c in pairs(SearchResults:GetChildren()) do
                if c:IsA("GuiObject") then c:Destroy() end
            end
            if q == "" then
                SearchResults.Visible = false
                ScrollTab.Visible = true
                return
            end
            ScrollTab.Visible = false
            SearchResults.Visible = true

            local scored = {}
            for _, entry in ipairs(SearchRegistry) do
                local score = SmartMatch(q, entry.label)
                if score > 0 then
                    table.insert(scored, { entry = entry, score = score })
                end
            end
            table.sort(scored, function(a, b) return a.score > b.score end)

            local found = 0
            for _, s in ipairs(scored) do
                local entry = s.entry
                local Row = Instance.new("Frame")
                Row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Row.BackgroundTransparency = 0.93
                Row.BorderSizePixel = 0
                Row.Size = UDim2.new(1, 0, 0, 40)
                Row.LayoutOrder = found
                Row.ZIndex = 21
                Row.Name = "Result"
                Row.Parent = SearchResults

                local RowCorner = Instance.new("UICorner")
                RowCorner.CornerRadius = UDim.new(0, 4)
                RowCorner.Parent = Row

                local RowLabel = Instance.new("TextLabel")
                RowLabel.Font = Enum.Font.GothamBold
                RowLabel.Text = entry.label
                RowLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
                RowLabel.TextSize = 12
                RowLabel.TextXAlignment = Enum.TextXAlignment.Left
                RowLabel.TextTruncate = Enum.TextTruncate.AtEnd
                RowLabel.BackgroundTransparency = 1
                RowLabel.Position = UDim2.new(0, 8, 0, 6)
                RowLabel.Size = UDim2.new(1, -16, 0, 14)
                RowLabel.ZIndex = 22
                RowLabel.Parent = Row

                local RowTab = Instance.new("TextLabel")
                RowTab.Font = Enum.Font.Gotham
                RowTab.Text = entry.tab .. (entry.kind and (" • " .. entry.kind) or "")
                RowTab.TextColor3 = GuiConfig.Color
                RowTab.TextSize = 10
                RowTab.TextXAlignment = Enum.TextXAlignment.Left
                RowTab.BackgroundTransparency = 1
                RowTab.Position = UDim2.new(0, 8, 0, 22)
                RowTab.Size = UDim2.new(1, -16, 0, 12)
                RowTab.ZIndex = 22
                RowTab.Parent = Row

                local RowButton = Instance.new("TextButton")
                RowButton.Text = ""
                RowButton.BackgroundTransparency = 1
                RowButton.Size = UDim2.new(1, 0, 1, 0)
                RowButton.ZIndex = 23
                RowButton.Parent = Row

                RowButton.Activated:Connect(function()
                    if entry.kind == "Toggle" and entry.element and entry.element.Set then
                        entry.element.Value = not entry.element.Value
                        entry.element:Set(entry.element.Value)
                    else
                        SearchBox.Text = ""
                        if entry.switch then entry.switch() end
                    end
                end)

                found = found + 1
                if found >= 15 then break end
            end

            if found == 0 then
                local Empty = Instance.new("TextLabel")
                Empty.Font = Enum.Font.GothamBold
                Empty.Text = "No results"
                Empty.TextColor3 = Color3.fromRGB(150, 150, 150)
                Empty.TextSize = 12
                Empty.BackgroundTransparency = 1
                Empty.Size = UDim2.new(1, 0, 0, 40)
                Empty.ZIndex = 22
                Empty.Parent = SearchResults
            end
        end

        local searchTicket = 0
        SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
            searchTicket = searchTicket + 1
            local ticket = searchTicket
            task.delay(0.08, function()
                if ticket == searchTicket then
                    RunSearch()
                end
            end)
        end)
        GuiFunc.FocusSearch = function()
            SearchBox:CaptureFocus()
        end
    end

    function GuiFunc:DestroyGui()
        if CoreGui:FindFirstChild("BHub") then
            BHub:Destroy()
        end
    end

    Min.Activated:Connect(function()
        CircleClick(Min, Mouse.X, Mouse.Y)
        DropShadowHolder.Visible = false
    end)
    Close.Activated:Connect(function()
        CircleClick(Close, Mouse.X, Mouse.Y)

        local Overlay = Instance.new("Frame")
        Overlay.Size = UDim2.new(1, 0, 1, 0)
        Overlay.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
        Overlay.BackgroundTransparency = 0.3
        Overlay.ZIndex = 50
        Overlay.Parent = DropShadowHolder

        local Dialog = Instance.new("ImageLabel")
        Dialog.Size = UDim2.new(0, 300, 0, 150)
        Dialog.Position = UDim2.new(0.5, -150, 0.5, -75)
        Dialog.Image = "rbxassetid://9542022979"
        Dialog.ImageColor3 = Color3.fromRGB(22, 22, 22)
        Dialog.ImageTransparency = 0
        Dialog.BorderSizePixel = 0
        Dialog.ZIndex = 51
        Dialog.Parent = Overlay
        local UICorner = Instance.new("UICorner", Dialog)
        UICorner.CornerRadius = UDim.new(0, 8)

        local DialogGlow = Instance.new("Frame")
        DialogGlow.Size = UDim2.new(0, 310, 0, 160)
        DialogGlow.Position = UDim2.new(0.5, -155, 0.5, -80)
        DialogGlow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        DialogGlow.BackgroundTransparency = 0.75
        DialogGlow.BorderSizePixel = 0
        DialogGlow.ZIndex = 50
        DialogGlow.Parent = Overlay

        local GlowCorner = Instance.new("UICorner", DialogGlow)
        GlowCorner.CornerRadius = UDim.new(0, 10)

        local Gradient = Instance.new("UIGradient")
        Gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(190, 190, 190)),
            ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 255, 255))
        })
        Gradient.Rotation = 90
        Gradient.Parent = DialogGlow

        local Title = Instance.new("TextLabel")
        Title.Size = UDim2.new(1, 0, 0, 40)
        Title.Position = UDim2.new(0, 0, 0, 4)
        Title.BackgroundTransparency = 1
        Title.Font = Enum.Font.GothamBold
        Title.Text = "OxioHub Window"
        Title.TextSize = 22
        Title.TextColor3 = Color3.fromRGB(255, 255, 255)
        Title.ZIndex = 52
        Title.Parent = Dialog

        local Message = Instance.new("TextLabel")
        Message.Size = UDim2.new(1, -20, 0, 60)
        Message.Position = UDim2.new(0, 10, 0, 30)
        Message.BackgroundTransparency = 1
        Message.Font = Enum.Font.Gotham
        Message.Text = "Do you want to close this window?\nYou will not be able to open it again"
        Message.TextSize = 14
        Message.TextColor3 = Color3.fromRGB(200, 200, 200)
        Message.TextWrapped = true
        Message.ZIndex = 52
        Message.Parent = Dialog

        local Yes = Instance.new("TextButton")
        Yes.Size = UDim2.new(0.45, -10, 0, 35)
        Yes.Position = UDim2.new(0.05, 0, 1, -55)
        Yes.BackgroundColor3 = Color3.fromRGB(46, 46, 46)
        Yes.BackgroundTransparency = 0.1
        Yes.Text = "Yes"
        Yes.Font = Enum.Font.GothamBold
        Yes.TextSize = 15
        Yes.TextColor3 = Color3.fromRGB(255, 255, 255)
        Yes.TextTransparency = 0
        Yes.ZIndex = 52
        Yes.Name = "Yes"
        Yes.Parent = Dialog
        Instance.new("UICorner", Yes).CornerRadius = UDim.new(0, 6)

        local Cancel = Instance.new("TextButton")
        Cancel.Size = UDim2.new(0.45, -10, 0, 35)
        Cancel.Position = UDim2.new(0.5, 10, 1, -55)
        Cancel.BackgroundColor3 = Color3.fromRGB(46, 46, 46)
        Cancel.BackgroundTransparency = 0.1
        Cancel.Text = "Cancel"
        Cancel.Font = Enum.Font.GothamBold
        Cancel.TextSize = 15
        Cancel.TextColor3 = Color3.fromRGB(255, 255, 255)
        Cancel.TextTransparency = 0
        Cancel.ZIndex = 52
        Cancel.Name = "Cancel"
        Cancel.Parent = Dialog
        Instance.new("UICorner", Cancel).CornerRadius = UDim.new(0, 6)

        Yes.MouseButton1Click:Connect(function()
            if BHub then BHub:Destroy() end
            if game.CoreGui:FindFirstChild("ToggleUIButton") then
                game.CoreGui.ToggleUIButton:Destroy()
            end
        end)

        Cancel.MouseButton1Click:Connect(function()
            Overlay:Destroy()
        end)
    end)

    function GuiFunc:ToggleUI()
        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Parent = game:GetService("CoreGui")
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        ScreenGui.Name = "ToggleUIButton"

        local MainButton = Instance.new("ImageLabel")
        MainButton.Parent = ScreenGui
        MainButton.Size = UDim2.new(0, GuiConfig.LogoButtonSize, 0, GuiConfig.LogoButtonSize)
        MainButton.Position = UDim2.new(0, 20, 0, 100)
        MainButton.BackgroundTransparency = 1
        MainButton.Image = "rbxassetid://" .. GuiConfig.Image
        MainButton.ScaleType = Enum.ScaleType.Fit

        local UICorner = Instance.new("UICorner")
        UICorner.CornerRadius = UDim.new(0, 6)
        UICorner.Parent = MainButton

        local Button = Instance.new("TextButton")
        Button.Parent = MainButton
        Button.Size = UDim2.new(1, 0, 1, 0)
        Button.BackgroundTransparency = 1
        Button.Text = ""

        local UserInputService = game:GetService("UserInputService")
        local dragging = false
        local activeInput = nil
        local dragStart = nil
        local startPos = nil
        local moved = false

        local function IsInsideButton(position)
            local buttonPos = Button.AbsolutePosition
            local buttonSize = Button.AbsoluteSize
            return position.X >= buttonPos.X
                and position.X <= buttonPos.X + buttonSize.X
                and position.Y >= buttonPos.Y
                and position.Y <= buttonPos.Y + buttonSize.Y
        end

        local function update(input)
            if not dragging or not activeInput then return end
            local delta = input.Position - dragStart

            if delta.Magnitude > 3 then
                moved = true
            end

            MainButton.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end

        -- Input hanya boleh memulai drag kalau TOUCH/MOUSE benar-benar DIMULAI
        -- di dalam area tombol. Menyapu dari luar ke tombol tidak akan mengambil drag.
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end

            if not IsInsideButton(input.Position) then
                return
            end

            dragging = true
            activeInput = input
            dragStart = input.Position
            startPos = MainButton.Position
            moved = false
        end)

        UserInputService.InputChanged:Connect(function(input)
            if not dragging or not activeInput then return end

            if activeInput.UserInputType == Enum.UserInputType.Touch then
                if input == activeInput then
                    update(input)
                end
            elseif input.UserInputType == Enum.UserInputType.MouseMovement then
                update(input)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input ~= activeInput then return end

            -- Tap tanpa geser = toggle UI. Drag = hanya memindahkan tombol.
            if not moved and DropShadowHolder then
                DropShadowHolder.Visible = not DropShadowHolder.Visible
            end

            dragging = false
            activeInput = nil
            dragStart = nil
            startPos = nil
            moved = false
        end)
    end

    GuiFunc:ToggleUI()

    MakeDraggable(Top, DropShadowHolder)

    local MoreBlur = Instance.new("Frame");
    local DropShadowHolder1 = Instance.new("Frame");
    local DropShadow1 = Instance.new("ImageLabel");
    local UICorner28 = Instance.new("UICorner");
    local ConnectButton = Instance.new("TextButton");

    MoreBlur.AnchorPoint = Vector2.new(1, 1)
    MoreBlur.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
    MoreBlur.BackgroundTransparency = 0.999
    MoreBlur.BorderColor3 = Color3.fromRGB(27, 27, 27)
    MoreBlur.BorderSizePixel = 0
    MoreBlur.ClipsDescendants = true
    MoreBlur.Position = UDim2.new(1, 8, 1, 8)
    MoreBlur.Size = UDim2.new(1, 154, 1, 54)
    MoreBlur.Visible = false
    MoreBlur.Name = "MoreBlur"
    MoreBlur.Parent = Layers

    DropShadowHolder1.BackgroundTransparency = 1
    DropShadowHolder1.BorderSizePixel = 0
    DropShadowHolder1.Size = UDim2.new(1, 0, 1, 0)
    DropShadowHolder1.ZIndex = 0
    DropShadowHolder1.Name = "DropShadowHolder"
    DropShadowHolder1.Parent = MoreBlur

    DropShadow1.Image = "rbxassetid://6015897843"
    DropShadow1.ImageColor3 = Color3.fromRGB(27, 27, 27)
    DropShadow1.ImageTransparency = 1
    DropShadow1.ScaleType = Enum.ScaleType.Slice
    DropShadow1.SliceCenter = Rect.new(49, 49, 450, 450)
    DropShadow1.AnchorPoint = Vector2.new(0.5, 0.5)
    DropShadow1.BackgroundTransparency = 1
    DropShadow1.BorderSizePixel = 0
    DropShadow1.Position = UDim2.new(0.5, 0, 0.5, 0)
    DropShadow1.Size = UDim2.new(1, 35, 1, 35)
    DropShadow1.ZIndex = 0
    DropShadow1.Name = "DropShadow"
    DropShadow1.Parent = DropShadowHolder1

    UICorner28.Parent = MoreBlur

    ConnectButton.Font = Enum.Font.SourceSans
    ConnectButton.Text = ""
    ConnectButton.TextColor3 = Color3.fromRGB(27, 27, 27)
    ConnectButton.TextSize = 14
    ConnectButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ConnectButton.BackgroundTransparency = 0.999
    ConnectButton.BorderColor3 = Color3.fromRGB(27, 27, 27)
    ConnectButton.BorderSizePixel = 0
    ConnectButton.Size = UDim2.new(1, 0, 1, 0)
    ConnectButton.Name = "ConnectButton"
    ConnectButton.Parent = MoreBlur

    local DropdownSelect = Instance.new("Frame");
    local UICorner36 = Instance.new("UICorner");
    local UIStroke14 = Instance.new("UIStroke");
    local DropdownSelectReal = Instance.new("Frame");
    local DropdownFolder = Instance.new("Folder");
    local DropPageLayout = Instance.new("UIPageLayout");

    DropdownSelect.AnchorPoint = Vector2.new(1, 0.5)
    DropdownSelect.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
    DropdownSelect.BackgroundTransparency = 0.15
    DropdownSelect.BorderColor3 = Color3.fromRGB(27, 27, 27)
    DropdownSelect.BorderSizePixel = 0
    DropdownSelect.LayoutOrder = 1
    DropdownSelect.Position = UDim2.new(1, 172, 0.5, 0)
    DropdownSelect.Size = UDim2.new(0, 160, 1, -16)
    DropdownSelect.Name = "DropdownSelect"
    DropdownSelect.ClipsDescendants = true
    DropdownSelect.Parent = MoreBlur

    ConnectButton.Activated:Connect(function()
        if MoreBlur.Visible then
            TweenService:Create(MoreBlur, TweenInfo.new(0.3), { BackgroundTransparency = 0.999 }):Play()
            TweenService:Create(DropdownSelect, TweenInfo.new(0.3), { Position = UDim2.new(1, 172, 0.5, 0) }):Play()
            task.wait(0.3)
            MoreBlur.Visible = false
        end
    end)
    UICorner36.CornerRadius = UDim.new(0, 3)
    UICorner36.Parent = DropdownSelect

    UIStroke14.Color = Color3.fromRGB(255, 255, 255)
    UIStroke14.Thickness = 2.5
    UIStroke14.Transparency = 0.8
    UIStroke14.Parent = DropdownSelect

    DropdownSelectReal.AnchorPoint = Vector2.new(0.5, 0.5)
    DropdownSelectReal.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
    DropdownSelectReal.BackgroundTransparency = 0.4
    DropdownSelectReal.BorderColor3 = Color3.fromRGB(27, 27, 27)
    DropdownSelectReal.BorderSizePixel = 0
    DropdownSelectReal.LayoutOrder = 1
    DropdownSelectReal.Position = UDim2.new(0.5, 0, 0.5, 0)
    DropdownSelectReal.Size = UDim2.new(1, 1, 1, 1)
    DropdownSelectReal.Name = "DropdownSelectReal"
    DropdownSelectReal.Parent = DropdownSelect

    DropdownFolder.Name = "DropdownFolder"
    DropdownFolder.Parent = DropdownSelectReal

    DropPageLayout.EasingDirection = Enum.EasingDirection.InOut
    DropPageLayout.EasingStyle = Enum.EasingStyle.Quad
    DropPageLayout.TweenTime = 0.009999999776482582
    DropPageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    DropPageLayout.FillDirection = Enum.FillDirection.Vertical
    DropPageLayout.Archivable = false
    DropPageLayout.Name = "DropPageLayout"
    DropPageLayout.Parent = DropdownFolder
    local Tabs = {}
    local CountTab = 0
    local CountDropdown = 0
    function Tabs:AddTab(TabConfig)
        local TabConfig = TabConfig or {}
        TabConfig.Name = TabConfig.Name or "Tab"
        TabConfig.Icon = TabConfig.Icon or ""

        local ScrolLayers = Instance.new("ScrollingFrame");
        local UIListLayout1 = Instance.new("UIListLayout");

        ScrolLayers.ScrollBarImageColor3 = Color3.fromRGB(80.00000283122063, 80.00000283122063, 80.00000283122063)
        ScrolLayers.ScrollBarThickness = 0
        ScrolLayers.Active = true
        ScrolLayers.LayoutOrder = CountTab
        ScrolLayers.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ScrolLayers.BackgroundTransparency = 0.9990000128746033
        ScrolLayers.BorderColor3 = Color3.fromRGB(27, 27, 27)
        ScrolLayers.BorderSizePixel = 0
        ScrolLayers.Size = UDim2.new(1, 0, 1, 0)
        ScrolLayers.Name = "ScrolLayers"
        ScrolLayers.Parent = LayersFolder

        UIListLayout1.Padding = UDim.new(0, 3)
        UIListLayout1.SortOrder = Enum.SortOrder.LayoutOrder
        UIListLayout1.Parent = ScrolLayers

        local Tab = Instance.new("Frame");
        local UICorner3 = Instance.new("UICorner");
        local TabButton = Instance.new("TextButton");
        local TabName = Instance.new("TextLabel")
        local FeatureImg = Instance.new("ImageLabel");
        local UIStroke2 = Instance.new("UIStroke");
        local UICorner4 = Instance.new("UICorner");

        Tab.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        if CountTab == 0 then
            Tab.BackgroundTransparency = 0.9200000166893005
        else
            Tab.BackgroundTransparency = 0.9990000128746033
        end
        Tab.BorderColor3 = Color3.fromRGB(27, 27, 27)
        Tab.BorderSizePixel = 0
        Tab.LayoutOrder = CountTab
        Tab.Size = UDim2.new(1, 0, 0, 30)
        Tab.Name = "Tab"
        Tab.Parent = ScrollTab

        UICorner3.CornerRadius = UDim.new(0, 4)
        UICorner3.Parent = Tab

        TabButton.Font = Enum.Font.GothamBold
        TabButton.Text = ""
        TabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        TabButton.TextSize = 13
        TabButton.TextXAlignment = Enum.TextXAlignment.Left
        TabButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        TabButton.BackgroundTransparency = 0.9990000128746033
        TabButton.BorderColor3 = Color3.fromRGB(27, 27, 27)
        TabButton.BorderSizePixel = 0
        TabButton.Size = UDim2.new(1, 0, 1, 0)
        TabButton.Name = "TabButton"
        TabButton.Parent = Tab

        TabName.Font = Enum.Font.GothamBold
        TabName.Text = tostring(TabConfig.Name)
        TabName.TextColor3 = Color3.fromRGB(255, 255, 255)
        TabName.TextSize = 13
        TabName.TextXAlignment = Enum.TextXAlignment.Left
        TabName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        TabName.BackgroundTransparency = 0.9990000128746033
        TabName.BorderColor3 = Color3.fromRGB(27, 27, 27)
        TabName.BorderSizePixel = 0
        TabName.Size = UDim2.new(1, 0, 1, 0)
        TabName.Position = UDim2.new(0, 30, 0, 0)
        TabName.Name = "TabName"
        TabName.Parent = Tab

        FeatureImg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        FeatureImg.BackgroundTransparency = 0.9990000128746033
        FeatureImg.BorderColor3 = Color3.fromRGB(27, 27, 27)
        FeatureImg.BorderSizePixel = 0
        FeatureImg.Position = UDim2.new(0, 9, 0, 7)
        FeatureImg.Size = UDim2.new(0, 16, 0, 16)
        FeatureImg.Name = "FeatureImg"
        FeatureImg.Parent = Tab
        if CountTab == 0 then
            LayersPageLayout:JumpToIndex(0)
            NameTab.Text = TabConfig.Name
            local ChooseFrame = Instance.new("Frame");
            ChooseFrame.BackgroundColor3 = GuiConfig.Color
            ChooseFrame.BorderColor3 = Color3.fromRGB(27, 27, 27)
            ChooseFrame.BorderSizePixel = 0
            ChooseFrame.Position = UDim2.new(0, 2, 0, 9)
            ChooseFrame.Size = UDim2.new(0, 1, 0, 12)
            ChooseFrame.Name = "ChooseFrame"
            ChooseFrame.Parent = Tab

            UIStroke2.Color = GuiConfig.Color
            UIStroke2.Thickness = 1.600000023841858
            UIStroke2.Parent = ChooseFrame

            UICorner4.Parent = ChooseFrame
        end

        if TabConfig.Icon ~= "" then
            ApplyIcon(FeatureImg, TabConfig.Icon, 24)
        end

        local function switchToTab(force)
            local FrameChoose
            for a, s in ScrollTab:GetChildren() do
                for i, v in s:GetChildren() do
                    if v.Name == "ChooseFrame" then
                        FrameChoose = v
                        break
                    end
                end
            end
            if FrameChoose ~= nil and (force or Tab.LayoutOrder ~= LayersPageLayout.CurrentPage.LayoutOrder) then
                for _, TabFrame in ScrollTab:GetChildren() do
                    if TabFrame.Name == "Tab" then
                        TweenService:Create(
                            TabFrame,
                            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.InOut),
                            { BackgroundTransparency = 0.9990000128746033 }
                        ):Play()
                    end
                end
                TweenService:Create(
                    Tab,
                    TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.InOut),
                    { BackgroundTransparency = 0.9200000166893005 }
                ):Play()
                TweenService:Create(
                    FrameChoose,
                    TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                    { Position = UDim2.new(0, 2, 0, 9 + (33 * Tab.LayoutOrder)) }
                ):Play()
                LayersPageLayout:JumpToIndex(Tab.LayoutOrder)
                task.wait(0.05)
                NameTab.Text = TabConfig.Name
                TweenService:Create(
                    FrameChoose,
                    TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                    { Size = UDim2.new(0, 1, 0, 20) }
                ):Play()
                task.wait(0.2)
                TweenService:Create(
                    FrameChoose,
                    TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                    { Size = UDim2.new(0, 1, 0, 12) }
                ):Play()
            end
        end

        TabButton.Activated:Connect(function()
            CircleClick(TabButton, Mouse.X, Mouse.Y)
            switchToTab(false)
        end)

        local function SearchSwitch()
            if SearchResults then
                SearchResults.Visible = false
                ScrollTab.Visible = true
            end
            switchToTab(true)
        end

        TabRegistry[TabConfig.Name] = SearchSwitch
        RegisterSearch({ label = TabConfig.Name, tab = TabConfig.Name, kind = "Tab", switch = SearchSwitch })
        local Sections = {}
        local CountSection = 0
        function Sections:AddSection(Title, AlwaysOpen)
            local Title = Title or "Title"
            local Section = Instance.new("Frame");
            local SectionDecideFrame = Instance.new("Frame");
            local UICorner1 = Instance.new("UICorner");
            local UIGradient = Instance.new("UIGradient");

            Section.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Section.BackgroundTransparency = 0.9990000128746033
            Section.BorderColor3 = Color3.fromRGB(27, 27, 27)
            Section.BorderSizePixel = 0
            Section.LayoutOrder = CountSection
            Section.ClipsDescendants = true
            Section.LayoutOrder = 1
            Section.Size = UDim2.new(1, 0, 0, 30)
            Section.Name = "Section"
            Section.Parent = ScrolLayers

            local SectionReal = Instance.new("Frame");
            local UICorner = Instance.new("UICorner");
            local UIStroke = Instance.new("UIStroke");
            local SectionButton = Instance.new("TextButton");
            local FeatureFrame = Instance.new("Frame");
            local FeatureImg = Instance.new("ImageLabel");
            local SectionTitle = Instance.new("TextLabel");

            SectionReal.AnchorPoint = Vector2.new(0.5, 0)
            SectionReal.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            SectionReal.BackgroundTransparency = 0.9350000023841858
            SectionReal.BorderColor3 = Color3.fromRGB(27, 27, 27)
            SectionReal.BorderSizePixel = 0
            SectionReal.LayoutOrder = 1
            SectionReal.Position = UDim2.new(0.5, 0, 0, 0)
            SectionReal.Size = UDim2.new(1, 1, 0, 30)
            SectionReal.Name = "SectionReal"
            SectionReal.Parent = Section

            UICorner.CornerRadius = UDim.new(0, 4)
            UICorner.Parent = SectionReal

            SectionButton.Font = Enum.Font.SourceSans
            SectionButton.Text = ""
            SectionButton.TextColor3 = Color3.fromRGB(27, 27, 27)
            SectionButton.TextSize = 14
            SectionButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            SectionButton.BackgroundTransparency = 0.9990000128746033
            SectionButton.BorderColor3 = Color3.fromRGB(27, 27, 27)
            SectionButton.BorderSizePixel = 0
            SectionButton.Size = UDim2.new(1, 0, 1, 0)
            SectionButton.Name = "SectionButton"
            SectionButton.Parent = SectionReal

            FeatureFrame.AnchorPoint = Vector2.new(1, 0.5)
            FeatureFrame.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
            FeatureFrame.BackgroundTransparency = 0.9990000128746033
            FeatureFrame.BorderColor3 = Color3.fromRGB(27, 27, 27)
            FeatureFrame.BorderSizePixel = 0
            FeatureFrame.Position = UDim2.new(1, -5, 0.5, 0)
            FeatureFrame.Size = UDim2.new(0, 20, 0, 20)
            FeatureFrame.Name = "FeatureFrame"
            FeatureFrame.Parent = SectionReal

            FeatureImg.Image = "rbxassetid://16851841101"
            FeatureImg.AnchorPoint = Vector2.new(0.5, 0.5)
            FeatureImg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            FeatureImg.BackgroundTransparency = 0.9990000128746033
            FeatureImg.BorderColor3 = Color3.fromRGB(27, 27, 27)
            FeatureImg.BorderSizePixel = 0
            FeatureImg.Position = UDim2.new(0.5, 0, 0.5, 0)
            FeatureImg.Rotation = -90
            FeatureImg.Size = UDim2.new(1, 6, 1, 6)
            FeatureImg.Name = "FeatureImg"
            FeatureImg.Parent = FeatureFrame

            SectionTitle.Font = Enum.Font.GothamBold
            SectionTitle.Text = Title
            SectionTitle.TextColor3 = Color3.fromRGB(230.77499270439148, 230.77499270439148, 230.77499270439148)
            SectionTitle.TextSize = 13
            SectionTitle.TextXAlignment = Enum.TextXAlignment.Left
            SectionTitle.TextYAlignment = Enum.TextYAlignment.Top
            SectionTitle.AnchorPoint = Vector2.new(0, 0.5)
            SectionTitle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            SectionTitle.BackgroundTransparency = 0.9990000128746033
            SectionTitle.BorderColor3 = Color3.fromRGB(27, 27, 27)
            SectionTitle.BorderSizePixel = 0
            SectionTitle.Position = UDim2.new(0, 10, 0.5, 0)
            SectionTitle.Size = UDim2.new(1, -50, 0, 13)
            SectionTitle.Name = "SectionTitle"
            SectionTitle.Parent = SectionReal

            SectionDecideFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            SectionDecideFrame.BorderColor3 = Color3.fromRGB(27, 27, 27)
            SectionDecideFrame.AnchorPoint = Vector2.new(0.5, 0)
            SectionDecideFrame.BorderSizePixel = 0
            SectionDecideFrame.Position = UDim2.new(0.5, 0, 0, 33)
            SectionDecideFrame.Size = UDim2.new(0, 0, 0, 2)
            SectionDecideFrame.Name = "SectionDecideFrame"
            SectionDecideFrame.Parent = Section

            UICorner1.Parent = SectionDecideFrame

            UIGradient.Color = ColorSequence.new {
                ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 34, 34)),
                ColorSequenceKeypoint.new(0.5, GuiConfig.Color),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(34, 34, 34))
            }
            UIGradient.Parent = SectionDecideFrame

            local SectionAdd = Instance.new("Frame");
            local UICorner8 = Instance.new("UICorner");
            local UIListLayout2 = Instance.new("UIListLayout");

            SectionAdd.AnchorPoint = Vector2.new(0.5, 0)
            SectionAdd.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            SectionAdd.BackgroundTransparency = 0.9990000128746033
            SectionAdd.BorderColor3 = Color3.fromRGB(27, 27, 27)
            SectionAdd.BorderSizePixel = 0
            SectionAdd.ClipsDescendants = true
            SectionAdd.LayoutOrder = 1
            SectionAdd.Position = UDim2.new(0.5, 0, 0, 38)
            SectionAdd.Size = UDim2.new(1, 0, 0, 100)
            SectionAdd.Name = "SectionAdd"
            SectionAdd.Parent = Section

            UICorner8.CornerRadius = UDim.new(0, 2)
            UICorner8.Parent = SectionAdd

            UIListLayout2.Padding = UDim.new(0, 3)
            UIListLayout2.SortOrder = Enum.SortOrder.LayoutOrder
            UIListLayout2.Parent = SectionAdd

            local OpenSection = false
            local scrollUpdatePending = false
            local function UpdateSizeScroll()
                if scrollUpdatePending then return end
                scrollUpdatePending = true
                task.defer(function()
                    scrollUpdatePending = false
                    local OffsetY = 0
                    for _, child in ScrolLayers:GetChildren() do
                        if child.Name ~= "UIListLayout" then
                            OffsetY = OffsetY + 3 + child.Size.Y.Offset
                        end
                    end
                    ScrolLayers.CanvasSize = UDim2.new(0, 0, 0, OffsetY)
                end)
            end

            local sectionUpdatePending = false
            local function UpdateSizeSection()
                if not OpenSection then return end
                if sectionUpdatePending then return end
                sectionUpdatePending = true
                task.defer(function()
                    sectionUpdatePending = false
                    if not OpenSection then return end

                    local SectionSizeYWitdh = 38
                    for _, v in SectionAdd:GetChildren() do
                        if v.Name ~= "UIListLayout" and v.Name ~= "UICorner" then
                            SectionSizeYWitdh = SectionSizeYWitdh + v.Size.Y.Offset + 3
                        end
                    end
                    pcall(function()
                        TweenService:Create(FeatureFrame, TweenInfo.new(0.5), { Rotation = 90 }):Play()
                        TweenService:Create(Section, TweenInfo.new(0.5), { Size = UDim2.new(1, 1, 0, SectionSizeYWitdh) })
                            :Play()
                        TweenService:Create(SectionAdd, TweenInfo.new(0.5),
                            { Size = UDim2.new(1, 0, 0, SectionSizeYWitdh - 38) }):Play()
                        TweenService:Create(SectionDecideFrame, TweenInfo.new(0.5), { Size = UDim2.new(1, 0, 0, 2) })
                            :Play()
                    end)
                    task.delay(0.5, UpdateSizeScroll)
                end)
            end

            if AlwaysOpen == true then
                SectionButton:Destroy()
                FeatureFrame:Destroy()
                OpenSection = true
                UpdateSizeSection()
            elseif AlwaysOpen == false then
                OpenSection = true
                UpdateSizeSection()
            else
                OpenSection = false
            end

            if AlwaysOpen ~= true then
                SectionButton.Activated:Connect(function()
                    CircleClick(SectionButton, Mouse.X, Mouse.Y)
                    if OpenSection then
                        TweenService:Create(FeatureFrame, TweenInfo.new(0.5), { Rotation = 0 }):Play()
                        TweenService:Create(Section, TweenInfo.new(0.5), { Size = UDim2.new(1, 1, 0, 30) }):Play()
                        TweenService:Create(SectionDecideFrame, TweenInfo.new(0.5), { Size = UDim2.new(0, 0, 0, 2) })
                            :Play()
                        OpenSection = false
                        task.delay(0.5, UpdateSizeScroll)
                    else
                        OpenSection = true
                        UpdateSizeSection()
                    end
                end)
            end

            if AlwaysOpen == true or AlwaysOpen == false then
                OpenSection = true
                local SectionSizeYWitdh = 38
                for _, v in SectionAdd:GetChildren() do
                    if v.Name ~= "UIListLayout" and v.Name ~= "UICorner" then
                        SectionSizeYWitdh = SectionSizeYWitdh + v.Size.Y.Offset + 3
                    end
                end
                FeatureFrame.Rotation = 90
                Section.Size = UDim2.new(1, 1, 0, SectionSizeYWitdh)
                SectionAdd.Size = UDim2.new(1, 0, 0, SectionSizeYWitdh - 38)
                SectionDecideFrame.Size = UDim2.new(1, 0, 0, 2)
                UpdateSizeScroll()
            end

            SectionAdd.ChildAdded:Connect(UpdateSizeSection)
            SectionAdd.ChildRemoved:Connect(UpdateSizeSection)

            local layout = ScrolLayers:FindFirstChildOfClass("UIListLayout")
            if layout then
                layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    ScrolLayers.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
                end)
            end

            local function BuildItemsAPI(SectionAdd)
            local Items = {}
            local CountItem = 0

            function Items:AddParagraph(ParagraphConfig)
                local ParagraphConfig = ParagraphConfig or {}
                ParagraphConfig.Title = ParagraphConfig.Title or "Title"
                ParagraphConfig.Content = ParagraphConfig.Content or "Content"
                local ParagraphFunc = {}

                local Paragraph = Instance.new("Frame")
                local UICorner14 = Instance.new("UICorner")
                local ParagraphTitle = Instance.new("TextLabel")
                local ParagraphContent = Instance.new("TextLabel")

                Paragraph.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Paragraph.BackgroundTransparency = 0.935
                Paragraph.BorderSizePixel = 0
                Paragraph.LayoutOrder = CountItem
                Paragraph.Size = UDim2.new(1, 0, 0, 46)
                Paragraph.Name = "Paragraph"
                Paragraph.Parent = SectionAdd

                UICorner14.CornerRadius = UDim.new(0, 4)
                UICorner14.Parent = Paragraph

                local iconOffset = 10
                if ParagraphConfig.Icon then
                    local IconImg = Instance.new("ImageLabel")
                    IconImg.Size = UDim2.new(0, 20, 0, 20)
                    IconImg.Position = UDim2.new(0, 8, 0, 12)
                    IconImg.BackgroundTransparency = 1
                    IconImg.Name = "ParagraphIcon"
                    IconImg.Parent = Paragraph

                    ApplyIcon(IconImg, ParagraphConfig.Icon, 24)

                    iconOffset = 30
                end

                ParagraphTitle.Font = Enum.Font.GothamBold
                ParagraphTitle.Text = ParagraphConfig.Title
                ParagraphTitle.TextColor3 = Color3.fromRGB(231, 231, 231)
                ParagraphTitle.TextSize = 13
                ParagraphTitle.TextXAlignment = Enum.TextXAlignment.Left
                ParagraphTitle.TextYAlignment = Enum.TextYAlignment.Top
                ParagraphTitle.BackgroundTransparency = 1
                ParagraphTitle.Position = UDim2.new(0, iconOffset, 0, 10)
                ParagraphTitle.Size = UDim2.new(1, -16, 0, 13)
                ParagraphTitle.Name = "ParagraphTitle"
                ParagraphTitle.Parent = Paragraph

                ParagraphContent.Font = Enum.Font.Gotham
                ParagraphContent.Text = ParagraphConfig.Content
                ParagraphContent.TextColor3 = Color3.fromRGB(255, 255, 255)
                ParagraphContent.TextSize = 12
                ParagraphContent.TextXAlignment = Enum.TextXAlignment.Left
                ParagraphContent.TextYAlignment = Enum.TextYAlignment.Top
                ParagraphContent.BackgroundTransparency = 1
                ParagraphContent.Position = UDim2.new(0, iconOffset, 0, 25)
                ParagraphContent.Name = "ParagraphContent"
                ParagraphContent.TextWrapped = true
                ParagraphContent.RichText = true
                
                -- FIX: Matikan AutomaticSize agar tidak melar ke samping
                ParagraphContent.AutomaticSize = Enum.AutomaticSize.None
                ParagraphContent.Size = UDim2.new(1, -(iconOffset + 10), 0, 14)
                ParagraphContent.Parent = Paragraph

                local TextService = game:GetService("TextService")

                local function UpdateSize()
                    task.wait() -- Tunggu render UI agar AbsoluteSize tersedia
                    local maxWidth = Paragraph.AbsoluteSize.X - (iconOffset + 10) - 10
                    if maxWidth <= 0 then maxWidth = 200 end -- Fallback jika lebar belum terdeteksi

                    -- Hitung tinggi text secara akurat berdasarkan lebar kolom
                    local ok, bounds = pcall(function()
                        return TextService:GetTextSize(
                            ParagraphContent.Text, 
                            12, 
                            Enum.Font.Gotham, 
                            Vector2.new(maxWidth, math.huge)
                        )
                    end)

                    local contentHeight = (ok and bounds and bounds.Y) or 14
                    if contentHeight < 14 then contentHeight = 14 end

                    local buttonHeight = 0
                    if ParagraphButton then
                        buttonHeight = ParagraphButton.Size.Y.Offset + 5
                        ParagraphButton.Position = UDim2.new(0, 10, 0, contentHeight + 28)
                    end

                    local totalHeight = contentHeight + 33 + buttonHeight

                    ParagraphContent.Size = UDim2.new(1, -(iconOffset + 10), 0, contentHeight)
                    
                    if Paragraph.Size.Y.Offset ~= totalHeight then
                        Paragraph.Size = UDim2.new(1, 0, 0, totalHeight)
                        if UpdateSizeSection then UpdateSizeSection() end
                    end
                end

                ParagraphContent:GetPropertyChangedSignal("TextBounds"):Connect(function()
                    task.spawn(UpdateSize)
                end)
                
                task.spawn(function()
                    UpdateSize()
                end)

                function ParagraphFunc:SetContent(content)
                    content = content or "Content"
                    ParagraphContent.Text = content
                    task.spawn(UpdateSize)
                end

                CountItem = CountItem + 1
                RegisterSearch({ label = ParagraphConfig.Title, tab = TabConfig.Name, kind = "Info", switch = SearchSwitch })
                return ParagraphFunc
            end

            function Items:AddPanel(PanelConfig)
                PanelConfig = PanelConfig or {}
                PanelConfig.Title = PanelConfig.Title or "Title"
                PanelConfig.Content = PanelConfig.Content or ""
                PanelConfig.Placeholder = PanelConfig.Placeholder or nil
                PanelConfig.Default = PanelConfig.Default or ""
                PanelConfig.ButtonText = PanelConfig.Button or PanelConfig.ButtonText or "Confirm"
                PanelConfig.ButtonCallback = PanelConfig.Callback or PanelConfig.ButtonCallback or function() end
                PanelConfig.SubButtonText = PanelConfig.SubButton or PanelConfig.SubButtonText or nil
                PanelConfig.SubButtonCallback = PanelConfig.SubCallback or PanelConfig.SubButtonCallback or
                    function() end

                local configKey = "Panel_" .. PanelConfig.Title
                local shouldSave = PanelConfig.Save ~= false
                if shouldSave and ConfigData[configKey] ~= nil then
                    PanelConfig.Default = ConfigData[configKey]
                end

                local PanelFunc = { Value = PanelConfig.Default }

                local baseHeight = 50

                if PanelConfig.Placeholder then
                    baseHeight = baseHeight + 40
                end

                if PanelConfig.SubButtonText then
                    baseHeight = baseHeight + 40
                else
                    baseHeight = baseHeight + 36
                end

                local Panel = Instance.new("Frame")
                Panel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Panel.BackgroundTransparency = 0.935
                Panel.Size = UDim2.new(1, 0, 0, baseHeight)
                Panel.LayoutOrder = CountItem
                Panel.Parent = SectionAdd

                local UICorner = Instance.new("UICorner")
                UICorner.CornerRadius = UDim.new(0, 4)
                UICorner.Parent = Panel

                local Title = Instance.new("TextLabel")
                Title.Font = Enum.Font.GothamBold
                Title.Text = PanelConfig.Title
                Title.TextSize = 13
                Title.TextColor3 = Color3.fromRGB(255, 255, 255)
                Title.TextXAlignment = Enum.TextXAlignment.Left
                Title.BackgroundTransparency = 1
                Title.Position = UDim2.new(0, 10, 0, 10)
                Title.Size = UDim2.new(1, -20, 0, 13)
                Title.Parent = Panel

                local Content = Instance.new("TextLabel")
                Content.Font = Enum.Font.Gotham
                Content.Text = PanelConfig.Content
                Content.TextSize = 12
                Content.TextColor3 = Color3.fromRGB(255, 255, 255)
                Content.TextTransparency = 0
                Content.TextXAlignment = Enum.TextXAlignment.Left
                Content.BackgroundTransparency = 1
                Content.RichText = true
                Content.Position = UDim2.new(0, 10, 0, 28)
                Content.Size = UDim2.new(1, -20, 0, 14)
                Content.Parent = Panel

                local InputBox
                if PanelConfig.Placeholder then
                    local InputFrame = Instance.new("Frame")
                    InputFrame.AnchorPoint = Vector2.new(0.5, 0)
                    InputFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    InputFrame.BackgroundTransparency = 0.95
                    InputFrame.Position = UDim2.new(0.5, 0, 0, 48)
                    InputFrame.Size = UDim2.new(1, -20, 0, 30)
                    InputFrame.Parent = Panel

                    local inputCorner = Instance.new("UICorner")
                    inputCorner.CornerRadius = UDim.new(0, 4)
                    inputCorner.Parent = InputFrame

                    InputBox = Instance.new("TextBox")
                    InputBox.Font = Enum.Font.GothamBold
                    InputBox.PlaceholderText = PanelConfig.Placeholder
                    InputBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
                    InputBox.Text = PanelConfig.Default
                    InputBox.TextSize = 11
                    InputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
                    InputBox.BackgroundTransparency = 1
                    InputBox.TextXAlignment = Enum.TextXAlignment.Left
                    InputBox.Size = UDim2.new(1, -10, 1, -6)
                    InputBox.Position = UDim2.new(0, 5, 0, 3)
                    InputBox.Parent = InputFrame
                end

                local yBtn = 0
                if PanelConfig.Placeholder then
                    yBtn = 88
                else
                    yBtn = 48
                end

                local ButtonMain = Instance.new("TextButton")
                ButtonMain.Font = Enum.Font.GothamBold
                ButtonMain.Text = PanelConfig.ButtonText
                ButtonMain.TextColor3 = Color3.fromRGB(255, 255, 255)
                ButtonMain.TextSize = 12
                ButtonMain.TextTransparency = 0.3
                ButtonMain.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                ButtonMain.BackgroundTransparency = 0.935
                ButtonMain.Size = PanelConfig.SubButtonText and UDim2.new(0.5, -12, 0, 30) or UDim2.new(1, -20, 0, 30)
                ButtonMain.Position = UDim2.new(0, 10, 0, yBtn)
                ButtonMain.Parent = Panel

                local btnCorner = Instance.new("UICorner")
                btnCorner.CornerRadius = UDim.new(0, 6)
                btnCorner.Parent = ButtonMain

                ButtonMain.MouseButton1Click:Connect(function()
                    PanelConfig.ButtonCallback(InputBox and InputBox.Text or "")
                end)

                if PanelConfig.SubButtonText then
                    local SubButton = Instance.new("TextButton")
                    SubButton.Font = Enum.Font.GothamBold
                    SubButton.Text = PanelConfig.SubButtonText
                    SubButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                    SubButton.TextSize = 12
                    SubButton.TextTransparency = 0.3
                    SubButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    SubButton.BackgroundTransparency = 0.935
                    SubButton.Size = UDim2.new(0.5, -12, 0, 30)
                    SubButton.Position = UDim2.new(0.5, 2, 0, yBtn)
                    SubButton.Parent = Panel

                    local subCorner = Instance.new("UICorner")
                    subCorner.CornerRadius = UDim.new(0, 6)
                    subCorner.Parent = SubButton

                    SubButton.MouseButton1Click:Connect(function()
                        PanelConfig.SubButtonCallback(InputBox and InputBox.Text or "")
                    end)
                end

                if InputBox then
                    InputBox.FocusLost:Connect(function()
                        PanelFunc:Set(InputBox.Text)
                    end)
                end

                function PanelFunc:Set(Value, noSave)
                    Value = tostring(Value or "")
                    PanelFunc.Value = Value
                    if shouldSave then
                        ConfigData[configKey] = Value
                    end
                    if InputBox then
                        InputBox.Text = Value
                    end
                    if shouldSave and not noSave then QueueSaveConfig() end
                end

                function PanelFunc:GetInput()
                    return InputBox and InputBox.Text or ""
                end

                PanelFunc:Set(PanelFunc.Value, true)

                local PanelLockOverlay = CreateLockOverlay(Panel, "Locked")
                function PanelFunc:Lock(text) PanelLockOverlay:Lock(text) end
                function PanelFunc:Unlock() PanelLockOverlay:Unlock() end
                if PanelConfig.Locked then
                    PanelFunc:Lock(PanelConfig.TextLock)
                end
                CountItem = CountItem + 1
                if shouldSave then
                    Elements[configKey] = PanelFunc
                end
                return PanelFunc
            end

            function Items:AddButton(ButtonConfig)
                ButtonConfig = ButtonConfig or {}
                ButtonConfig.Title = ButtonConfig.Title or "Confirm"
                ButtonConfig.Callback = ButtonConfig.Callback or function() end
                ButtonConfig.SubTitle = ButtonConfig.SubTitle or nil
                ButtonConfig.SubCallback = ButtonConfig.SubCallback or function() end

                local Button = Instance.new("Frame")
                Button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Button.BackgroundTransparency = 0.935
                Button.Size = UDim2.new(1, 0, 0, 40)
                Button.LayoutOrder = CountItem
                Button.Parent = SectionAdd

                local UICorner = Instance.new("UICorner")
                UICorner.CornerRadius = UDim.new(0, 4)
                UICorner.Parent = Button

                local MainButton = Instance.new("TextButton")
                MainButton.Font = Enum.Font.GothamBold
                MainButton.Text = ButtonConfig.Title
                MainButton.TextSize = 12
                MainButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                MainButton.TextTransparency = 0.3
                MainButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                MainButton.BackgroundTransparency = 0.935
                MainButton.Size = ButtonConfig.SubTitle and UDim2.new(0.5, -8, 1, -10) or UDim2.new(1, -12, 1, -10)
                MainButton.Position = UDim2.new(0, 6, 0, 5)
                MainButton.Parent = Button

                local mainCorner = Instance.new("UICorner")
                mainCorner.CornerRadius = UDim.new(0, 4)
                mainCorner.Parent = MainButton

                MainButton.MouseButton1Click:Connect(ButtonConfig.Callback)

                if ButtonConfig.SubTitle then
                    local SubButton = Instance.new("TextButton")
                    SubButton.Font = Enum.Font.GothamBold
                    SubButton.Text = ButtonConfig.SubTitle
                    SubButton.TextSize = 12
                    SubButton.TextTransparency = 0.3
                    SubButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                    SubButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    SubButton.BackgroundTransparency = 0.935
                    SubButton.Size = UDim2.new(0.5, -8, 1, -10)
                    SubButton.Position = UDim2.new(0.5, 2, 0, 5)
                    SubButton.Parent = Button

                    local subCorner = Instance.new("UICorner")
                    subCorner.CornerRadius = UDim.new(0, 4)
                    subCorner.Parent = SubButton

                    SubButton.MouseButton1Click:Connect(ButtonConfig.SubCallback)
                end

                CountItem = CountItem + 1
                RegisterSearch({ label = ButtonConfig.Title, tab = TabConfig.Name, kind = "Button", switch = SearchSwitch })
            end

            function Items:AddToggle(ToggleConfig)
                local ToggleConfig = ToggleConfig or {}
                ToggleConfig.Title = ToggleConfig.Title or "Title"
                ToggleConfig.Title2 = ToggleConfig.Title2 or ""
                ToggleConfig.Content = ToggleConfig.Content or ""
                ToggleConfig.Default = ToggleConfig.Default or false
                ToggleConfig.Callback = ToggleConfig.Callback or function() end

                local configKey = "Toggle_" .. ToggleConfig.Title
                local shouldSave = ToggleConfig.Save ~= false
                if shouldSave and ConfigData[configKey] ~= nil then
                    ToggleConfig.Default = ConfigData[configKey]
                end

                local ToggleFunc = { Value = ToggleConfig.Default }

                local Toggle = Instance.new("Frame")
                local UICorner20 = Instance.new("UICorner")
                local ToggleTitle = Instance.new("TextLabel")
                local ToggleContent = Instance.new("TextLabel")
                local ToggleButton = Instance.new("TextButton")
                local FeatureFrame2 = Instance.new("Frame")
                local UICorner22 = Instance.new("UICorner")
                local UIStroke8 = Instance.new("UIStroke")
                local ToggleCircle = Instance.new("Frame")
                local UICorner23 = Instance.new("UICorner")

                Toggle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Toggle.BackgroundTransparency = 0.935
                Toggle.BorderSizePixel = 0
                Toggle.LayoutOrder = CountItem
                Toggle.Name = "Toggle"
                Toggle.Parent = SectionAdd

                UICorner20.CornerRadius = UDim.new(0, 4)
                UICorner20.Parent = Toggle

                ToggleTitle.Font = Enum.Font.GothamBold
                ToggleTitle.Text = ToggleConfig.Title
                ToggleTitle.TextSize = 13
                ToggleTitle.TextColor3 = Color3.fromRGB(231, 231, 231)
                ToggleTitle.TextXAlignment = Enum.TextXAlignment.Left
                ToggleTitle.TextYAlignment = Enum.TextYAlignment.Top
                ToggleTitle.BackgroundTransparency = 1
                ToggleTitle.Position = UDim2.new(0, 10, 0, 10)
                ToggleTitle.Size = UDim2.new(1, -100, 0, 13)
                ToggleTitle.Name = "ToggleTitle"
                ToggleTitle.Parent = Toggle

                local ToggleTitle2 = Instance.new("TextLabel")
                ToggleTitle2.Font = Enum.Font.GothamBold
                ToggleTitle2.Text = ToggleConfig.Title2
                ToggleTitle2.TextSize = 12
                ToggleTitle2.TextColor3 = Color3.fromRGB(231, 231, 231)
                ToggleTitle2.TextXAlignment = Enum.TextXAlignment.Left
                ToggleTitle2.TextYAlignment = Enum.TextYAlignment.Top
                ToggleTitle2.BackgroundTransparency = 1
                ToggleTitle2.Position = UDim2.new(0, 10, 0, 23)
                ToggleTitle2.Size = UDim2.new(1, -100, 0, 12)
                ToggleTitle2.Name = "ToggleTitle2"
                ToggleTitle2.Parent = Toggle

                ToggleContent.Font = Enum.Font.GothamBold
                ToggleContent.Text = ToggleConfig.Content
                ToggleContent.TextColor3 = Color3.fromRGB(255, 255, 255)
                ToggleContent.TextSize = 12
                ToggleContent.TextTransparency = 0.6
                ToggleContent.TextXAlignment = Enum.TextXAlignment.Left
                ToggleContent.TextYAlignment = Enum.TextYAlignment.Bottom
                ToggleContent.BackgroundTransparency = 1
                ToggleContent.Size = UDim2.new(1, -100, 0, 12)
                ToggleContent.Name = "ToggleContent"
                ToggleContent.Parent = Toggle

                if ToggleConfig.Title2 ~= "" then
                    Toggle.Size = UDim2.new(1, 0, 0, 57)
                    ToggleContent.Position = UDim2.new(0, 10, 0, 36)
                    ToggleTitle2.Visible = true
                else
                    Toggle.Size = UDim2.new(1, 0, 0, 46)
                    ToggleContent.Position = UDim2.new(0, 10, 0, 23)
                    ToggleTitle2.Visible = false
                end

                ToggleContent.Size = UDim2.new(1, -100, 0,
                    12 + (12 * (ToggleContent.TextBounds.X // ToggleContent.AbsoluteSize.X)))
                ToggleContent.TextWrapped = true
                if ToggleConfig.Title2 ~= "" then
                    Toggle.Size = UDim2.new(1, 0, 0, ToggleContent.AbsoluteSize.Y + 47)
                else
                    Toggle.Size = UDim2.new(1, 0, 0, ToggleContent.AbsoluteSize.Y + 33)
                end

                ToggleContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                    ToggleContent.TextWrapped = false
                    ToggleContent.Size = UDim2.new(1, -100, 0,
                        12 + (12 * (ToggleContent.TextBounds.X // ToggleContent.AbsoluteSize.X)))
                    if ToggleConfig.Title2 ~= "" then
                        Toggle.Size = UDim2.new(Toggle.Size.X.Scale, Toggle.Size.X.Offset, 0,
                            ToggleContent.AbsoluteSize.Y + 47)
                    else
                        Toggle.Size = UDim2.new(Toggle.Size.X.Scale, Toggle.Size.X.Offset, 0,
                            ToggleContent.AbsoluteSize.Y + 33)
                    end
                    ToggleContent.TextWrapped = true
                    UpdateSizeSection()
                end)

                ToggleButton.Font = Enum.Font.SourceSans
                ToggleButton.Text = ""
                ToggleButton.BackgroundTransparency = 1
                ToggleButton.Size = UDim2.new(1, 0, 1, 0)
                ToggleButton.Name = "ToggleButton"
                ToggleButton.Parent = Toggle

                FeatureFrame2.AnchorPoint = Vector2.new(1, 0.5)
                FeatureFrame2.BackgroundTransparency = 0.92
                FeatureFrame2.BorderSizePixel = 0
                FeatureFrame2.Position = UDim2.new(1, -15, 0.5, 0)
                FeatureFrame2.Size = UDim2.new(0, 30, 0, 15)
                FeatureFrame2.Name = "FeatureFrame"
                FeatureFrame2.Parent = Toggle

                UICorner22.Parent = FeatureFrame2

                UIStroke8.Color = Color3.fromRGB(255, 255, 255)
                UIStroke8.Thickness = 2
                UIStroke8.Transparency = 0.9
                UIStroke8.Parent = FeatureFrame2

                ToggleCircle.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
                ToggleCircle.BorderSizePixel = 0
                ToggleCircle.Size = UDim2.new(0, 14, 0, 14)
                ToggleCircle.Name = "ToggleCircle"
                ToggleCircle.Parent = FeatureFrame2

                UICorner23.CornerRadius = UDim.new(0, 15)
                UICorner23.Parent = ToggleCircle

                ToggleButton.Activated:Connect(function()
                    ToggleFunc.Value = not ToggleFunc.Value
                    ToggleFunc:Set(ToggleFunc.Value)
                end)

                function ToggleFunc:Set(Value, noSave)
                    Value = Value and true or false
                    ToggleFunc.Value = Value
                    if typeof(ToggleConfig.Callback) == "function" then
                        local ok, err = pcall(function()
                            ToggleConfig.Callback(Value)
                        end)
                        if not ok then warn("Toggle Callback error:", err) end
                    end
                    if shouldSave then
                        ConfigData[configKey] = Value
                        if not noSave then QueueSaveConfig() end
                    end
                    if Value then
                        TweenService:Create(ToggleTitle, TweenInfo.new(0.2), { TextColor3 = GuiConfig.Color }):Play()
                        TweenService:Create(ToggleCircle, TweenInfo.new(0.2), { Position = UDim2.new(0, 15, 0, 0) })
                            :Play()
                        TweenService:Create(UIStroke8, TweenInfo.new(0.2), { Color = GuiConfig.Color, Transparency = 0.5 })
                            :Play()
                        TweenService:Create(FeatureFrame2, TweenInfo.new(0.2),
                            { BackgroundColor3 = GuiConfig.Color, BackgroundTransparency = 0.3 }):Play()
                    else
                        TweenService:Create(ToggleTitle, TweenInfo.new(0.2),
                            { TextColor3 = Color3.fromRGB(230, 230, 230) }):Play()
                        TweenService:Create(ToggleCircle, TweenInfo.new(0.2), { Position = UDim2.new(0, 0, 0, 0) }):Play()
                        TweenService:Create(UIStroke8, TweenInfo.new(0.2),
                            { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.9 }):Play()
                        TweenService:Create(FeatureFrame2, TweenInfo.new(0.2),
                            { BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.92 }):Play()
                    end
                end

                ToggleFunc:Set(ToggleFunc.Value, true)

                local ToggleLockOverlay = CreateLockOverlay(Toggle, "Locked")
                function ToggleFunc:Lock(text) ToggleLockOverlay:Lock(text) end
                function ToggleFunc:Unlock() ToggleLockOverlay:Unlock() end
                if ToggleConfig.Locked then
                    ToggleFunc:Lock(ToggleConfig.TextLock)
                end

                CountItem = CountItem + 1
                if shouldSave then
                    Elements[configKey] = ToggleFunc
                end
                RegisterSearch({ label = ToggleConfig.Title, tab = TabConfig.Name, kind = "Toggle", element = ToggleFunc, switch = SearchSwitch })
                return ToggleFunc
            end

            function Items:AddSlider(SliderConfig)
                local SliderConfig = SliderConfig or {}
                SliderConfig.Title = SliderConfig.Title or "Slider"
                SliderConfig.Content = SliderConfig.Content or ""
                SliderConfig.Min = tonumber(SliderConfig.Min) or 0
                SliderConfig.Max = tonumber(SliderConfig.Max) or 100
                if SliderConfig.Max < SliderConfig.Min then
                    SliderConfig.Min, SliderConfig.Max = SliderConfig.Max, SliderConfig.Min
                end
                SliderConfig.Default = tonumber(SliderConfig.Default) or SliderConfig.Min
                SliderConfig.Increment = tonumber(SliderConfig.Increment or SliderConfig.Step) or 1
                local sliderSpan = SliderConfig.Max - SliderConfig.Min
                if SliderConfig.Increment <= 0 then
                    SliderConfig.Increment = sliderSpan >= 1 and 1 or (sliderSpan > 0 and math.max(sliderSpan / 100, 0.01) or 1)
                elseif sliderSpan > 0 and SliderConfig.Increment >= sliderSpan then
                    SliderConfig.Increment = sliderSpan >= 1 and 1 or math.max(sliderSpan / 100, 0.01)
                end
                SliderConfig.Live = SliderConfig.Live == true
                SliderConfig.Callback = SliderConfig.Callback or function() end

                local configKey = "Slider_" .. SliderConfig.Title
                local shouldSave = SliderConfig.Save ~= false
                if shouldSave and ConfigData[configKey] ~= nil then
                    SliderConfig.Default = tonumber(ConfigData[configKey]) or SliderConfig.Default
                end

                local SliderFunc = { Value = SliderConfig.Default }

                local Slider = Instance.new("Frame");
                local UICorner15 = Instance.new("UICorner");
                local SliderTitle = Instance.new("TextLabel");
                local SliderContent = Instance.new("TextLabel");
                local SliderInput = Instance.new("Frame");
                local UICorner16 = Instance.new("UICorner");
                local TextBox = Instance.new("TextBox");
                local SliderFrame = Instance.new("Frame");
                local UICorner17 = Instance.new("UICorner");
                local SliderDraggable = Instance.new("Frame");
                local UICorner18 = Instance.new("UICorner");
                local UIStroke5 = Instance.new("UIStroke");
                local SliderCircle = Instance.new("Frame");
                local UICorner19 = Instance.new("UICorner");
                local UIStroke6 = Instance.new("UIStroke");
                local UIStroke7 = Instance.new("UIStroke");

                Slider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Slider.BackgroundTransparency = 0.9350000023841858
                Slider.BorderColor3 = Color3.fromRGB(27, 27, 27)
                Slider.BorderSizePixel = 0
                Slider.LayoutOrder = CountItem
                Slider.Size = UDim2.new(1, 0, 0, 46)
                Slider.Name = "Slider"
                Slider.Parent = SectionAdd

                UICorner15.CornerRadius = UDim.new(0, 4)
                UICorner15.Parent = Slider

                SliderTitle.Font = Enum.Font.GothamBold
                SliderTitle.Text = SliderConfig.Title
                SliderTitle.TextColor3 = Color3.fromRGB(230.77499270439148, 230.77499270439148, 230.77499270439148)
                SliderTitle.TextSize = 13
                SliderTitle.TextXAlignment = Enum.TextXAlignment.Left
                SliderTitle.TextYAlignment = Enum.TextYAlignment.Top
                SliderTitle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                SliderTitle.BackgroundTransparency = 0.9990000128746033
                SliderTitle.BorderColor3 = Color3.fromRGB(27, 27, 27)
                SliderTitle.BorderSizePixel = 0
                SliderTitle.Position = UDim2.new(0, 10, 0, 10)
                SliderTitle.Size = UDim2.new(1, -230, 0, 13)
                SliderTitle.Name = "SliderTitle"
                SliderTitle.Parent = Slider

                SliderContent.Font = Enum.Font.GothamBold
                SliderContent.Text = SliderConfig.Content
                SliderContent.TextColor3 = Color3.fromRGB(255, 255, 255)
                SliderContent.TextSize = 12
                SliderContent.TextTransparency = 0.6000000238418579
                SliderContent.TextXAlignment = Enum.TextXAlignment.Left
                SliderContent.TextYAlignment = Enum.TextYAlignment.Bottom
                SliderContent.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                SliderContent.BackgroundTransparency = 0.9990000128746033
                SliderContent.BorderColor3 = Color3.fromRGB(27, 27, 27)
                SliderContent.BorderSizePixel = 0
                SliderContent.Position = UDim2.new(0, 10, 0, 25)
                SliderContent.Size = UDim2.new(1, -230, 0, 12)
                SliderContent.Name = "SliderContent"
                SliderContent.Parent = Slider

                SliderContent.Size = UDim2.new(1, -230, 0,
                    12 + (12 * (SliderContent.TextBounds.X // SliderContent.AbsoluteSize.X)))
                SliderContent.TextWrapped = true
                Slider.Size = UDim2.new(1, 0, 0, SliderContent.AbsoluteSize.Y + 33)

                SliderContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                    SliderContent.TextWrapped = false
                    SliderContent.Size = UDim2.new(1, -230, 0,
                        12 + (12 * (SliderContent.TextBounds.X // SliderContent.AbsoluteSize.X)))
                    Slider.Size = UDim2.new(Slider.Size.X.Scale, Slider.Size.X.Offset, 0,
                        SliderContent.AbsoluteSize.Y + 33)
                    SliderContent.TextWrapped = true
                    UpdateSizeSection()
                end)

                SliderInput.AnchorPoint = Vector2.new(0, 0.5)
                SliderInput.BackgroundColor3 = GuiConfig.Color
                SliderInput.BorderColor3 = Color3.fromRGB(27, 27, 27)
                SliderInput.BackgroundTransparency = 1
                SliderInput.BorderSizePixel = 0
                SliderInput.Position = UDim2.new(1, -200, 0.5, 0)
                SliderInput.Size = UDim2.new(0, 44, 0, 20)
                SliderInput.Name = "SliderInput"
                SliderInput.Parent = Slider

                UICorner16.CornerRadius = UDim.new(0, 2)
                UICorner16.Parent = SliderInput

                TextBox.Font = Enum.Font.GothamBold
                TextBox.Text = "90"
                TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
                TextBox.TextSize = 13
                TextBox.TextWrapped = true
                TextBox.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
                TextBox.BackgroundTransparency = 0.9990000128746033
                TextBox.BorderColor3 = Color3.fromRGB(27, 27, 27)
                TextBox.BorderSizePixel = 0
                TextBox.Position = UDim2.new(0, -1, 0, 0)
                TextBox.Size = UDim2.new(1, 0, 1, 0)
                TextBox.Parent = SliderInput

                SliderFrame.AnchorPoint = Vector2.new(1, 0.5)
                SliderFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                SliderFrame.BackgroundTransparency = 0.800000011920929
                SliderFrame.BorderColor3 = Color3.fromRGB(27, 27, 27)
                SliderFrame.BorderSizePixel = 0
                SliderFrame.Position = UDim2.new(1, -20, 0.5, 0)
                SliderFrame.Size = UDim2.new(0, 140, 0, 3)
                SliderFrame.Name = "SliderFrame"
                SliderFrame.Parent = Slider

                UICorner17.Parent = SliderFrame

                SliderDraggable.AnchorPoint = Vector2.new(0, 0.5)
                SliderDraggable.BackgroundColor3 = GuiConfig.Color
                SliderDraggable.BorderColor3 = Color3.fromRGB(27, 27, 27)
                SliderDraggable.BorderSizePixel = 0
                SliderDraggable.Position = UDim2.new(0, 0, 0.5, 0)
                SliderDraggable.Size = UDim2.new(0.899999976, 0, 0, 1)
                SliderDraggable.Name = "SliderDraggable"
                SliderDraggable.Parent = SliderFrame

                UICorner18.Parent = SliderDraggable

                SliderCircle.AnchorPoint = Vector2.new(1, 0.5)
                SliderCircle.BackgroundColor3 = GuiConfig.Color
                SliderCircle.BorderColor3 = Color3.fromRGB(27, 27, 27)
                SliderCircle.BorderSizePixel = 0
                SliderCircle.Position = UDim2.new(1, 4, 0.5, 0)
                SliderCircle.Size = UDim2.new(0, 8, 0, 8)
                SliderCircle.Name = "SliderCircle"
                SliderCircle.Parent = SliderDraggable

                UICorner19.Parent = SliderCircle

                UIStroke6.Color = GuiConfig.Color
                UIStroke6.Parent = SliderCircle

                local SliderHitbox = Instance.new("Frame")
                SliderHitbox.AnchorPoint = Vector2.new(1, 0.5)
                SliderHitbox.BackgroundTransparency = 1
                SliderHitbox.BorderSizePixel = 0
                SliderHitbox.Position = UDim2.new(1, -20, 0.5, 0)
                SliderHitbox.Size = UDim2.new(0, 140, 0, 36)
                SliderHitbox.ZIndex = 5
                SliderHitbox.Active = true
                SliderHitbox.Name = "SliderHitbox"
                SliderHitbox.Parent = Slider

                local Dragging = false
                local UpdatingText = false

                local function Round(Number, Factor)
                    if sliderSpan <= 0 then return SliderConfig.Min end
                    local Steps = math.floor(((Number - SliderConfig.Min) / Factor) + 0.5)
                    return SliderConfig.Min + (Steps * Factor)
                end

                local function FormatValue(Value)
                    if math.abs(Value - math.floor(Value)) < 0.000001 then
                        return tostring(math.floor(Value))
                    end
                    local text = string.format("%.4f", Value)
                    text = text:gsub("0+$", ""):gsub("%.$", "")
                    return text
                end

                local function ValueScale(Value)
                    if sliderSpan <= 0 then return 0 end
                    return math.clamp((Value - SliderConfig.Min) / sliderSpan, 0, 1)
                end

                local function ApplySliderValue(Value, noSave, instant, fireCallback)
                    Value = tonumber(Value) or SliderConfig.Min
                    Value = math.clamp(Round(Value, SliderConfig.Increment), SliderConfig.Min, SliderConfig.Max)

                    SliderFunc.Value = Value
                    if shouldSave then
                        ConfigData[configKey] = Value
                    end

                    UpdatingText = true
                    TextBox.Text = FormatValue(Value)
                    UpdatingText = false

                    local targetSize = UDim2.fromScale(ValueScale(Value), 1)
                    if instant then
                        SliderDraggable.Size = targetSize
                    else
                        TweenService:Create(
                            SliderDraggable,
                            TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                            { Size = targetSize }
                        ):Play()
                    end

                    if fireCallback then
                        local ok, err = pcall(function()
                            SliderConfig.Callback(Value)
                        end)
                        if not ok then warn("Slider Callback error:", err) end
                    end

                    if shouldSave and not noSave then QueueSaveConfig() end
                end

                function SliderFunc:Set(Value, noSave)
                    ApplySliderValue(Value, noSave, false, true)
                end

                SliderHitbox.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                        Dragging = true
                        TweenService:Create(
                            SliderCircle,
                            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                            { Size = UDim2.new(0, 14, 0, 14) }
                        ):Play()
                        local SizeScale = math.clamp(
                            (Input.Position.X - SliderFrame.AbsolutePosition.X) / SliderFrame.AbsoluteSize.X,
                            0,
                            1
                        )
                        ApplySliderValue(SliderConfig.Min + (sliderSpan * SizeScale), true, true, SliderConfig.Live)
                    end
                end)

                local function FinishSliderDrag(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                        if not Dragging then return end
                        Dragging = false
                        ApplySliderValue(SliderFunc.Value, false, false, not SliderConfig.Live)
                        TweenService:Create(
                            SliderCircle,
                            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                            { Size = UDim2.new(0, 8, 0, 8) }
                        ):Play()
                    end
                end

                SliderHitbox.InputEnded:Connect(FinishSliderDrag)
                UserInputService.InputEnded:Connect(FinishSliderDrag)

                UserInputService.InputChanged:Connect(function(Input)
                    if Dragging and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
                        local SizeScale = math.clamp(
                            (Input.Position.X - SliderFrame.AbsolutePosition.X) / SliderFrame.AbsoluteSize.X,
                            0,
                            1
                        )
                        ApplySliderValue(SliderConfig.Min + (sliderSpan * SizeScale), true, true, SliderConfig.Live)
                    end
                end)

                TextBox.FocusLost:Connect(function()
                    if UpdatingText then return end
                    local raw = TextBox.Text:gsub(",", ".")
                    local number = tonumber(raw)
                    if number then
                        SliderFunc:Set(number)
                    else
                        TextBox.Text = FormatValue(SliderFunc.Value)
                    end
                end)
                SliderFunc:Set(SliderConfig.Default, true)

                local SliderLockOverlay = CreateLockOverlay(Slider, "Locked")
                function SliderFunc:Lock(text) SliderLockOverlay:Lock(text) end
                function SliderFunc:Unlock() SliderLockOverlay:Unlock() end
                if SliderConfig.Locked then
                    SliderFunc:Lock(SliderConfig.TextLock)
                end
                CountItem = CountItem + 1
                if shouldSave then
                    Elements[configKey] = SliderFunc
                end
                RegisterSearch({ label = SliderConfig.Title, tab = TabConfig.Name, kind = "Slider", element = SliderFunc, switch = SearchSwitch })
                return SliderFunc
            end

            function Items:AddColorPicker(ColorConfig)
                local ColorConfig = ColorConfig or {}
                ColorConfig.Title = ColorConfig.Title or "Color"
                ColorConfig.Content = ColorConfig.Content or ""
                ColorConfig.Default = typeof(ColorConfig.Default) == "Color3" and ColorConfig.Default or Color3.fromRGB(255, 255, 255)
                ColorConfig.Callback = ColorConfig.Callback or function() end
                ColorConfig.Colors = ColorConfig.Colors or {
                    Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 200, 200), Color3.fromRGB(120, 120, 120),
                    Color3.fromRGB(40, 40, 40), Color3.fromRGB(0, 0, 0),
                    Color3.fromRGB(255, 0, 0), Color3.fromRGB(255, 85, 0), Color3.fromRGB(255, 170, 0),
                    Color3.fromRGB(255, 255, 0), Color3.fromRGB(170, 255, 0),
                    Color3.fromRGB(0, 255, 0), Color3.fromRGB(0, 255, 170), Color3.fromRGB(0, 255, 255),
                    Color3.fromRGB(0, 170, 255), Color3.fromRGB(0, 85, 255),
                    Color3.fromRGB(0, 0, 255), Color3.fromRGB(85, 0, 255), Color3.fromRGB(170, 0, 255),
                    Color3.fromRGB(255, 0, 255), Color3.fromRGB(255, 0, 170),
                    Color3.fromRGB(255, 0, 85), Color3.fromRGB(139, 69, 19), Color3.fromRGB(255, 192, 203),
                    Color3.fromRGB(0, 128, 128), Color3.fromRGB(255, 215, 0),
                }

                local configKey = "ColorPicker_" .. ColorConfig.Title
                local shouldSave = ColorConfig.Save ~= false
                if shouldSave and ConfigData[configKey] ~= nil and type(ConfigData[configKey]) == "table" then
                    local c = ConfigData[configKey]
                    ColorConfig.Default = Color3.fromRGB(tonumber(c.R) or 255, tonumber(c.G) or 255, tonumber(c.B) or 255)
                end

                local ColorFunc = { Value = ColorConfig.Default }

                local ColorPicker = Instance.new("Frame")
                ColorPicker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                ColorPicker.BackgroundTransparency = 0.935
                ColorPicker.BorderSizePixel = 0
                ColorPicker.LayoutOrder = CountItem
                ColorPicker.Size = UDim2.new(1, 0, 0, 46)
                ColorPicker.Name = "ColorPicker"
                ColorPicker.Parent = SectionAdd

                local PickerCorner = Instance.new("UICorner")
                PickerCorner.CornerRadius = UDim.new(0, 4)
                PickerCorner.Parent = ColorPicker

                local PickerTitle = Instance.new("TextLabel")
                PickerTitle.Font = Enum.Font.GothamBold
                PickerTitle.Text = ColorConfig.Title
                PickerTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
                PickerTitle.TextSize = 13
                PickerTitle.TextXAlignment = Enum.TextXAlignment.Left
                PickerTitle.TextYAlignment = Enum.TextYAlignment.Top
                PickerTitle.BackgroundTransparency = 1
                PickerTitle.Position = UDim2.new(0, 10, 0, 10)
                PickerTitle.Size = UDim2.new(1, -70, 0, 13)
                PickerTitle.Parent = ColorPicker

                local PickerContent = Instance.new("TextLabel")
                PickerContent.Font = Enum.Font.GothamBold
                PickerContent.Text = ColorConfig.Content
                PickerContent.TextColor3 = Color3.fromRGB(255, 255, 255)
                PickerContent.TextSize = 12
                PickerContent.TextTransparency = 0.6
                PickerContent.TextXAlignment = Enum.TextXAlignment.Left
                PickerContent.TextYAlignment = Enum.TextYAlignment.Bottom
                PickerContent.BackgroundTransparency = 1
                PickerContent.Position = UDim2.new(0, 10, 0, 25)
                PickerContent.Size = UDim2.new(1, -70, 0, 12)
                PickerContent.Parent = ColorPicker

                local Swatch = Instance.new("TextButton")
                Swatch.Text = ""
                Swatch.AnchorPoint = Vector2.new(1, 0.5)
                Swatch.BackgroundColor3 = ColorConfig.Default
                Swatch.BorderSizePixel = 0
                Swatch.Position = UDim2.new(1, -10, 0.5, 0)
                Swatch.Size = UDim2.new(0, 28, 0, 18)
                Swatch.Name = "Swatch"
                Swatch.Parent = ColorPicker

                local SwatchCorner = Instance.new("UICorner")
                SwatchCorner.CornerRadius = UDim.new(0, 4)
                SwatchCorner.Parent = Swatch

                local SwatchStroke = Instance.new("UIStroke")
                SwatchStroke.Color = Color3.fromRGB(255, 255, 255)
                SwatchStroke.Transparency = 0.7
                SwatchStroke.Parent = Swatch

                local function ApplyColor(color, noSave, fireCallback)
                    ColorFunc.Value = color
                    Swatch.BackgroundColor3 = color
                    if shouldSave then
                        ConfigData[configKey] = { R = math.floor(color.R * 255), G = math.floor(color.G * 255), B = math.floor(color.B * 255) }
                    end
                    if fireCallback then
                        local ok, err = pcall(function() ColorConfig.Callback(color) end)
                        if not ok then warn("ColorPicker Callback error:", err) end
                    end
                    if shouldSave and not noSave then QueueSaveConfig() end
                end

                local function OpenPalette()
                    local editH, editS, editV = ColorFunc.Value:ToHSV()
                    local editColor = ColorFunc.Value
                    local svDragging, hueDragging = false, false
                    local Connections = {}

                    local Overlay = Instance.new("Frame")
                    Overlay.Size = UDim2.new(1, 0, 1, 0)
                    Overlay.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
                    Overlay.BackgroundTransparency = 0.35
                    Overlay.ZIndex = 60
                    Overlay.Name = "ColorOverlay"
                    Overlay.Parent = DropShadowHolder

                    local OverlayClose = Instance.new("TextButton")
                    OverlayClose.Text = ""
                    OverlayClose.BackgroundTransparency = 1
                    OverlayClose.Size = UDim2.new(1, 0, 1, 0)
                    OverlayClose.ZIndex = 60
                    OverlayClose.Parent = Overlay

                    local dialogWidth, dialogHeight = 300, 340

                    local Dialog = Instance.new("Frame")
                    Dialog.Size = UDim2.new(0, dialogWidth, 0, dialogHeight)
                    Dialog.Position = UDim2.new(0.5, -dialogWidth / 2, 0.5, -dialogHeight / 2)
                    Dialog.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
                    Dialog.BorderSizePixel = 0
                    Dialog.ZIndex = 61
                    Dialog.Parent = Overlay

                    local DialogCorner = Instance.new("UICorner")
                    DialogCorner.CornerRadius = UDim.new(0, 10)
                    DialogCorner.Parent = Dialog

                    local DialogStroke = Instance.new("UIStroke")
                    DialogStroke.Color = Color3.fromRGB(255, 255, 255)
                    DialogStroke.Transparency = 0.85
                    DialogStroke.Parent = Dialog

                    local DialogTitle = Instance.new("TextLabel")
                    DialogTitle.Font = Enum.Font.GothamBold
                    DialogTitle.Text = ColorConfig.Title
                    DialogTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
                    DialogTitle.TextSize = 15
                    DialogTitle.TextXAlignment = Enum.TextXAlignment.Left
                    DialogTitle.BackgroundTransparency = 1
                    DialogTitle.Position = UDim2.new(0, 14, 0, 12)
                    DialogTitle.Size = UDim2.new(1, -28, 0, 20)
                    DialogTitle.ZIndex = 62
                    DialogTitle.Parent = Dialog

                    local SVBox = Instance.new("Frame")
                    SVBox.Name = "SVBox"
                    SVBox.BackgroundColor3 = Color3.fromHSV(editH, 1, 1)
                    SVBox.BorderSizePixel = 0
                    SVBox.Position = UDim2.new(0, 14, 0, 40)
                    SVBox.Size = UDim2.new(0, 200, 0, 150)
                    SVBox.ZIndex = 62
                    SVBox.Parent = Dialog

                    local SVBoxCorner = Instance.new("UICorner")
                    SVBoxCorner.CornerRadius = UDim.new(0, 8)
                    SVBoxCorner.Parent = SVBox

                    local SVWhiteOverlay = Instance.new("Frame")
                    SVWhiteOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    SVWhiteOverlay.BorderSizePixel = 0
                    SVWhiteOverlay.Size = UDim2.new(1, 0, 1, 0)
                    SVWhiteOverlay.ZIndex = 62
                    SVWhiteOverlay.Parent = SVBox

                    local SVWhiteCorner = Instance.new("UICorner")
                    SVWhiteCorner.CornerRadius = UDim.new(0, 8)
                    SVWhiteCorner.Parent = SVWhiteOverlay

                    local SVWhiteGradient = Instance.new("UIGradient")
                    SVWhiteGradient.Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0),
                        NumberSequenceKeypoint.new(1, 1),
                    })
                    SVWhiteGradient.Parent = SVWhiteOverlay

                    local SVBlackOverlay = Instance.new("Frame")
                    SVBlackOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                    SVBlackOverlay.BorderSizePixel = 0
                    SVBlackOverlay.Size = UDim2.new(1, 0, 1, 0)
                    SVBlackOverlay.ZIndex = 62
                    SVBlackOverlay.Parent = SVBox

                    local SVBlackCorner = Instance.new("UICorner")
                    SVBlackCorner.CornerRadius = UDim.new(0, 8)
                    SVBlackCorner.Parent = SVBlackOverlay

                    local SVBlackGradient = Instance.new("UIGradient")
                    SVBlackGradient.Rotation = 90
                    SVBlackGradient.Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1),
                        NumberSequenceKeypoint.new(1, 0),
                    })
                    SVBlackGradient.Parent = SVBlackOverlay

                    local SVCursor = Instance.new("Frame")
                    SVCursor.AnchorPoint = Vector2.new(0.5, 0.5)
                    SVCursor.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    SVCursor.BorderSizePixel = 0
                    SVCursor.Size = UDim2.new(0, 16, 0, 16)
                    SVCursor.ZIndex = 63
                    SVCursor.Parent = SVBox

                    local SVCursorCorner = Instance.new("UICorner")
                    SVCursorCorner.CornerRadius = UDim.new(1, 0)
                    SVCursorCorner.Parent = SVCursor

                    local SVCursorStroke = Instance.new("UIStroke")
                    SVCursorStroke.Color = GuiConfig.Color
                    SVCursorStroke.Thickness = 2
                    SVCursorStroke.Parent = SVCursor

                    local SVHitbox = Instance.new("TextButton")
                    SVHitbox.Text = ""
                    SVHitbox.BackgroundTransparency = 1
                    SVHitbox.Size = UDim2.new(1, 0, 1, 0)
                    SVHitbox.ZIndex = 64
                    SVHitbox.Parent = SVBox

                    -- Slider Hue
                    local HueSlider = Instance.new("Frame")
                    HueSlider.Name = "HueSlider"
                    HueSlider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    HueSlider.BorderSizePixel = 0
                    HueSlider.Position = UDim2.new(0, 224, 0, 40)
                    HueSlider.Size = UDim2.new(0, 20, 0, 150)
                    HueSlider.ZIndex = 62
                    HueSlider.Parent = Dialog

                    local HueCorner = Instance.new("UICorner")
                    HueCorner.CornerRadius = UDim.new(0, 10)
                    HueCorner.Parent = HueSlider

                    local HueGradient = Instance.new("UIGradient")
                    HueGradient.Rotation = 90
                    HueGradient.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
                        ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
                        ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
                        ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
                        ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
                        ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
                    })
                    HueGradient.Parent = HueSlider

                    local HueCursor = Instance.new("Frame")
                    HueCursor.AnchorPoint = Vector2.new(0.5, 0.5)
                    HueCursor.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    HueCursor.BorderSizePixel = 0
                    HueCursor.Position = UDim2.new(0.5, 0, 0, 0)
                    HueCursor.Size = UDim2.new(0, 26, 0, 10)
                    HueCursor.ZIndex = 63
                    HueCursor.Parent = HueSlider

                    local HueCursorCorner = Instance.new("UICorner")
                    HueCursorCorner.CornerRadius = UDim.new(1, 0)
                    HueCursorCorner.Parent = HueCursor

                    local HueCursorStroke = Instance.new("UIStroke")
                    HueCursorStroke.Color = Color3.fromRGB(32, 32, 32)
                    HueCursorStroke.Thickness = 2
                    HueCursorStroke.Parent = HueCursor

                    local HueHitbox = Instance.new("TextButton")
                    HueHitbox.Text = ""
                    HueHitbox.BackgroundTransparency = 1
                    HueHitbox.Size = UDim2.new(1, 0, 1, 0)
                    HueHitbox.ZIndex = 64
                    HueHitbox.Parent = HueSlider

                    local function CreateField(posX, posY, width, labelText)
                        local Field = Instance.new("Frame")
                        Field.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                        Field.BackgroundTransparency = 0.935
                        Field.BorderSizePixel = 0
                        Field.Position = UDim2.new(0, posX, 0, posY)
                        Field.Size = UDim2.new(0, width, 0, 30)
                        Field.ZIndex = 62
                        Field.Parent = Dialog

                        local FieldCorner = Instance.new("UICorner")
                        FieldCorner.CornerRadius = UDim.new(0, 6)
                        FieldCorner.Parent = Field

                        local ValueBox = Instance.new("TextBox")
                        ValueBox.Font = Enum.Font.GothamBold
                        ValueBox.Text = ""
                        ValueBox.TextColor3 = Color3.fromRGB(255, 255, 255)
                        ValueBox.TextSize = 13
                        ValueBox.TextXAlignment = Enum.TextXAlignment.Left
                        ValueBox.ClearTextOnFocus = false
                        ValueBox.BackgroundTransparency = 1
                        ValueBox.Position = UDim2.new(0, 12, 0, 0)
                        ValueBox.Size = UDim2.new(0.5, -12, 1, 0)
                        ValueBox.ZIndex = 63
                        ValueBox.Parent = Field

                        local Label = Instance.new("TextLabel")
                        Label.Font = Enum.Font.GothamBold
                        Label.Text = labelText
                        Label.TextColor3 = Color3.fromRGB(255, 255, 255)
                        Label.TextTransparency = 0.55
                        Label.TextSize = 12
                        Label.TextXAlignment = Enum.TextXAlignment.Right
                        Label.BackgroundTransparency = 1
                        Label.Position = UDim2.new(0.5, 0, 0, 0)
                        Label.Size = UDim2.new(0.5, -12, 1, 0)
                        Label.ZIndex = 63
                        Label.Parent = Field

                        return ValueBox
                    end

                    local PreviewSwatch = Instance.new("Frame")
                    PreviewSwatch.BackgroundColor3 = editColor
                    PreviewSwatch.BorderSizePixel = 0
                    PreviewSwatch.Position = UDim2.new(0, 14, 0, 204)
                    PreviewSwatch.Size = UDim2.new(0, 30, 0, 30)
                    PreviewSwatch.ZIndex = 62
                    PreviewSwatch.Parent = Dialog

                    local PreviewCorner = Instance.new("UICorner")
                    PreviewCorner.CornerRadius = UDim.new(0, 6)
                    PreviewCorner.Parent = PreviewSwatch

                    local PreviewStroke = Instance.new("UIStroke")
                    PreviewStroke.Color = Color3.fromRGB(255, 255, 255)
                    PreviewStroke.Transparency = 0.7
                    PreviewStroke.Parent = PreviewSwatch

                    local HexBox = CreateField(52, 204, 234, "Hex")
                    local RBox = CreateField(14, 242, 85, "Red")
                    local GBox = CreateField(107, 242, 85, "Green")
                    local BBox = CreateField(200, 242, 85, "Blue")

                    local CancelButton = Instance.new("TextButton")
                    CancelButton.Font = Enum.Font.GothamBold
                    CancelButton.Text = "Cancel"
                    CancelButton.TextColor3 = Color3.fromRGB(235, 235, 235)
                    CancelButton.TextSize = 15
                    CancelButton.AutoButtonColor = false
                    CancelButton.BackgroundColor3 = Color3.fromRGB(52, 52, 56)
                    CancelButton.BorderSizePixel = 0
                    CancelButton.Position = UDim2.new(0, 14, 0, 284)
                    CancelButton.Size = UDim2.new(0, 132, 0, 44)
                    CancelButton.ZIndex = 62
                    CancelButton.Parent = Dialog

                    local CancelCorner = Instance.new("UICorner")
                    CancelCorner.CornerRadius = UDim.new(1, 0)
                    CancelCorner.Parent = CancelButton

                    local CancelStroke = Instance.new("UIStroke")
                    CancelStroke.Color = Color3.fromRGB(255, 255, 255)
                    CancelStroke.Transparency = 0.88
                    CancelStroke.Parent = CancelButton

                    CancelButton.MouseEnter:Connect(function()
                        TweenService:Create(CancelButton, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(64, 64, 69) }):Play()
                    end)
                    CancelButton.MouseLeave:Connect(function()
                        TweenService:Create(CancelButton, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(52, 52, 56) }):Play()
                    end)

                    local accent = GuiConfig.Color
                    local function ClampChannel(v) return math.clamp(v, 0, 1) end
                    local ApplyFill = Color3.new(
                        ClampChannel(accent.R * 0.45 + 0.05),
                        ClampChannel(accent.G * 0.45 + 0.05),
                        ClampChannel(accent.B * 0.45 + 0.05)
                    )
                    local ApplyFillHover = Color3.new(
                        ClampChannel(accent.R * 0.55 + 0.1),
                        ClampChannel(accent.G * 0.55 + 0.1),
                        ClampChannel(accent.B * 0.55 + 0.1)
                    )

                    local ApplyButton = Instance.new("TextButton")
                    ApplyButton.Font = Enum.Font.GothamBold
                    ApplyButton.Text = "Apply"
                    ApplyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                    ApplyButton.TextSize = 15
                    ApplyButton.AutoButtonColor = false
                    ApplyButton.BackgroundColor3 = ApplyFill
                    ApplyButton.BorderSizePixel = 0
                    ApplyButton.Position = UDim2.new(0, 154, 0, 284)
                    ApplyButton.Size = UDim2.new(0, 132, 0, 44)
                    ApplyButton.ZIndex = 62
                    ApplyButton.Parent = Dialog

                    local ApplyCorner = Instance.new("UICorner")
                    ApplyCorner.CornerRadius = UDim.new(1, 0)
                    ApplyCorner.Parent = ApplyButton

                    ApplyButton.MouseEnter:Connect(function()
                        TweenService:Create(ApplyButton, TweenInfo.new(0.15), { BackgroundColor3 = ApplyFillHover }):Play()
                    end)
                    ApplyButton.MouseLeave:Connect(function()
                        TweenService:Create(ApplyButton, TweenInfo.new(0.15), { BackgroundColor3 = ApplyFill }):Play()
                    end)


                    local updatingFields = false

                    local function RefreshUI(skipFields)
                        editColor = Color3.fromHSV(editH, editS, editV)
                        SVBox.BackgroundColor3 = Color3.fromHSV(editH, 1, 1)
                        SVCursor.Position = UDim2.new(editS, 0, 1 - editV, 0)
                        HueCursor.Position = UDim2.new(0.5, 0, editH, 0)
                        PreviewSwatch.BackgroundColor3 = editColor

                        if not skipFields then
                            local r = math.floor(editColor.R * 255 + 0.5)
                            local g = math.floor(editColor.G * 255 + 0.5)
                            local b = math.floor(editColor.B * 255 + 0.5)
                            updatingFields = true
                            HexBox.Text = string.format("#%02X%02X%02X", r, g, b)
                            RBox.Text = tostring(r)
                            GBox.Text = tostring(g)
                            BBox.Text = tostring(b)
                            updatingFields = false
                        end
                    end

                    local function UpdateSVFromInput(inputPos)
                        local relX = math.clamp((inputPos.X - SVBox.AbsolutePosition.X) / SVBox.AbsoluteSize.X, 0, 1)
                        local relY = math.clamp((inputPos.Y - SVBox.AbsolutePosition.Y) / SVBox.AbsoluteSize.Y, 0, 1)
                        editS = relX
                        editV = 1 - relY
                        RefreshUI(false)
                    end

                    local function UpdateHueFromInput(inputPos)
                        local relY = math.clamp((inputPos.Y - HueSlider.AbsolutePosition.Y) / HueSlider.AbsoluteSize.Y, 0, 1)
                        editH = relY
                        RefreshUI(false)
                    end

                    table.insert(Connections, SVHitbox.InputBegan:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                            svDragging = true
                            UpdateSVFromInput(inp.Position)
                        end
                    end))

                    table.insert(Connections, HueHitbox.InputBegan:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                            hueDragging = true
                            UpdateHueFromInput(inp.Position)
                        end
                    end))

                    table.insert(Connections, UserInputService.InputChanged:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
                            if svDragging then UpdateSVFromInput(inp.Position) end
                            if hueDragging then UpdateHueFromInput(inp.Position) end
                        end
                    end))

                    local function StopDragging(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                            svDragging = false
                            hueDragging = false
                        end
                    end
                    table.insert(Connections, UserInputService.InputEnded:Connect(StopDragging))

                    HexBox.FocusLost:Connect(function()
                        if updatingFields then return end
                        local text = HexBox.Text:gsub("#", ""):gsub("%s", "")
                        if #text == 6 and text:match("^%x+$") then
                            local r = tonumber(text:sub(1, 2), 16)
                            local g = tonumber(text:sub(3, 4), 16)
                            local b = tonumber(text:sub(5, 6), 16)
                            editH, editS, editV = Color3.fromRGB(r, g, b):ToHSV()
                        end
                        RefreshUI(false)
                    end)

                    local function ApplyRGBEdit()
                        if updatingFields then return end
                        local curR = math.floor(editColor.R * 255 + 0.5)
                        local curG = math.floor(editColor.G * 255 + 0.5)
                        local curB = math.floor(editColor.B * 255 + 0.5)
                        local r = math.clamp(math.floor(tonumber(RBox.Text) or curR), 0, 255)
                        local g = math.clamp(math.floor(tonumber(GBox.Text) or curG), 0, 255)
                        local b = math.clamp(math.floor(tonumber(BBox.Text) or curB), 0, 255)
                        editH, editS, editV = Color3.fromRGB(r, g, b):ToHSV()
                        RefreshUI(false)
                    end
                    RBox.FocusLost:Connect(ApplyRGBEdit)
                    GBox.FocusLost:Connect(ApplyRGBEdit)
                    BBox.FocusLost:Connect(ApplyRGBEdit)

                    local function CloseModal()
                        for _, connection in ipairs(Connections) do
                            connection:Disconnect()
                        end
                        Overlay:Destroy()
                    end

                    CancelButton.MouseButton1Click:Connect(CloseModal)
                    OverlayClose.MouseButton1Click:Connect(CloseModal)

                    ApplyButton.MouseButton1Click:Connect(function()
                        ApplyColor(editColor, false, true)
                        CloseModal()
                    end)

                    RefreshUI(false)
                end

                Swatch.MouseButton1Click:Connect(OpenPalette)

                function ColorFunc:Set(color, noSave)
                    if typeof(color) == "table" then
                        color = Color3.fromRGB(tonumber(color.R) or 255, tonumber(color.G) or 255, tonumber(color.B) or 255)
                    end
                    ApplyColor(color, noSave, true)
                end

                ApplyColor(ColorConfig.Default, true, true)

                local ColorLockOverlay = CreateLockOverlay(ColorPicker, "Locked")
                function ColorFunc:Lock(text) ColorLockOverlay:Lock(text) end
                function ColorFunc:Unlock() ColorLockOverlay:Unlock() end
                if ColorConfig.Locked then
                    ColorFunc:Lock(ColorConfig.TextLock)
                end

                CountItem = CountItem + 1
                if shouldSave then
                    Elements[configKey] = ColorFunc
                end
                RegisterSearch({ label = ColorConfig.Title, tab = TabConfig.Name, kind = "ColorPicker", element = ColorFunc, switch = SearchSwitch })
                return ColorFunc
            end

            function Items:AddInput(InputConfig)
                local InputConfig = InputConfig or {}
                InputConfig.Title = InputConfig.Title or "Title"
                InputConfig.Content = InputConfig.Content or ""
                InputConfig.Callback = InputConfig.Callback or function() end
                InputConfig.Default = InputConfig.Default or ""
                InputConfig.Placeholder = InputConfig.Placeholder or "Input Here"

                local configKey = "Input_" .. InputConfig.Title
                local shouldSave = InputConfig.Save ~= false
                if shouldSave and ConfigData[configKey] ~= nil then
                    InputConfig.Default = ConfigData[configKey]
                end

                local InputFunc = { Value = InputConfig.Default }

                local Input = Instance.new("Frame");
                local UICorner12 = Instance.new("UICorner");
                local InputTitle = Instance.new("TextLabel");
                local InputContent = Instance.new("TextLabel");
                local InputFrame = Instance.new("Frame");
                local UICorner13 = Instance.new("UICorner");
                local InputTextBox = Instance.new("TextBox");

                Input.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Input.BackgroundTransparency = 0.9350000023841858
                Input.BorderColor3 = Color3.fromRGB(27, 27, 27)
                Input.BorderSizePixel = 0
                Input.LayoutOrder = CountItem
                Input.Size = UDim2.new(1, 0, 0, 46)
                Input.Name = "Input"
                Input.Parent = SectionAdd

                UICorner12.CornerRadius = UDim.new(0, 4)
                UICorner12.Parent = Input

                InputTitle.Font = Enum.Font.GothamBold
                InputTitle.Text = InputConfig.Title or "TextBox"
                InputTitle.TextColor3 = Color3.fromRGB(230.77499270439148, 230.77499270439148, 230.77499270439148)
                InputTitle.TextSize = 13
                InputTitle.TextXAlignment = Enum.TextXAlignment.Left
                InputTitle.TextYAlignment = Enum.TextYAlignment.Top
                InputTitle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                InputTitle.BackgroundTransparency = 0.9990000128746033
                InputTitle.BorderColor3 = Color3.fromRGB(27, 27, 27)
                InputTitle.BorderSizePixel = 0
                InputTitle.Position = UDim2.new(0, 10, 0, 10)
                InputTitle.Size = UDim2.new(1, -180, 0, 13)
                InputTitle.Name = "InputTitle"
                InputTitle.Parent = Input

                InputContent.Font = Enum.Font.GothamBold
                InputContent.Text = InputConfig.Content or "This is a TextBox"
                InputContent.TextColor3 = Color3.fromRGB(255, 255, 255)
                InputContent.TextSize = 12
                InputContent.TextTransparency = 0.6000000238418579
                InputContent.TextWrapped = true
                InputContent.TextXAlignment = Enum.TextXAlignment.Left
                InputContent.TextYAlignment = Enum.TextYAlignment.Bottom
                InputContent.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                InputContent.BackgroundTransparency = 0.9990000128746033
                InputContent.BorderColor3 = Color3.fromRGB(27, 27, 27)
                InputContent.BorderSizePixel = 0
                InputContent.Position = UDim2.new(0, 10, 0, 25)
                InputContent.Size = UDim2.new(1, -180, 0, 12)
                InputContent.Name = "InputContent"
                InputContent.Parent = Input

                InputContent.Size = UDim2.new(1, -180, 0,
                    12 + (12 * (InputContent.TextBounds.X // InputContent.AbsoluteSize.X)))
                InputContent.TextWrapped = true
                Input.Size = UDim2.new(1, 0, 0, InputContent.AbsoluteSize.Y + 33)

                InputContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                    InputContent.TextWrapped = false
                    InputContent.Size = UDim2.new(1, -180, 0,
                        12 + (12 * (InputContent.TextBounds.X // InputContent.AbsoluteSize.X)))
                    Input.Size = UDim2.new(Input.Size.X.Scale, Input.Size.X.Offset, 0,
                        InputContent.AbsoluteSize.Y + 33)
                    InputContent.TextWrapped = true
                    UpdateSizeSection()
                end)

                InputFrame.AnchorPoint = Vector2.new(1, 0.5)
                InputFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                InputFrame.BackgroundTransparency = 0.949999988079071
                InputFrame.BorderColor3 = Color3.fromRGB(27, 27, 27)
                InputFrame.BorderSizePixel = 0
                InputFrame.ClipsDescendants = true
                InputFrame.Position = UDim2.new(1, -7, 0.5, 0)
                InputFrame.Size = UDim2.new(0, 148, 0, 30)
                InputFrame.Name = "InputFrame"
                InputFrame.Parent = Input

                UICorner13.CornerRadius = UDim.new(0, 4)
                UICorner13.Parent = InputFrame

                InputTextBox.CursorPosition = -1
                InputTextBox.Font = Enum.Font.GothamBold
                InputTextBox.PlaceholderColor3 = Color3.fromRGB(120.00000044703484, 120.00000044703484,
                    120.00000044703484)
                InputTextBox.PlaceholderText = InputConfig.Placeholder
                InputTextBox.Text = InputConfig.Default
                InputTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
                InputTextBox.TextSize = 12
                InputTextBox.TextXAlignment = Enum.TextXAlignment.Left
                InputTextBox.AnchorPoint = Vector2.new(0, 0.5)
                InputTextBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                InputTextBox.BackgroundTransparency = 0.9990000128746033
                InputTextBox.BorderColor3 = Color3.fromRGB(27, 27, 27)
                InputTextBox.BorderSizePixel = 0
                InputTextBox.Position = UDim2.new(0, 5, 0.5, 0)
                InputTextBox.Size = UDim2.new(1, -10, 1, -8)
                InputTextBox.Name = "InputTextBox"
                InputTextBox.Parent = InputFrame
                function InputFunc:Set(Value, noSave)
                    Value = tostring(Value or "")
                    InputTextBox.Text = Value
                    InputFunc.Value = Value
                    InputConfig.Callback(Value)
                    if shouldSave then
                        ConfigData[configKey] = Value
                        if not noSave then QueueSaveConfig() end
                    end
                end

                InputFunc:Set(InputFunc.Value, true)

                local InputLockOverlay = CreateLockOverlay(Input, "Locked")
                function InputFunc:Lock(text) InputLockOverlay:Lock(text) end
                function InputFunc:Unlock() InputLockOverlay:Unlock() end
                if InputConfig.Locked then
                    InputFunc:Lock(InputConfig.TextLock)
                end

                InputTextBox.FocusLost:Connect(function()
                    InputFunc:Set(InputTextBox.Text)
                end)
                CountItem = CountItem + 1
                if shouldSave then
                    Elements[configKey] = InputFunc
                end
                RegisterSearch({ label = InputConfig.Title, tab = TabConfig.Name, kind = "Input", element = InputFunc, switch = SearchSwitch })
                return InputFunc
            end

            function Items:AddKeybind(KeybindConfig)
                local KeybindConfig = KeybindConfig or {}
                
                -- Sembunyikan Keybind sepenuhnya jika dimainkan di Mobile/Android
                if isMobile then
                    local DummyFunc = { Value = Enum.KeyCode.Unknown }
                    function DummyFunc:Set(kc) end
                    function DummyFunc:GetValue() return Enum.KeyCode.Unknown end
                    return DummyFunc
                end

                KeybindConfig.Title   = KeybindConfig.Title   or "Keybind"
                KeybindConfig.Content = KeybindConfig.Content or ""
                KeybindConfig.Default = KeybindConfig.Default or Enum.KeyCode.Unknown
                KeybindConfig.Callback = KeybindConfig.Callback or function() end

                local configKey = "Keybind_" .. KeybindConfig.Title
                local shouldSave = KeybindConfig.Save ~= false
                if shouldSave and ConfigData[configKey] ~= nil then
                    local ok, kc = pcall(function()
                        return Enum.KeyCode[ConfigData[configKey]]
                    end)
                    if ok and kc then KeybindConfig.Default = kc end
                end

                local KeybindFunc = { Value = KeybindConfig.Default }
                local listening = false

                local KeyRow = Instance.new("Frame")
                KeyRow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                KeyRow.BackgroundTransparency = 0.935
                KeyRow.BorderSizePixel = 0
                KeyRow.LayoutOrder = CountItem
                KeyRow.Size = UDim2.new(1, 0, 0, 46)
                KeyRow.Name = "Keybind"
                KeyRow.Parent = SectionAdd

                local KeyCorner = Instance.new("UICorner")
                KeyCorner.CornerRadius = UDim.new(0, 4)
                KeyCorner.Parent = KeyRow

                local KeyTitle = Instance.new("TextLabel")
                KeyTitle.Font = Enum.Font.GothamBold
                KeyTitle.Text = KeybindConfig.Title
                KeyTitle.TextColor3 = Color3.fromRGB(231, 231, 231)
                KeyTitle.TextSize = 13
                KeyTitle.TextXAlignment = Enum.TextXAlignment.Left
                KeyTitle.TextYAlignment = Enum.TextYAlignment.Top
                KeyTitle.BackgroundTransparency = 1
                KeyTitle.Position = UDim2.new(0, 10, 0, 10)
                KeyTitle.Size = UDim2.new(1, -110, 0, 13)
                KeyTitle.Parent = KeyRow

                local KeyContent = Instance.new("TextLabel")
                KeyContent.Font = Enum.Font.GothamBold
                KeyContent.Text = KeybindConfig.Content
                KeyContent.TextColor3 = Color3.fromRGB(255, 255, 255)
                KeyContent.TextSize = 12
                KeyContent.TextTransparency = 0.6
                KeyContent.TextXAlignment = Enum.TextXAlignment.Left
                KeyContent.TextYAlignment = Enum.TextYAlignment.Bottom
                KeyContent.BackgroundTransparency = 1
                KeyContent.Position = UDim2.new(0, 10, 0, 25)
                KeyContent.Size = UDim2.new(1, -110, 0, 12)
                KeyContent.Parent = KeyRow

                -- [DESAIN MODERN] Tombol Keybind ala Keycap
                local KeyBtn = Instance.new("TextButton")
                KeyBtn.Font = Enum.Font.GothamBold
                KeyBtn.Text = KeybindConfig.Default ~= Enum.KeyCode.Unknown
                    and KeybindConfig.Default.Name
                    or "None"
                KeyBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
                KeyBtn.TextSize = 12
                KeyBtn.TextWrapped = true
                KeyBtn.AutoButtonColor = false
                KeyBtn.BackgroundColor3 = Color3.fromRGB(47, 47, 47)
                KeyBtn.BackgroundTransparency = 0.2
                KeyBtn.BorderSizePixel = 0
                KeyBtn.AnchorPoint = Vector2.new(1, 0.5)
                KeyBtn.Position = UDim2.new(1, -10, 0.5, 0)
                KeyBtn.Size = UDim2.new(0, 70, 0, 28)
                KeyBtn.Name = "KeyBtn"
                KeyBtn.Parent = KeyRow

                local KeyBtnCorner = Instance.new("UICorner")
                KeyBtnCorner.CornerRadius = UDim.new(0, 8) -- Sudut membulat modern
                KeyBtnCorner.Parent = KeyBtn

                local KeyBtnStroke = Instance.new("UIStroke")
                KeyBtnStroke.Color = Color3.fromRGB(72, 72, 72)
                KeyBtnStroke.Thickness = 1
                KeyBtnStroke.Transparency = 0.2
                KeyBtnStroke.Parent = KeyBtn

                -- [DESAIN MODERN] Warna default dan hover
                local defaultBg = Color3.fromRGB(47, 47, 47)
                local defaultBgTrans = 0.2
                local defaultStroke = Color3.fromRGB(72, 72, 72)
                local defaultText = Color3.fromRGB(200, 200, 200)
                local hoverBg = Color3.fromRGB(57, 57, 57)
                local hoverStroke = Color3.fromRGB(90, 90, 90)

                local function SetListening(state)
                    listening = state
                    if state then
                        KeyBtn.Text = "..."
                        -- Saat menunggu input, tombol menyala sesuai warna tema
                        TweenService:Create(KeyBtnStroke, TweenInfo.new(0.2), { Color = GuiConfig.Color, Transparency = 0 }):Play()
                        TweenService:Create(KeyBtn, TweenInfo.new(0.2), { BackgroundColor3 = GuiConfig.Color, BackgroundTransparency = 0.85 }):Play()
                        TweenService:Create(KeyBtn, TweenInfo.new(0.2), { TextColor3 = GuiConfig.Color }):Play()
                    else
                        local label = KeybindFunc.Value ~= Enum.KeyCode.Unknown
                            and KeybindFunc.Value.Name
                            or "None"
                        KeyBtn.Text = label
                        TweenService:Create(KeyBtnStroke, TweenInfo.new(0.2), { Color = defaultStroke, Transparency = 0.2 }):Play()
                        TweenService:Create(KeyBtn, TweenInfo.new(0.2), { BackgroundColor3 = defaultBg, BackgroundTransparency = defaultBgTrans }):Play()
                        TweenService:Create(KeyBtn, TweenInfo.new(0.2), { TextColor3 = defaultText }):Play()
                    end
                end

                -- [DESAIN MODERN] Efek Hover
                KeyBtn.MouseEnter:Connect(function()
                    if not listening then
                        TweenService:Create(KeyBtn, TweenInfo.new(0.15), { BackgroundColor3 = hoverBg }):Play()
                        TweenService:Create(KeyBtnStroke, TweenInfo.new(0.15), { Color = hoverStroke }):Play()
                    end
                end)

                KeyBtn.MouseLeave:Connect(function()
                    if not listening then
                        TweenService:Create(KeyBtn, TweenInfo.new(0.15), { BackgroundColor3 = defaultBg, BackgroundTransparency = defaultBgTrans }):Play()
                        TweenService:Create(KeyBtnStroke, TweenInfo.new(0.15), { Color = defaultStroke, Transparency = 0.2 }):Play()
                    end
                end)

                function KeybindFunc:Set(kc, noSave)
                    if type(kc) == "string" then
                        local ok, converted = pcall(function() return Enum.KeyCode[kc] end)
                        kc = (ok and converted) or Enum.KeyCode.Unknown
                    end
                    kc = kc or Enum.KeyCode.Unknown

                    KeybindFunc.Value = kc
                    local label = kc ~= Enum.KeyCode.Unknown and kc.Name or "None"
                    KeyBtn.Text = label
                    if shouldSave then
                        ConfigData[configKey] = kc.Name
                        if not noSave then QueueSaveConfig() end
                    end
                end

                KeyBtn.MouseButton1Click:Connect(function()
                    SetListening(not listening)
                end)

                -- PERBAIKAN: Cegah bug nyala sendiri 
                -- 1. Jangan trigger jika sedang mengetik di chat/UI lain (gpe)
                -- 2. Jangan trigger jika keybind belum diset (Unknown)
                UserInputService.InputBegan:Connect(function(input, gpe)
                    if not listening then
                        if gpe then return end
                        if KeybindFunc.Value == Enum.KeyCode.Unknown then return end
                        
                        if input.KeyCode == KeybindFunc.Value then
                            local ok, err = pcall(KeybindConfig.Callback, KeybindFunc.Value)
                            if not ok then warn("Keybind Callback error:", err) end
                        end
                        return
                    end
                    
                    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
                    if input.KeyCode == Enum.KeyCode.Escape then
                        SetListening(false)
                        return
                    end
                    KeybindFunc:Set(input.KeyCode, false)
                    local ok, err = pcall(KeybindConfig.Callback, KeybindFunc.Value)
                    if not ok then warn("Keybind Callback error:", err) end
                    SetListening(false)
                end)

                KeybindFunc:Set(KeybindConfig.Default, true)

                local KeybindLockOverlay = CreateLockOverlay(KeyRow, "Locked")
                function KeybindFunc:Lock(text) KeybindLockOverlay:Lock(text) end
                function KeybindFunc:Unlock() KeybindLockOverlay:Unlock() end
                if KeybindConfig.Locked then
                    KeybindFunc:Lock(KeybindConfig.TextLock)
                end
                CountItem = CountItem + 1
                if shouldSave then
                    Elements[configKey] = KeybindFunc
                end
                RegisterSearch({ label = KeybindConfig.Title, tab = TabConfig.Name, kind = "Keybind", element = KeybindFunc, switch = SearchSwitch })
                return KeybindFunc
            end

            function Items:AddDropdown(DropdownConfig)
                local DropdownConfig = DropdownConfig or {}
                DropdownConfig.Title = DropdownConfig.Title or "Title"
                DropdownConfig.Content = DropdownConfig.Content or ""
                DropdownConfig.Multi = DropdownConfig.Multi or false
                DropdownConfig.Options = DropdownConfig.Options or {}
                DropdownConfig.Default = DropdownConfig.Default or (DropdownConfig.Multi and {} or nil)
                DropdownConfig.Callback = DropdownConfig.Callback or function() end

                local configKey = "Dropdown_" .. DropdownConfig.Title
                local shouldSave = DropdownConfig.Save ~= false
                if shouldSave and ConfigData[configKey] ~= nil then
                    DropdownConfig.Default = ConfigData[configKey]
                end

                local DropdownFunc = { Value = DropdownConfig.Default, Options = DropdownConfig.Options }

                local Dropdown = Instance.new("Frame")
                local DropdownButton = Instance.new("TextButton")
                local UICorner10 = Instance.new("UICorner")
                local DropdownTitle = Instance.new("TextLabel")
                local DropdownContent = Instance.new("TextLabel")
                local SelectOptionsFrame = Instance.new("Frame")
                local UICorner11 = Instance.new("UICorner")
                local OptionSelecting = Instance.new("TextLabel")
                local OptionImg = Instance.new("ImageLabel")

                Dropdown.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Dropdown.BackgroundTransparency = 0.935
                Dropdown.BorderSizePixel = 0
                Dropdown.LayoutOrder = CountItem
                Dropdown.Size = UDim2.new(1, 0, 0, 46)
                Dropdown.Name = "Dropdown"
                Dropdown.Parent = SectionAdd

                DropdownButton.Text = ""
                DropdownButton.BackgroundTransparency = 1
                DropdownButton.Size = UDim2.new(1, 0, 1, 0)
                DropdownButton.Name = "ToggleButton"
                DropdownButton.Parent = Dropdown

                UICorner10.CornerRadius = UDim.new(0, 4)
                UICorner10.Parent = Dropdown

                DropdownTitle.Font = Enum.Font.GothamBold
                DropdownTitle.Text = DropdownConfig.Title
                DropdownTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
                DropdownTitle.TextSize = 13
                DropdownTitle.TextXAlignment = Enum.TextXAlignment.Left
                DropdownTitle.BackgroundTransparency = 1
                DropdownTitle.Position = UDim2.new(0, 10, 0, 10)
                DropdownTitle.Size = UDim2.new(1, -180, 0, 13)
                DropdownTitle.Name = "DropdownTitle"
                DropdownTitle.Parent = Dropdown

                DropdownContent.Font = Enum.Font.GothamBold
                DropdownContent.Text = DropdownConfig.Content
                DropdownContent.TextColor3 = Color3.fromRGB(255, 255, 255)
                DropdownContent.TextSize = 12
                DropdownContent.TextTransparency = 0.6
                DropdownContent.TextWrapped = true
                DropdownContent.TextXAlignment = Enum.TextXAlignment.Left
                DropdownContent.BackgroundTransparency = 1
                DropdownContent.Position = UDim2.new(0, 10, 0, 25)
                DropdownContent.Size = UDim2.new(1, -180, 0, 12)
                DropdownContent.Name = "DropdownContent"
                DropdownContent.Parent = Dropdown

                SelectOptionsFrame.AnchorPoint = Vector2.new(1, 0.5)
                SelectOptionsFrame.BackgroundTransparency = 0.95
                SelectOptionsFrame.Position = UDim2.new(1, -7, 0.5, 0)
                SelectOptionsFrame.Size = UDim2.new(0, 148, 0, 30)
                SelectOptionsFrame.Name = "SelectOptionsFrame"
                SelectOptionsFrame.LayoutOrder = CountDropdown
                SelectOptionsFrame.Parent = Dropdown

                UICorner11.CornerRadius = UDim.new(0, 4)
                UICorner11.Parent = SelectOptionsFrame

                DropdownButton.Activated:Connect(function()
                    if not MoreBlur.Visible then
                        MoreBlur.Visible = true
                        DropPageLayout:JumpToIndex(SelectOptionsFrame.LayoutOrder)
                        TweenService:Create(MoreBlur, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
                        TweenService:Create(DropdownSelect, TweenInfo.new(0.3), { Position = UDim2.new(1, -11, 0.5, 0) })
                            :Play()
                    end
                end)

                OptionSelecting.Font = Enum.Font.GothamBold
                OptionSelecting.Text = DropdownConfig.Multi and "Select Options" or "Select Option"
                OptionSelecting.TextColor3 = Color3.fromRGB(255, 255, 255)
                OptionSelecting.TextSize = 12
                OptionSelecting.TextTransparency = 0.6
                OptionSelecting.TextXAlignment = Enum.TextXAlignment.Left
                OptionSelecting.AnchorPoint = Vector2.new(0, 0.5)
                OptionSelecting.BackgroundTransparency = 1
                OptionSelecting.Position = UDim2.new(0, 5, 0.5, 0)
                OptionSelecting.Size = UDim2.new(1, -30, 1, -8)
                OptionSelecting.Name = "OptionSelecting"
                OptionSelecting.Parent = SelectOptionsFrame

                OptionImg.Image = "rbxassetid://16851841101"
                OptionImg.ImageColor3 = Color3.fromRGB(230, 230, 230)
                OptionImg.AnchorPoint = Vector2.new(1, 0.5)
                OptionImg.BackgroundTransparency = 1
                OptionImg.Position = UDim2.new(1, 0, 0.5, 0)
                OptionImg.Size = UDim2.new(0, 25, 0, 25)
                OptionImg.Name = "OptionImg"
                OptionImg.Parent = SelectOptionsFrame

                local DropdownContainer = Instance.new("Frame")
                DropdownContainer.Size = UDim2.new(1, 0, 1, 0)
                DropdownContainer.BackgroundTransparency = 1
                DropdownContainer.Parent = DropdownFolder

                local SearchBox = Instance.new("TextBox")
                SearchBox.PlaceholderText = "Search"
                SearchBox.Font = Enum.Font.Gotham
                SearchBox.Text = ""
                SearchBox.TextSize = 12
                SearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
                SearchBox.BackgroundColor3 = Color3.fromRGB(42, 42, 42)
                SearchBox.BackgroundTransparency = 0.9
                SearchBox.BorderSizePixel = 0
                SearchBox.Size = UDim2.new(1, 0, 0, 25)
                SearchBox.Position = UDim2.new(0, 0, 0, 0)
                SearchBox.ClearTextOnFocus = false
                SearchBox.Name = "SearchBox"
                SearchBox.Parent = DropdownContainer

                local ScrollSelect = Instance.new("ScrollingFrame")
                ScrollSelect.Size = UDim2.new(1, 0, 1, -30)
                ScrollSelect.Position = UDim2.new(0, 0, 0, 30)
                ScrollSelect.ScrollBarImageTransparency = 1
                ScrollSelect.BorderSizePixel = 0
                ScrollSelect.BackgroundTransparency = 1
                ScrollSelect.ScrollBarThickness = 0
                ScrollSelect.CanvasSize = UDim2.new(0, 0, 0, 0)
                ScrollSelect.Name = "ScrollSelect"
                ScrollSelect.Parent = DropdownContainer

                local UIListLayout4 = Instance.new("UIListLayout")
                UIListLayout4.Padding = UDim.new(0, 3)
                UIListLayout4.SortOrder = Enum.SortOrder.LayoutOrder
                UIListLayout4.Parent = ScrollSelect

                UIListLayout4:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    ScrollSelect.CanvasSize = UDim2.new(0, 0, 0, UIListLayout4.AbsoluteContentSize.Y)
                end)

                local dropdownSearchTicket = 0
                local function RunDropdownSearch()
                    local query = string.lower(SearchBox.Text)
                    for _, option in pairs(ScrollSelect:GetChildren()) do
                        if option.Name == "Option" and option:FindFirstChild("OptionText") then
                            local text = string.lower(option.OptionText.Text)
                            option.Visible = query == "" or string.find(text, query, 1, true)
                        end
                    end
                    ScrollSelect.CanvasSize = UDim2.new(0, 0, 0, UIListLayout4.AbsoluteContentSize.Y)
                end

                SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
                    dropdownSearchTicket = dropdownSearchTicket + 1
                    local ticket = dropdownSearchTicket
                    task.delay(0.08, function()
                        if ticket == dropdownSearchTicket then
                            RunDropdownSearch()
                        end
                    end)
                end)

                local DropCount = 0

                function DropdownFunc:Clear()
                    for _, DropFrame in ScrollSelect:GetChildren() do
                        if DropFrame.Name == "Option" then
                            DropFrame:Destroy()
                        end
                    end
                    DropdownFunc.Value = DropdownConfig.Multi and {} or nil
                    DropdownFunc.Options = {}
                    OptionSelecting.Text = DropdownConfig.Multi and "Select Options" or "Select Option"
                    DropCount = 0
                end

                function DropdownFunc:AddOption(option)
                    local label, value
                    if typeof(option) == "table" and option.Label and option.Value ~= nil then
                        label = tostring(option.Label)
                        value = option.Value
                    else
                        label = tostring(option)
                        value = option
                    end

                    local Option = Instance.new("Frame")
                    local OptionButton = Instance.new("TextButton")
                    local OptionText = Instance.new("TextLabel")
                    local ChooseFrame = Instance.new("Frame")
                    local UIStroke15 = Instance.new("UIStroke")
                    local UICorner38 = Instance.new("UICorner")
                    local UICorner37 = Instance.new("UICorner")

                    Option.BackgroundTransparency = 1
                    Option.Size = UDim2.new(1, 0, 0, 30)
                    Option.Name = "Option"
                    Option.Parent = ScrollSelect

                    UICorner37.CornerRadius = UDim.new(0, 3)
                    UICorner37.Parent = Option

                    OptionButton.BackgroundTransparency = 1
                    OptionButton.Size = UDim2.new(1, 0, 1, 0)
                    OptionButton.Text = ""
                    OptionButton.Name = "OptionButton"
                    OptionButton.Parent = Option

                    OptionText.Font = Enum.Font.GothamBold
                    OptionText.Text = label
                    OptionText.TextSize = 13
                    OptionText.TextColor3 = Color3.fromRGB(230, 230, 230)
                    OptionText.Position = UDim2.new(0, 8, 0, 8)
                    OptionText.Size = UDim2.new(1, -100, 0, 13)
                    OptionText.BackgroundTransparency = 1
                    OptionText.TextXAlignment = Enum.TextXAlignment.Left
                    OptionText.Name = "OptionText"
                    OptionText.Parent = Option

                    Option:SetAttribute("RealValue", value)

                    ChooseFrame.AnchorPoint = Vector2.new(0, 0.5)
                    ChooseFrame.BackgroundColor3 = GuiConfig.Color
                    ChooseFrame.Position = UDim2.new(0, 2, 0.5, 0)
                    ChooseFrame.Size = UDim2.new(0, 0, 0, 0)
                    ChooseFrame.Name = "ChooseFrame"
                    ChooseFrame.Parent = Option

                    UIStroke15.Color = GuiConfig.Color
                    UIStroke15.Thickness = 1.6
                    UIStroke15.Transparency = 0.999
                    UIStroke15.Parent = ChooseFrame
                    UICorner38.Parent = ChooseFrame

                    OptionButton.Activated:Connect(function()
                        if DropdownConfig.Multi then
                            if not table.find(DropdownFunc.Value, value) then
                                table.insert(DropdownFunc.Value, value)
                            else
                                for i, v in pairs(DropdownFunc.Value) do
                                    if v == value then
                                        table.remove(DropdownFunc.Value, i)
                                        break
                                    end
                                end
                            end
                        else
                            DropdownFunc.Value = value
                        end
                        DropdownFunc:Set(DropdownFunc.Value)
                    end)
                end

                function DropdownFunc:Set(Value, noSave)
                    task.spawn(function()
                        if DropdownConfig.Multi then
                            DropdownFunc.Value = type(Value) == "table" and Value or {}
                        else
                            DropdownFunc.Value = (type(Value) == "table" and Value[1]) or Value
                        end

                        if shouldSave then
                            ConfigData[configKey] = DropdownFunc.Value
                            if not noSave then QueueSaveConfig() end
                        end

                        local texts = {}
                        for _, Drop in ScrollSelect:GetChildren() do
                            if Drop.Name == "Option" and Drop:FindFirstChild("OptionText") then
                                local v = Drop:GetAttribute("RealValue")
                                local selected = DropdownConfig.Multi and table.find(DropdownFunc.Value, v) or
                                    DropdownFunc.Value == v

                                if selected then
                                    TweenService:Create(Drop.ChooseFrame, TweenInfo.new(0.2),
                                        { Size = UDim2.new(0, 1, 0, 12) }):Play()
                                    TweenService:Create(Drop.ChooseFrame.UIStroke, TweenInfo.new(0.2), { Transparency = 0 })
                                        :Play()
                                    TweenService:Create(Drop, TweenInfo.new(0.2), { BackgroundTransparency = 0.935 }):Play()
                                    table.insert(texts, Drop.OptionText.Text)
                                else
                                    TweenService:Create(Drop.ChooseFrame, TweenInfo.new(0.1),
                                        { Size = UDim2.new(0, 0, 0, 0) }):Play()
                                    TweenService:Create(Drop.ChooseFrame.UIStroke, TweenInfo.new(0.1),
                                        { Transparency = 0.999 }):Play()
                                    TweenService:Create(Drop, TweenInfo.new(0.1), { BackgroundTransparency = 0.999 }):Play()
                                end
                            end
                        end

                        OptionSelecting.Text = (#texts == 0)
                            and (DropdownConfig.Multi and "Select Options" or "Select Option")
                            or table.concat(texts, ", ")

                        if DropdownConfig.Callback then
                            if DropdownConfig.Multi then
                                DropdownConfig.Callback(DropdownFunc.Value)
                            else
                                local str = (DropdownFunc.Value ~= nil) and tostring(DropdownFunc.Value) or ""
                                DropdownConfig.Callback(str)
                            end
                        end
                    end)
                end

                function DropdownFunc:SetValue(val)
                    self:Set(val)
                end

                function DropdownFunc:GetValue()
                    return self.Value
                end

                function DropdownFunc:SetValues(newList, selecting, noSave)
                    newList = newList or {}
                    selecting = selecting or (DropdownConfig.Multi and {} or nil)
                    DropdownFunc:Clear()
                    task.spawn(function()
                        for i, v in ipairs(newList) do
                            DropdownFunc:AddOption(v)
                            if i % 20 == 0 then
                                task.wait()
                            end
                        end
                        DropdownFunc:Set(selecting, noSave)
                    end)
                    DropdownFunc.Options = newList
                end

                DropdownFunc:SetValues(DropdownFunc.Options, DropdownFunc.Value, true)

                local DropdownLockOverlay = CreateLockOverlay(Dropdown, "Locked")
                function DropdownFunc:Lock(text) DropdownLockOverlay:Lock(text) end
                function DropdownFunc:Unlock() DropdownLockOverlay:Unlock() end
                if DropdownConfig.Locked then
                    DropdownFunc:Lock(DropdownConfig.TextLock)
                end

                CountItem = CountItem + 1
                CountDropdown = CountDropdown + 1
                if shouldSave then
                    Elements[configKey] = DropdownFunc
                end
                RegisterSearch({ label = DropdownConfig.Title, tab = TabConfig.Name, kind = "Dropdown", element = DropdownFunc, switch = SearchSwitch })
                return DropdownFunc
            end

            function Items:AddConfig(ConfigCfg)
                ConfigCfg = ConfigCfg or {}

                local autoName = GuiFunc:GetAutoLoad()
                local currentName = ""
                local importJson = ""
                local selectedConfig = autoName ~= "" and autoName or nil

                local NameInput = Items:AddInput({
                    Title       = "Config Name",
                    Content     = "Name for saving",
                    Placeholder = "MyConfig",
                    Save        = false,
                    Callback    = function(text) currentName = text end,
                })

                local ConfigList
                local function RefreshList()
                    local list = GuiFunc:GetConfigs()
                    if ConfigList and ConfigList.SetValues then
                        ConfigList:SetValues(list, selectedConfig, true)
                    end
                end

                ConfigList = Items:AddDropdown({
                    Title    = "Saved Configs",
                    Content  = "Select a config",
                    Multi    = false,
                    Options  = GuiFunc:GetConfigs(),
                    Default  = selectedConfig,
                    Save     = false,
                    Callback = function(choice)
                        selectedConfig = choice ~= "" and choice or nil
                        -- SARAN: Auto isi NameInput saat memilih config dari Dropdown
                        if selectedConfig and NameInput then
                            currentName = selectedConfig
                            NameInput:Set(selectedConfig)
                        end
                    end,
                })

                Items:AddButton({
                    Title    = "Save",
                    SubTitle = "Load",
                    Callback = function()
                        if GuiFunc:SaveConfigAs(currentName) then
                            selectedConfig = currentName
                            RefreshList()
                        end
                    end,
                    SubCallback = function()
                        if selectedConfig then GuiFunc:LoadConfigByName(selectedConfig) end
                    end,
                })

                Items:AddButton({
                    Title    = "Delete",
                    SubTitle = "Refresh List",
                    Callback = function()
                        if selectedConfig then
                            GuiFunc:DeleteConfig(selectedConfig)
                            selectedConfig = nil
                            RefreshList()
                        end
                    end,
                    SubCallback = function()
                        RefreshList()
                    end,
                })

                -- PERBARUAN: Tombol Auto Save
                local AutoSaveToggle
                AutoSaveToggle = Items:AddToggle({
                    Title    = "Auto Save",
                    Content  = "Save changes automatically",
                    Default  = AutoSaveEnabled,
                    Save     = false,
                    Callback = function(value)
                        AutoSaveEnabled = value
                        SetActiveConfig(ActiveConfigName, ActiveConfigPath, AutoSaveEnabled, ActiveConfigMode)
                        if value then
                            than("Auto Save diaktifkan", 4, GuiConfig.Color, "OxioHub", "Config")
                        else
                            than("Auto Save dimatikan", 4, Color3.fromRGB(255, 170, 0), "OxioHub", "Config")
                        end
                    end,
                })

                local AutoToggle
                local initializingAutoToggle = true
                AutoToggle = Items:AddToggle({
                    Title    = "Auto Load",
                    Content  = autoName ~= "" and ("Auto: " .. autoName) or "Load selected on startup",
                    Default  = autoName ~= "",
                    Save     = false,
                    Callback = function(value)
                        if initializingAutoToggle then return end
                        if value and selectedConfig then
                            GuiFunc:SetAutoLoad(selectedConfig)
                            than("Auto load set to '" .. selectedConfig .. "'", 4, GuiConfig.Color, "OxioHub", "Config")
                        elseif value then
                            GuiFunc:SetAutoLoad("")
                            if AutoToggle then AutoToggle:Set(false, true) end
                            than("Select a config first", 4, Color3.fromRGB(255, 170, 0), "OxioHub", "Config")
                        else
                            GuiFunc:SetAutoLoad("")
                        end
                    end,
                })
                initializingAutoToggle = false

                local ImportInput = Items:AddInput({
                    Title       = "Import JSON",
                    Content     = "Paste exported config",
                    Placeholder = "{...}",
                    Save        = false,
                    Callback    = function(text) importJson = text end,
                })

                Items:AddButton({
                    Title    = "Import JSON",
                    SubTitle = "Import from Clipboard",
                    Callback = function()
                        if GuiFunc:ImportConfig(importJson) then
                            RefreshList()
                        end
                    end,
                    SubCallback = function()
                        local clip = (getclipboard and getclipboard()) or ""
                        if GuiFunc:ImportConfig(clip) then
                            RefreshList()
                        end
                    end,
                })

                Items:AddButton({
                    Title    = "Export to Clipboard",
                    Callback = function()
                        GuiFunc:ExportConfig()
                    end,
                })

                return { Refresh = RefreshList }
            end

            function Items:AddBanner(BannerConfig)
                BannerConfig = BannerConfig or {}
                local asset = tostring(BannerConfig.Image or BannerConfig.Banner or "")
                if asset ~= "" and not string.find(asset, "rbxassetid://") then
                    asset = "rbxassetid://" .. asset
                end

                local ratio = BannerConfig.AspectRatio or (16 / 5)

                local Banner = Instance.new("Frame")
                Banner.BackgroundColor3 = Color3.fromRGB(34, 34, 34)
                Banner.BackgroundTransparency = 0.2
                Banner.BorderSizePixel = 0
                Banner.ClipsDescendants = true
                Banner.LayoutOrder = CountItem
                Banner.Size = UDim2.new(1, 0, 0, 110)
                Banner.Name = "Banner"
                Banner.Parent = SectionAdd

                local BannerCorner = Instance.new("UICorner")
                BannerCorner.CornerRadius = UDim.new(0, 8)
                BannerCorner.Parent = Banner

                local function FitHeight()
                    local w = Banner.AbsoluteSize.X
                    if w > 0 then
                        local h = math.floor(w / ratio)
                        if math.abs(Banner.Size.Y.Offset - h) > 1 then
                            Banner.Size = UDim2.new(Banner.Size.X.Scale, Banner.Size.X.Offset, 0, h)
                            UpdateSizeSection()
                        end
                    end
                end

                if asset ~= "" then
                    local Img = Instance.new("ImageLabel")
                    Img.Image = asset
                    Img.BackgroundTransparency = 1
                    Img.ScaleType = Enum.ScaleType.Crop
                    Img.Size = UDim2.new(1, 0, 1, 0)
                    Img.Name = "BannerImage"
                    Img.Parent = Banner
                else
                    local Grad = Instance.new("UIGradient")
                    Grad.Color = ColorSequence.new {
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 34, 34)),
                        ColorSequenceKeypoint.new(0.5, GuiConfig.Color),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(34, 34, 34))
                    }
                    Grad.Rotation = 25
                    Grad.Parent = Banner
                end

                if BannerConfig.Version then
                    local VerPill = Instance.new("Frame")
                    VerPill.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
                    VerPill.BackgroundTransparency = 0.35
                    VerPill.BorderSizePixel = 0
                    VerPill.AnchorPoint = Vector2.new(1, 0)
                    VerPill.Position = UDim2.new(1, -8, 0, 8)
                    VerPill.Size = UDim2.new(0, 52, 0, 20)
                    VerPill.ZIndex = 3
                    VerPill.Name = "VersionPill"
                    VerPill.Parent = Banner

                    local VerCorner = Instance.new("UICorner")
                    VerCorner.CornerRadius = UDim.new(0, 10)
                    VerCorner.Parent = VerPill

                    local VerLabel = Instance.new("TextLabel")
                    VerLabel.Font = Enum.Font.GothamBold
                    VerLabel.Text = tostring(BannerConfig.Version)
                    VerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    VerLabel.TextSize = 10
                    VerLabel.BackgroundTransparency = 1
                    VerLabel.Size = UDim2.new(1, 0, 1, 0)
                    VerLabel.ZIndex = 4
                    VerLabel.Parent = VerPill
                end

                Banner:GetPropertyChangedSignal("AbsoluteSize"):Connect(FitHeight)
                task.spawn(function()
                    task.wait()
                    FitHeight()
                end)

                CountItem = CountItem + 1
                return Banner
            end

            function Items:AddCardWidget(CardConfig)
                CardConfig = CardConfig or {}
                local asset = tostring(CardConfig.catwidget or CardConfig.CatWidget or CardConfig.Image or CardConfig.Url or "")
                local ratio = CardConfig.AspectRatio or (1000 / 300)

                local Widget = Instance.new("Frame")
                Widget.BackgroundColor3 = Color3.fromRGB(34, 34, 34)
                Widget.BackgroundTransparency = 0.2
                Widget.BorderSizePixel = 0
                Widget.ClipsDescendants = true
                Widget.LayoutOrder = CountItem
                Widget.Size = UDim2.new(1, 0, 0, 110)
                Widget.Name = "CardWidget"
                Widget.Parent = SectionAdd

                local WidgetCorner = Instance.new("UICorner")
                WidgetCorner.CornerRadius = UDim.new(0, 8)
                WidgetCorner.Parent = Widget

                local function FitHeight()
                    local w = Widget.AbsoluteSize.X
                    if w > 0 then
                        local h = math.floor(w / ratio)
                        if math.abs(Widget.Size.Y.Offset - h) > 1 then
                            Widget.Size = UDim2.new(Widget.Size.X.Scale, Widget.Size.X.Offset, 0, h)
                            UpdateSizeSection()
                        end
                    end
                end

                if asset ~= "" then
                    local Img = Instance.new("ImageLabel")
                    Img.BackgroundTransparency = 1
                    Img.ScaleType = Enum.ScaleType.Fit
                    Img.Size = UDim2.new(1, 0, 1, 0)
                    Img.Name = "CardWidgetImage"
                    Img.Image = ""
                    Img.Parent = Widget

                    local LoadingLabel = Instance.new("TextLabel")
                    LoadingLabel.Font = Enum.Font.Gotham
                    LoadingLabel.Text = "Loading..."
                    LoadingLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
                    LoadingLabel.TextSize = 12
                    LoadingLabel.BackgroundTransparency = 1
                    LoadingLabel.Size = UDim2.new(1, 0, 1, 0)
                    LoadingLabel.Name = "CardWidgetLoading"
                    LoadingLabel.Parent = Widget

                    if asset:match("^rbxassetid://") or asset:match("^rbxasset://") or asset:match("^rbxthumb://") or asset:match("^%d+$") then
                        ApplyIcon(Img, asset, 512)
                        LoadingLabel:Destroy()
                    else
                        task.spawn(function()
                            local loaded = GetWebImageAsset(asset)
                            if Img and Img.Parent then
                                if loaded ~= "" then
                                    Img.Image = loaded
                                else
                                    LoadingLabel.Text = "Failed to load image"
                                    LoadingLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
                                    return
                                end
                            end
                            if LoadingLabel and LoadingLabel.Parent then
                                LoadingLabel:Destroy()
                            end
                        end)
                    end

                    if CardConfig.Callback or CardConfig.Link then
                        local Click = Instance.new("TextButton")
                        Click.BackgroundTransparency = 1
                        Click.AutoButtonColor = false
                        Click.Text = ""
                        Click.Size = UDim2.new(1, 0, 1, 0)
                        Click.ZIndex = 5
                        Click.Name = "ClickArea"
                        Click.Parent = Widget

                        Click.MouseButton1Click:Connect(function()
                            if CardConfig.Callback then
                                pcall(CardConfig.Callback)
                            end
                            if CardConfig.Link then
                                if setclipboard then
                                    pcall(setclipboard, CardConfig.Link)
                                    than("Link copied to clipboard", 4, GuiConfig.Color, "OxioHub", "Widget")
                                end
                            end
                        end)
                    end
                else
                    local Grad = Instance.new("UIGradient")
                    Grad.Color = ColorSequence.new {
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 34, 34)),
                        ColorSequenceKeypoint.new(0.5, GuiConfig.Color),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(34, 34, 34))
                    }
                    Grad.Rotation = 25
                    Grad.Parent = Widget
                end

                Widget:GetPropertyChangedSignal("AbsoluteSize"):Connect(FitHeight)
                task.spawn(function()
                    task.wait()
                    FitHeight()
                end)

                RegisterSearch({ label = CardConfig.Title or "Card Widget", tab = TabConfig.Name, kind = "CardWidget", switch = SearchSwitch })
                CountItem = CountItem + 1
                return Widget
            end

            function Items:AddCardsWidget(CardsWidget)
                CardsWidget = CardsWidget or {}
                local created = {}
                for _, entry in ipairs(CardsWidget) do
                    created[#created + 1] = Items:AddCardWidget(entry)
                end
                return created
            end

            function Items:AddCard(CardConfig)
                CardConfig = CardConfig or {}
                CardConfig.Title = CardConfig.Title or "Card"
                CardConfig.Description = CardConfig.Description or ""
                local btns = CardConfig.Buttons or {}
                local cardHeight = 70 + (#btns > 0 and 40 or 0)

                local Card = Instance.new("Frame")
                Card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Card.BackgroundTransparency = 0.935
                Card.BorderSizePixel = 0
                Card.LayoutOrder = CountItem
                Card.Size = UDim2.new(1, 0, 0, cardHeight)
                Card.Name = "Card"
                Card.Parent = SectionAdd

                local CardCorner = Instance.new("UICorner")
                CardCorner.CornerRadius = UDim.new(0, 6)
                CardCorner.Parent = Card

                local cx = 12
                if CardConfig.Logo and CardConfig.Logo ~= "" then
                    local Logo = Instance.new("ImageLabel")
                    Logo.BackgroundTransparency = 1
                    Logo.ScaleType = Enum.ScaleType.Fit
                    Logo.Position = UDim2.new(0, 12, 0, 14)
                    Logo.Size = UDim2.new(0, 32, 0, 32)
                    Logo.Name = "CardLogo"
                    Logo.Parent = Card
                    ApplyIcon(Logo, CardConfig.Logo, 48)
                    cx = 52
                end

                local CardTitle = Instance.new("TextLabel")
                CardTitle.Font = Enum.Font.GothamBold
                CardTitle.Text = CardConfig.Title
                CardTitle.TextColor3 = Color3.fromRGB(235, 235, 235)
                CardTitle.TextSize = 13
                CardTitle.TextXAlignment = Enum.TextXAlignment.Left
                CardTitle.BackgroundTransparency = 1
                CardTitle.Position = UDim2.new(0, cx, 0, 12)
                CardTitle.Size = UDim2.new(1, -cx - 12, 0, 16)
                CardTitle.Parent = Card

                local CardDesc = Instance.new("TextLabel")
                CardDesc.Font = Enum.Font.Gotham
                CardDesc.Text = CardConfig.Description
                CardDesc.TextColor3 = Color3.fromRGB(180, 180, 180)
                CardDesc.TextSize = 11
                CardDesc.TextXAlignment = Enum.TextXAlignment.Left
                CardDesc.TextYAlignment = Enum.TextYAlignment.Top
                CardDesc.TextWrapped = true
                CardDesc.RichText = true
                CardDesc.BackgroundTransparency = 1
                CardDesc.Position = UDim2.new(0, cx, 0, 30)
                CardDesc.Size = UDim2.new(1, -cx - 12, 0, 28)
                CardDesc.Parent = Card

                if #btns > 0 then
                    local Row = Instance.new("Frame")
                    Row.BackgroundTransparency = 1
                    Row.Position = UDim2.new(0, 8, 0, cardHeight - 38)
                    Row.Size = UDim2.new(1, -16, 0, 30)
                    Row.Parent = Card

                    local RowLayout = Instance.new("UIListLayout")
                    RowLayout.FillDirection = Enum.FillDirection.Horizontal
                    RowLayout.Padding = UDim.new(0, 6)
                    RowLayout.Parent = Row

                    local bw = (#btns == 1) and UDim2.new(1, 0, 1, 0) or UDim2.new(0.5, -3, 1, 0)
                    for _, bd in ipairs(btns) do
                        local Btn = Instance.new("TextButton")
                        Btn.Font = Enum.Font.GothamBold
                        Btn.Text = bd.Name or "Button"
                        Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                        Btn.TextSize = 11
                        Btn.TextTransparency = 0.2
                        Btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                        Btn.BackgroundTransparency = 0.9
                        Btn.BorderSizePixel = 0
                        Btn.Size = bw
                        Btn.Parent = Row

                        local BtnCorner = Instance.new("UICorner")
                        BtnCorner.CornerRadius = UDim.new(0, 6)
                        BtnCorner.Parent = Btn

                        if bd.Callback then
                            Btn.MouseButton1Click:Connect(bd.Callback)
                        end
                    end
                end

                RegisterSearch({ label = CardConfig.Title, tab = TabConfig.Name, kind = "Card", switch = SearchSwitch })
                CountItem = CountItem + 1
                return Card
            end

            function Items:AddDivider()
                local Divider = Instance.new("Frame")
                Divider.Name = "Divider"
                Divider.Parent = SectionAdd
                Divider.Size = UDim2.new(1, 0, 0, 2)
                Divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Divider.BackgroundTransparency = 0
                Divider.BorderSizePixel = 0
                Divider.LayoutOrder = CountItem

                local UIGradient = Instance.new("UIGradient")
                UIGradient.Color = ColorSequence.new {
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 34, 34)),
                    ColorSequenceKeypoint.new(0.5, GuiConfig.Color),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(34, 34, 34))
                }
                UIGradient.Parent = Divider

                local UICorner = Instance.new("UICorner")
                UICorner.CornerRadius = UDim.new(0, 2)
                UICorner.Parent = Divider

                CountItem = CountItem + 1
                return Divider
            end

            function Items:AddSubSection(title)
                title = title or "Sub Section"

                local SubSection = Instance.new("Frame")
                SubSection.Name = "SubSection"
                SubSection.Parent = SectionAdd
                SubSection.BackgroundTransparency = 1
                SubSection.Size = UDim2.new(1, 0, 0, 22)
                SubSection.LayoutOrder = CountItem

                local Background = Instance.new("Frame")
                Background.Parent = SubSection
                Background.Size = UDim2.new(1, 0, 1, 0)
                Background.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Background.BackgroundTransparency = 0.935
                Background.BorderSizePixel = 0
                Instance.new("UICorner", Background).CornerRadius = UDim.new(0, 6)

                local Label = Instance.new("TextLabel")
                Label.Parent = SubSection
                Label.AnchorPoint = Vector2.new(0, 0.5)
                Label.Position = UDim2.new(0, 10, 0.5, 0)
                Label.Size = UDim2.new(1, -20, 1, 0)
                Label.BackgroundTransparency = 1
                Label.Font = Enum.Font.GothamBold
                Label.Text = "──> " .. title .. " <──"
                Label.TextColor3 = Color3.fromRGB(230, 230, 230)
                Label.TextSize = 12
                Label.TextXAlignment = Enum.TextXAlignment.Left

                CountItem = CountItem + 1
                return SubSection
            end

            function Items:AddSpace(SpaceConfig)
                SpaceConfig = SpaceConfig or {}
                local Space = Instance.new("Frame")
                Space.Name = "Space"
                Space.BackgroundTransparency = 1
                Space.BorderSizePixel = 0
                Space.LayoutOrder = CountItem
                Space.Size = UDim2.new(0, SpaceConfig.Width or 12, 0, SpaceConfig.Height or 8)
                Space.Parent = SectionAdd

                CountItem = CountItem + 1
                return Space
            end

            function Items:AddHStack(StackConfig)
                StackConfig = StackConfig or {}
                local Padding = StackConfig.Padding or 6
                local FixedHeight = StackConfig.Height
                local Sizing = StackConfig.Sizing or "Equal"
                local HorizontalAlignment = StackConfig.HorizontalAlignment or Enum.HorizontalAlignment.Left
                local VerticalAlignment = StackConfig.VerticalAlignment or Enum.VerticalAlignment.Center

                local Stack = Instance.new("Frame")
                Stack.Name = "HStack"
                Stack.BackgroundTransparency = 1
                Stack.BorderSizePixel = 0
                Stack.LayoutOrder = CountItem
                Stack.Size = UDim2.new(1, 0, 0, FixedHeight or 0)
                Stack.Parent = SectionAdd

                local StackLayout = Instance.new("UIListLayout")
                StackLayout.FillDirection = Enum.FillDirection.Horizontal
                StackLayout.Padding = UDim.new(0, Padding)
                StackLayout.HorizontalAlignment = HorizontalAlignment
                StackLayout.VerticalAlignment = VerticalAlignment
                StackLayout.SortOrder = Enum.SortOrder.LayoutOrder
                StackLayout.Parent = Stack

                if not FixedHeight then
                    local function UpdateStackHeight()
                        Stack.Size = UDim2.new(1, 0, 0, StackLayout.AbsoluteContentSize.Y)
                        UpdateSizeSection()
                    end
                    StackLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateStackHeight)
                end

                local EqualHeight = StackConfig.EqualHeight
                if EqualHeight == nil then EqualHeight = true end
                local heightConnections = {}
                local syncingHeight = false

                local function RecalculateHeights()
                    if not EqualHeight or syncingHeight then return end
                    syncingHeight = true

                    local maxHeight = 0
                    local contentChildren = {}
                    for _, child in ipairs(Stack:GetChildren()) do
                        if child:IsA("GuiObject") and child.Name ~= "Space" then
                            table.insert(contentChildren, child)
                            if child.Size.Y.Offset > maxHeight then
                                maxHeight = child.Size.Y.Offset
                            end
                        end
                    end

                    for _, child in ipairs(contentChildren) do
                        if child.Size.Y.Offset ~= maxHeight then
                            child.Size = UDim2.new(child.Size.X.Scale, child.Size.X.Offset, 0, maxHeight)
                        end
                    end

                    syncingHeight = false
                end
                local heightsPending = false
                local function ScheduleRecalculateHeights()
                    if heightsPending then return end
                    heightsPending = true
                    task.defer(function()
                        heightsPending = false
                        RecalculateHeights()
                    end)
                end

                if Sizing == "Equal" then
                    local function RecalculateWidths()
                        local contentChildren, allChildrenCount, spaceOffsetTotal = {}, 0, 0
                        for _, child in ipairs(Stack:GetChildren()) do
                            if child:IsA("GuiObject") then
                                allChildrenCount = allChildrenCount + 1
                                if child.Name == "Space" then
                                    spaceOffsetTotal = spaceOffsetTotal + child.Size.X.Offset
                                else
                                    table.insert(contentChildren, child)
                                end
                            end
                        end
                        local count = #contentChildren
                        if count == 0 then return end
                        local totalPadding = Padding * math.max(allChildrenCount - 1, 0)
                        local extraOffset = -(totalPadding + spaceOffsetTotal)
                        for _, child in ipairs(contentChildren) do
                            child.Size = UDim2.new(1 / count, extraOffset / count, child.Size.Y.Scale,
                                child.Size.Y.Offset)
                        end
                    end
                    local widthsPending = false
                    local function ScheduleRecalculateWidths()
                        if widthsPending then return end
                        widthsPending = true
                        task.defer(function()
                            widthsPending = false
                            RecalculateWidths()
                        end)
                    end
                    Stack.ChildAdded:Connect(function(child)
                        if child:IsA("GuiObject") then
                            ScheduleRecalculateWidths()
                        end
                    end)
                    Stack.ChildRemoved:Connect(function(child)
                        if child:IsA("GuiObject") then
                            ScheduleRecalculateWidths()
                        end
                    end)
                end

                Stack.ChildAdded:Connect(function(child)
                    if child:IsA("GuiObject") then
                        heightConnections[child] = child:GetPropertyChangedSignal("Size"):Connect(function()
                            ScheduleRecalculateHeights()
                        end)
                        ScheduleRecalculateHeights()
                    end
                end)
                Stack.ChildRemoved:Connect(function(child)
                    if heightConnections[child] then
                        heightConnections[child]:Disconnect()
                        heightConnections[child] = nil
                    end
                    ScheduleRecalculateHeights()
                end)

                CountItem = CountItem + 1
                return BuildItemsAPI(Stack)
            end

            function Items:AddVStack(StackConfig)
                StackConfig = StackConfig or {}
                local Padding = StackConfig.Padding or 3
                local HorizontalAlignment = StackConfig.HorizontalAlignment or Enum.HorizontalAlignment.Left
                local VerticalAlignment = StackConfig.VerticalAlignment or Enum.VerticalAlignment.Top

                local Stack = Instance.new("Frame")
                Stack.Name = "VStack"
                Stack.BackgroundTransparency = 1
                Stack.BorderSizePixel = 0
                Stack.LayoutOrder = CountItem
                Stack.Size = UDim2.new(1, 0, 0, 0)
                Stack.Parent = SectionAdd

                local StackLayout = Instance.new("UIListLayout")
                StackLayout.FillDirection = Enum.FillDirection.Vertical
                StackLayout.Padding = UDim.new(0, Padding)
                StackLayout.HorizontalAlignment = HorizontalAlignment
                StackLayout.VerticalAlignment = VerticalAlignment
                StackLayout.SortOrder = Enum.SortOrder.LayoutOrder
                StackLayout.Parent = Stack

                local function UpdateStackHeight()
                    Stack.Size = UDim2.new(1, 0, 0, StackLayout.AbsoluteContentSize.Y)
                    UpdateSizeSection()
                end
                StackLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateStackHeight)

                CountItem = CountItem + 1
                return BuildItemsAPI(Stack)
            end

            function Items:AddPresetManager(PresetConfig)
                local PresetConfig = PresetConfig or {}
                PresetConfig.Title = PresetConfig.Title or "Preset Manager"
                PresetConfig.Content = PresetConfig.Content or "Save and load values"
                PresetConfig.Placeholder = PresetConfig.Placeholder or "Enter value..."
                PresetConfig.Default = PresetConfig.Default or ""
                PresetConfig.Callback = PresetConfig.Callback or function() end
                
                local configKey = "PresetManager_" .. PresetConfig.Title
                local shouldSave = PresetConfig.Save ~= false

                -- [FIX] Sistem Save & Load JSON Independen untuk Preset
                local presetFilePath = "OxioHub/Config/Presets_" .. gameName .. ".json"
                local presetFileData = { Presets = {}, Value = "", SelectedPreset = "" }

                local function LoadPresetFile()
                    if not isfile then return end
                    if isfile(presetFilePath) then
                        local ok, data = pcall(function()
                            return HttpService:JSONDecode(readfile(presetFilePath))
                        end)
                        if ok and type(data) == "table" then
                            presetFileData.Presets = type(data.Presets) == "table" and data.Presets or {}
                            presetFileData.Value = tostring(data.Value or "")
                            presetFileData.SelectedPreset = tostring(data.SelectedPreset or "")
                        end
                    end
                end

                -- Load data dari file JSON sebelum UI dibuat
                LoadPresetFile()

                -- Ambil preset bawaan dari script
                local presets = PresetConfig.Presets or {}
                -- Gabungkan dengan preset dari file JSON
                for k, v in pairs(presetFileData.Presets) do
                    presets[k] = v
                end

                local savedValue = presetFileData.Value ~= "" and presetFileData.Value or PresetConfig.Default
                local savedSelectedPreset = presetFileData.SelectedPreset

                -- Deklarasi variabel kosong terlebih dahulu agar bisa diakses oleh function di bawahnya
                local PresetFunc = { Value = savedValue, Presets = presets }
                local currentPresetName = savedSelectedPreset

                local function SavePresetFile()
                    if not writefile then return end
                    -- PresetFunc sudah dideklarasikan di atas, jadi tidak akan nil
                    presetFileData.Value = PresetFunc.Value or ""
                    presetFileData.SelectedPreset = currentPresetName or ""
                    presetFileData.Presets = PresetFunc.Presets or {}
                    
                    local ok, encoded = pcall(function()
                        return HttpService:JSONEncode(presetFileData)
                    end)
                    if ok then
                        writefile(presetFilePath, encoded)
                    end
                end

                -- Forward declarations untuk UI
                local PresetDropdown
                local RefreshDropdown

                -- [UI] Main Card Container
                local Card = Instance.new("Frame")
                Card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Card.BackgroundTransparency = 0.935
                Card.BorderSizePixel = 0
                Card.LayoutOrder = CountItem
                Card.Size = UDim2.new(1, 0, 0, 0)
                Card.Name = "PresetManagerCard"
                Card.Parent = SectionAdd
                
                local CardCorner = Instance.new("UICorner")
                CardCorner.CornerRadius = UDim.new(0, 6)
                CardCorner.Parent = Card
                
                local CardLayout = Instance.new("UIListLayout")
                CardLayout.Padding = UDim.new(0, 8)
                CardLayout.SortOrder = Enum.SortOrder.LayoutOrder
                CardLayout.Parent = Card
                
                local CardPadding = Instance.new("UIPadding")
                CardPadding.PaddingTop = UDim.new(0, 12)
                CardPadding.PaddingBottom = UDim.new(0, 12)
                CardPadding.PaddingLeft = UDim.new(0, 12)
                CardPadding.PaddingRight = UDim.new(0, 12)
                CardPadding.Parent = Card
                
                local sizeQueued = false
                local function UpdateCardSize()
                    if sizeQueued then return end
                    sizeQueued = true
                    task.defer(function()
                        sizeQueued = false
                        Card.Size = UDim2.new(1, 0, 0, CardLayout.AbsoluteContentSize.Y + 24)
                        UpdateSizeSection()
                    end)
                end
                CardLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCardSize)

                local TitleLabel = Instance.new("TextLabel")
                TitleLabel.Font = Enum.Font.GothamBold
                TitleLabel.Text = PresetConfig.Title
                TitleLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
                TitleLabel.TextSize = 13
                TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
                TitleLabel.BackgroundTransparency = 1
                TitleLabel.Size = UDim2.new(1, 0, 0, 16)
                TitleLabel.Parent = Card

                local function CreateModernInput(placeholder)
                    local InputFrame = Instance.new("Frame")
                    InputFrame.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
                    InputFrame.BackgroundTransparency = 0.2
                    InputFrame.BorderSizePixel = 0
                    InputFrame.Size = UDim2.new(1, 0, 0, 34)
                    InputFrame.Parent = Card

                    local Corner = Instance.new("UICorner")
                    Corner.CornerRadius = UDim.new(0, 6)
                    Corner.Parent = InputFrame

                    local Stroke = Instance.new("UIStroke")
                    Stroke.Color = Color3.fromRGB(72, 72, 72)
                    Stroke.Transparency = 0.5
                    Stroke.Parent = InputFrame

                    local Box = Instance.new("TextBox")
                    Box.Font = Enum.Font.GothamBold
                    Box.PlaceholderText = placeholder
                    Box.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
                    Box.Text = ""
                    Box.TextColor3 = Color3.fromRGB(255, 255, 255)
                    Box.TextSize = 12
                    Box.ClearTextOnFocus = false
                    Box.TextXAlignment = Enum.TextXAlignment.Left
                    Box.BackgroundTransparency = 1
                    Box.Position = UDim2.new(0, 10, 0, 0)
                    Box.Size = UDim2.new(1, -20, 1, 0)
                    Box.Parent = InputFrame
                    return Box
                end

                local ValueBox = CreateModernInput(PresetConfig.Placeholder)
                ValueBox.Text = savedValue
                PresetFunc.Value = savedValue

                ValueBox.FocusLost:Connect(function()
                    PresetFunc.Value = ValueBox.Text
                    PresetConfig.Callback(ValueBox.Text)
                    SavePresetFile()
                end)

                function PresetFunc:Set(value, noSave)
                    if type(value) == "table" then
                        -- Abaikan table dari sistem config lama, kita pakai JSON sendiri
                        return
                    end

                    ValueBox.Text = tostring(value or "")
                    PresetFunc.Value = ValueBox.Text
                    PresetConfig.Callback(PresetFunc.Value)
                    if not noSave then
                        SavePresetFile()
                    end
                end

                PresetDropdown = Items:AddDropdown({
                    Title = "Saved Presets",
                    Content = "Pilih preset untuk dimuat",
                    Options = {},
                    Default = nil,
                    Save = false,
                    Callback = function(selectedName)
                        currentPresetName = selectedName
                        if selectedName and selectedName ~= "" then
                            if PresetFunc.Presets[selectedName] then
                                ValueBox.Text = tostring(PresetFunc.Presets[selectedName])
                                PresetFunc.Value = ValueBox.Text
                                PresetConfig.Callback(PresetFunc.Value)
                                SavePresetFile()
                            end
                        end
                    end
                })

                local DropUI
                for _, child in ipairs(SectionAdd:GetChildren()) do
                    if child.Name == "Dropdown" then
                        local title = child:FindFirstChild("DropdownTitle")
                        if title and title.Text == "Saved Presets" then
                            DropUI = child
                            break
                        end
                    end
                end

                if DropUI then
                    DropUI.Parent = Card
                    DropUI.LayoutOrder = 2
                    DropUI.BackgroundTransparency = 1
                    DropUI.Size = UDim2.new(1, 0, 0, 34)
                    
                    local SelectFrame = DropUI:FindFirstChild("SelectOptionsFrame")
                    if SelectFrame then
                        SelectFrame.AnchorPoint = Vector2.new(0, 0)
                        SelectFrame.Position = UDim2.new(0, 0, 0, 0)
                        SelectFrame.Size = UDim2.new(1, 0, 1, 0)
                        SelectFrame.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
                        SelectFrame.BackgroundTransparency = 0.2
                        
                        Instance.new("UICorner", SelectFrame).CornerRadius = UDim.new(0, 6)
                        local SStroke = Instance.new("UIStroke", SelectFrame)
                        SStroke.Color = Color3.fromRGB(72, 72, 72)
                        SStroke.Transparency = 0.5
                        
                        local OptText = SelectFrame:FindFirstChild("OptionSelecting")
                        if OptText then
                            OptText.AnchorPoint = Vector2.new(0, 0.5)
                            OptText.Position = UDim2.new(0, 10, 0.5, 0)
                            OptText.Size = UDim2.new(1, -40, 1, -8)
                            OptText.Font = Enum.Font.GothamBold
                            OptText.TextSize = 12
                            OptText.TextColor3 = Color3.fromRGB(200, 200, 200)
                            OptText.TextXAlignment = Enum.TextXAlignment.Left
                        end
                        
                        local OptImg = SelectFrame:FindFirstChild("OptionImg")
                        if OptImg then
                            OptImg.AnchorPoint = Vector2.new(1, 0.5)
                            OptImg.Position = UDim2.new(1, -10, 0.5, 0)
                            OptImg.Size = UDim2.new(0, 16, 0, 16)
                        end
                    end
                    
                    local DTitle = DropUI:FindFirstChild("DropdownTitle")
                    local DContent = DropUI:FindFirstChild("DropdownContent")
                    if DTitle then DTitle.Visible = false end
                    if DContent then DContent.Visible = false end
                end

                RefreshDropdown = function()
                    local names = {}
                    for name, _ in pairs(PresetFunc.Presets) do
                        table.insert(names, name)
                    end
                    table.sort(names)
                    if PresetDropdown and PresetDropdown.SetValues then
                        PresetDropdown:SetValues(names, currentPresetName ~= "" and currentPresetName or nil, true)
                    end
                end
                RefreshDropdown()

                local OptHeader = Instance.new("TextButton")
                OptHeader.BackgroundTransparency = 1
                OptHeader.Size = UDim2.new(1, 0, 0, 24)
                OptHeader.Text = ""
                OptHeader.LayoutOrder = 3
                OptHeader.Parent = Card
                
                local OptTitle = Instance.new("TextLabel")
                OptTitle.Font = Enum.Font.GothamBold
                OptTitle.Text = "Pengaturan Preset (Save / Delete)"
                OptTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
                OptTitle.TextSize = 12
                OptTitle.TextXAlignment = Enum.TextXAlignment.Left
                OptTitle.BackgroundTransparency = 1
                OptTitle.AnchorPoint = Vector2.new(0, 0.5)
                OptTitle.Position = UDim2.new(0, 4, 0.5, 0)
                OptTitle.Size = UDim2.new(1, -20, 0, 14)
                OptTitle.Parent = OptHeader
                
                local OptArrow = Instance.new("ImageLabel")
                OptArrow.Image = "rbxassetid://16851841101"
                OptArrow.Rotation = -90
                OptArrow.AnchorPoint = Vector2.new(1, 0.5)
                OptArrow.Position = UDim2.new(1, -4, 0.5, 0)
                OptArrow.Size = UDim2.new(0, 16, 0, 16)
                OptArrow.BackgroundTransparency = 1
                OptArrow.Parent = OptHeader
                
                local OptContainer = Instance.new("Frame")
                OptContainer.BackgroundTransparency = 1
                OptContainer.Size = UDim2.new(1, 0, 0, 0)
                OptContainer.ClipsDescendants = true
                OptContainer.LayoutOrder = 4
                OptContainer.Parent = Card
                
                local OptLayout = Instance.new("UIListLayout")
                OptLayout.Padding = UDim.new(0, 8)
                OptLayout.SortOrder = Enum.SortOrder.LayoutOrder
                OptLayout.Parent = OptContainer
                
                local isOptOpen = false
                OptHeader.MouseButton1Click:Connect(function()
                    CircleClick(OptHeader, Mouse.X, Mouse.Y)
                    isOptOpen = not isOptOpen
                    if isOptOpen then
                        OptArrow.Rotation = 0
                        TweenService:Create(OptContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 0, OptLayout.AbsoluteContentSize.Y) }):Play()
                    else
                        OptArrow.Rotation = -90
                        TweenService:Create(OptContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 0, 0) }):Play()
                    end
                    task.delay(0.35, UpdateCardSize)
                end)
                
                local NameBoxFrame = Instance.new("Frame")
                NameBoxFrame.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
                NameBoxFrame.BackgroundTransparency = 0.2
                NameBoxFrame.BorderSizePixel = 0
                NameBoxFrame.Size = UDim2.new(1, 0, 0, 34)
                NameBoxFrame.Parent = OptContainer
                
                Instance.new("UICorner", NameBoxFrame).CornerRadius = UDim.new(0, 6)
                local NStroke = Instance.new("UIStroke", NameBoxFrame)
                NStroke.Color = Color3.fromRGB(72, 72, 72)
                NStroke.Transparency = 0.5
                
                local NameBox = Instance.new("TextBox")
                NameBox.Font = Enum.Font.GothamBold
                NameBox.PlaceholderText = "Preset Name (e.g. Avatar 1)"
                NameBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
                NameBox.Text = savedSelectedPreset
                NameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
                NameBox.TextSize = 12
                NameBox.ClearTextOnFocus = false
                NameBox.TextXAlignment = Enum.TextXAlignment.Left
                NameBox.BackgroundTransparency = 1
                NameBox.Position = UDim2.new(0, 10, 0, 0)
                NameBox.Size = UDim2.new(1, -20, 1, 0)
                NameBox.Parent = NameBoxFrame
                NameBox.FocusLost:Connect(function() currentPresetName = NameBox.Text end)
                
                local BtnRow = Instance.new("Frame")
                BtnRow.BackgroundTransparency = 1
                BtnRow.Size = UDim2.new(1, 0, 0, 34)
                BtnRow.Parent = OptContainer
                
                local BtnLayout = Instance.new("UIListLayout")
                BtnLayout.FillDirection = Enum.FillDirection.Horizontal
                BtnLayout.Padding = UDim.new(0, 8)
                BtnLayout.SortOrder = Enum.SortOrder.LayoutOrder
                BtnLayout.Parent = BtnRow
                
                local function CreateBtn(text, bgColor, callback)
                    local Btn = Instance.new("TextButton")
                    Btn.Font = Enum.Font.GothamBold
                    Btn.Text = text
                    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                    Btn.TextSize = 12
                    Btn.TextTransparency = 0.1
                    Btn.BackgroundColor3 = bgColor
                    Btn.Size = UDim2.new(0.5, -4, 1, 0)
                    Btn.AutoButtonColor = false
                    Btn.Parent = BtnRow
                    
                    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)
                    local BtnStroke = Instance.new("UIStroke", Btn)
                    BtnStroke.Color = Color3.fromRGB(72, 72, 72)
                    BtnStroke.Transparency = 0.5
                    
                    Btn.MouseEnter:Connect(function()
                        TweenService:Create(Btn, TweenInfo.new(0.15), { BackgroundColor3 = bgColor:lerp(Color3.fromRGB(255, 255, 255), 0.1) }):Play()
                    end)
                    Btn.MouseLeave:Connect(function()
                        TweenService:Create(Btn, TweenInfo.new(0.15), { BackgroundColor3 = bgColor }):Play()
                    end)
                    
                    Btn.Activated:Connect(function()
                        CircleClick(Btn, Mouse.X, Mouse.Y)
                        callback()
                    end)
                end
                
                CreateBtn("Save", Color3.fromRGB(40, 40, 40), function()
                    if currentPresetName == "" or not currentPresetName then
                        than("Masukkan nama preset terlebih dahulu!", 3, Color3.fromRGB(255, 170, 0), "OxioHub", "Preset")
                        return
                    end
                    PresetFunc.Presets[currentPresetName] = PresetFunc.Value
                    SavePresetFile()
                    RefreshDropdown()
                    PresetDropdown:Set(currentPresetName)
                    than("Preset '" .. currentPresetName .. "' disimpan!", 3, GuiConfig.Color, "OxioHub", "Preset")
                end)
                
                CreateBtn("Delete", Color3.fromRGB(60, 25, 25), function()
                    if currentPresetName == "" or not currentPresetName then return end
                    if PresetFunc.Presets[currentPresetName] then
                        PresetFunc.Presets[currentPresetName] = nil
                        SavePresetFile()
                        currentPresetName = ""
                        NameBox.Text = ""
                        RefreshDropdown()
                        than("Preset berhasil dihapus.", 3, Color3.fromRGB(255, 170, 0), "OxioHub", "Preset")
                    else
                        than("Preset tidak ditemukan.", 3, Color3.fromRGB(255, 90, 90), "OxioHub", "Preset")
                    end
                end)

                -- Dummy config element agar tidak mengganggu config bawaan
                if shouldSave then
                    Elements[configKey] = { Set = function() end }
                end

                UpdateCardSize()
                CountItem = CountItem + 1
                RegisterSearch({ label = PresetConfig.Title, tab = TabConfig.Name, kind = "PresetManager", element = PresetFunc, switch = SearchSwitch })
                return PresetFunc
            end

            return Items
            end

            local Items = BuildItemsAPI(SectionAdd)

            CountSection = CountSection + 1
            return Items
        end

        CountTab = CountTab + 1
        local safeName = TabConfig.Name:gsub("%s+", "_")
        _G[safeName] = Sections
        return Sections
    end

    function Tabs:InfoTab(InfoConfig)
    InfoConfig = InfoConfig or {}
    local Sections = Tabs:AddTab({
        Name = InfoConfig.Name or "Info",
        Icon = InfoConfig.Icon or "lightbulb",
    })
    local Items = Sections:AddSection(InfoConfig.SectionTitle or "Information", true)

    if InfoConfig.Banner and InfoConfig.Banner ~= "" then
        Items:AddBanner({
            Image = InfoConfig.Banner,
            Version = InfoConfig.Version,
            AspectRatio = InfoConfig.BannerAspectRatio,
        })
    end

    if InfoConfig.DiscordLink then
        local fullDescription = InfoConfig.DiscordText or "Support, updates and announcements."
        if InfoConfig.DiscordDesc and InfoConfig.DiscordDesc ~= "" then
            fullDescription = fullDescription .. "\n" .. InfoConfig.DiscordDesc
        end
        
        Items:AddCard({
            Title = InfoConfig.DiscordName or "Community",
            Description = fullDescription,
            Logo = discord_logo_asset_id,
            Buttons = {
                {
                    Name = "Copy Invite",
                    Callback = function()
                        if setclipboard then
                            setclipboard(InfoConfig.DiscordLink)
                            than("Discord invite copied", 4, GuiConfig.Color, "OxioHub", "Community")
                        end
                    end,
                },
            },
        })
    end

    for _, card in ipairs(InfoConfig.Cards or {}) do
        Items:AddCard(card)
    end

    for _, widget in ipairs(InfoConfig.CardsWidget or {}) do
        Items:AddCardWidget(widget)
    end

    return Sections, Items
  end

    GuiFunc.InfoTab = function(_, cfg) return Tabs:InfoTab(cfg) end
    Tabs.Window = GuiFunc
    Tabs.ExportConfig = function() return GuiFunc:ExportConfig() end
    Tabs.ImportConfig = function(_, str) return GuiFunc:ImportConfig(str) end

    if GuiConfig.Search then
        UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
                or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
                or UserInputService:IsKeyDown(Enum.KeyCode.LeftMeta)
                or UserInputService:IsKeyDown(Enum.KeyCode.RightMeta)
            local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
                or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
            if ctrl and shift and input.KeyCode == Enum.KeyCode.F then
                if DropShadowHolder then DropShadowHolder.Visible = true end
                if GuiFunc.FocusSearch then GuiFunc.FocusSearch() end
            elseif ctrl and input.KeyCode == Enum.KeyCode.O then
                if DropShadowHolder then DropShadowHolder.Visible = true end
                if GuiFunc.FocusSearch then GuiFunc.FocusSearch() end
            end
        end)
    end

    task.spawn(function()
        task.wait(0.5)
        local autoName = GuiFunc:GetAutoLoad()
        if autoName and autoName ~= "" then
            GuiFunc:LoadConfigByName(autoName)
        end
    end)

    return Tabs
end

return Chloex
