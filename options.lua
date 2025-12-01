local folderName, addon = ...
local L = LibStub("AceAddon-3.0"):NewAddon(folderName)


-- For the options menu.
local appName = "Ludius Plus"




-- A local variable for saved variable LP_config for easier access.
local config

local CONFIG_DEFAULTS = {
  dismountToggle_enabled           = true,
  dismountToggle_travelFormEnabled = true,
  dismountToggle_soarEnabled       = true,
  dismountToggle_changeActionBarTo = "disabled",
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
_G["BINDING_NAME_" .. dismountToggleBindingName] = "Dismount/Mount Toggle"


local optionsTable = {
  type = "group",
  args = {

    n01 = {order = 0.1, type = "description", name = " ",},

    dismountToggleGroup = {
      type = "group",
      name = _G["BINDING_NAME_" .. dismountToggleBindingName],
      order = 1,
      inline = true,
      args = {

        dismountToggleDescription = {
          order = 0,
          type = "description",
          name = "Assign dismounting and re-mounting to a single key, so you can comfortably switch between both.",
          width = "full",
        },

        dismountToggleEnabled = {
          order = 1,
          type = "toggle",
          name = "Enable",
          width = "full",
          get = function() return config.dismountToggle_enabled end,
          set = 
            function(_, newValue)
              config.dismountToggle_enabled = newValue
              addon.SetupDismountToggleMacro()
            end,
        },
        
        dismountToggleKeybindGroup = {
          type = "group",
          name = "",
          order = 2,
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
                    return "Assigned Hotkey: |cffffd200" .. key .. "|r"
                  else
                    return "Assigned Hotkey: |cff808080Not Bound|r"
                  end
                end,
              width = 1.5,
            },

            dismountToggleAssignButton = {
              order = 2,
              type = "execute",
              name = "New Key Bind",
              desc = "Assign a new hotkey binding.",
              width = 0.9,
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

            blank21 = {order = 2.1, type = "description", name = " ", width = 0.1,},

            dismountToggleUnassignButton = {
              order = 3,
              type = "execute",
              name = "Unbind",
              desc = "Unassign the current binding.",
              width = 0.9,
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
        
        dismountToggleChangeActionBarTo = {
          order = 3,
          type = "select",
          name = "When mounting, switch automatically to Action Bar:",
          desc = "Lets you automatically switch to your action bar holding the dynamic flight abilities when mounting up.",
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
          name = "Druid Travel Form instead of mounting",
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
          name = "Dracthyr Soar instead of mounting",
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
    

  },
}



function L:OnInitialize()

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
