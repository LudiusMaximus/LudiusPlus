local folderName, addon = ...

-- Automate Auction House confirmation and pet charm buy confirmation.

hooksecurefunc("StaticPopup_Show", function(which, args)

  if not LP_config or not LP_config.dialogSkipper_enabled then return end

  -- print(which, args)

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
      if AuctionHouseFrame then AuctionHouseFrame.ItemBuyFrame.BackButton:Click("LeftButton") end
    end
  end
  
end)



-- Prevent equip bind confirmation.
local f = CreateFrame("Frame")
f:RegisterEvent("EQUIP_BIND_CONFIRM")
f:SetScript("OnEvent", function(self, event, slot)
  if not LP_config or not LP_config.dialogSkipper_enabled or not LP_config.dialogSkipper_skipEquipBind then return end
  
  -- Cannot do this while in combat.
  if not InCombatLockdown() then
    EquipPendingItem(slot)
  end
end)




