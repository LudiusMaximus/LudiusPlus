local L = LibStub("AceLocale-3.0"):NewLocale("LudiusPlus", "zhCN")
if not L then return end

-- Module Descriptions
L["Assign dismounting and re-mounting to a single key, so you can comfortably switch between both."] = "将下马和重新上马分配给同一个按键，方便您在两者之间切换。"
L["Toggles the \"%s\" toy on and off with a hotkey."] = "使用热键开启或关闭“%s”玩具。"
L["Mute specific sounds by their Sound File IDs.\n\nFind IDs on Wowhead (https://www.wowhead.com/sounds/) or learn about other methods at https://warcraft.wiki.gg/wiki/API_MuteSoundFile.\n\nExample: 598079, 598187 (Dutiful Squire summon sounds)."] = "根据声音文件 ID 静音特定声音。\n\n在 Wowhead (https://www.wowhead.com/sounds/) 上查找 ID，或在 https://warcraft.wiki.gg/wiki/API_MuteSoundFile 上了解其他方法。\n\n示例：598079, 598187（负责任的侍从召唤声音）。"
L["Automatically skip confirmation dialogs"] = "自动跳过确认对话框。"
L["Automatically maintain your desired weapon sheath state."] = "自动保持您期望的武器收拔状态。"
L["Automatically resummon your last active pet companion after it disappears. For example, after flying or stepping through portals"] = "在最后激活的宠物伙伴消失后自动重新召唤。例如，在飞行或穿过传送门之后。"

-- DismountToggle Options
L["Dismount/Mount Toggle"] = "上下马切换"
L["Enable"] = "启用"
L["Assigned Hotkey:"] = "已分配热键："
L["Not Bound"] = "未绑定"
L["New Key Bind"] = "新按键绑定"
L["Assign a new hotkey binding."] = "分配一个新的热键绑定。"
L["Unbind"] = "清除"
L["Unassign the current binding."] = "清除当前绑定。"
L["When mounting, switch automatically to Action Bar:"] = "上马时自动切换动作条："
L["Automatically switch to this action bar when you mount up, so you have your flying/mount abilities easily accessible. Set to \"disabled\" to keep your current action bar."] = "上马时自动切换到此动作条，以便您轻松使用飞行/坐骑技能。设置为“已禁用”以保持当前动作条。"
L["Druid Travel Form instead of mounting"] = "使用德鲁伊旅行形态代替上马"
L["Druids only: Use Travel Form or Flight Form as \"mounting\", and Humanoid form as \"dismounting\", instead of standard mounts."] = "仅限德鲁伊：使用旅行形态或飞行形态作为“上马”，人形作为“下马”，代替标准坐骑。"
L["Dracthyr Soar instead of mounting"] = "使用龙希尔翱翔代替上马"
L["Dracthyr only: Use Soar as \"mounting\" and humanoid form as \"dismounting\", instead of standard mounts."] = "仅限龙希尔：使用翱翔作为“上马”，人形作为“下马”，代替标准坐骑。"
L["Mounts to ignore (comma-separated Mount IDs)"] = "忽略的坐骑（逗号分隔的坐骑 ID）"
L["Enter Mount IDs to ignore when storing your last mount. Useful for utility mounts like Yak or Brutosaur that you use temporarily but don't want to summon with your hotkey.\n\nFind Mount IDs at: https://www.wowhead.com/spells/mounts"] = "输入在存储最后坐骑时要忽略的坐骑 ID。对于您临时使用但不希望用热键召唤的功能性坐骑（如牦牛或雷龙）非常有用。\n\n在此查找坐骑 ID：https://www.wowhead.com/spells/mounts"
L["Fill in Utility Mounts"] = "填入功能性坐骑"
L["Adds commonly used utility mounts to the ignore list:"] = "将常用的功能性坐骑添加到忽略列表："
L["Auto-mount last non-ignored mount when on ignored mounts"] = "在忽略坐骑上时自动召唤最后非忽略坐骑"
L["While on an ignored mount, the hotkey will dismount and immediately mount the last non-ignored mount. Disable to only dismount."] = "当在忽略坐骑上时，热键将下马并立即召唤最后一个非忽略坐骑。禁用此项则仅执行下马。"

-- RaceOnLastMount Options
L["Race on Last Mount"] = "使用最后坐骑竞速"
L["When you start a Skyriding race while not mounted, you're automatically placed on the Renewed Proto-Drake with no way to choose your preferred mount. This addon automatically switches to your last active flying mount during the race countdown (after a 2-second delay required by the game).\n\nNote: Cannot automatically switch to Druid Flight Form due to API limitations."] = "如果您在未骑乘状态下开始驭空术竞速，通常会自动骑乘复苏始祖幼龙。此插件会在竞速倒计时期间（2 秒延迟后）自动切换到您最后使用的飞行坐骑。\n\n注意：由于 API 限制，无法自动切换到德鲁伊飞行形态。"

-- Flashlight Options
L["Flashlight (Torch)"] = "手电筒（火把）"
L["Torch Toggle"] = "切换火把"
L["Toy Missing:"] = "缺少玩具："
L["You don't have the %s!\nGet it from the Illuminated Footlocker:\nhttps://www.wowhead.com/object=437211/illuminated-footlocker"] = "您没有玩具“%s”！\n请从光耀提箱中获取：\nhttps://www.wowhead.com/cn/object=437211/光耀提箱"

-- MuteSounds Options
L["Mute Sounds"] = "静音声音"
L["Sound IDs to mute (comma-separated)"] = "要静音的声音 ID（逗号分隔）"
L["Enter Sound File IDs separated by commas."] = "输入用逗号分隔的声音文件 ID。"

-- DialogSkipper Options
L["Dialog Skipper"] = "对话跳过器"
L["Skip auction house buyout confirmations"] = "跳过拍卖行一口价确认"
L["Only skip if price is below (gold)"] = "仅在价格低于（金币）时跳过"
L["Set the maximum price in gold for automatically confirming auctions."] = "设置自动确认拍卖的最高金币价格。"
L["Skip Polished Pet Charm purchases"] = "跳过使用抛光的宠物符购买确认"
L["Skip Order Resources purchases"] = "跳过使用职业大厅资源购买确认"
L["Skip equip bind confirmations"] = "跳过装备绑定确认"
L["Automatically confirm \"Bind on Equip\" dialogs when equipping gear from quest rewards, vendors, or other sources."] = "在装备来自任务奖励、商人或其他来源的装备时，自动确认“装备后绑定”对话框。"

-- PersistentUnsheath Options
L["Persistent Unsheath"] = "持久武器状态"
L["Restore sheathed"] = "恢复收起武器"
L["Remembers if your last sheath/unsheath toggle was into the sheathed state and automatically returns to sheathed whenever a game action changes the state to unsheathed (for example, after combat)."] = "记住您最后是将武器收起，并在游戏动作改变状态为拔出（例如战斗后）时自动恢复为收起状态。"
L["Restore unsheathed"] = "恢复拔出武器"
L["Remembers if your last sheath/unsheath toggle was into the unsheathed state and automatically returns to unsheathed whenever a game action changes the state to sheathed (for example, after casting or interacting with NPCs)."] = "记住您最后是将武器拔出，并在游戏动作改变状态为收起（例如施法或与 NPC 互动后）时自动恢复为拔出状态。"
L["Silent restoration"] = "静音恢复"
L["Mutes the sheath and unsheath sound effects when the addon automatically restores your weapon state. The sounds from manual toggling are not affected."] = "当插件自动恢复您的武器状态时，静音收拔武器的音效。手动切换的声音不受影响。"

-- PersistentCompanion Options
L["Persistent Companion"] = "持久伙伴"
