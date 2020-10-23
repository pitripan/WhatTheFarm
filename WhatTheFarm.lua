WTFAddon = LibStub("AceAddon-3.0"):NewAddon("WhatTheFarm", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("WhatTheFarm")
local LDB = LibStub("LibDataBroker-1.1"):NewDataObject("WhatTheFarm", {
  type = "data source",
  text = L["WTF_MMBTooltipTitle"],
  icon = "Interface\\Icons\\INV_Misc_Note_03",
  OnTooltipShow = function(tooltip)
    tooltip:SetText(L["WTF_MMBTooltipTitle"])
    tooltip:AddLine(L["WTF_MMBTooltipInfo"], 1, 1, 1)
    tooltip:Show()
  end,
  OnClick = function(self, button)
    if button == "LeftButton" then
      WTFAddon:ToggleMainFrame()
    elseif button == "RightButton" then
      WTFAddon:ShowOptionsFrame()
    end
  end})
local WTFMiniMapButton = LibStub("LibDBIcon-1.0")
--
local _Colors = WTFAddon_GetColors()
local _defaultConfig = WTFAddon_GetDefaultConfig()



--[[
ToDo-List:
  - settings / optionen implementieren -> vorbereitet
  - /help command für Ausgabe der möglichen Befehle implementieren
  - show latest sessions info (or even after stopping session)

ToCome / Ideos List:
  - show statistic (farmed per hour, etc.)
  - save data of last x sessions
  - implement ignore list
  - frame to manage ignore list
  - track gold looted
  - show tooltip for each item on mouseover
  - grouping for reagents
]]



--------------------------------------------------
-- Variable definitions
--------------------------------------------------
local _OffsetY = 0
local _OffsetY_Default = 0
local _OffsetY_Step = 18
local _IconSize = 16
local _LineHeight = 16
local _Ticker = nil
local _ContinuedSession = false
local _SessionStart = 0
local _SessionStop = 0


--------------------------------------------------
-- Utility Functions
--------------------------------------------------
function panRemoveFromArray(array, removeMe)
  local j, n = 1, #array

  for i = 1, n do
    if (array[i] == removeMe) then
      array[i] = nil
    else
      -- Move i's kept value to j's position, if it's not already there.
      if (i ~= j) then
        array[j] = array[i]
        array[i] = nil
      end
      j = j + 1 -- Increment position of where we'll place the next kept value.
    end
  end

  return t
end

function panShowArray(array)
  for i = 1, #array do
    print('total:'..#array , 'i:'..i, 'v:'..array[i]);
  end
end

function panTableContains(table, item)
  local index = 1
  while table[index] do
    if item == table[index] then
      return true
    end
    index = index + 1
  end
  return false
end

function panGetPartiallyColoredString(text, coloredText, color)
	local colorString = ""
	colorString = "\124cff" .. color .. coloredText .. "\124r"
	return string.format(text, colorString)
end

function panGetQualityNumber(quality)
  if quality == "poor" then
    return 0
  elseif quality == "common" then
    return 1
  elseif quality == "uncommon" then
    return 2
  elseif quality == "rare" then
    return 3
  elseif quality == "epic" then
    return 4
  elseif quality == "legendary" then
    return 5
  elseif quality == "artifact" then
    return 6
  elseif quality == "heirloom" then
    return 7
  elseif quality == "wow_token" then
    return 8
  end
end

function panGetQualityName(quality)
  if quality == 0 then
    return "poor"
  elseif quality == 1 then
    return "common"
  elseif quality == 2 then
    return "uncommon"
  elseif quality == 3 then
    return "rare"
  elseif quality == 4 then
    return "epic"
  elseif quality == 5 then
    return "legendary"
  elseif quality == 6 then
    return "artifact"
  elseif quality == 7 then
    return "heirloom"
  elseif quality == 8 then
    return "wow_token"
  end
end

--------------------------------------------------
-- General Functions
--------------------------------------------------
local function addNewLine(position)
  local scrollFrameWidth = WTFAddon.farmListFrame.scrollFrame:GetWidth()

  -- Texture: item icon
  local wtfNewItemIcon = WTFAddon.farmListFrame.scrollFrame:CreateTexture("WTFItemIcon_"..position, "ARTWORK")
  wtfNewItemIcon:SetPoint("TOPLEFT", WTFAddon.farmListFrame.scrollFrame, "TOPLEFT", 0, _OffsetY)
  wtfNewItemIcon:SetWidth(_IconSize)
  wtfNewItemIcon:SetHeight(_IconSize)
  wtfNewItemIcon:Hide()

  -- Button: item name
  local fontForName = CreateFont("fontForName")
  fontForName:SetTextColor(1, 1, 1, 1)

  local wtfNewItemName = CreateFrame("Button", "WTFItemName_"..position, WTFAddon.farmListFrame.scrollFrame, "WTF_TransparentButtonTemplate")
  wtfNewItemName:SetPoint("LEFT", wtfNewItemIcon, 24, 0)
  wtfNewItemName:SetText("")
  wtfNewItemName:SetSize(scrollFrameWidth - 80, _LineHeight)
  wtfNewItemName:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText(self:GetText())
    --PTHTODO: Tooltip erweitern?
    GameTooltip:Show()
  end)
  wtfNewItemName:SetNormalFontObject(fontForName)
  wtfNewItemName:SetHighlightFontObject(fontForName)
  wtfNewItemName:GetFontString():SetPoint("LEFT")
  wtfNewItemName:Hide()

  -- FontString: item count
  local wtfNewItemCount = WTFAddon.farmListFrame.scrollFrame:CreateFontString("WTFItemCount_"..position, "OVERLAY", "WhatTheFarm_DisplayListFont")
  wtfNewItemCount:SetPoint("RIGHT", wtfNewItemIcon, scrollFrameWidth - 40, 0)
  wtfNewItemCount:SetText("")
  wtfNewItemCount:SetTextColor(1, 1, 1, 1)
  wtfNewItemCount:Hide()

  -- Button: ignore item
  local wtfNewItemIgnore = CreateFrame("Button", "WTFItemIgnore_"..position, WTFAddon.farmListFrame.scrollFrame, "WTF_ItemIgnoreButtonTemplate")
  wtfNewItemIgnore:SetPoint("RIGHT", wtfNewItemIcon, scrollFrameWidth - _IconSize, 0)
  wtfNewItemIgnore:SetSize(_IconSize, _IconSize)
  wtfNewItemIgnore:Hide()

  -- set new vertical offset
  _OffsetY = _OffsetY - _OffsetY_Step
end

local function updateSessionTime(isStopped, init)
  -- default parameter
  if isStopped ~= true then
    isStopped = false
  end
  if init ~= true then
    init = false
  end

  local diff = 0
  if isStopped == true then
    diff = _SessionStop - _SessionStart
  elseif init == true then
    diff = WTFAddon.db.profile.session.timeDiff
  else
    diff = GetServerTime() - _SessionStart
  end

  if _ContinuedSession == true then
    diff = WTFAddon.db.profile.session.timeDiff + diff
  end

  local hours = math.floor(diff / 3600)
  diff = diff - (hours * 3600)
  local minutes = math.floor(diff / 60)
  diff = diff - (minutes * 60)
  local seconds = diff

  WhatTheFarm_SessionTime:SetText(string.format("[%02d:%02d:%02d]", hours, minutes, seconds))
end

local function startSession(isNewSession)
  if isNewSession ~= false then
    isNewSession = true
  end

  -- set SavedVariables
  if isNewSession == true then
    _ContinuedSession = false
  else
    _ContinuedSession = true
  end

  WTFAddon.db.profile.session.isStarted = true
  _SessionStart = GetServerTime()

  -- register event & start tracking if looting
  WhatTheFarm:RegisterEvent("LOOT_OPENED")
  WhatTheFarm:RegisterEvent("PLAYER_MONEY")

  -- set ticker
  _Ticker = C_Timer.NewTicker(1, updateSessionTime)

  -- toggle button visibility
  WhatTheFarm_StartSession:Hide()
  WhatTheFarm_StopSession:Show()
  -- toggle button status
  WhatTheFarm_ResetSession:Disable()
  -- toggle time visibility
  --WhatTheFarm_SessionTime:Show()

  -- print to chat
  if isNewSession == true then
    WTFAddon:PrintColored(L["WTF_SessionStart"], _Colors.green.seagreen)
  else
    WTFAddon:PrintColored(L["WTF_SessionStart_Continue"], _Colors.orange.orange)
  end
end

local function stopSession(isReset)
  -- default parameter
  if isReset ~= true then
    isReset = false
  end

  -- set SavedVariables
  WTFAddon.db.profile.session.isStarted = false

  if isReset == false then
    _SessionStop = GetServerTime()
  end

  -- unregister event & stop tracking
  WhatTheFarm:UnregisterEvent("LOOT_OPENED")
  WhatTheFarm:UnregisterEvent("PLAYER_MONEY")

  if _Ticker ~= nil then
    -- cancel ticker
    _Ticker:Cancel()

    -- update ticker display
    updateSessionTime(true)
  end

  WTFAddon.db.profile.session.timeDiff = WTFAddon.db.profile.session.timeDiff + (_SessionStop - _SessionStart)

  -- toggle button visibility
  WhatTheFarm_StopSession:Hide()
  WhatTheFarm_StartSession:Show()
  -- toggle button status
  WhatTheFarm_ResetSession:Enable()
  -- toggle time visibility
  --WhatTheFarm_SessionTime:Hide()

  -- print to chat
  WTFAddon:PrintColored(L["WTF_SessionStop"], _Colors.red.crimson)
end

local function resetSession()
  _ContinuedSession = false
  _SessionStart = 0
  _SessionStop = 0

  -- stop current session
  stopSession(true)

  -- reset all SavedVariables
  WTFAddon.db.profile.session.isStarted = false
  WTFAddon.db.profile.session.timeDiff = 0
  WTFAddon.db.profile.session.totalLinesCount = 0
  -- money
  WTFAddon.db.profile.session.lastMoney = 0
  WTFAddon.db.profile.session.madeProfit = false
  -- lists
  WTFAddon.db.profile.session.lines = {}
  WTFAddon.db.profile.session.linesInfo = {}

  -- update display
  WhatTheFarm_ScrollFrame_Update(WTFAddon.farmListFrame.scrollFrame)

  -- print to chat
  WTFAddon:PrintColored(L["WTF_SessionReset"], _Colors.red.indianred)
end

local function sortItemsByName(self, button)
	local helperTable = {}
  local linesSorted = {}

  for i = 1, #WTFAddon.db.profile.session.lines do
    itemId = WTFAddon.db.profile.session.lines[i]

    table.insert(helperTable, {
      itemId = itemId,
      itemName = WTFAddon.db.profile.session.linesInfo[itemId].itemName,
      itemCount = WTFAddon.db.profile.session.linesInfo[itemId].itemCount
    })
	end

  if button == "LeftButton" then
  	table.sort(helperTable, function(a, b)
      return a.itemName < b.itemName
    end)
  elseif button == "RightButton" then
    table.sort(helperTable, function(a, b)
      return a.itemName > b.itemName
    end)
  end

  -- fill sorted array
  for i = 1, #helperTable do
      linesSorted[i] = helperTable[i].itemId
  end

  -- replace old array with sorted array
  WTFAddon.db.profile.session.lines = linesSorted

  -- refresh UI list
  WhatTheFarm_ScrollFrame_Update(WTFAddon.farmListFrame.scrollFrame)
end

local function sortItemsByCount(self, button)
	local helperTable = {}
  local linesSorted = {}

  for i = 1, #WTFAddon.db.profile.session.lines do
    itemId = WTFAddon.db.profile.session.lines[i]

    table.insert(helperTable, {
      itemId = itemId,
      itemName = WTFAddon.db.profile.session.linesInfo[itemId].itemName,
      itemCount = WTFAddon.db.profile.session.linesInfo[itemId].itemCount
    })
	end

  if button == "LeftButton" then
  	table.sort(helperTable, function(a, b)
      if a.itemCount == b.itemCount then
        return a.itemName < b.itemName
      end
      return a.itemCount < b.itemCount
    end)
  elseif button == "RightButton" then
    table.sort(helperTable, function(a, b)
      if a.itemCount == b.itemCount then
        return a.itemName < b.itemName
      end
      return a.itemCount > b.itemCount
    end)
  end

  -- fill sorted array
  for i = 1, #helperTable do
    linesSorted[i] = helperTable[i].itemId
  end

  -- replace old array with sorted array
  WTFAddon.db.profile.session.lines = linesSorted

  -- refresh UI list
  WhatTheFarm_ScrollFrame_Update(WTFAddon.farmListFrame.scrollFrame)
end

local function addItemToIgnoreList(itemId)
  if panTableContains(WTFAddon.db.profile.config.ignoreList, itemId) == false then
    WTFAddon.db.profile.config.ignoreList[#WTFAddon.db.profile.config.ignoreList + 1] = itemId

    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
      itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, isCraftingReagent = GetItemInfo(itemId)
    WTFAddon:Print(string.format(L["WTF_IgnoreList_Ignore"], itemName))
  end

  for i = 1, #WTFAddon.db.profile.session.lines do
    if WTFAddon.db.profile.session.lines[i] == itemId then
      panRemoveFromArray(WTFAddon.db.profile.session.lines, itemId)
    end
	end

  -- refresh UI list
  WhatTheFarm_ScrollFrame_Update(WTFAddon.farmListFrame.scrollFrame)
end

local function removeItemsFromFarmListByQuality(quality)
  local qualityNumber = panGetQualityNumber(quality)
  local itemsToRemove = {}

  for i = 1, #WTFAddon.db.profile.session.lines do
    local itemId = WTFAddon.db.profile.session.lines[i]
    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
      itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, isCraftingReagent = GetItemInfo(itemId)

    if itemRarity == qualityNumber then
      itemsToRemove[#itemsToRemove + 1] = itemId
    end
	end

  if #itemsToRemove > 0 then
    for i = 1, #itemsToRemove do
      panRemoveFromArray(WTFAddon.db.profile.session.lines, itemsToRemove[i])
    end
  end

  -- refresh UI list
  WhatTheFarm_ScrollFrame_Update(WTFAddon.farmListFrame.scrollFrame)
end

local function showHelp()
  WTFAddon:Print(L["WTF_Help"])
  WTFAddon:Print(L["WTF_Help_Default"])
  WTFAddon:Print(L["WTF_Help_Toggle"])
  WTFAddon:Print(L["WTF_Help_Minimap"])
end

function WTFAddon_SetupPopupDialogs()
  -- perform reload when needed
  StaticPopupDialogs["WTF_PerformReload"] = {
    text = L["WTF_PerformReload"],
    button1 = L["WTF_Yes"],
    button2 = L["WTF_No"],
    OnAccept = function()
      ReloadUI()
    end,
    OnCancel = function()
      WTFAddon:Print(L["WTF_NotReloaded"])
    end,
    timeout = 0,
    whileDead = false,
    hideOnEscape = true,
    preferredIndex = 3
  }

  -- reset session data
  StaticPopupDialogs["WTF_ResetDataOnSessionStart"] = {
    text = L["WTF_ResetDataOnSessionStart"],
    button1 = L["WTF_Yes"],
    button2 = L["WTF_No"],
    OnAccept = function()
      resetSession()
      startSession(true)
    end,
    OnCancel = function()
      startSession(false)
    end,
    timeout = 0,
    whileDead = false,
    hideOnEscape = true,
    preferredIndex = 3
  }
end

function WTFAddon_SetupGUI()
  local farmListHeight = 50 + (WTFAddon.db.profile.config.linesToShow * _OffsetY_Step)

  -- setup farm list
  WTFAddon.farmListFrame = CreateFrame("Frame", "WhatTheFarm_FarmList", UIParent)
  WTFAddon.farmListFrame:SetPoint("TOPLEFT", WhatTheFarm, "BOTTOMLEFT", 0, 0)
  WTFAddon.farmListFrame:SetSize(400, farmListHeight) --210
  WTFAddon.farmListFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 11, top = 11, bottom = 10 },
  })

  -- setup scroll frame
  WTFAddon.farmListFrame.scrollFrame = CreateFrame("ScrollFrame", "WhatTheFarm_ScrollFrame", WTFAddon.farmListFrame, "FauxScrollFrameTemplate")
  WTFAddon.farmListFrame.scrollFrame:SetPoint("TOPLEFT", WTFAddon.farmListFrame, "TOPLEFT", 16, -16)
  WTFAddon.farmListFrame.scrollFrame:SetPoint("BOTTOMRIGHT", WTFAddon.farmListFrame, "BOTTOMRIGHT", -36, 16)
  -- WTFAddon.farmListFrame.scrollFrame:SetBackdrop({
  --   bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
  --   tile = false,
  --   tileSize = 0,
  --   edgeSize = 32,
  --   insets = { left = 0, right = 0, top = 0, bottom = 0 },
  -- })
  WTFAddon.farmListFrame.scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, 16, WhatTheFarm_ScrollFrame_Update)
  end)
  WTFAddon.farmListFrame.scrollFrame:SetScript("OnShow", WhatTheFarm_ScrollFrame_Update)

  -- create header line
  do
    local scrollFrameWidth = WTFAddon.farmListFrame.scrollFrame:GetWidth()

    local fontForButtons = CreateFont("fontForButtons")
    fontForButtons:SetTextColor(0.3, 0.7, 1.0, 1)

    -- FontString: item icon
    local wtfItemIconHeader = WTFAddon.farmListFrame.scrollFrame:CreateFontString("WTFItemIconHeader", "OVERLAY", "WhatTheFarm_DisplayListFont")
    wtfItemIconHeader:SetPoint("TOPLEFT", WTFAddon.farmListFrame.scrollFrame, "TOPLEFT", 0, _OffsetY)
    wtfItemIconHeader:SetText("-")
    wtfItemIconHeader:SetTextColor(1, 1, 1, 0)

    -- Button: item name
    local wtfItemNameHeader = CreateFrame("Button", "WTFItemNameHeader", WTFAddon.farmListFrame.scrollFrame, "WTF_TransparentButtonTemplate")
    wtfItemNameHeader:SetPoint("LEFT", wtfItemIconHeader, 24, 0)
    wtfItemNameHeader:SetText("Item")
    wtfItemNameHeader:SetSize(scrollFrameWidth - 80, _LineHeight)
    wtfItemNameHeader:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    wtfItemNameHeader:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
      GameTooltip:SetText(L["WTF_SortBy_Tooltip"])
      GameTooltip:Show()
    end)
    wtfItemNameHeader:SetScript("OnClick", function(self, button)
      sortItemsByName(self, button)
    end)
    wtfItemNameHeader:SetNormalFontObject(fontForButtons)
    wtfItemNameHeader:SetHighlightFontObject(fontForButtons)
    wtfItemNameHeader:GetFontString():SetPoint("LEFT")

    -- Button: item count
    local wtfItemCountHeader = CreateFrame("Button", "WTFItemCountHeader", WTFAddon.farmListFrame.scrollFrame, "WTF_TransparentButtonTemplate")
    wtfItemCountHeader:SetPoint("LEFT", wtfItemIconHeader, scrollFrameWidth - 48, 0)
    wtfItemCountHeader:SetText("#")
    wtfItemCountHeader:SetSize(32, _LineHeight)
    wtfItemCountHeader:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    wtfItemCountHeader:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
      GameTooltip:SetText(L["WTF_SortBy_Tooltip"])
      GameTooltip:Show()
    end)
    wtfItemCountHeader:SetScript("OnClick", function(self, button)
      sortItemsByCount(self, button)
    end)
    wtfItemCountHeader:SetNormalFontObject(fontForButtons)
    wtfItemCountHeader:SetHighlightFontObject(fontForButtons)
    wtfItemCountHeader:GetFontString():SetPoint("CENTER")

    -- FontString: ignore item
    local wtfItemIgnoreHeader = WTFAddon.farmListFrame.scrollFrame:CreateFontString("WTFItemIgnoreHeader", "OVERLAY", "WhatTheFarm_DisplayListFont")
    wtfItemIgnoreHeader:SetPoint("RIGHT", wtfItemIconHeader, scrollFrameWidth - _IconSize, 0)
    wtfItemIgnoreHeader:SetText("-")
    wtfItemIgnoreHeader:SetTextColor(1, 1, 1, 0)

    -- set new vertical offset
    _OffsetY = _OffsetY - _OffsetY_Step
  end

  -- pre-create all lines to show
  for line = 1, WTFAddon.db.profile.config.linesToShow, 1 do
    addNewLine(line)
  end

  -- initial call
  WhatTheFarm_ScrollFrame_Update(WTFAddon.farmListFrame.scrollFrame)

  WTFAddon:Print("WTFAddon_SetupGUI done.")
end

-- function WTFAddon_ReturnDetailedMoney(money)
--   -- local absMoney = abs(money)
--   -- local gold = floor(absMoney / 10000)
--   -- local silver = floor((absMoney - gold * 10000) / 100)
--   -- local copper = absMoney - gold * 10000 - silver * 100
--   -- return gold, silver, copper
-- end

--------------------------------------------------
-- Interface Events & Functions
--------------------------------------------------
function WhatTheFarm_Button_OnEnter(self, motion)
  if self then
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText(L[self:GetName() .. "_Tooltip"])
    GameTooltip:Show()
  end
end

function WhatTheFarm_IconButton_OnEnter(self, motion)
  if self then
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText(L[self:GetName()])
    GameTooltip:AddLine(L[self:GetName().."_Tooltip"], 1, 1, 1, true)
    GameTooltip:Show()
  end
end

function WhatTheFarm_ItemIgnoreButton_OnEnter(self, motion)
  if self then
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText(L["WTF_IgnoreItemButton"])
    GameTooltip:AddLine(L["WTF_IgnoreItemButton_Desc"], 1, 1, 1, true)
    GameTooltip:Show()
  end
end

function WhatTheFarm_Button_OnLeave(self, motion)
  GameTooltip:Hide()
end

function WhatTheFarm_ShowTooltip(self, title, description)
  if self then
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText(title)
    GameTooltip:AddLine(description, 1, 1, 1, true)
    GameTooltip:Show()
  end
end

function WhatTheFarm_HideTooltip(self)
  GameTooltip:Hide()
end

function WhatTheFarm_Close_OnClick(self, motion)
  WTFAddon:ToggleMainFrame()
end

function WhatTheFarm_StartSession_OnClick(self, motion)
  if WTFAddon.db.profile.session.isStarted == false then
    StaticPopup_Show("WTF_ResetDataOnSessionStart")
  end
end

function WhatTheFarm_StopSession_OnClick(self, motion)
  if WTFAddon.db.profile.session.isStarted == true then
    stopSession()
  end
end

function WhatTheFarm_ResetSession_OnClick(self, motion)
  resetSession()
end

function WhatTheFarm_ToggleDisplayList_OnClick(self, motion)
  if WhatTheFarm_FarmList:IsVisible() then
    HideUIPanel(WhatTheFarm_FarmList)
  else
    ShowUIPanel(WhatTheFarm_FarmList)
  end
end

function WhatTheFarm_ScrollFrame_Update(self)
  local numItems = #WTFAddon.db.profile.session.lines

  --function: FauxScrollFrame_Update(frame, numItems, numToDisplay, valueStep, button, smallWidth, bigWidth, highlightFrame, smallHighlightWidth, bigHighlightWidth)
	FauxScrollFrame_Update(WTFAddon.farmListFrame.scrollFrame, numItems, WTFAddon.db.profile.config.linesToShow, _LineHeight)

	local offset = FauxScrollFrame_GetOffset(WTFAddon.farmListFrame.scrollFrame)

	for line = 1, WTFAddon.db.profile.config.linesToShow, 1 do
		local lineplusoffset = line + offset
    local itemId = WTFAddon.db.profile.session.lines[lineplusoffset]

		if lineplusoffset > numItems then
      -- hide line
      _G["WTFItemName_"..line]:Hide()
      _G["WTFItemIcon_"..line]:Hide()
      _G["WTFItemCount_"..line]:Hide()
      _G["WTFItemIgnore_"..line]:Hide()
		else
      local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
        itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, isCraftingReagent = GetItemInfo(itemId)
      local itemInfo = WTFAddon.db.profile.session.linesInfo[itemId]

      -- fallback if GetItemInfo has not received data yet
      if itemName == nil then
        itemName = itemInfo.itemName
        itemLink = itemInfo.itemLink
        itemRarity = itemInfo.itemRarity
        itemType = itemInfo.itemType
        itemSubType = itemInfo.itemSubType
        itemIcon = itemInfo.itemIcon
        isCraftingReagent = itemInfo.isCraftingReagent
      end
      local r, g, b, hex = GetItemQualityColor(itemRarity)

      _G["WTFItemIcon_"..line]:SetTexture(itemIcon)
      _G["WTFItemName_"..line]:SetText(itemName)
      _G["WTFItemName_"..line]:GetFontString():SetTextColor(r, g, b, 1)
      _G["WTFItemCount_"..line]:SetText(itemInfo.itemCount)
      _G["WTFItemCount_"..line]:SetTextColor(r, g, b, 1)
      _G["WTFItemIgnore_"..line]:SetScript("OnClick", function(self)
        addItemToIgnoreList(itemId)
      end)
      -- show line
      _G["WTFItemIcon_"..line]:Show()
      _G["WTFItemName_"..line]:Show()
      _G["WTFItemCount_"..line]:Show()
      _G["WTFItemIgnore_"..line]:Show()
		end
	end

  WTFAddon.farmListFrame.scrollFrame:Show()
end

--------------------------------------------------
-- Functions
--------------------------------------------------
function WTFAddon:ToggleMainFrame()
  if WhatTheFarm:IsVisible() then
    WTFAddon.db.profile.config.isVisible = false
    HideUIPanel(WhatTheFarm)
    HideUIPanel(WhatTheFarm_FarmList)
  else
    WTFAddon.db.profile.config.isVisible = true
    ShowUIPanel(WhatTheFarm)
    ShowUIPanel(WhatTheFarm_FarmList)
  end
end

function WTFAddon:ShowOptionsFrame()
  -- double call to open the correct interface options panel
  InterfaceOptionsFrame_OpenToCategory(L["WTF_Title"])
  InterfaceOptionsFrame_OpenToCategory(L["WTF_Title"])
end

function WTFAddon:ToggleMinimapButton()
  self.db.profile.minimapButton.hide = not self.db.profile.minimapButton.hide
  if self.db.profile.minimapButton.hide then
    WTFMiniMapButton:Hide("WhatTheFarm")
  else
    WTFMiniMapButton:Show("WhatTheFarm")
  end
end

function WTFAddon:ToggleShowQuality(quality)
  if quality == "poor" then
    self.db.profile.config.showQuality.poor = not self.db.profile.config.showQuality.poor
    if not self.db.profile.config.showQuality.poor then
      removeItemsFromFarmListByQuality("poor")
      WTFAddon:Print(panGetPartiallyColoredString(L["WTF_ShowQuality_Hide"], ITEM_QUALITY0_DESC, _Colors.quality.poor))
    else
      WTFAddon:Print(panGetPartiallyColoredString(L["WTF_ShowQuality_Show"], ITEM_QUALITY0_DESC, _Colors.quality.poor))
    end
  elseif quality == "common" then
    self.db.profile.config.showQuality.common = not self.db.profile.config.showQuality.common
    if not self.db.profile.config.showQuality.common then
      removeItemsFromFarmListByQuality("common")
      WTFAddon:Print(panGetPartiallyColoredString(L["WTF_ShowQuality_Hide"], ITEM_QUALITY1_DESC, _Colors.quality.common))
    else
      WTFAddon:Print(panGetPartiallyColoredString(L["WTF_ShowQuality_Show"], ITEM_QUALITY1_DESC, _Colors.quality.common))
    end
  elseif quality == "uncommon" then
    self.db.profile.config.showQuality.uncommon = not self.db.profile.config.showQuality.uncommon
    if not self.db.profile.config.showQuality.uncommon then
      removeItemsFromFarmListByQuality("uncommon")
      WTFAddon:Print(panGetPartiallyColoredString(L["WTF_ShowQuality_Hide"], ITEM_QUALITY2_DESC, _Colors.quality.uncommon))
    else
      WTFAddon:Print(panGetPartiallyColoredString(L["WTF_ShowQuality_Show"], ITEM_QUALITY2_DESC, _Colors.quality.uncommon))
    end
  elseif quality == "rare" then
    self.db.profile.config.showQuality.rare = not self.db.profile.config.showQuality.rare
    if not self.db.profile.config.showQuality.rare then
      removeItemsFromFarmListByQuality("rare")
      WTFAddon:Print(panGetPartiallyColoredString(L["WTF_ShowQuality_Hide"], ITEM_QUALITY3_DESC, _Colors.quality.rare))
    else
      WTFAddon:Print(panGetPartiallyColoredString(L["WTF_ShowQuality_Show"], ITEM_QUALITY3_DESC, _Colors.quality.rare))
    end
  elseif quality == "epic" then
    self.db.profile.config.showQuality.epic = not self.db.profile.config.showQuality.epic
    if not self.db.profile.config.showQuality.epic then
      removeItemsFromFarmListByQuality("epic")
      WTFAddon:Print(panGetPartiallyColoredString(L["WTF_ShowQuality_Hide"], ITEM_QUALITY4_DESC, _Colors.quality.epic))
    else
      WTFAddon:Print(panGetPartiallyColoredString(L["WTF_ShowQuality_Show"], ITEM_QUALITY4_DESC, _Colors.quality.epic))
    end
  elseif quality == "legendary" then
    self.db.profile.config.showQuality.legendary = not self.db.profile.config.showQuality.legendary
    if not self.db.profile.config.showQuality.legendary then
      removeItemsFromFarmListByQuality("legendary")
      WTFAddon:Print(panGetPartiallyColoredString(L["WTF_ShowQuality_Hide"], ITEM_QUALITY5_DESC, _Colors.quality.legendary))
    else
      WTFAddon:Print(panGetPartiallyColoredString(L["WTF_ShowQuality_Show"], ITEM_QUALITY5_DESC, _Colors.quality.legendary))
    end
  end
end

function WTFAddon:PrintColored(msg, color)
  WTFAddon:Print("|cff" .. color .. msg .. "|r")
end

function WTFAddon:OnOptionHide()
   if (self.needReload) then
     self.needReload = false
     StaticPopup_Show("WTF_PerformReload")
   end
end

function WTFAddon:DoReload()
  self.needReload = false
  StaticPopup_Show("WTF_PerformReload")
end

--------------------------------------------------
-- Register Slash Commands
--------------------------------------------------
SLASH_RELOADUI1 = "/rl";
SlashCmdList.RELOADUI = ReloadUI;

function WTFAddon:ChatCommands(msg)
	local msg, msgParam = strsplit(" ", msg, 2)

  if msg == "toggle" then
  	if msgParam then
      WTFAddon:ToggleMainFrame()
  	end
  elseif msg == "minimap" then
  	if msgParam then
      WTFAddon:ToggleMinimapButton()
  	end
	else
    showHelp()
	end
end


--------------------------------------------------
-- Main Events
--------------------------------------------------
function WhatTheFarm_OnLoad(self) -- 1
  self:RegisterForDrag("LeftButton");

  -- register first events
  self:RegisterEvent("ADDON_LOADED")

  WTFAddon:Print("OnLoad done.")
end

function WTFAddon:OnInitialize() -- 2
  OffsetY = _OffsetY_Default

  -- register database
  self.db = LibStub("AceDB-3.0"):New("WhatTheFarmDB", _defaultConfig, false) -- by default all chars use default profile
  self.needReload = false

  self.db.RegisterCallback(self, "OnProfileChanged", "DoReload");
  self.db.RegisterCallback(self, "OnProfileCopied", "DoReload");
  self.db.RegisterCallback(self, "OnProfileReset", "DoReload");

  -- setup options frame
  WTFAddon_SetupOptionsUI();
  WTFAddon:SecureHookScript(self.optionsFrame, "OnHide", "OnOptionHide")

  -- setup profile options
  profileOptions = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
  LibStub("AceConfig-3.0"):RegisterOptionsTable("WhatTheFarmProfiles", profileOptions)
  profileSubMenu = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("WhatTheFarmProfiles", "Profiles", L["WTF_Title"])

  -- register minimap button
  WTFMiniMapButton:Register("WhatTheFarm", LDB, self.db.profile.minimapButton)

  -- register slash commands
  WTFAddon:RegisterChatCommand("wtf", "ChatCommands")
  WTFAddon:RegisterChatCommand("whatthefarm", "ChatCommands")

  -- setup popup dialogs
  WTFAddon_SetupPopupDialogs()

  WTFAddon:Print("OnInitialize done.")
end

function WhatTheFarm_OnEvent(self, event, ...)
  if event == "ADDON_LOADED" and ... == "WhatTheFarm" then -- 3
    -- for reagent in pairs(WTF_DB.session.reagents) do
    --   setReagentValues(reagent, 0)
    -- end
    --
    -- local reagentsCount = 0
    -- local sortedReagents = WTFAddon_InitializeListSort()
    -- for k, v in pairs(sortedReagents) do
    --   setReagentValues(v.itemId, WTF_DB.session.reagents[v.itemId].itemCount, true)
    --   reagentsCount = reagentsCount + 1
    -- end
    -- WTF_DB.session.totalLinesCount = reagentsCount
    --
    -- -- set button visibility
    -- WhatTheFarm_Controls_StartSession:Show()
    -- WhatTheFarm_Controls_StopSession:Hide()
    --
    -- -- update display
    -- WTFAddon_RefreshDisplayList(true)
    --
    -- -- show last session's time
    -- updateSessionTime(false, true)

    -- hide scroll frame
    --WhatTheFarm_ScrollFrame:Hide()

    WTFAddon:Print("ADDON_LOADED done.")

    self:RegisterEvent("PLAYER_LOGIN")
    self:UnregisterEvent("ADDON_LOADED")
  elseif event == "PLAYER_LOGIN" then -- 4
    WTFAddon.db.profile.session.isStarted = false

    -- setup main frame
    --WTFAddon_ApplyLayout(WTFAddon.db.profile.config.layout)
    WTFAddon_SetupGUI()

    -- hide frame by latest setting
    if WTFAddon.db.profile.config.isVisible == false then
        HideUIPanel(WhatTheFarm)
        HideUIPanel(WhatTheFarm_FarmList)
    else
        ShowUIPanel(WhatTheFarm)
        ShowUIPanel(WhatTheFarm_FarmList)
    end

    WTFAddon:Print("PLAYER_LOGIN done.") -- 3
  elseif event == "PLAYER_LOGOUT" or event == "PLAYER_QUITING" then
    if WTFAddon.db.profile.session.isStarted == true then
      stopSession()
    end
  elseif event == "LOOT_OPENED" then
    -- loops for every loot slot
    for i = 1, GetNumLootItems(), 1 do
      if LootSlotHasItem(i) then
        local lootIcon, lootName, lootQuantity, currencyID, lootQuality, locked, isQuestItem, questID, isActive = GetLootSlotInfo(i)
        local itemLink = GetLootSlotLink(i)

        if itemLink then
          local itemId = tonumber(strmatch(itemLink, "item:(%d+)"))
          local doAddReagent = false

          -- filter items by quality
          if lootQuality == 0 and WTFAddon.db.profile.config.showQuality.poor == true then doAddReagent = true
          elseif lootQuality == 1 and WTFAddon.db.profile.config.showQuality.common == true then doAddReagent = true
          elseif lootQuality == 2 and WTFAddon.db.profile.config.showQuality.uncommon == true then doAddReagent = true
          elseif lootQuality == 3 and WTFAddon.db.profile.config.showQuality.rare == true then doAddReagent = true
          elseif lootQuality == 4 and WTFAddon.db.profile.config.showQuality.epic == true then doAddReagent = true
          elseif lootQuality == 5 and WTFAddon.db.profile.config.showQuality.legendary == true then doAddReagent = true
          else doAddReagent = false
          end

          if panTableContains(WTFAddon.db.profile.config.ignoreList, itemId) == false then
            if locked ~= true and itemId and doAddReagent then
              local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
                itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, isCraftingReagent = GetItemInfo(itemId)

              if panTableContains(WTFAddon.db.profile.session.lines, itemId) == false then
                local lineCount = #WTFAddon.db.profile.session.lines
                WTFAddon.db.profile.session.lines[lineCount + 1] = itemId

                WTFAddon.db.profile.session.linesInfo[itemId] = {}
                WTFAddon.db.profile.session.linesInfo[itemId].itemName = itemName
                WTFAddon.db.profile.session.linesInfo[itemId].itemCount = lootQuantity
                WTFAddon.db.profile.session.linesInfo[itemId].itemLink = itemLink
                WTFAddon.db.profile.session.linesInfo[itemId].itemRarity = itemRarity
                WTFAddon.db.profile.session.linesInfo[itemId].itemType = itemType
                WTFAddon.db.profile.session.linesInfo[itemId].itemSubType = itemSubType
                WTFAddon.db.profile.session.linesInfo[itemId].itemIcon = itemIcon
                WTFAddon.db.profile.session.linesInfo[itemId].isCraftingReagent = isCraftingReagent
              else
                WTFAddon.db.profile.session.linesInfo[itemId].itemName = itemName
                WTFAddon.db.profile.session.linesInfo[itemId].itemCount = WTFAddon.db.profile.session.linesInfo[itemId].itemCount + lootQuantity
                WTFAddon.db.profile.session.linesInfo[itemId].itemLink = itemLink
                WTFAddon.db.profile.session.linesInfo[itemId].itemRarity = itemRarity
                WTFAddon.db.profile.session.linesInfo[itemId].itemType = itemType
                WTFAddon.db.profile.session.linesInfo[itemId].itemSubType = itemSubType
                WTFAddon.db.profile.session.linesInfo[itemId].itemIcon = itemIcon
                WTFAddon.db.profile.session.linesInfo[itemId].isCraftingReagent = isCraftingReagent
              end
            end
          end
        end
      end
    end

    WhatTheFarm_ScrollFrame_Update(WTFAddon.farmListFrame.scrollFrame)
  elseif event == "PLAYER_MONEY" then
    -- if WTF_DB.session.madeProfit == false then
    --   table.insert(WTF_DB.session.moneyHistory, 1, 0)
    --   WTF_DB.session.madeProfit = true
    -- end
    --
    -- local difference = GetMoney() - WTF_DB.session.lastMoney
    -- WTF_DB.session.moneyHistory[1] = WTF_DB.session.moneyHistory[1] + difference
    -- WTF_DB.session.lastMoney = GetMoney()
    --
    -- local gold, silver, copper = WTFAddon_ReturnDetailedMoney(WTF_DB.session.moneyHistory[1])
    -- WhatTheFarm_GoldString:SetText(gold)
    -- WhatTheFarm_SilverString:SetText(silver)
    -- WhatTheFarm_CopperString:SetText(copper)
  end
end
