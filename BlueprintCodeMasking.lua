local _, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale("LudiusPlus")

-- ============================================================================
-- BLUEPRINT SHARE-CODE MASKING (streamer privacy)
-- ============================================================================
--
-- Masks the blueprint share codes in Blizzard_HousingBlueprint's import/export
-- boxes with U+25CF bullets, while leaving the real text untouched so Copy /
-- Chat / editing all keep working. See TAINT MODEL below for why we never write
-- the text.
--
--   Import: HousingBlueprintImportFrame.InputContent.ShareCodeBox
--   Export: HousingBlueprintExportFrame.SuccessContent.ShareCodeBox
--
-- (The export frame's InputContent.NameInputBox is the blueprint NAME, not the
-- code, so it is deliberately NOT masked.)
--
-- HOW IT LOOKS
-- ----------------------------------------------------------------------------
-- While masked we hide the box's real text (alpha 0), its selection highlight
-- (transparent) and its scroll bar (alpha 0), and lay a TRANSPARENT cover over
-- it that draws our own bullets, caret, selection, and a 1:1 native scroll bar.
-- The box's own translucent background shows through, so masked and revealed
-- look identical except dots-vs-text.
--
-- Both boxes are InputScrollFrameTemplate whose edit box is multi-line, so both
-- wrap and scroll. Our bullets are a UNIFORM grid: we wrap them ourselves at a
-- fixed bullets-per-line and do all caret/selection/scroll math in that grid,
-- mapping (line,col) back to a character index to drive the real box. The real
-- box's own proportional wrapping is hidden and irrelevant; our grid scrolls on
-- its own dot-row count (SyncBar drives Blizzard's scroll-bar widget; the bar's
-- OnScroll drives our bullets).
--
-- TAINT MODEL (established empirically in-client)
-- ----------------------------------------------------------------------------
-- The taint boundary is the TEXT VALUE, not the frame: writing the text taints
-- the box, so Blizzard's Copy button (GetText -> protected CopyToClipboard) then
-- fires ADDON_ACTION_FORBIDDEN.
--   Taints: SetText, SetPassword (flagged ForceTaint_Strong).
--   Safe:   SetCursorPosition, HighlightText, SetFocus, SetAlpha,
--           SetHighlightColor, geometry (SetWidth/SetPoint), and all reads.
-- So we never write the text - we only move the caret/selection and toggle
-- visual properties.
--
-- ACCEPTED LIMITATIONS: keyboard shift-selection isn't drawn (WoW has no getter
-- for the selection range; the real selection still works for Ctrl-C).
--
-- ENABLE/DISABLE: gated by the LP_config.houseEditorEnhancer_blueprintMasking
-- toggle (IsEnabled). addon.SetupOrTeardownBlueprintMasking() applies it live -
-- enhancing/activating or fully restoring each box.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- FINE-TUNING. Visual position/size knobs per box (pixels). Nothing else needs
-- editing to nudge things into place.
-- ----------------------------------------------------------------------------
local TUNING = {
  import = {
    buttonSize = 40,                                 -- eye button size (square)
    buttonPoint = "TOPLEFT", buttonRel = "TOPRIGHT", -- button corner -> box corner
    buttonX = 4, buttonY = 7,                        -- offset (button sits BESIDE the box)
    boxRightReserve = 32,
  },

  -- The export box is shorter and has share buttons beneath it, so these are
  -- structural placeholders that still want visual tuning in-client.
  export = {
    buttonSize = 29,
    buttonPoint = "TOPLEFT", buttonRel = "TOPRIGHT",
    buttonX = 4, buttonY = 6.5,
    boxRightReserve = 33,

    mouseCaret = false,  -- the native export box ignores mouse caret placement
                         -- (focus + keyboard only); mirror that
  },
}


-- Open eye = mask ON (bullets shown); crossed eye = mask OFF (real code shown).
local EYE_ON  = "128-RedButton-VisibilityOn"
local EYE_OFF = "128-RedButton-VisibilityOff"

local BULLET = "\226\151\143"              -- U+25CF BLACK CIRCLE
local SELECTION_COLOR = { 1, 1, 1, 0.28 }  -- fallback if the box has no highlight colour
local MAX_BULLETS = 5000                   -- safety cap for very long codes
local TEXT_RIGHT_MARGIN = 18               -- px InputScrollFrame reserves on the right for
                                           -- its scroll bar; our dots stop there too

-- Caret-navigation keys that deselect (a keyboard move drops the selection).
local NAV_KEYS = {
  LEFT = true, RIGHT = true, UP = true, DOWN = true,
  HOME = true, END = true, PAGEUP = true, PAGEDOWN = true,
}

local function IsEnabled()
  return LP_config and LP_config.houseEditorEnhancer_blueprintMasking
end

local function SetEyeTexture(button, masked)
  local base = masked and EYE_ON or EYE_OFF
  button:SetNormalAtlas(base)
  button:SetPushedAtlas(base .. "-Pressed")
  button:SetHighlightAtlas(base .. "-Highlight", "ADD")
end

-- Width of a single bullet, measured once and cached.
local function GetBulletWidth(overlay)
  if not overlay.bulletWidth then
    local shown = overlay.Bullets:GetText()
    overlay.Bullets:SetText(BULLET)
    local w = overlay.Bullets:GetStringWidth()
    overlay.Bullets:SetText(shown or "")
    if w and w > 0 then
      overlay.bulletWidth = w
    end
  end
  return overlay.bulletWidth
end

-- Recompute grid metrics (bullet width, line height, bullets-per-line) from the
-- current cover size, cached on the box for the hot paths. The dots reserve the
-- same right margin the real text does, so they end at the scroll bar.
local function RecalcMetrics(box)
  local overlay = box.ludiusOverlay
  local per = GetBulletWidth(overlay) or 1
  box.ludiusPer = per
  box.ludiusLH = overlay.fontHeight or 12
  box.ludiusBPL = math.max(1, math.floor((overlay:GetWidth() - TEXT_RIGHT_MARGIN) / per))
end

-- (x, y) of the top-left of the caret/character at bullet-grid index i, in the
-- cover's frame, accounting for the current scroll offset.
local function IndexToXY(box, i)
  local bpl = box.ludiusBPL or 1
  local line = math.floor(i / bpl)
  local col = i - line * bpl
  return col * (box.ludiusPer or 1),
    -line * (box.ludiusLH or 12) + (box.ludiusScrollOffset or 0)
end

-- Bullet-grid index under the mouse, clamped to what's shown.
local function PointToIndex(box)
  local overlay = box.ludiusOverlay
  local per, lh, bpl = box.ludiusPer or 1, box.ludiusLH or 12, box.ludiusBPL or 1
  local scale = overlay:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  cx, cy = cx / scale, cy / scale
  local lx = cx - overlay:GetLeft()
  local ly = overlay:GetTop() - cy + (box.ludiusScrollOffset or 0)
  local line = math.max(0, math.floor(ly / lh))
  local col = math.max(0, math.min(math.floor(lx / per + 0.5), bpl))
  return math.max(0, math.min(line * bpl + col, box.ludiusBulletCount or 0))
end

-- Byte offset (what SetCursorPosition/HighlightText expect) of the start of the
-- charIndex-th character in the real text (read-only).
local function CharIndexToByte(text, charIndex)
  if charIndex <= 0 then
    return 0
  end
  local i, chars, len = 1, 0, #text
  while i <= len and chars < charIndex do
    local b = string.byte(text, i)
    local size = 1
    if b >= 240 then size = 4
    elseif b >= 224 then size = 3
    elseif b >= 192 then size = 2 end
    i = i + size
    chars = chars + 1
  end
  return i - 1
end

-- Total height of the full bullet grid, and how far it can scroll in the cover.
local function GridHeight(box)
  local totalRows = math.ceil((box.ludiusBulletCount or 0) / (box.ludiusBPL or 1))
  return totalRows * (box.ludiusLH or 12)
end

local function ScrollMax(box)
  return math.max(0, GridHeight(box) - box.ludiusOverlay:GetHeight())
end

-- Reposition the bullet grid for the current (clamped) scroll offset. Does NOT
-- touch the scroll bar - the bar's OnScroll calls this, so touching the bar here
-- would feed back into a loop.
local function PositionBullets(box)
  local overlay = box.ludiusOverlay
  box.ludiusScrollOffset = math.max(0, math.min(box.ludiusScrollOffset or 0, ScrollMax(box)))
  overlay.Bullets:ClearAllPoints()
  overlay.Bullets:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, box.ludiusScrollOffset)
end

-- Push our scroll state onto Blizzard's scroll-bar widget (thumb size + position
-- + step). Guarded so the SetScrollPercentage-driven OnScroll doesn't loop back.
local function SyncBar(box)
  local sb = box.ludiusScrollBar
  if not sb then
    return
  end
  local ourMax = ScrollMax(box)
  if ourMax <= 0 then
    sb:Hide()
    return
  end
  sb:Show()
  local gridH = math.max(1, GridHeight(box))
  box.ludiusBarSyncing = true
  sb:SetPanExtentPercentage((box.ludiusLH or 12) / gridH)
  sb:SetVisibleExtentPercentage(box.ludiusOverlay:GetHeight() / gridH)
  sb:SetScrollPercentage((box.ludiusScrollOffset or 0) / ourMax, true)
  box.ludiusBarSyncing = false
end

local function ApplyScroll(box)
  PositionBullets(box)
  SyncBar(box)
end

-- Auto-scroll so the caret's row stays in view (only while focused).
local function EnsureCaretVisible(box)
  if not box.EditBox:HasFocus() then
    return
  end
  local pos = math.min(box.EditBox:GetUTF8CursorPosition() or 0, box.ludiusBulletCount or 0)
  local lh = box.ludiusLH or 12
  local caretTop = math.floor(pos / (box.ludiusBPL or 1)) * lh
  local viewH = box.ludiusOverlay:GetHeight()
  local off = box.ludiusScrollOffset or 0
  if caretTop < off then
    off = caretTop
  elseif caretTop + lh > off + viewH then
    off = caretTop + lh - viewH
  end
  box.ludiusScrollOffset = off
  ApplyScroll(box)
end

-- Rebuild the bullet grid (one bullet per character, wrapped at bulletsPerLine).
-- Every bullet is rendered; the clipped cover scrolls over them. Shown whenever
-- masked (even empty, so the caret shows in an empty focused field - harmless
-- since the cover is transparent).
local function UpdateBullets(box)
  local overlay = box.ludiusOverlay
  if not overlay then
    return
  end
  RecalcMetrics(box)

  local bpl = box.ludiusBPL
  local count = math.min(box.EditBox:GetNumLetters() or 0, MAX_BULLETS)
  box.ludiusBulletCount = count

  if count == 0 then
    overlay.Bullets:SetText("")
  else
    local parts = {}
    for i = 1, count do
      parts[#parts + 1] = BULLET
      if i % bpl == 0 and i < count then
        parts[#parts + 1] = "\n"
      end
    end
    overlay.Bullets:SetText(table.concat(parts))
  end
  ApplyScroll(box)
  overlay:SetShown(box.ludiusMasked)
end

-- Our caret mirrors the real cursor (read-only).
local function UpdateCaret(box)
  local overlay = box.ludiusOverlay
  local caret = overlay and overlay.Caret
  if not caret then
    return
  end
  if not (box.ludiusMasked and box.EditBox:HasFocus()) then
    caret:Hide()
    return
  end
  local pos = math.min(box.EditBox:GetUTF8CursorPosition() or 0, box.ludiusBulletCount or 0)
  local x, y = IndexToXY(box, pos)
  caret:ClearAllPoints()
  caret:SetPoint("TOPLEFT", overlay, "TOPLEFT", x, y)
  caret:Show()
  overlay.blink = 0
  caret:SetAlpha(1)
end

local function GetSelRect(overlay, i)
  overlay.selRects = overlay.selRects or {}
  local r = overlay.selRects[i]
  if not r then
    r = overlay:CreateTexture(nil, "ARTWORK")
    r:SetColorTexture(unpack(overlay.selColor or SELECTION_COLOR))
    overlay.selRects[i] = r
  end
  return r
end

-- Draw the mouse/Ctrl+A selection as one rectangle per covered grid row.
local function UpdateSelection(box)
  local overlay = box.ludiusOverlay
  if not overlay then
    return
  end
  if overlay.selRects then
    for _, r in ipairs(overlay.selRects) do
      r:Hide()
    end
  end

  local a, b = box.ludiusSelA, box.ludiusSelB
  local count = box.ludiusBulletCount or 0
  if not (box.ludiusMasked and a and b) then
    return
  end
  a, b = math.min(a, count), math.min(b, count)
  if b <= a then
    return
  end

  local per, lh, bpl = box.ludiusPer, box.ludiusLH, box.ludiusBPL
  local firstLine, lastLine = math.floor(a / bpl), math.floor(b / bpl)
  local ri = 0
  for line = firstLine, lastLine do
    local colFrom = (line == firstLine) and (a - line * bpl) or 0
    local colTo = (line == lastLine) and (b - line * bpl) or bpl
    if colTo > colFrom then
      ri = ri + 1
      local r = GetSelRect(overlay, ri)
      local x, y = IndexToXY(box, line * bpl + colFrom)  -- reuses the scroll-aware layout
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", overlay, "TOPLEFT", x, y)
      r:SetSize((colTo - colFrom) * per, lh)
      r:Show()
    end
  end
end

-- Free a gap on the box's right for the eye button. A layout-managed box (import:
-- an "expand" child) gets a wider right padding, which grows the content area and
-- opens the gap while the box itself stays put; an explicitly anchored box
-- (export) just gets its right edge pulled in. Runs once, at setup.
local function ShrinkBox(box)
  local reserve = box.ludiusTuning.boxRightReserve
  if not (reserve and reserve > 0) then
    return
  end
  if box.rightPadding ~= nil then
    box.ludiusBaseRightPadding = box.ludiusBaseRightPadding or box.rightPadding
    box.rightPadding = box.ludiusBaseRightPadding + reserve
    local parent = box:GetParent()
    if parent then
      if parent.MarkDirty then parent:MarkDirty() end
      if parent.Layout then parent:Layout() end
    end
  else
    box:SetPoint("RIGHT", box:GetParent(), "RIGHT", -reserve, 0)
    -- The export Copy button anchors its TOPRIGHT to the box's BOTTOMRIGHT, so it
    -- would follow the box inward. Push its right point back out by the same
    -- amount to keep it in place. (y = -15 matches its XML anchor.)
    local copyButton = box:GetParent().ClipboardButton
    if copyButton then
      copyButton:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", reserve, -15)
    end
  end
end

-- Reverse of ShrinkBox: restore the box (and the export Copy button) to Blizzard's
-- original geometry when the feature is switched off.
local function UnshrinkBox(box)
  local reserve = box.ludiusTuning.boxRightReserve
  if not (reserve and reserve > 0) then
    return
  end
  if box.rightPadding ~= nil then
    box.rightPadding = box.ludiusBaseRightPadding or box.rightPadding
    local parent = box:GetParent()
    if parent then
      if parent.MarkDirty then parent:MarkDirty() end
      if parent.Layout then parent:Layout() end
    end
  else
    box:SetPoint("RIGHT", box:GetParent(), "RIGHT", 0, 0)
    local copyButton = box:GetParent().ClipboardButton
    if copyButton then
      copyButton:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -15)
    end
  end
end

-- Apply the current masked/revealed state to the real box's visuals: hide (or
-- restore) its text, selection highlight, and scroll bar. Visual-only, so no taint.
local function ApplyMaskVisuals(box)
  local editBox, masked = box.EditBox, box.ludiusMasked
  editBox:SetAlpha(masked and 0 or 1)
  if masked then
    editBox:SetHighlightColor(0, 0, 0, 0)
  else
    editBox:SetHighlightColor(unpack(box.ludiusOverlay.selColor or SELECTION_COLOR))
  end
  if box.ScrollBar then
    box.ScrollBar:SetAlpha(masked and 0 or 1)
  end
end

-- Boxes we've enhanced, so a config toggle can re-activate or restore them all.
local enhancedBoxes = {}

-- Add the mask overlay + eye button to one InputScrollFrameTemplate share-code
-- box. Idempotent. Never writes the box's text.
local function EnhanceShareCodeBox(box, tuning)
  if not box or not box.EditBox or box.ludiusOverlay then
    return
  end
  box.ludiusTuning = tuning
  enhancedBoxes[#enhancedBoxes + 1] = box
  local editBox = box.EditBox
  -- Whether mouse clicks position the caret / drag-select. The export box natively
  -- ignores mouse caret placement (focus + keyboard only), so we mirror that.
  local mouseCaret = tuning.mouseCaret ~= false

  -- Eye button: our own frame, placed and sized entirely from TUNING.
  local button = CreateFrame("Button", nil, box)
  button:SetSize(tuning.buttonSize, tuning.buttonSize)
  button:SetPoint(tuning.buttonPoint, box, tuning.buttonRel, tuning.buttonX, tuning.buttonY)
  button:SetFrameLevel(editBox:GetFrameLevel() + 10)
  box.ludiusMaskButton = button

  -- Cover: transparent (the box's own translucent bg shows through), mouse-
  -- enabled to capture interaction in bullet space, clipped so scrolled-off
  -- bullets/caret/selection don't spill.
  local overlay = CreateFrame("Frame", nil, box)
  overlay:SetFrameLevel(editBox:GetFrameLevel() + 5)
  overlay:EnableMouse(mouseCaret)  -- transparent to clicks when the box has no mouse caret
  overlay:EnableMouseWheel(true)
  overlay:SetClipsChildren(true)
  overlay:SetAllPoints(box)
  box.ludiusOverlay = overlay

  local bullets = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bullets:SetJustifyH("LEFT")
  bullets:SetJustifyV("TOP")
  bullets:SetWordWrap(true)  -- needed for our explicit "\n" grid breaks to render
  bullets:SetPoint("TOPLEFT", overlay, "TOPLEFT")
  -- GameFontHighlightSmall's font (FRIZQT__.TTF) lacks U+25CF; the chat edit box's
  -- font file has it, so borrow that file at our own size.
  local _, hlSize, hlFlags = GameFontHighlightSmall:GetFont()
  local chatFile = ChatFrame1EditBox and (ChatFrame1EditBox:GetFont())
  if chatFile then
    bullets:SetFont(chatFile, hlSize, hlFlags)
  end
  overlay.Bullets = bullets
  overlay.fontHeight = select(2, bullets:GetFont()) or 12
  overlay.selColor = { editBox:GetHighlightColor() }  -- match the box's own selection colour

  local caret = overlay:CreateTexture(nil, "OVERLAY")
  caret:SetSize(2, overlay.fontHeight + 2)  -- 2px wide, like Blizzard's caret
  caret:SetColorTexture(1, 1, 1, 1)
  caret:Hide()
  overlay.Caret = caret

  -- Scroll bar: Blizzard's OWN MinimalScrollBar widget pinned exactly onto the
  -- box's (hidden) bar, so ours is 1:1 native and pixel-congruent. We drive it
  -- from our dot-grid scroll (SyncBar) and mirror its OnScroll back onto the
  -- bullets (user drag / arrow / track click).
  local sb = CreateFrame("EventFrame", nil, overlay, "MinimalScrollBar")
  sb:SetFrameLevel(overlay:GetFrameLevel() + 5)
  if box.ScrollBar then
    sb:SetAllPoints(box.ScrollBar)
  end
  sb:Init(1, 0.1)  -- visible/pan percentages; SyncBar sets the real values
  box.ludiusScrollBar = sb
  sb:RegisterCallback(ScrollBarMixin.Event.OnScroll, function(_owner, scrollPercentage)
    if box.ludiusBarSyncing then
      return  -- our own SyncBar push; don't feed it back
    end
    box.ludiusScrollOffset = scrollPercentage * ScrollMax(box)
    PositionBullets(box)
    UpdateCaret(box)
    UpdateSelection(box)
  end, box)

  -- Initial state: masked.
  box.ludiusMasked = true
  SetEyeTexture(button, true)
  ShrinkBox(box)
  ApplyMaskVisuals(box)
  UpdateBullets(box)
  UpdateCaret(box)

  -- Click positions the caret; drag selects. Both translate bullet-space into a
  -- character index and drive the real box with taint-safe setters. Skipped when
  -- the box has no mouse caret (export) - clicks fall through to the real box, so
  -- it focuses/positions natively and our caret mirrors it via OnCursorChanged.
  if mouseCaret then
    overlay:SetScript("OnMouseDown", function(_self, mouseButton)
      if mouseButton ~= "LeftButton" then
        return
      end
      editBox:SetFocus()
      local idx = PointToIndex(box)
      editBox:SetCursorPosition(CharIndexToByte(editBox:GetText(), idx))
      editBox:HighlightText(0, 0)
      box.ludiusDragStart = idx
      box.ludiusDragging = true
      box.ludiusSelA, box.ludiusSelB = idx, idx
      UpdateSelection(box)
      UpdateCaret(box)
    end)
    overlay:SetScript("OnMouseUp", function()
      box.ludiusDragging = false
    end)
  end
  overlay:SetScript("OnMouseWheel", function(_self, delta)
    box.ludiusScrollOffset = (box.ludiusScrollOffset or 0) - delta * (box.ludiusLH or 12) * 3
    ApplyScroll(box)
    UpdateCaret(box)
    UpdateSelection(box)
  end)

  overlay:SetScript("OnUpdate", function(self, elapsed)
    if box.ludiusDragging then
      if not IsMouseButtonDown("LeftButton") then
        box.ludiusDragging = false
        return
      end
      local cur = PointToIndex(box)
      local start = box.ludiusDragStart or cur
      local a, b = math.min(start, cur), math.max(start, cur)
      box.ludiusSelA, box.ludiusSelB = a, b
      local text = editBox:GetText()
      if b > a then
        editBox:HighlightText(CharIndexToByte(text, a), CharIndexToByte(text, b))
      else
        editBox:HighlightText(0, 0)
      end
      editBox:SetCursorPosition(CharIndexToByte(text, cur))
      UpdateSelection(box)
      UpdateCaret(box)
    else
      local caret = self.Caret  -- blink
      if caret:IsShown() then
        self.blink = (self.blink or 0) + elapsed
        if self.blink >= 0.53 then
          self.blink = 0
          caret:SetAlpha(caret:GetAlpha() > 0.5 and 0 or 1)
        end
      end
    end
  end)

  -- Read-only, taint-safe hooks. Deselection is driven by explicit user actions
  -- (typing, nav keys, clicks) rather than OnCursorChanged, because cursor events
  -- also fire on focus loss/regain (eye-toggle) and would wipe a selection we
  -- want to keep across the toggle.
  editBox:HookScript("OnTextChanged", function()
    box.ludiusSelA, box.ludiusSelB = nil, nil
    UpdateBullets(box)
    EnsureCaretVisible(box)
    UpdateSelection(box)
    UpdateCaret(box)
  end)
  editBox:HookScript("OnCursorChanged", function()
    EnsureCaretVisible(box)
    UpdateCaret(box)
  end)
  editBox:HookScript("OnKeyDown", function(_self, key)
    if key == "A" and IsControlKeyDown() and box.ludiusMasked and box.EditBox:HasFocus() then
      editBox:HighlightText()  -- select all; Ctrl-C then copies the whole code
      box.ludiusSelA, box.ludiusSelB = 0, box.ludiusBulletCount or 0
      UpdateSelection(box)
      UpdateCaret(box)
    elseif NAV_KEYS[key] then
      box.ludiusSelA, box.ludiusSelB = nil, nil  -- a keyboard caret move deselects
      UpdateSelection(box)
    end
  end)
  editBox:HookScript("OnEditFocusGained", function()
    box.ludiusFocused = true
    UpdateCaret(box)
  end)
  editBox:HookScript("OnEditFocusLost", function()
    -- Track when focus was lost so a toggle in the same instant can restore it
    -- (see the button OnClick). Hide the now-inactive caret.
    box.ludiusFocused = false
    box.ludiusUnfocusedAt = GetTime()
    UpdateCaret(box)
  end)
  box:HookScript("OnSizeChanged", function()
    UpdateBullets(box)
    UpdateSelection(box)
    UpdateCaret(box)
  end)
  box:HookScript("OnMouseDown", function()
    -- Fires only when revealed (our overlay captures clicks while masked): the
    -- user is interacting natively, so drop our selection to stay in sync.
    box.ludiusSelA, box.ludiusSelB = nil, nil
    UpdateSelection(box)
  end)

  local function ShowButtonTooltip()
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOMRIGHT")
    GameTooltip_SetTitle(GameTooltip, box.ludiusMasked and L["Show blueprint code"] or L["Hide blueprint code"])
    GameTooltip:AddLine(L["by Ludius Plus"], DISABLED_FONT_COLOR.r, DISABLED_FONT_COLOR.g, DISABLED_FONT_COLOR.b, 1, true)
    GameTooltip:Show()
  end

  button:SetScript("OnClick", function(self)
    -- The click clears the box's focus (WoW default) before OnClick runs, so
    -- HasFocus() is already false; treat it as focused if it was in this instant.
    local wasFocused = editBox:HasFocus() or box.ludiusFocused
      or (box.ludiusUnfocusedAt and (GetTime() - box.ludiusUnfocusedAt) < 0.5)

    box.ludiusMasked = not box.ludiusMasked
    if box.ludiusMasked and not (box.ludiusSelA and box.ludiusSelB) then
      -- Masking with no overlay selection to restore: a native selection made
      -- while revealed can't be read/mirrored, so drop it - masked and real stay
      -- in sync at "no selection". One of ours that survived the toggle is kept.
      editBox:HighlightText(0, 0)
    end
    ApplyMaskVisuals(box)
    SetEyeTexture(self, box.ludiusMasked)
    UpdateBullets(box)
    UpdateSelection(box)
    UpdateCaret(box)
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)

    -- The label now describes the opposite action, so refresh the tooltip in
    -- place if it is still hovered instead of waiting for a re-enter.
    if GameTooltip:IsOwned(self) then
      ShowButtonTooltip()
    end

    -- Restore the focus the click stole, next frame (after the click's own focus
    -- handling), so the user can keep typing/selecting through a toggle.
    if wasFocused then
      C_Timer.After(0, function()
        if editBox:IsVisible() then
          editBox:SetFocus()
        end
      end)
    end
  end)

  button:SetScript("OnEnter", ShowButtonTooltip)
  button:SetScript("OnLeave", GameTooltip_Hide)
end

-- Switch the feature on/off for one already-enhanced box: activate (shrink the
-- box, apply the mask visuals, show our overlay) or fully restore Blizzard's box.
-- The widgets/hooks stay in place either way; only the visuals + geometry change.
local function SetBlueprintMaskActive(box, active)
  box.ludiusMaskButton:SetShown(active)
  if active then
    box.ludiusMasked = true  -- enabling the feature starts masked
    SetEyeTexture(box.ludiusMaskButton, true)
    ShrinkBox(box)
    ApplyMaskVisuals(box)
    box.ludiusOverlay:SetShown(true)
  else
    -- Revealed state, so the still-installed edit-box hooks (OnTextChanged etc.)
    -- keep our overlay hidden instead of re-showing it on the next edit.
    box.ludiusMasked = false
    UnshrinkBox(box)
    box.EditBox:SetAlpha(1)
    box.EditBox:SetHighlightColor(unpack(box.ludiusOverlay.selColor or SELECTION_COLOR))
    if box.ScrollBar then
      box.ScrollBar:SetAlpha(1)
    end
    box.ludiusOverlay:Hide()
  end
end

local function EnhanceBlueprintFrames()
  if not IsEnabled() then
    return
  end
  if HousingBlueprintImportFrame and HousingBlueprintImportFrame.InputContent then
    EnhanceShareCodeBox(HousingBlueprintImportFrame.InputContent.ShareCodeBox, TUNING.import)
  end
  if HousingBlueprintExportFrame and HousingBlueprintExportFrame.SuccessContent then
    EnhanceShareCodeBox(HousingBlueprintExportFrame.SuccessContent.ShareCodeBox, TUNING.export)
  end
end

-- Public entry point for the options toggle. Enhances the boxes if the feature is
-- on and the blueprint UI is already loaded, then activates/restores each one.
function addon.SetupOrTeardownBlueprintMasking()
  local active = IsEnabled()
  if active then
    EnhanceBlueprintFrames()
  end
  for _, box in ipairs(enhancedBoxes) do
    SetBlueprintMaskActive(box, active)
  end
end

-- Blizzard_HousingBlueprint is LoadOnDemand; ContinueOnAddOnLoaded fires
-- immediately if it is already loaded, otherwise once it loads.
EventUtil.ContinueOnAddOnLoaded("Blizzard_HousingBlueprint", EnhanceBlueprintFrames)



-- There is no in-game string to directly use for "House Editor".
-- To get the translations right, let the translators extract the string to use from these:
-- ERR_HOUSING_RESULT_BLUEPRINT_NOT_FOUND
-- EN:  "Blueprint not found"
-- DE:  "Bauplan nicht gefunden"
-- FR:  "Plan introuvable"
-- IT:  "Progetto non trovato"
-- ES:  "Plano no encontrado"
-- MX:  "No se encontró el plano"
-- BR:  "Diagrama não encontrado"
-- RU:  "Чертеж не найден"
-- KR:  "청사진을 찾을 수 없습니다."
-- TW:  "找不到該藍圖"
-- CN:  "未找到图纸"



-- -- For coding:
-- -- Show a dummy export frame for fine-tuning the variabls.
-- EventUtil.RegisterOnceFrameEventAndCallback("PLAYER_LOGIN", function()
--   C_AddOns.LoadAddOn("Blizzard_HousingBlueprint")
--   EnhanceBlueprintFrames()  -- idempotent; ensures the box is enhanced before we populate it
--   local f = HousingBlueprintExportFrame
--   if not (f and f.SuccessContent) then
--     return
--   end
--   f:Show()  -- plain Show (not ShowSelf) so it appears at its XML anchor, no UI-panel routing
--   f:ShowContent(f.SuccessContent)
--   -- Long enough to wrap to several dot-rows so the scroll bar shows too.
--   f.SuccessContent:SetData("Test Blueprint", string.rep("ABCDEFGHJKLMNPQRSTUVWXYZ23456789", 12))
-- end)
