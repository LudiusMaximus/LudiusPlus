local folderName, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("LudiusPlus")

-- Improves the House Editor's decor storage panel by adding a slider that
-- lets the player resize the catalog entry boxes.
--
-- The catalog entries are laid out by a ScrollBoxListSequenceView inside
-- HouseEditorFrame.StoragePanel.OptionsContainer. The view asks an
-- ElementSizeCalculator for each element's (width, height). We wrap that
-- calculator to return scaled (width, height) for decor/room/bundle entries.
-- The view's ResizeFrame path then physically sizes each acquired frame via
-- :SetSize, which makes the background/icon grow. The inner ModelScene has
-- a fixed 80x80 size anchored CENTER, so we scale it directly.

local MIN_SCALE = 0.55
local MAX_SCALE = 3.65
local STEP = 0.01

-- Default SearchBox anchor y-offset in Blizzard's XML is -20. We shift it
-- upwards to make vertical room for the slider row underneath.
local SEARCH_BOX_DEFAULT_Y = -20
local SEARCH_BOX_SHIFTED_Y = -13

-- The StoragePanel's XML sets widthSnapMultiplier=102, which HouseEditor's
-- OnResizeStopped uses to snap the options grid width to whole columns.
-- That 102 decomposes as tile width (BaseHousingCatalogEntryTemplate is
-- 97 wide) + 5px inter-column spacing. Only the tile portion scales with
-- our slider; the spacing stays constant, so the correct column pitch at
-- scale s is 97*s + 5; not 102*s.
local TILE_DEFAULT_WIDTH = 97
local COLUMN_SPACING = 5
local WIDTH_SNAP_DEFAULT = TILE_DEFAULT_WIDTH + COLUMN_SPACING

-- Only these template keys represent actual decor/room tiles.
local SCALEABLE_TEMPLATE_KEYS = {
  CATALOG_ENTRY_DECOR  = true,
  CATALOG_ENTRY_ROOM   = true,
  CATALOG_ENTRY_BUNDLE = true,
}


local DEFAULT_SCALE = 1.0
-- Reset button texture matches DynamicCam's reset buttons.
local RESET_TEXTURE = "Interface\\Transmogrify\\Transmogrify"
local RESET_TEXCOORDS = {0.58203125, 0.64453125, 0.30078125, 0.36328125}

local slider = nil
local sliderLabel = nil
local resetButton = nil
local hooked = false


-- The "Featured" category in the Catalog tab shows bundle/advertisement
-- tiles of non-standard sizes, and the panel forces its own fixed width
-- (FIXED_BUNDLE_WIDTH) + disables the ResizeButton while it's focused.
-- Our scaling would break that layout, so we fall back to 1.0 whenever
-- Featured is focused.
local function IsFeaturedFocused()
  local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
  local categories = storagePanel and storagePanel.Categories
  return categories and categories.IsFeaturedCategoryFocused and categories:IsFeaturedCategoryFocused() or false
end


local function GetScale()
  if not (LP_config and LP_config.houseEditorEnhancer_enabled) then
    return 1.0
  end
  if IsFeaturedFocused() then
    return 1.0
  end
  return LP_config.houseEditorEnhancer_itemSize or 1.0
end


local function ApplyModelSceneScale(frame)
  if frame and frame.ModelScene then
    frame.ModelScene:SetScale(GetScale())
  end
end


local function GetContainer()
  return HouseEditorFrame
    and HouseEditorFrame.StoragePanel
    and HouseEditorFrame.StoragePanel.OptionsContainer
end


-- Sync the panel's widthSnapMultiplier with the current scale so
-- HouseEditorStorageFrameMixin:OnResizeStopped snaps to whole columns of
-- scaled tiles. We leave storagePanel.minWidth untouched so the user can
-- drag narrower than one column at large scales; SnapPanelWidth (below)
-- then bumps it back out to >=1 column on release.
local function ApplyWidthSnapMultiplier()
  local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
  if not storagePanel then return end
  storagePanel.widthSnapMultiplier = TILE_DEFAULT_WIDTH * GetScale() + COLUMN_SPACING
end


-- Snap the storage panel's width to the nearest whole-column multiple at
-- the current scale, ensuring at least one column of options fits. Fired
-- on mouse-up of our slider and of the panel's ResizeButton (not during
-- drag, to avoid jitter under the user's cursor). Mirrors the snap/CVar
-- bookkeeping in HouseEditorStorageFrameMixin:OnResizeStopped.
local function SnapPanelWidth()
  local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
  if not storagePanel or not storagePanel.OptionsContainer then return end
  local scrollBox = storagePanel.OptionsContainer.ScrollBox
  if not scrollBox then return end

  local currentWidth = storagePanel:GetWidth()
  local optionsWidth = scrollBox:GetWidth()
  local nonOptionsWidth = currentWidth - optionsWidth
  local mult = storagePanel.widthSnapMultiplier or WIDTH_SNAP_DEFAULT

  local snappedOptionsWidth = RoundToNearestMultiple(optionsWidth, mult)
  -- Guarantee room for at least one column at the current scale.
  if snappedOptionsWidth < mult then
    snappedOptionsWidth = mult
  end
  local snappedWidth = Clamp(nonOptionsWidth + snappedOptionsWidth, storagePanel.minWidth, storagePanel.maxWidth)

  if not ApproximatelyEqual(currentWidth, snappedWidth) then
    storagePanel:SetWidth(snappedWidth)
  end

  SetCVar("housingStoragePanelWidth", storagePanel:GetWidth())
  SetCVar("housingStoragePanelHeight", storagePanel:GetHeight())
  storagePanel.OptionsContainer:UpdateLayout()
end


-- Rebuild forces the ScrollBox to re-acquire its frames, which runs the
-- view's ResizeFrame on every tile with our wrapped calculator's current
-- output - so both the layout and the physical frame sizes refresh.
local function RefreshCatalog()
  ApplyWidthSnapMultiplier()

  local container = GetContainer()
  if not container or not container.ScrollBox then return end
  local scrollBox = container.ScrollBox
  if not scrollBox:HasDataProvider() then return end

  local view = scrollBox:GetView()
  if view and view.ClearElementSizeData then
    view:ClearElementSizeData()
  end
  scrollBox:Rebuild(true)

  -- Rebuild re-acquires frames; fire ModelScene scaling for each.
  for _, frame in scrollBox:EnumerateFrames() do
    ApplyModelSceneScale(frame)
  end
end


local function InstallViewHook(container)
  if hooked then return true end

  local scrollBox = container.ScrollBox
  local view = scrollBox and scrollBox:GetView()
  if not view or not view.GetElementSizeCalculator then return false end

  local originalCalculator = view:GetElementSizeCalculator()
  if not originalCalculator then return false end

  view:SetElementSizeCalculator(function(dataIndex, elementData)
    local w, h = originalCalculator(dataIndex, elementData)
    if elementData and SCALEABLE_TEMPLATE_KEYS[elementData.templateKey] and w and h then
      local s = GetScale()
      return w * s, h * s
    end
    return w, h
  end)

  -- Every time a frame is acquired (new or from the pool), make sure its
  -- ModelScene is scaled to match. This also covers the ResizeButton case,
  -- where resizing the panel re-acquires frames from the pool.
  scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnAcquiredFrame, function(_, frame)
    ApplyModelSceneScale(frame)
  end, scrollBox)

  hooked = true
  return true
end


local function SetupEnhancer()
  local container = GetContainer()
  if not container then return end

  if not InstallViewHook(container) then return end

  local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
  if not storagePanel or not storagePanel.SearchBox then return end

  -- Snap to >=1 column when the user releases the panel's ResizeButton.
  if storagePanel.ResizeButton and not storagePanel.ResizeButton._lpSnapHooked then
    storagePanel.ResizeButton:HookScript("OnMouseUp", function() SnapPanelWidth() end)
    storagePanel.ResizeButton._lpSnapHooked = true
  end

  -- Re-scale whenever the user switches category: leaving "Featured"
  -- restores our custom size, entering "Featured" drops back to 1.0 (see
  -- GetScale). We hook Categories:SetFocus rather than the storage
  -- panel's OnCategoryFocusChanged because Categories:Initialize captures
  -- the callback via GenerateClosure - hooking OnCategoryFocusChanged on
  -- the panel would be bypassed. SetFocus is the universal entry point.
  if storagePanel.Categories and not storagePanel.Categories._lpFocusHooked then
    -- Defer the refresh by one frame: SetFocus runs mid-transition, before
    -- the new data provider is fully populated. Calling Rebuild inline
    -- here re-invokes element initializers on half-initialized entries
    -- (e.g. CatalogShop product cards without productInfo yet), causing
    -- Blizzard-side Lua errors.
    hooksecurefunc(storagePanel.Categories, "SetFocus", function()
      C_Timer.After(0, function()
        RefreshCatalog()
        if slider and slider._lpUpdateControlStates then
          slider._lpUpdateControlStates()
        end
      end)
    end)
    storagePanel.Categories._lpFocusHooked = true
  end

  -- Shift the SearchBox (and the Filters frame anchored to it) up to make
  -- room for our slider row beneath it.
  local searchBox = storagePanel.SearchBox
  searchBox:ClearAllPoints()
  searchBox:SetPoint("TOPLEFT", storagePanel, "TOPLEFT", 20, SEARCH_BOX_SHIFTED_Y)
  searchBox:SetPoint("TOPRIGHT", storagePanel, "TOPRIGHT", -160, SEARCH_BOX_SHIFTED_Y)

  if not slider then
    -- Parent the controls to the StoragePanel so they sit below the SearchBox.
    sliderLabel = storagePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sliderLabel:SetText(L["Decor Icon Size:"])
    sliderLabel:SetJustifyH("LEFT")

    slider = CreateFrame("Slider", "LudiusPlusHouseEditorSizeSlider", storagePanel, "MinimalSliderTemplate")
    slider:SetMinMaxValues(MIN_SCALE, MAX_SCALE)
    slider:SetValueStep(STEP)
    slider:SetObeyStepOnDrag(true)

    resetButton = CreateFrame("Button", "LudiusPlusHouseEditorResetButton", storagePanel)
    resetButton:SetSize(18, 18)
    local tex = resetButton:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(RESET_TEXTURE)
    tex:SetTexCoord(unpack(RESET_TEXCOORDS))
    tex:SetAllPoints()
    resetButton.texture = tex

    -- The Featured category ignores our scale (see GetScale), so the
    -- slider/reset controls are greyed out and non-interactive while it
    -- is focused - otherwise the UI implies the controls affect tiles
    -- that they don't.
    local function UpdateControlStates()
      local featured = IsFeaturedFocused()
      if featured then
        slider:Disable()
      else
        slider:Enable()
      end

      local value = slider:GetValue()
      local atDefault = math.abs(value - DEFAULT_SCALE) < STEP / 2
      local disabled = featured or atDefault
      resetButton:SetEnabled(not disabled)
      if disabled then
        tex:SetDesaturated(true)
        tex:SetVertexColor(0.5, 0.5, 0.5)
      else
        tex:SetDesaturated(false)
        tex:SetVertexColor(1, 1, 1)
      end
    end

    slider:SetScript("OnValueChanged", function(_, value)
      value = math.floor(value / STEP + 0.5) * STEP
      if LP_config then
        LP_config.houseEditorEnhancer_itemSize = value
      end
      UpdateControlStates()
      RefreshCatalog()
    end)
    slider:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
      GameTooltip:SetText(L["Resize decor item icons"], NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1, true)
      GameTooltip:AddLine(L["A feature of Ludius Plus's\n\"Technically Advanced Editor\" (TAE)."], TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b, 1, true)
      if IsFeaturedFocused() then
        GameTooltip_AddErrorLine(GameTooltip, L["Not working in the \"Featured\" category. TAE wants no part of %s!"]:format(HOUSING_MARKET_HEARTHSTEEL_TOOLTIP))
      end
      GameTooltip:Show()
    end)
    slider:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Snap the panel's width to the best-fitting column count when the user
    -- releases the slider. Also fires when clicking the track (harmless).
    slider:HookScript("OnMouseUp", function() SnapPanelWidth() end)

    resetButton:SetScript("OnClick", function()
      slider:SetValue(DEFAULT_SCALE)
      SnapPanelWidth()
    end)
    resetButton:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
      GameTooltip:SetText(L["Reset to default size"], NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1, true)
      GameTooltip:Show()
    end)
    resetButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    slider._lpUpdateControlStates = UpdateControlStates
  end

  -- Anchor layout: label at left under SearchBox, reset button pinned to
  -- SearchBox's right edge, slider stretches between them so it respects
  -- the label's locale-dependent width dynamically.
  sliderLabel:ClearAllPoints()
  sliderLabel:SetPoint("TOPLEFT", storagePanel.SearchBox, "BOTTOMLEFT", -3, -2)

  resetButton:ClearAllPoints()
  resetButton:SetPoint("RIGHT", storagePanel.SearchBox, "RIGHT", -4, 0)
  resetButton:SetPoint("TOP", sliderLabel, "TOP", 0, 2)

  slider:ClearAllPoints()
  slider:SetPoint("LEFT", sliderLabel, "RIGHT", 8, 0)
  slider:SetPoint("RIGHT", resetButton, "LEFT", -4, 0)
  slider:SetPoint("TOP", sliderLabel, "TOP", 0, 2)
  slider:SetFrameLevel(storagePanel:GetFrameLevel() + 20)

  sliderLabel:Show()
  slider:Show()
  resetButton:Show()

  slider:SetValue(LP_config and LP_config.houseEditorEnhancer_itemSize or DEFAULT_SCALE)
  if slider._lpUpdateControlStates then slider._lpUpdateControlStates() end

  RefreshCatalog()
end


local function TeardownEnhancer()
  if slider then slider:Hide() end
  if sliderLabel then sliderLabel:Hide() end
  if resetButton then resetButton:Hide() end

  -- Restore the SearchBox's original anchor y-offset.
  local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
  if storagePanel and storagePanel.SearchBox then
    local searchBox = storagePanel.SearchBox
    searchBox:ClearAllPoints()
    searchBox:SetPoint("TOPLEFT", storagePanel, "TOPLEFT", 20, SEARCH_BOX_DEFAULT_Y)
    searchBox:SetPoint("TOPRIGHT", storagePanel, "TOPRIGHT", -160, SEARCH_BOX_DEFAULT_Y)
  end
  -- GetScale() returns 1.0 when disabled, so RefreshCatalog resets tile
  -- sizes back to the Blizzard defaults.
  RefreshCatalog()
end


function addon.SetupOrTeardownHouseEditorEnhancer()
  if LP_config and LP_config.houseEditorEnhancer_enabled then
    if HouseEditorFrame then
      SetupEnhancer()
    end
    -- Otherwise the ADDON_LOADED handler below sets up when the house
    -- editor (load-on-demand) loads.
  else
    if HouseEditorFrame then
      TeardownEnhancer()
    end
  end
end


local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, addonName)
  if addonName == "Blizzard_HouseEditor" then
    if LP_config and LP_config.houseEditorEnhancer_enabled then
      SetupEnhancer()
    end
  end
end)
