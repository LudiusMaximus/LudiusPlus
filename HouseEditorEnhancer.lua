local _, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("LudiusPlus")

-- The Enhanced House Editor module bundles three independent features,
-- each with its own Setup/Teardown pair. SetupOrTeardownHouseEditorEnhancer
-- is a thin dispatcher that toggles each feature based on its config flag.
-- No hook, event, or frame is installed until its feature is first
-- enabled - a cold /reload with all flags off leaves zero footprint.
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
-- 3. FEATURED LAST (toggle: houseEditorEnhancer_featuredLast)
--    Moves the "Featured" category to the bottom of the Market tab's
--    category list and defaults to "All" whenever the user switches to
--    the Market tab.
--
-- Hooks installed via hooksecurefunc can't be removed; where we use
-- them, Setup installs once per session and the hook body runtime-gates
-- on its config flag so in-session disable is instant. Teardown removes
-- whatever it can (callbacks, events, frames) and leaves the idempotent
-- residue inert.


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
local viewHooked = false           -- ElementSizeCalculator + ApplyModelSceneScale
local guardLayoutInstalled = false -- CatalogShop product card Layout guards
local categoriesFocusHooked = false
local resizeButtonSnapHooked = false
local updateControlStates = nil    -- assigned on first slider creation

-- Preview:
local previewFrame = nil
local scrollBoxHooked = false      -- per-frame OnInteract + OnEnter/OnLeave wrap
local previewButtonsHooked = false -- CollapseButton + StorageButton OnClick
local hoveredFrame = nil
local inspectCursorActive = false

local lastPreviewEntryInfo = nil
local previewWasShownBeforeCollapse = false

-- Featured last:
local featuredLastHooked = false


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
  if not LP_config.houseEditorEnhancer_iconResizer then
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


-- ===== Preview: helpers =====

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
      and LP_config.houseEditorEnhancer_preview
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
  local savedWidth = LP_config.houseEditorEnhancer_previewWidth or DEFAULT_PREVIEW_WIDTH
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
  -- Parented to StoragePanel (not previewFrame) so its frame level can sit
  -- one below previewFrame's - a child would always render above its
  -- parent. Visibility is therefore independent, so we sync it with
  -- previewFrame via OnShow/OnHide.
  local clickBlocker = CreateFrame("Frame", nil, HouseEditorFrame.StoragePanel)
  clickBlocker:SetPoint("TOPLEFT", previewFrame, "TOPLEFT")
  clickBlocker:SetPoint("BOTTOMRIGHT", previewFrame, "BOTTOMRIGHT")
  clickBlocker:EnableMouse(true)
  clickBlocker:SetFrameLevel(previewFrame:GetFrameLevel() - 1)
  clickBlocker:Hide()
  previewFrame:HookScript("OnShow", function() clickBlocker:Show() end)
  previewFrame:HookScript("OnHide", function() clickBlocker:Hide() end)

  local credit = previewFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableTiny")
  credit:SetText(L["by Ludius Plus"])
  credit:SetPoint("BOTTOMLEFT", previewFrame, "BOTTOMLEFT", 6, 4)

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
    LP_config.houseEditorEnhancer_previewWidth = previewFrame:GetWidth()
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
    local saved = LP_config.houseEditorEnhancer_previewWidth or DEFAULT_PREVIEW_WIDTH
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
        and LP_config.houseEditorEnhancer_preview and self:HasValidData() then
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


-- ===== Events =====

-- Single eventFrame used both as the ADDON_LOADED trigger and as the
-- carrier for MODIFIER_STATE_CHANGED (registered only while preview is
-- active). OnEvent is installed unconditionally because ADDON_LOADED has
-- to land somewhere; the per-event bodies are self-gated.
local eventFrame = CreateFrame("Frame")


-- ===== Icon resizer: setup / teardown =====

local function SetupIconResizer()
  local container = GetContainer()
  if not container then return end

  -- Guard CatalogShop product card Layout methods against nil productInfo.
  -- Our RefreshCatalog calls scrollBox:Rebuild which re-initializes frames
  -- whose productInfo hasn't been populated yet. The base Layout and its
  -- subclass overrides (Wide, Small) all access self.productInfo directly.
  if not guardLayoutInstalled then
    local function GuardLayout(mixin)
      if not mixin or mixin._lpOriginalLayout then return end
      mixin._lpOriginalLayout = mixin.Layout
      mixin.Layout = function(self)
        if not self.productInfo then return end
        return mixin._lpOriginalLayout(self)
      end
    end
    GuardLayout(CatalogShopDefaultProductCardMixin)
    GuardLayout(WideCatalogShopProductCardMixin)
    GuardLayout(SmallCatalogShopProductCardMixin)
    guardLayoutInstalled = true
  end

  -- Install the calculator wrapper that scales decor/room/bundle tiles,
  -- plus an OnAcquiredFrame callback that re-scales each tile's ModelScene.
  -- The latter also covers panel-resize re-acquisitions from the frame pool.
  if not viewHooked then
    local scrollBox = container.ScrollBox
    local view = scrollBox and scrollBox:GetView()
    if not view or not view.GetElementSizeCalculator then return end

    local originalCalculator = view:GetElementSizeCalculator()
    if not originalCalculator then return end

    view:SetElementSizeCalculator(function(dataIndex, elementData)
      local w, h = originalCalculator(dataIndex, elementData)
      if elementData and SCALEABLE_TEMPLATE_KEYS[elementData.templateKey] and w and h then
        local s = GetScale()
        return w * s, h * s
      end
      return w, h
    end)

    scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnAcquiredFrame, function(_, frame)
      ApplyModelSceneScale(frame)
    end, scrollBox)

    viewHooked = true
  end

  local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
  if not storagePanel or not storagePanel.SearchBox then return end

  -- Snap to >=1 column when the user releases the panel's ResizeButton.
  if storagePanel.ResizeButton and not resizeButtonSnapHooked then
    storagePanel.ResizeButton:HookScript("OnMouseUp", function()
      if LP_config.houseEditorEnhancer_iconResizer then
        SnapPanelWidth()
      end
    end)
    resizeButtonSnapHooked = true
  end

  -- Re-scale whenever the user switches category: leaving "Featured"
  -- restores our custom size, entering "Featured" drops back to 1.0 (see
  -- GetScale). We hook Categories:SetFocus rather than the storage
  -- panel's OnCategoryFocusChanged because Categories:Initialize captures
  -- the callback via GenerateClosure - hooking OnCategoryFocusChanged on
  -- the panel would be bypassed. SetFocus is the universal entry point.
  if storagePanel.Categories and not categoriesFocusHooked then
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
      if not LP_config.houseEditorEnhancer_iconResizer then return end
      C_Timer.After(0, function()
        if not LP_config.houseEditorEnhancer_iconResizer then return end
        if not IsFeaturedFocused() then
          RefreshCatalog()
        end
        if updateControlStates then
          updateControlStates()
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
    categoriesFocusHooked = true
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
    updateControlStates = function()
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
      LP_config.houseEditorEnhancer_iconResizerSize = value
      updateControlStates()
      RefreshCatalog()
    end)
    slider:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
      GameTooltip:SetText(L["Resize decor item icons"], NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1, true)
      GameTooltip:AddLine(L["by Ludius Plus"], DISABLED_FONT_COLOR.r, DISABLED_FONT_COLOR.g, DISABLED_FONT_COLOR.b, 1, true)
      if IsFeaturedFocused() then
        GameTooltip_AddErrorLine(GameTooltip, L["Not working in the \"%1$s\" category. The \"Technically Advanced Editor\" (TAE) wants no part of %2$s!"]:format(C_HousingCatalog.GetCatalogCategoryInfo(Constants.HousingCatalogConsts.HOUSING_CATALOG_FEATURED_CATEGORY_ID).name, HOUSING_MARKET_HEARTHSTEEL_TOOLTIP))
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

  slider:SetValue(LP_config.houseEditorEnhancer_iconResizerSize or DEFAULT_SCALE)
  if updateControlStates then updateControlStates() end

  RefreshCatalog()
end


local function TeardownIconResizer()
  -- If the slider has never been set up in this session, there is nothing
  -- to revert: the view hook was never installed, GetScale returns 1.0,
  -- and the SearchBox still has its original anchor.
  if not slider then return end

  slider:Hide()
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


-- ===== Preview: setup / teardown =====

local function SetupPreview()
  local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
  if not storagePanel then return end

  local scrollBox = storagePanel.OptionsContainer and storagePanel.OptionsContainer.ScrollBox
  if not scrollBox then return end

  -- Register the OnAcquiredFrame callback. Keyed by an owner string so
  -- Teardown can unregister it specifically without touching other
  -- callbacks on the ScrollBox (e.g. the icon-resizer's ModelScene hook).
  if not scrollBoxHooked then
    scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnAcquiredFrame, function(_, frame)
      HookCatalogEntry(frame)
    end, "LudiusPlus_HouseEditorEnhancer_Preview")
    scrollBoxHooked = true
  end

  -- Hook any frames already acquired before we registered the callback,
  -- or acquired while the preview was disabled in-session.
  for _, frame in scrollBox:EnumerateFrames() do
    HookCatalogEntry(frame)
  end

  -- Remember-and-restore behavior around the StoragePanel collapse/expand:
  -- when the panel is collapsed we hide the preview (and stash what was
  -- showing), and when the panel is expanded again we bring it back.
  if not previewButtonsHooked then
    if storagePanel.CollapseButton then
      storagePanel.CollapseButton:HookScript("OnClick", function()
        if not LP_config.houseEditorEnhancer_preview then return end
        if previewFrame and previewFrame:IsShown() then
          previewWasShownBeforeCollapse = true
          lastPreviewEntryInfo = previewFrame.lastEntryInfo
          HidePreview()
        else
          previewWasShownBeforeCollapse = false
        end
      end)
    end
    if HouseEditorFrame.StorageButton then
      HouseEditorFrame.StorageButton:HookScript("OnClick", function()
        if not LP_config.houseEditorEnhancer_preview then return end
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
    previewButtonsHooked = true
  end

  eventFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
end


local function TeardownPreview()
  local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
  local scrollBox = storagePanel
    and storagePanel.OptionsContainer
    and storagePanel.OptionsContainer.ScrollBox
  if scrollBox and scrollBoxHooked then
    scrollBox:UnregisterCallback(ScrollBoxListMixin.Event.OnAcquiredFrame, "LudiusPlus_HouseEditorEnhancer_Preview")
    scrollBoxHooked = false
  end

  HidePreview()
  previewWasShownBeforeCollapse = false
  lastPreviewEntryInfo = nil

  eventFrame:UnregisterEvent("MODIFIER_STATE_CHANGED")

  if inspectCursorActive then
    ResetCursor()
    inspectCursorActive = false
  end
  hoveredFrame = nil
end


-- ===== Featured last: setup / teardown =====

-- Move Featured to the end of the layout by mutating layoutIndex on the
-- existing category frames. Idempotent: repeat calls without an
-- intervening Blizzard DisplayTopLevelCategories leave the ordering
-- stable (important for in-session toggle-on-twice). No-op if categories
-- haven't been populated yet - on cold /reload, SetupFeaturedLast can
-- run before Blizzard's first DisplayTopLevelCategories, and the hook
-- will pick up the work on that first natural call.
local function ApplyFeaturedLastOrdering(categories)
  if not categories or not categories.categoryFramesByID then return end

  local featuredFrame = categories.categoryFramesByID[Constants.HousingCatalogConsts.HOUSING_CATALOG_FEATURED_CATEGORY_ID]
  if not featuredFrame or not featuredFrame.layoutIndex then return end

  local featuredIndex = featuredFrame.layoutIndex
  local maxOther = 0
  for _, frame in pairs(categories.categoryFramesByID) do
    if frame ~= featuredFrame and frame.layoutIndex then
      if frame.layoutIndex > featuredIndex then
        frame.layoutIndex = frame.layoutIndex - 1
      end
      if frame.layoutIndex > maxOther then
        maxOther = frame.layoutIndex
      end
    end
  end
  featuredFrame.layoutIndex = maxOther + 1

  if categories.Layout then
    categories:Layout()
  end
end


local function SetupFeaturedLast()
  local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
  if not storagePanel or not storagePanel.Categories then return end

  if not featuredLastHooked then
    hooksecurefunc(storagePanel.Categories, "DisplayTopLevelCategories", function(self)
      if not LP_config.houseEditorEnhancer_featuredLast then return end
      ApplyFeaturedLastOrdering(self)
    end)

    hooksecurefunc(storagePanel, "OnMarketTabSelected", function(self, isUserAction)
      if not LP_config.houseEditorEnhancer_featuredLast then return end
      if isUserAction then
        self.Categories:SetFocus(Constants.HousingCatalogConsts.HOUSING_CATALOG_ALL_CATEGORY_ID)
        self:UpdateCategoryText()
      end
    end)

    featuredLastHooked = true
  end

  -- Apply immediately if categories are already populated. On cold
  -- /reload this is a no-op because Blizzard hasn't populated the
  -- category frames yet; our DisplayTopLevelCategories post-hook picks
  -- up the reorder on Blizzard's first natural call.
  ApplyFeaturedLastOrdering(storagePanel.Categories)
end


-- ===== Public API =====

function addon.SetupOrTeardownHouseEditorEnhancer()
  -- HouseEditor is LoadOnDemand; the ADDON_LOADED handler below re-runs
  -- this once it's loaded.
  if not HouseEditorFrame then return end

  if LP_config.houseEditorEnhancer_iconResizer then
    SetupIconResizer()
  else
    TeardownIconResizer()
  end

  if LP_config.houseEditorEnhancer_preview then
    SetupPreview()
  else
    TeardownPreview()
  end

  if LP_config.houseEditorEnhancer_featuredLast then
    SetupFeaturedLast()
  end
  -- No TeardownFeaturedLast: the featuredLast hooks can't be removed
  -- (hooksecurefunc) and we can't safely re-invoke DisplayTopLevelCategories
  -- ourselves (it needs a categoriesToShow argument). The hook bodies
  -- runtime-gate on LP_config.houseEditorEnhancer_featuredLast, so once
  -- the flag flips off they become inert; Blizzard's next natural
  -- DisplayTopLevelCategories call restores the default ordering.
end


-- ===== Event dispatch =====

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == "Blizzard_HouseEditor" then
      addon.SetupOrTeardownHouseEditorEnhancer()
    end
  elseif event == "MODIFIER_STATE_CHANGED" then
    if arg1 == "LCTRL" or arg1 == "RCTRL" then
      UpdateInspectCursor()
    end
  end
end)



-- There is no in-game string to directly use for "House Editor".
-- To get the translations right, let the translators extract the string to use from these:
-- EN: BINDING_NAME_HOUSING_TOGGLEEDITOR = "Enter/Exit House Editor"
-- DE: BINDING_NAME_HOUSING_TOGGLEEDITOR = "Hauseditor öffnen/verlassen"
-- FR: BINDING_NAME_HOUSING_TOGGLEEDITOR = "Ouvrir/quitter l’éditeur de maison"
-- IT: BINDING_NAME_HOUSING_TOGGLEEDITOR = "Entra/Esci dall'Editor della Casa"
-- ES: BINDING_NAME_HOUSING_TOGGLEEDITOR = "Abrir/cerrar el editor de casas"
-- MX: BINDING_NAME_HOUSING_TOGGLEEDITOR = "Entrar/Salir del Editor de casas"
-- BR: BINDING_NAME_HOUSING_TOGGLEEDITOR = "Entrar/Sair do editor da casa"
-- RU: BINDING_NAME_HOUSING_TOGGLEEDITOR = "Переключить редактор дома"
-- KR: BINDING_NAME_HOUSING_TOGGLEEDITOR = "집 편집기 들어가기/나가기"
-- TW: BINDING_NAME_HOUSING_TOGGLEEDITOR = "進入/退出房屋編輯器"
-- CN: BINDING_NAME_HOUSING_TOGGLEEDITOR = "进入/退出住宅编辑器"