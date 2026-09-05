-- // Oxio UI Library (Core Engine) - Optimized for Zero Lag Loops

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")

local Library = {
    WhitelistedUsers = {} 
}

-- // Utility: File System Mock Overrides
local _isfolder = isfolder or function() return true end
local _makefolder = makefolder or function() end
local _writefile = writefile or function(path, data) warn("File saving not supported on this executor.") end
local _readfile = readfile or function() return "{}" end
local _listfiles = listfiles or function() return {} end
local _delfile = delfile or function() warn("File deletion not supported.") end

-- // Utility: Safe Clipboard Copy
local function SafeCopyToClipboard(text)
    if setclipboard then
        setclipboard(text)
    elseif toclipboard then
        toclipboard(text)
    else
        warn("Clipboard copying is not supported on your current executor.")
    end
end

-- // Utility: Instance Creator
local function Create(className, properties)
    local instance = Instance.new(className)
    
    if className == "TextBox" then
        instance.Text = ""
    end

    for k, v in pairs(properties or {}) do
        instance[k] = v
    end
    
    if (className == "TextLabel" or className == "TextButton" or className == "TextBox") then
        if properties.TextSize and properties.RichText ~= true then
            instance.TextScaled = true
            local constraint = Instance.new("UITextSizeConstraint")
            constraint.MaxTextSize = properties.TextSize
            constraint.MinTextSize = 6
            constraint.Parent = instance
        end
    end
    
    return instance
end

-- // Utility: Build search index for a card (cached)
local function BuildSearchIndex(card)
    local parts = {}
    for _, desc in ipairs(card:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox") then
            if desc.Text and desc.Text ~= "" then
                table.insert(parts, desc.Text:lower())
            end
        end
    end
    return table.concat(parts, " ")
end

-- // Utility: Smooth Tweening
local function Tween(instance, properties, duration)
    duration = duration or 0.25
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local tween = TweenService:Create(instance, tweenInfo, properties)
    tween:Play()
    return tween
end

-- // Utility: Micro-Interaction Bounce
local function AddBounce(button, scaleFactor)
    scaleFactor = scaleFactor or 0.96
    local scaleObj = button:FindFirstChild("UIScale") or Create("UIScale", {Parent = button, Scale = 1})
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            Tween(scaleObj, {Scale = scaleFactor}, 0.15)
        end
    end)
    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            Tween(scaleObj, {Scale = 1}, 0.15)
        end
    end)
    button.MouseLeave:Connect(function()
        Tween(scaleObj, {Scale = 1}, 0.15)
    end)
end

-- // Utility: Draggable
local function MakeDraggable(topbar, object)
    topbar.Active = true
    object.Active = true
    local dragging, dragInput, dragStart, startPos
    
    topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = object.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    topbar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            Tween(object, {Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)}, 0.08)
        end
    end)
end

-- // Utility: Obsidian-style Resizable Window
local function MakeResizable(UI, DragFrame, Callback)
    local dragging = false
    local dragStart
    local startSize
    local endedConnection

    DragFrame.Active = true

    DragFrame.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        dragStart = input.Position
        startSize = UI.Size
        dragging = true

        if endedConnection then
            endedConnection:Disconnect()
            endedConnection = nil
        end

        endedConnection = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false

                if endedConnection then
                    endedConnection:Disconnect()
                    endedConnection = nil
                end
            end
        end)
    end)

    local inputChangedConnection
    inputChangedConnection = UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end

        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        if not UI.Visible or not UI.Parent then
            dragging = false
            return
        end

        local uiScale = UI:FindFirstChildOfClass("UIScale")
        local scale = uiScale and math.max(uiScale.Scale, 0.01) or 1
        local delta = input.Position - dragStart

        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)

        local minWidth = 430
        local minHeight = 300
        local maxWidth = math.max(minWidth, (viewport.X - 30) / scale)
        local maxHeight = math.max(minHeight, (viewport.Y - 40) / scale)

        local newWidth = math.clamp(
            startSize.X.Offset + (delta.X / scale),
            minWidth,
            maxWidth
        )

        local newHeight = math.clamp(
            startSize.Y.Offset + (delta.Y / scale),
            minHeight,
            maxHeight
        )

        UI.Size = UDim2.fromOffset(newWidth, newHeight)

        if Callback then
            Callback(newWidth, newHeight)
        end
    end)

    UI.Destroying:Connect(function()
        dragging = false

        if inputChangedConnection then
            inputChangedConnection:Disconnect()
            inputChangedConnection = nil
        end

        if endedConnection then
            endedConnection:Disconnect()
            endedConnection = nil
        end
    end)
end

local AccentColor = Color3.fromRGB(190, 140, 255)
local BackgroundColor = Color3.fromRGB(18, 18, 20)
local CardColor = Color3.fromRGB(24, 24, 27)
local HoverColor = Color3.fromRGB(35, 35, 40)
local TextColor = Color3.fromRGB(240, 240, 240)
local SubTextColor = Color3.fromRGB(150, 150, 150)

-- // Global Notification API
local GlobalNotifContainer

function Library:Notify(options)
    if not GlobalNotifContainer then return end
    local title = options.Title or "Notification"
    local desc = options.Description or "Information updated."
    local duration = options.Duration or 3

    local Notif = Create("Frame", {Parent = GlobalNotifContainer, BackgroundColor3 = Color3.fromRGB(20, 20, 22), Size = UDim2.new(1, 0, 0, 65), BackgroundTransparency = 1, ZIndex = 201, ClipsDescendants = true})
    Create("UICorner", {Parent = Notif, CornerRadius = UDim.new(0, 8)})
    local Stroke = Create("UIStroke", {Parent = Notif, Color = AccentColor, Thickness = 1.5, Transparency = 1})

    local TitleText = Create("TextLabel", {Parent = Notif, Text = title, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = TextColor, BackgroundTransparency = 1, Position = UDim2.new(0, 15, 0, 15), Size = UDim2.new(1, -30, 0, 15), TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, ZIndex = 202})
    local DescText = Create("TextLabel", {Parent = Notif, Text = desc, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = SubTextColor, BackgroundTransparency = 1, Position = UDim2.new(0, 15, 0, 32), Size = UDim2.new(1, -30, 0, 15), TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, ZIndex = 202})

    Tween(Notif, {BackgroundTransparency = 0}, 0.3)
    Tween(Stroke, {Transparency = 0}, 0.3)
    Tween(TitleText, {TextTransparency = 0}, 0.3)
    Tween(DescText, {TextTransparency = 0}, 0.3)

    task.delay(duration, function()
        Tween(Notif, {BackgroundTransparency = 1}, 0.4)
        Tween(Stroke, {Transparency = 1}, 0.4)
        Tween(TitleText, {TextTransparency = 1}, 0.4)
        Tween(DescText, {TextTransparency = 1}, 0.4)
        task.wait(0.4)
        Notif:Destroy()
    end)
end

function Library:CreateWindow(options)
    local hubName = "Oxio Ui Lib"
    local subText = "Made By Hypol-X"
    local subColor = AccentColor
    local sphTextToggle = false
    local sphWords = "OX"
    local sphImage = nil
    local topbarLogo = nil
    local logoSize = 32
    local sphIconSize = 26

    if type(options) == "table" then
        hubName = options.Title or hubName
        subText = options.Subtitle or subText
        subColor = options.SubtitleColor or subColor
        
        if options.SphereText ~= nil then
            sphTextToggle = options.SphereText
        end
        if options.SphereWords ~= nil then
            -- Enforce 2-word limit logic
            local wordList = string.split(tostring(options.SphereWords), " ")
            if #wordList > 2 then
                sphWords = wordList[1] .. " " .. wordList[2]
            else
                sphWords = tostring(options.SphereWords)
            end
        end
        
        sphImage = options.SphereImage
        topbarLogo = options.Logo
        logoSize = options.LogoSize or 32
        sphIconSize = options.SphereIconSize or 26
    elseif type(options) == "string" then
        hubName = options
    end

    local uniqueID = HttpService:GenerateGUID(false)
    local ScreenGui = Create("ScreenGui", {
        Name = "Oxio_UI_" .. uniqueID,
        Parent = RunService:IsStudio() and game.Players.LocalPlayer:WaitForChild("PlayerGui") or CoreGui,
        ResetOnSpawn = false,
        IgnoreGuiInset = true
    })

    local NotifContainer = Create("Frame", {
        Parent = ScreenGui,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 320, 1, -20),
        Position = UDim2.new(1, -340, 0, 10),
        ZIndex = 200,
        Active = false
    })
    Create("UIListLayout", {Parent = NotifContainer, VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12)})
    GlobalNotifContainer = NotifContainer

    local function SendPremiumNotification()
        local Notif = Create("Frame", {Parent = NotifContainer, BackgroundColor3 = Color3.fromRGB(20, 20, 22), Size = UDim2.new(1, 0, 0, 65), BackgroundTransparency = 1, ZIndex = 201, ClipsDescendants = true})
        Create("UICorner", {Parent = Notif, CornerRadius = UDim.new(0, 8)})
        
        local Stroke = Create("UIStroke", {Parent = Notif, Thickness = 1.5, Transparency = 1})
        local StrokeGrad = Create("UIGradient", {Parent = Stroke, Color = ColorSequence.new(Color3.fromRGB(255, 215, 0), Color3.fromRGB(180, 130, 20)), Rotation = 45})

        local LockIcon = Create("ImageLabel", {Parent = Notif, BackgroundTransparency = 1, Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(0, 15, 0.5, -12), Image = "rbxassetid://6031082533", ImageColor3 = Color3.fromRGB(255, 215, 0), ImageTransparency = 1, ZIndex = 202})
        local TitleText = Create("TextLabel", {Parent = Notif, Text = "ACCESS DENIED", Font = Enum.Font.GothamBlack, TextSize = 12, TextColor3 = SubTextColor, BackgroundTransparency = 1, Position = UDim2.new(0, 50, 0, 15), Size = UDim2.new(1, -60, 0, 15), TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, ZIndex = 202})
        local DescText = Create("TextLabel", {Parent = Notif, Text = 'This Is For <font color="#FFD700"><b>Whitelisted Users</b></font>', RichText = true, Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = TextColor, BackgroundTransparency = 1, Position = UDim2.new(0, 50, 0, 32), Size = UDim2.new(1, -60, 0, 15), TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, ZIndex = 202})
        
        local Shine = Create("Frame", {Parent = Notif, BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.8, BorderSizePixel = 0, Size = UDim2.new(0, 20, 2, 0), Position = UDim2.new(-0.2, 0, -0.5, 0), Rotation = 25, ZIndex = 203})

        Tween(Notif, {BackgroundTransparency = 0}, 0.3)
        Tween(Stroke, {Transparency = 0}, 0.3)
        Tween(LockIcon, {ImageTransparency = 0}, 0.3)
        Tween(TitleText, {TextTransparency = 0}, 0.3)
        Tween(DescText, {TextTransparency = 0}, 0.3)

        local shineTween = TweenService:Create(Shine, TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Position = UDim2.new(1.2, 0, -0.5, 0)})
        task.delay(0.2, function() shineTween:Play() end)

        task.delay(4, function()
            Tween(Notif, {BackgroundTransparency = 1}, 0.4)
            Tween(Stroke, {Transparency = 1}, 0.4)
            Tween(LockIcon, {ImageTransparency = 1}, 0.4)
            Tween(TitleText, {TextTransparency = 1}, 0.4)
            Tween(DescText, {TextTransparency = 1}, 0.4)
            task.wait(0.4)
            Notif:Destroy()
        end)
    end

    local InfoOverlay = Create("Frame", {Parent = ScreenGui, BackgroundColor3 = Color3.fromRGB(5, 5, 8), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ZIndex = 150, Visible = false, Active = true})
    local InfoCard = Create("Frame", {Parent = InfoOverlay, BackgroundColor3 = Color3.fromRGB(16, 16, 20), Size = UDim2.new(0, 360, 0, 280), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 151, BackgroundTransparency = 1, ClipsDescendants = true})
    Create("UICorner", {Parent = InfoCard, CornerRadius = UDim.new(0, 8)})
    Create("UIStroke", {Parent = InfoCard, Color = AccentColor, Thickness = 1.5, Transparency = 1})
    local InfoScale = Create("UIScale", {Parent = InfoCard, Scale = 0})

    local InfoHeader = Create("Frame", {Parent = InfoCard, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), ZIndex = 152})
    local InfoTitle = Create("TextLabel", {Parent = InfoHeader, Text = "Feature Info", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = TextColor, BackgroundTransparency = 1, Position = UDim2.new(0, 20, 0, 0), Size = UDim2.new(1, -60, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, ZIndex = 152})
    local InfoCloseBtn = Create("TextButton", {Parent = InfoHeader, Text = "X", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = SubTextColor, BackgroundTransparency = 1, Size = UDim2.new(0, 40, 1, 0), Position = UDim2.new(1, -40, 0, 0), ZIndex = 152, TextTransparency = 1})
    AddBounce(InfoCloseBtn)

    local InfoScroll = Create("ScrollingFrame", {Parent = InfoCard, BackgroundTransparency = 1, Size = UDim2.new(1, -40, 1, -60), Position = UDim2.new(0, 20, 0, 50), CanvasSize = UDim2.new(0, 0, 0, 0), ScrollBarThickness = 2, ScrollBarImageColor3 = AccentColor, BorderSizePixel = 0, ZIndex = 152})
    local InfoLayout = Create("UIListLayout", {Parent = InfoScroll, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10)})
    local InfoDesc = Create("TextLabel", {Parent = InfoScroll, Text = "", Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = SubTextColor, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 152, TextTransparency = 1})
    local InfoExampleBox = Create("Frame", {Parent = InfoScroll, BackgroundColor3 = Color3.fromRGB(10, 10, 12), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 152})
    Create("UICorner", {Parent = InfoExampleBox, CornerRadius = UDim.new(0, 6)})
    Create("UIStroke", {Parent = InfoExampleBox, Color = Color3.fromRGB(40, 40, 45), Thickness = 1})
    local InfoExampleText = Create("TextLabel", {Parent = InfoExampleBox, Text = "", Font = Enum.Font.Code, TextSize = 12, TextColor3 = AccentColor, BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 0), Position = UDim2.new(0, 10, 0, 10), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 152, TextTransparency = 1})
    Create("UIPadding", {Parent = InfoExampleBox, PaddingBottom = UDim.new(0, 10)})

    InfoLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() InfoScroll.CanvasSize = UDim2.new(0, 0, 0, InfoLayout.AbsoluteContentSize.Y + 10) end)

    local function OpenInfoWindow(data)
        InfoTitle.Text = data.Title or "Information"
        InfoDesc.Text = data.Description or "No description provided."
        if data.Example then
            InfoExampleText.Text = data.Example
            InfoExampleBox.Visible = true
        else
            InfoExampleBox.Visible = false
        end
        InfoOverlay.Visible = true
        Tween(InfoOverlay, {BackgroundTransparency = 0.4}, 0.3)
        Tween(InfoCard, {BackgroundTransparency = 0}, 0.3)
        Tween(InfoCard:FindFirstChild("UIStroke"), {Transparency = 0.3}, 0.3)
        Tween(InfoScale, {Scale = 1}, 0.3)
        Tween(InfoTitle, {TextTransparency = 0}, 0.3)
        Tween(InfoCloseBtn, {TextTransparency = 0}, 0.3)
        Tween(InfoDesc, {TextTransparency = 0}, 0.3)
        if data.Example then Tween(InfoExampleText, {TextTransparency = 0}, 0.3) end
    end

    InfoCloseBtn.MouseButton1Click:Connect(function()
        Tween(InfoOverlay, {BackgroundTransparency = 1}, 0.3)
        Tween(InfoCard, {BackgroundTransparency = 1}, 0.3)
        Tween(InfoCard:FindFirstChild("UIStroke"), {Transparency = 1}, 0.3)
        Tween(InfoScale, {Scale = 0}, 0.3)
        Tween(InfoTitle, {TextTransparency = 1}, 0.3)
        Tween(InfoCloseBtn, {TextTransparency = 1}, 0.3)
        Tween(InfoDesc, {TextTransparency = 1}, 0.3)
        if InfoExampleBox.Visible then Tween(InfoExampleText, {TextTransparency = 1}, 0.3) end
        task.wait(0.3)
        InfoOverlay.Visible = false
    end)

    local function AddInfoIcon(parent, pos, data)
        if not data then return end
        local Btn = Create("TextButton", {Parent = parent, Text = "?", Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = SubTextColor, BackgroundColor3 = Color3.fromRGB(35, 35, 40), Size = UDim2.new(0, 16, 0, 16), Position = pos, AutoButtonColor = false, ZIndex = 5})
        Create("UICorner", {Parent = Btn, CornerRadius = UDim.new(1, 0)})
        AddBounce(Btn)
        Btn.MouseEnter:Connect(function() Tween(Btn, {TextColor3 = TextColor, BackgroundColor3 = AccentColor}, 0.2) end)
        Btn.MouseLeave:Connect(function() Tween(Btn, {TextColor3 = SubTextColor, BackgroundColor3 = Color3.fromRGB(35, 35, 40)}, 0.2) end)
        Btn.MouseButton1Click:Connect(function() OpenInfoWindow(data) end)
    end

    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    local windowWidth = math.min(650, math.max(430, viewport.X - 30))
    local windowHeight = math.min(420, math.max(300, viewport.Y - 60))

    local MainFrame = Create("Frame", {Parent = ScreenGui, BackgroundColor3 = BackgroundColor, Size = UDim2.fromOffset(windowWidth, windowHeight), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), ClipsDescendants = true, BackgroundTransparency = 1, Active = true})
    local MainScale = Create("UIScale", {Parent = MainFrame, Scale = 0.8})
    Create("UICorner", {Parent = MainFrame, CornerRadius = UDim.new(0, 8)})
    Create("UIStroke", {Parent = MainFrame, Color = Color3.fromRGB(40, 40, 45), Thickness = 1})
    Tween(MainScale, {Scale = 1}, 0.5)
    Tween(MainFrame, {BackgroundTransparency = 0}, 0.5)

    -- // OXIO BOTTOM CONTROL BAR
    -- A wider invisible drag target with a thin floating visual bar.
    -- The resize handle itself lives on the actual window corner, just like polished UI libraries.
    local BottomDragHitbox = Create("Frame", {
        Parent = ScreenGui,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(360, 28),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ZIndex = 145,
        Active = true
    })

    local FloatingBottomBar = Create("Frame", {
        Parent = BottomDragHitbox,
        BackgroundColor3 = CardColor,
        BackgroundTransparency = 0,
        Size = UDim2.new(1, 0, 0, 6),
        Position = UDim2.new(0, 0, 0.5, -3),
        ZIndex = 146
    })

    Create("UICorner", {
        Parent = FloatingBottomBar,
        CornerRadius = UDim.new(1, 0)
    })

    local BottomBarStroke = Create("UIStroke", {
        Parent = FloatingBottomBar,
        Color = Color3.fromRGB(50, 50, 55),
        Thickness = 1.2,
        Transparency = 0
    })

    MakeDraggable(BottomDragHitbox, MainFrame)

    -- // Obsidian-style corner resize handle
    local ResizeHandle = Create("TextButton", {
        Parent = MainFrame,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -3, 1, -3),
        Size = UDim2.fromOffset(28, 28),
        ZIndex = 150,
        Active = true
    })

    local ResizeScale = Create("UIScale", {
        Parent = ResizeHandle,
        Scale = 1
    })

    local ResizeLine1 = Create("Frame", {
        Parent = ResizeHandle,
        BackgroundColor3 = SubTextColor,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(2, 7),
        Position = UDim2.fromOffset(17, 17),
        Rotation = 45,
        AnchorPoint = Vector2.new(0.5, 0.5),
        ZIndex = 151
    })

    local ResizeLine2 = Create("Frame", {
        Parent = ResizeHandle,
        BackgroundColor3 = SubTextColor,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(2, 11),
        Position = UDim2.fromOffset(20, 14),
        Rotation = 45,
        AnchorPoint = Vector2.new(0.5, 0.5),
        ZIndex = 151
    })

    local ResizeLine3 = Create("Frame", {
        Parent = ResizeHandle,
        BackgroundColor3 = SubTextColor,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(2, 5),
        Position = UDim2.fromOffset(23, 11),
        Rotation = 45,
        AnchorPoint = Vector2.new(0.5, 0.5),
        ZIndex = 151
    })

    local function SetResizeVisual(active)
        local targetColor = active and TextColor or SubTextColor
        local targetScale = active and 1.08 or 1

        Tween(ResizeLine1, {BackgroundColor3 = targetColor}, 0.12)
        Tween(ResizeLine2, {BackgroundColor3 = targetColor}, 0.12)
        Tween(ResizeLine3, {BackgroundColor3 = targetColor}, 0.12)
        Tween(ResizeScale, {Scale = targetScale}, 0.12)
    end

    ResizeHandle.MouseEnter:Connect(function()
        SetResizeVisual(true)
    end)

    ResizeHandle.MouseLeave:Connect(function()
        SetResizeVisual(false)
    end)

    -- // Keep the external floating drag bar perfectly aligned without RenderStepped.
    local function UpdateBottomBar()
        if not MainFrame.Visible then
            BottomDragHitbox.Visible = false
            return
        end

        BottomDragHitbox.Visible = true

        local FrameSize = MainFrame.AbsoluteSize
        local FramePos = MainFrame.AbsolutePosition
        local BarWidth = math.clamp(FrameSize.X * 0.55, 220, 420)

        BottomDragHitbox.Size = UDim2.fromOffset(BarWidth, 28)
        BottomDragHitbox.Position = UDim2.fromOffset(
            FramePos.X + (FrameSize.X / 2),
            FramePos.Y + FrameSize.Y + 18
        )

        local Scale = MainScale.Scale
        FloatingBottomBar.Size = UDim2.new(1, 0, 0, 6 * Scale)
        FloatingBottomBar.Position = UDim2.new(0, 0, 0.5, -(3 * Scale))
    end

    MainFrame:GetPropertyChangedSignal("Size"):Connect(UpdateBottomBar)
    MainFrame:GetPropertyChangedSignal("Position"):Connect(UpdateBottomBar)
    MainFrame:GetPropertyChangedSignal("Visible"):Connect(UpdateBottomBar)
    MainScale:GetPropertyChangedSignal("Scale"):Connect(UpdateBottomBar)
    UpdateBottomBar()

    local TopBar = Create("Frame", {Parent = MainFrame, BackgroundColor3 = BackgroundColor, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 0), Active = true})
    MakeDraggable(TopBar, MainFrame)
    
    local titleOffsetX = 15
    if topbarLogo then
        local TopbarIcon = Create("ImageLabel", {
            Parent = TopBar,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, logoSize, 0, logoSize),
            Position = UDim2.new(0, 8, 0.5, -(logoSize / 2)),
            Image = topbarLogo,
            ScaleType = Enum.ScaleType.Fit
        })
        titleOffsetX = 8 + logoSize + 8
    end

    local TitleContainer = Create("Frame", {Parent = TopBar, BackgroundTransparency = 1, Size = UDim2.new(0, 160, 1, 0), Position = UDim2.new(0, titleOffsetX, 0, 0)})
    local Title = Create("TextLabel", {Parent = TitleContainer, Text = hubName, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = TextColor, BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 5), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left})
    local Subtitle = Create("TextLabel", {Parent = TitleContainer, Text = subText, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = subColor, BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 0, 12), TextXAlignment = Enum.TextXAlignment.Left})

    local SearchBar = Create("Frame", {Parent = TopBar, BackgroundColor3 = CardColor, Size = UDim2.fromOffset(math.max(150, windowWidth - (titleOffsetX + 175) - 105), 26), Position = UDim2.new(0, titleOffsetX + 175, 0.5, -13)})
    Create("UICorner", {Parent = SearchBar, CornerRadius = UDim.new(0, 6)})
    local SearchIcon = Create("ImageLabel", {Parent = SearchBar, BackgroundTransparency = 1, Image = "rbxassetid://6031154871", ImageColor3 = SubTextColor, Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, 8, 0.5, -7)})
    local SearchInput = Create("TextBox", {Parent = SearchBar, BackgroundTransparency = 1, Size = UDim2.new(1, -30, 1, 0), Position = UDim2.new(0, 30, 0, 0), Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TextColor, PlaceholderText = "Search..", TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false})

    local CloseBtn = Create("TextButton", {Parent = TopBar, Text = "X", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = SubTextColor, BackgroundTransparency = 1, Size = UDim2.new(0, 30, 1, 0), Position = UDim2.new(1, -35, 0, 0)})
    local MinBtn = Create("TextButton", {Parent = TopBar, Text = "—", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = SubTextColor, BackgroundTransparency = 1, Size = UDim2.new(0, 30, 1, 0), Position = UDim2.new(1, -65, 0, 0)})

    local InitialSidebarWidth = math.clamp(windowWidth * 0.25, 135, 175)

    local Sidebar = Create("Frame", {Parent = MainFrame, BackgroundColor3 = BackgroundColor, BackgroundTransparency = 1, Size = UDim2.new(0, InitialSidebarWidth, 1, -40), Position = UDim2.new(0, 0, 0, 40), Active = true})
    local TabSearchBox = Create("TextBox", {Parent = Sidebar, BackgroundColor3 = CardColor, Size = UDim2.new(1, -20, 0, 26), Position = UDim2.new(0, 10, 0, 5), Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TextColor, PlaceholderText = "Search tabs...", TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false})
    Create("UIPadding", {Parent = TabSearchBox, PaddingLeft = UDim.new(0, 8)})
    Create("UICorner", {Parent = TabSearchBox, CornerRadius = UDim.new(0, 4)})
    local TabSearchStroke = Create("UIStroke", {Parent = TabSearchBox, Color = Color3.fromRGB(45, 45, 50), Thickness = 1})
    
    local TabContainer = Create("ScrollingFrame", {Parent = Sidebar, BackgroundTransparency = 1, Size = UDim2.new(1, -15, 1, -40), Position = UDim2.new(0, 10, 0, 40), ScrollBarThickness = 0})
    Create("UIListLayout", {Parent = TabContainer, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5)})
    local Divider = Create("Frame", {Parent = MainFrame, BackgroundColor3 = Color3.fromRGB(40, 40, 45), BorderSizePixel = 0, Size = UDim2.new(0, 1, 1, -40), Position = UDim2.new(0, InitialSidebarWidth, 0, 40)})

    local ContentArea = Create("Frame", {Parent = MainFrame, BackgroundTransparency = 1, Size = UDim2.new(1, -InitialSidebarWidth - 5, 1, -40), Position = UDim2.new(0, InitialSidebarWidth + 5, 0, 40), Active = true})

    -- // Resize behavior / responsive layout
    MakeResizable(MainFrame, ResizeHandle, function(NewWidth, NewHeight)
        local SidebarWidth = math.clamp(NewWidth * 0.25, 135, 175)

        Sidebar.Size = UDim2.new(0, SidebarWidth, 1, -40)
        Divider.Position = UDim2.new(0, SidebarWidth, 0, 40)
        ContentArea.Position = UDim2.new(0, SidebarWidth + 5, 0, 40)
        ContentArea.Size = UDim2.new(1, -SidebarWidth - 5, 1, -40)

        local SearchStart = titleOffsetX + 175
        local SearchEndSpace = 105
        local AvailableWidth = NewWidth - SearchStart - SearchEndSpace

        SearchBar.Position = UDim2.new(0, SearchStart, 0.5, -13)
        SearchBar.Size = UDim2.fromOffset(math.max(150, AvailableWidth), 26)

        UpdateBottomBar()
    end)

    local Sphere = Create("ImageButton", {Parent = ScreenGui, BackgroundColor3 = BackgroundColor, BackgroundTransparency = 0.2, Size = UDim2.new(0, 50, 0, 50), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, AutoButtonColor = false, ImageTransparency = 1, ClipsDescendants = true})
    Create("UICorner", {Parent = Sphere, CornerRadius = UDim.new(1, 0)})
    Create("UIStroke", {Parent = Sphere, Color = AccentColor, Thickness = 2})
    
    -- MODIFIED SECTION: Text Label prioritized if SphereText toggle is true. Avoids passing boolean as Text.
    local SphereImageLabel = Create("ImageLabel", {Parent = Sphere, BackgroundTransparency = 1, Size = UDim2.new(0, sphIconSize, 0, sphIconSize), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), Image = sphImage or "", ImageTransparency = 1, Visible = (not sphTextToggle and sphImage ~= nil)})
    local SphereTextLabel = Create("TextLabel", {Parent = Sphere, Text = sphWords, Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = AccentColor, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), TextTransparency = 1, Visible = sphTextToggle})
    MakeDraggable(Sphere, Sphere)

    local Window = {CurrentTab = nil, Tabs = {}, Title = Title, AllCards = {}, MainFrame = MainFrame, CurrentTransparency = 0, ConfigElements = {}}

    function Window:SetTransparency(val)
        Window.CurrentTransparency = val
        if MainFrame.Visible then
            Tween(MainFrame, {BackgroundTransparency = val}, 0.3)
            -- Dynamic floating bottom bar transparency control integrated
            Tween(FloatingBottomBar, {BackgroundTransparency = val > 0 and 0.2 or 0}, 0.3)
        end
    end

    MinBtn.MouseButton1Click:Connect(function()
        Tween(MainScale, {Scale = 0}, 0.4)
        Tween(MainFrame, {BackgroundTransparency = 1}, 0.4)
        Tween(FloatingBottomBar, {BackgroundTransparency = 1}, 0.4)
        Tween(BottomBarStroke, {Transparency = 1}, 0.4)
        task.wait(0.3)
        MainFrame.Visible = false
        BottomDragHitbox.Visible = false
        Sphere.Visible = true
        Tween(Sphere, {Size = UDim2.new(0, 50, 0, 50)}, 0.4)
        
        -- Corrected fade logic depending on Text toggle
        if not sphTextToggle and sphImage then
            Tween(SphereImageLabel, {ImageTransparency = 0}, 0.4)
        elseif sphTextToggle then
            Tween(SphereTextLabel, {TextTransparency = 0}, 0.4)
        end
    end)

    Sphere.MouseButton1Click:Connect(function()
        Tween(Sphere, {Size = UDim2.new(0, 0, 0, 0)}, 0.3)
        
        -- Corrected fade logic depending on Text toggle
        if not sphTextToggle and sphImage then Tween(SphereImageLabel, {ImageTransparency = 1}, 0.3) end
        if sphTextToggle then Tween(SphereTextLabel, {TextTransparency = 1}, 0.3) end
        
        task.wait(0.2)
        Sphere.Visible = false
        MainFrame.Visible = true
        BottomDragHitbox.Visible = true
        Tween(MainScale, {Scale = 1}, 0.4)
        Tween(MainFrame, {BackgroundTransparency = Window.CurrentTransparency}, 0.4)
        Tween(FloatingBottomBar, {BackgroundTransparency = Window.CurrentTransparency > 0 and 0.2 or 0}, 0.4)
        Tween(BottomBarStroke, {Transparency = 0}, 0.4)
    end)

    local Popup = Create("Frame", {Parent = ScreenGui, BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ZIndex = 100, Visible = false, Active = true})
    local PopupCard = Create("Frame", {Parent = Popup, BackgroundColor3 = Color3.fromRGB(20, 20, 24), Size = UDim2.new(0, 320, 0, 160), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 101, BackgroundTransparency = 1, ClipsDescendants = false})
    Create("UICorner", {Parent = PopupCard, CornerRadius = UDim.new(0, 12)})
    local PopupScale = Create("UIScale", {Parent = PopupCard, Scale = 0.8})
    local PopupStroke = Create("UIStroke", {Parent = PopupCard, Color = Color3.fromRGB(50, 50, 55), Thickness = 1, Transparency = 1})
    local PopupTitle = Create("TextLabel", {Parent = PopupCard, Text = "Exit Application", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = TextColor, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 25), ZIndex = 102, TextTransparency = 1, TextXAlignment = Enum.TextXAlignment.Center})
    local PopupText = Create("TextLabel", {Parent = PopupCard, Text = "Are you sure you want to close Oxio? Unsaved configurations might be lost.", Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = SubTextColor, BackgroundTransparency = 1, Size = UDim2.new(1, -40, 0, 40), Position = UDim2.new(0, 20, 0, 55), ZIndex = 102, TextTransparency = 1, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true})
    local YesBtn = Create("TextButton", {Parent = PopupCard, Text = "Confirm", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.fromRGB(255, 255, 255), BackgroundColor3 = AccentColor, Size = UDim2.new(0, 125, 0, 36), Position = UDim2.new(0.5, 10, 0, 105), ZIndex = 102, BackgroundTransparency = 1, TextTransparency = 1, AutoButtonColor = false})
    Create("UICorner", {Parent = YesBtn, CornerRadius = UDim.new(0, 6)})
    AddBounce(YesBtn)
    local NoBtn = Create("TextButton", {Parent = PopupCard, Text = "Cancel", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = TextColor, BackgroundColor3 = Color3.fromRGB(40, 40, 45), Size = UDim2.new(0, 125, 0, 36), Position = UDim2.new(0.5, -135, 0, 105), ZIndex = 102, BackgroundTransparency = 1, TextTransparency = 1, AutoButtonColor = false})
    Create("UICorner", {Parent = NoBtn, CornerRadius = UDim.new(0, 6)})
    AddBounce(NoBtn)

    CloseBtn.MouseButton1Click:Connect(function()
        Popup.Visible = true
        Tween(Popup, {BackgroundTransparency = 0.5}, 0.3)
        Tween(PopupCard, {BackgroundTransparency = 0}, 0.3)
        Tween(PopupScale, {Scale = 1}, 0.3)
        Tween(PopupStroke, {Transparency = 0}, 0.3)
        Tween(PopupTitle, {TextTransparency = 0}, 0.3)
        Tween(PopupText, {TextTransparency = 0}, 0.3)
        Tween(YesBtn, {BackgroundTransparency = 0, TextTransparency = 0}, 0.3)
        Tween(NoBtn, {BackgroundTransparency = 0, TextTransparency = 0}, 0.3)
    end)

    YesBtn.MouseButton1Click:Connect(function()
        Tween(Popup, {BackgroundTransparency = 1}, 0.3)
        Tween(PopupCard, {BackgroundTransparency = 1}, 0.3)
        Tween(PopupStroke, {Transparency = 1}, 0.3)
        Tween(PopupTitle, {TextTransparency = 1}, 0.3)
        Tween(PopupText, {TextTransparency = 1}, 0.3)
        Tween(YesBtn, {BackgroundTransparency = 1, TextTransparency = 1}, 0.3)
        Tween(NoBtn, {BackgroundTransparency = 1, TextTransparency = 1}, 0.3)
        Tween(MainScale, {Scale = 0.8}, 0.3)
        Tween(MainFrame, {BackgroundTransparency = 1}, 0.3)
        Tween(FloatingBottomBar, {BackgroundTransparency = 1}, 0.3)
        Tween(BottomBarStroke, {Transparency = 1}, 0.3)

        for _, desc in ipairs(MainFrame:GetDescendants()) do
            if desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox") then Tween(desc, {TextTransparency = 1}, 0.3) if desc.BackgroundTransparency < 1 then Tween(desc, {BackgroundTransparency = 1}, 0.3) end
            elseif desc:IsA("ImageLabel") or desc:IsA("ImageButton") then Tween(desc, {ImageTransparency = 1}, 0.3)
            elseif desc:IsA("Frame") or desc:IsA("ScrollingFrame") then if desc.BackgroundTransparency < 1 then Tween(desc, {BackgroundTransparency = 1}, 0.3) end
            elseif desc:IsA("UIStroke") then Tween(desc, {Transparency = 1}, 0.3) end
        end
        task.wait(0.35)
        ScreenGui:Destroy()
    end)

    NoBtn.MouseButton1Click:Connect(function()
        Tween(Popup, {BackgroundTransparency = 1}, 0.3)
        Tween(PopupCard, {BackgroundTransparency = 1}, 0.3)
        Tween(PopupScale, {Scale = 0.8}, 0.3)
        Tween(PopupStroke, {Transparency = 1}, 0.3)
        Tween(PopupTitle, {TextTransparency = 1}, 0.3)
        Tween(PopupText, {TextTransparency = 1}, 0.3)
        Tween(YesBtn, {BackgroundTransparency = 1, TextTransparency = 1}, 0.3)
        Tween(NoBtn, {BackgroundTransparency = 1, TextTransparency = 1}, 0.3)
        task.wait(0.3)
        Popup.Visible = false
    end)

    TabSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local query = TabSearchBox.Text:lower()
        for _, tabInfo in ipairs(Window.Tabs) do
            if query == "" or string.find(tabInfo.Txt.Text:lower(), query) then
                tabInfo.Button.Visible = true
            else
                tabInfo.Button.Visible = false
            end
        end
    end)

    SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
        local query = SearchInput.Text:lower()
        if query == "" then
            for _, data in ipairs(Window.AllCards) do
                data.Card.Parent = data.OrigParent
                data.Card.Visible = true
            end
        else
            if not Window.CurrentTab or not Window.CurrentTab.CurrentPage then return end
            local activeLeft = Window.CurrentTab.CurrentPage.LeftCol
            local activeRight = Window.CurrentTab.CurrentPage.RightCol
            local placeLeft = true
            
            for _, data in ipairs(Window.AllCards) do
                local card = data.Card
                if data.Tab == Window.CurrentTab then
                    if not data.SearchIndex then
                        data.SearchIndex = BuildSearchIndex(card)
                    end
                    local match = string.find(data.SearchIndex, query, 1, true)
                    if match then
                        card.Parent = placeLeft and activeLeft or activeRight
                        placeLeft = not placeLeft
                        card.Visible = true
                    else
                        card.Visible = false
                    end
                else
                    card.Parent = data.OrigParent
                    card.Visible = true
                end
            end
        end
    end)

    function Window:CreateTab(tabName, isDefault, isLocked)
        local isWhitelisted = false
        local player = game:GetService("Players").LocalPlayer
        if player then
            for _, allowedUser in ipairs(Library.WhitelistedUsers) do
                if player.Name == allowedUser or player.DisplayName == allowedUser then
                    isWhitelisted = true
                    break
                end
            end
        end

        local TabBtn = Create("TextButton", {Parent = TabContainer, Text = "", BackgroundColor3 = HoverColor, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 35), AutoButtonColor = false})
        Create("UICorner", {Parent = TabBtn, CornerRadius = UDim.new(0, 6)})
        AddBounce(TabBtn, 0.98)
        local Indicator = Create("Frame", {Name = "Indicator", Parent = TabBtn, BackgroundColor3 = isLocked and Color3.fromRGB(255, 215, 0) or AccentColor, Size = UDim2.new(0, 3, 0, 0), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5)})
        Create("UICorner", {Parent = Indicator, CornerRadius = UDim.new(1, 0)})
        local Txt = Create("TextLabel", {Parent = TabBtn, Text = tabName, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = SubTextColor, BackgroundTransparency = 1, Size = UDim2.new(1, -40, 1, 0), Position = UDim2.new(0, 15, 0, 0), TextXAlignment = Enum.TextXAlignment.Left})

        if isLocked then
            Create("ImageLabel", {Parent = TabBtn, Image = "rbxassetid://6031082533", ImageColor3 = Color3.fromRGB(255, 215, 0), BackgroundTransparency = 1, Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(1, -22, 0.5, -7)})
        end

        local TabContent = Create("Frame", {Parent = ContentArea, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Visible = false})
        local PageNav = Create("Frame", {Parent = TabContent, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 35)})
        local PageNavList = Create("UIListLayout", {Parent = PageNav, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 15), VerticalAlignment = Enum.VerticalAlignment.Center})
        local PageContainer = Create("Frame", {Parent = TabContent, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -35), Position = UDim2.new(0, 0, 0, 35)})

        local TabConfig = {Button = TabBtn, Content = TabContent, Indicator = Indicator, Txt = Txt, Pages = {}, CurrentPage = nil}
        table.insert(Window.Tabs, TabConfig)

        TabBtn.MouseButton1Click:Connect(function()
            if isLocked and not isWhitelisted then
                SendPremiumNotification()
                return
            end

            if Window.CurrentTab == TabConfig then return end
            
            if Window.CurrentTab then
                Tween(Window.CurrentTab.Button, {BackgroundTransparency = 1}, 0.2)
                Tween(Window.CurrentTab.Indicator, {Size = UDim2.new(0, 3, 0, 0)}, 0.2)
                Tween(Window.CurrentTab.Txt, {TextColor3 = SubTextColor}, 0.2)
                Window.CurrentTab.Content.Visible = false
            end
            
            Window.CurrentTab = TabConfig
            TabConfig.Content.Visible = true
            
            TabConfig.Content.Position = UDim2.new(0, 0, 0, 15)
            Tween(TabConfig.Content, {Position = UDim2.new(0, 0, 0, 0)}, 0.35)

            Tween(TabBtn, {BackgroundTransparency = 0}, 0.2)
            Tween(Indicator, {Size = UDim2.new(0, 3, 0, 18)}, 0.3)
            Tween(Txt, {TextColor3 = TextColor}, 0.2)

            if #TabConfig.Pages > 0 then
                local firstPage = TabConfig.Pages[1]
                if TabConfig.CurrentPage ~= firstPage then
                    if TabConfig.CurrentPage then
                        Tween(TabConfig.CurrentPage.Btn, {TextColor3 = SubTextColor}, 0)
                        Tween(TabConfig.CurrentPage.Highlight, {Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 1}, 0)
                        TabConfig.CurrentPage.Scroll.Visible = false
                    end
                    TabConfig.CurrentPage = firstPage
                    firstPage.Scroll.Visible = true
                    
                    firstPage.Scroll.Position = UDim2.new(0, 5, 0, 15)
                    Tween(firstPage.Scroll, {Position = UDim2.new(0, 5, 0, 5)}, 0.35)

                    Tween(firstPage.Btn, {TextColor3 = TextColor}, 0)
                    Tween(firstPage.Highlight, {Size = UDim2.new(1, 0, 0, 2), BackgroundTransparency = 0}, 0)
                end
            end
        end)

        function TabConfig:CreatePage(pageName)
            local PageBtn = Create("TextButton", {Parent = PageNav, Text = pageName, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = SubTextColor, BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X})
            local PageHighlight = Create("Frame", {Parent = PageBtn, BackgroundColor3 = AccentColor, Size = UDim2.new(0, 0, 0, 2), Position = UDim2.new(0.5, 0, 1, -5), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1})
            local PageScroll = Create("ScrollingFrame", {Parent = PageContainer, BackgroundTransparency = 1, Size = UDim2.new(1, -10, 1, -10), Position = UDim2.new(0, 5, 0, 5), ScrollBarThickness = 2, ScrollBarImageColor3 = Color3.fromRGB(60, 60, 65), Visible = false, BorderSizePixel = 0})

            local LeftColumn = Create("Frame", {Parent = PageScroll, BackgroundTransparency = 1, Size = UDim2.new(0.5, -5, 1, 0)})
            local RightColumn = Create("Frame", {Parent = PageScroll, BackgroundTransparency = 1, Size = UDim2.new(0.5, -5, 1, 0), Position = UDim2.new(0.5, 5, 0, 0)})
            
            local L_Layout = Create("UIListLayout", {Parent = LeftColumn, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10)})
            local R_Layout = Create("UIListLayout", {Parent = RightColumn, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10)})
            
            L_Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() PageScroll.CanvasSize = UDim2.new(0, 0, 0, math.max(L_Layout.AbsoluteContentSize.Y, R_Layout.AbsoluteContentSize.Y) + 20) end)
            R_Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() PageScroll.CanvasSize = UDim2.new(0, 0, 0, math.max(L_Layout.AbsoluteContentSize.Y, R_Layout.AbsoluteContentSize.Y) + 20) end)

            local PageObj = {Scroll = PageScroll, Btn = PageBtn, Highlight = PageHighlight, Left = true, LeftCol = LeftColumn, RightCol = RightColumn}
            table.insert(TabConfig.Pages, PageObj)

            PageBtn.MouseButton1Click:Connect(function()
                if TabConfig.CurrentPage == PageObj then return end
                if TabConfig.CurrentPage then
                    Tween(TabConfig.CurrentPage.Btn, {TextColor3 = SubTextColor}, 0.2)
                    Tween(TabConfig.CurrentPage.Highlight, {Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 1}, 0.2)
                    TabConfig.CurrentPage.Scroll.Visible = false
                end
                TabConfig.CurrentPage = PageObj
                PageObj.Scroll.Visible = true
                
                PageObj.Scroll.Position = UDim2.new(0, 5, 0, 20)
                Tween(PageObj.Scroll, {Position = UDim2.new(0, 5, 0, 5)}, 0.35)

                Tween(PageBtn, {TextColor3 = TextColor}, 0.2)
                Tween(PageHighlight, {Size = UDim2.new(1, 0, 0, 2), BackgroundTransparency = 0}, 0.3)
            end)

            if #TabConfig.Pages == 1 and not isLocked then
                TabConfig.CurrentPage = PageObj
                PageObj.Scroll.Visible = true
                PageBtn.TextColor3 = TextColor
                PageHighlight.Size = UDim2.new(1, 0, 0, 2)
                PageHighlight.BackgroundTransparency = 0
            end

            function PageObj:CreateSection(sectionName)
                local targetColumn = PageObj.Left and LeftColumn or RightColumn
                PageObj.Left = not PageObj.Left

                local SectionContainer = Create("Frame", {Parent = targetColumn, BackgroundColor3 = CardColor, Size = UDim2.new(1, 0, 0, 30), AutomaticSize = Enum.AutomaticSize.Y, ClipsDescendants = true})
                Create("UICorner", {Parent = SectionContainer, CornerRadius = UDim.new(0, 6)})
                
                table.insert(Window.AllCards, {
                    Card = SectionContainer,
                    OrigParent = targetColumn,
                    Tab = TabConfig,
                    Page = PageObj,
                    SearchIndex = nil 
                })
                
                local Title = Create("TextLabel", {Parent = SectionContainer, Text = sectionName, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = TextColor, BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 10, 0, 0), TextXAlignment = Enum.TextXAlignment.Left})
                local ItemContainer = Create("Frame", {Parent = SectionContainer, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 0, 30), AutomaticSize = Enum.AutomaticSize.Y})
                local Pad = Create("UIPadding", {Parent = ItemContainer, PaddingBottom = UDim.new(0, 10), PaddingTop = UDim.new(0, 5)})
                local SList = Create("UIListLayout", {Parent = ItemContainer, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8)})

                local Elements = {}

                function Elements:AddCopyButton(name, copyText, infoData)
                    local BtnFrame = Create("Frame", {Parent = ItemContainer, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30)})
                    local Btn = Create("TextButton", {Parent = BtnFrame, Text = name, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TextColor, BackgroundColor3 = BackgroundColor, Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 10, 0, 0), AutoButtonColor = false})
                    Create("UICorner", {Parent = Btn, CornerRadius = UDim.new(0, 4)})
                    Create("UIStroke", {Parent = Btn, Color = Color3.fromRGB(45, 45, 50), Thickness = 1})

                    AddBounce(Btn)
                    Btn.MouseEnter:Connect(function() Tween(Btn, {BackgroundColor3 = HoverColor}, 0.2) end)
                    Btn.MouseLeave:Connect(function() Tween(Btn, {BackgroundColor3 = BackgroundColor}, 0.2) end)
                    
                    Btn.MouseButton1Click:Connect(function()
                        SafeCopyToClipboard(copyText)
                        local oldText = Btn.Text
                        Btn.Text = "Copied to Clipboard!"
                        Tween(Btn, {TextColor3 = AccentColor, BackgroundColor3 = HoverColor}, 0.2)
                        task.wait(1.5)
                        if Btn.Parent then
                            Btn.Text = oldText
                            Tween(Btn, {TextColor3 = TextColor, BackgroundColor3 = BackgroundColor}, 0.2)
                        end
                    end)
                    AddInfoIcon(BtnFrame, UDim2.new(1, -40, 0.5, -8), infoData)
                end

                function Elements:AddButton(name, callback, infoData)
                    local BtnFrame = Create("Frame", {Parent = ItemContainer, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30)})
                    local Btn = Create("TextButton", {Parent = BtnFrame, Text = name, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TextColor, BackgroundColor3 = BackgroundColor, Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 10, 0, 0), AutoButtonColor = false})
                    Create("UICorner", {Parent = Btn, CornerRadius = UDim.new(0, 4)})
                    Create("UIStroke", {Parent = Btn, Color = Color3.fromRGB(45, 45, 50), Thickness = 1})

                    AddBounce(Btn)
                    Btn.MouseEnter:Connect(function() Tween(Btn, {BackgroundColor3 = HoverColor}, 0.2) end)
                    Btn.MouseLeave:Connect(function() Tween(Btn, {BackgroundColor3 = BackgroundColor}, 0.2) end)
                    Btn.MouseButton1Click:Connect(function() if callback then callback() end end)

                    AddInfoIcon(BtnFrame, UDim2.new(1, -40, 0.5, -8), infoData)
                end

                function Elements:AddToggle(name, default, callback, infoData)
                    local state = default or false
                    local TogFrame = Create("Frame", {Parent = ItemContainer, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24)})
                    
                    Create("TextLabel", {Parent = TogFrame, Text = name, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = SubTextColor, BackgroundTransparency = 1, Size = UDim2.new(1, -60, 1, 0), Position = UDim2.new(0, 10, 0, 0), TextXAlignment = Enum.TextXAlignment.Left})
                    
                    local Lever = Create("TextButton", {Parent = TogFrame, Text = "", BackgroundColor3 = state and AccentColor or Color3.fromRGB(45, 45, 50), Size = UDim2.new(0, 36, 0, 18), Position = UDim2.new(1, -46, 0.5, -9), AutoButtonColor = false})
                    Create("UICorner", {Parent = Lever, CornerRadius = UDim.new(1, 0)})
                    AddBounce(Lever)
                    
                    local Knob = Create("Frame", {Parent = Lever, BackgroundColor3 = Color3.fromRGB(255, 255, 255), Size = UDim2.new(0, 14, 0, 14), Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)})
                    Create("UICorner", {Parent = Knob, CornerRadius = UDim.new(1, 0)})

                    local function internalSet(val)
                        state = val
                        Tween(Lever, {BackgroundColor3 = state and AccentColor or Color3.fromRGB(45, 45, 50)}, 0.3)
                        Tween(Knob, {Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)}, 0.3)
                        if callback then callback(state) end
                    end

                    Lever.MouseButton1Click:Connect(function() internalSet(not state) end)
                    AddInfoIcon(TogFrame, UDim2.new(1, -70, 0.5, -8), infoData)
                    
                    Window.ConfigElements[name] = { Set = internalSet, Get = function() return state end }
                end

                function Elements:AddSlider(name, min, max, default, callback, infoData)
                    local val = default or min
                    local SliFrame = Create("Frame", {Parent = ItemContainer, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 45)})
                    
                    Create("TextLabel", {Parent = SliFrame, Text = name, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = SubTextColor, BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 15), Position = UDim2.new(0, 10, 0, 0), TextXAlignment = Enum.TextXAlignment.Left})
                    local ValTxt = Create("TextLabel", {Parent = SliFrame, Text = tostring(val), Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = TextColor, BackgroundTransparency = 1, Size = UDim2.new(0, 30, 0, 15), Position = UDim2.new(1, -40, 0, 0), TextXAlignment = Enum.TextXAlignment.Right})
                    
                    local TrackBase = Create("Frame", {Parent = SliFrame, BackgroundColor3 = BackgroundColor, Size = UDim2.new(1, -20, 0, 6), Position = UDim2.new(0, 10, 0, 25)})
                    Create("UICorner", {Parent = TrackBase, CornerRadius = UDim.new(1, 0)})
                    Create("UIStroke", {Parent = TrackBase, Color = Color3.fromRGB(45, 45, 50), Thickness = 1})

                    local Fill = Create("Frame", {Parent = TrackBase, BackgroundColor3 = AccentColor, Size = UDim2.new((val-min)/(max-min), 0, 1, 0)})
                    Create("UICorner", {Parent = Fill, CornerRadius = UDim.new(1, 0)})
                    local Knob = Create("Frame", {Parent = Fill, BackgroundColor3 = Color3.fromRGB(255, 255, 255), Size = UDim2.new(0, 12, 0, 12), Position = UDim2.new(1, -6, 0.5, -6)})
                    Create("UICorner", {Parent = Knob, CornerRadius = UDim.new(1, 0)})

                    local function internalSet(v)
                        val = math.clamp(v, min, max)
                        ValTxt.Text = tostring(val)
                        Tween(Fill, {Size = UDim2.new((val-min)/(max-min), 0, 1, 0)}, 0.1)
                        if callback then callback(val) end
                    end

                    local dragging = false
                    local function Update(input)
                        local pos = math.clamp((input.Position.X - TrackBase.AbsolutePosition.X) / TrackBase.AbsoluteSize.X, 0, 1)
                        internalSet(math.floor(min + ((max - min) * pos)))
                    end

                    Knob.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true end end)
                    UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
                    UserInputService.InputChanged:Connect(function(input) if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then Update(input) end end)
                    AddInfoIcon(SliFrame, UDim2.new(1, -65, 0, 0), infoData)

                    Window.ConfigElements[name] = { Set = internalSet, Get = function() return val end }
                end

                function Elements:AddDropdown(name, options, isMulti, callback, infoData)
                    local selected = isMulti and {} or (options[1] or nil)
                    local dropped = false
                    local optionButtons = {}
                    local maxVisible = math.min(#options, 3)
                    local listHeight = maxVisible * 25
                    local dropOpenHeight = 50 + 32 + listHeight
                    
                    local DropFrame = Create("Frame", {Parent = ItemContainer, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50), ClipsDescendants = true})
                    Create("TextLabel", {Parent = DropFrame, Text = name, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = SubTextColor, BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 15), Position = UDim2.new(0, 10, 0, 0), TextXAlignment = Enum.TextXAlignment.Left})
                    
                    local MainBtn = Create("TextButton", {Parent = DropFrame, Text = isMulti and "Select Options..." or "Select...", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TextColor, BackgroundColor3 = BackgroundColor, Size = UDim2.new(1, -20, 0, 26), Position = UDim2.new(0, 10, 0, 20), AutoButtonColor = false, TextXAlignment = Enum.TextXAlignment.Left})
                    Create("UIPadding", {Parent = MainBtn, PaddingLeft = UDim.new(0, 8)})
                    Create("UICorner", {Parent = MainBtn, CornerRadius = UDim.new(0, 4)})
                    Create("UIStroke", {Parent = MainBtn, Color = Color3.fromRGB(45, 45, 50), Thickness = 1})
                    AddBounce(MainBtn, 0.98)
                    local Arrow = Create("TextLabel", {Parent = MainBtn, Text = "▼", Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = SubTextColor, BackgroundTransparency = 1, Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -28, 0, 0)})

                    local SearchBox = Create("TextBox", {Parent = DropFrame, PlaceholderText = "Search...", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TextColor, BackgroundColor3 = Color3.fromRGB(15, 15, 18), Size = UDim2.new(1, -20, 0, 24), Position = UDim2.new(0, 10, 0, 50), TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Visible = false})
                    Create("UIPadding", {Parent = SearchBox, PaddingLeft = UDim.new(0, 8)})
                    Create("UICorner", {Parent = SearchBox, CornerRadius = UDim.new(0, 4)})
                    local SearchStroke = Create("UIStroke", {Parent = SearchBox, Color = Color3.fromRGB(45, 45, 50), Thickness = 1})

                    local ListFrame = Create("ScrollingFrame", {Parent = DropFrame, BackgroundColor3 = BackgroundColor, Size = UDim2.new(1, -20, 0, listHeight), Position = UDim2.new(0, 10, 0, 78), CanvasSize = UDim2.new(0, 0, 0, #options * 25), ScrollBarThickness = 2, ScrollBarImageColor3 = Color3.fromRGB(80, 80, 85), BorderSizePixel = 0})
                    Create("UICorner", {Parent = ListFrame, CornerRadius = UDim.new(0, 4)})
                    local DList = Create("UIListLayout", {Parent = ListFrame, SortOrder = Enum.SortOrder.LayoutOrder})

                    local function UpdateText()
                        if isMulti then
                            local txt = ""
                            for _, v in pairs(selected) do txt = txt .. v .. ", " end
                            MainBtn.Text = txt == "" and "Select Options..." or txt:sub(1, -3)
                        else
                            MainBtn.Text = selected or "Select..."
                        end
                    end

                    local function internalSet(v)
                        selected = v
                        UpdateText()
                        for _, btn in ipairs(optionButtons) do
                            local isSel = false
                            if isMulti then
                                isSel = table.find(selected, btn.Text) ~= nil
                            else
                                isSel = (selected == btn.Text)
                            end
                            Tween(btn, {TextColor3 = isSel and TextColor or SubTextColor}, 0.2)
                            Tween(btn:FindFirstChild("Frame"), {Size = isSel and UDim2.new(1, 0, 1, 0) or UDim2.new(0, 0, 1, 0)}, 0.2)
                        end
                        if callback then callback(selected) end
                    end

                    for _, opt in pairs(options) do
                        local isInitialSelected = (not isMulti and selected == opt)
                        local OptBtn = Create("TextButton", {Parent = ListFrame, Text = opt, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = isInitialSelected and TextColor or SubTextColor, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 25), AutoButtonColor = false})
                        local Check = Create("Frame", {Parent = OptBtn, BackgroundColor3 = AccentColor, Size = isInitialSelected and UDim2.new(1, 0, 1, 0) or UDim2.new(0, 0, 1, 0), BackgroundTransparency = 0.8})
                        table.insert(optionButtons, OptBtn)
                        
                        OptBtn.MouseButton1Click:Connect(function()
                            if isMulti then
                                if table.find(selected, opt) then
                                    table.remove(selected, table.find(selected, opt))
                                else
                                    table.insert(selected, opt)
                                end
                                internalSet(selected)
                            else
                                internalSet(opt)
                                dropped = false
                                Tween(Arrow, {Rotation = 0}, 0.3)
                                Tween(DropFrame, {Size = UDim2.new(1, 0, 0, 50)}, 0.3)
                                SearchBox.Visible = false
                            end
                        end)
                    end
                    UpdateText()

                    SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
                        local q = SearchBox.Text:lower()
                        for _, btn in ipairs(optionButtons) do
                            if q == "" or string.find(btn.Text:lower(), q) then btn.Visible = true else btn.Visible = false end
                        end
                    end)

                    DList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                        ListFrame.CanvasSize = UDim2.new(0, 0, 0, DList.AbsoluteContentSize.Y)
                        if dropped then
                            local dynamicHeight = math.min(DList.AbsoluteContentSize.Y, listHeight)
                            local newOpenHeight = 50 + 32 + dynamicHeight
                            ListFrame.Size = UDim2.new(1, -20, 0, dynamicHeight)
                            Tween(DropFrame, {Size = UDim2.new(1, 0, 0, newOpenHeight)}, 0.1)
                        end
                    end)

                    MainBtn.MouseButton1Click:Connect(function()
                        dropped = not dropped
                        if dropped then
                            SearchBox.Visible = true
                            SearchBox.Text = ""
                            Tween(Arrow, {Rotation = 180}, 0.3)
                            local dynamicHeight = math.min(DList.AbsoluteContentSize.Y, listHeight)
                            local newOpenHeight = 50 + 32 + dynamicHeight
                            ListFrame.Size = UDim2.new(1, -20, 0, dynamicHeight)
                            Tween(DropFrame, {Size = UDim2.new(1, 0, 0, newOpenHeight)}, 0.3)
                        else
                            SearchBox.Visible = false
                            Tween(Arrow, {Rotation = 0}, 0.3)
                            Tween(DropFrame, {Size = UDim2.new(1, 0, 0, 50)}, 0.3)
                        end
                    end)
                    AddInfoIcon(DropFrame, UDim2.new(1, -25, 0, 0), infoData)

                    Window.ConfigElements[name] = { Set = internalSet, Get = function() return selected end }
                end

                function Elements:AddTextbox(name, placeholder, callback, infoData)
                    local TxtFrame = Create("Frame", {Parent = ItemContainer, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50)})
                    Create("TextLabel", {Parent = TxtFrame, Text = name, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = SubTextColor, BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 15), Position = UDim2.new(0, 10, 0, 0), TextXAlignment = Enum.TextXAlignment.Left})
                    local Input = Create("TextBox", {Parent = TxtFrame, PlaceholderText = placeholder or "Type here...", Text = "", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TextColor, BackgroundColor3 = BackgroundColor, Size = UDim2.new(1, -20, 0, 26), Position = UDim2.new(0, 10, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false})
                    Create("UIPadding", {Parent = Input, PaddingLeft = UDim.new(0, 8)})
                    Create("UICorner", {Parent = Input, CornerRadius = UDim.new(0, 4)})
                    local Stroke = Create("UIStroke", {Parent = Input, Color = Color3.fromRGB(45, 45, 50), Thickness = 1})

                    local function internalSet(v)
                        Input.Text = tostring(v)
                        if callback then callback(v) end
                    end

                    Input.FocusLost:Connect(function(enterPressed) internalSet(Input.Text) end)
                    AddInfoIcon(TxtFrame, UDim2.new(1, -25, 0, 0), infoData)
                    
                    Window.ConfigElements[name] = { Set = internalSet, Get = function() return Input.Text end }
                end

                function Elements:AddColorPicker(name, defaultColor, callback, infoData)
                    local color = defaultColor or Color3.fromRGB(255, 255, 255)
                    local h, s, v_hsv = color:ToHSV()
                    local dropped = false
                    
                    local CFrame = Create("Frame", {Parent = ItemContainer, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), ClipsDescendants = true})
                    Create("TextLabel", {Parent = CFrame, Text = name, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = SubTextColor, BackgroundTransparency = 1, Size = UDim2.new(1, -60, 0, 30), Position = UDim2.new(0, 10, 0, 0), TextXAlignment = Enum.TextXAlignment.Left})
                    local DisplayBtn = Create("TextButton", {Parent = CFrame, Text = "", BackgroundColor3 = color, Size = UDim2.new(0, 30, 0, 16), Position = UDim2.new(1, -40, 0.5, -8), AutoButtonColor = false})
                    Create("UICorner", {Parent = DisplayBtn, CornerRadius = UDim.new(0, 4)})
                    Create("UIStroke", {Parent = DisplayBtn, Color = Color3.fromRGB(255,255,255), Transparency = 0.8, Thickness = 1})
                    AddBounce(DisplayBtn)

                    local PickerArea = Create("Frame", {Parent = CFrame, BackgroundColor3 = BackgroundColor, Size = UDim2.new(1, -20, 0, 140), Position = UDim2.new(0, 10, 0, 35)})
                    Create("UICorner", {Parent = PickerArea, CornerRadius = UDim.new(0, 4)})

                    local PickerClose = Create("TextButton", {Parent = PickerArea, Text = "X", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = SubTextColor, BackgroundColor3 = Color3.fromRGB(30, 20, 20), Size = UDim2.new(0, 18, 0, 18), Position = UDim2.new(1, -22, 0, 4), ZIndex = 50, AutoButtonColor = false})
                    Create("UICorner", {Parent = PickerClose, CornerRadius = UDim.new(0, 4)})
                    AddBounce(PickerClose)
                    
                    PickerClose.MouseEnter:Connect(function() Tween(PickerClose, {TextColor3 = Color3.fromRGB(255, 60, 60)}, 0.2) end)
                    PickerClose.MouseLeave:Connect(function() Tween(PickerClose, {TextColor3 = SubTextColor}, 0.2) end)
                    PickerClose.MouseButton1Click:Connect(function() dropped = false Tween(CFrame, {Size = UDim2.new(1, 0, 0, 30)}, 0.3) end)

                    local SVMap = Create("TextButton", {Parent = PickerArea, Text = "", BackgroundColor3 = Color3.fromHSV(h, 1, 1), Size = UDim2.new(1, -45, 0, 90), Position = UDim2.new(0, 10, 0, 10), AutoButtonColor = false, Active = true})
                    Create("UICorner", {Parent = SVMap, CornerRadius = UDim.new(0, 4)})
                    
                    local WhiteGrad = Create("Frame", {Parent = SVMap, Size = UDim2.new(1,0,1,0), BackgroundColor3 = Color3.new(1,1,1), ZIndex = 2})
                    Create("UIGradient", {Parent = WhiteGrad, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}), Rotation = 0})
                    Create("UICorner", {Parent = WhiteGrad, CornerRadius = UDim.new(0, 4)})

                    local BlackGrad = Create("Frame", {Parent = SVMap, Size = UDim2.new(1,0,1,0), BackgroundColor3 = Color3.new(0,0,0), ZIndex = 3})
                    Create("UIGradient", {Parent = BlackGrad, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)}), Rotation = 90})
                    Create("UICorner", {Parent = BlackGrad, CornerRadius = UDim.new(0, 4)})

                    local SVRing = Create("Frame", {Parent = BlackGrad, Size = UDim2.new(0, 10, 0, 10), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(s, 0, 1-v_hsv, 0), BackgroundColor3 = Color3.new(1,1,1), ZIndex = 4})
                    Create("UICorner", {Parent = SVRing, CornerRadius = UDim.new(1, 0)})
                    Create("UIStroke", {Parent = SVRing, Color = Color3.new(0,0,0), Thickness = 1})

                    local HueSlider = Create("TextButton", {Parent = PickerArea, Text = "", Size = UDim2.new(1, -20, 0, 15), Position = UDim2.new(0, 10, 0, 110), AutoButtonColor = false, BackgroundColor3 = Color3.new(1,1,1), Active = true})
                    Create("UICorner", {Parent = HueSlider, CornerRadius = UDim.new(0, 4)})
                    local HueGradient = Create("UIGradient", {Parent = HueSlider, Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)), ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255, 255, 0)), ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)), ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0, 0, 255)), ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))})})
                    local HueRing = Create("Frame", {Parent = HueSlider, Size = UDim2.new(0, 6, 0, 15), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(h, 0, 0.5, 0), BackgroundColor3 = Color3.new(1,1,1)})
                    Create("UICorner", {Parent = HueRing, CornerRadius = UDim.new(0, 2)})
                    Create("UIStroke", {Parent = HueRing, Color = Color3.new(0,0,0), Thickness = 1})

                    local function internalSet(hexString)
                        local s_check, c = pcall(function() return Color3.fromHex(hexString) end)
                        if s_check then
                            color = c
                            h, s, v_hsv = color:ToHSV()
                            DisplayBtn.BackgroundColor3 = color
                            SVMap.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                            SVRing.Position = UDim2.new(s, 0, 1-v_hsv, 0)
                            HueRing.Position = UDim2.new(h, 0, 0.5, 0)
                            if callback then callback(color) end
                        end
                    end

                    local function UpdateColor()
                        color = Color3.fromHSV(h, s, v_hsv)
                        DisplayBtn.BackgroundColor3 = color
                        SVMap.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                        if callback then callback(color) end
                    end

                    local draggingSV = false
                    local draggingHue = false
                    
                    SVMap.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingSV = true if PageObj and PageObj.Scroll then PageObj.Scroll.ScrollingEnabled = false end end end)
                    HueSlider.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingHue = true if PageObj and PageObj.Scroll then PageObj.Scroll.ScrollingEnabled = false end end end)
                    UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingSV = false draggingHue = false if PageObj and PageObj.Scroll then PageObj.Scroll.ScrollingEnabled = true end end end)

                    UserInputService.InputChanged:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                            if draggingSV then
                                local relX = math.clamp((input.Position.X - SVMap.AbsolutePosition.X) / SVMap.AbsoluteSize.X, 0, 1)
                                local relY = math.clamp((input.Position.Y - SVMap.AbsolutePosition.Y) / SVMap.AbsoluteSize.Y, 0, 1)
                                s = relX
                                v_hsv = 1 - relY
                                SVRing.Position = UDim2.new(s, 0, 1-v_hsv, 0)
                                UpdateColor()
                            elseif draggingHue then
                                local relX = math.clamp((input.Position.X - HueSlider.AbsolutePosition.X) / HueSlider.AbsoluteSize.X, 0, 1)
                                h = relX
                                HueRing.Position = UDim2.new(h, 0, 0.5, 0)
                                UpdateColor()
                            end
                        end
                    end)

                    DisplayBtn.MouseButton1Click:Connect(function() dropped = not dropped Tween(CFrame, {Size = UDim2.new(1, 0, 0, dropped and 185 or 30)}, 0.3) end)
                    AddInfoIcon(CFrame, UDim2.new(1, -65, 0, 7), infoData)

                    Window.ConfigElements[name] = { Set = internalSet, Get = function() return color:ToHex() end }
                end

                function Elements:AddConfigManager(folderName)
                    folderName = folderName or "oxioSavers"
                    if not _isfolder(folderName) then _makefolder(folderName) end

                    local ManagerFrame = Create("Frame", {Parent = ItemContainer, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 240)})
                    
                    local ManagerSearch = Create("TextBox", {Parent = ManagerFrame, PlaceholderText = "Search Saves Loader...", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TextColor, BackgroundColor3 = BackgroundColor, Size = UDim2.new(1, -20, 0, 26), Position = UDim2.new(0, 10, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false})
                    Create("UIPadding", {Parent = ManagerSearch, PaddingLeft = UDim.new(0, 8)})
                    Create("UICorner", {Parent = ManagerSearch, CornerRadius = UDim.new(0, 4)})
                    Create("UIStroke", {Parent = ManagerSearch, Color = Color3.fromRGB(45, 45, 50), Thickness = 1})

                    local Monitor = Create("ScrollingFrame", {Parent = ManagerFrame, BackgroundColor3 = Color3.fromRGB(15, 15, 18), Size = UDim2.new(1, -20, 0, 110), Position = UDim2.new(0, 10, 0, 35), ScrollBarThickness = 2, BorderSizePixel = 0, CanvasSize = UDim2.new(0, 0, 0, 0)})
                    Create("UICorner", {Parent = Monitor, CornerRadius = UDim.new(0, 4)})
                    Create("UIStroke", {Parent = Monitor, Color = Color3.fromRGB(45, 45, 50), Thickness = 1})
                    local MonitorLayout = Create("UIListLayout", {Parent = Monitor, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5)})
                    Create("UIPadding", {Parent = Monitor, PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5)})

                    MonitorLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                        Monitor.CanvasSize = UDim2.new(0, 0, 0, MonitorLayout.AbsoluteContentSize.Y + 10)
                    end)

                    local deleteMode = false
                    local editMode = false
                    local selectedForDelete = {}
                    local editTargetFile = ""

                    local Controls = Create("Frame", {Parent = ManagerFrame, BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 80), Position = UDim2.new(0, 10, 0, 155)})

                    local NameBox = Create("TextBox", {Parent = Controls, PlaceholderText = "Enter save name...", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TextColor, BackgroundColor3 = BackgroundColor, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false})
                    Create("UIPadding", {Parent = NameBox, PaddingLeft = UDim.new(0, 8)})
                    Create("UICorner", {Parent = NameBox, CornerRadius = UDim.new(0, 4)})
                    Create("UIStroke", {Parent = NameBox, Color = Color3.fromRGB(45, 45, 50), Thickness = 1})

                    local CreateBtn = Create("TextButton", {Parent = Controls, Text = "Create Save", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.fromRGB(255,255,255), BackgroundColor3 = AccentColor, Size = UDim2.new(0.5, -5, 0, 26), Position = UDim2.new(0, 0, 0, 35), AutoButtonColor = false})
                    Create("UICorner", {Parent = CreateBtn, CornerRadius = UDim.new(0, 4)})
                    AddBounce(CreateBtn)

                    local DeleteTogBtn = Create("TextButton", {Parent = Controls, Text = "Delete Mode: OFF", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = TextColor, BackgroundColor3 = Color3.fromRGB(45, 45, 50), Size = UDim2.new(0.5, -5, 0, 26), Position = UDim2.new(0.5, 5, 0, 35), AutoButtonColor = false})
                    Create("UICorner", {Parent = DeleteTogBtn, CornerRadius = UDim.new(0, 4)})
                    AddBounce(DeleteTogBtn)

                    local ActionArea = Create("Frame", {Parent = Controls, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 0, 35), Visible = false})
                    
                    local ConfirmActionBtn = Create("TextButton", {Parent = ActionArea, Text = "Confirm", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.fromRGB(255,255,255), BackgroundColor3 = Color3.fromRGB(200, 50, 50), Size = UDim2.new(0.5, -5, 0, 26), Position = UDim2.new(0, 0, 0, 0), AutoButtonColor = false})
                    Create("UICorner", {Parent = ConfirmActionBtn, CornerRadius = UDim.new(0, 4)})
                    AddBounce(ConfirmActionBtn)

                    local CancelActionBtn = Create("TextButton", {Parent = ActionArea, Text = "Cancel", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = TextColor, BackgroundColor3 = Color3.fromRGB(60, 60, 65), Size = UDim2.new(0.5, -5, 0, 26), Position = UDim2.new(0.5, 5, 0, 0), AutoButtonColor = false})
                    Create("UICorner", {Parent = CancelActionBtn, CornerRadius = UDim.new(0, 4)})
                    AddBounce(CancelActionBtn)

                    AddInfoIcon(ManagerFrame, UDim2.new(1, -20, 0, -22), {
                        Title = "Saves Loader Config Protocol",
                        Description = "Welcome to the Saves System. Here are your instructions:\n\n" ..
                        "1. Create a Save: Type a name in the text box below and click 'Create Save'. This executes the configuration saving.\n" ..
                        "2. Create a Name: Any string is valid. Naming it the exact same as an existing save will not overwrite the old one; it inherently creates a new duplicate file seamlessly.\n" ..
                        "3. Delete a Save Loader: Click 'Delete Mode: OFF' to toggle it ON. Click the file you want deleted (it turns red). Click 'Delete Selected'. A prompt will appear; click Yes to permanently erase.\n" ..
                        "4. Saves Loader Functionality: The system pulls all modified user data (Toggles, Sliders, Colors) and exports it securely as JSON to your workspace. Clicking 'Load' pulls it back in.\n" ..
                        "5. Edit / Overwrite: Click 'Edit' on a save. Change the name inside the input box, then click 'Save Edit'. This effectively edits the target.\n" ..
                        "6. Unedit Saves Loader: If you mistakenly clicked 'Edit' or 'Delete Mode', simply click the 'Cancel' button to back out without causing changes."
                    })

                    local InternalConfirmPopup = Create("Frame", {Parent = ManagerFrame, BackgroundColor3 = Color3.fromRGB(20, 20, 24), Size = UDim2.new(1, -20, 1, -20), Position = UDim2.new(0, 10, 0, 10), ZIndex = 60, BackgroundTransparency = 1, Visible = false})
                    Create("UICorner", {Parent = InternalConfirmPopup, CornerRadius = UDim.new(0, 8)})
                    Create("UIStroke", {Parent = InternalConfirmPopup, Color = Color3.fromRGB(180, 50, 50), Thickness = 1, Transparency = 1})
                    
                    local P_Title = Create("TextLabel", {Parent = InternalConfirmPopup, Text = "Confirm Deletion?", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.fromRGB(255, 60, 60), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 40), TextTransparency = 1, ZIndex = 61})
                    local P_Desc = Create("TextLabel", {Parent = InternalConfirmPopup, Text = "You are about to delete these specific saves loaders permanently.", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = SubTextColor, BackgroundTransparency = 1, Size = UDim2.new(1, -40, 0, 40), Position = UDim2.new(0, 20, 0, 70), TextWrapped = true, TextTransparency = 1, ZIndex = 61})
                    
                    local P_Yes = Create("TextButton", {Parent = InternalConfirmPopup, Text = "Yes", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.fromRGB(255, 255, 255), BackgroundColor3 = Color3.fromRGB(180, 50, 50), Size = UDim2.new(0.5, -30, 0, 30), Position = UDim2.new(0, 20, 0, 130), AutoButtonColor = false, BackgroundTransparency = 1, TextTransparency = 1, ZIndex = 61})
                    Create("UICorner", {Parent = P_Yes, CornerRadius = UDim.new(0, 4)})
                    AddBounce(P_Yes)
                    
                    local P_No = Create("TextButton", {Parent = InternalConfirmPopup, Text = "No", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = TextColor, BackgroundColor3 = Color3.fromRGB(45, 45, 50), Size = UDim2.new(0.5, -30, 0, 30), Position = UDim2.new(0.5, 10, 0, 130), AutoButtonColor = false, BackgroundTransparency = 1, TextTransparency = 1, ZIndex = 61})
                    Create("UICorner", {Parent = P_No, CornerRadius = UDim.new(0, 4)})
                    AddBounce(P_No)

                    local function HideInternalPopup()
                        Tween(InternalConfirmPopup, {BackgroundTransparency = 1}, 0.3)
                        Tween(InternalConfirmPopup:FindFirstChild("UIStroke"), {Transparency = 1}, 0.3)
                        Tween(P_Title, {TextTransparency = 1}, 0.3)
                        Tween(P_Desc, {TextTransparency = 1}, 0.3)
                        Tween(P_Yes, {BackgroundTransparency = 1, TextTransparency = 1}, 0.3)
                        Tween(P_No, {BackgroundTransparency = 1, TextTransparency = 1}, 0.3)
                        task.wait(0.3)
                        InternalConfirmPopup.Visible = false
                    end

                    local function RefreshMonitor()
                        for _, v in ipairs(Monitor:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end
                        selectedForDelete = {}

                        local files = _listfiles(folderName)
                        for _, filepath in ipairs(files) do
                            local rawName = filepath:match("([^/\\]+)%.json$")
                            if rawName then
                                local displayFName = rawName:gsub("_%d+%.%d+$", ""):gsub("_%d+$", "")

                                local Row = Create("Frame", {Parent = Monitor, BackgroundColor3 = BackgroundColor, Size = UDim2.new(1, 0, 0, 30)})
                                Create("UICorner", {Parent = Row, CornerRadius = UDim.new(0, 4)})
                                
                                local Title = Create("TextLabel", {Parent = Row, Text = displayFName, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TextColor, BackgroundTransparency = 1, Size = UDim2.new(1, -60, 1, 0), Position = UDim2.new(0, 10, 0, 0), TextXAlignment = Enum.TextXAlignment.Left})
                                
                                local LoadBtn = Create("TextButton", {Parent = Row, Text = "Load", Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = TextColor, BackgroundColor3 = Color3.fromRGB(45, 120, 60), Size = UDim2.new(0, 35, 0, 20), Position = UDim2.new(1, -70, 0.5, -10), AutoButtonColor = false})
                                Create("UICorner", {Parent = LoadBtn, CornerRadius = UDim.new(0, 4)})
                                AddBounce(LoadBtn)

                                local EditBtn = Create("TextButton", {Parent = Row, Text = "Edit", Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = TextColor, BackgroundColor3 = Color3.fromRGB(150, 100, 45), Size = UDim2.new(0, 30, 0, 20), Position = UDim2.new(1, -33, 0.5, -10), AutoButtonColor = false})
                                Create("UICorner", {Parent = EditBtn, CornerRadius = UDim.new(0, 4)})
                                AddBounce(EditBtn)

                                local SelectionMask = Create("TextButton", {Parent = Row, Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, -80, 1, 0), ZIndex = 2})
                                
                                SelectionMask.MouseButton1Click:Connect(function()
                                    if deleteMode then
                                        if selectedForDelete[filepath] then
                                            selectedForDelete[filepath] = nil
                                            Tween(Row, {BackgroundColor3 = BackgroundColor}, 0.2)
                                        else
                                            selectedForDelete[filepath] = true
                                            Tween(Row, {BackgroundColor3 = Color3.fromRGB(180, 50, 50)}, 0.2)
                                        end
                                    end
                                end)

                                LoadBtn.MouseButton1Click:Connect(function()
                                    if deleteMode or editMode then return end
                                    local s, data = pcall(function() return HttpService:JSONDecode(_readfile(filepath)) end)
                                    if s and type(data) == "table" then
                                        for k, v in pairs(data) do
                                            if Window.ConfigElements[k] and Window.ConfigElements[k].Set then
                                                Window.ConfigElements[k].Set(v)
                                            end
                                        end
                                        Library:Notify({Title = "Saves Loader", Description = "Successfully loaded " .. displayFName})
                                    end
                                end)

                                EditBtn.MouseButton1Click:Connect(function()
                                    if deleteMode then return end
                                    editMode = true
                                    editTargetFile = filepath
                                    NameBox.Text = displayFName
                                    CreateBtn.Visible = false
                                    DeleteTogBtn.Visible = false
                                    ActionArea.Visible = true
                                    ConfirmActionBtn.Text = "Save Edit"
                                    ConfirmActionBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 200)
                                end)
                            end
                        end
                    end

                    local function ExecuteSave(saveName)
                        local payload = {}
                        for k, el in pairs(Window.ConfigElements) do
                            if el.Get then payload[k] = el.Get() end
                        end
                        local encoded = HttpService:JSONEncode(payload)
                        local uniqueKey = tostring(math.floor(tick()))
                        local finalPath = folderName .. "/" .. saveName .. "_" .. uniqueKey .. ".json"
                        _writefile(finalPath, encoded)
                        RefreshMonitor()
                        Library:Notify({Title = "Saved Successfully", Description = "Config [" .. saveName .. "] secured."})
                    end

                    CreateBtn.MouseButton1Click:Connect(function()
                        if NameBox.Text ~= "" then ExecuteSave(NameBox.Text) end
                    end)

                    DeleteTogBtn.MouseButton1Click:Connect(function()
                        if editMode then return end
                        deleteMode = not deleteMode
                        DeleteTogBtn.Text = deleteMode and "Delete Mode: ON" or "Delete Mode: OFF"
                        Tween(DeleteTogBtn, {BackgroundColor3 = deleteMode and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(45, 45, 50)}, 0.2)
                        
                        ActionArea.Visible = deleteMode
                        CreateBtn.Visible = not deleteMode
                        if deleteMode then
                            ConfirmActionBtn.Text = "Delete Selected"
                            ConfirmActionBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                        else
                            RefreshMonitor()
                        end
                    end)

                    ConfirmActionBtn.MouseButton1Click:Connect(function()
                        if deleteMode then
                            InternalConfirmPopup.Visible = true
                            Tween(InternalConfirmPopup, {BackgroundTransparency = 0.1}, 0.3)
                            Tween(InternalConfirmPopup:FindFirstChild("UIStroke"), {Transparency = 0.5}, 0.3)
                            Tween(P_Title, {TextTransparency = 0}, 0.3)
                            Tween(P_Desc, {TextTransparency = 0}, 0.3)
                            Tween(P_Yes, {BackgroundTransparency = 0, TextTransparency = 0}, 0.3)
                            Tween(P_No, {BackgroundTransparency = 0, TextTransparency = 0}, 0.3)
                        elseif editMode then
                            local newName = NameBox.Text
                            if newName ~= "" then
                                pcall(function() _delfile(editTargetFile) end)
                                ExecuteSave(newName)
                            end
                            editMode = false
                            ActionArea.Visible = false
                            CreateBtn.Visible = true
                            DeleteTogBtn.Visible = true
                            RefreshMonitor()
                        end
                    end)

                    P_Yes.MouseButton1Click:Connect(function()
                        for file, _ in pairs(selectedForDelete) do pcall(function() _delfile(file) end) end
                        deleteMode = false
                        DeleteTogBtn.Text = "Delete Mode: OFF"
                        DeleteTogBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
                        ActionArea.Visible = false
                        CreateBtn.Visible = true
                        RefreshMonitor()
                        Library:Notify({Title = "Deletions Complete", Description = "Selected saves erased from system."})
                        HideInternalPopup()
                    end)

                    P_No.MouseButton1Click:Connect(function()
                        HideInternalPopup()
                    end)

                    CancelActionBtn.MouseButton1Click:Connect(function()
                        editMode = false
                        deleteMode = false
                        DeleteTogBtn.Text = "Delete Mode: OFF"
                        DeleteTogBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
                        ActionArea.Visible = false
                        CreateBtn.Visible = true
                        DeleteTogBtn.Visible = true
                        NameBox.Text = ""
                        RefreshMonitor()
                    end)

                    ManagerSearch:GetPropertyChangedSignal("Text"):Connect(function()
                        local q = ManagerSearch.Text:lower()
                        for _, v in ipairs(Monitor:GetChildren()) do
                            if v:IsA("Frame") then
                                local lbl = v:FindFirstChildOfClass("TextLabel")
                                if lbl then v.Visible = (q == "" or string.find(lbl.Text:lower(), q) ~= nil) end
                            end
                        end
                    end)

                    RefreshMonitor()
                end

                return Elements
            end
            return PageObj
        end

        if isDefault then
            TabBtn.BackgroundTransparency = 0
            Indicator.Size = UDim2.new(0, 3, 0, 18)
            Txt.TextColor3 = TextColor
            TabContent.Visible = true
            Window.CurrentTab = TabConfig
        end
        return TabConfig
    end
    return Window
end

return Library
