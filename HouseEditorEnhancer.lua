local _, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("LudiusPlus")

-- The Enhanced House Editor module bundles two independent features:
--
-- 1. ICON SIZE SLIDER (toggle: houseEditorEnhancer_iconResizer)
--    Adds a slider above the storage panel that lets the player resize
--    catalog entry tiles. The catalog is laid out by a
--    ScrollBoxListSequenceView inside HouseEditorFrame.StoragePanel.
--    OptionsContainer. The view asks an ElementSizeCalculator for each
--    element's (w, h); we wrap it to return scaled dimensions for
--    decor entries. The view's ResizeFrame path then physically sizes
--    each acquired frame via :SetSize, growing the background/icon.
--    The inner ModelScene has a fixed 80x80 size anchored CENTER, so we
--    scale it directly.
--
-- 2. CTRL+CLICK PREVIEW (toggle: houseEditorEnhancer_preview)
--    Ctrl+LeftClick on a tile opens a model preview anchored to the
--    right of the editor. Blizzard only provides such a preview in the
--    HousingDashboardFrame's catalog; the HouseEditor has none. We
--    reuse Blizzard's HousingModelPreviewTemplate so it looks identical.
--    To keep Ctrl+LeftClick from also starting decor placement, we wrap
--    each catalog entry frame's OnInteract method as it's acquired by
--    the ScrollBox and skip the original when our modifier conditions
--    match. Wrapping the shared mixin (HousingCatalogEntryMixin) would
--    not work: XML-level Mixin copies methods onto each frame instance
--    at creation time, so frames already own their own function
--    reference and bypass any later mixin-table edits.
--
-- The module is set up if either option is enabled, torn down only when
-- both are off. Each feature's hooks are idempotent and gated by their
-- own option, so they coexist cleanly.


-- ===== Slider: constants =====

local MIN_SCALE = 0.55
local MAX_SCALE = 3.65
local STEP = 0.01

-- Default SearchBox anchor y-offset in Blizzard's XML is -20. We shift
-- it upwards to make vertical room for the slider row underneath.
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


-- ===== Preview: constants =====

local MIN_PREVIEW_WIDTH = 300
local MAX_PREVIEW_WIDTH = 1200
local DEFAULT_PREVIEW_WIDTH = 540
-- Gap between StoragePanel's right edge and preview's left edge. Used
-- both when anchoring and when computing how wide the preview can grow
-- before it'd hit the screen's right edge.
local PANEL_GAP = 8


-- ===== Module state =====

-- Slider:
local slider = nil
local sliderLabel = nil
local resetButton = nil
local viewHooked = false  -- ElementSizeCalculator + ApplyModelSceneScale

-- Preview:
local previewFrame = nil
local scrollBoxHooked = false  -- per-frame OnInteract + OnEnter/OnLeave wrap
local hoveredFrame = nil
local inspectCursorActive = false

local lastPreviewEntryInfo = nil
local previewWasShownBeforeCollapse = false


-- ===== Slider: helpers =====

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
  if not (LP_config and LP_config.houseEditorEnhancer_iconResizer) then
    return 1.0
  end
  if IsFeaturedFocused() then
    return 1.0
  end
  return LP_config.houseEditorEnhancer_iconResizerSize or 1.0
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
  if IsFeaturedFocused() then return end

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
  if viewHooked then return true end

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

  viewHooked = true
  return true
end


-- ===== Preview: helpers =====

local function IsPreviewEnabled()
  return LP_config and LP_config.houseEditorEnhancer_preview
end


local function HidePreview()
  if not previewFrame then return end
  previewFrame:Hide()
  previewFrame:ClearPreviewData()
end


-- Show the inspect cursor while Ctrl is held over a previewable tile.
-- We track inspectCursorActive so ResetCursor only runs if *we* set it -
-- otherwise we'd clobber cursors set by other systems (drag-and-drop,
-- spell targeting, etc.).
local function UpdateInspectCursor()
  local shouldShow = hoveredFrame
      and IsPreviewEnabled()
      and IsControlKeyDown()
      and hoveredFrame:HasValidData()
  if shouldShow then
    if not inspectCursorActive then
      ShowInspectCursor()
      inspectCursorActive = true
    end
  elseif inspectCursorActive then
    ResetCursor()
    inspectCursorActive = false
  end
end


-- Forward declaration: EnsurePreviewFrame's OnSizeChanged hook captures
-- this; the actual function body is defined further down so it can also
-- be called from ShowPreviewForEntry without an extra forward ref.
local UpdatePreviewLayout


local function EnsurePreviewFrame()
  if not HouseEditorFrame or not HouseEditorFrame.StoragePanel then return end

  if previewFrame then return previewFrame end

  if not C_AddOns.IsAddOnLoaded("Blizzard_HousingModelPreview") then
    C_AddOns.LoadAddOn("Blizzard_HousingModelPreview")
  end

  previewFrame = CreateFrame("Frame", "LudiusPlusHouseEditorPreviewFrame", HouseEditorFrame.StoragePanel, "HousingModelPreviewTemplate")
  local savedWidth = (LP_config and LP_config.houseEditorEnhancer_previewWidth) or DEFAULT_PREVIEW_WIDTH
  previewFrame:SetWidth(Clamp(savedWidth, MIN_PREVIEW_WIDTH, MAX_PREVIEW_WIDTH))
  previewFrame:SetPoint("BOTTOMLEFT", HouseEditorFrame.StoragePanel, "BOTTOMRIGHT", PANEL_GAP, 0)
  -- Ensure the preview frame is behind the StoragePanel's CollapseButton.
  previewFrame:SetFrameLevel(HouseEditorFrame.StoragePanel.CollapseButton:GetFrameLevel() - 1)
  -- Deliberately NOT SetClampedToScreen: it would snap our anchor inward
  -- when the preview's right edge hits the screen, visually detaching us
  -- from StoragePanel and overlapping it. UpdatePreviewLayout shrinks the
  -- width instead, keeping the anchor relationship intact.
  previewFrame:Hide()

  -- Hide only on our instance (each template instantiation gets its own
  -- texture children), so the HousingDashboardFrame's preview is untouched.
  if previewFrame.PreviewCornerLeft then previewFrame.PreviewCornerLeft:Hide() end
  if previewFrame.PreviewCornerRight then previewFrame.PreviewCornerRight:Hide() end

  -- Border-only variant of the tooltip backdrop (backdropColorAlpha=0):
  -- TooltipBorderedFrameTemplate would draw an 0.8-alpha dark Center over
  -- the model scene and visibly dim it.
  local border = CreateFrame("Frame", nil, previewFrame, "TooltipBorderBackdropTemplate")
  -- Extend the border beyond the preview frame a few pixels so the
  -- backdrop doesn't show through around the edge.
  border:SetPoint("TOPLEFT", previewFrame, "TOPLEFT", -2, 2)
  border:SetPoint("BOTTOMRIGHT", previewFrame, "BOTTOMRIGHT", 2, -2)

  -- Invisible frame behind previewFrame to catch clicks and prevent click-through.
  -- (Setting previewFrame:EnableMouse(true) prevented the mouse from interacting with the 3d model.)
  local clickBlocker = CreateFrame("Frame", nil, HouseEditorFrame.StoragePanel)
  clickBlocker:SetPoint("TOPLEFT", previewFrame, "TOPLEFT")
  clickBlocker:SetPoint("BOTTOMRIGHT", previewFrame, "BOTTOMRIGHT")
  clickBlocker:EnableMouse(true)
  clickBlocker:SetFrameLevel(previewFrame:GetFrameLevel() - 1)

  local close = CreateFrame("Button", nil, previewFrame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", previewFrame, "TOPRIGHT", 2, 2)
  close:SetScript("OnClick", function()
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
    HidePreview()
    previewWasShownBeforeCollapse = false
  end)

  -- Width-only resize handle. Uses PanelResizeButtonTemplate for the
  -- chat-style grabber visuals to match Blizzard's StoragePanel resize
  -- button, but overrides every script: PanelResizeButtonMixin would
  -- StartSizing on a BOTTOMRIGHT corner (resizing both width AND height),
  -- and our height is driven by UpdatePreviewLayout, not by the user.
  local resize = CreateFrame("Button", nil, previewFrame, "PanelResizeButtonTemplate")
  resize:SetPoint("BOTTOMRIGHT", previewFrame, "BOTTOMRIGHT", -2, 2)
  local dragStartCursorX, dragStartWidth
  resize:SetScript("OnMouseDown", function(self)
    dragStartCursorX = (GetCursorPosition()) / UIParent:GetEffectiveScale()
    dragStartWidth = previewFrame:GetWidth()
    self:SetScript("OnUpdate", function()
      local cursorX = (GetCursorPosition()) / UIParent:GetEffectiveScale()
      -- Cap by available space to the screen's right edge so the preview
      -- can't be dragged off-screen. Compute desired-left from the panel
      -- (not previewFrame:GetLeft()), to match UpdatePreviewLayout's logic.
      local panel = HouseEditorFrame and HouseEditorFrame.StoragePanel
      local panelRight = panel and panel:GetRight()
      local maxByScreen = panelRight and (UIParent:GetRight() - (panelRight + PANEL_GAP)) or MAX_PREVIEW_WIDTH
      local maxWidth = math.min(MAX_PREVIEW_WIDTH, maxByScreen)
      local newWidth = Clamp(dragStartWidth + (cursorX - dragStartCursorX), MIN_PREVIEW_WIDTH, maxWidth)
      previewFrame:SetWidth(newWidth)
    end)
  end)
  resize:SetScript("OnMouseUp", function(self)
    self:SetScript("OnUpdate", nil)
    if LP_config then
      LP_config.houseEditorEnhancer_previewWidth = previewFrame:GetWidth()
    end
  end)
  resize:SetScript("OnEnter", function() SetCursor("UI_RESIZE_CURSOR") end)
  resize:SetScript("OnLeave", function() SetCursor(nil) end)

  -- Sounds are intentionally not wired to OnShow/OnHide. The preview is
  -- parented to the editor, so OnShow/OnHide also fire on cascaded
  -- effective-visibility changes (e.g. StoragePanel hides during decor
  -- placement) - we'd play extra sounds in those cases. Instead, the
  -- open/select/close sounds are played inline at the actual user-driven
  -- actions: click to preview (ShowPreviewForEntry) and the close button.

  HouseEditorFrame:HookScript("OnHide", HidePreview)

  -- Re-fit on StoragePanel resize: panel resizing changes both the
  -- available vertical room (panel bottom moves) and our left edge
  -- (panel right moves), so width may need to shrink to stay on-screen.
  HouseEditorFrame.StoragePanel:HookScript("OnSizeChanged", UpdatePreviewLayout)

  return previewFrame
end


-- Recompute the preview's height and width.
--
-- Height: fill the vertical gap between StoragePanel's bottom and
-- HouseEditorButton's bottom, so the preview never covers the button.
-- WoW's anchor system can't express this with two anchors (left X comes
-- from StoragePanel, top Y from HouseEditorButton at a different X), so
-- we compute height explicitly.
--
-- Width: clamp to the available space between our left edge (which
-- equals panel:GetRight() + PANEL_GAP via our anchor) and the screen's
-- right edge so a wider StoragePanel can't push the preview off-screen.
-- We restore from LP_config rather than just shrinking the current
-- width, so a later StoragePanel-shrink expands the preview back to the
-- user's saved preference.
--
-- Important: we read panel:GetRight() rather than previewFrame:GetLeft()
-- because anchors-with-clamping can lie - if SetClampedToScreen were on,
-- GetLeft would return the post-clamp position, hiding the overflow.
function UpdatePreviewLayout()
  local panel = HouseEditorFrame and HouseEditorFrame.StoragePanel
  local btn = HousingControlsFrame
    and HousingControlsFrame.OwnerControlFrame
    and HousingControlsFrame.OwnerControlFrame.HouseEditorButton
  if not previewFrame or not panel or not btn then return end

  local btnBottom = btn:GetBottom()
  local panelBottom = panel:GetBottom()
  if btnBottom and panelBottom then
    local height = btnBottom - panelBottom
    if height > 0 then
      previewFrame:SetHeight(height)
    end
  end

  local panelRight = panel:GetRight()
  if panelRight then
    local maxByScreen = UIParent:GetRight() - (panelRight + PANEL_GAP)
    local saved = (LP_config and LP_config.houseEditorEnhancer_previewWidth) or DEFAULT_PREVIEW_WIDTH
    local target = Clamp(saved, MIN_PREVIEW_WIDTH, math.min(MAX_PREVIEW_WIDTH, maxByScreen))
    previewFrame:SetWidth(target)
  end
end


local function ShowPreviewForEntry(entry)
  local pf = EnsurePreviewFrame()
  if not pf then return end
  -- First open plays the open sound; subsequent entry swaps play the
  -- dashboard's select sound. Only one or the other, never both.
  if pf:IsShown() then
    PlaySound(SOUNDKIT.HOUSING_CATALOG_ENTRY_SELECT)
  else
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
  end
  pf:PreviewCatalogEntryInfo(entry.entryInfo)
  pf.lastEntryInfo = entry.entryInfo
  previewWasShownBeforeCollapse = true
  UpdatePreviewLayout()
  pf:Show()
end


local function HookCatalogEntry(frame)
  if not frame or frame._lpHooked then return end
  if type(frame.OnInteract) ~= "function" then return end

  local original = frame.OnInteract
  frame.OnInteract = function(self, button, isDrag)
    if not isDrag and button == "LeftButton" and IsControlKeyDown()
        and IsPreviewEnabled() and self:HasValidData() then
      ShowPreviewForEntry(self)
      return
    end
    return original(self, button, isDrag)
  end

  -- Track hover so MODIFIER_STATE_CHANGED can flip the cursor while the
  -- mouse stays still. OnEnter/OnLeave alone wouldn't catch the case of
  -- the user pressing Ctrl after hovering.
  frame:HookScript("OnEnter", function(self)
    hoveredFrame = self
    UpdateInspectCursor()
  end)
  frame:HookScript("OnLeave", function(self)
    if hoveredFrame == self then
      hoveredFrame = nil
    end
    UpdateInspectCursor()
  end)

  frame._lpHooked = true
end


local function InstallScrollBoxHook()
  if scrollBoxHooked then return end
  local scrollBox = HouseEditorFrame
    and HouseEditorFrame.StoragePanel
    and HouseEditorFrame.StoragePanel.OptionsContainer
    and HouseEditorFrame.StoragePanel.OptionsContainer.ScrollBox
  if not scrollBox then return end

  scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnAcquiredFrame, function(_, frame)
    HookCatalogEntry(frame)
  end, "LudiusPlus_HouseEditorEnhancer_Preview")

  -- Hook any frames already acquired before we installed the callback.
  for _, frame in scrollBox:EnumerateFrames() do
    HookCatalogEntry(frame)
  end

  scrollBoxHooked = true
end


-- ===== Slider: setup / teardown =====

local function SetupSlider()
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
    --
    -- Also skip RefreshCatalog entirely when Featured is focused: its
    -- CatalogShop product cards populate productInfo asynchronously, so
    -- even a deferred Rebuild can re-init a card before its data arrives.
    -- Our scale is forced to 1.0 in Featured (see GetScale), so no refresh
    -- is needed there anyway - Blizzard's own SetDataProvider does it.
    hooksecurefunc(storagePanel.Categories, "SetFocus", function()
      C_Timer.After(0, function()
        if not IsFeaturedFocused() then
          RefreshCatalog()
        end
        if slider and slider._lpUpdateControlStates then
          slider._lpUpdateControlStates()
        end
        -- Hide ResizeButton when Featured is focused, show it otherwise.
        if storagePanel.ResizeButton then
          if IsFeaturedFocused() then
            storagePanel.ResizeButton:Hide()
          else
            storagePanel.ResizeButton:Show()
          end
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
        LP_config.houseEditorEnhancer_iconResizerSize = value
      end
      UpdateControlStates()
      RefreshCatalog()
    end)
    slider:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
      GameTooltip:SetText(L["Resize decor item icons"], NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1, true)
      GameTooltip:AddLine(L["by Ludius Plus"], TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b, 1, true)
      if IsFeaturedFocused() then
        GameTooltip_AddErrorLine(GameTooltip, L["Not working in the \"Featured\" category. The \"Technically Advanced Editor\" (TAE) wants no part of %s!"]:format(HOUSING_MARKET_HEARTHSTEEL_TOOLTIP))
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

  slider:SetValue(LP_config and LP_config.houseEditorEnhancer_iconResizerSize or DEFAULT_SCALE)
  if slider._lpUpdateControlStates then slider._lpUpdateControlStates() end

  RefreshCatalog()
end


local function TeardownSlider()
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


-- ===== Public API =====

function addon.SetupOrTeardownHouseEditorEnhancer()
  -- HouseEditor is LoadOnDemand; the ADDON_LOADED handler below re-runs
  -- this once it's loaded.
  if not HouseEditorFrame then return end


  -- Hook to prevent error when productInfo is nil
  if not CatalogShopDefaultProductCardMixin._originalLayout then
    CatalogShopDefaultProductCardMixin._originalLayout = CatalogShopDefaultProductCardMixin.Layout
    CatalogShopDefaultProductCardMixin.Layout = function(self)
      if not self.productInfo then return end
      return CatalogShopDefaultProductCardMixin._originalLayout(self)
    end
  end
  if _G.FormatPriceStrings and not _G._originalFormatPriceStrings then
    _G._originalFormatPriceStrings = _G.FormatPriceStrings
    _G.FormatPriceStrings = function(productInfo)
      if not productInfo then return "", "" end
      return _G._originalFormatPriceStrings(productInfo)
    end
  end


  if LP_config and LP_config.houseEditorEnhancer_iconResizer then
    SetupSlider()
  else
    TeardownSlider()
  end

  -- Preview frame itself is created lazily by EnsurePreviewFrame on the
  -- first Ctrl+Click, but the per-frame OnInteract wrap (and the OnEnter/
  -- OnLeave hover tracking for the inspect cursor) must be installed up
  -- front so the click is intercepted before Blizzard's placement logic
  -- runs.
  if IsPreviewEnabled() then
    InstallScrollBoxHook()
  else
    HidePreview()
  end
end


-- ===== Events =====

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == "Blizzard_HouseEditor" then
      addon.SetupOrTeardownHouseEditorEnhancer()
      -- Hook the collapse and expand buttons for preview management.
      if HouseEditorFrame and HouseEditorFrame.StoragePanel and HouseEditorFrame.StoragePanel.CollapseButton then
        HouseEditorFrame.StoragePanel.CollapseButton:HookScript("OnClick", function()
          if previewFrame and previewFrame:IsShown() then
            previewWasShownBeforeCollapse = true
            lastPreviewEntryInfo = previewFrame.lastEntryInfo
            HidePreview()
          else
            previewWasShownBeforeCollapse = false
          end
        end)
      end
      if HouseEditorFrame and HouseEditorFrame.StorageButton then
        HouseEditorFrame.StorageButton:HookScript("OnClick", function()
          if previewWasShownBeforeCollapse and lastPreviewEntryInfo then
            local pf = EnsurePreviewFrame()
            if pf then
              pf:PreviewCatalogEntryInfo(lastPreviewEntryInfo)
              UpdatePreviewLayout()
              pf:Show()
            end
          end
        end)
      end
    end
  elseif event == "MODIFIER_STATE_CHANGED" then
    if arg1 == "LCTRL" or arg1 == "RCTRL" then
      UpdateInspectCursor()
    end
  end
end)
