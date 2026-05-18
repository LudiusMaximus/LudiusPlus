local _, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("LudiusPlus")

-- The Enhanced House Editor module bundles several independent features,
-- each with its own Setup/Teardown pair. SetupOrTeardownHouseEditorEnhancer
-- is a thin dispatcher that toggles each feature based on its config flag.
-- No hook, event, or frame is installed until its feature is first
-- enabled - a cold /reload with all flags off leaves zero footprint.
--
-- 1. ICON SIZE SLIDER and CTRL+WHEEL ZOOM (toggles:
--      houseEditorEnhancer_iconResizerSlider,
--      houseEditorEnhancer_iconResizerCtrlWheel)
--    Two independent ways to drive the same scaling state. The slider
--    flag controls a widget under the SearchBox; the CTRL+wheel flag
--    enables zoom by scrolling over the catalog tiles. Both share the
--    same stored size (houseEditorEnhancer_iconResizerSize) and either
--    one (or both) activating turns on our "parallel catalog" (a complete
--    rebuild of Blizzard's catalog scroll box to prevent taint) + scaling
--    hooks. The slider widget itself only appears when its specific flag
--    is on - CTRL+wheel-only mode keeps the SearchBox in its default
--    position.
--    Scaling is applied via ScrollTarget:SetScale on Blizzard's tiles
--    (Featured) and via per-tile SetSize on our parallel grid (all other
--    categories). The Featured catalog forces scale to 1.0 because its
--    wide bundle cards have fixed non-standard sizes that don't scale
--    meaningfully.
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
--    The per-instance OnInteract replacement is a taint-write on a
--    Blizzard frame, but it's scoped to DECOR-type catalog entries
--    and is only reachable from a user click event - DECOR frames never
--    enter the GetProductInfo path (that's BUNDLE/SMALL_PRODUCT in
--    the "Featured" category of the catalog tab), so the taint has no
--    path to a protected C function in practice.
--
-- 3. CHAIN PLACEMENT (toggle: houseEditorEnhancer_chainPlacement)
--    When the user commits a decor placement (click or drag-release)
--    while holding SHIFT, and at least one copy of the same decor is
--    still in storage, immediately start a new placement of the same
--    item. Avoids round-tripping through the catalog UI for repeated
--    placements of the same decor. A small icon at the cursor shows the
--    remaining storage count while SHIFT is held. Implemented by hooking
--    C_HousingBasicMode.StartPlacingNewDecor (to remember the entry)
--    and FinishPlacingNewDecor (to fire the chain on commit).
--
-- Hooks installed via hooksecurefunc can't be removed; where we use
-- them, Setup installs once per session and the hook body runtime-gates
-- on its config flag so in-session disable is instant. Teardown removes
-- whatever it can (callbacks, events, frames) and leaves the idempotent
-- residue inert.
--
--
-- ============================================================================
-- TAINT LESSONS LEARNED (file these in your head before touching this code)
-- ============================================================================
--
-- This module's scroll box is HouseEditorFrame.StoragePanel.OptionsContainer.
-- ScrollBox. It uses ScrollBoxListMixin and a ScrollBoxListSequenceView.
-- The Featured catalog category populates the scroll box with frames whose
-- initializer (HousingMarketProductDisplayMixin:Init) calls the PROTECTED
-- C function C_CatalogShop.GetProductInfo. If anything we do leaves the
-- scroll box's internal state in a tainted condition before
-- RestoreFocusState -> SetFocus -> SetDataProvider -> FullUpdate -> Update
-- -> InvokeInitializers runs, that protected call fires
-- ADDON_ACTION_FORBIDDEN attributed to LudiusPlus. The original repro
-- (pre-parallel-catalog) was: /reload -> open editor -> resize the panel
-- -> click Market tab (which defaults to Featured). The parallel catalog
-- replaces Blizzard's grid on non-Featured tabs, sidestepping the trap;
-- the repro is kept here as the canonical example to keep the rules
-- below grounded in a concrete failure mode.
--
-- 1. HOOK MECHANISMS - WHAT'S SAFE
-- ----------------------------------------------------------------------------
-- * hooksecurefunc(target, "method", fn) - taint-safe by engine design.
--   The wrapper uses securecall semantics so the original runs cleanly
--   even when invoked from tainted code. Use this for everything you can.
-- * frame:HookScript("OnX", fn) - same engine-level isolation, for frame
--   scripts. Safe.
-- * Empirically verified: hooksecurefunc(scrollBox, "Update", emptyFn) on
--   our exact scroll box, with the hook body doing nothing, does NOT
--   cause FORBIDDEN. Hooks themselves do not induce taint.
--
-- 2. HOOK MECHANISMS - WHAT'S NOT SAFE
-- ----------------------------------------------------------------------------
-- * RegisterCallback on a Blizzard CallbackRegistry is a plain Lua table
--   write into target.callbacks[event][owner]. Our addon-defined function
--   becomes a tainted entry; when TriggerEvent iterates the table, the
--   tainted read propagates. For OnUpdate specifically this poisons Update's
--   own state (SetUpdateLocked at ScrollBox.lua:793 writes the tainted
--   state into self.isUpdateLocked) and contaminates the next Update.
--   OnAcquiredFrame's downstream happens not to hit a protected function,
--   so the preview feature's RegisterCallback is OK in practice - but it's
--   a latent risk.
--
-- 3. THE REAL TRAP - BLIZZARD FRAME METHODS WITH HIDDEN WRITES
-- ----------------------------------------------------------------------------
-- Some Blizzard frame methods that LOOK like pure reads actually trigger
-- internal writes (lazy layout calculations / cache fills). Invoked from
-- addon-tainted code on a scroll-box-managed frame, those internal writes
-- get tainted and the scroll box reads them during its next Update.
--
--   TAINTED when called on scroll-box-managed frames from addon code:
--     f:GetSize()
--     f:GetWidth()    (assume GetHeight too)
--     ...assume any size/geometry accessor that needs a layout pass
--
--   SAFE on the same frames from the same context:
--     f:GetName()
--     f:GetNumPoints()
--     f:GetPoint(i)
--     tostring(f)
--     iteration via scrollBox:EnumerateFrames()
--
-- Bisected by stepping a hooksecurefunc'd diagnostic timer through each
-- line one at a time. The pattern is consistent: methods that compute
-- geometry trigger taint; methods that read static or pre-computed fields
-- don't. Writes (SetPoint, SetSize, etc.) are inherently more dangerous
-- and have not been verified - assume tainted until proven otherwise.
--
-- 4. INSTANCE vs MIXIN HOOK TARGETS
-- ----------------------------------------------------------------------------
-- WoW's XML mixin="X" attribute COPIES the mixin's methods to the frame at
-- creation time. By the time our addon's ADDON_LOADED runs, frames already
-- have their own copies. hooksecurefunc on the MIXIN table (e.g.
-- ScrollBoxListMixin) will not fire for those existing instances - the
-- read of self.Method finds the instance's copy, not the mixin's wrapper.
-- ALWAYS hook the INSTANCE (e.g. container.ScrollBox), not the mixin,
-- unless you can guarantee you ran before frame creation.
--
-- Exception: methods that are stored elsewhere by Blizzard at view-setup
-- time (e.g. scrollBox.OnViewAcquiredFrame, which the view captures as a
-- callback reference) can't be hooked at the instance level after the
-- fact either - the view still calls the captured original reference.
-- For those, RegisterCallback is unfortunately the only option.




local math_log = _G.math.log






-- ===== Icon resizer: constants =====

local MIN_SCALE = 0.5
local MAX_SCALE = 3.55
local STEP = 0.005

-- Default SearchBox anchor y-offset in Blizzard's XML is -20. We shift
-- it upwards to make vertical room for the slider row underneath.
local SEARCH_BOX_DEFAULT_Y = -20
local SEARCH_BOX_SHIFTED_Y = -13

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
local categoriesFocusHooked = false
local updateControlStates = nil    -- assigned on first slider creation
local refreshParallelOnSliderChange = nil  -- forward-declared; assigned by parallel catalog setup

-- Preview:
local previewFrame = nil
local scrollBoxHooked = false      -- per-frame OnInteract + OnEnter/OnLeave wrap
local previewButtonsHooked = false -- CollapseButton + StorageButton OnClick
local hoveredFrame = nil
local inspectCursorActive = false

local lastPreviewEntryInfo = nil
local previewWasShownBeforeCollapse = false


-- Parallel Catalog (Storage tab + non-Featured Market replacement):
local parallelFrame = nil
local parallelChild = nil
local parallelScrollBar = nil
local parallelTabHooked = false
local parallelResultsHooked = false
local parallelCategoryHooked = false
local scrollBoxOriginalAnchors = nil  -- captured once on first move
local scrollBarOriginalAnchors = nil  -- ditto for the (Minimal)ScrollBar sibling

-- Tile grid constants. Declared up here (rather than near RefreshTileGrid)
-- so they're in scope for EnsureParallelFrame and CreateTile, which are
-- defined earlier in the file.
local TILE_WIDTH = 97
local TILE_HEIGHT = 97
local TILE_SPACING = 5
local TOP_PADDING = 0
local OVERSCAN_ROWS = 1
local EDGE_FADE_LENGTH = 75  -- matches Blizzard housing catalog edge fade

-- Tile pool (reusable Button frames) and current active list.
-- AcquireTile pops from the pool or creates fresh; ReleaseAllTiles hides
-- the current actives and pushes them back so the next render reuses them.
local tilePool = {}
local activeTiles = {}

-- Forward declaration: WireParallelScroll is defined later in this file
-- (it needs RefreshTileGrid in scope), but ShowParallelCatalog (defined
-- earlier) needs to call it. Without this local-declaration, ShowParallelCatalog's
-- body would resolve `WireParallelScroll` to a nil global at call time.
local WireParallelScroll

-- Diagnostic: kept commented out as a debugging archive. See the
-- "Scroll box diagnostic" block lower in this file.
-- local scrollBoxDiagHooked = false
-- local diagPending = false


-- ===== Icon resizer: helpers =====

-- The Featured catalog category uses wide bundle cards with fixed,
-- non-standard sizes. Scaling them via ScrollTarget:SetScale just makes
-- them overflow the panel. We skip our scaling in Featured (both the
-- slider AND the CTRL+wheel zoom). Everywhere else (storage tab and all
-- non-Featured market categories) scaling applies normally.
--
-- Pure read of Blizzard-set state via the Categories mixin method; no
-- Lua field write, no taint.
local function IsFeaturedCategoryFocused()
  local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
  local categories = storagePanel and storagePanel.Categories
  if not categories or not categories.IsFeaturedCategoryFocused then return false end
  return categories:IsFeaturedCategoryFocused()
end


-- True if any of the icon-resizing features is enabled. The slider UI and
-- the CTRL+wheel handler are two independent ways to drive the same
-- resize state, so the parallel catalog and the scaling hooks must
-- activate when EITHER is on.
local function IsAnyIconResizingActive()
  return LP_config.houseEditorEnhancer_iconResizerSlider
      or LP_config.houseEditorEnhancer_iconResizerCtrlWheel
end

local function GetScale()
  if not IsAnyIconResizingActive() then
    return 1.0
  end
  if IsFeaturedCategoryFocused() then
    return 1.0
  end
  return LP_config.houseEditorEnhancer_iconResizerSize or 1.0
end


local function GetContainer()
  return HouseEditorFrame
    and HouseEditorFrame.StoragePanel
    and HouseEditorFrame.StoragePanel.OptionsContainer
end


-- Apply the current slider scale to the ScrollTarget so tiles appear
-- visually smaller or larger without touching elementSizeCalculator or
-- calling Rebuild (both would taint scroll-view Lua fields that Blizzard's
-- Update reads, causing ADDON_ACTION_FORBIDDEN via GetProductInfo).
-- Column count is unaffected; Blizzard's widthSnapMultiplier (102 px) still
-- controls column snapping on panel resize.
local function RefreshCatalog()
  local container = GetContainer()
  if not container or not container.ScrollBox then return end
  local scrollBox = container.ScrollBox
  if scrollBox.ScrollTarget then
    scrollBox.ScrollTarget:SetScale(GetScale())
  end
end


-- ===== Preview: helpers =====

local function HidePreview()
  if not previewFrame then return end
  previewFrame:Hide()
  previewFrame:ClearPreviewData()
end


-- Predicate: is hoveredFrame a tile our CTRL+click preview can act on?
-- Two flavors:
--   - HousingCatalogEntryMixin-based tiles (Storage, non-Featured Market,
--     and bundle-item decor tiles in Featured) have HasValidData.
--   - HousingMarketProductDisplayMixin-based tiles (Featured Small Product
--     cards) don't; we use the same elementData check as the StartPreview
--     hook so the inspect cursor and the click both light up on the same
--     set of frames (single-decor Small Products, not Bundle wide cards).
local function IsHoveredFramePreviewable()
  local f = hoveredFrame
  if not f then return false end
  if type(f.HasValidData) == "function" then
    return f:HasValidData()
  end
  if f.elementData and f.elementData.canPreview
     and f.elementData.entryVariantID
     and f.elementData.entryVariantID.entryType == Enum.HousingCatalogEntryType.Decor then
    return true
  end
  return false
end

-- Show the inspect cursor while CTRL is held over a previewable tile.
-- We track inspectCursorActive so ResetCursor only runs if *we* set it -
-- otherwise we'd clobber cursors set by other systems (drag-and-drop,
-- spell targeting, etc.).
local function UpdateInspectCursor()
  local shouldShow = LP_config.houseEditorEnhancer_preview
      and IsControlKeyDown()
      and IsHoveredFramePreviewable()
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

-- Hover tracker: set hoveredFrame on enter, clear on leave, and refresh
-- the inspect cursor in both cases. Shared by HookCatalogEntry's two
-- branches (HousingCatalogEntryMixin tiles and HousingMarketProductDisplayMixin
-- tiles) since their tracking logic is identical. The parallel
-- catalog's own tiles use the same pattern inline because they also need
-- to drive their hover-bg texture and tooltip in the same script.
local function WireInspectCursorOnHover(frame)
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

  if type(frame.OnInteract) == "function" then
    -- HousingCatalogEntryMixin path: Storage tab + non-Featured Market
    -- entries + bundle-item decor tiles in Featured (CATALOG_ENTRY_DECOR
    -- template). OnInteract funnels both OnClick and OnDragStart, so
    -- wrapping it once covers both.
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
    -- the user pressing CTRL after hovering.
    WireInspectCursorOnHover(frame)

  elseif type(frame.StartPreview) == "function" then
    -- HousingMarketProductDisplayMixin path: Featured tab Small Product
    -- tiles and Bundle wide cards. We can't wrap OnClick on these - the
    -- XML uses <OnClick method="OnClick"/> which captures the method
    -- reference at frame creation (same trap as hooksecurefunc on a
    -- mixin), so reassigning frame.OnClick is silently a no-op against
    -- the script handler that's already bound. Instead wrap StartPreview,
    -- which Blizzard's OnClick calls via `self:StartPreview()` - a
    -- dynamic method lookup that DOES see our instance-level override.
    --
    -- We only intercept SINGLE decor items: the canPreview +
    -- entryVariantID.entryType == Decor guard skips bundle wide cards
    -- (their elementData has decorEntries, no single entryVariantID)
    -- and any non-decor previewables. Without CTRL held, we fall through
    -- to Blizzard's StartPreview (the in-game placement preview).
    local originalStartPreview = frame.StartPreview
    frame.StartPreview = function(self)
      -- IsMouseButtonDown distinguishes click (button already released by
      -- the time OnClick fires, since registerForClicks is "...ButtonUp")
      -- from drag (button still held when OnDragStart fires). We only
      -- want to intercept clicks; CTRL+drag should fall through to the
      -- normal drag-place behavior.
      if IsControlKeyDown() and not IsMouseButtonDown("LeftButton")
         and LP_config.houseEditorEnhancer_preview
         and self.elementData and self.elementData.canPreview
         and self.elementData.entryVariantID
         and self.elementData.entryVariantID.entryType == Enum.HousingCatalogEntryType.Decor then
        local entryInfo = C_HousingCatalog.GetCatalogEntryInfo(self.elementData.entryVariantID)
        if entryInfo then
          ShowPreviewForEntry({ entryInfo = entryInfo })
          return
        end
      end
      return originalStartPreview(self)
    end

    -- Hover tracking for the inspect cursor. UpdateInspectCursor's
    -- previewable check accepts both HasValidData-style frames and
    -- elementData/canPreview-style market product frames, so the
    -- magnifying-glass cursor appears on hovered single-decor small
    -- products too. Bundle wide cards (no entryVariantID on elementData)
    -- correctly fall through and don't trigger the cursor change.
    WireInspectCursorOnHover(frame)
  end

  frame._lpHooked = true
end


-- ===== Events =====

-- Single eventFrame used both as the ADDON_LOADED trigger and as the
-- carrier for MODIFIER_STATE_CHANGED (registered only while preview is
-- active). OnEvent is installed unconditionally because ADDON_LOADED has
-- to land somewhere; the per-event bodies are self-gated.
local eventFrame = CreateFrame("Frame")


-- ===== Icon resizer: setup / teardown =====

-- Forward declaration: SetupIconResizer's CTRL+wheel-only branch needs to
-- call HideIconResizerSlider, but that helper is defined after this block
-- so TeardownIconResizer (which sits next to it) can share it.
local HideIconResizerSlider

local function SetupIconResizer()
  local container = GetContainer()
  if not container then return end

  local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
  if not storagePanel or not storagePanel.SearchBox then return end

  -- Re-scale whenever the user switches category or tab. We hook
  -- Categories:SetFocus rather than the storage panel's
  -- OnCategoryFocusChanged because Categories:Initialize captures the
  -- callback via GenerateClosure - hooking OnCategoryFocusChanged on the
  -- panel would be bypassed. SetFocus is the universal entry point for
  -- both category changes and tab changes (called from OnTabChanged).
  if storagePanel.Categories and not categoriesFocusHooked then
    hooksecurefunc(storagePanel.Categories, "SetFocus", function()
      if not IsAnyIconResizingActive() then return end
      -- Featured category forces ScrollTarget to 1.0 (slider is ignored
      -- there because bundle wide cards have fixed non-standard sizes);
      -- everywhere else re-applies the slider's scale.
      if IsFeaturedCategoryFocused() then
        local scrollBox = container.ScrollBox
        if scrollBox and scrollBox.ScrollTarget then
          scrollBox.ScrollTarget:SetScale(1.0)
        end
      else
        RefreshCatalog()
      end
      if updateControlStates then updateControlStates() end
    end)
    categoriesFocusHooked = true
  end

  -- Slider UI only shows when the slider flag is specifically on. The
  -- CTRL+wheel-only mode (iconResizer off, iconResizerCtrlWheel on) still
  -- needs the scaling hook above, but no slider widget, no SearchBox
  -- shift. Hand off to the slider-UI teardown helper in that case and
  -- skip the slider-creation block entirely.
  if not LP_config.houseEditorEnhancer_iconResizerSlider then
    HideIconResizerSlider()
    RefreshCatalog()
    return
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
      local featured = IsFeaturedCategoryFocused()
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
      if refreshParallelOnSliderChange then refreshParallelOnSliderChange() end
    end)
    slider:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
      GameTooltip:SetText(L["Resize decor item icons"], NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1, true)
      GameTooltip:AddLine(L["by Ludius Plus"], DISABLED_FONT_COLOR.r, DISABLED_FONT_COLOR.g, DISABLED_FONT_COLOR.b, 1, true)
      if IsFeaturedCategoryFocused() then
        GameTooltip_AddErrorLine(GameTooltip, L["Not working in the \"%1$s\" category. The \"Thoughtfully Augmented Editor\" (TAE) wants no part of %2$s!"]:format(C_HousingCatalog.GetCatalogCategoryInfo(Constants.HousingCatalogConsts.HOUSING_CATALOG_FEATURED_CATEGORY_ID).name, HOUSING_MARKET_HEARTHSTEEL_TOOLTIP))
      end
      GameTooltip:Show()
    end)
    slider:SetScript("OnLeave", function() GameTooltip:Hide() end)

    resetButton:SetScript("OnClick", function()
      slider:SetValue(DEFAULT_SCALE)
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


-- Shared by TeardownIconResizer and the CTRL+wheel-only path of
-- SetupIconResizer: hide the slider/label/reset and restore the SearchBox
-- to its original (un-shifted) position. Assigned to the forward-declared
-- local at top of section.
HideIconResizerSlider = function()
  if not slider then return end  -- never created this session

  slider:Hide()
  if sliderLabel then sliderLabel:Hide() end
  if resetButton then resetButton:Hide() end

  local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
  if storagePanel and storagePanel.SearchBox then
    local searchBox = storagePanel.SearchBox
    searchBox:ClearAllPoints()
    searchBox:SetPoint("TOPLEFT", storagePanel, "TOPLEFT", 20, SEARCH_BOX_DEFAULT_Y)
    searchBox:SetPoint("TOPRIGHT", storagePanel, "TOPRIGHT", -160, SEARCH_BOX_DEFAULT_Y)
  end
end

local function TeardownIconResizer()
  -- If the slider has never been set up in this session there is nothing
  -- to revert: GetScale returns 1.0 and the SearchBox has its original anchor.
  if not slider then return end
  HideIconResizerSlider()
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

  -- Catch newly-acquired frames so we can wrap their OnInteract for
  -- CTRL+Click preview. We use RegisterCallback rather than hooksecurefunc
  -- here despite the taint considerations because the alternatives don't
  -- work: hooksecurefunc on ScrollBoxListMixin.OnViewAcquiredFrame is
  -- mixin-level and the scroll box instance has its own copy from before
  -- our addon loaded; hooksecurefunc on the instance's OnViewAcquiredFrame
  -- also fails because the view registered the original function reference
  -- as its callback at view-creation time and that captured reference
  -- bypasses any instance-level wrapper we install later.
  -- RegisterCallback for OnAcquiredFrame is empirically safe in this
  -- specific call site, unlike OnUpdate: the downstream-write after
  -- OnAcquiredFrame fires (SetAcquireLocked(false) on the view) doesn't
  -- result in tainted state being read by InvokeInitializers's path to
  -- GetProductInfo. Keyed by an owner string so Teardown can unregister.
  if not scrollBoxHooked then
    scrollBox:RegisterCallback(
      ScrollBoxListMixin.Event.OnAcquiredFrame,
      function(_, frame)
        HookCatalogEntry(frame)
      end,
      "LudiusPlus_HouseEditorEnhancer_Preview")
    scrollBoxHooked = true
  end

  -- Hook any frames already acquired before we registered the callback,
  -- or acquired while the preview was disabled in-session.
  for _, frame in scrollBox:EnumerateFrames() do
    HookCatalogEntry(frame)
  end

  -- Remember-and-restore behavior around the StoragePanel collapse/expand:
  -- when the panel is collapsed, we hide the preview (and stash what was
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


-- ===== Parallel Catalog UI =====
--
-- A from-scratch catalog grid that replaces Blizzard's
-- OptionsContainer.ScrollBox on the Storage tab AND on non-"Featured" Market
-- (in-game called "Catalog") categories, so we can do tile wrapping and
-- own-controlled scrolling without fighting Blizzard's taint-sensitive
-- internals. The slider drives tile size AND columns-per-row. The "Featured"
-- category uses fixed-size bundle cards we don't lay out, so we leave
-- Blizzard's grid in place there.
--
-- Architecture: Blizzard's ScrollBox is relocated off-screen (not hidden -
-- Hide() taints internal state); our parallelFrame takes its place. A
-- pooled tile grid is virtualized against the visible row range. Scroll
-- bar uses Blizzard's MinimalScrollBar template wired manually (not via
-- ScrollUtil) so no callback-registry writes touch a Blizzard mixin.
-- Click/drag dispatch branches on C_HousingDecor.IsPreviewState() to call
-- StartPlacingPreviewDecor (Market) vs StartPlacingNewDecor (Storage).

local function EnsureParallelFrame()
  if parallelFrame then return parallelFrame end
  local container = GetContainer()
  if not container or not container.ScrollBox then return end

  -- Plain Frame (NOT ScrollFrame): ScrollFrame's scroll-child rendering
  -- path bypasses SetAlphaGradient. Blizzard's own ScrollBox is also a
  -- plain frame with a manually-repositioned "ScrollTarget" child; we do
  -- the same - track scroll position ourselves and shift parallelChild's
  -- anchor by that amount, clipped by parallelFrame.
  parallelFrame = CreateFrame("Frame", "LudiusPlusParallelCatalog", container)
  parallelFrame:EnableMouseWheel(true)
  parallelFrame:EnableMouse(true)         -- swallow clicks
  parallelFrame:SetClipsChildren(true)
  -- Required for SetAlphaGradient to take effect on this frame and its
  -- child frames. https://warcraft.wiki.gg/wiki/API_Frame_SetAlphaGradient
  -- IMPORTANT: flatten only the outer frame. Flattening parallelChild too
  -- breaks gradient propagation - the children render but never receive
  -- the gradient's per-pixel alpha.
  parallelFrame:SetFlattensRenderLayers(true)
  parallelFrame.lpScroll = 0  -- our manual scroll offset (pixels, >=0)
  -- Anchors are applied in ShowParallelCatalog using the captured original
  -- ScrollBox anchors. We don't anchor to container.ScrollBox here because
  -- once we move that off-screen, anything anchored to it follows.

  parallelChild = CreateFrame("Frame", nil, parallelFrame)
  parallelChild:SetSize(1, 1) -- real size set in RefreshTileGrid
  -- TOPLEFT-anchored to parallelFrame; RefreshTileGrid shifts it by the
  -- current scroll value (positive Y in WoW = upward) so content rolls up
  -- as the user scrolls down. parallelFrame:SetClipsChildren clips the
  -- portions that move outside the visible bounds.
  parallelChild:SetPoint("TOPLEFT", parallelFrame, "TOPLEFT", 0, 0)

  -- Vertical scroll bar using Blizzard's MinimalScrollBar template - same
  -- visuals as the bar we displaced (track + thumb + Back/Forward arrows).
  -- Parented to container (NOT parallelFrame) so it sits in the 23px right-
  -- margin slot reserved by the captured ScrollBox anchors (BOTTOMRIGHT x=-23)
  -- and isn't clipped by parallelFrame's SetClipsChildren. Anchors match
  -- Blizzard's housing catalog ScrollBar (Blizzard_HousingCatalogTemplates.xml:46-52):
  --   TOP    -> container.TOP
  --   LEFT   -> parallelFrame.RIGHT + 5
  --   BOTTOM -> container.BOTTOM
  -- We don't wire it to a ScrollBox via ScrollUtil; instead we drive
  -- SetScrollPercentage/SetVisibleExtentPercentage manually from
  -- RefreshTileGrid and listen for OnScroll to update our scroll position.
  parallelScrollBar = CreateFrame("EventFrame", "LudiusPlusParallelScrollBar", container, "MinimalScrollBar")
  parallelScrollBar:SetPoint("TOP", container, "TOP", 0, 0)
  parallelScrollBar:SetPoint("LEFT", parallelFrame, "RIGHT", 5, 0)
  parallelScrollBar:SetPoint("BOTTOM", container, "BOTTOM", 0, 0)
  -- Init args: visibleExtentPercentage, panExtentPercentage. Real values
  -- get set continually in RefreshTileGrid; this is just initial state.
  parallelScrollBar:Init(1, 0)

  -- Scroll handlers wired in WireParallelScroll (after RefreshTileGrid is in scope).

  return parallelFrame
end


-- Guard mirroring HousingCatalogDecorEntryMixin:TypeSpecificOnInteract
-- (Blizzard_HousingCatalogEntry.lua:590-622) so our parallel tiles surface
-- the same popups and error messages Blizzard's tiles do before placement
-- starts: HOUSING_MAX_DECOR_REACHED popup at budget cap; indoor/outdoor
-- mismatch via UIErrorsFrame; silent bails for inactive editor / empty
-- storage. Skips the bundle-item check because our parallel catalog
-- filters to Decor/Room entries only.
local function CanStartPlacing(entryInfo)
  if not C_HouseEditor.IsHouseEditorActive() then return false end
  if not entryInfo then return false end

  local preview = C_HousingDecor and C_HousingDecor.IsPreviewState
                  and C_HousingDecor.IsPreviewState()
  if not preview then
    local stored = Blizzard_HousingCatalogUtil
                   and Blizzard_HousingCatalogUtil.GetEntryNumStored
                   and Blizzard_HousingCatalogUtil.GetEntryNumStored(entryInfo)
    if (stored or 0) <= 0 then return false end
  end

  if C_HousingDecor.HasMaxPlacementBudget and C_HousingDecor.HasMaxPlacementBudget() then
    local placed = C_HousingDecor.GetSpentPlacementBudget()
    local maxDecor = C_HousingDecor.GetMaxPlacementBudget()
    if placed and maxDecor and placed >= maxDecor then
      StaticPopup_Show("HOUSING_MAX_DECOR_REACHED")
      return false
    end
  end

  if C_Housing and C_Housing.IsInsideHouse then
    local indoors = C_Housing.IsInsideHouse()
    if indoors and not entryInfo.isAllowedIndoors then
      UIErrorsFrame:AddMessage(HOUSING_DECOR_ONLY_PLACEABLE_OUTSIDE_ERROR, RED_FONT_COLOR:GetRGBA())
      return false
    elseif (not indoors) and not entryInfo.isAllowedOutdoors then
      UIErrorsFrame:AddMessage(HOUSING_DECOR_ONLY_PLACEABLE_INSIDE_ERROR, RED_FONT_COLOR:GetRGBA())
      return false
    end
  end

  return true
end


-- Placement dispatcher used by both the click and drag handlers. Mirrors
-- Blizzard's branch in HousingCatalogEntry.lua:625-637: preview state ->
-- StartPlacingPreviewDecor (Market browse), otherwise StartPlacingNewDecor
-- (Storage, owned item). Branching on IsPreviewState (not on tab) makes
-- this robust to edge cases where the editor's preview/storage state and
-- the visible tab can briefly disagree.
local function StartPlacingForEntry(evi)
  local preview = C_HousingDecor and C_HousingDecor.IsPreviewState
                  and C_HousingDecor.IsPreviewState()
  if preview then
    C_HousingBasicMode.StartPlacingPreviewDecor(evi.recordID)
  else
    C_HousingBasicMode.StartPlacingNewDecor(evi)
  end
end


-- Tile factory + pool. Tile structure matches Blizzard's
-- BaseHousingCatalogEntryTemplate (Blizzard_HousingCatalogEntry.xml:38-103):
--   tile: 97x97 Button
--   bg:   house-chest-list-item-default atlas, fills the tile
--   icon: 5px inset on each side
-- Click  -> deferred StartPlacingForEntry (mouse-up has fired; defer
--           dodges Blizzard's auto-commit on the current mouse-up).
-- Drag   -> immediate StartPlacingForEntry (mouse still down; the drag's
--           mouse-up naturally commits the placement).
local function CreateTile()
  local tile = CreateFrame("Button", nil, parallelChild)
  tile:SetSize(97, 97)

  tile.bg = tile:CreateTexture(nil, "BACKGROUND")
  tile.bg:SetAllPoints()
  tile.bg:SetAtlas("house-chest-list-item-default")

  -- Hover glow: same tile-border atlas, additive blend mode, 0.75 alpha.
  -- Matches BaseHousingCatalogEntryTemplate.HoverBackground
  -- (Blizzard_HousingCatalogEntry.xml:51).
  tile.hoverBg = tile:CreateTexture(nil, "BACKGROUND")
  tile.hoverBg:SetAllPoints()
  tile.hoverBg:SetAtlas("house-chest-list-item-default")
  tile.hoverBg:SetAlpha(0.75)
  tile.hoverBg:SetBlendMode("ADD")
  tile.hoverBg:Hide()

  tile.icon = tile:CreateTexture(nil, "ARTWORK")
  tile.icon:SetPoint("TOPLEFT", tile, "TOPLEFT", 5, -5)
  tile.icon:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -5, 5)

  -- Overlay decorations mirroring BaseHousingCatalogEntryTemplate + DecorEntryTemplate
  -- (Blizzard_HousingCatalogEntry.xml:55-82, :107-111). Hidden by default;
  -- UpdateTileVisuals shows/hides based on entry info & variant state.

  -- CustomizeIcon: palette icon BOTTOMLEFT, shown when entry is dyeable
  -- AND no dyes are currently applied to this variant.
  tile.customizeIcon = tile:CreateTexture(nil, "ARTWORK")
  tile.customizeIcon:SetAtlas("housing-dyable-palette-icon", true)
  tile.customizeIcon:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 12, 6)
  tile.customizeIcon:Hide()

  -- InfoText: BOTTOMRIGHT number - owned quantity (Storage) or formatted
  -- price (Market). UpdateTileVisuals chooses based on preview state.
  tile.infoText = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  tile.infoText:SetHeight(20)
  tile.infoText:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -9, 7)

  -- InfoIcon: trophy icon at BOTTOMRIGHT (replaces InfoText when the
  -- entry is a unique trophy).
  tile.infoIcon = tile:CreateTexture(nil, "OVERLAY")
  tile.infoIcon:SetAtlas("house-chest-trophy-icon", true)
  tile.infoIcon:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -11, 9)
  tile.infoIcon:Hide()

  -- DyeDisplay: up to 3 dye-drop swatches at BOTTOMLEFT, vertex-colored
  -- per the variant's dye slot colors.
  tile.dyeIcons = {}
  for i = 1, 3 do
    local dye = tile:CreateTexture(nil, "ARTWORK")
    dye:SetAtlas("dye-drop_32", true)
    dye:SetSize(16, 16)
    if i == 1 then
      dye:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 10, 8)
    else
      dye:SetPoint("LEFT", tile.dyeIcons[i - 1], "RIGHT", -6, 0)
    end
    dye:Hide()
    tile.dyeIcons[i] = dye
  end

  -- HasValidData mirrors HousingCatalogEntryMixin:HasValidData so the
  -- preview feature's UpdateInspectCursor can validate our tile the same
  -- way it validates Blizzard's tiles (it does hoveredFrame:HasValidData()).
  -- Our tiles only render when we have full entryInfo, so this is enough.
  tile.HasValidData = function(self) return self.entryInfo ~= nil end

  tile:RegisterForClicks("LeftButtonUp")
  tile:RegisterForDrag("LeftButton")
  tile:SetScript("OnClick", function(self, button)
    if button ~= "LeftButton" then return end
    if not self.entryVariantID or not self.entryVariantID.entryType or not self.entryVariantID.recordID then return end
    -- CTRL+click: show the LudiusPlus preview frame instead of starting
    -- placement, when the preview feature is enabled. Mirrors the
    -- equivalent CTRL+click branch added by HookCatalogEntry to Blizzard's
    -- own tiles (see SetupPreview / HookCatalogEntry). ShowPreviewForEntry
    -- only reads `.entryInfo` from its argument, which we stash on the
    -- tile during RefreshTileGrid.
    if IsControlKeyDown() and LP_config.houseEditorEnhancer_preview
       and self.entryInfo then
      ShowPreviewForEntry(self)
      return
    end
    if not CanStartPlacing(self.entryInfo) then return end
    -- Defer to the next frame so this click's mouse-up is fully processed
    -- BEFORE we enter placement mode. Otherwise Blizzard's
    -- HouseEditorBasicDecorMode GLOBAL_MOUSE_UP handler sees us already
    -- placing decor and immediately commits because commitNewDecorOnMouseUp
    -- defaults to true. Blizzard's own click flow (HousingCatalogEntry.lua:657)
    -- sets that flag to false before calling StartPlacing; deferring achieves
    -- the same effect without writing to a Blizzard frame's Lua state.
    C_Timer.After(0, function()
      StartPlacingForEntry(self.entryVariantID)
    end)
  end)
  tile:SetScript("OnDragStart", function(self)
    if not self.entryVariantID or not self.entryVariantID.entryType or not self.entryVariantID.recordID then return end
    if not CanStartPlacing(self.entryInfo) then return end
    -- No defer here: mouse is still down. Calling StartPlacing right now
    -- attaches the placement to the cursor mid-drag, and the drag's own
    -- mouse-up commits it via commitNewDecorOnMouseUp's default value of
    -- true - which is exactly what Blizzard's drag path also does
    -- (HousingCatalogEntry.lua:657 sets it to isDrag, i.e. true on drag).
    -- WoW button input is click-or-drag (mutually exclusive), so OnClick
    -- won't fire for the same gesture, no race with the deferred path.
    StartPlacingForEntry(self.entryVariantID)
  end)

  tile:SetScript("OnEnter", function(self)
    self.hoverBg:Show()
    -- Inspect-cursor tracking for the preview feature - same pattern
    -- HookCatalogEntry uses on Blizzard's tiles. Always set hoveredFrame;
    -- UpdateInspectCursor internally gates on LP_config.houseEditorEnhancer_preview
    -- so this is a no-op when the preview feature is off.
    hoveredFrame = self
    UpdateInspectCursor()
    if not self.entryVariantID then return end
    local info = C_HousingCatalog.GetCatalogEntryInfo(self.entryVariantID)
    if not info or not info.name then return end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, 0)

    -- Title line: name (in item-quality color) on the left, placement
    -- cost on the right. Mirrors HousingCatalogDecorEntryMixin:AddTooltipTitle
    -- (Blizzard_HousingCatalogEntry.lua:476-486).
    local dyeNames = info.customizations
    local isDyed = dyeNames and #dyeNames > 0
    local name = isDyed and HOUSING_DECOR_DYED_NAME_FORMAT:format(info.name) or info.name
    local placementCost = info.placementCost
      and HOUSING_DECOR_PLACEMENT_COST_FORMAT:format(info.placementCost) or ""
    local qualityColor = ColorManager.GetColorDataForItemQuality(info.quality or Enum.ItemQuality.Common).color
    GameTooltip_AddColoredDoubleLine(GameTooltip, name, placementCost,
                                      qualityColor, HIGHLIGHT_FONT_COLOR, false)

    -- Unique trophy line.
    if info.isUniqueTrophy then
      GameTooltip_AddHighlightLine(GameTooltip, HOUSING_DECOR_UNIQUE_TROPHY_TOOLTIP)
    end

    -- Owned count: total / placed / stored.
    local stored = Blizzard_HousingCatalogUtil
      and Blizzard_HousingCatalogUtil.GetEntryNumStored
      and Blizzard_HousingCatalogUtil.GetEntryNumStored(info)
    local total = Blizzard_HousingCatalogUtil
      and Blizzard_HousingCatalogUtil.GetEntryTotalOwned
      and Blizzard_HousingCatalogUtil.GetEntryTotalOwned(info)
    if total and total ~= 0 then
      GameTooltip_AddNormalLine(GameTooltip,
        HOUSING_DECOR_OWNED_COUNT_FORMAT:format(total, info.totalNumPlaced or 0, stored or 0),
        false)
    end

    -- First acquisition bonus.
    if info.firstAcquisitionBonus and info.firstAcquisitionBonus > 0 then
      GameTooltip_AddNormalLine(GameTooltip,
        HOUSING_DECOR_FIRST_ACQUISITION_FORMAT:format(info.firstAcquisitionBonus))
    end

    -- Market (in the UI called "Catalog") mode additions:
    -- price + "Click or drag to preview" line.
    -- Mirrors HousingCatalogDecorEntryMixin:AddTooltipLines
    -- (HousingCatalogEntry.lua:518-529). Owned-count above stays as-is:
    -- Blizzard also shows it on Market when total > 0, naturally hidden
    -- when total == 0 (which is the common Market case).
    local preview = C_HousingDecor and C_HousingDecor.IsPreviewState
                    and C_HousingDecor.IsPreviewState()
    if preview then
      local marketInfo
      if self.entryVariantID.entryType == Enum.HousingCatalogEntryType.Decor and C_HousingCatalog.GetMarketInfoForDecor then
        marketInfo = C_HousingCatalog.GetMarketInfoForDecor(self.entryVariantID.recordID)
      end
      if marketInfo and marketInfo.price
         and Blizzard_HousingCatalogUtil and Blizzard_HousingCatalogUtil.FormatPrice then
        local priceText = Blizzard_HousingCatalogUtil.FormatPrice(marketInfo.price)
        GameTooltip_AddHighlightLine(GameTooltip,
          HOUSING_DECOR_PRICE_FORMAT:format(priceText))
      end
      -- Disclaimer when the entry is also obtainable through one or more
      -- bundles - same condition Blizzard uses (HousingCatalogEntry.lua:525-527).
      if marketInfo and marketInfo.bundleIDs and #marketInfo.bundleIDs > 0 then
        GameTooltip_AddColoredLine(GameTooltip, HOUSING_DECOR_BUNDLE_DISCLAIMER,
          DISCLAIMER_TOOLTIP_COLOR)
      end
      GameTooltip_AddInstructionLine(GameTooltip, HOUSING_BUNDLE_CLICK_TO_PLACE_DECOR)
    end

    GameTooltip:Show()
    PlaySound(SOUNDKIT.HOUSING_ITEM_HOVER)
  end)

  tile:SetScript("OnLeave", function(self)
    self.hoverBg:Hide()
    GameTooltip:Hide()
    if hoveredFrame == self then
      hoveredFrame = nil
    end
    UpdateInspectCursor()
  end)

  return tile
end


local function AcquireTile()
  local tile = tremove(tilePool)
  if not tile then tile = CreateTile() end
  return tile
end


local function ReleaseAllTiles()
  for i = #activeTiles, 1, -1 do
    local tile = activeTiles[i]
    tile:Hide()
    tile:ClearAllPoints()
    tile.icon:SetTexture(nil)
    tile.icon:SetAtlas(nil)
    tile.customizeIcon:Hide()
    tile.infoText:SetText("")
    tile.infoText:Hide()
    tile.infoIcon:Hide()
    for _, dye in ipairs(tile.dyeIcons) do dye:Hide() end
    tile.entryVariantID = nil
    tile.entryInfo = nil
    tinsert(tilePool, tile)
    activeTiles[i] = nil
  end
end


-- Per-tile overlay update. Mirrors HousingCatalogEntryMixin:UpdateEntryData
-- + HousingCatalogDecorEntryMixin:UpdateTypeSpecificVisuals, scoped to the
-- entry shapes we render (Decor and Room - no bundle items). Handles both
-- Storage (owned-quantity in InfoText) and Market (price in InfoText) via
-- the preview-state branch below. Overlays scale via SetScale(s) but keep
-- their native anchor offsets so they stay pinned near the tile corners
-- regardless of tile size.
local function UpdateTileVisuals(tile, entryVariantID, info)
  -- Overlay scale: linear with the slider up to the default size, then
  -- tapers logarithmically above the default so the corner overlays
  -- don't become grotesque at max tile size. math.log is natural log;
  -- its derivative at x=1 is exactly 1, so overlays scale ~1:1 with the
  -- tile near the default (smooth transition, no kink at s=1) and the
  -- slope falls off as the tile grows (≈0.28 at the max slider value).
  local tileScale = GetScale()
  local s = (tileScale > 1) and (1 + math_log(tileScale)) or tileScale
  local variantInfo = C_HousingCatalog.GetCatalogEntryVariantInfo
                      and C_HousingCatalog.GetCatalogEntryVariantInfo(entryVariantID)

  -- Let the position change a little depending on scale, so the labels are
  --  not outside the chamfered edges of the tiles.
  local xOffset = 1.6*tileScale
  local yOffset = 1.4*tileScale

  -- BOTTOMRIGHT slot is 3-way: Market price / unique-trophy icon / owned
  -- quantity. Size scales with s, position stays at the corner.
  tile.infoIcon:SetScale(s)
  tile.infoIcon:ClearAllPoints()
  tile.infoIcon:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -11 -xOffset, 9 +yOffset)
  tile.infoText:SetScale(s)
  tile.infoText:ClearAllPoints()
  tile.infoText:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -9 -xOffset, 7 +yOffset)
  -- In preview state (Market browse) show the formatted price instead of
  -- owned-quantity / trophy icon. Mirrors HousingCatalogEntry.lua:276-280
  -- where showMarketInfo takes priority over the unique-trophy display.
  -- Price hidden when 0 (matches Blizzard's SetShown(price > 0)).
  local preview = C_HousingDecor and C_HousingDecor.IsPreviewState
                  and C_HousingDecor.IsPreviewState()
  if preview then
    tile.infoIcon:Hide()
    local marketInfo
    if entryVariantID.entryType == Enum.HousingCatalogEntryType.Decor
       and C_HousingCatalog.GetMarketInfoForDecor then
      marketInfo = C_HousingCatalog.GetMarketInfoForDecor(entryVariantID.recordID)
    end
    local price = marketInfo and marketInfo.price or 0
    if price > 0 and Blizzard_HousingCatalogUtil
       and Blizzard_HousingCatalogUtil.FormatPrice then
      tile.infoText:SetText(Blizzard_HousingCatalogUtil.FormatPrice(price))
      tile.infoText:Show()
    else
      tile.infoText:SetText("")
      tile.infoText:Hide()
    end
  elseif info.isUniqueTrophy then
    tile.infoText:Hide()
    tile.infoIcon:Show()
  else
    tile.infoIcon:Hide()
    local quantity = Blizzard_HousingCatalogUtil
                     and Blizzard_HousingCatalogUtil.GetEntryQuantity
                     and Blizzard_HousingCatalogUtil.GetEntryQuantity(info, variantInfo)
                     or 0
    local isRoom = entryVariantID.entryType == Enum.HousingCatalogEntryType.Room
    if not isRoom and quantity > 0 then
      tile.infoText:SetText(quantity)
      tile.infoText:Show()
    else
      tile.infoText:SetText("")
      tile.infoText:Hide()
    end
  end

  -- DyeDisplay: color the dye-drop textures from the variant's dye slots.
  -- Each scales with s; positions cascade off dye[i-1] so a single scaled
  -- spacing offset gives the correct stacked layout.
  local dyeSlots = variantInfo and variantInfo.dyeSlots or {}
  local anyDyes = false
  for i, dye in ipairs(tile.dyeIcons) do
    dye:SetScale(s)
    dye:ClearAllPoints()
    if i == 1 then
      dye:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 10 +xOffset, 8 +yOffset)
    else
      dye:SetPoint("LEFT", tile.dyeIcons[i - 1], "RIGHT", -6 -xOffset, 0)
    end
    local slot = dyeSlots[i]
    if slot then
      local dyeColorInfo = slot.dyeColorID
                           and C_DyeColor and C_DyeColor.GetDyeColorInfo
                           and C_DyeColor.GetDyeColorInfo(slot.dyeColorID)
      if dyeColorInfo and dyeColorInfo.swatchColorStart then
        dye:SetVertexColor(dyeColorInfo.swatchColorStart:GetRGB())
        dye:SetAlpha(1)
        anyDyes = true
      else
        dye:SetVertexColor(1, 1, 1)
        dye:SetAlpha(0.2)
      end
      dye:Show()
    else
      dye:Hide()
    end
  end

  -- CustomizeIcon: dyeable AND no dyes applied (matches Blizzard's logic
  -- at HousingCatalogEntry.lua:580).
  tile.customizeIcon:SetScale(s)
  tile.customizeIcon:ClearAllPoints()
  tile.customizeIcon:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 12 +xOffset, 6 +yOffset)
  tile.customizeIcon:SetShown(info.canCustomize and not anyDyes)
end


-- Visibility toggle. show=true on Storage tab and non-Featured Market
-- categories: move Blizzard's ScrollBox (and its sibling ScrollBar)
-- off-screen and show our parallel frame in its original place.
-- show=false on Featured Market and when the feature is disabled:
-- restore Blizzard's anchors (only if we previously captured them).
--
-- Why not :Hide()? Because :Hide() on the ScrollBox taints internal state
-- (bisected: causes GetProductInfo FORBIDDEN after resize -> Featured).
-- ClearAllPoints + SetPoint to off-screen coordinates is safe in practice
-- and is the approach we've been running with successfully.

-- Helpers: capture and apply anchors for the relocate-off-screen trick.
local function CaptureAnchorsOnce(frame, storage)
  if storage[1] then return storage end  -- already captured
  for i = 1, frame:GetNumPoints() do
    storage[i] = { frame:GetPoint(i) }
  end
  return storage
end

local function MoveOffScreen(frame, container)
  frame:ClearAllPoints()
  -- Anchor relative to the frame's parent (same anchor family),
  -- not UIParent (cross-family triggers "anchor family connection" errors
  -- because parallelFrame is already anchored to container.ScrollBox).
  frame:SetPoint("TOPLEFT", container, "TOPLEFT", -20000, 20000)
end

local function RestoreAnchors(frame, anchors)
  if not anchors or not anchors[1] then return end
  frame:ClearAllPoints()
  for _, p in ipairs(anchors) do
    frame:SetPoint(unpack(p))
  end
end


local function ShowParallelCatalog(show)
  local container = GetContainer()
  if not container or not container.ScrollBox then return end
  local sb = container.ScrollBox
  local bar = container.ScrollBar  -- sibling MinimalScrollBar

  if show then
    if not EnsureParallelFrame() then return end
    WireParallelScroll()
    -- One-time capture of original anchors. The ScrollBar has to move
    -- too because its anchors were geometrically tied to the ScrollBox
    -- area; with the ScrollBox relocated, the bar stretches weirdly to
    -- fill the container.
    scrollBoxOriginalAnchors = scrollBoxOriginalAnchors or {}
    CaptureAnchorsOnce(sb, scrollBoxOriginalAnchors)
    if bar then
      scrollBarOriginalAnchors = scrollBarOriginalAnchors or {}
      CaptureAnchorsOnce(bar, scrollBarOriginalAnchors)
    end
    -- Apply the ScrollBox's captured anchors to our parallel frame so it
    -- visually occupies the same spot the grid did, then override TOPLEFT
    -- with the dynamic offset (see comment below in the else branch).
    RestoreAnchors(parallelFrame, scrollBoxOriginalAnchors)
    local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
    if storagePanel and storagePanel.Categories
       and storagePanel.Categories.GetFocusedCategoryString then
      local categoryString = storagePanel.Categories:GetFocusedCategoryString()
      local topOffset = (categoryString and not storagePanel.customCatalogData) and -28 or 0
      parallelFrame:SetPoint("TOPLEFT", 0, topOffset)
    end
    -- Then shove the originals off-screen.
    MoveOffScreen(sb, container)
    if bar then MoveOffScreen(bar, container) end
    parallelFrame:Show()
    -- parallelScrollBar is parented to container (not parallelFrame) so
    -- we have to show/hide it manually. (RefreshTileGrid may still
    -- hide it again if no scrolling is needed for the current content.)
    if parallelScrollBar then parallelScrollBar:Show() end
  else
    if parallelFrame then parallelFrame:Hide() end
    if parallelScrollBar then parallelScrollBar:Hide() end
    -- Skip the restore work entirely if we never swapped Blizzard's UI
    -- out (no captured anchors). This matters when the feature is off:
    -- TeardownParallelCatalog calls us with show=false on a fresh state,
    -- and we must NOT poke sb:SetPoint - that'd write to an otherwise
    -- untouched Blizzard frame.
    if not scrollBoxOriginalAnchors or not scrollBoxOriginalAnchors[1] then
      return
    end
    RestoreAnchors(sb, scrollBoxOriginalAnchors)
    -- Blizzard's UpdateCategoryText dynamically sets the ScrollBox's
    -- TOPLEFT offset (0 when no focused category, -28 when there is one)
    -- via SetScrollBoxTopOffset at HousingCatalogTemplates.lua:221. Our
    -- captured anchors snapshot whatever offset was current at capture
    -- time (usually 0 from OnLoad before any category was focused), so
    -- restoring them on tab change overrides the value Blizzard just set.
    -- Recompute and override.
    local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
    if storagePanel and storagePanel.Categories
       and storagePanel.Categories.GetFocusedCategoryString then
      local categoryString = storagePanel.Categories:GetFocusedCategoryString()
      local topOffset = (categoryString and not storagePanel.customCatalogData) and -28 or 0
      sb:SetPoint("TOPLEFT", 0, topOffset)
    end
    if bar then RestoreAnchors(bar, scrollBarOriginalAnchors) end
  end
end


-- Virtualized grid: compute columns from viewport width, total rows from
-- entry count, size parallelChild to the full content height (so our
-- scroll math has a logical extent), and render only the rows in the
-- viewport plus a 1-row overscan band above and below using the tile pool.


local function GetScaledTileDims()
  -- GetScale() returns the saved size (or 1.0 if neither the slider nor
  -- the CTRL+wheel toggle is on - see IsAnyIconResizingActive).
  local s = GetScale()
  return TILE_WIDTH * s, TILE_HEIGHT * s, TILE_SPACING * s
end


local refreshing = false


local function RefreshTileGrid()
  if refreshing then return end
  if not parallelChild or not parallelFrame then return end
  refreshing = true

  local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
  if not storagePanel or not storagePanel.catalogSearcher then
    ReleaseAllTiles()
    refreshing = false
    return
  end
  local entries = storagePanel.catalogSearcher:GetCatalogSearchResults()
  local count = entries and #entries or 0

  local viewportWidth = parallelFrame:GetWidth() or 0
  local viewportHeight = parallelFrame:GetHeight() or 0
  local tileW, tileH, spacing = GetScaledTileDims()
  local rowHeight = tileH + spacing
  local colWidth = tileW + spacing

  -- parallelFrame already excludes the scroll-bar slot (captured anchors
  -- include BOTTOMRIGHT x=-23 from Blizzard's ScrollBox). Tiles use the
  -- full parallelFrame width.
  local columns = math.max(1, math.floor((viewportWidth + spacing) / colWidth))
  local totalRows = (count > 0) and math.ceil(count / columns) or 0
  local contentHeight = TOP_PADDING + totalRows * rowHeight

  -- parallelChild holds all tiles; its full height drives our scroll math.
  parallelChild:SetSize(viewportWidth, math.max(1, contentHeight))

  -- Clamp scroll if data shrank below current position, then anchor
  -- parallelChild so it shifts up by the scroll amount (positive Y = up).
  local maxScroll = math.max(0, contentHeight - viewportHeight)
  if parallelFrame.lpScroll > maxScroll then parallelFrame.lpScroll = maxScroll end
  local scroll = parallelFrame.lpScroll
  parallelChild:ClearAllPoints()
  parallelChild:SetPoint("TOPLEFT", parallelFrame, "TOPLEFT", 0, scroll)

  -- Compute visible row range (with overscan) given the current scroll.
  local visibleTop = scroll
  local visibleBottom = scroll + viewportHeight
  local firstRow = math.max(0, math.floor((visibleTop - TOP_PADDING) / rowHeight) - OVERSCAN_ROWS)
  local lastRow = math.min(totalRows - 1, math.floor((visibleBottom - TOP_PADDING) / rowHeight) + OVERSCAN_ROWS)

  ReleaseAllTiles()
  for r = firstRow, lastRow do
    for c = 0, columns - 1 do
      local i = r * columns + c + 1
      if i > count then break end
      local entryVariantID = entries[i]
      -- Restrict to the entryType values Blizzard's own template chooser
      -- handles (Blizzard_HousingCatalogTemplates.lua:99-105) - Decor and
      -- Room. Other values appeared once in the wild as entryType=24
      -- during the FinishPlacingNewDecor -> OnTabChanged cascade and
      -- crashed C_HousingCatalog.GetCatalogEntryInfo's argument validator,
      -- which aborted our refresh and left Blizzard's placement cleanup
      -- half-finished. Such entries aren't renderable through this API
      -- anyway, so skipping them costs nothing visible.
      local et = type(entryVariantID) == "table" and entryVariantID.entryType
      if et == Enum.HousingCatalogEntryType.Decor or et == Enum.HousingCatalogEntryType.Room then
        local info = C_HousingCatalog.GetCatalogEntryInfo(entryVariantID)
        if info then
          local tile = AcquireTile()
          tile:SetSize(tileW, tileH)
          tile:ClearAllPoints()
          tile:SetPoint("TOPLEFT", parallelChild, "TOPLEFT",
                        c * colWidth,
                        -(TOP_PADDING + r * rowHeight))
          tile.icon:SetTexture(nil)
          tile.icon:SetAtlas(nil)
          if info.iconTexture then
            tile.icon:SetTexture(info.iconTexture)
          elseif info.iconAtlas then
            tile.icon:SetAtlas(info.iconAtlas)
          end
          tile.entryVariantID = entryVariantID
          tile.entryInfo = info  -- read by ShowPreviewForEntry + HasValidData
          UpdateTileVisuals(tile, entryVariantID, info)
          tile:Show()
          tinsert(activeTiles, tile)
        end
      end
    end
  end

  -- Keep scroll bar in sync with current scrollable range and position.
  -- visibleExtentPercentage = visible viewport / total content (sizes thumb).
  -- scrollPercentage 0..1 (positions thumb).
  if parallelScrollBar then
    local visibleExtent = (contentHeight > 0) and math.min(1, viewportHeight / contentHeight) or 1
    parallelScrollBar:SetVisibleExtentPercentage(visibleExtent)
    if maxScroll > 0 then
      parallelScrollBar:SetScrollPercentage(scroll / maxScroll)
      parallelScrollBar:Show()
    else
      parallelScrollBar:SetScrollPercentage(0)
      parallelScrollBar:Hide()
    end
  end

  -- Edge fade-out at top/bottom using Frame:SetAlphaGradient. Same strength
  -- math as Blizzard's ScrollBoxBaseMixin:CalculateEdgeFade
  -- (ScrollBox.lua:221-237). `SecretArguments = "AllowedWhenUntainted"` in
  -- the API doc looked like a taint restriction but turns out to appear on
  -- many functions addons use routinely - it's not a runtime block.
  --   top fade strength    ramps 0 -> 1 as scrollPct goes 0 -> 0.15
  --   bottom fade strength ramps 1 -> 0 as scrollPct goes 0.85 -> 1.0
  if maxScroll > 0 then
    local scrollPct = scroll / maxScroll
    local topStrength = (scrollPct < 0.15) and (scrollPct / 0.15) or 1
    local bottomStrength = (scrollPct > 0.85) and ((1 - scrollPct) / 0.15) or 1
    -- Indices 0..3 presumed top, bottom, left, right respectively.
    -- Wiki: "Fade lengths should be applied for all four edges, otherwise
    -- the frame may render as almost fully transparent." So left/right get
    -- zero-length vectors (no fade applied at those edges).
    parallelFrame:SetAlphaGradient(0, CreateVector2D(0, EDGE_FADE_LENGTH * topStrength))
    parallelFrame:SetAlphaGradient(1, CreateVector2D(0, EDGE_FADE_LENGTH * bottomStrength))
    parallelFrame:SetAlphaGradient(2, CreateVector2D(0, 0))
    parallelFrame:SetAlphaGradient(3, CreateVector2D(0, 0))
  else
    parallelFrame:ClearAlphaGradient()
  end

  refreshing = false
end

-- Slider drives our grid: when the user moves the slider, the
-- OnValueChanged handler calls this through the forward-declared callback.
refreshParallelOnSliderChange = RefreshTileGrid


-- Set our manual scroll offset (clamped) and refresh.
local function SetParallelScroll(value)
  if not parallelFrame then return end
  local maxScroll = math.max(0, (parallelChild and parallelChild:GetHeight() or 0)
                                - (parallelFrame:GetHeight() or 0))
  value = math.max(0, math.min(maxScroll, value))
  if math.abs(value - parallelFrame.lpScroll) < 0.5 then return end
  parallelFrame.lpScroll = value
  RefreshTileGrid()
end


-- Hook up scroll handlers on parallelFrame so wheel + size changes + scroll
-- bar movement all re-render the visible row range. Called once from
-- ShowParallelCatalog after EnsureParallelFrame has run. Assigned to the
-- forward-declared local at top of section.
WireParallelScroll = function()
  if not parallelFrame or parallelFrame._lpScrollWired then return end
  parallelFrame:SetScript("OnMouseWheel", function(self, delta)
    -- CTRL+wheel: zoom the tiles, gated on the dedicated flag so the user
    -- can opt out of wheel zoom while keeping the slider, or vice versa.
    -- Wheel-up enlarges, wheel-down shrinks. 0.1 per notch is coarser than
    -- the slider's STEP=0.005 - slider for fine positioning, wheel for
    -- quick zoom.
    if IsControlKeyDown() and LP_config.houseEditorEnhancer_iconResizerCtrlWheel then
      local zoomStep = 0.1
      local current = (slider and slider:GetValue())
                      or LP_config.houseEditorEnhancer_iconResizerSize or DEFAULT_SCALE
      local newValue = math.max(MIN_SCALE, math.min(MAX_SCALE, current + delta * zoomStep))
      if slider then
        -- Slider exists: drive it. Its OnValueChanged saves to LP_config
        -- and triggers refresh for both Blizzard's grid and our tiles.
        slider:SetValue(newValue)
      else
        -- No slider (iconResizer flag off, wheel-only mode): write the
        -- config and trigger refreshes manually.
        LP_config.houseEditorEnhancer_iconResizerSize = newValue
        RefreshCatalog()
        if refreshParallelOnSliderChange then refreshParallelOnSliderChange() end
      end
      return
    end
    local _, tileH, spacing = GetScaledTileDims()
    local rowHeight = tileH + spacing
    SetParallelScroll(self.lpScroll - delta * rowHeight)
  end)
  -- Re-render the grid live as the user drags the storage panel's
  -- ResizeButton. parallelFrame's anchors are tied (via captured ScrollBox
  -- anchors) to container, so its size tracks the panel automatically;
  -- OnSizeChanged fires for free on each size delta.
  parallelFrame:SetScript("OnSizeChanged", function()
    RefreshTileGrid()
  end)
  -- MinimalScrollBar fires "OnScroll" with a percentage 0..1 whenever the
  -- user drags the thumb or clicks the steppers. Translate to our pixel
  -- scroll value.
  if parallelScrollBar then
    parallelScrollBar:RegisterCallback("OnScroll", function(_, scrollPercentage)
      local maxScroll = math.max(0, (parallelChild and parallelChild:GetHeight() or 0)
                                    - (parallelFrame:GetHeight() or 0))
      SetParallelScroll(scrollPercentage * maxScroll)
    end, "LudiusPlus")
  end
  parallelFrame._lpScrollWired = true
end


local function RefreshParallelCatalog()
  -- Decide whether our UI should be active right now.
  --   - Feature flag on
  --   - AND HouseEditor is loaded (positive readiness probe via the
  --     StoragePanel method we'd be calling anyway)
  --   - AND we're NOT on the Featured market category (Featured uses
  --     fixed-size bundle cards we don't lay out)
  -- This covers Storage tab implicitly because Featured is Market-only.
  local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
  local renderable = storagePanel and storagePanel.IsInMarketTab
                     and not IsFeaturedCategoryFocused()
  local active = IsAnyIconResizingActive() and renderable
  ShowParallelCatalog(active)
  if active then RefreshTileGrid() end
end


local function SetupParallelCatalog()
  -- Install the three hooks that drive activation (idempotent - the
  -- parallel{Tab,Results,Category}Hooked flags ensure each fires only
  -- once across re-invocations) and do an initial RefreshParallelCatalog
  -- pass so the UI matches the current state right away.
  local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
  if storagePanel and not parallelTabHooked then
    -- OnTabChanged is the common path for both OnStorageTabSelected and
    -- OnMarketTabSelected, so a single hook covers both directions.
    hooksecurefunc(storagePanel, "OnTabChanged", function()
      RefreshParallelCatalog()
    end)
    parallelTabHooked = true
  end
  if storagePanel and not parallelResultsHooked then
    -- catalogSearcher fetches results asynchronously. OnEntryResultsUpdated
    -- is Blizzard's post-fetch hook (HouseEditorStorageFrame.lua:309) -
    -- it fires whenever fresh results arrive for the current filter/search
    -- state, on tab change, category change, search-text change, etc.
    -- Hooking it post-hook gives us a single trigger for any data refresh.
    -- Route through RefreshParallelCatalog (not RefreshTileGrid directly)
    -- so category changes within the Market tab toggle our UI in/out as
    -- the user moves between "Featured" and non-"Featured" categories.
    hooksecurefunc(storagePanel, "OnEntryResultsUpdated", function()
      RefreshParallelCatalog()
    end)
    parallelResultsHooked = true
  end
  if storagePanel and storagePanel.Categories and not parallelCategoryHooked then
    -- We need a category-change trigger on top of OnEntryResultsUpdated
    -- because "Featured" uses a different data path (UpdateCatalogData ->
    -- custom bundle cards via GetFeaturedBundles) and doesn't fire the
    -- entry-results hook, so without a dedicated category hook we never
    -- deactivate our UI when the user returns to "Featured".
    --
    -- We can't hook storagePanel.OnCategoryFocusChanged because Blizzard
    -- wires it via GenerateClosure(self.OnCategoryFocusChanged, self) at
    -- Categories:Initialize time (Blizzard_HouseEditorStorageFrame.lua:136).
    -- GenerateClosure captures the method reference by value; our later
    -- hooksecurefunc on the storage panel would swap a NEW reference into
    -- storagePanel.OnCategoryFocusChanged but the closure already holds
    -- the original, so our hook would never fire for actual category clicks.
    --
    -- Instead hook storagePanel.Categories.SetFocus - the upstream choke
    -- point all category-change paths flow through
    -- (Blizzard_HousingCatalogCategories.lua:169). After SetFocus returns,
    -- focusedCategoryID is set and the callback has run, so our post-hook
    -- sees consistent state. Categories is an XML-mixined instance, so we
    -- hook the instance (not the mixin) per the rule documented at the top
    -- of this file.
    hooksecurefunc(storagePanel.Categories, "SetFocus", function()
      RefreshParallelCatalog()
    end)
    parallelCategoryHooked = true
  end
  RefreshParallelCatalog()
end


-- Restore Blizzard's UI to its original state when the feature is off.
-- Hooks installed by SetupParallelCatalog stay registered for the session
-- (hooksecurefunc can't be undone), but their bodies route through
-- RefreshParallelCatalog which gates on IsAnyIconResizingActive (true
-- when either the slider or the CTRL+wheel toggle is on), so they're
-- inert when both flags are off. The only meaningful work here
-- is to put Blizzard's frames back where they were, in case we'd previously
-- swapped them out. Safe to call on a fresh state (no captured anchors ->
-- ShowParallelCatalog(false)'s guard returns without touching Blizzard).
local function TeardownParallelCatalog()
  ShowParallelCatalog(false)
end


-- ===== Chain placement =====
--
-- When the user commits a decor placement (click or drag-release) while
-- holding SHIFT, and at least one copy of the same decor is still in
-- storage, immediately start a new placement of the same item. Lets the
-- user place several of the same decor without round-tripping to the
-- catalog UI between placements. Cursor overlay shows the remaining
-- storage count while SHIFT is held.
-- Toggleable via LP_config.houseEditorEnhancer_chainPlacement.
--
-- The chain is DEFERRED via C_Timer.After(0). The click commit path
-- fires two events for the same mouse release - first
-- DecorMoveOverlay:OnMouseUp -> FinishPlacingNewDecor, then
-- GLOBAL_MOUSE_UP -> FinishPlacingNewDecor again. A synchronous chain
-- in the first hook would have IsPlacingNewDecor=true by the time the
-- second fires, double-committing at the same cursor position.
-- Deferring past GLOBAL_MOUSE_UP avoids that.
--
-- The naive defer causes a one-frame storage-panel flash because
-- Blizzard's OnTargetUnselected reopens the storage between commit and
-- our deferred restart. We hide that flash via SetAlpha(0) on the
-- storage panel right when our hook fires, then SetAlpha(1) once the
-- chain has restarted. SetAlpha doesn't change IsShown state, so
-- Blizzard's Show/Hide cycle still happens normally - the user just
-- doesn't see it.

local lastPlacingEntryVariantID = nil
local chainPlacementHooked = false
local chainPlacementCursorOverlay = nil
local chainPlacementModFrame = nil


-- Cursor overlay: small icon offset to the bottom-right of the cursor
-- while SHIFT is held during a (non-preview) placement, to signal that
-- the next commit will chain another copy. Self-contained so it can be
-- removed without affecting the chain logic.

local function ShouldShowCursorOverlay()
  if not LP_config.houseEditorEnhancer_chainPlacement then return false end
  local placing = C_HousingBasicMode and C_HousingBasicMode.IsPlacingNewDecor
                  and C_HousingBasicMode.IsPlacingNewDecor()
  if not placing then return false end
  if C_HousingDecor and C_HousingDecor.IsPreviewState
     and C_HousingDecor.IsPreviewState() then
    return false  -- preview placements don't chain
  end
  return IsShiftKeyDown()
end

-- Variant-aware stored count. When the entry has dye variants, items
-- show as separate tiles per variant and storage is tracked per variant
-- too. We want the count for the SPECIFIC variant we're chain-placing,
-- not the total across all dye variants - so we look up variantInfo and
-- pass it to GetEntryQuantity (which returns variant-specific numStored
-- when variantInfo is given, or total numStored when it isn't).
local function GetCurrentStoredCount()
  if not lastPlacingEntryVariantID then return 0 end
  local info = C_HousingCatalog.GetCatalogEntryInfo(lastPlacingEntryVariantID)
  if not info then return 0 end
  if not (Blizzard_HousingCatalogUtil and Blizzard_HousingCatalogUtil.GetEntryQuantity) then
    return 0
  end
  local variantInfo = C_HousingCatalog.GetCatalogEntryVariantInfo
                      and C_HousingCatalog.GetCatalogEntryVariantInfo(lastPlacingEntryVariantID)
  return Blizzard_HousingCatalogUtil.GetEntryQuantity(info, variantInfo) or 0
end

local function CursorOverlay_OnUpdate(self)
  -- Re-check conditions; if no longer applicable, hide and stop running.
  if not ShouldShowCursorOverlay() then
    self:Hide()
    self:SetScript("OnUpdate", nil)
    return
  end

  -- Update the count text from the current storage count. SetText is
  -- a no-op when the value is unchanged, so calling it per-frame is cheap.
  self.count:SetText(tostring(GetCurrentStoredCount()))

  -- GetCursorPosition returns physical screen pixel coordinates. SetPoint
  -- offsets are in OUR frame's effective scale coordinate space; dividing
  -- by our own scale resolves to the right pixel position regardless of
  -- parent scale (WorldFrame=1.0 here, would be ~0.7 if parent=UIParent).
  -- Calling SetPoint with the same anchor type updates the existing
  -- anchor's offset in-place rather than adding a new one.
  local x, y = GetCursorPosition()
  local scale = self:GetEffectiveScale()
  self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale + 15, y / scale - 15)
end

local function MaybeShowCursorOverlay()
  if not chainPlacementCursorOverlay then return end
  if chainPlacementCursorOverlay:IsShown() then return end
  if not ShouldShowCursorOverlay() then return end
  chainPlacementCursorOverlay:Show()
  chainPlacementCursorOverlay:SetScript("OnUpdate", CursorOverlay_OnUpdate)
end

local function EnsureCursorOverlay()
  if chainPlacementCursorOverlay then return end
  -- Parented to WorldFrame because UIParent children are hidden by the
  -- house editor (even with SetIgnoreParentAlpha applied). WorldFrame is
  -- always rendered.
  chainPlacementCursorOverlay = CreateFrame("Frame", "LudiusPlusChainPlacementCursorOverlay", WorldFrame)
  chainPlacementCursorOverlay:SetFrameStrata("TOOLTIP")
  chainPlacementCursorOverlay:SetSize(60, 28)
  chainPlacementCursorOverlay:Hide()
  -- Initial anchor; OnUpdate updates the offset of this same BOTTOMLEFT
  -- anchor in-place each frame.
  chainPlacementCursorOverlay:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)

  -- Icon: circular-arrow "redo" atlas - indicates chain-placement.
  local icon = chainPlacementCursorOverlay:CreateTexture(nil, "OVERLAY")
  icon:SetSize(24, 24)
  icon:SetPoint("LEFT", chainPlacementCursorOverlay, "LEFT", 0, 0)
  icon:SetAtlas("transmog-icon-revert")
  chainPlacementCursorOverlay.icon = icon

  -- Count text: items remaining in storage (including the one currently
  -- on the cursor). Updated every frame by OnUpdate.
  local count = chainPlacementCursorOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  count:SetPoint("LEFT", icon, "RIGHT", 4, 0)
  count:SetText("")
  chainPlacementCursorOverlay.count = count

  -- Re-evaluate when SHIFT is pressed/released so the overlay can appear
  -- the instant the user holds SHIFT mid-placement.
  if not chainPlacementModFrame then
    chainPlacementModFrame = CreateFrame("Frame")
    chainPlacementModFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
    chainPlacementModFrame:SetScript("OnEvent", function(_, _, key)
      if key == "LSHIFT" or key == "RSHIFT" then
        MaybeShowCursorOverlay()
      end
    end)
  end
end


local function SetupChainPlacement()
  if chainPlacementHooked then return end

  EnsureCursorOverlay()

  -- Remember the entry being placed every time a new placement starts.
  -- All placement paths (our parallel tile, Blizzard's own tile, the
  -- /lpplace test command, any future entry point) funnel through
  -- C_HousingBasicMode.StartPlacingNewDecor, so one hook covers them all.
  hooksecurefunc(C_HousingBasicMode, "StartPlacingNewDecor", function(entryVariantID)
    if type(entryVariantID) == "table" then
      lastPlacingEntryVariantID = entryVariantID
    end
    -- New placement starting; show overlay if SHIFT is already held.
    MaybeShowCursorOverlay()
  end)

  -- Both the click path (DecorMoveOverlay:OnMouseUp -> FinishPlacingNewDecor
  -- at BasicDecorMode.lua:23) and the drag path (GLOBAL_MOUSE_UP ->
  -- FinishPlacingNewDecor at :70) funnel through this function.
  hooksecurefunc(C_HousingBasicMode, "FinishPlacingNewDecor", function()
    if not LP_config.houseEditorEnhancer_chainPlacement then return end
    if not IsShiftKeyDown() then return end
    if not lastPlacingEntryVariantID then return end
    -- Skip Market preview placements - they don't consume stock, so
    -- "chain another copy" doesn't apply.
    if C_HousingDecor and C_HousingDecor.IsPreviewState
       and C_HousingDecor.IsPreviewState() then
      return
    end
    -- Stock check: only chain if there's still a copy of THIS variant in
    -- storage (GetCurrentStoredCount is variant-aware, matching what the
    -- cursor overlay displays).
    if GetCurrentStoredCount() <= 0 then return end

    -- Hide the storage panel visually for the brief window during which
    -- Blizzard's post-placement cleanup will reopen and then re-close
    -- it. The Show/Hide cycle still runs (we don't change IsShown), so
    -- nothing downstream that depends on visibility state breaks; the
    -- user just doesn't see the flash.
    local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
    if storagePanel then storagePanel:SetAlpha(0) end

    -- Defer the chain past the subsequent GLOBAL_MOUSE_UP (click path)
    -- so it can't commit our chained placement at the same cursor
    -- position. Drag path has no such second event, so the defer just
    -- adds a one-frame latency there (imperceptible).
    C_Timer.After(0, function()
      if not IsShiftKeyDown() then
        -- User released SHIFT before our timer fired - no chain.
        -- Restore alpha so the now-visible storage panel displays normally.
        if storagePanel then storagePanel:SetAlpha(1) end
        return
      end
      C_HousingBasicMode.StartPlacingNewDecor(lastPlacingEntryVariantID)
      -- Restore alpha in a SECOND defer so it stays at 0 for one more
      -- frame. This guarantees StoragePanel:Hide() (from the chain's
      -- OnTargetSelected event) has dispatched before the panel can
      -- render with alpha=1. Without this extra defer, a slow event
      -- pump (e.g. right after toggling options, lots of churn) could
      -- leave one rendered frame where the panel is briefly visible -
      -- the flash the user reported as transient.
      C_Timer.After(0, function()
        if storagePanel then storagePanel:SetAlpha(1) end
      end)
    end)
  end)

  chainPlacementHooked = true
end


-- The chain hooks installed by SetupChainPlacement stay registered for the
-- session (hooksecurefunc can't be undone). Their bodies runtime-gate on
-- LP_config.houseEditorEnhancer_chainPlacement so they're inert when the
-- feature is off. The only meaningful teardown is hiding the cursor
-- overlay in case it happens to be visible (it'd hide itself on next
-- OnUpdate anyway via ShouldShowCursorOverlay, but doing it explicitly
-- gives instant feedback when the option is toggled).
local function TeardownChainPlacement()
  if chainPlacementCursorOverlay and chainPlacementCursorOverlay:IsShown() then
    chainPlacementCursorOverlay:Hide()
    chainPlacementCursorOverlay:SetScript("OnUpdate", nil)
  end
end


-- ===== Public API =====

function addon.SetupOrTeardownHouseEditorEnhancer()
  -- HouseEditor is LoadOnDemand; the ADDON_LOADED handler below re-runs
  -- this once it's loaded.
  if not HouseEditorFrame then return end

  -- Two independent flags drive the icon-resizing UI:
  --   iconResizer         - the slider widget under the SearchBox
  --   iconResizerCtrlWheel - CTRL+wheel zoom over the catalog tiles
  -- Either one activates the parallel catalog + scaling hooks; the slider
  -- widget itself only appears when its specific flag is on.
  if IsAnyIconResizingActive() then
    SetupIconResizer()
    SetupParallelCatalog()
  else
    TeardownIconResizer()
    TeardownParallelCatalog()
  end

  if LP_config.houseEditorEnhancer_preview then
    SetupPreview()
  else
    TeardownPreview()
  end

  if LP_config.houseEditorEnhancer_chainPlacement then
    SetupChainPlacement()
  else
    TeardownChainPlacement()
  end

  -- SetupScrollBoxDiagnostic()  -- archived; uncomment with the diagnostic block below to reactivate
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
