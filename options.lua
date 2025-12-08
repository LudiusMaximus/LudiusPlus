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
  dismountToggle_enabled              = true,
  dismountToggle_travelFormEnabled    = true,
  dismountToggle_soarEnabled          = true,
  dismountToggle_changeActionBarTo    = "disabled",
  flashlight_enabled                  = true,
  muteSounds_enabled                  = true,
  muteSounds_soundIds                 = "598079, 598187",
  dialogSkipper_enabled               = true,
  dialogSkipper_skipAuction           = true,
  dialogSkipper_auctionPriceLimit     = 10000000,
  dialogSkipper_skipPetCharm          = true,
  dialogSkipper_skipOrderResources    = true,
  dialogSkipper_skipEquipBind         = true,
  persistentUnsheath_autoSheath       = false,
  persistentUnsheath_autoUnsheath     = true,
  persistentUnsheath_muteToggleSounds = true,
  persistentCompanion_enabled         = true,
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

-- Module descriptions
local dismountToggleDesc = L["Assign dismounting and re-mounting to a single key, so you can comfortably switch between both."]
local flashlightDesc = L["Switch between Cave Spelunker's Torch on and off with a hotkey."]
local muteSoundsDesc = L["Mute specific sounds by their Sound File IDs. E.g. annoying summon sounds."]
local dialogSkipperDesc = L["Automatically skip confirmation dialogs"]
local persistentUnsheathDesc = L["Automatically maintain your desired weapon sheath state."]
local persistentCompanionDesc = L["Automatically resummon your last active pet companion after it disappears. For example, after flying or stepping through portals"]

-- Module order (from most to least demanded)
local dialogSkipperOrder = 1
local dismountToggleOrder = 2
local persistentCompanionOrder = 3
local persistentUnsheathOrder = 4
local muteSoundsOrder = 5
local flashlightOrder = 6

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
    n01 = {order = 0.1, type = "description", name = " ",},

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

        n02 = {order = 0.5, type = "description", name = " ",},

        dismountToggleEnabled = {
          order = 1,
          type = "toggle",
          name = L["Enable"],
          width = "full",
          get = function() return config.dismountToggle_enabled end,
          set = 
            function(_, newValue)
              config.dismountToggle_enabled = newValue
              addon.SetupDismountToggleMacro()
            end,
        },
        
        n03 = {order = 1.5, type = "description", name = " ",},
        
        dismountToggleKeybindGroup = {
          type = "group",
          name = "",
          order = 2,
          inline = true,
          width = "full",
          args = {
          
            dismountToggleSpace = {order = 0, type = "description", name = " ", width = 0.04,},

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

            blank21 = {order = 2.1, type = "description", name = " ", width = 0.05,},

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
        
        n04 = {order = 2.5, type = "description", name = " ",},
        
        dismountToggleChangeActionBarTo = {
          order = 3,
          type = "select",
          name = L["When mounting, switch automatically to Action Bar:"],
          desc = L["Automatically switch to this action bar when you mount up, so you have your flying/mount abilities easily accessible. Set to 'disabled' to keep your current action bar."],
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
              addon.SetupDismountToggleMacro()
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
        
        dismountToggleTravelFormEnabled = {
          order = 4,
          type = "toggle",
          name = L["Druid Travel Form instead of mounting"],
          desc = L["Druids only: Use Travel Form or Flight Form as \"mounting\", and Humanoid form as \"dismounting\", instead of standard mounts."],
          width = "full",
          get = function() return config.dismountToggle_travelFormEnabled end,
          set = 
            function(_, newValue)
              config.dismountToggle_travelFormEnabled = newValue
              addon.SetupDismountToggleMacro()
            end,
          disabled = 
            function()
              return not config.dismountToggle_enabled
            end,          
        },
        
        dismountToggleSoarEnabled = {
          order = 5,
          type = "toggle",
          name = L["Dracthyr Soar instead of mounting"],
          desc = L["Dracthyr only: Use Soar as \"mounting\" and humanoid form as \"dismounting\", instead of standard mounts."],
          width = "full",
          get = function() return config.dismountToggle_soarEnabled end,
          set = 
            function(_, newValue)
              config.dismountToggle_soarEnabled = newValue
              addon.SetupDismountToggleMacro()
            end,
          disabled = 
            function()
              return not config.dismountToggle_enabled
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

        n05 = {order = 0.5, type = "description", name = " ",},

        flashlightEnabled = {
          order = 1,
          type = "toggle",
          name = L["Enable"],
          width = "full",
          get = function() return config.flashlight_enabled end,
          set = 
            function(_, newValue)
              config.flashlight_enabled = newValue
              addon.SetupFlashlightMacros()
            end,
        },
        
        n06 = {order = 1.5, type = "description", name = " ",},
        
        flashlightKeybindGroup = {
          type = "group",
          name = "",
          order = 2,
          inline = true,
          width = "full",
          args = {
          
            flashlightSpace = {order = 0, type = "description", name = " ", width = 0.04,},

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

            blank22 = {order = 2.1, type = "description", name = " ", width = 0.05,},

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

        n07 = {order = 0.5, type = "description", name = " ",},

        muteSoundsEnabled = {
          order = 1,
          type = "toggle",
          name = L["Enable"],
          width = "full",
          get = function() return config.muteSounds_enabled end,
          set = 
            function(_, newValue)
              config.muteSounds_enabled = newValue
              addon.SetupMuteSounds()
            end,
        },

        muteSoundsSoundIds = {
          order = 2,
          type = "input",
          name = L["Sound IDs to mute (comma-separated)"],
          desc = L["Enter Sound File IDs separated by commas. Find IDs on WoW databases like Wowhead or using UI addons. Example: 598079, 598187"],
          width = "full",
          multiline = 12,
          get = function() return config.muteSounds_soundIds end,
          set = 
            function(_, newValue)
              config.muteSounds_soundIds = newValue
              addon.SetupMuteSounds()
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

        n08 = {order = 0.5, type = "description", name = " ",},

        dialogSkipperEnabled = {
          order = 1,
          type = "toggle",
          name = L["Enable"],
          width = "full",
          get = function() return config.dialogSkipper_enabled end,
          set = 
            function(_, newValue)
              config.dialogSkipper_enabled = newValue
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
            end,
          disabled = 
            function()
              return not config.dialogSkipper_enabled
            end,
        },

        n09 = {order = 1.5, type = "description", name = " ",},

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
              end
            end,
          disabled = 
            function()
              return not config.dialogSkipper_enabled or not config.dialogSkipper_skipAuction
            end,
        },

        n10 = {order = 3.5, type = "description", name = " ",},

        dialogSkipperSkipPetCharm = {
          order = 4,
          type = "toggle",
          name = L["Skip Polished Pet Charm purchases"],
          width = "full",
          get = function() return config.dialogSkipper_skipPetCharm end,
          set = 
            function(_, newValue)
              config.dialogSkipper_skipPetCharm = newValue
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
            end,
          disabled = 
            function()
              return not config.dialogSkipper_enabled
            end,
        },

        n14 = {order = 5.5, type = "description", name = " ",},

        dialogSkipperSkipEquipBind = {
          order = 6,
          type = "toggle",
          name = L["Skip equip bind confirmations"],
          desc = L["Automatically confirm 'Bind on Equip' dialogs when equipping gear from quest rewards, vendors, or other sources."],
          width = "full",
          get = function() return config.dialogSkipper_skipEquipBind end,
          set = 
            function(_, newValue)
              config.dialogSkipper_skipEquipBind = newValue
            end,
          disabled = 
            function()
              return not config.dialogSkipper_enabled
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

        n11 = {order = 0.5, type = "description", name = " ",},

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
            end,
        },

        n12 = {order = 2.5, type = "description", name = " ",},

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

        n13 = {order = 0.5, type = "description", name = " ",},

        persistentCompanionEnabled = {
          order = 1,
          type = "toggle",
          name = L["Enable"],
          width = "full",
          get = function() return config.persistentCompanion_enabled end,
          set = 
            function(_, newValue)
              config.persistentCompanion_enabled = newValue
              addon.SetupPersistentCompanion()
            end,
        },
      },
    },

  },
}



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

  LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(appName, optionsTable)
  self.optionsMenu = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(appName)

end
