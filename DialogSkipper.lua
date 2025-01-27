


-- Automate Auction House confirmation and pet charm buy confirmation.

hooksecurefunc("StaticPopup_Show", function(which, args)

  -- print(which, args)

  if InCombatLockdown() then return end
  
  local ok = false
  if which == "BUYOUT_AUCTION" then
    ok = true
  elseif which == "CONFIRM_PURCHASE_NONREFUNDABLE_ITEM" then
    if type(args) == "string" and string.find(args, "Polished Pet Charm") then
      ok = true
    end
  end
  if not ok then return end

  
  for i = 1, 10 do
    local frame = _G["StaticPopup" .. i]
    if frame and frame:IsShown() and frame.which and frame.which == which then

       -- Only confirm when more than 1000 gold.
       if which == "BUYOUT_AUCTION" then
          local money = _G["StaticPopup" .. i .. "MoneyFrame"].staticMoney
          if money > 10000000 then return end
       end

      -- Confirm the popup.
      _G["StaticPopup" .. i .. "Button1"]:Click("LeftButton")
      
      -- Also click the back button to return to the overview of items to buy.
      if AuctionHouseFrame then AuctionHouseFrame.ItemBuyFrame.BackButton:Click("LeftButton") end
    end
  end
  
end)


local f = CreateFrame("Frame")
f:RegisterEvent("EQUIP_BIND_CONFIRM")
f:SetScript("OnEvent", function(self, event, slot)
  EquipPendingItem(slot)
end)



