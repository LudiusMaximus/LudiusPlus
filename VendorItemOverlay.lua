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
-- Table to store our checkmark textures
local checkmarkFrames = {}
-- Table to store our shadow textures
local shadowFrames = {}

-- Localized strings for "Already known"
local knownStrings

local function InitializeKnownStrings()
  if knownStrings then return end

  local candidates = { _G.ERR_COSMETIC_KNOWN, _G.ITEM_SPELL_KNOWN, _G.USED }
  local unique = {}
  local list = {}

  for _, s in ipairs(candidates) do
    if s and not unique[s] then
      unique[s] = true
      table.insert(list, s)
    end
  end

  if #list == 1 then
    knownStrings = list[1]
  else
    knownStrings = list
  end
end


-- Tooltip used for scanning.
local scannerTooltip = CreateFrame("GameTooltip", "LudiusPlusVendorItemOverlayScannerTooltip", nil, "GameTooltipTemplate")
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
        overlayFrames[i] = overlay
      end

      -- Create a Texture for the checkmark
      if not checkmarkFrames[i] then
        local checkmark = itemButton:CreateTexture(nil, "OVERLAY", nil, 7)
        checkmark:SetAtlas("QuestLog-icon-checkmark-yellow")
        local checkmarkFactor = 1.3
        checkmark:SetSize(17 * checkmarkFactor, 14 * checkmarkFactor)
        checkmark:SetPoint("BOTTOMRIGHT", itemButton, "BOTTOMRIGHT", 5, -4)
        checkmark:Hide()
        checkmarkFrames[i] = checkmark

        -- Shadow
        local shadow = itemButton:CreateTexture(nil, "OVERLAY", nil, 6)
        shadow:SetAtlas("Garr_BuildingShadowOverlay")
        shadow:SetAlpha(0.7)
        shadow:SetSize(32, 32)
        shadow:SetPoint("CENTER", checkmark, "CENTER", -2, -1)
        shadow:Hide()
        shadowFrames[i] = shadow
      end
    end
  end
end


-- Check if an item is already known (Toy, Mount, Transmog, Ensemble, Battle Pet)
local function IsAlreadyKnown(itemLink)
  if not itemLink then return false end
  local itemID = C_Item.GetItemIDForItemInfo(itemLink)
  if not itemID then return false end

  -- Check Toy
  if C_ToyBox and C_ToyBox.GetToyInfo(itemID) then
    if LP_config.vendorItemOverlay_toys_enabled then
      if PlayerHasToy(itemID) then
        return true
      end
    end
    return false
  end

  -- Check Mount
  if C_MountJournal then
    local mountID = C_MountJournal.GetMountFromItem(itemID)
    if mountID then
      if LP_config.vendorItemOverlay_mounts_enabled then
        local isCollected = select(11, C_MountJournal.GetMountInfoByID(mountID))
        if isCollected then
          return true
        end
      end
      return false
    end
  end

  -- Check Battle Pet
  if C_PetJournal and C_PetJournal.GetPetInfoByItemID then
    local speciesID = select(13, C_PetJournal.GetPetInfoByItemID(itemID))
    if speciesID then
      if LP_config.vendorItemOverlay_pets_enabled then
        local numCollected = C_PetJournal.GetNumCollectedInfo(speciesID)
        if numCollected and numCollected > 0 then
          return true
        end
      end
      return false
    end
  end

  -- Check Transmog Set (Ensemble)
  if C_Item.GetItemLearnTransmogSet then
    local setID = C_Item.GetItemLearnTransmogSet(itemLink)
    if setID and C_TransmogSets then
      if LP_config.vendorItemOverlay_transmog_enabled then
        local setInfo = C_TransmogSets.GetSetInfo(setID)
        if setInfo and setInfo.collected then
          return true
        end
      end
      -- We don't return false here, because Ensembles might also be detected via tooltip fallback (e.g. Arsenals)
    end
  end



  -- Check Transmog
  if C_TransmogCollection and C_TransmogCollection.PlayerHasTransmog then
    if C_TransmogCollection.PlayerHasTransmog(itemID) then
      if LP_config.vendorItemOverlay_transmog_enabled then
        return true
      end
      -- We don't return false here, because some items might be transmoggable but not detected by this API,
      -- or we might want to catch them via tooltip fallback if the API says false but tooltip says true (unlikely but possible for edge cases).
      -- However, standard transmog items usually work with this API.
      -- But let's stick to the plan: Toys, Mounts, Pets are definitive.
    end
  end

  -- Check for non-appearance items (Neck, Finger, Trinket)
  if LP_config.vendorItemOverlay_transmog_enabled and LP_config.vendorItemOverlay_transmog_non_appearance_known then
    local itemEquipLoc = select(9, C_Item.GetItemInfo(itemLink))
    if itemEquipLoc == "INVTYPE_NECK" or itemEquipLoc == "INVTYPE_FINGER" or itemEquipLoc == "INVTYPE_TRINKET" then
      return true
    end
  end

  -- Fallback: Check Tooltip for "Already known"
  -- This catches items that the specific APIs missed, or generic "Already known" items.

  -- Determine item type to respect settings
  local shouldCheck = false

  -- We already handled Toys, Mounts and Pets above and returned if matched.
  -- So here we are left with Transmog, Recipes and other stuff.

  -- Check if it is a recipe
  local itemClassID = select(12, C_Item.GetItemInfo(itemLink))
  if itemClassID == Enum.ItemClass.Recipe then
      if LP_config.vendorItemOverlay_recipes_enabled then shouldCheck = true end
  else
      -- Assume everything else (Armor, Weapon, Ensembles) falls under Transmog/Cosmetic
      if LP_config.vendorItemOverlay_transmog_enabled then shouldCheck = true end
  end

  if shouldCheck then
    scannerTooltip:ClearLines()
    scannerTooltip:SetHyperlink(itemLink)
    local numLines = scannerTooltip:NumLines()
    for i = 1, numLines do
      local line = _G[scannerTooltip:GetName().."TextLeft"..i]
      if line then
        local text = line:GetText()

        -- Differentiate between single string and list of strings (in case of multiple "Already known" strings due to localization).
        if type(knownStrings) == "string" then
          if text == knownStrings then
            return true
          end
        elseif knownStrings then
          for _, s in ipairs(knownStrings) do
            if text == s then
              return true
            end
          end
        end

      end
    end
  end

  return false
end


-- Update a single overlay for a specific merchant item index
local function UpdateSingleOverlay(i, index)
  if not overlayFrames[i] then
    return
  end

  local itemLink = GetMerchantItemLink(index)
  local merchantItem = _G["MerchantItem"..i]
  local itemButton = merchantItem.ItemButton

  -- Check if already known and grey out
  if IsAlreadyKnown(itemLink) then
    SetItemButtonDesaturated(itemButton, true)
    if checkmarkFrames[i] then
      checkmarkFrames[i]:Show()
    end
    if shadowFrames[i] then
      shadowFrames[i]:Show()
    end
  else
    if checkmarkFrames[i] then
      checkmarkFrames[i]:Hide()
    end
    if shadowFrames[i] then
      shadowFrames[i]:Hide()
    end
  end

  -- Check if this is a housing decor item
  if IsHousingDecorItem(itemLink) then

    local decorInfo = C_HousingCatalog_GetCatalogEntryInfoByItem(itemLink, true)
    -- print(itemLink, decorInfo.numPlaced, decorInfo.quantity, decorInfo.showQuantity, decorInfo.remainingRedeemable )

    if decorInfo and decorInfo.numPlaced and decorInfo.quantity and decorInfo.remainingRedeemable then

      -- Apparently, if you have never placed but bought an item, the amount in storage is not stored as quantity
      -- but as remainingRedeemable. For our overlay, we treat these the same!
      local amountInStorage = decorInfo.quantity + decorInfo.remainingRedeemable
      local totalOwned = amountInStorage + decorInfo.numPlaced

  
      -- Probably a bug, when we get all 0, don't trust it but double check the (also not reliable) tooltip.
      if amountInStorage == 0 and totalOwned == 0 then
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
                local ttTotalOwned, ttNumPlaced, ttAmountInStorage = string_match(msg, formatString)
                if ttTotalOwned and ttAmountInStorage then
                  -- print("Matched owned info from tooltip:", ttTotalOwned, ttNumPlaced, ttAmountInStorage)
                  local newAmountInStorage = tonumber(ttAmountInStorage)
                  local newTotalOwned = tonumber(ttTotalOwned)
                  if newAmountInStorage ~= amountInStorage or newTotalOwned ~= totalOwned then
                    print("Tooltip corrected API:", itemLink, "amountInStorage:", amountInStorage, "to", newAmountInStorage, "totalOwned", totalOwned, "to", newTotalOwned)
                    amountInStorage = tonumber(ttAmountInStorage)
                    totalOwned = tonumber(ttTotalOwned)
                  end
                  break
                end
              end
            end
          end
        end
      end
      
      -- Display as "storage/total"
      overlayFrames[i]:SetText(string_format("%d/%d", amountInStorage, totalOwned))
      if decorInfo.firstAcquisitionBonus and decorInfo.firstAcquisitionBonus > 0 then
        overlayFrames[i]:SetTextColor(DARKYELLOW_FONT_COLOR:GetRGB())
      else
        overlayFrames[i]:SetTextColor(1, 1, 1, 1)
      end

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
        if checkmarkFrames[i] then
          checkmarkFrames[i]:Hide()
        end
        if shadowFrames[i] then
          shadowFrames[i]:Hide()
        end
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
      if checkmarkFrames[i] then
        checkmarkFrames[i]:Hide()
      end
      if shadowFrames[i] then
        shadowFrames[i]:Hide()
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

  InitializeKnownStrings()

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
    if checkmarkFrames[i] then
      checkmarkFrames[i]:Hide()
    end
    if shadowFrames[i] then
      shadowFrames[i]:Hide()
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