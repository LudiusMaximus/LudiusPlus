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
-- 4. RECENT CATEGORY (toggle: houseEditorEnhancer_recent)
--    Adds a custom "Recent" button to the Storage tab's category pane; while
--    it's selected, the catalog lists the decor the player most recently
--    placed or modified (latest first) rendered through the parallel-catalog
--    grid. History is recorded by hooking placements (HOUSING_DECOR_PLACE_SUCCESS,
--    this includes movement, rotation and resize) and dye commits
--    (CommitDyesForSelectedDecor), and persisted per house x indoor/outdoor in
--    the LP_houseEditorRecent SavedVariable. It needs the parallel catalog to
--    render, so enabling it sets that up too - but the grid only goes
--    ACTIVE while the Recent view is open, so with the icon resizer
--    off, normal browsing keeps Blizzard's native catalog. Teardown purges
--    the SavedVariable so a disabled feature leaves no footprint.
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
-- Forward-declared: WireParallelScroll is defined later (it needs RefreshTileGrid
-- in scope) but called from ShowParallelCatalog, which is defined earlier.
local WireParallelScroll

-- Recent: a custom "Recent" category for the Storage tab that lists decor the
-- user has recently placed, most-recent-first. Persisted per house and per
-- indoor/outdoor area (see SyncRecentList) - the "Recent" section near the
-- parallel catalog has the full rationale.
local RECENT_MAX = 200             -- cap on the tracked history length (per list)
local recentEntries = {}           -- POINTER to the current house+area saved list (LP_houseEditorRecent[key]); re-pointed by SyncRecentList. Empty default until first sync.
local recentMode = false           -- true while the Recent view is showing
local recentExitPending = false    -- true while a deferred Recent exit is waiting for the new category's results (see BeginRecentExit)
local recentButton = nil           -- our side-pane toggle (addon-owned frame)
local recentSelectionMask = nil    -- click-through overlay hiding the active category/subcategory's selected look while in Recent
local recentRecordHooked = false   -- StartPlacingNewDecor stash hook + PLACE_SUCCESS event installed
local recentExitHooked = false     -- OnCategoryClicked / OnSearchTextUpdated "exit Recent" hooks installed
local recentPlaceEventFrame = nil  -- listens for HOUSING_DECOR_PLACE_SUCCESS
local pendingPlaceVariant = nil    -- exact entryVariantID of the in-progress fresh placement
-- These are defined down in the "Recent" section but called from earlier
-- sections (the parallel-catalog renderer + tile code), so they're forward-
-- declared here, with the rest of the Recent state:
local SyncRecentList                -- re-point recentEntries to the current house+area list (RefreshParallelCatalog)
local LeaveRecentMode               -- exit Recent + restore Blizzard's header (RefreshParallelCatalog / exit hooks)
local UpdateRecentButtonVisibility  -- show/hide the side-pane toggle (RefreshParallelCatalog)
local RemoveRecentEntry             -- drop one entry (a tile's hover delete button, in CreateTile)
local VariantStoredCount            -- per-variant storage count (UpdateTileVisuals)
local variantStoredCache = {}       -- per-RefreshTileGrid-pass memo for VariantStoredCount (wiped there)

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

-- ===== Feature-state predicates =====
-- True if any of the icon-resizing features is enabled. The slider UI and
-- the CTRL+wheel handler are two independent ways to drive the same
-- resize state, so the parallel catalog and the scaling hooks must
-- activate when EITHER is on.
local function IsAnyIconResizingActive()
  return LP_config.houseEditorEnhancer_iconResizerSlider
      or LP_config.houseEditorEnhancer_iconResizerCtrlWheel
end

local function IsRecentEnabled()
  return LP_config.houseEditorEnhancer_recent
end

-- The parallel catalog (our custom tile grid) is the renderer for BOTH the
-- icon resizer and the Recent view, so it must be SET UP whenever either is
-- enabled. (Being set up only installs hooks; it stays dormant - Blizzard's
-- native catalog shows - until RefreshParallelCatalog makes it active.)
local function IsParallelCatalogNeeded()
  return IsAnyIconResizingActive() or IsRecentEnabled()
end


-- ===== Icon resizer & shared scroll-box helpers =====

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
    -- which Blizzard's OnClick calls via self:StartPreview() - a
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
local function StartPlacingForEntry(entryVariantID)
  local preview = C_HousingDecor and C_HousingDecor.IsPreviewState
                  and C_HousingDecor.IsPreviewState()
  if preview then
    C_HousingBasicMode.StartPlacingPreviewDecor(entryVariantID.recordID)
  else
    -- StartPlacingNewDecor needs a real variantIdentifier. Our uncatalogued
    -- Recent color tiles (a dyed variant fully placed out of storage) carry
    -- none and can't be placed anyway (0 in storage) - they're history-only.
    if entryVariantID.variantIdentifier == nil then return end
    C_HousingBasicMode.StartPlacingNewDecor(entryVariantID)
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

  -- Delete-from-history button (Recent view only). Borrows the look of
  -- UIResetButtonTemplate / FilterButton.ResetButton (the world-map filter's
  -- red X): the auctionhouse-ui-filter-redx atlas as the normal texture plus
  -- the same atlas as an ADD-blend, 0.4-alpha highlight. Shown only while the
  -- cursor is over the tile (see the hover handlers below); clicking drops this
  -- tile's entry from the Recent history. Its SIZE and POSITION are set in
  -- UpdateTileVisuals (the single place, so they scale with the tile).
  tile.deleteBtn = CreateFrame("Button", nil, tile)
  tile.deleteBtn:SetNormalAtlas("auctionhouse-ui-filter-redx")
  tile.deleteBtn:SetHighlightAtlas("auctionhouse-ui-filter-redx", "ADD")
  tile.deleteBtn:GetHighlightTexture():SetAlpha(0.4)
  tile.deleteBtn:RegisterForClicks("LeftButtonUp")
  tile.deleteBtn:Hide()
  tile.deleteBtn:SetScript("OnClick", function()
    if tile.entryVariantID then RemoveRecentEntry(tile.entryVariantID) end
  end)

  -- Tear down the tile's hover visuals (glow, tooltip, inspect cursor) and the
  -- delete button. Region:IsMouseOver() tests the cursor against the frame's
  -- RECTANGLE, not the mouse-focus frame, and the delete button sits inside the
  -- tile's rect - so this guard reads true whether the cursor is over the tile
  -- body or the button. Moving between the two therefore keeps the hover state;
  -- only leaving the whole tile clears it. Shared by both OnLeave handlers.
  local function HideHover()
    if tile:IsMouseOver() then return end
    tile.hoverBg:Hide()
    tile.deleteBtn:Hide()
    GameTooltip:Hide()
    if hoveredFrame == tile then hoveredFrame = nil end
    UpdateInspectCursor()
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
    -- only reads entryInfo from its argument, which we stash on the
    -- tile during RefreshTileGrid.
    if IsControlKeyDown() and LP_config.houseEditorEnhancer_preview
       and self.entryInfo then
      ShowPreviewForEntry(self)
      return
    end
    -- A Recent tile for a variant with none in storage (a color fully placed,
    -- or the undyed base after placing all of it) isn't placeable - clicking
    -- it does nothing, like an out-of-stock catalog entry. (CanStartPlacing
    -- only sees the whole-item total, so this variant-specific guard is needed.)
    if self.recentStored ~= nil and self.recentStored <= 0 then return end
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
    -- See OnClick: a Recent tile with 0 of this variant in storage isn't placeable.
    if self.recentStored ~= nil and self.recentStored <= 0 then return end
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
    -- Recent view only: reveal the delete-from-history button while hovering.
    if recentMode then self.deleteBtn:Show() end
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

  tile:SetScript("OnLeave", HideHover)
  -- The delete button's own tooltip. SetOwner re-points GameTooltip at the
  -- button, replacing the tile's item tooltip while hovering the X. No restore
  -- is needed on leave: moving back onto the tile body re-fires the tile's
  -- OnEnter (the parent reclaims mouse focus from the child), which rebuilds the
  -- item tooltip; moving off the tile entirely runs HideHover, which hides it.
  tile.deleteBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Remove from history"])
    GameTooltip:Show()
  end)
  -- The delete button steals mouse focus from the tile while hovered, firing
  -- the tile's OnLeave; routing the button's OnLeave through the same guard
  -- means the hover state only tears down once the cursor leaves both.
  tile.deleteBtn:SetScript("OnLeave", HideHover)

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
    tile.hoverBg:Hide()
    tile.deleteBtn:Hide()
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

  -- Delete-from-history button: THE single place to control its size and
  -- position. The two base numbers are px on the default 97px tile (TILE_WIDTH);
  -- both scale LINEARLY with the tile (not the log-tapered overlay scale s), so
  -- the button keeps the same relative footprint and corner inset at any slider
  -- value. Edit these two numbers - nothing else sets the button's geometry.
  local DELETE_BTN_SIZE, DELETE_BTN_INSET = 20, 6
  tile.deleteBtn:SetSize(DELETE_BTN_SIZE * tileScale, DELETE_BTN_SIZE * tileScale)
  tile.deleteBtn:ClearAllPoints()
  tile.deleteBtn:SetPoint("TOPRIGHT", tile, "TOPRIGHT",
                          -DELETE_BTN_INSET * tileScale, -DELETE_BTN_INSET * tileScale)

  -- Variant info drives the owned-quantity and (for catalog tiles) the dye
  -- swatches. Skipped for our uncatalogued Recent entries (no variantIdentifier,
  -- e.g. a color fully placed out of storage) - they carry their own dyeSlots.
  local variantInfo = entryVariantID.variantIdentifier
                      and C_HousingCatalog.GetCatalogEntryVariantInfo
                      and C_HousingCatalog.GetCatalogEntryVariantInfo(entryVariantID)

  -- Recent tiles carry a dyeKey; compute this variant's own storage count
  -- (variant-specific, correct even for the base/undyed - see VariantStoredCount).
  -- Stashed on the tile so the click handlers can gate placement on it.
  local isRecent = entryVariantID.dyeKey ~= nil
  tile.recentStored = isRecent
    and VariantStoredCount(entryVariantID.recordID, entryVariantID.dyeKey) or nil

  -- Let the position change a little depending on scale, so the labels are
  -- not outside the chamfered edges of the tiles.
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
  -- Default the count to white every render; the 0-in-storage case below
  -- re-colors it dim red. Needed because tiles are pooled - a tile reused from
  -- a prior dim-red render would otherwise keep that color for a price/count.
  tile.infoText:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
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
    local quantity
    if isRecent then
      -- Recent tile: show THIS variant's storage count (0 for a color fully
      -- placed, or the undyed base after placing all of it).
      quantity = tile.recentStored
    else
      quantity = Blizzard_HousingCatalogUtil
                 and Blizzard_HousingCatalogUtil.GetEntryQuantity
                 and Blizzard_HousingCatalogUtil.GetEntryQuantity(info, variantInfo)
                 or 0
    end
    local isRoom = entryVariantID.entryType == Enum.HousingCatalogEntryType.Room
    if isRoom then
      -- Rooms never show an owned-quantity count.
      tile.infoText:SetText("")
      tile.infoText:Hide()
    elseif quantity > 0 then
      tile.infoText:SetText(quantity)
      tile.infoText:Show()
    else
      -- None left in storage (a Recent variant fully placed out into the world,
      -- or the undyed base after placing all of it): show a dim-red 0 in the
      -- same slot and font, so the tile reads as owned-but-unplaceable rather
      -- than blank. White default was set above; re-color just this case.
      tile.infoText:SetText("0")
      tile.infoText:SetTextColor(DIM_RED_FONT_COLOR:GetRGB())
      tile.infoText:Show()
    end
  end

  -- DyeDisplay: color the dye-drop textures from the dye slots. Prefer the
  -- entry's own dyeSlots (Recent entries carry them, so colors show even for
  -- variants with no catalog entry); fall back to the catalog variant's slots
  -- for normal catalog tiles. Each scales with s; positions cascade off
  -- dye[i-1] so a single scaled spacing offset gives the correct stacked layout.
  local dyeSlots = entryVariantID.dyeSlots or (variantInfo and variantInfo.dyeSlots) or {}
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
  local scrollBox = container.ScrollBox
  local bar = container.ScrollBar  -- sibling MinimalScrollBar

  if show then
    if not EnsureParallelFrame() then return end
    WireParallelScroll()
    -- One-time capture of original anchors. The ScrollBar has to move
    -- too because its anchors were geometrically tied to the ScrollBox
    -- area; with the ScrollBox relocated, the bar stretches weirdly to
    -- fill the container.
    scrollBoxOriginalAnchors = scrollBoxOriginalAnchors or {}
    CaptureAnchorsOnce(scrollBox, scrollBoxOriginalAnchors)
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
    -- Both of the following run EVERY time the grid is shown, in EVERY scenario
    -- (icon-resizing and Recent alike) - there is no per-mode branching here.
    -- Each closes a different gap, and neither alone covers everything:
    --
    --  * MoveOffScreen parks Blizzard's ScrollBox AND its ScrollBar off-screen
    --    (ClearAllPoints + one far-off point). For the BAR this is the real fix:
    --    it severs the bar's LEFT->ScrollBox.RIGHT anchor (which would otherwise
    --    stretch it across the panel) and parks it clear of our parallelScrollBar's
    --    mouse area. Crucially, nothing re-anchors the bar afterwards -
    --    SetScrollBoxTopOffset (see below) only ever re-points the ScrollBox -
    --    so the bar STAYS off-screen for the whole session and can't misbehave.
    --
    --  * SetAlpha(0) is the reliable VISUAL hide for the BOX, which - unlike the
    --    bar - DOES come back: Blizzard re-anchors the ScrollBox's TOPLEFT
    --    on-screen via SetScrollBoxTopOffset (on category focus /
    --    UpdateCategoryText), undoing our move. In icon-resizing mode the frequent
    --    RefreshParallelCatalog churn keeps re-moving it off, and its tiles sit
    --    behind our identical ones so a peek is invisible anyway; but in a
    --    Recent-only session there's no such churn and our tiles differ, so the
    --    re-anchored box would show its tiles through the gaps between ours.
    --    Alpha 0 hides it wherever it lands (its mouse is swallowed by
    --    parallelFrame on top). SetAlpha is taint-safe: cosmetic, no layout, and
    --    the catalog's Update never reads alpha.
    --
    -- So strictly only the BOX needs the alpha; the bar's SetAlpha just below is
    -- redundant (it's already parked off-screen), kept only for symmetry and as
    -- cheap insurance should a future patch ever start re-anchoring the bar.
    MoveOffScreen(scrollBox, container)
    if bar then MoveOffScreen(bar, container) end
    scrollBox:SetAlpha(0)
    if bar then bar:SetAlpha(0) end
    parallelFrame:Show()
    -- parallelScrollBar is parented to container (not parallelFrame) so
    -- we have to show/hide it manually. (RefreshTileGrid may still
    -- hide it again if no scrolling is needed for the current content.)
    if parallelScrollBar then parallelScrollBar:Show() end

  -- if not show
  else
    if parallelFrame then parallelFrame:Hide() end
    if parallelScrollBar then parallelScrollBar:Hide() end
    -- Skip the restore work entirely if we never swapped Blizzard's UI
    -- out (no captured anchors). This matters when the feature is off:
    -- TeardownParallelCatalog calls us with show=false on a fresh state,
    -- and we must NOT poke scrollBox:SetPoint - that'd write to an otherwise
    -- untouched Blizzard frame.
    if not scrollBoxOriginalAnchors or not scrollBoxOriginalAnchors[1] then
      return
    end
    -- Undo the alpha-0 hide from the show branch (anchors captured => we'd hidden it).
    scrollBox:SetAlpha(1)
    if bar then bar:SetAlpha(1) end
    RestoreAnchors(scrollBox, scrollBoxOriginalAnchors)
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
      scrollBox:SetPoint("TOPLEFT", 0, topOffset)
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

  -- Per-pass memo for VariantStoredCount; wiped each refresh so per-variant
  -- counts stay live as storage changes.
  wipe(variantStoredCache)

  local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
  -- Recent mode renders our own tracked history; everything else renders
  -- Blizzard's catalog search results. Both are arrays of entryVariantID,
  -- so the rendering loop below is identical for either source.
  local entries
  if recentMode then
    entries = recentEntries
  else
    if not storagePanel or not storagePanel.catalogSearcher then
      ReleaseAllTiles()
      refreshing = false
      return
    end
    entries = storagePanel.catalogSearcher:GetCatalogSearchResults()
  end
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
  -- (ScrollBox.lua:221-237). SecretArguments = "AllowedWhenUntainted" in
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
  -- Decide whether our parallel grid should be rendering (replacing Blizzard's
  -- catalog) right now. It's active when:
  --   - icon resizing is on (replace everywhere to scale the tiles), OR we're
  --     viewing Recent (recentMode - replace just to show our history tiles;
  --     this is what lets Recent work with icon resizing OFF, keeping Blizzard's
  --     native catalog for normal browsing)
  --   - AND HouseEditor is loaded (positive readiness probe via the
  --     StoragePanel method we'd be calling anyway)
  --   - AND we're NOT on the Featured market category (Featured uses
  --     fixed-size bundle cards we don't lay out)
  -- This covers Storage tab implicitly because Featured is Market-only.
  local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
  local renderable = storagePanel and storagePanel.IsInMarketTab
                     and not IsFeaturedCategoryFocused()
  -- Recent is a Storage-tab-only view: drop out of it if the storage catalog
  -- isn't renderable (Featured focused, or the panel is gone) or we've moved to
  -- the Market tab. Done BEFORE computing "active", because "active" depends on
  -- recentMode and LeaveRecentMode clears it. (Short-circuit: when storagePanel
  -- is nil, "not renderable" is already true, so IsInMarketTab() isn't called.)
  if recentMode and (not renderable or storagePanel:IsInMarketTab()) then
    LeaveRecentMode()
  end
  -- Still in Recent: re-point the list to the CURRENT house+area before
  -- rendering. The editor remembers Recent as the last category, so it reopens
  -- already in recentMode without a button click; if the player changed area
  -- (indoor<->outdoor, which needs leaving the editor) between sessions, this
  -- swaps the stale list for the correct one. Guarded on SyncRecentList being
  -- assigned (defined later, in the Recent section).
  if recentMode and SyncRecentList then SyncRecentList() end
  local active = (IsAnyIconResizingActive() or recentMode) and renderable
  ShowParallelCatalog(active)
  if active then RefreshTileGrid() end
  if UpdateRecentButtonVisibility then UpdateRecentButtonVisibility() end
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
    -- NOTE: this fires for ALL focus changes, including the programmatic
    -- re-focus when the editor re-shows after a placement. So it must NOT
    -- touch recentMode (that would kick us out of Recent on every placement);
    -- exiting Recent is driven by the user-intent hooks in SetupRecent
    -- (OnCategoryClicked / OnSearchTextUpdated) instead.
    hooksecurefunc(storagePanel.Categories, "SetFocus", function()
      RefreshParallelCatalog()
    end)
    parallelCategoryHooked = true
  end
  RefreshParallelCatalog()
end


-- Restore Blizzard's UI to its original state when the parallel catalog isn't
-- needed. Hooks installed by SetupParallelCatalog stay registered for the
-- session (hooksecurefunc can't be undone), but their bodies route through
-- RefreshParallelCatalog, which only makes the grid active when icon resizing
-- is on OR the Recent view is open. This teardown only runs when neither the
-- icon resizer nor Recent is enabled (IsParallelCatalogNeeded is false), and
-- with Recent disabled recentMode can't be true - so the hooks are inert and
-- the only work here is putting Blizzard's frames back where they were, in case
-- we'd previously swapped them out. Safe to call on a fresh state (no captured
-- anchors -> ShowParallelCatalog(false)'s guard returns without touching Blizzard).
local function TeardownParallelCatalog()
  ShowParallelCatalog(false)
end


-- ===== "Recent" category =====
--
-- A custom "Recent" category for the Storage tab listing decor the user
-- has recently placed, most-recently-placed first. Reuses the parallel
-- catalog renderer entirely: RefreshTileGrid swaps its data source to
-- recentEntries while recentMode is on, and the rendering loop (Decor/Room
-- filter, GetCatalogEntryInfo, tiles, scroll, CanStartPlacing) is identical
-- because a recent entry is the same entryVariantID shape as a search result.
--
-- RECORDING: driven by the HOUSING_DECOR_PLACE_SUCCESS event, which fires on
-- a successful commit for BOTH fresh-from-storage placements (isNew=true) and
-- moves of already-placed world decor (isNew=false) - so picking an item up
-- in the world and dropping it elsewhere counts too. Recovering the exact dye
-- variant (the event only carries a decorGUID, not the variant):
--   * Fresh placement (isNew=true): the StartPlacingNewDecor hook stashed the
--     exact entryVariantID, so we record that directly. (The event's decorGUID
--     is usually nil here - the server hasn't assigned it yet - but the stash
--     means we don't need it.)
--   * Move (isNew=false): the GUID is valid, so resolve the instance's decorID
--     + applied dyeSlots via GetDecorInstanceInfoForGUID and recover the
--     variantIdentifier by matching those dyes against the catalog's variant
--     list (GetAllVariantInfosForEntry). Works for any placed instance, session
--     or pre-existing. If the dyes can't be matched (a dyed variant with 0 in
--     storage isn't enumerated), we still record the exact color from the
--     instance's own dyeSlots: the tile draws its swatches but is display-only
--     (not placeable), since StartPlacingNewDecor needs a real variantIdentifier.
--
-- Also recorded: re-dyes of already-placed decor, captured at the dye pane's
-- COMMIT (hooksecurefunc on C_HousingCustomizeMode.CommitDyesForSelectedDecor)
-- and resolved the same way as a move, so re-coloring an item updates its
-- variant in the history. We hook the commit rather than listening to
-- HOUSING_DECOR_CUSTOMIZATION_CHANGED, which fires on every live PREVIEW swatch
-- click (recording colors merely tried) and in bulk for all decor on editor
-- close - the commit fires only on a genuine Apply.
--
-- TAINT NOTE: Blizzard's category pane is data-driven from
-- C_HousingCatalog.SearchCatalogCategories, so we can't inject a real
-- category. Instead we add our OWN button as a child of the pane. Creating
-- a child frame doesn't taint the parent, and we only ever SetPoint our
-- own button - so this stays taint-free (unlike SetPoint-ing one of
-- Blizzard's pooled category buttons, which is what tainted when we tried
-- to relocate "Featured"). The pane is a VerticalLayoutFrame that lays its
-- buttons out from the top; we bottom-anchor ours so its Layout() churn
-- never touches us.
--
-- PERSISTENCE: the history is saved across sessions in the LP_houseEditorRecent
-- SavedVariable, scoped per house AND per indoor/outdoor area (the key is
-- houseGUID + in/out - see SyncRecentList/CurrentRecentKey), giving up to four
-- lists (two plots x indoors/outdoors). recentEntries always points at the
-- current house+area's saved sub-table.
--
-- ENABLEMENT: driven by its own toggle (houseEditorEnhancer_recent). Recent
-- renders through the parallel catalog, so enabling it sets that up too (see
-- the dispatcher and IsParallelCatalogNeeded); the parallel grid only goes
-- ACTIVE while the Recent view is open, so with the icon resizer off, normal
-- browsing still shows Blizzard's native catalog. Works alongside any of the
-- other House Editor features.


local function FinalizeRecentChange()
  while #recentEntries > RECENT_MAX do
    tremove(recentEntries)
  end
  -- Reflect the change live if the Recent view is currently showing.
  if recentMode then RefreshParallelCatalog() end
end

-- The persistence key for the list that applies right now: one per house TIMES
-- indoor/outdoor (so up to 4 - the two neighborhoods' plots are distinct
-- houseGUIDs, and indoor vs outdoor decor is placed/stored separately). Both
-- come from plain, freely-callable C_Housing getters Blizzard's own UI uses:
-- GetCurrentHouseInfo().houseGUID identifies the house, and IsInsideHouse() is
-- the very flag Blizzard feeds to catalogSearcher:SetAllowedIndoors, so it lines
-- up exactly with what decor is placeable where. Edit mode is only ever entered
-- at your own plot, so houseGUID is always present here; "none" is a defensive
-- catch-all that never realistically triggers. The houseGUID and the in/out
-- suffix are both fixed for a whole editor session - you can't cross
-- inside<->outside without leaving edit mode (loading screen between them).
local function CurrentRecentKey()
  local houseInfo = C_Housing and C_Housing.GetCurrentHouseInfo and C_Housing.GetCurrentHouseInfo()
  local houseGUID = houseInfo and houseInfo.houseGUID
  if not houseGUID then return "none" end
  local inside = C_Housing.IsInsideHouse and C_Housing.IsInsideHouse()
  return houseGUID .. (inside and "-in" or "-out")
end

-- Point recentEntries at the saved sub-list for the current house+area, creating
-- it (and the saved root) on first use. recentEntries is a file-local upvalue,
-- so this reassignment is seen by every closure that reads it. Called before
-- recording (so the item is bucketed by where it's placed), before removing,
-- and on every render while in Recent (RefreshParallelCatalog). The render-time
-- sync matters because the House Editor remembers Recent as the last category,
-- so it reopens already in recentMode WITHOUT going through the button's OnClick -
-- and the house+area can have changed between sessions (indoor<->outdoor needs
-- a loading screen, i.e. leaving the editor). Without it, a reopen would show
-- the previous area's stale list. (Still not live in-session switching, which
-- can't happen.) Assigned to a forward-declared local so RefreshParallelCatalog
-- (defined earlier) can call it. LP_houseEditorRecent is an account-wide
-- SavedVariable: { [key] = { entry, ... } }.
SyncRecentList = function()
  LP_houseEditorRecent = LP_houseEditorRecent or {}
  local key = CurrentRecentKey()
  LP_houseEditorRecent[key] = LP_houseEditorRecent[key] or {}
  recentEntries = LP_houseEditorRecent[key]
end

-- Exit the Recent view and restore Blizzard's real header text. The order
-- matters: clear recentMode FIRST, so the UpdateCategoryText reassert-hook
-- (which repaints "Recent" while recentMode is true) steps aside and lets
-- Blizzard repaint the focused category's actual name + color. Callers re-render
-- afterwards as needed; RefreshParallelCatalog already does so itself, so it is
-- intentionally NOT called here (that would recurse when called from within it).
LeaveRecentMode = function()
  recentExitPending = false  -- a direct exit cancels any deferred one
  recentMode = false
  local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
  if storagePanel and storagePanel.UpdateCategoryText then
    storagePanel:UpdateCategoryText()   -- restore the focused category's label + color
  end
  if storagePanel and storagePanel.UpdateCategoryTotal then
    storagePanel:UpdateCategoryTotal()  -- re-show + recompute the count we hid in Recent
  end
end

-- Finish a deferred Recent exit (see BeginRecentExit): now that the new
-- category's results are in, actually leave Recent and reveal them. No-op if no
-- exit is pending (e.g. the safety timer fired after the results already did).
local function FinishRecentExit()
  if not recentExitPending then return end
  recentExitPending = false
  LeaveRecentMode()
  RefreshParallelCatalog()
end

-- Begin leaving Recent, DEFERRED. The user clicked another category (or started
-- a search), but Blizzard's catalog still holds the PREVIOUS category's tiles
-- until the new search completes - revealing now would flash them (jarring when
-- the old category had a scroll bar and the new one doesn't). So keep the Recent
-- grid up as a cover and finish the exit when the new results arrive (the
-- OnEntryResultsUpdated hook in SetupRecent calls FinishRecentExit), or after a
-- short fallback delay if for some reason none fire. recentMode stays true
-- meanwhile, so the cover keeps rendering.
local function BeginRecentExit()
  if recentExitPending then return end
  recentExitPending = true
  C_Timer.After(0.3, FinishRecentExit)
end

-- Manual removal only - automatic pruning of "extinct" color variants is
-- IMPRACTICAL. A color variant becomes extinct when its last instance is
-- recolored away or removed, leaving it neither in storage nor placed. But we
-- can't detect that state: "0 in storage, still placed somewhere" (keep - we
-- intentionally list placed-but-unstored variants, option B) is API-
-- indistinguishable from "0 in storage, no longer placed" (prune). There's no
-- per-variant placed count, and C_HousingDecor.GetAllPlacedDecor is protected
-- (ADDON_ACTION_FORBIDDEN), so we can't enumerate placements to tell them
-- apart. Hence the user prunes stale entries by hand via each tile's delete
-- button, which calls RemoveRecentEntry. See [[housing_placed_decor_api_access]].
RemoveRecentEntry = function(entry)
  SyncRecentList()  -- the tile's entry lives in the current house+area list
  for i = #recentEntries, 1, -1 do
    if recentEntries[i] == entry then
      tremove(recentEntries, i)
      break
    end
  end
  FinalizeRecentChange()
end

-- Order-independent signature of a decor instance's / variant's applied dyes:
-- a sorted list of "channel=colorID" pairs for the slots that ACTUALLY have a
-- color applied. Unpainted slots are skipped so "no dye" yields the same key
-- ("") regardless of how the source spells it - the catalog's undyed variant
-- uses an empty dyeSlots list, while a placed undyed instance lists every
-- channel with dyeColorID=0 (a "no dye" sentinel; note 0 is TRUTHY in Lua, so
-- it must be excluded explicitly). This key is also the Recent dedup identity,
-- so each distinct decor+color is one tile.
local function DyeKey(dyeSlots)
  if not dyeSlots then return "" end
  local parts = {}
  for _, slot in ipairs(dyeSlots) do
    if slot.dyeColorID and slot.dyeColorID ~= 0 then
      parts[#parts + 1] = tostring(slot.channel) .. "=" .. tostring(slot.dyeColorID)
    end
  end
  table.sort(parts)
  return table.concat(parts, ";")
end

-- Shared catalog query: all owned variant infos for a decor record - the base
-- variant plus the dyed variants currently in STORAGE (each entry carries
-- entryVariantID, numStored, and dyeSlots). Returns nil if the API is missing.
-- See the NOTE in FindVariantIdForInstance for what this list omits (0-stored
-- dyed variants). Used by both VariantStoredCount and FindVariantIdForInstance.
local function GetDecorVariantInfos(recordID)
  if not (C_HousingCatalog and C_HousingCatalog.GetAllVariantInfosForEntry) then
    return nil
  end
  return C_HousingCatalog.GetAllVariantInfosForEntry({
    entryType = Enum.HousingCatalogEntryType.Decor,
    recordID = recordID,
  })
end

-- Assigned to the forward-declared local so UpdateTileVisuals (defined earlier)
-- can use it. Live per-variant storage count keyed by dye signature.
-- GetAllVariantInfosForEntry lists every owned variant's numStored - INCLUDING
-- the base (id 0), even at 0 - so this is the correct per-variant count, unlike
-- GetEntryQuantity on the base variant (which returns the whole-entry total).
-- A variant with none in storage isn't listed, so it reads as 0. Cached per
-- RefreshTileGrid pass (variantStoredCache is wiped there).
VariantStoredCount = function(recordID, dyeKey)
  local map = variantStoredCache[recordID]
  if not map then
    map = {}
    local variants = GetDecorVariantInfos(recordID)
    if variants then
      for _, v in ipairs(variants) do
        map[DyeKey(v.dyeSlots)] = v.numStored or 0
      end
    end
    variantStoredCache[recordID] = map
  end
  return map[dyeKey] or 0
end

-- Record a Recent entry = {entryType, recordID, variantIdentifier?,
-- dyeSlots?}. Move-to-front, dedup on (entryType, recordID, dye signature) so
-- each distinct color is ONE tile whether or not it has a catalog
-- variantIdentifier. We keep the dyeSlots so the tile can draw its own swatches
-- (dyed variants with 0 in storage have no catalog variant - see
-- FindVariantIdForInstance), and the variantIdentifier when known so the tile
-- can be placed while stock exists.
local function RecordRecentEntry(entry)
  -- The recording hooks (StartPlacingNewDecor stash, PLACE_SUCCESS, dye commit)
  -- stay installed for the session once Recent has ever been enabled, since
  -- hooksecurefunc can't be undone. Gate here so a DISABLED feature records
  -- nothing and never recreates the purged SavedVariable (see TeardownRecent).
  if not IsRecentEnabled() then return end
  if type(entry) ~= "table" or not entry.entryType or not entry.recordID then return end
  SyncRecentList()  -- record into the current house+area (persisted) list
  local key = DyeKey(entry.dyeSlots)
  for i = #recentEntries, 1, -1 do
    local e = recentEntries[i]
    if e.entryType == entry.entryType and e.recordID == entry.recordID and e.dyeKey == key then
      tremove(recentEntries, i)
    end
  end
  tinsert(recentEntries, 1, {
    entryType = entry.entryType,
    recordID = entry.recordID,
    variantIdentifier = entry.variantIdentifier,
    dyeSlots = entry.dyeSlots,
    dyeKey = key,
  })
  FinalizeRecentChange()
end

-- Recover the catalog variantIdentifier for a placed instance by matching its
-- applied dyes against the catalog's variant list for the same decor. The
-- placed instance carries dyeSlots (the colors) but not the variantIdentifier;
-- each catalog variant carries both, so the variant whose dyeSlots match is
-- the one. Works for any instance with a valid GUID (session or pre-existing);
-- the placed variant enumerates even when 0 are left in storage. Returns the
-- matched variantIdentifier, or nil if there's no catalog data / no match.
local function FindVariantIdForInstance(decorID, instanceDyeSlots)
  local variants = GetDecorVariantInfos(decorID)
  if not variants then return nil end
  -- NOTE: GetAllVariantInfosForEntry only lists the base variant plus dyed
  -- variants the player currently holds in STORAGE. A dyed variant with 0 in
  -- storage (fully placed, or dyed in-world) isn't listed, so its
  -- variantIdentifier (an opaque hash) can't be recovered here. Returning nil is
  -- fine: the caller still records the exact color from the instance's own
  -- dyeSlots, so the tile draws its swatches - it's just display-only (not
  -- placeable, count shown as 0) until a copy of that color is back in storage.
  local target = DyeKey(instanceDyeSlots)
  for _, v in ipairs(variants) do
    if v.entryVariantID and DyeKey(v.dyeSlots) == target then
      return v.entryVariantID.variantIdentifier
    end
  end
  return nil
end


-- Record a placed instance (by GUID) at its CURRENT dyes: resolve the decor
-- record + applied dyes, and record with the instance's own dyeSlots (so the
-- tile shows the color) plus the catalog variantIdentifier when the variant is
-- still in storage (so it can be re-placed; nil otherwise). Used for moves and
-- for in-world dye changes - any time we only have a GUID and read live state.
local function RecordPlacedDecorByGUID(decorGUID)
  if not decorGUID or not (C_HousingDecor and C_HousingDecor.GetDecorInstanceInfoForGUID) then
    return
  end
  local info = C_HousingDecor.GetDecorInstanceInfoForGUID(decorGUID)
  if not info or not info.decorID then return end
  RecordRecentEntry({
    entryType = Enum.HousingCatalogEntryType.Decor,
    recordID = info.decorID,
    variantIdentifier = FindVariantIdForInstance(info.decorID, info.dyeSlots),
    dyeSlots = info.dyeSlots,
  })
end


-- Handle one HOUSING_DECOR_PLACE_SUCCESS. Records the placed decor into the
-- Recent history with its exact dye variant whenever possible: fresh
-- placements use the variant stashed at placement start; moves recover it by
-- matching the placed instance's dyes against the catalog variant list.
local function RecordPlacedDecor(decorGUID, isNew, isPreview)
  -- Market preview decor isn't owned and doesn't belong in a placement
  -- history; chain placement skips it for the same reason.
  if isPreview then
    pendingPlaceVariant = nil
    return
  end

  if isNew and pendingPlaceVariant then
    -- Fresh placement we tracked: record the exact stashed variant. (The
    -- event's decorGUID is usually nil here - the server hasn't assigned the
    -- new instance's GUID yet - but we don't need it.) Pull its dyeSlots from
    -- the catalog variant so its tile draws swatches like any other entry.
    local v = pendingPlaceVariant
    local vinfo = C_HousingCatalog.GetCatalogEntryVariantInfo
                  and C_HousingCatalog.GetCatalogEntryVariantInfo(v)
    RecordRecentEntry({
      entryType = v.entryType,
      recordID = v.recordID,
      variantIdentifier = v.variantIdentifier,
      dyeSlots = vinfo and vinfo.dyeSlots,
    })
    pendingPlaceVariant = nil
    return
  end
  pendingPlaceVariant = nil

  -- Move (isNew=false) or a fresh placement that bypassed our stash: the GUID
  -- is valid, so resolve and record from the instance's live state.
  RecordPlacedDecorByGUID(decorGUID)
end


-- Custom Recent button art: a 256x256 file split into three 128x128 cells -
-- topleft active, topright pressed, bottomleft inactive. We TexCoord into it
-- per state rather than ship three separate files.
local RECENT_BTN_TEX = "Interface\\AddOns\\LudiusPlus\\HouseEditorButtonRecent"
local RECENT_BTN_COORD = {
  active   = { 0,   0.5, 0,   0.5 },  -- topleft  (left/right/top/bottom)
  pressed  = { 0.5, 1,   0,   0.5 },  -- topright
  inactive = { 0,   0.5, 0.5, 1   },  -- bottomleft
}

-- Drive the button art from its state, mirroring how the category buttons swap
-- textures: pressed > selected(active) > inactive. The hover overlay always
-- tracks the resting (non-pressed) art so its additive brighten matches.
local function RefreshRecentButtonTexture()
  if not recentButton then return end
  local resting = recentMode and RECENT_BTN_COORD.active or RECENT_BTN_COORD.inactive
  recentButton.tex:SetTexCoord(unpack(recentButton.pressed and RECENT_BTN_COORD.pressed or resting))
  recentButton.hoverBg:SetTexCoord(unpack(resting))
  -- Selection glow + sparkle, but only in the subcategory view (glowEligible) -
  -- the top-level view shows selection by the active texture alone, like the
  -- top-level categories. Shown while Recent is active, independent of
  -- press/hover (matching SetActive). Created lazily, so guard.
  if recentButton.glow then
    local showGlow = recentMode and recentButton.glowEligible
    recentButton.glow:SetShown(showGlow)
    recentButton.sparkle:SetShown(showGlow)
    if showGlow then
      recentButton.sparkleAnim:Play()
    else
      recentButton.sparkleAnim:Stop()
    end
  end
end


local function EnsureRecentButton()
  if recentButton then return end
  local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
  local cats = storagePanel and storagePanel.Categories
  if not cats then return end

  -- Size + glow adapt to the pane's current view in UpdateRecentButtonVisibility:
  -- 64px / no glow in the top-level "All" view (like the top-level categories),
  -- 54px / glow in the subcategory view (like the subcategories). These are just
  -- initial values; bottom-anchored so the pane's layout never repositions us.
  recentButton = CreateFrame("Button", "LudiusPlusRecentCategoryButton", cats)
  recentButton:SetSize(64, 64)
  recentButton:SetPoint("BOTTOM", cats, "BOTTOM", 0, 8)
  recentButton:RegisterForClicks("LeftButtonUp")

  -- Selection glow + sparkle behind the button, replicating the subcategory
  -- SelectedBackground (Blizzard_HousingCatalogCategories.xml:34-60) so Recent
  -- reads like a selected subcategory: the glow spans the full pane width and
  -- 10px above/below the button (its side borders register with the pane's nav
  -- border), and the sparkle is a centered flipbook. Both shown only while
  -- Recent is the active view; RefreshRecentButtonTexture drives visibility.
  -- Created before the icon so they sit behind it.
  local sparkle = recentButton:CreateTexture(nil, "BACKGROUND", nil, 0)
  sparkle:SetAtlas("house-chest-active-nav-highlight-flipbook")
  sparkle:SetSize(76, 82)
  sparkle:Hide()
  recentButton.sparkle = sparkle

  local glow = recentButton:CreateTexture(nil, "BACKGROUND", nil, 1)
  glow:SetPoint("TOP", recentButton, "TOP", 0, 10)
  glow:SetPoint("BOTTOM", recentButton, "BOTTOM", 0, -10)
  glow:SetPoint("LEFT", cats, "LEFT", 0, 0)
  glow:SetPoint("RIGHT", cats, "RIGHT", 0, 0)
  glow:SetAtlas("house-chest-active-nav_selected-bg-glow")
  glow:Hide()
  recentButton.glow = glow
  sparkle:SetPoint("CENTER", glow, "CENTER", 0, 0)  -- centered in the glow, like Blizzard

  local sparkleAnim = recentButton:CreateAnimationGroup()
  sparkleAnim:SetLooping("REPEAT")
  local flipBook = sparkleAnim:CreateAnimation("FlipBook")
  flipBook:SetTarget(sparkle)
  flipBook:SetDuration(2)
  flipBook:SetFlipBookRows(8)
  flipBook:SetFlipBookColumns(6)
  flipBook:SetFlipBookFrames(48)
  recentButton.sparkleAnim = sparkleAnim

  -- Whole-button art from our custom file (HouseEditorButtonRecent.blp). The
  -- visible state - active (selected) / inactive / pressed - is chosen by
  -- TexCoord in RefreshRecentButtonTexture, exactly how the category buttons
  -- swap their state art.
  local tex = recentButton:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints()
  tex:SetTexture(RECENT_BTN_TEX)
  recentButton.tex = tex

  -- Hover brighten: the same art, additive, mirroring the category HoverIcon.
  -- Shown on enter unless pressed (Blizzard's showHoverVisuals = hovered and
  -- not pressed).
  local hover = recentButton:CreateTexture(nil, "OVERLAY")
  hover:SetAllPoints()
  hover:SetTexture(RECENT_BTN_TEX)
  hover:SetBlendMode("ADD")
  hover:SetAlpha(0.5)  -- matches Blizzard's category HoverIcon alpha
  hover:Hide()
  recentButton.hoverBg = hover

  RefreshRecentButtonTexture()  -- initial resting (inactive) art + glow state

  recentButton:SetScript("OnMouseDown", function(self)
    self.pressed = true
    self.hoverBg:Hide()
    RefreshRecentButtonTexture()
  end)
  recentButton:SetScript("OnMouseUp", function(self)
    self.pressed = false
    if self:IsMouseMotionFocus() then self.hoverBg:Show() end
    RefreshRecentButtonTexture()
  end)
  recentButton:SetScript("OnEnter", function(self)
    if not self.pressed then self.hoverBg:Show() end
    if SOUNDKIT.HOUSING_CATALOG_CATEGORY_HOVER then
      PlaySound(SOUNDKIT.HOUSING_CATALOG_CATEGORY_HOVER)
    end
    -- Anchor matches the category buttons' template (ANCHOR_RIGHT, -12, -12).
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -12, -12)
    GameTooltip_SetTitle(GameTooltip, L["Recent"])
    GameTooltip:AddLine(L["by Ludius Plus"], DISABLED_FONT_COLOR.r, DISABLED_FONT_COLOR.g, DISABLED_FONT_COLOR.b, 1, true)
    GameTooltip:Show()
  end)
  recentButton:SetScript("OnLeave", function(self)
    self.hoverBg:Hide()
    GameTooltip_Hide()
  end)
  recentButton:SetScript("OnClick", function()
    -- Like the category buttons, always play the select sound; clicking while
    -- already active has no further effect (no toggle-off - the user leaves
    -- Recent by clicking another category, exactly like the other categories).
    if SOUNDKIT.HOUSING_CATALOG_CATEGORY_SELECT then
      PlaySound(SOUNDKIT.HOUSING_CATALOG_CATEGORY_SELECT)
    end
    if recentMode then return end
    recentMode = true
    -- Focusing a non-"All" category clears any active search (Blizzard does
    -- this in OnCategoryFocusChanged at HouseEditorStorageFrame.lua:832-837);
    -- Recent is a non-"All" view, so match it via Blizzard's own clear.
    if storagePanel.ClearSearchText and storagePanel.catalogSearcher
       and storagePanel.catalogSearcher:GetSearchText() then
      storagePanel:ClearSearchText()
    end
    RefreshParallelCatalog()
  end)

  -- Mask that hides the selected look of whichever pane button is currently
  -- active while Recent is showing - top-level category, subcategory, or the
  -- "All subcategories" standin - so nothing but Recent reads as selected. A
  -- plain texture on a mouse-disabled frame layered just above the buttons,
  -- showing that button's UNSELECTED art (its own GetDefaultTexture). Works for
  -- any of them because they all share BaseHousingCatalogCategoryMixin.
  -- Taint-free: textures never capture mouse (clicks pass through to the real
  -- button), and we only READ the button (anchor + GetDefaultTexture), never
  -- write to it. UpdateRecentButtonVisibility finds the active one and shows it.
  recentSelectionMask = CreateFrame("Frame", nil, cats)
  recentSelectionMask:EnableMouse(false)
  recentSelectionMask:Hide()
  local mtex = recentSelectionMask:CreateTexture(nil, "ARTWORK")
  mtex:SetAllPoints(recentSelectionMask)
  recentSelectionMask.tex = mtex

  -- Hover brightening, mirroring the category HoverIcon (same art, additive).
  -- Driven by polling the masked button's mouse-over in OnUpdate so the mask
  -- can stay mouse-disabled (clicks + tooltip still reach the real button).
  local mhover = recentSelectionMask:CreateTexture(nil, "OVERLAY")
  mhover:SetAllPoints(recentSelectionMask)
  mhover:SetBlendMode("ADD")
  mhover:SetAlpha(0.5)  -- matches Blizzard's category HoverIcon alpha
  mhover:Hide()
  recentSelectionMask.hoverTex = mhover
  recentSelectionMask:SetScript("OnUpdate", function(self)
    local btn = self.maskedButton
    if not btn then return end
    -- Subcategory / "All subcategories" buttons carry an extra pane-wide
    -- selection glow (SelectedBackground) behind them that our icon-sized mask
    -- can't reach. It's purely decorative - never read by secure/protected
    -- code (unlike the store-backed Featured button), so hiding it while masked
    -- is taint-safe. Blizzard re-shows it via SetActive when the user leaves
    -- Recent, and we re-hide here each frame against its relayouts. Top-level
    -- categories have no SelectedBackground (this is a no-op for them).
    if btn.SelectedBackground then btn.SelectedBackground:Hide() end
    -- Mirror the real button's press: while it's pressed its Icon shows the
    -- pressed atlas, so show that on the mask too; otherwise show the inactive
    -- art that hides its selected look. Hover brighten is suppressed while
    -- pressed, exactly like the category buttons.
    local pressed = self.pressedAtlas and btn.Icon and btn.Icon:GetAtlas() == self.pressedAtlas
    self.tex:SetAtlas(pressed and self.pressedAtlas or self.inactiveAtlas)
    self.hoverTex:SetShown(btn:IsMouseOver() and not pressed)
  end)
end


-- The pane button that currently reads as "selected", whichever kind it is:
-- a top-level category, a subcategory, or the "All subcategories" standin. They
-- all share BaseHousingCatalogCategoryMixin, so :IsActive() identifies the one
-- highlighted, and the mask handles any of them with a single code path. Only
-- one is ever active at a time (top-level frames are cleared in subcategory
-- view and vice versa).
local function FindActivePaneButton(cats)
  for _, f in pairs(cats.categoryFramesByID or {}) do
    if f.IsActive and f:IsActive() then return f end
  end
  for _, f in pairs(cats.subcategoryFramesByID or {}) do
    if f.IsActive and f:IsActive() then return f end
  end
  local stand = cats.AllSubcategoriesStandIn
  if stand and stand:IsShown() and stand.IsActive and stand:IsActive() then
    return stand
  end
  return nil
end


-- Restore a button's SelectedBackground glow that our mask's OnUpdate had been
-- hiding each frame. Needed because Blizzard's SetActive is a no-op when
-- isActive is unchanged, so it won't re-show the glow on its own (e.g. when the
-- user re-selects the SAME subcategory after leaving Recent). We mirror what
-- SetActive would do: SetShown + sparkle SetPlaying to match the active state.
local function RestoreMaskedGlow(btn)
  if not (btn and btn.SelectedBackground) then return end
  local active = btn.IsActive and btn:IsActive()
  btn.SelectedBackground:SetShown(active)
  if btn.SelectedBackground.FlipbookSparkleAnim then
    btn.SelectedBackground.FlipbookSparkleAnim:SetPlaying(active)
  end
end


-- Style the header area for Recent: (1) label it "Recent", always in the "All"
-- category's color (HOUSING_STORAGE_HEADER_COLOR) rather than inheriting the
-- last-viewed category's; and (2) hide the CategoryTotal count, which Blizzard
-- would otherwise populate from the underlying focused category - a number
-- that's meaningless for our Recent list. Both are restored when we leave
-- Recent: LeaveRecentMode re-runs Blizzard's UpdateCategoryText (color/label)
-- and UpdateCategoryTotal (re-show + recompute the count).
local function ApplyRecentHeader(storagePanel)
  local oc = storagePanel and storagePanel.OptionsContainer
  if not oc then return end
  if oc.CategoryText then
    oc.CategoryText:SetText(L["Recent"])
    if HOUSING_STORAGE_HEADER_COLOR then
      oc.CategoryText:SetTextColor(HOUSING_STORAGE_HEADER_COLOR:GetRGB())
    end
  end
  if oc.CategoryTotal then oc.CategoryTotal:Hide() end
end


-- Assigned to the forward-declared local so RefreshParallelCatalog (above) can
-- drive it. The Recent button shows whenever the feature is enabled and we're on
-- the Storage tab - including while drilled into a subcategory, so Recent is
-- always reachable; hidden on the Market tab. This is independent of whether the
-- parallel grid is currently active: with the icon resizer off, the grid only
-- activates while the Recent view itself is open, yet the button must stay
-- visible so the user can open it. Clicking it never touches Blizzard's category
-- focus, so it doesn't leave the subcategory menu.
UpdateRecentButtonVisibility = function()
  if not recentButton then return end
  local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
  local cats = storagePanel and storagePanel.Categories

  -- Match whatever buttons surround us. The pane shows its BackButton exactly
  -- in the subcategory view, so use that: subcategory view -> 54px + selection
  -- glow (like the subcategories); top-level view -> 64px + no glow (like the
  -- top-level categories, which show selection by icon swap only). Re-anchor
  -- only on a view change. glowEligible feeds RefreshRecentButtonTexture.
  local inSub = (cats and cats.BackButton and cats.BackButton:IsShown()) and true or false
  recentButton.glowEligible = inSub
  if cats and recentButton.inSub ~= inSub then
    recentButton.inSub = inSub
    recentButton:SetSize(inSub and 54 or 64, inSub and 54 or 64)
    recentButton:ClearAllPoints()
    recentButton:SetPoint("BOTTOM", cats, "BOTTOM", 0, inSub and 12 or 8)
  end

  local show = IsRecentEnabled()
    and storagePanel and not storagePanel:IsInMarketTab()
  recentButton:SetShown(show)
  RefreshRecentButtonTexture()  -- reflect selected (active) vs inactive art + glow
  -- Header text: while in Recent, label it "Recent" (in the "All" color)
  -- instead of the focused Blizzard category. Plain FontString writes are
  -- benign (no taint path); reasserted by the UpdateCategoryText hook against
  -- Blizzard's refreshes, and restored by Blizzard when the user leaves Recent
  -- (clicking another category or searching both run UpdateCategoryText).
  if recentMode then
    ApplyRecentHeader(storagePanel)
  end

  -- Cover whichever pane button is currently selected (category, subcategory,
  -- or "All subcategories" standin) with its unselected art while in Recent
  -- (see EnsureRecentButton). Only READS the button; never writes to it.
  if recentSelectionMask then
    -- Determine which button to mask right now (nil = none).
    local btn = nil
    if recentMode and show and cats then
      local candidate = FindActivePaneButton(cats)
      if candidate and candidate.GetDefaultTexture then
        local iconName, isAtlas = candidate:GetDefaultTexture()
        if iconName and isAtlas then
          btn = candidate
          recentSelectionMask:ClearAllPoints()
          recentSelectionMask:SetAllPoints(btn)
          recentSelectionMask:SetFrameLevel(btn:GetFrameLevel() + 2)
          -- inactive (resting) art, and the pressed art the OnUpdate swaps in
          -- while the button is held. hoverTex always uses the inactive art
          -- since the brighten is suppressed during press.
          recentSelectionMask.inactiveAtlas = iconName
          recentSelectionMask.pressedAtlas = btn.atlasNames and btn.atlasNames["_pressed"]
          recentSelectionMask.tex:SetAtlas(iconName)
          recentSelectionMask.hoverTex:SetAtlas(iconName)
          recentSelectionMask:Show()
        end
      end
    end

    -- When we stop masking a button (or switch to a different one), restore the
    -- glow our OnUpdate had been hiding (Blizzard won't - see RestoreMaskedGlow).
    local prev = recentSelectionMask.maskedButton
    if prev and prev ~= btn then
      RestoreMaskedGlow(prev)
    end
    recentSelectionMask.maskedButton = btn  -- OnUpdate polls this for hover + press

    if not btn then
      recentSelectionMask:Hide()
    end
  end
end


local function SetupRecent()
  -- Recording (all taint-free: hooksecurefunc + our own frame/table):
  --   - Placements & moves: HOUSING_DECOR_PLACE_SUCCESS fires on a real commit
  --     for both. The StartPlacingNewDecor hook only STASHES the exact variant
  --     of the in-progress fresh placement so we record dye fidelity when the
  --     matching success arrives; the event handler does the actual recording.
  --     (Chain placement also hooks StartPlacingNewDecor; chained hooks are fine.)
  --   - Re-dyes of placed decor: hook the dye pane's COMMIT. We deliberately do
  --     NOT use HOUSING_DECOR_CUSTOMIZATION_CHANGED - it fires on every live
  --     PREVIEW swatch click (ApplyDyeToSelectedDecor), so we'd record every
  --     color merely tried, and it also fires in bulk for all decor on editor
  --     close. CommitDyesForSelectedDecor fires only on the genuine Apply.
  if not recentRecordHooked then
    hooksecurefunc(C_HousingBasicMode, "StartPlacingNewDecor", function(entryVariantID)
      if type(entryVariantID) == "table" then
        pendingPlaceVariant = {
          entryType = entryVariantID.entryType,
          recordID = entryVariantID.recordID,
          variantIdentifier = entryVariantID.variantIdentifier,
        }
      end
    end)
    recentPlaceEventFrame = CreateFrame("Frame")
    recentPlaceEventFrame:RegisterEvent("HOUSING_DECOR_PLACE_SUCCESS")
    recentPlaceEventFrame:SetScript("OnEvent", function(_, _event, ...)
      local decorGUID, _, isNew, isPreview = ...
      RecordPlacedDecor(decorGUID, isNew, isPreview)
    end)
    -- Re-dye commit on already-placed decor. The dye pane keeps the decor
    -- selected through the commit (it deselects only afterwards, via
    -- CancelActiveEditing in CloseDyePane), so the selected instance still
    -- resolves here. Its dyeSlots already reflect the previewed (now committed)
    -- colors, so RecordPlacedDecorByGUID reads the final variant - same path
    -- as a move.
    if C_HousingCustomizeMode and C_HousingCustomizeMode.CommitDyesForSelectedDecor then
      hooksecurefunc(C_HousingCustomizeMode, "CommitDyesForSelectedDecor", function()
        local sel = C_HousingCustomizeMode.GetSelectedDecorInfo
                    and C_HousingCustomizeMode.GetSelectedDecorInfo()
        if sel and sel.decorGUID then
          RecordPlacedDecorByGUID(sel.decorGUID)
        end
      end)
    end
    recentRecordHooked = true
  end

  -- Exit the Recent view only on genuine user intent. We deliberately do
  -- NOT key off Categories:SetFocus, because that also fires when the editor
  -- re-shows after a placement (PopulateCategories -> RestoreFocusState ->
  -- SetFocus); keying off it would drop us out of Recent on every placement.
  -- Instead:
  --   - OnCategoryClicked fires only from real category/subcategory/back
  --     button clicks, so it's the true "user picked another category" signal.
  --   - Typing a non-empty search: Blizzard refocuses to "All" and searches
  --     across categories, so Recent should drop out too (just like every
  --     other category does). We can't hook storagePanel.OnSearchTextUpdated -
  --     the SearchBox captured the ORIGINAL via GenerateClosure at Initialize
  --     (HouseEditorStorageFrame.lua:134), so our wrapper would never run -
  --     so we HookScript the SearchBox's OnTextChanged directly.
  local storagePanel = HouseEditorFrame and HouseEditorFrame.StoragePanel
  if storagePanel and storagePanel.Categories and not recentExitHooked then
    hooksecurefunc(storagePanel.Categories, "OnCategoryClicked", function()
      -- A genuine click on another category leaves Recent - but DEFERRED, so we
      -- don't flash the previous category's stale tiles before the new search
      -- completes (see BeginRecentExit / FinishRecentExit). When not in Recent,
      -- render the newly-focused category as usual.
      if recentMode then
        BeginRecentExit()
      else
        RefreshParallelCatalog()
      end
    end)
    if storagePanel.SearchBox then
      storagePanel.SearchBox:HookScript("OnTextChanged", function(box)
        -- A non-empty search refocuses to "All" across categories, so Recent
        -- drops out like any other category would - deferred for the same
        -- no-flash reason as a category click.
        if recentMode and box:GetText() ~= "" then
          BeginRecentExit()
        end
      end)
    end
    -- A pending deferred exit (above) finishes the moment the new category's /
    -- search's results arrive - this is the "new content is ready" cue, so the
    -- swap is snappy rather than waiting out BeginRecentExit's fallback timer.
    -- FinishRecentExit is a no-op when nothing is pending, so normal results
    -- updates are unaffected.
    hooksecurefunc(storagePanel, "OnEntryResultsUpdated", function()
      FinishRecentExit()
    end)
    -- Blizzard recomputes the header text on category/storage refreshes; while
    -- in Recent, reassert "Recent" after it runs so the header doesn't flip
    -- back to the focused category's name. (ApplyRecentHeader also hides the
    -- CategoryTotal count.)
    hooksecurefunc(storagePanel, "UpdateCategoryText", function(self)
      if recentMode then
        ApplyRecentHeader(self)
      end
    end)
    -- Same for the storage-count label: Blizzard re-shows it on its own
    -- refreshes (e.g. an entry's quantity changing), so re-hide it while in
    -- Recent - its count is the underlying category's, not our list's.
    hooksecurefunc(storagePanel, "UpdateCategoryTotal", function(self)
      if recentMode and self.OptionsContainer and self.OptionsContainer.CategoryTotal then
        self.OptionsContainer.CategoryTotal:Hide()
      end
    end)
    recentExitHooked = true
  end

  EnsureRecentButton()
  UpdateRecentButtonVisibility()
end


-- The recording hooks stay registered for the session (hooksecurefunc can't be
-- undone), but RecordRecentEntry gates on IsRecentEnabled, so a disabled feature
-- records nothing. Teardown drops out of the Recent view, hides the button, and
-- PURGES the persisted history: a nil global isn't written to the SavedVariables
-- file, so a disabled feature leaves zero footprint there. (Re-enabling starts a
-- fresh history; SyncRecentList rebuilds the root on the next record/view.)
--
-- This is the SINGLE purge point, and the dispatcher calls it on disable even
-- when the editor isn't loaded (see SetupOrTeardownHouseEditorEnhancer), so
-- toggling Recent off purges immediately regardless of editor state. That means
-- it can run before any of our frames exist - so every frame access here MUST
-- stay nil-guarded.
local function TeardownRecent()
  recentMode = false
  if recentButton then recentButton:Hide() end
  if recentSelectionMask then
    -- Restore the glow we were hiding before dropping the mask, in case we're
    -- torn down mid-Recent over a subcategory.
    RestoreMaskedGlow(recentSelectionMask.maskedButton)
    recentSelectionMask.maskedButton = nil
    recentSelectionMask:Hide()
  end
  LP_houseEditorRecent = nil
  recentEntries = {}  -- detached empty default; re-pointed by SyncRecentList
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
  -- All placement paths (our parallel tile, Blizzard's own tile) funnel through
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
  if not HouseEditorFrame then
    -- The editor isn't loaded yet, so nothing can be SET UP - but a DISABLED
    -- Recent still needs its TEARDOWN to run now, so toggling the feature off
    -- purges its SavedVariable and drops the view immediately, regardless of
    -- whether the editor has ever been opened this session. TeardownRecent is
    -- fully nil-guarded, so it's safe to call before any frames exist.
    if not IsRecentEnabled() then TeardownRecent() end
    return
  end

  -- Two independent flags drive the icon-resizing UI:
  --   iconResizer         - the slider widget under the SearchBox
  --   iconResizerCtrlWheel - CTRL+wheel zoom over the catalog tiles
  -- Either one turns on the scaling hooks; the slider widget itself only
  -- appears when its specific flag is on.
  if IsAnyIconResizingActive() then
    SetupIconResizer()
  else
    TeardownIconResizer()
  end

  -- The parallel catalog renders BOTH the icon-resizer tiles and the Recent
  -- view, so set it up if either feature needs it. On its own it only installs
  -- hooks and stays dormant (native catalog shows) until RefreshParallelCatalog
  -- makes it active - for icon resizing that's always; for Recent-only that's
  -- just while the Recent view is open. So the three features compose freely:
  -- Recent works with the icon resizer on OR off, and with preview/chain.
  if IsParallelCatalogNeeded() then
    SetupParallelCatalog()
  else
    TeardownParallelCatalog()
  end

  if IsRecentEnabled() then
    SetupRecent()
  else
    TeardownRecent()
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
