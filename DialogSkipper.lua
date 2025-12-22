local folderName, addon = ...

-- Automate Auction House confirmation and pet charm buy confirmation.

local isHooked = false

local eventFrame = CreateFrame("Frame")


local function EventFrameScript(self, event, ...)

  if event == "EQUIP_BIND_CONFIRM" then
    local slot = ...
    -- Cannot do this while in combat.
    if not InCombatLockdown() then
      EquipPendingItem(slot)
    end

  elseif event == "ADDON_LOADED" then
    local addonName = ...
    if addonName == "LudiusPlus" then
      self:UnregisterEvent("ADDON_LOADED")
      addon.SetupOrTeardownDialogSkipper()
    end

  end
end


local function SetupDialogSkipper()
  -- print("SetupDialogSkipper")

  eventFrame:SetScript("OnEvent", EventFrameScript)

  -- Only register EQUIP_BIND_CONFIRM if skipEquipBind is enabled.
  if LP_config.dialogSkipper_skipEquipBind then
    eventFrame:RegisterEvent("EQUIP_BIND_CONFIRM")
  else
    -- If skipEquipBind is disabled, ensure the event is unregistered.
    eventFrame:UnregisterEvent("EQUIP_BIND_CONFIRM")
  end

  -- Hook StaticPopup_Show only once
  if not isHooked then
    hooksecurefunc("StaticPopup_Show", function(which, args)
      if not LP_config or not LP_config.dialogSkipper_enabled then return end
      if InCombatLockdown() then return end

      local ok = false
      if which == "BUYOUT_AUCTION" and LP_config.dialogSkipper_skipAuction then
        ok = true
      elseif which == "CONFIRM_PURCHASE_NONREFUNDABLE_ITEM" and LP_config.dialogSkipper_skipPetCharm then
        local polishedPetCharmName = GetItemInfo(163036)
        if type(args) == "string" and polishedPetCharmName and string.find(args, polishedPetCharmName) then
          ok = true
        end
      elseif which == "CONFIRM_PURCHASE_TOKEN_ITEM" and LP_config.dialogSkipper_skipOrderResources then
        local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(1220)
        local orderResourcesName = currencyInfo and currencyInfo.name
        if type(args) == "string" and orderResourcesName and string.find(args, orderResourcesName) then
          ok = true
        end
      end
      if not ok then return end

      for i = 1, 10 do
        local frame = _G["StaticPopup" .. i]
        if frame and frame:IsShown() and frame.which and frame.which == which then

          -- Only confirm when price is below limit.
          if which == "BUYOUT_AUCTION" then
            local money = _G["StaticPopup" .. i .. "MoneyFrame"].staticMoney
            if money > LP_config.dialogSkipper_auctionPriceLimit then return end
          end

          -- Confirm the popup.
          _G["StaticPopup" .. i .. "Button1"]:Click("LeftButton")

          -- Also click the back button to return to the overview of items to buy.
          if LP_config.dialogSkipper_auctionBackButton and AuctionHouseFrame then
            AuctionHouseFrame.ItemBuyFrame.BackButton:Click("LeftButton")
          end
        end
      end
    end)
    isHooked = true
  end
end


local function TeardownDialogSkipper()
  -- print("TeardownDialogSkipper")

  eventFrame:UnregisterEvent("EQUIP_BIND_CONFIRM")
  eventFrame:SetScript("OnEvent", nil)
end


function addon.SetupOrTeardownDialogSkipper()
  if LP_config and LP_config.dialogSkipper_enabled then
    SetupDialogSkipper()
  else
    TeardownDialogSkipper()
  end
end


-- Initialize when addon loads
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", EventFrameScript)




