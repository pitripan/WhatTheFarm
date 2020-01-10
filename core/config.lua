local L = LibStub("AceLocale-3.0"):GetLocale("WhatTheFarm")
local _Colors = WTFAddon_GetColors()

local _DefaultLayout = "Default"
local _OffsetY_IgnoreList = 0
local _OffsetY_Default = 0
local _OffsetY_Step = 18
local _IconSize = 16
local _LineHeight = 16
local _IgnoreList_LinesToShow = 10


--------------------------------------------------
-- UI Widget Functions
--------------------------------------------------
local function createSlider(parent, name, label, description, minVal, maxVal, valStep, onValueChanged, onShow)
	local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
	local editbox = CreateFrame("EditBox", name.."EditBox", slider, "InputBoxTemplate")

	slider:SetMinMaxValues(minVal, maxVal)
	slider:SetValue(minVal)
	slider:SetValueStep(1)
	slider.text = _G[name.."Text"]
	slider.text:SetText(label)
	slider.textLow = _G[name.."Low"]
	slider.textHigh = _G[name.."High"]
	slider.textLow:SetText(floor(minVal))
	slider.textHigh:SetText(floor(maxVal))
	slider.textLow:SetTextColor(0.4,0.4,0.4)
	slider.textHigh:SetTextColor(0.4,0.4,0.4)
  slider.tooltipText = label
  slider.tooltipRequirement = description

	editbox:SetSize(50,30)
	editbox:SetNumeric(true)
	editbox:SetMultiLine(false)
	editbox:SetMaxLetters(5)
	editbox:ClearAllPoints()
	editbox:SetPoint("TOP", slider, "BOTTOM", 0, -5)
	editbox:SetNumber(slider:GetValue())
	editbox:SetCursorPosition(0);
	editbox:ClearFocus();
	editbox:SetAutoFocus(false)
  editbox.tooltipText = label
  editbox.tooltipRequirement = description

	slider:SetScript("OnValueChanged", function(self,value)
		self.editbox:SetNumber(floor(value))
		if(not self.editbox:HasFocus()) then
			self.editbox:SetCursorPosition(0);
			self.editbox:ClearFocus();
		end
    onValueChanged(self, value)
	end)

  slider:SetScript("OnShow", function(self,value)
    onShow(self, value)
  end)

	editbox:SetScript("OnTextChanged", function(self)
		local value = self:GetText()

		if tonumber(value) then
			if(floor(value) > maxVal) then
				self:SetNumber(maxVal)
			end

			if floor(self:GetParent():GetValue()) ~= floor(value) then
				self:GetParent():SetValue(floor(value))
			end
		end
	end)

	editbox:SetScript("OnEnterPressed", function(self)
		local value = self:GetText()
		if tonumber(value) then
			self:GetParent():SetValue(floor(value))
				self:ClearFocus()
		end
	end)

	slider.editbox = editbox
	return slider
end

local function createCheckbox(parent, name, label, description, hideLabel, onClick)
  local check = CreateFrame("CheckButton", name, parent, "InterfaceOptionsCheckButtonTemplate")
  check.label = _G[check:GetName() .. "Text"]
  if not hideLabel then
		check.label:SetText(label)
		check:SetFrameLevel(8)
	end
  check.tooltipText = label
  check.tooltipRequirement = description

  -- events
  check:SetScript("OnClick", function(self)
    local tick = self:GetChecked()
    onClick(self, tick and true or false)
  end)

  return check
end

local function createEditbox(parent, name, tooltipTitle, tooltipDescription, width, height, multiline, onTextChanged)
	local editbox	 = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
	editbox:SetSize(width, height)
	editbox:SetMultiLine(multiline)
	editbox:SetFrameLevel(9)
	editbox:ClearFocus()
	editbox:SetAutoFocus(false)
	editbox:SetScript("OnTextChanged", function(self)
		onTextChanged(self)
	end)
	editbox:SetScript("OnEnter", function(self, motion)
		MakePeopleGreetAgain_ShowTooltip(self, tooltipTitle, tooltipDescription)
	end)
	editbox:SetScript("OnLeave", function(self, motion)
		MakePeopleGreetAgain_HideTooltip(self)
	end)

  return editbox
end

local function createLabel(parent, name, text)
	local label = parent:CreateFontString(name, "ARTWORK", "GameFontNormal")
	label:SetText(text)
  return label
end

local function createItemLineForConfig(prefix, position)
  local scrollFrameWidth = WTFAddon.optionsFrame.scrollFrameIgnore:GetWidth()

  -- Texture: item icon
  local wtfNewItemIcon = WTFAddon.optionsFrame.scrollFrameIgnore:CreateTexture("WTFItemIcon_"..prefix.."_"..position, "ARTWORK")
  wtfNewItemIcon:SetPoint("TOPLEFT", WTFAddon.optionsFrame.scrollFrameIgnore, "TOPLEFT", 0, _OffsetY_IgnoreList)
  wtfNewItemIcon:SetWidth(_IconSize)
  wtfNewItemIcon:SetHeight(_IconSize)
  wtfNewItemIcon:Hide()

  -- Button: item name
  local fontForName = CreateFont("fontForName")
  fontForName:SetTextColor(1, 1, 1, 1)

  local wtfNewItemName = CreateFrame("Button", "WTFItemName_"..prefix.."_"..position, WTFAddon.optionsFrame.scrollFrameIgnore, "WTF_TransparentButtonTemplate")
  wtfNewItemName:SetPoint("LEFT", wtfNewItemIcon, 24, 0)
  wtfNewItemName:SetText("")
  wtfNewItemName:SetSize(scrollFrameWidth - 80, _LineHeight)
  wtfNewItemName:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
      GameTooltip:SetText(self:GetText())
      GameTooltip:Show()
  end)
  wtfNewItemName:SetNormalFontObject(fontForName)
  wtfNewItemName:SetHighlightFontObject(fontForName)
  wtfNewItemName:GetFontString():SetPoint("LEFT")
  wtfNewItemName:Hide()

  -- Button: ignore item
  local wtfNewItemIgnore = CreateFrame("Button", "WTFItemIgnore_"..prefix.."_"..position, WTFAddon.optionsFrame.scrollFrameIgnore, "WTF_ItemIgnoreButtonTemplate")
  wtfNewItemIgnore:SetPoint("RIGHT", wtfNewItemIcon, scrollFrameWidth - _IconSize, 0)
  wtfNewItemIgnore:SetSize(_IconSize, _IconSize)
  wtfNewItemIgnore:Hide()

  -- set new vertical offset
  _OffsetY_IgnoreList = _OffsetY_IgnoreList - _OffsetY_Step
end


--------------------------------------------------
-- General Functions
--------------------------------------------------
local function removeItemFromIgnoreList(itemId)
  if panTableContains(WTFAddon.db.profile.config.ignoreList, itemId) == true then
		panRemoveFromArray(WTFAddon.db.profile.config.ignoreList, itemId)
  end

  -- refresh UI list
  WTFAddon_IgnoreList_Update(WTFAddon.optionsFrame.scrollFrameIgnore)
end

local function sortIgnoredItemsByName(self, button)
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

local function getPartiallyColoredString(text, coloredText, color)
	local colorString = ""
	colorString = "\124cff" .. color .. coloredText .. "\124r"
	return string.format(text, colorString)
end

local function getColoredString(text, color)
  return "\124cff" .. color .. text .. "\124r"
end

--------------------------------------------------
-- Interface Events & Functions
--------------------------------------------------
function WTFAddon_SetupOptionsUI()
  WTFAddon.optionsFrame = CreateFrame("Frame", "WhatTheFarm_Options", InterfaceOptionsFramePanelContainer)
  WTFAddon.optionsFrame.name = L["WTF_Title"]
	WTFAddon.optionsFrame:SetAllPoints()
	HideUIPanel(WTFAddon.optionsFrame)

  local title = WTFAddon.optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 10, -10)
	title:SetText(L["WTF_Title"])

	-- layout
	do
		local layoutLabel = createLabel(WTFAddon.optionsFrame, "layoutLabel", L["WTF_SetLayout"])
		layoutLabel:SetPoint("TOPLEFT", title, 0, -30)

		WTFAddon.layoutDropdown = CreateFrame("Frame", "WhatTheFarmLayoutDropdown", WTFAddon.optionsFrame, "UIDropDownMenuTemplate")
		WTFAddon.layoutDropdown:SetPoint("TOPLEFT", layoutLabel, -16, -14)
		UIDropDownMenu_SetWidth(WTFAddon.layoutDropdown, 150)
		UIDropDownMenu_Initialize(WTFAddon.layoutDropdown, function(frame, level, menuList)
			local info = UIDropDownMenu_CreateInfo()
			info.func = WTFAddon_SetLayout
			info.text, info.arg1 = L["WTF_Layout_Default"], _DefaultLayout
			UIDropDownMenu_AddButton(info)
		end)
		UIDropDownMenu_SetText(WTFAddon.layoutDropdown, L["WTF_Layout_"..WTFAddon.db.profile.config.layout])
	end

	-- Minimap Button
	do
		local minimapButtonCheckbox = createCheckbox(
	    WTFAddon.optionsFrame,
	    "WTF_MinimapButton_Checkbox",
	    L["WTF_MinimapButton"],
	    L["WTF_MinimapButton_Desc"],
			false,
	    function(self, value)
	      WTFAddon:ToggleMinimapButton()
	    end
		)
		minimapButtonCheckbox:SetChecked(not WTFAddon.db.profile.minimapButton.hide)
	  minimapButtonCheckbox:SetPoint("TOPLEFT", layoutLabel, 300, 0)
	end

	-- Show Quality label
	local showQualityLabel = createLabel(WTFAddon.optionsFrame, "showQualityLabel", L["WTF_ShowQuality"])
	showQualityLabel:SetPoint("TOPLEFT", layoutLabel, 0, -60)
	showQualityLabel:SetWidth(300)
	showQualityLabel:SetJustifyH("LEFT")

	-- Show (Loot) Quality: Poor
	do
		local showQualityPoorCheckbox = createCheckbox(
	    WTFAddon.optionsFrame,
	    "WTF_ShowQualityPoor_Checkbox",
			getColoredString(ITEM_QUALITY0_DESC, _Colors.quality.poor),
			L["WTF_ShowQuality_Desc"],
			false,
	    function(self, value)
				WTFAddon:ToggleShowQuality("poor")
	    end
		)
		showQualityPoorCheckbox:SetChecked(WTFAddon.db.profile.config.showQuality.poor)
	  showQualityPoorCheckbox:SetPoint("TOPLEFT", showQualityLabel, 0, -30)
	end

	-- Show (Loot) Quality: Common
	do
		local showQualityCommonCheckbox = createCheckbox(
			WTFAddon.optionsFrame,
			"WTF_ShowQualityCommon_Checkbox",
			getColoredString(ITEM_QUALITY1_DESC, _Colors.quality.common),
			L["WTF_ShowQuality_Desc"],
			false,
			function(self, value)
				WTFAddon:ToggleShowQuality("common")
			end
		)
		showQualityCommonCheckbox:SetChecked(WTFAddon.db.profile.config.showQuality.common)
		showQualityCommonCheckbox:SetPoint("TOPLEFT", showQualityLabel, 0, -50)
	end

	-- Show (Loot) Quality: Uncommon
	do
		local showQualityUncommonCheckbox = createCheckbox(
			WTFAddon.optionsFrame,
			"WTF_ShowQualityUncommon_Checkbox",
			getColoredString(ITEM_QUALITY2_DESC, _Colors.quality.uncommon),
			L["WTF_ShowQuality_Desc"],
			false,
			function(self, value)
				WTFAddon:ToggleShowQuality("uncommon")
			end
		)
		showQualityUncommonCheckbox:SetChecked(WTFAddon.db.profile.config.showQuality.uncommon)
		showQualityUncommonCheckbox:SetPoint("TOPLEFT", showQualityLabel, 0, -70)
	end

	-- Show (Loot) Quality: Rare
	do
		local showQualityRareCheckbox = createCheckbox(
			WTFAddon.optionsFrame,
			"WTF_ShowQualityRare_Checkbox",
			getColoredString(ITEM_QUALITY3_DESC, _Colors.quality.rare),
			L["WTF_ShowQuality_Desc"],
			false,
			function(self, value)
				WTFAddon:ToggleShowQuality("rare")
			end
		)
		showQualityRareCheckbox:SetChecked(WTFAddon.db.profile.config.showQuality.rare)
		showQualityRareCheckbox:SetPoint("TOPLEFT", showQualityLabel, 0, -90)
	end

	-- Show (Loot) Quality: Epic
	do
		local showQualityEpicCheckbox = createCheckbox(
			WTFAddon.optionsFrame,
			"WTF_ShowQualityEpic_Checkbox",
			getColoredString(ITEM_QUALITY4_DESC, _Colors.quality.epic),
			L["WTF_ShowQuality_Desc"],
			false,
			function(self, value)
				WTFAddon:ToggleShowQuality("epic")
			end
		)
		showQualityEpicCheckbox:SetChecked(WTFAddon.db.profile.config.showQuality.epic)
		showQualityEpicCheckbox:SetPoint("TOPLEFT", showQualityLabel, 0, -110)
	end

	-- Show (Loot) Quality: Legendary
	do
		local showQualityLegendaryCheckbox = createCheckbox(
			WTFAddon.optionsFrame,
			"WTF_ShowQualityLegendary_Checkbox",
			getColoredString(ITEM_QUALITY5_DESC, _Colors.quality.legendary),
			L["WTF_ShowQuality_Desc"],
			false,
			function(self, value)
				WTFAddon:ToggleShowQuality("legendary")
			end
		)
		showQualityLegendaryCheckbox:SetChecked(WTFAddon.db.profile.config.showQuality.legendary)
		showQualityLegendaryCheckbox:SetPoint("TOPLEFT", showQualityLabel, 0, -130)
	end

	-- lines to show
	do
	end

	-- ignore list
	do
		local ignoreListLabel = createLabel(WTFAddon.optionsFrame, "ignoreListLabel", L["WTF_IgnoreListHeader"])
		ignoreListLabel:SetPoint("TOPLEFT", WTFAddon.optionsFrame, "TOPLEFT", 300, -80)

		-- setup scroll frame
	  WTFAddon.optionsFrame.scrollFrameIgnore = CreateFrame("ScrollFrame", "WhatTheFarm_IgnoreList_ScrollFrame", WTFAddon.optionsFrame, "FauxScrollFrameTemplate")
	  WTFAddon.optionsFrame.scrollFrameIgnore:SetPoint("TOPLEFT", WTFAddon.optionsFrame, "TOPLEFT", 300, -100)
	  WTFAddon.optionsFrame.scrollFrameIgnore:SetPoint("BOTTOMRIGHT", WTFAddon.optionsFrame, "BOTTOMRIGHT", -36, 16)
	  -- WTFAddon.optionsFrame.scrollFrameIgnore:SetBackdrop({
	  --   bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		-- 	--bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
	  --   tile = false,
	  --   tileSize = 0,
	  --   edgeSize = 32,
	  --   insets = { left = 0, right = 0, top = 0, bottom = 0 },
	  -- })
	  WTFAddon.optionsFrame.scrollFrameIgnore:SetScript("OnVerticalScroll", function(self, offset)
	     FauxScrollFrame_OnVerticalScroll(self, offset, 16, WTFAddon_IgnoreList_Update)
	   end)
	  WTFAddon.optionsFrame.scrollFrameIgnore:SetScript("OnShow", WTFAddon_IgnoreList_Update)

	  -- create header line
	  do
	    local scrollFrameWidth = WTFAddon.optionsFrame.scrollFrameIgnore:GetWidth()

	    local fontForButtons = CreateFont("fontForButtons")
	    fontForButtons:SetTextColor(0.3, 0.7, 1.0, 1)

	    -- FontString: item icon
	    local wtfItemIconHeader = WTFAddon.optionsFrame.scrollFrameIgnore:CreateFontString("WTFItemIconHeader_IgnoreList", "OVERLAY", "WhatTheFarm_DisplayListFont")
	    wtfItemIconHeader:SetPoint("TOPLEFT", WTFAddon.optionsFrame.scrollFrameIgnore, "TOPLEFT", 0, _OffsetY_IgnoreList)
	    wtfItemIconHeader:SetText("-")
	    wtfItemIconHeader:SetTextColor(1, 1, 1, 0)

	    -- Button: item name
	    local wtfItemNameHeader = CreateFrame("Button", "WTFItemNameHeader_IgnoreList", WTFAddon.optionsFrame.scrollFrameIgnore, "WTF_TransparentButtonTemplate")
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
	      sortIgnoredItemsByName(self, button)
	    end)
	    wtfItemNameHeader:SetNormalFontObject(fontForButtons)
	    wtfItemNameHeader:SetHighlightFontObject(fontForButtons)
	    wtfItemNameHeader:GetFontString():SetPoint("LEFT")

	    -- FontString: ignore item
	    local wtfItemIgnoreHeader = WTFAddon.optionsFrame.scrollFrameIgnore:CreateFontString("WTFItemIgnoreHeader_IgnoreList", "OVERLAY", "WhatTheFarm_DisplayListFont")
	    wtfItemIgnoreHeader:SetPoint("RIGHT", wtfItemIconHeader, scrollFrameWidth - _IconSize, 0)
	    wtfItemIgnoreHeader:SetText("-")
	    wtfItemIgnoreHeader:SetTextColor(1, 1, 1, 0)

	    -- set new vertical offset
	    _OffsetY_IgnoreList = _OffsetY_IgnoreList - _OffsetY_Step
	  end

	  -- pre-create all lines to show
	  for line = 1, _IgnoreList_LinesToShow, 1 do
	    createItemLineForConfig("IgnoreList", line)
	  end
	end

	-- add to interface options
  InterfaceOptions_AddCategory(WTFAddon.optionsFrame);
end

function WTFAddon_SetLayout(newValue)
	-- MPGAAddon.db.profile.config.layout = newValue.arg1
	-- MPGAAddon.needReload = true
	-- UIDropDownMenu_SetText(MPGAAddon.layoutDropdown, newValue.value)
	-- CloseDropDownMenus()
end

function WTFAddon_ApplyLayout(layout)
  -- if layout == _SingleRowLayout then
  --   -- set database values
  --   MPGAAddon.db.profile.config.layout = _SingleRowLayout
  --   MPGAAddon.db.profile.config.buttonsPerRow = 8
  --   -- change layout settings
  --   MakePeopleGreetAgain_Title:SetText(L["MPGA_Title"])
  --   MakePeopleGreetAgain:SetSize(416, 72)
  -- elseif layout == _SingleColumnLayout then
  --   -- set database values
  --   MPGAAddon.db.profile.config.layout = _SingleColumnLayout
  --   MPGAAddon.db.profile.config.buttonsPerRow = 1
  --   -- change layout settings
  --   MakePeopleGreetAgain_Title:SetText(L["MPGA_Title_Short"])
  --   MakePeopleGreetAgain:SetSize(80, 240)
  -- elseif layout == _TwoColumnsLayout then
  --   -- set database values
  --   MPGAAddon.db.profile.config.layout = _TwoColumnsLayout
  --   MPGAAddon.db.profile.config.buttonsPerRow = 2
  --   -- change layout settings
  --   MakePeopleGreetAgain_Title:SetText(L["MPGA_Title_Short"])
  --   MakePeopleGreetAgain:SetSize(128, 144)
  -- else -- DEFAULT
  --   -- set database values
  --   MPGAAddon.db.profile.config.layout = _DefaultLayout
  --   MPGAAddon.db.profile.config.buttonsPerRow = 4
  --   -- change layout settings
  --   MakePeopleGreetAgain_Title:SetText(L["MPGA_Title"])
  --   MakePeopleGreetAgain:SetSize(224, 96)
  -- end
end

function WTFAddon_IgnoreList_Update(self)
  local numItems = #WTFAddon.db.profile.config.ignoreList

  --function: FauxScrollFrame_Update(frame, numItems, numToDisplay, valueStep, button, smallWidth, bigWidth, highlightFrame, smallHighlightWidth, bigHighlightWidth)
	FauxScrollFrame_Update(WTFAddon.optionsFrame.scrollFrameIgnore, numItems, _IgnoreList_LinesToShow, _LineHeight)

	local offset = FauxScrollFrame_GetOffset(WTFAddon.optionsFrame.scrollFrameIgnore)

	for line = 1, _IgnoreList_LinesToShow, 1 do
		local lineplusoffset = line + offset
    local itemId = WTFAddon.db.profile.config.ignoreList[lineplusoffset]

		if lineplusoffset > numItems then
      -- hide line
      _G["WTFItemName_IgnoreList_"..line]:Hide()
      _G["WTFItemIcon_IgnoreList_"..line]:Hide()
      _G["WTFItemIgnore_IgnoreList_"..line]:Hide()
		else
      local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
        itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, isCraftingReagent = GetItemInfo(itemId)
      local r, g, b, hex = GetItemQualityColor(itemRarity)

      _G["WTFItemIcon_IgnoreList_"..line]:SetTexture(itemIcon)
      _G["WTFItemName_IgnoreList_"..line]:SetText(itemName)
      _G["WTFItemName_IgnoreList_"..line]:GetFontString():SetTextColor(r, g, b, 1)
      _G["WTFItemIgnore_IgnoreList_"..line]:SetScript("OnClick", function(self)
          removeItemFromIgnoreList(itemId)
					WTFAddon:Print(string.format(L["WTF_IgnoreList_Unignore"], itemName))
      end)
      -- show line
      _G["WTFItemIcon_IgnoreList_"..line]:Show()
      _G["WTFItemName_IgnoreList_"..line]:Show()
      _G["WTFItemIgnore_IgnoreList_"..line]:Show()
		end
	end

  WTFAddon.optionsFrame.scrollFrameIgnore:Show()
end
