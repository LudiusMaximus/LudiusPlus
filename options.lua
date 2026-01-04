local folderName, addon = ...
LibStub("AceAddon-3.0"):NewAddon(addon, folderName)
local L = LibStub("AceLocale-3.0"):GetLocale(folderName, true)
if not L then
  L = {}
  setmetatable(L, {__index = function(t, k) return k end})
end

-- For the options menu.
local appName = "Ludius Plus"


-- A local variable for saved variable LP_config for easier access.
local config

local CONFIG_DEFAULTS = {

  dialogSkipper_enabled                = false,
  dialogSkipper_skipAuction            = true,
  dialogSkipper_auctionBackButton      = true,
  dialogSkipper_auctionPriceLimit      = 10000000,
  dialogSkipper_skipPetCharm           = true,
  dialogSkipper_skipOrderResources     = true,
  dialogSkipper_skipEquipBind          = true,

  dismountToggle_enabled               = false,
  dismountToggle_travelFormEnabled     = false,
  dismountToggle_soarEnabled           = false,
  dismountToggle_changeActionBarTo     = "disabled",
  dismountToggle_ignoredMounts         = "",
  dismountToggle_ignoredMountAutoMount = false,

  raceOnLastMount_enabled              = false,

  persistentCompanion_enabled          = false,

  persistentUnsheath_autoSheath        = false,
  persistentUnsheath_autoUnsheath      = false,
  persistentUnsheath_muteToggleSounds  = true,

  muteSounds_enabled                   = false,
  muteSounds_soundIds                  = "598079, 598187",

  vendorItemOverlay_enabled            = false,
  vendorItemOverlay_toys_enabled       = false,
  vendorItemOverlay_mounts_enabled     = false,
  vendorItemOverlay_transmog_enabled   = false,
  vendorItemOverlay_transmog_non_appearance_known = true,
  vendorItemOverlay_pets_enabled       = false,
  vendorItemOverlay_recipes_enabled    = false,
  
  spellIconOverlay_showInSpellbook     = false,
  spellIconOverlay_showOnActionBars    = false,
  spellIconOverlay_onlyWhenAssistUsed  = false,

  flashlight_enabled                   = false,

}




local currentlyEditedCommand = nil

local keyPressFrame = CreateFrame("Frame")
local KeyPressedFunction = function(self, key)

  if key == "ESCAPE" then
    StaticPopup_Hide("LUDIUSPLUS_KEYBIND_PROMPT")
    return
  end

  if key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" or key == "LSHIFT" or key == "RSHIFT" then
    return
  end

  if IsShiftKeyDown() then
    key = "SHIFT-" .. key
  end
  if IsControlKeyDown() then
    key = "CTRL-" .. key
  end
  if IsAltKeyDown() then
    key = "ALT-" .. key
  end


  -- Check last key bind.
  local lastKey = GetBindingKey(currentlyEditedCommand)

  if lastKey and lastKey == key then
    StaticPopup_Hide("LUDIUSPLUS_KEYBIND_PROMPT")
    return
  end


  -- Check if key is already taken. GetBindingAction() returns "" if key has no action.
  local command = GetBindingAction(key)
  if command ~= "" and command ~= currentlyEditedCommand then
    local data = {
      ["lastKey"] = lastKey,
      ["key"] = key,
      ["command"] = currentlyEditedCommand
    }
    StaticPopup_Hide("LUDIUSPLUS_KEYBIND_PROMPT")
    StaticPopup_Show("LUDIUSPLUS_KEYBIND_CONFIRM", key .. " is already assigned to \"" .. GetBindingName(command) .. "\". Do you really want to assign it to \"" .. GetBindingName(data.command) .. "\" instead?", _, data)
    return
  end


  -- Assign new binding.
  if lastKey then
    SetBinding(lastKey)
  end
  SetBinding(key)
  SetBinding(key, currentlyEditedCommand)
  StaticPopup_Hide("LUDIUSPLUS_KEYBIND_PROMPT")
  LibStub("AceConfigRegistry-3.0"):NotifyChange(appName)

end


-- Cover the remaining options and make them unclickable while our keybind prompt is open.
local coverOptionsFrame = CreateFrame("Frame")
coverOptionsFrame:SetFrameStrata("HIGH")
coverOptionsFrame:SetFrameLevel(10000)
coverOptionsFrame.blackTexture = coverOptionsFrame:CreateTexture(nil, "ARTWORK")
coverOptionsFrame.blackTexture:SetAllPoints()
coverOptionsFrame.blackTexture:SetColorTexture(0, 0, 0, 0.75)
coverOptionsFrame:EnableMouse(true)

local function ShowCoverOptionsFrame()

  if SettingsPanel and SettingsPanel:IsShown() then
    coverOptionsFrame:ClearAllPoints()
    coverOptionsFrame:SetPoint("TOPLEFT", SettingsPanel, "TOPLEFT", 3, -1)
    coverOptionsFrame:SetPoint("BOTTOMRIGHT", SettingsPanel, "BOTTOMRIGHT", 0, 1)
    coverOptionsFrame:Show()
  end

end


StaticPopupDialogs["LUDIUSPLUS_KEYBIND_PROMPT"] = {

  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,  -- avoid some UI taint, see https://authors.curseforge.com/forums/world-of-warcraft/general-chat/lua-code-discussion/226040-how-to-reduce-chance-of-ui-taint-from
  text = "%s",

  OnShow = function (_, data)
    currentlyEditedCommand = data.command
    -- print(currentlyEditedCommand)
    ShowCoverOptionsFrame()
    keyPressFrame:SetScript("OnKeyDown", KeyPressedFunction)
  end,
  OnHide = function()
    currentlyEditedCommand = nil
    keyPressFrame:SetScript("OnKeyDown", nil)
    coverOptionsFrame:Hide()
  end,

  button1 = "Cancel",
  OnButton1 = function() end,
}


StaticPopupDialogs["LUDIUSPLUS_KEYBIND_CONFIRM"] = {

  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,  -- avoid some UI taint, see https://authors.curseforge.com/forums/world-of-warcraft/general-chat/lua-code-discussion/226040-how-to-reduce-chance-of-ui-taint-from
  text = "%s",

  OnShow = function ()
    ShowCoverOptionsFrame()
  end,
  OnHide = function()
    coverOptionsFrame:Hide()
  end,

  -- So that we can have different functions for each button.
  selectCallbackByIndex = true,

  button1 = "Yes",
  OnButton1 = function(_, data)
    if data.lastKey then
      SetBinding(data.lastKey)
    end
    SetBinding(data.key)
    SetBinding(data.key, data.command)
    LibStub("AceConfigRegistry-3.0"):NotifyChange(appName)
  end,

  button2 = "No",
  OnButton2 = function() end,
}



-- In order to make a keybinding run a macro, I have to call it this in bindings.xml:
local dismountToggleMacroName = "Dismount/Mount Toggle"
local dismountToggleBindingName = "MACRO " .. dismountToggleMacroName
-- If I ever do i18n for this, it would be here.
_G["BINDING_NAME_" .. dismountToggleBindingName] = L["Dismount/Mount Toggle"]

local flashlightBindingName = "MACRO Torch Toggle"
_G["BINDING_NAME_" .. flashlightBindingName] = L["Torch Toggle"]

-- Get the toy name from the API (Cave Spelunker's Torch)
local flashlightItemID = 224552
local _, flashlightToyName = C_ToyBox.GetToyInfo(flashlightItemID)
flashlightToyName = flashlightToyName or "Cave Spelunker's Torch"


-- Module descriptions
-- (Defining these here, as we use them as text and tooltip in the options.
local dialogSkipperDesc = L["Automatically skip confirmation dialogs."]
local vendorItemOverlayDesc = L["Display useful information as overlays for items at vendors."]
local spellIconOverlayDesc = L["Display an |A:UI-RefreshButton:16:16:0:0|a icon overlay on spells in the spellbook or action bars that are included in the single-button combat rotation. So you can identify them at a glance."]
local dismountToggleDesc = L["Assign dismounting and re-mounting to a single key, so you can comfortably switch between both."]
local raceOnLastMountDesc = L["When you start a Skyriding race while not mounted, you're automatically placed on the Renewed Proto-Drake with no way to choose your preferred mount. This addon automatically switches to your last active flying mount during the race countdown (after a 2-second delay required by the game).\n\nNote: Cannot automatically switch to Druid Flight Form due to API limitations."]
local persistentCompanionDesc = L["Automatically resummon your last active pet companion after it disappears. For example, after flying or stepping through portals."]
local persistentUnsheathDesc = L["Automatically maintain your desired weapon sheath state."]
local muteSoundsDesc = L["Mute specific sounds by their Sound File IDs.\n\nFind IDs on Wowhead (https://www.wowhead.com/sounds/) or learn about other methods at https://warcraft.wiki.gg/wiki/API_MuteSoundFile.\n\nExample: 598079, 598187 (Dutiful Squire summon sounds)."]
local flashlightDesc = L["Toggles the \"%s\" toy on and off with a hotkey."]:format(flashlightToyName)


-- Module order (from most to least demanded)
local dialogSkipperOrder = 1
local vendorItemOverlayOrder = 1.5
local spellIconOverlayOrder = 1.6
local dismountToggleOrder = 2
local raceOnLastMountOrder = 3
local persistentCompanionOrder = 4
local persistentUnsheathOrder = 5
local muteSoundsOrder = 6
local flashlightOrder = 7

-- Dynamic group name functions (return grey text if module disabled)
local function GetModuleGroupName(name, ...)
  local conditions = {...}
  local allTrue = true
  for _, condition in ipairs(conditions) do
    if not condition then
      allTrue = false
      break
    end
  end
  if not allTrue then
    return "|cff808080" .. name .. "|r"
  end
  return name
end

local optionsTable = {
  type = "group",
  args = {

    -- Blank space!
    optionsTableBlank00 = {order = 0.0, type = "description", name = " ",},

    dismountToggleGroup = {
      type = "group",
      name = function() return GetModuleGroupName(L["Dismount/Mount Toggle"], config.dismountToggle_enabled) end,
      desc = dismountToggleDesc,
      order = dismountToggleOrder,
      args = {

        dismountToggleDescription = {
          order = 0,
          type = "description",
          name = dismountToggleDesc,
          width = "full",
        },

        dismountToggleGroupBlank05 = {order = 0.5, type = "description", name = " ",},

        dismountToggleEnabled = {
          order = 1,
          type = "toggle",
          name = L["Enable"],
          width = "full",
          get = function() return config.dismountToggle_enabled end,
          set =
            function(_, newValue)
              config.dismountToggle_enabled = newValue
              addon.SetupOrTeardownDismountToggle()
            end,
        },

        dismountToggleGroupBlank15 = {order = 1.5, type = "description", name = " ",},

        dismountToggleKeybindGroup = {
          type = "group",
          name = "",
          order = 2,
          inline = true,
          width = "full",
          args = {

            dismountToggleKeybindGroupBlank00 = {order = 0.0, type = "description", name = " ", width = 0.04,},

            dismountToggleLabel = {
              order = 1,
              type = "description",
              name =
                function()
                  local key = GetBindingKey(dismountToggleBindingName)
                  if key then
                    return L["Assigned Hotkey:"] .. " |cffffd200" .. key .. "|r"
                  else
                    return L["Assigned Hotkey:"] .. " |cff808080" .. L["Not Bound"] .. "|r"
                  end
                end,
              width = 1,
            },

            dismountToggleAssignButton = {
              order = 2,
              type = "execute",
              name = L["New Key Bind"],
              desc = L["Assign a new hotkey binding."],
              width = 0.7,
              func =
                function()
                  local data = { ["command"] = dismountToggleBindingName }
                  StaticPopup_Show("LUDIUSPLUS_KEYBIND_PROMPT", SETTINGS_BIND_KEY_TO_COMMAND_OR_CANCEL:format(GetBindingName(dismountToggleBindingName), GetBindingText("ESCAPE")), _, data)
                end,
              disabled =
                function()
                  return not config.dismountToggle_enabled
                end,
            },

            dismountToggleKeybindGroupBlank25 = {order = 2.5, type = "description", name = " ", width = 0.05,},

            dismountToggleUnassignButton = {
              order = 3,
              type = "execute",
              name = L["Unbind"],
              desc = L["Unassign the current binding."],
              width = 0.7,
              func =
                function()
                  SetBinding(GetBindingKey(dismountToggleBindingName))
                end,
              disabled =
                function()
                  if GetBindingKey(dismountToggleBindingName) then return false else return true end
                end,
            },
          },
        },

        dismountToggleGroupBlank25 = {order = 2.5, type = "description", name = " ",},

        dismountToggleIgnoredMounts = {
          order = 3,
          type = "input",
          name = L["Mounts to ignore (comma-separated Mount IDs)"],
          desc = L["Enter Mount IDs to ignore when storing your last mount. Useful for utility mounts like Yak or Brutosaur that you use temporarily but don't want to summon with your hotkey.\n\nFind Mount IDs at: https://www.wowhead.com/spells/mounts"],
          width = "full",
          multiline = 3,
          get = function() return config.dismountToggle_ignoredMounts end,
          set =
            function(_, newValue)
              config.dismountToggle_ignoredMounts = newValue
              -- Update LibMountInfo's ignore list
              local LibMountInfo = LibStub("LibMountInfo-1.0")
              LibMountInfo:SetIgnoredMounts(newValue)
            end,
          disabled =
            function()
              return not config.dismountToggle_enabled
            end,
        },

        dismountToggleFillUtilityMounts = {
          order = 3.5,
          type = "execute",
          name = L["Fill in Utility Mounts"],
          desc = function()
            local utilityMounts = {
              {id = 280, name = nil},
              {id = 284, name = nil},
              {id = 460, name = nil},
              {id = 1039, name = nil},
              {id = 2237, name = nil},
              {id = 2265, name = nil},
            }

            -- Fetch mount names
            for _, mount in ipairs(utilityMounts) do
              local name = C_MountJournal.GetMountInfoByID(mount.id)
              mount.name = name or ("Mount ID " .. mount.id)
            end

            local desc = L["Adds commonly used utility mounts to the ignore list:"] .. "\n"
            for _, mount in ipairs(utilityMounts) do
              desc = desc .. "\n" .. mount.id .. ": " .. mount.name
            end

            return desc
          end,
          width = "full",
          func = function()
            local utilityMountIDs = {280, 284, 460, 1039, 2237, 2265}

            -- Parse existing IDs
            local existingIDs = {}
            for id in string.gmatch(config.dismountToggle_ignoredMounts, "%d+") do
              existingIDs[tonumber(id)] = true
            end

            -- Add utility mount IDs if not already present
            local idsToAdd = {}
            for _, id in ipairs(utilityMountIDs) do
              if not existingIDs[id] then
                table.insert(idsToAdd, id)
              end
            end

            -- Build new string
            if #idsToAdd > 0 then
              local newIDs = table.concat(idsToAdd, ", ")
              if config.dismountToggle_ignoredMounts == "" then
                config.dismountToggle_ignoredMounts = newIDs
              else
                config.dismountToggle_ignoredMounts = config.dismountToggle_ignoredMounts .. ", " .. newIDs
              end

              -- Update LibMountInfo
              local LibMountInfo = LibStub("LibMountInfo-1.0")
              LibMountInfo:SetIgnoredMounts(config.dismountToggle_ignoredMounts)

              -- Refresh options display
              LibStub("AceConfigRegistry-3.0"):NotifyChange(appName)
            end
          end,
          disabled = function()
            return not config.dismountToggle_enabled
          end,
        },

        dismountToggleIgnoredMountAutoMount = {
          order = 3.7,
          type = "toggle",
          name = L["Auto-mount last non-ignored mount when on ignored mounts"],
          desc = L["While on an ignored mount, the hotkey will dismount and immediately mount the last non-ignored mount. Disable to only dismount."],
          width = "full",
          get = function() return config.dismountToggle_ignoredMountAutoMount end,
          set =
            function(_, newValue)
              config.dismountToggle_ignoredMountAutoMount = newValue
              addon.SetupOrTeardownDismountToggle()
            end,
          disabled =
            function()
              return not config.dismountToggle_enabled
            end,
        },

        dismountToggleGroupBlank38 = {order = 3.8, type = "description", name = " ",},

        dismountToggleChangeActionBarTo = {
          order = 4,
          type = "select",
          name = L["When mounting, switch automatically to Action Bar:"],
          desc = L["Automatically switch to this action bar when you mount up, so you have your flying/mount abilities easily accessible. Set to \"disabled\" to keep your current action bar."],
          width = 2,
          disabled =
            function()
              return not config.dismountToggle_enabled
            end,
          get =
            function()
              return config.dismountToggle_changeActionBarTo
            end,
          set =
            function(_, newValue)
              config.dismountToggle_changeActionBarTo = newValue
              addon.SetupOrTeardownDismountToggle()
            end,
          values = {
            [1] = "1",
            [2] = "2",
            [3] = "3",
            [4] = "4",
            [5] = "5",
            [6] = "6",
            ["disabled"] = "disabled",
          },
        },

        dismountToggleGroupBlank45 = {order = 4.5, type = "description", name = " ",},

        dismountToggleTravelFormEnabled = {
          order = 5,
          type = "toggle",
          name = L["Druid Travel Form instead of mounting"],
          desc = L["Druids only: Use Travel Form or Flight Form as \"mounting\", and Humanoid form as \"dismounting\", instead of standard mounts."],
          width = "full",
          get = function() return config.dismountToggle_travelFormEnabled end,
          set =
            function(_, newValue)
              config.dismountToggle_travelFormEnabled = newValue
              addon.SetupOrTeardownDismountToggle()
            end,
          disabled =
            function()
              return not config.dismountToggle_enabled
            end,
        },

        dismountToggleSoarEnabled = {
          order = 6,
          type = "toggle",
          name = L["Dracthyr Soar instead of mounting"],
          desc = L["Dracthyr only: Use Soar as \"mounting\" and humanoid form as \"dismounting\", instead of standard mounts."],
          width = "full",
          get = function() return config.dismountToggle_soarEnabled end,
          set =
            function(_, newValue)
              config.dismountToggle_soarEnabled = newValue
              addon.SetupOrTeardownDismountToggle()
            end,
          disabled =
            function()
              return not config.dismountToggle_enabled
            end,
        },

      },
    },

    raceOnLastMountGroup = {
      type = "group",
      name = function() return GetModuleGroupName(L["Race on Last Mount"], config.raceOnLastMount_enabled) end,
      desc = raceOnLastMountDesc,
      order = raceOnLastMountOrder,
      args = {

        raceOnLastMountDescription = {
          order = 0,
          type = "description",
          name = raceOnLastMountDesc,
          width = "full",
        },

        raceOnLastMountGroupBlank05 = {order = 0.5, type = "description", name = " ",},

        raceOnLastMountEnabled = {
          order = 1,
          type = "toggle",
          name = L["Enable"],
          width = "full",
          get = function() return config.raceOnLastMount_enabled end,
          set =
            function(_, newValue)
              config.raceOnLastMount_enabled = newValue
              addon.SetupOrTeardownRaceOnLastMount()
            end,
        },

      },
    },

    flashlightGroup = {
      type = "group",
      name = function() return GetModuleGroupName(L["Flashlight (Torch)"], config.flashlight_enabled) end,
      desc = flashlightDesc,
      order = flashlightOrder,
      args = {

        flashlightDescription = {
          order = 0,
          type = "description",
          name = flashlightDesc,
          width = "full",
        },

        flashlightGroupBlank05 = {order = 0.5, type = "description", name = " ",},

        flashlightMissingToyWarning = {
          order = 0.7,
          type = "description",
          name = function()
            if not addon.HasFlashlightToy() then
              return "|cffff0000" .. L["Toy Missing:"] .. "|r " .. L["You don't have the %s!\nGet it from the Illuminated Footlocker:\nhttps://www.wowhead.com/object=437211/illuminated-footlocker"]:format(flashlightToyName)
            end
            return ""
          end,
          width = "full",
          hidden = function() return addon.HasFlashlightToy() end,
        },

        flashlightGroupBlank05b = {order = 0.75, type = "description", name = " ", hidden = function() return addon.HasFlashlightToy() end},

        flashlightEnabled = {
          order = 1,
          type = "toggle",
          name = L["Enable"],
          width = "full",
          get = function() return config.flashlight_enabled end,
          set =
            function(_, newValue)
              config.flashlight_enabled = newValue
              addon.SetupOrTeardownFlashlight()
            end,
          disabled = function() return not addon.HasFlashlightToy() end,
        },

        flashlightGroupBlank15 = {order = 1.5, type = "description", name = " ",},

        flashlightKeybindGroup = {
          type = "group",
          name = "",
          order = 2,
          inline = true,
          width = "full",
          args = {

            flashlightKeybindGroupBlank00 = {order = 0.0, type = "description", name = " ", width = 0.04,},

            flashlightLabel = {
              order = 1,
              type = "description",
              name =
                function()
                  local key = GetBindingKey(flashlightBindingName)
                  if key then
                    return L["Assigned Hotkey:"] .. " |cffffd200" .. key .. "|r"
                  else
                    return L["Assigned Hotkey:"] .. " |cff808080" .. L["Not Bound"] .. "|r"
                  end
                end,
              width = 1,
            },

            flashlightAssignButton = {
              order = 2,
              type = "execute",
              name = L["New Key Bind"],
              desc = L["Assign a new hotkey binding."],
              width = 0.7,
              func =
                function()
                  local data = { ["command"] = flashlightBindingName }
                  StaticPopup_Show("LUDIUSPLUS_KEYBIND_PROMPT", SETTINGS_BIND_KEY_TO_COMMAND_OR_CANCEL:format(GetBindingName(flashlightBindingName), GetBindingText("ESCAPE")), _, data)
                end,
              disabled =
                function()
                  return not config.flashlight_enabled
                end,
            },

            flashlightKeybindGroupBlank25 = {order = 2.5, type = "description", name = " ", width = 0.05,},

            flashlightUnassignButton = {
              order = 3,
              type = "execute",
              name = L["Unbind"],
              desc = L["Unassign the current binding."],
              width = 0.7,
              func =
                function()
                  SetBinding(GetBindingKey(flashlightBindingName))
                end,
              disabled =
                function()
                  if GetBindingKey(flashlightBindingName) then return false else return true end
                end,
            },
          },
        },
      },
    },

    muteSoundsGroup = {
      type = "group",
      name = function() return GetModuleGroupName(L["Mute Sounds"], config.muteSounds_enabled) end,
      desc = muteSoundsDesc,
      order = muteSoundsOrder,
      args = {

        muteSoundsDescription = {
          order = 0,
          type = "description",
          name = muteSoundsDesc,
          width = "full",
        },

        muteSoundsGroupBlank05 = {order = 0.5, type = "description", name = " ",},

        muteSoundsEnabled = {
          order = 1,
          type = "toggle",
          name = L["Enable"],
          width = "full",
          get = function() return config.muteSounds_enabled end,
          set =
            function(_, newValue)
              config.muteSounds_enabled = newValue
              addon.SetupOrTeardownMuteSounds()
            end,
        },

        muteSoundsSoundIds = {
          order = 2,
          type = "input",
          name = L["Sound IDs to mute (comma-separated)"],
          desc = L["Enter Sound File IDs separated by commas."],
          width = "full",
          multiline = 12,
          get = function() return config.muteSounds_soundIds end,
          set =
            function(_, newValue)
              config.muteSounds_soundIds = newValue
              addon.SetupOrTeardownMuteSounds()
            end,
          disabled =
            function()
              return not config.muteSounds_enabled
            end,
        },
      },
    },

    dialogSkipperGroup = {
      type = "group",
      name = function() return GetModuleGroupName(L["Dialog Skipper"], config.dialogSkipper_enabled) end,
      desc = dialogSkipperDesc,
      order = dialogSkipperOrder,
      args = {

        dialogSkipperDescription = {
          order = 0,
          type = "description",
          name = dialogSkipperDesc,
          width = "full",
        },

        dialogSkipperGroupBlank05 = {order = 0.5, type = "description", name = " ",},

        dialogSkipperEnabled = {
          order = 1,
          type = "toggle",
          name = L["Enable"],
          width = "full",
          get = function() return config.dialogSkipper_enabled end,
          set =
            function(_, newValue)
              config.dialogSkipper_enabled = newValue
              addon.SetupOrTeardownDialogSkipper()
            end,
        },

        dialogSkipperSkipAuction = {
          order = 2,
          type = "toggle",
          name = L["Skip auction house buyout confirmations"],
          width = "full",
          get = function() return config.dialogSkipper_skipAuction end,
          set =
            function(_, newValue)
              config.dialogSkipper_skipAuction = newValue
              addon.SetupOrTeardownDialogSkipper()
            end,
          disabled =
            function()
              return not config.dialogSkipper_enabled
            end,
        },

        dialogSkipperGroupBlank15 = {order = 1.5, type = "description", name = " ",},

        dialogSkipperAuctionBackButton = {
          order = 2.5,
          type = "toggle",
          name = L["Back to previous item list after buyout"],
          desc = L["After buying out an item, the addon automatically returns you to the previous item list overview. This is useful when you typically purchase one listing of an item and then want to go back to browse other items."],
          width = "full",
          get = function() return config.dialogSkipper_auctionBackButton end,
          set =
            function(_, newValue)
              config.dialogSkipper_auctionBackButton = newValue
              addon.SetupOrTeardownDialogSkipper()
            end,
          disabled =
            function()
              return not config.dialogSkipper_enabled or not config.dialogSkipper_skipAuction
            end,
        },

        dialogSkipperAuctionPriceLimit = {
          order = 3,
          type = "input",
          name = L["Only skip if price is below (gold)"],
          desc = L["Set the maximum price in gold for automatically confirming auctions."],
          width = "full",
          get = function() return tostring(config.dialogSkipper_auctionPriceLimit / 10000) end,
          set =
            function(_, newValue)
              local num = tonumber(newValue)
              if num then
                config.dialogSkipper_auctionPriceLimit = math.floor(num * 10000)
                addon.SetupOrTeardownDialogSkipper()
              end
            end,
          disabled =
            function()
              return not config.dialogSkipper_enabled or not config.dialogSkipper_skipAuction
            end,
        },

        dialogSkipperGroupBlank35 = {order = 3.5, type = "description", name = " ",},

        dialogSkipperSkipPetCharm = {
          order = 4,
          type = "toggle",
          name = L["Skip Polished Pet Charm purchases"],
          width = "full",
          get = function() return config.dialogSkipper_skipPetCharm end,
          set =
            function(_, newValue)
              config.dialogSkipper_skipPetCharm = newValue
              addon.SetupOrTeardownDialogSkipper()
            end,
          disabled =
            function()
              return not config.dialogSkipper_enabled
            end,
        },

        dialogSkipperSkipOrderResources = {
          order = 5,
          type = "toggle",
          name = L["Skip Order Resources purchases"],
          width = "full",
          get = function() return config.dialogSkipper_skipOrderResources end,
          set =
            function(_, newValue)
              config.dialogSkipper_skipOrderResources = newValue
              addon.SetupOrTeardownDialogSkipper()
            end,
          disabled =
            function()
              return not config.dialogSkipper_enabled
            end,
        },

        dialogSkipperGroupBlank55 = {order = 5.5, type = "description", name = " ",},

        dialogSkipperSkipEquipBind = {
          order = 6,
          type = "toggle",
          name = L["Skip equip bind confirmations"],
          desc = L["Automatically confirm \"Bind on Equip\" dialogs when equipping gear from quest rewards, vendors, or other sources."],
          width = "full",
          get = function() return config.dialogSkipper_skipEquipBind end,
          set =
            function(_, newValue)
              config.dialogSkipper_skipEquipBind = newValue
              addon.SetupOrTeardownDialogSkipper()
            end,
          disabled =
            function()
              return not config.dialogSkipper_enabled
            end,
        },
      },
    },

    vendorItemOverlayGroup = {
      type = "group",
      name = function() return GetModuleGroupName(L["Vendor Item Overlay"],
        config.vendorItemOverlay_enabled or
        config.vendorItemOverlay_toys_enabled or
        config.vendorItemOverlay_mounts_enabled or
        config.vendorItemOverlay_transmog_enabled or
        config.vendorItemOverlay_pets_enabled or
        config.vendorItemOverlay_recipes_enabled) end,
      desc = vendorItemOverlayDesc,
      order = vendorItemOverlayOrder,
      args = {

        vendorItemOverlayDescription = {
          order = 0,
          type = "description",
          name = vendorItemOverlayDesc,
          width = "full",
        },

        vendorItemOverlayGroupBlank05 = {order = 0.5, type = "description", name = " ",},

        vendorItemOverlayEnabled = {
          order = 1,
          type = "toggle",
          name = L["Ownership for decor items"],
          desc = L["Display ownership information for housing decor items when visiting vendors. Shows the count as [in storage]/[total owned] in the top-right corner of each item icon."],
          width = "full",
          get = function() return config.vendorItemOverlay_enabled end,
          set =
            function(_, newValue)
              config.vendorItemOverlay_enabled = newValue
              addon.SetupOrTeardownVendorItemOverlay()
            end,
        },

        vendorItemOverlayGroupBlank15 = {order = 1.5, type = "description", name = " ",},

        vendorItemOverlayToysEnabled = {
          order = 2,
          type = "toggle",
          name = L["Already known for toys"],
          desc = L["Grey out and mark toys that you already know."],
          width = "full",
          get = function() return config.vendorItemOverlay_toys_enabled end,
          set =
            function(_, newValue)
              config.vendorItemOverlay_toys_enabled = newValue
              addon.SetupOrTeardownVendorItemOverlay()
            end,
        },

        vendorItemOverlayMountsEnabled = {
          order = 3,
          type = "toggle",
          name = L["Already known for mounts"],
          desc = L["Grey out and mark mounts that you already know."],
          width = "full",
          get = function() return config.vendorItemOverlay_mounts_enabled end,
          set =
            function(_, newValue)
              config.vendorItemOverlay_mounts_enabled = newValue
              addon.SetupOrTeardownVendorItemOverlay()
            end,
        },

        vendorItemOverlayTransmogEnabled = {
          order = 4,
          type = "toggle",
          name = L["Already known for transmogs and heirlooms"],
          desc = L["Grey out and mark transmog items/ensembles and heirlooms that you already know."],
          width = "full",
          get = function() return config.vendorItemOverlay_transmog_enabled end,
          set =
            function(_, newValue)
              config.vendorItemOverlay_transmog_enabled = newValue
              addon.SetupOrTeardownVendorItemOverlay()
            end,
        },

        vendorItemOverlayGroupBlank45 = {order = 4.5, type = "description", name = " ", width = 0.1,},

        vendorItemOverlayTransmogNonAppearanceKnown = {
          order = 4.6,
          type = "toggle",
          name = L["Treat non-appearance items as known"],
          desc = L["Necklaces, rings and trinkets will be marked as already known even though they technically cannot be learned. This prevents them from looking like uncollected items in the vendor."],
          width = 1.5,
          get = function() return config.vendorItemOverlay_transmog_non_appearance_known end,
          set =
            function(_, newValue)
              config.vendorItemOverlay_transmog_non_appearance_known = newValue
              addon.SetupOrTeardownVendorItemOverlay()
            end,
          disabled =
            function()
              return not config.vendorItemOverlay_transmog_enabled
            end,
        },

        vendorItemOverlayPetsEnabled = {
          order = 5,
          type = "toggle",
          name = L["Already known for pets"],
          desc = L["Grey out and mark battle pets that you have already collected."],
          width = "full",
          get = function() return config.vendorItemOverlay_pets_enabled end,
          set =
            function(_, newValue)
              config.vendorItemOverlay_pets_enabled = newValue
              addon.SetupOrTeardownVendorItemOverlay()
            end,
        },

        vendorItemOverlayRecipesEnabled = {
          order = 6,
          type = "toggle",
          name = L["Already known for recipes"],
          desc = L["Grey out and mark recipes that you already know."],
          width = "full",
          get = function() return config.vendorItemOverlay_recipes_enabled end,
          set =
            function(_, newValue)
              config.vendorItemOverlay_recipes_enabled = newValue
              addon.SetupOrTeardownVendorItemOverlay()
            end,
        },

      },
    },

    spellIconOverlayGroup = {
      type = "group",
      name = function() return GetModuleGroupName(L["Spell Icon Overlay"], config.spellIconOverlay_showInSpellbook or config.spellIconOverlay_showOnActionBars) end,
      desc = spellIconOverlayDesc,
      order = spellIconOverlayOrder,
      args = {

        spellIconOverlayDescription = {
          order = 0,
          type = "description",
          name = spellIconOverlayDesc,
          width = "full",
        },

        spellIconOverlayGroupBlank05 = {order = 0.5, type = "description", name = " ",},

        spellIconOverlayShowInSpellbook = {
          order = 1,
          type = "toggle",
          name = L["Show in Spellbook"],
          desc = L["Display the |A:UI-RefreshButton:16:16:0:0|a icon overlay on spells in your spellbook that are included in the single-button combat rotation."],
          width = "full",
          get = function() return config.spellIconOverlay_showInSpellbook end,
          set =
            function(_, newValue)
              config.spellIconOverlay_showInSpellbook = newValue
              addon.SetupOrTeardownSpellIconOverlay()
            end,
        },

        spellIconOverlayShowOnActionBars = {
          order = 2,
          type = "toggle",
          name = L["Show on Action Bars"],
          desc = L["Display the |A:UI-RefreshButton:16:16:0:0|a icon overlay on action bar buttons for spells included in the rotation."],
          width = "full",
          get = function() return config.spellIconOverlay_showOnActionBars end,
          set =
            function(_, newValue)
              config.spellIconOverlay_showOnActionBars = newValue
              addon.SetupOrTeardownSpellIconOverlay()
            end,
        },

        spellIconOverlayGroupBlank25 = {order = 2.5, type = "description", name = " ", width = 0.1,},

        spellIconOverlayOnlyWhenAssistUsed = {
          order = 3,
          type = "toggle",
          name = L["Only when Single-Button is used"],
          desc = L["Only show the |A:UI-RefreshButton:16:16:0:0|a icon overlay on action bars if the Single-Button Assistant spell is currently placed on an action bar."],
          width = 1.5,
          get = function() return config.spellIconOverlay_onlyWhenAssistUsed end,
          set =
            function(_, newValue)
              config.spellIconOverlay_onlyWhenAssistUsed = newValue
              addon.SetupOrTeardownSpellIconOverlay()
            end,
          disabled =
            function()
              return not config.spellIconOverlay_showOnActionBars
            end,
        },

      },
    },

    persistentUnsheathGroup = {
      type = "group",
      name = function() return GetModuleGroupName(L["Persistent Unsheath"], config.persistentUnsheath_autoSheath or config.persistentUnsheath_autoUnsheath) end,
      desc = persistentUnsheathDesc,
      order = persistentUnsheathOrder,
      args = {

        persistentUnsheathDescription = {
          order = 0,
          type = "description",
          name = persistentUnsheathDesc,
          width = "full",
        },

        persistentUnsheathGroupBlank05 = {order = 0.5, type = "description", name = " ",},

        persistentUnsheathAutoSheath = {
          order = 1,
          type = "toggle",
          name = L["Restore sheathed"],
          desc = L["Remembers if your last sheath/unsheath toggle was into the sheathed state and automatically returns to sheathed whenever a game action changes the state to unsheathed (for example, after combat)."],
          width = "full",
          get = function() return config.persistentUnsheath_autoSheath end,
          set =
            function(_, newValue)
              config.persistentUnsheath_autoSheath = newValue
              addon.SetupOrTeardownPersistentUnsheath()
            end,
        },

        persistentUnsheathAutoUnsheath = {
          order = 2,
          type = "toggle",
          name = L["Restore unsheathed"],
          desc = L["Remembers if your last sheath/unsheath toggle was into the unsheathed state and automatically returns to unsheathed whenever a game action changes the state to sheathed (for example, after casting or interacting with NPCs)."],
          width = "full",
          get = function() return config.persistentUnsheath_autoUnsheath end,
          set =
            function(_, newValue)
              config.persistentUnsheath_autoUnsheath = newValue
              addon.SetupOrTeardownPersistentUnsheath()
            end,
        },

        persistentUnsheathGroupBlank25 = {order = 2.5, type = "description", name = " ",},

        persistentUnsheathMuteToggleSounds = {
          order = 3,
          type = "toggle",
          name = L["Silent restoration"],
          desc = L["Mutes the sheath and unsheath sound effects when the addon automatically restores your weapon state. The sounds from manual toggling are not affected."],
          width = "full",
          get = function() return config.persistentUnsheath_muteToggleSounds end,
          set =
            function(_, newValue)
              config.persistentUnsheath_muteToggleSounds = newValue
              addon.SetupOrTeardownPersistentUnsheath()
            end,
        },
      },
    },

    persistentCompanionGroup = {
      type = "group",
      name = function() return GetModuleGroupName(L["Persistent Companion"], config.persistentCompanion_enabled) end,
      desc = persistentCompanionDesc,
      order = persistentCompanionOrder,
      args = {

        persistentCompanionDescription = {
          order = 0,
          type = "description",
          name = persistentCompanionDesc,
          width = "full",
        },

        persistentCompanionGroupBlank05 = {order = 0.5, type = "description", name = " ",},

        persistentCompanionEnabled = {
          order = 1,
          type = "toggle",
          name = L["Enable"],
          width = "full",
          get = function() return config.persistentCompanion_enabled end,
          set =
            function(_, newValue)
              config.persistentCompanion_enabled = newValue
              addon.SetupOrTeardownPersistentCompanion()
            end,
        },
      },
    },

  },
}



local function AreAllModulesDisabled()
  return not (
    config.dialogSkipper_enabled or
    config.dismountToggle_enabled or
    config.raceOnLastMount_enabled or
    config.persistentCompanion_enabled or
    config.persistentUnsheath_autoSheath or
    config.persistentUnsheath_autoUnsheath or
    config.muteSounds_enabled or
    config.vendorItemOverlay_enabled or
    config.flashlight_enabled
  )
end

function addon:OnInitialize()

  LP_config = LP_config or {}
  -- For easier access.
  config = LP_config

  -- Remove keys from previous versions.
  for k, v in pairs(config) do
    -- print (k, v)
    if CONFIG_DEFAULTS[k] == nil then
      -- print(k, "not in CONFIG_DEFAULTS")
      config[k] = nil
    end
  end

  -- Set CONFIG_DEFAULTS for new key.
  for k, v in pairs(CONFIG_DEFAULTS) do
    -- print (k, v)
    if config[k] == nil then
      -- print(k, "not there")
      config[k] = v
    end
  end

  -- Print welcome message if all modules are disabled
  if AreAllModulesDisabled() then
    print("|cFFFF8800" .. L["Welcome to LudiusPlus! Type /ldp to pick modules to enable."] .. "|r")
  end

  LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(appName, optionsTable)
  self.optionsMenu = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(appName)

  -- Register chat command to open settings
  SLASH_LUDIUSPLUS1 = "/ldp"
  SlashCmdList["LUDIUSPLUS"] = function()
    Settings.OpenToCategory(self.optionsMenu.name)
  end

end
