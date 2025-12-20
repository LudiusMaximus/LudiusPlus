local folderName, addon = ...

-- VendorItemOverlay module
-- Adds overlay text to vendor item icons for player housing decor items

local MERCHANT_ITEMS_PER_PAGE = 10


-- Frequently used global functions.
local C_Item_GetItemInfo                         = _G.C_Item.GetItemInfo
local C_HousingCatalog_GetCatalogEntryInfoByItem = _G.C_HousingCatalog.GetCatalogEntryInfoByItem
local GetMerchantItemLink                        = _G.GetMerchantItemLink
local GetMerchantNumItems                        = _G.GetMerchantNumItems
local string_find                                = _G.string.find
local string_format                              = _G.string.format
local string_match                               = _G.string.match


-- Table to store our overlay text frames
local overlayFrames = {}


-- Tooltip used for scanning.
local scannerTooltip = CreateFrame("GameTooltip", "BagnonRequiredLevelScannerTooltip", nil, "GameTooltipTemplate")
scannerTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

-- Convert the format string to a pattern for matching
-- HOUSING_DECOR_OWNED_COUNT_FORMAT = "Owned: |cnHIGHLIGHT_FONT_COLOR:%d (Placed: %d, Storage: %d)|r"
local formatString = HOUSING_DECOR_OWNED_COUNT_FORMAT
-- Remove color codes
formatString = string.gsub(formatString, "|c%x%x%x%x%x%x%x%x", "")
formatString = string.gsub(formatString, "|r", "")
-- Escape all pattern special characters except %
formatString = string.gsub(formatString, "([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
-- Now replace %d with capture pattern - must escape the % first
formatString = string.gsub(formatString, "%%d", "(%%d+)")



-- Check if an item is a housing decor item
local function IsHousingDecorItem(itemLink)
  if not itemLink then
    return false
  end

  local itemClassID, itemSubclassID = select(12, C_Item_GetItemInfo(itemLink))
  return itemClassID == Enum.ItemClass.Housing and itemSubclassID == Enum.ItemHousingSubclass.Decor
end


-- Create overlay text for each merchant item button
local function CreateOverlayFrames()
  for i = 1, MERCHANT_ITEMS_PER_PAGE do
    local merchantItem = _G["MerchantItem"..i]
    if merchantItem and merchantItem.ItemButton then
      local itemButton = merchantItem.ItemButton

      -- Create a FontString for the overlay text
      if not overlayFrames[i] then
        local overlay = itemButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmallOutline")
        overlay:SetPoint("TOPRIGHT", itemButton, "TOPRIGHT", -1, -2)
        overlay:SetTextColor(1, 1, 1, 1)
        overlayFrames[i] = overlay
      end
    end
  end
end


-- Update a single overlay for a specific merchant item index
local function UpdateSingleOverlay(i, index)
  if not overlayFrames[i] then
    return
  end

  local itemLink = GetMerchantItemLink(index)

  -- Check if this is a housing decor item
  if IsHousingDecorItem(itemLink) then

    local decorInfo = C_HousingCatalog_GetCatalogEntryInfoByItem(itemLink, true)
    -- print(itemLink, decorInfo.numPlaced, decorInfo.numStored)

    -- Probably a bug, but when numStored is 0, numPlaced also returns 0 even when there are some placed.
    -- So we double check the tooltip.
    if not decorInfo or (decorInfo.numPlaced == 0 and decorInfo.numStored == 0) then
      scannerTooltip:ClearLines()
      scannerTooltip:SetItemByID(C_Item.GetItemIDForItemInfo(itemLink))

      -- Scan tooltip lines for owned count info. Start from line 4 to skip item name and basic info.
      for j = 4, scannerTooltip:NumLines(), 1 do
        local line = _G[scannerTooltip:GetName().."TextLeft"..j]
        if line then
          local msg = line:GetText()
          if msg then
            -- print(j, msg)
            if string_find(msg, formatString) then
              local totalOwned, placed, inStorage = string_match(msg, formatString)
              if placed and inStorage then
                -- print("Matched owned info from tooltip:", totalOwned, placed, inStorage)
                decorInfo = decorInfo or {}
                decorInfo.numPlaced = tonumber(placed)
                decorInfo.numStored = tonumber(inStorage)
                break
              end
            end
          end
        end
      end

    end

    -- Calculate total owned and in storage
    local totalOwned = decorInfo.numPlaced + decorInfo.numStored
    local inStorage = decorInfo.numStored

    if totalOwned and inStorage then
      -- Display as "storage/total"
      overlayFrames[i]:SetText(string_format("%d/%d", inStorage, totalOwned))
      overlayFrames[i]:Show()
    else
      overlayFrames[i]:Hide()
    end

  -- No decor item.
  else
    overlayFrames[i]:Hide()
  end
end

-- Update overlay visibility and content based on merchant frame state
local function UpdateOverlays()
  if not MerchantFrame or not MerchantFrame:IsShown() then
    return
  end

  -- Update overlays for visible items
  local numMerchantItems = GetMerchantNumItems()
  for i = 1, MERCHANT_ITEMS_PER_PAGE do
    local index = (((MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE) + i)
    if overlayFrames[i] then
      if index <= numMerchantItems and MerchantFrame.selectedTab == 1 then
        UpdateSingleOverlay(i, index)
      else
        overlayFrames[i]:Hide()
      end
    end
  end
end


-- Event handler frame
local eventFrame = CreateFrame("Frame")
local isHooked = false






local function EventFrameScript(self, event, ...)

  if event == "HOUSING_STORAGE_ENTRY_UPDATED" then
    -- Update overlays when housing storage is updated
    if MerchantFrame and MerchantFrame:IsShown() then
      UpdateOverlays()
    end

  elseif event == "MERCHANT_CLOSED" then
    -- Hide all overlays when merchant closes
    for i = 1, MERCHANT_ITEMS_PER_PAGE do
      if overlayFrames[i] then
        overlayFrames[i]:Hide()
      end
    end

  elseif event == "PLAYER_ENTERING_WORLD" then
    -- print("PLAYER_ENTERING_WORLD")

    -- Initialize housing catalog.
    -- We just have to call CreateCatalogSearcher() once for the API to return the correct values.
    -- Got to wait for 2 seconds, otherwise it has been seen to not work right after logging in.
    C_Timer.After(2, function()
      C_HousingCatalog.CreateCatalogSearcher()
    end)

  elseif event == "ADDON_LOADED" then
    -- print("ADDON_LOADED")
    local addonName = ...
    if addonName == "LudiusPlus" then
      self:UnregisterEvent("ADDON_LOADED")
      addon.SetupOrTeardownVendorItemOverlay()
    end

  end
end



local function SetupVendorItemOverlay()
  -- print("SetupVendorItemOverlay")

  -- Initialize housing catalog (in case module is enabled mid-session).
  C_Timer.After(2, function()
    C_HousingCatalog.CreateCatalogSearcher()
  end)

  -- Register event handlers.
  eventFrame:RegisterEvent("HOUSING_STORAGE_ENTRY_UPDATED")
  eventFrame:RegisterEvent("MERCHANT_CLOSED")
  eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  eventFrame:SetScript("OnEvent", EventFrameScript)


  -- Create overlay frames if not already created
  if #overlayFrames == 0 then
    CreateOverlayFrames()
  end


  -- Hook into MerchantFrame_Update (can only be done once)
  if not isHooked then
    hooksecurefunc("MerchantFrame_Update", function()
      if LP_config and LP_config.vendorItemOverlay_enabled then
        UpdateOverlays()
      end
    end)
    isHooked = true
  end

end


local function TeardownVendorItemOverlay()
  -- print("TeardownVendorItemOverlay")

  -- Unregister events
  eventFrame:UnregisterEvent("HOUSING_STORAGE_ENTRY_UPDATED")
  eventFrame:UnregisterEvent("MERCHANT_CLOSED")
  eventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
  eventFrame:SetScript("OnEvent", nil)

  -- Hide all overlays
  for i = 1, MERCHANT_ITEMS_PER_PAGE do
    if overlayFrames[i] then
      overlayFrames[i]:Hide()
    end
  end
end

function addon.SetupOrTeardownVendorItemOverlay()
  if LP_config and LP_config.vendorItemOverlay_enabled then
    SetupVendorItemOverlay()
  else
    TeardownVendorItemOverlay()
  end
end


-- Initialize when addon loads
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", EventFrameScript)