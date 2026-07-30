--// ====================================================
--// STAFF PANEL + STAFF NOTIFIER + ANTI-AIMVIEW SCRIPT
--// ====================================================

--// SERVICES
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--// CONFIGURATION
local GROUPS = {
	{ Id = 996191638, Tag = "🛡️" }, -- Void Falls Staff Team
	{ Id = 224003059, Tag = "⭐" },  -- VFS Stars
	{ 
		Id = 35612235,                -- VoidFalls HOF
		Roles = {
			["star player"]   = "⭐",
			["crew leader"]   = "⭐",
			["star creator"]  = "⭐",
			["star legend"]   = "🌟",
			["manager/admin"] = "🛡️🛡️",
			["manager"]       = "🛡️🛡️",
			["admin"]         = "🛡️🛡️"
		}
	}
}

local STAFF_GROUP_ID = 996191638

local STAFF_USERIDS = {
	6203233210, 555909464, 350124454, 5637396, 3130721894, 
	893987861, 461435528, 3860151481, 10418656725, 10406715512, 
	1094365126, 5627602266, 1464049899, 1617828795, 1649686630, 
	2462748038, 167515541, 1955732479, 35301832, 133676773, 59122242
}

--// SELECTED STATE & TOGGLES
local SelectedPlayer = nil
local SpectatingPlayer = nil
local GlobalEspEnabled = false

-- Cache for Group Memberships & Scraped Tags
local groupCache = {}
local dynamicTagCache = {}
local UpdatePlayerList

--// ----------------------------------------------------
--// HELPER FUNCTIONS (NOTIFICATIONS & STAFF)
--// ----------------------------------------------------
local function getHead(userId)
	local success, image = pcall(function()
		return Players:GetUserThumbnailAsync(
			userId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size420x420
		)
	end)

	return success and image or "rbxassetid://15059364356"
end

local function notify(title, message, icon)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title,
			Text = message,
			Icon = icon or "rbxassetid://15059364356",
			Duration = 8
		})
	end)
end

local function ProcessPlayerGroupData(plr)
	if groupCache[plr.UserId] then
		return groupCache[plr.UserId]
	end

	groupCache[plr.UserId] = { Tags = "", IsStaff = table.find(STAFF_USERIDS, plr.UserId) ~= nil }

	task.spawn(function()
		local tags = ""
		local isStaffMember = table.find(STAFF_USERIDS, plr.UserId) ~= nil

		for _, groupInfo in ipairs(GROUPS) do
			if groupInfo.Roles then
				local success, role = pcall(function()
					return plr:GetRoleInGroup(groupInfo.Id)
				end)

				if success and role and role ~= "Guest" and role ~= "Normal Players" then
					local cleanRole = role:lower()
					for targetRole, tagEmoji in pairs(groupInfo.Roles) do
						if cleanRole:find(targetRole, 1, true) then
							tags = tags .. tagEmoji .. " "
							break
						end
					end
				end
			elseif groupInfo.Tag then
				local success, inGroup = pcall(function()
					return plr:IsInGroup(groupInfo.Id)
				end)
				if success and inGroup then
					tags = tags .. groupInfo.Tag .. " "
					if groupInfo.Id == STAFF_GROUP_ID then
						isStaffMember = true
					end
				end
			end
		end

		groupCache[plr.UserId] = {
			Tags = tags,
			IsStaff = isStaffMember
		}

		if UpdatePlayerList then
			UpdatePlayerList()
		end
	end)

	return groupCache[plr.UserId]
end

local function isStaff(player)
	local data = ProcessPlayerGroupData(player)
	return data.IsStaff
end

-- ULTIMATE TAG PARSER (Scans Character/Head for UI text, BillboardGuis, and tags)
local function GetCharacterOverheadTags(plr)
	local data = ProcessPlayerGroupData(plr)
	local tags = data.Tags or ""
	
	-- 1. Check Dynamic Cache from Background Scanner
	if dynamicTagCache[plr.Name] then
		for _, cachedTag in ipairs(dynamicTagCache[plr.Name]) do
			if not tags:find(cachedTag, 1, true) then
				tags = tags .. cachedTag .. " "
			end
		end
	end
	
	-- 2. Real-time direct inspection of the player's character and head for chat tags / overhead tags
	if plr and plr.Character then
		for _, descendant in ipairs(plr.Character:GetDescendants()) do
			if descendant:IsA("TextLabel") or descendant:IsA("TextBox") then
				local txt = descendant.Text
				if txt and txt ~= "" then
					-- Look for bracket tags like [LOST], [BOPS], [jugg], etc., that aren't just the player's name
					for bracket in txt:gmatch("%b[]") do
						local lowerB = bracket:lower()
						if bracket ~= "[ ]" and not lowerB:find(plr.Name:lower()) and not lowerB:find(plr.DisplayName:lower()) then
							if not tags:find(bracket, 1, true) then
								tags = tags .. bracket .. " "
							end
						end
					end
				end
			end
		end
	end
	
	return tags
end

-- Comprehensive Continuous Background Scanner
task.spawn(function()
	while task.wait(0.2) do
		pcall(function()
			local roots = { Workspace, LocalPlayer:FindFirstChild("PlayerGui") }
			for _, root in ipairs(roots) do
				if root then
					for _, obj in ipairs(root:GetDescendants()) do
						if obj:IsA("TextLabel") or obj:IsA("TextBox") then
							local txt = obj.Text
							if txt and txt ~= "" then
								for _, plr in ipairs(Players:GetPlayers()) do
									if txt:find(plr.Name, 1, true) or txt:find(plr.DisplayName, 1, true) then
										for bracket in txt:gmatch("%b[]") do
											local lowerB = bracket:lower()
											if bracket ~= "[ ]" and not lowerB:find(plr.Name:lower()) and not lowerB:find(plr.DisplayName:lower()) then
												dynamicTagCache[plr.Name] = dynamicTagCache[plr.Name] or {}
												local exists = false
												for _, existing in ipairs(dynamicTagCache[plr.Name]) do
													if existing == bracket then exists = true break end
												end
												if not exists then
													table.insert(dynamicTagCache[plr.Name], bracket)
													if UpdatePlayerList then UpdatePlayerList() end
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end)
	end
end)

--// ----------------------------------------------------
--// CREATE MAIN GUI PANEL
--// ----------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "StaffPanelGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Panel Frame
local Panel = Instance.new("Frame")
Panel.Name = "StaffPanel"
Panel.Size = UDim2.new(0, 310, 0, 260)
Panel.Position = UDim2.new(0, 10, 1, -310)
Panel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Panel.BackgroundTransparency = 0.15
Panel.BorderSizePixel = 1
Panel.BorderColor3 = Color3.fromRGB(40, 40, 40)
Panel.Visible = true
Panel.Parent = ScreenGui

-- Header Title
local Header = Instance.new("TextLabel")
Header.Size = UDim2.new(1, 0, 0, 25)
Header.Position = UDim2.new(0, 0, 0, 0)
Header.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
Header.BackgroundTransparency = 0.5
Header.Text = "  Yens Panel ⭐"
Header.TextColor3 = Color3.fromRGB(220, 220, 220)
Header.TextSize = 13
Header.Font = Enum.Font.SourceSansBold
Header.TextXAlignment = Enum.TextXAlignment.Left
Header.Parent = Panel

-- Search Box
local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(0, 100, 0, 20)
SearchBox.Position = UDim2.new(1, -105, 0, 2.5)
SearchBox.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
SearchBox.BackgroundTransparency = 0.5
SearchBox.BorderColor3 = Color3.fromRGB(60, 60, 60)
SearchBox.PlaceholderText = "search"
SearchBox.Text = ""
SearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SearchBox.TextSize = 12
SearchBox.Font = Enum.Font.SourceSans
SearchBox.Parent = Panel

-- Player Scroll List Frame
local PlayerList = Instance.new("ScrollingFrame")
PlayerList.Size = UDim2.new(0, 195, 0, 225)
PlayerList.Position = UDim2.new(0, 5, 0, 30)
PlayerList.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
PlayerList.BackgroundTransparency = 0.3
PlayerList.BorderSizePixel = 1
PlayerList.BorderColor3 = Color3.fromRGB(35, 35, 35)
PlayerList.ScrollBarThickness = 4
PlayerList.CanvasSize = UDim2.new(0, 0, 0, 0)
PlayerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
PlayerList.Visible = true
PlayerList.Parent = Panel

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 2)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Parent = PlayerList

-- Colors Tab Frame
local ColorsFrame = Instance.new("Frame")
ColorsFrame.Name = "ColorsFrame"
ColorsFrame.Size = UDim2.new(0, 195, 0, 225)
ColorsFrame.Position = UDim2.new(0, 5, 0, 30)
ColorsFrame.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
ColorsFrame.BackgroundTransparency = 0.3
ColorsFrame.BorderSizePixel = 1
ColorsFrame.BorderColor3 = Color3.fromRGB(35, 35, 35)
ColorsFrame.Visible = false
ColorsFrame.Parent = Panel

local ColorsLayout = Instance.new("UIListLayout")
ColorsLayout.Padding = UDim.new(0, 4)
ColorsLayout.SortOrder = Enum.SortOrder.LayoutOrder
ColorsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ColorsLayout.Parent = ColorsFrame

local function CreateColorOption(name, bgColor, transparency)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.9, 0, 0, 32)
	btn.BackgroundColor3 = bgColor
	btn.BackgroundTransparency = transparency or 0.2
	btn.BorderColor3 = Color3.fromRGB(60, 60, 60)
	btn.Text = name
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 13
	btn.Font = Enum.Font.SourceSansBold
	btn.Parent = ColorsFrame
	
	btn.MouseButton1Click:Connect(function()
		Panel.BackgroundColor3 = bgColor
		Panel.BackgroundTransparency = transparency or 0.15
	end)
	return btn
end

CreateColorOption("Transparent", Color3.fromRGB(0, 0, 0), 0.85)
CreateColorOption("Red", Color3.fromRGB(60, 15, 15), 0.15)
CreateColorOption("Blue", Color3.fromRGB(15, 25, 60), 0.15)
CreateColorOption("Black", Color3.fromRGB(10, 10, 10), 0.05)

-- Right Action Buttons Panel
local ActionFrame = Instance.new("Frame")
ActionFrame.Size = UDim2.new(0, 100, 0, 225)
ActionFrame.Position = UDim2.new(1, -105, 0, 30)
ActionFrame.BackgroundTransparency = 1
ActionFrame.Parent = Panel

local ActionLayout = Instance.new("UIListLayout")
ActionLayout.Padding = UDim.new(0, 4)
ActionLayout.SortOrder = Enum.SortOrder.LayoutOrder
ActionLayout.Parent = ActionFrame

local function CreateActionButton(text)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 28)
	btn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	btn.BorderColor3 = Color3.fromRGB(70, 70, 70)
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(0, 255, 100)
	btn.TextSize = 14
	btn.Font = Enum.Font.SourceSans
	btn.Parent = ActionFrame
	return btn
end

local SpectateBtn = CreateActionButton("Spectate")
local TPBtn = CreateActionButton("TP")
local ToggleTagBtn = CreateActionButton("Toggle Tag")
ToggleTagBtn.TextColor3 = Color3.fromRGB(220, 220, 220)

local RejoinBtn = CreateActionButton("Rejoin")
RejoinBtn.TextColor3 = Color3.fromRGB(255, 170, 0)

local ColorsTabBtn = CreateActionButton("Colors")
ColorsTabBtn.TextColor3 = Color3.fromRGB(180, 180, 255)

local EspBtn = CreateActionButton("ESP")
EspBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
EspBtn.Visible = false

-- Rejoin Logic
RejoinBtn.MouseButton1Click:Connect(function()
	if #Players:GetPlayers() <= 1 then
		TeleportService:Teleport(game.PlaceId, LocalPlayer)
	else
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
	end
end)

-- Colors Navigation Logic
ColorsTabBtn.MouseButton1Click:Connect(function()
	local open = not ColorsFrame.Visible
	ColorsFrame.Visible = open
	PlayerList.Visible = not open
	ColorsTabBtn.TextColor3 = open and Color3.fromRGB(255, 255, 0) or Color3.fromRGB(180, 180, 255)
end)

-- Bottom Bar Toggle Button
local BottomBarToggleBtn = Instance.new("ImageButton")
BottomBarToggleBtn.Name = "StaffPanelToggleBtn"
BottomBarToggleBtn.Size = UDim2.new(0, 28, 0, 28)
BottomBarToggleBtn.AnchorPoint = Vector2.new(0, 0.5)
BottomBarToggleBtn.Position = UDim2.new(0, 185, 1, -25)
BottomBarToggleBtn.BackgroundTransparency = 1
BottomBarToggleBtn.Image = "rbxassetid://10734950309"
BottomBarToggleBtn.ImageColor3 = Color3.fromRGB(0, 255, 100)
BottomBarToggleBtn.Parent = ScreenGui

BottomBarToggleBtn.MouseButton1Click:Connect(function()
	Panel.Visible = not Panel.Visible
	BottomBarToggleBtn.ImageColor3 = Panel.Visible and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 255, 255)
end)

-- Complete Cleanup Helper for All ESP Tags/Highlights across the server
local function RemoveESPFromPlayer(plr)
	if plr and plr.Character then
		local head = plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart")
		if head then
			for _, tag in ipairs(head:GetChildren()) do
				if tag.Name == "YenRedNameTag" then tag:Destroy() end
			end
		end
		for _, hl in ipairs(plr.Character:GetChildren()) do
			if hl.Name == "YenHighlight" then hl:Destroy() end
		end
	end
end

local function RemoveESPFromEveryone()
	for _, plr in ipairs(Players:GetPlayers()) do
		RemoveESPFromPlayer(plr)
	end
end

-- Deselect Player and Force Clean ESP when Clicking Outside
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if SelectedPlayer and Panel.Visible then
			local mousePos = UserInputService:GetMouseLocation() - Vector2.new(0, 36)
			local panelPos = Panel.AbsolutePosition
			local panelSize = Panel.AbsoluteSize

			local isInsidePanel = (mousePos.X >= panelPos.X and mousePos.X <= panelPos.X + panelSize.X) and
			                      (mousePos.Y >= panelPos.Y and mousePos.Y <= panelPos.Y + panelSize.Y)
			
			local btnPos = BottomBarToggleBtn.AbsolutePosition
			local btnSize = BottomBarToggleBtn.AbsoluteSize
			local isInsideToggleBtn = (mousePos.X >= btnPos.X and mousePos.X <= btnPos.X + btnSize.X) and
			                          (mousePos.Y >= btnPos.Y and mousePos.Y <= btnPos.Y + btnSize.Y)

			if not isInsidePanel and not isInsideToggleBtn then
				if SelectedPlayer then
					RemoveESPFromPlayer(SelectedPlayer)
				end
				SelectedPlayer = nil
				EspBtn.Visible = false
				if UpdatePlayerList then UpdatePlayerList() end
			end
		end
	end
end)

-- Draggable UI Logic
local dragging, dragInput, dragStart, startPos

Header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = Panel.Position

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

Header.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging then
		local delta = input.Position - dragStart
		Panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

-- Teleport Logic
local function TeleportToPlayer(targetPlr)
	if not targetPlr or targetPlr == LocalPlayer then return end
	local myChar = LocalPlayer.Character
	local targetChar = targetPlr.Character
	
	if myChar and targetChar then
		local myRoot = myChar:FindFirstChild("HumanoidRootPart")
		local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
		if myRoot and targetRoot then
			myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
		end
	end
end

--// ----------------------------------------------------
--// INDIVIDUAL & GLOBAL ESP LOGIC (NAMES ONLY, NO HIGHLIGHTS, NO NOTIFICATIONS)
--// ----------------------------------------------------
local function CreateInGameTag(plr)
	if not plr or plr == LocalPlayer then return end
	
	task.spawn(function()
		local char = plr.Character
		local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
		
		local attempts = 0
		while (not char or not head or not char:FindFirstChild("Humanoid")) and attempts < 10 do
			task.wait(0.2)
			char = plr.Character
			head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
			attempts += 1
		end
		
		if not char or not head then return end

		for _, tag in ipairs(head:GetChildren()) do
			if tag.Name == "YenRedNameTag" then tag:Destroy() end
		end

		local bb = Instance.new("BillboardGui")
		bb.Name = "YenRedNameTag"
		bb.Adornee = head
		bb.Size = UDim2.new(0, 300, 0, 50)
		bb.StudsOffset = Vector3.new(0, 2.5, 0)
		bb.AlwaysOnTop = true
		bb.Parent = head

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		
		local fullTags = GetCharacterOverheadTags(plr)
		local prefix = (fullTags ~= "") and (fullTags .. " ") or ""
		
		label.Text = prefix .. plr.DisplayName .. " (@" .. plr.Name .. ")"
		label.TextColor3 = Color3.fromRGB(255, 0, 0)
		label.TextScaled = false
		label.TextSize = 14
		label.Font = Enum.Font.SourceSansBold
		label.TextStrokeTransparency = 0.2
		label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		label.Parent = bb
	end)
end

local function ApplyESPToPlayer(plr)
	if not plr or plr == LocalPlayer then return end
	CreateInGameTag(plr)
end

local function TogglePlayerESP(plr)
	if not plr then return end
	
	local char = plr.Character
	local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
	local hasTag = head and head:FindFirstChild("YenRedNameTag") ~= nil
	
	if hasTag then
		RemoveESPFromPlayer(plr)
	else
		ApplyESPToPlayer(plr)
	end
end

local function IsPlayerEspActive(plr)
	if not plr or not plr.Character then return false end
	local head = plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart")
	return head and head:FindFirstChild("YenRedNameTag") ~= nil
end

EspBtn.MouseButton1Click:Connect(function()
	if SelectedPlayer then
		TogglePlayerESP(SelectedPlayer)
		task.delay(0.1, function()
			if SelectedPlayer then
				EspBtn.TextColor3 = IsPlayerEspActive(SelectedPlayer) and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 100, 100)
			end
		end)
	end
end)

--// ----------------------------------------------------
--// KEYBIND LISTENER (PRESS Q TO ESP EVERYONE - NAMES ONLY, NO NOTIFICATIONS)
--// ----------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.Q then
		GlobalEspEnabled = not GlobalEspEnabled
		
		if GlobalEspEnabled then
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LocalPlayer then
					ApplyESPToPlayer(plr)
				end
			end
		else
			RemoveESPFromEveryone()
		end
	end
end)

-- Automatically apply ESP to newly joining players if Global ESP is active
Players.PlayerAdded:Connect(function(plr)
	if GlobalEspEnabled then
		task.delay(1, function()
			if GlobalEspEnabled and plr ~= LocalPlayer then
				ApplyESPToPlayer(plr)
			end
		end)
	end
end)

--// ----------------------------------------------------
--// PANEL LIST LOGIC
--// ----------------------------------------------------
UpdatePlayerList = function()
	local currentScrollPosition = PlayerList.CanvasPosition

	for _, item in ipairs(PlayerList:GetChildren()) do
		if item:IsA("Frame") then item:Destroy() end
	end
	
	local filter = SearchBox.Text:lower()
	
	for _, plr in ipairs(Players:GetPlayers()) do
		local dispName = plr.DisplayName
		local userName = plr.Name
		
		if filter ~= "" and not userName:lower():find(filter, 1, true) and not dispName:lower():find(filter, 1, true) then
			continue
		end
		
		local Row = Instance.new("Frame")
		Row.Size = UDim2.new(1, 0, 0, 32)
		Row.BackgroundColor3 = (SelectedPlayer == plr) and Color3.fromRGB(20, 50, 20) or Color3.fromRGB(12, 12, 12)
		Row.BackgroundTransparency = 0.2
		Row.BorderSizePixel = 0
		Row.Parent = PlayerList
		
		local AvatarImg = Instance.new("ImageLabel")
		AvatarImg.Size = UDim2.new(0, 26, 0, 26)
		AvatarImg.Position = UDim2.new(0, 3, 0.5, -13)
		AvatarImg.BackgroundTransparency = 1
		AvatarImg.Image = "rbxassetid://15059364356"
		AvatarImg.Parent = Row
		
		task.spawn(function()
			local success, img = pcall(function()
				return Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
			end)
			if success and img then
				AvatarImg.Image = img
			end
		end)
		
		local NameLabel = Instance.new("TextLabel")
		NameLabel.Size = UDim2.new(1, -35, 1, 0)
		NameLabel.Position = UDim2.new(0, 32, 0, 0)
		NameLabel.BackgroundTransparency = 1
		
		local isSelf = (plr == LocalPlayer) and " (YOU)" or ""
		local overheadPrefix = GetCharacterOverheadTags(plr)
		local rawText = overheadPrefix .. dispName .. isSelf
		
		NameLabel.Text = rawText
		NameLabel.TextColor3 = (SelectedPlayer == plr) and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(200, 200, 200)
		NameLabel.TextSize = 13
		NameLabel.Font = Enum.Font.SourceSans
		NameLabel.TextXAlignment = Enum.TextXAlignment.Left
		NameLabel.Parent = Row
		
		local ClickBtn = Instance.new("TextButton")
		ClickBtn.Size = UDim2.new(1, 0, 1, 0)
		ClickBtn.BackgroundTransparency = 1
		ClickBtn.Text = ""
		ClickBtn.Parent = Row
		
		ClickBtn.MouseButton1Click:Connect(function()
			if SelectedPlayer and SelectedPlayer ~= plr then
				RemoveESPFromPlayer(SelectedPlayer)
			end
			
			SelectedPlayer = (SelectedPlayer == plr) and nil or plr
			
			EspBtn.Visible = (SelectedPlayer ~= nil)
			if SelectedPlayer then
				EspBtn.TextColor3 = IsPlayerEspActive(SelectedPlayer) and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 100, 100)
			end
			
			UpdatePlayerList()
		end)
	end

	task.defer(function()
		PlayerList.CanvasPosition = currentScrollPosition
	end)
end

-- Copy Tag Logic
ToggleTagBtn.MouseButton1Click:Connect(function()
	if not SelectedPlayer then return end
	
	local overheadPrefix = GetCharacterOverheadTags(SelectedPlayer)
	local tagString = overheadPrefix .. SelectedPlayer.DisplayName .. " (@" .. SelectedPlayer.Name .. ")"
	
	if setclipboard then
		setclipboard(tagString)
	else
		print("Tag Copied to Log:", tagString)
	end
	
	ToggleTagBtn.Text = "Copied!"
	ToggleTagBtn.TextColor3 = Color3.fromRGB(255, 255, 0)
	
	tagString = overheadPrefix .. SelectedPlayer.DisplayName .. " (@" .. SelectedPlayer.Name .. ")"
	
	task.delay(1.5, function()
		ToggleTagBtn.Text = "Toggle Tag"
		ToggleTagBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
	end)
end)

TPBtn.MouseButton1Click:Connect(function()
	if not SelectedPlayer then return end
	TeleportToPlayer(SelectedPlayer)
end)

SpectateBtn.MouseButton1Click:Connect(function()
	if not SelectedPlayer or not SelectedPlayer.Character then return end
	
	if SpectatingPlayer == SelectedPlayer then
		Camera.CameraSubject = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		SpectatingPlayer = nil
		SpectateBtn.TextColor3 = Color3.fromRGB(0, 255, 100)
	else
		local hum = SelectedPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			Camera.CameraSubject = hum
			SpectatingPlayer = SelectedPlayer
			SpectateBtn.TextColor3 = Color3.fromRGB(255, 200, 0)
		end
	end
end)

SearchBox:GetPropertyChangedSignal("Text"):Connect(UpdatePlayerList)

-- Continuous loop to refresh tags live as they load in-game
task.spawn(function()
	while task.wait(1) do
		if UpdatePlayerList and Panel.Visible then
			UpdatePlayerList()
		end
	end
end)

--// ----------------------------------------------------
--// STAFF JOIN / LEAVE NOTIFIER LOGIC
--// ----------------------------------------------------
local function CheckAndNotifyStaff(player, isJoin)
	task.spawn(function()
		if isStaff(player) then
			local actionText = isJoin and "joined the server" or "left the server"
			notify(player.DisplayName, player.Name .. " " .. actionText, getHead(player.UserId))
		end
		UpdatePlayerList()
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	CheckAndNotifyStaff(player, true)
end

Players.PlayerAdded:Connect(function(player)
	CheckAndNotifyStaff(player, true)
end)

Players.PlayerRemoving:Connect(joinOrLeavePlayer)
Players.PlayerRemoving:Connect(function(player)
	CheckAndNotifyStaff(player, false)
	groupCache[player.UserId] = nil
	if SelectedPlayer == player then 
		RemoveESPFromPlayer(player)
		SelectedPlayer = nil 
		EspBtn.Visible = false
	end
	if SpectatingPlayer == player then
		Camera.CameraSubject = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		SpectatingPlayer = nil
		SpectateBtn.TextColor3 = Color3.fromRGB(0, 255, 100)
	end
	UpdatePlayerList()
end)

UpdatePlayerList()

--// ----------------------------------------------------
--// ANTI-AIMVIEW DETECTOR LOGIC
--// ----------------------------------------------------
local function isAimViewInstance(child)
	if child:IsA("Beam") or child:IsA("LineHandleAdornment") or child.Name:find("Aim") or child.Name:find("Viewer") then
		return true
	end
	return false
end

local function monitorCharacter(char)
	if not char then return end

	for _, child in ipairs(char:GetDescendants()) do
		if isAimViewInstance(child) then
			notify("⚠️ WARNING", "you are being aimviewed", getHead(LocalPlayer.UserId))
			break
		end
	end

	char.DescendantAdded:Connect(function(child)
		if isAimViewInstance(child) then
			notify("⚠️ WARNING", "you are being aimviewed", getHead(LocalPlayer.UserId))
		end
	end)
end

if LocalPlayer.Character then
	monitorCharacter(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(monitorCharacter)

print("@hi im yen")
