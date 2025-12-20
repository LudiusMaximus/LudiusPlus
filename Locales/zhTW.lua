local L = LibStub("AceLocale-3.0"):NewLocale("LudiusPlus", "zhTW")
if not L then return end

-- DismountToggle Options
L["Dismount/Mount Toggle"] = "上下馬切換"
L["Assign dismounting and re-mounting to a single key, so you can comfortably switch between both."] = "將下馬和重新上馬分配給同一個按鍵，方便您在兩者之間切換。"
L["Enable"] = "啟用"
L["Assigned Hotkey:"] = "已分配熱鍵："
L["Not Bound"] = "未綁定"
L["New Key Bind"] = "新按鍵綁定"
L["Assign a new hotkey binding."] = "分配一個新的熱鍵綁定。"
L["Unbind"] = "清除"
L["Unassign the current binding."] = "清除當前綁定。"
L["When mounting, switch automatically to Action Bar:"] = "上馬時自動切換快捷列："
L["Automatically switch to this action bar when you mount up, so you have your flying/mount abilities easily accessible. Set to \"disabled\" to keep your current action bar."] = "上馬時自動切換到此快捷列，以便您輕鬆使用飛行/坐騎技能。設置為「已禁用」以保持當前快捷列。"
L["Druid Travel Form instead of mounting"] = "使用德魯伊旅行形態代替上馬"
L["Druids only: Use Travel Form or Flight Form as \"mounting\", and Humanoid form as \"dismounting\", instead of standard mounts."] = "僅限德魯伊：使用旅行形態或飛行形態作為「上馬」，人形作為「下馬」，代替標準坐騎。"
L["Dracthyr Soar instead of mounting"] = "使用半龍人飛騰代替上馬"
L["Dracthyr only: Use Soar as \"mounting\" and humanoid form as \"dismounting\", instead of standard mounts."] = "僅限半龍人：使用飛騰作為「上馬」，人形作為「下馬」，代替標準坐騎。"
L["Mounts to ignore (comma-separated Mount IDs)"] = "忽略的坐騎（逗號分隔的坐騎 ID）"
L["Enter Mount IDs to ignore when storing your last mount. Useful for utility mounts like Yak or Brutosaur that you use temporarily but don't want to summon with your hotkey.\n\nFind Mount IDs at: https://www.wowhead.com/spells/mounts"] = "輸入在存儲最後坐騎時要忽略的坐騎 ID。對於您臨時使用但不希望用熱鍵召喚的功能性坐騎（如犛牛或雷龍）非常有用。\n\n在此查找坐騎 ID：https://www.wowhead.com/spells/mounts"
L["Fill in Utility Mounts"] = "填入功能性坐騎"
L["Adds commonly used utility mounts to the ignore list:"] = "將常用的功能性坐騎添加到忽略列表："
L["Auto-mount last non-ignored mount when on ignored mounts"] = "在忽略坐騎上時自動召喚最後非忽略坐騎"
L["While on an ignored mount, the hotkey will dismount and immediately mount the last non-ignored mount. Disable to only dismount."] = "當在忽略坐騎上時，熱鍵將下馬並立即召喚最後一個非忽略坐騎。禁用此項則僅執行下馬。"

-- RaceOnLastMount Options
L["Race on Last Mount"] = "使用最後坐騎競速"
L["When you start a Skyriding race while not mounted, you're automatically placed on the Renewed Proto-Drake with no way to choose your preferred mount. This addon automatically switches to your last active flying mount during the race countdown (after a 2-second delay required by the game).\n\nNote: Cannot automatically switch to Druid Flight Form due to API limitations."] = "如果您在未騎乘狀態下開始飛龍騎術競速，通常會自動騎乘復甦元龍。此插件會於競速倒數計時期間（2 秒延遲後）自動切換到您最後使用的飛行坐騎。\n\n注意：由於 API 限制，無法自動切換到德魯伊飛行形態。"

-- Flashlight Options
L["Flashlight (Torch)"] = "手電筒（火把）"
L["Toggles the \"%s\" toy on and off with a hotkey."] = "使用熱鍵開啟或關閉「%s」玩具。"
L["Torch Toggle"] = "切換火把"
L["Toy Missing:"] = "缺少玩具："
L["You don't have the %s!\nGet it from the Illuminated Footlocker:\nhttps://www.wowhead.com/object=437211/illuminated-footlocker"] = "您沒有玩具「%s」！\n請從發光的置物箱中獲取：\nhttps://www.wowhead.com/tw/object=437211/發光的置物箱"

-- MuteSounds Options
L["Mute Sounds"] = "靜音聲音"
L["Mute specific sounds by their Sound File IDs.\n\nFind IDs on Wowhead (https://www.wowhead.com/sounds/) or learn about other methods at https://warcraft.wiki.gg/wiki/API_MuteSoundFile.\n\nExample: 598079, 598187 (Dutiful Squire summon sounds)."] = "根據聲音檔案 ID 靜音特定聲音。\n\n在 Wowhead (https://www.wowhead.com/sounds/) 上尋找 ID，或在 https://warcraft.wiki.gg/wiki/API_MuteSoundFile 上了解其他方法。\n\n範例：598079, 598187（盡責的侍從召喚聲音）。"
L["Sound IDs to mute (comma-separated)"] = "要靜音的聲音 ID（逗號分隔）"
L["Enter Sound File IDs separated by commas."] = "輸入用逗號分隔的聲音檔案 ID。"

-- DialogSkipper Options
L["Dialog Skipper"] = "對話跳過器"
L["Automatically skip confirmation dialogs"] = "自動跳過確認對話框。"
L["Skip auction house buyout confirmations"] = "跳過拍賣場直購確認"
L["Only skip if price is below (gold)"] = "僅在價格低於（金幣）時跳過"
L["Set the maximum price in gold for automatically confirming auctions."] = "設置自動確認拍賣的最高金幣價格。"
L["Skip Polished Pet Charm purchases"] = "跳過使用亮光寵物吊飾購買確認"
L["Skip Order Resources purchases"] = "跳過使用職業大廳資源購買確認"
L["Skip equip bind confirmations"] = "跳過裝備綁定確認"
L["Automatically confirm \"Bind on Equip\" dialogs when equipping gear from quest rewards, vendors, or other sources."] = "在裝備來自任務獎勵、商人或其他來源的裝備時，自動確認「裝備綁定」對話框。"

-- VendorItemOverlay Options
L["Vendor Item Overlay"] = "商人物品覆蓋"
L["Display useful information as overlays for items at vendors."] = "為商人處的物品顯示有用的覆蓋資訊。"
L["Ownership for decor items"] = "裝飾物品所有權"
L["Display ownership information for housing decor items when visiting vendors. Shows the count as [in storage]/[total owned] in the top-right corner of each item icon."] = "訪問商人時顯示住房裝飾物品的所有權資訊。在每個物品圖示的右上角顯示數量，格式為[存儲中]/[總擁有]。"

-- PersistentUnsheath Options
L["Persistent Unsheath"] = "持久武器狀態"
L["Automatically maintain your desired weapon sheath state."] = "自動保持您期望的武器收拔狀態。"
L["Restore sheathed"] = "恢復收起武器"
L["Remembers if your last sheath/unsheath toggle was into the sheathed state and automatically returns to sheathed whenever a game action changes the state to unsheathed (for example, after combat)."] = "記住您最後是將武器收起，並在遊戲動作改變狀態為拔出（例如戰鬥後）時自動恢復為收起狀態。"
L["Restore unsheathed"] = "恢復拔出武器"
L["Remembers if your last sheath/unsheath toggle was into the unsheathed state and automatically returns to unsheathed whenever a game action changes the state to sheathed (for example, after casting or interacting with NPCs)."] = "記住您最後是將武器拔出，並在遊戲動作改變狀態為收起（例如施法或與 NPC 互動後）時自動恢復為拔出狀態。"
L["Silent restoration"] = "靜音恢復"
L["Mutes the sheath and unsheath sound effects when the addon automatically restores your weapon state. The sounds from manual toggling are not affected."] = "當插件自動恢復您的武器狀態時，靜音收拔武器的音效。手動切換的聲音不受影響。"

-- PersistentCompanion Options
L["Persistent Companion"] = "持久夥伴"
L["Automatically resummon your last active pet companion after it disappears. For example, after flying or stepping through portals"] = "在最後激活的寵物夥伴消失後自動重新召喚。例如，在飛行或穿過傳送門之後。"

-- Welcome Message
L["Welcome to LudiusPlus! Type /ldp to pick modules to enable."] = "歡迎使用 LudiusPlus！輸入 /ldp 選擇要啟用的模組。"
