local L = LibStub("AceLocale-3.0"):NewLocale("LudiusPlus", "zhCN")
if not L then return end

-- DismountToggle Options
L["Dismount/Mount Toggle"] = "上下马切换"
L["Assign dismounting and re-mounting to a single key, so you can comfortably switch between both. The addon will remember your last mount and re-mount it when you press the hotkey again."] = "将下马和重新上马分配给同一个按键，方便您在两者之间切换。插件会记住你最后使用的坐骑，并在你再次按下热键时重新召唤它。"
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
L["Dismount/Mount Toggle module is disabled. Enable it in the addon options."] = "上下马切换模块已禁用。请在插件设置中启用。"

-- RaceOnLastMount Options
L["Race on Last Mount"] = "使用最后坐骑竞速"
L["When you start a Skyriding race while not mounted, you're automatically placed on the Renewed Proto-Drake with no way to choose your preferred mount. This addon automatically switches to your last active flying mount during the race countdown (after a 2-second delay required by the game).\n\nNote: Cannot automatically switch to Druid Flight Form due to API limitations."] = "如果您在未骑乘状态下开始驭空术竞速，通常会自动骑乘复苏始祖幼龙。此插件会在竞速倒计时期间（2 秒延迟后）自动切换到您最后使用的飞行坐骑。\n\n注意：由于 API 限制，无法自动切换到德鲁伊飞行形态。"

-- Flashlight Options
L["Flashlight (Torch)"] = "手电筒（火把）"
L["Toggles the \"%s\" toy on and off with a hotkey."] = "使用热键开启或关闭“%s”玩具。"
L["Torch Toggle"] = "切换火把"
L["Toy Missing:"] = "缺少玩具："
L["You don't have the %s!\nGet it from the Illuminated Footlocker:\nhttps://www.wowhead.com/object=437211/illuminated-footlocker"] = "您没有玩具“%s”！\n请从光耀提箱中获取：\nhttps://www.wowhead.com/cn/object=437211/光耀提箱"
L["Flashlight module is disabled. Enable it in the addon options."] = "手电筒模块已禁用。请在插件设置中启用。"

-- MuteSounds Options
L["Mute Sounds"] = "静音声音"
L["Mute specific sounds by their Sound File IDs.\n\nFind IDs on Wago (https://wago.tools/sounds), Wowhead (https://www.wowhead.com/sounds/) or learn about other methods at https://warcraft.wiki.gg/wiki/API_MuteSoundFile.\n\nExample: 598079, 598187 (Dutiful Squire summon sounds)."] = "根据声音文件 ID 静音特定声音。\n\n在 Wago (https://wago.tools/sounds), Wowhead (https://www.wowhead.com/sounds/) 上查找 ID，或在 https://warcraft.wiki.gg/wiki/API_MuteSoundFile 上了解其他方法。\n\n示例：598079, 598187（负责任的侍从召唤声音）。"
L["Sound IDs to mute (comma-separated)"] = "要静音的声音 ID（逗号分隔）"
L["Enter Sound File IDs separated by commas."] = "输入用逗号分隔的声音文件 ID。"

-- DialogSkipper Options
L["Dialog Skipper"] = "对话跳过器"
L["Automatically skip confirmation dialogs."] = "自动跳过确认对话框。"
L["Skip auction house buyout confirmations"] = "跳过拍卖行一口价确认"
L["Back to previous item list after buyout"] = "购买后返回上一个列表"
L["After buying out an item, the addon automatically returns you to the previous item list overview. This is useful when you typically purchase one listing of an item and then want to go back to browse other items."] = "购买物品后，插件自动返回上一个物品列表概览。当您通常购买一个物品的一条清单，然后想返回浏览其他物品时，这很有用。"
L["Only skip if price is below (gold)"] = "仅在价格低于（金币）时跳过"
L["Set the maximum price in gold for automatically confirming auctions."] = "设置自动确认拍卖的最高金币价格。"
L["Skip Polished Pet Charm purchases"] = "跳过使用抛光的宠物符购买确认"
L["Skip Order Resources purchases"] = "跳过使用职业大厅资源购买确认"
L["Skip equip bind confirmations"] = "跳过装备绑定确认"
L["Automatically confirm \"Bind on Equip\" dialogs when equipping gear from quest rewards, vendors, or other sources."] = "在装备来自任务奖励、商人或其他来源的装备时，自动确认“装备后绑定”对话框。"

-- VendorItemOverlay Options
L["Vendor Item Overlay"] = "商人物品覆盖"
L["Display useful information as overlays for items at vendors."] = "为商人处的物品显示有用的覆盖信息。"
L["Ownership for decor items"] = "装饰物品所有权"
L["Display ownership information for housing decor items when visiting vendors. Shows the count as [in storage]/[total owned] in the top-right corner of each item icon."] = "访问商人时显示住房装饰物品的所有权信息。在每个物品图标的右上角显示数量，格式为[存储中]/[总拥有]。"
L["Already known for toys"] = "已知的玩具"
L["Grey out and mark toys that you already know."] = "将你已经知道的玩具变灰并标记。"
L["Already known for mounts"] = "已知的坐骑"
L["Grey out and mark mounts that you already know."] = "将你已经拥有的坐骑变灰并标记。"
L["Already known for transmogs and heirlooms"] = "已知的幻化和传家宝"
L["Grey out and mark transmog items/ensembles and heirlooms that you already know."] = "将你已经知道的幻化物品/套装和传家宝变灰并标记。"
L["Treat non-appearance items as known"] = "将无外观物品视为已知"
L["Necklaces, rings and trinkets will be marked as already known even though they technically cannot be learned. This prevents them from looking like uncollected items in the vendor."] = "项链、戒指和饰品将被标记为已知，即使它们在技术上无法学习。这可以防止它们在商人处看起来像未收集的物品。"
L["Already known for pets"] = "已知的宠物"
L["Grey out and mark battle pets that you have already collected."] = "将你已经收集的战斗宠物变灰并标记。"
L["Already known for recipes"] = "已知的配方"
L["Grey out and mark recipes that you already know."] = "将你已经学会的配方变灰并标记。"

-- SpellIconOverlay Options
L["Spell Icon Overlay"] = "法术图标覆盖"
L["Display an |A:UI-RefreshButton:16:16:0:0|a icon overlay on spells in the spellbook or action bars that are included in the single-button combat rotation. So you can identify them at a glance."] = "在法术书或动作条中包含在单键战斗循环的法术上显示 |A:UI-RefreshButton:16:16:0:0|a 图标覆盖。这样您可以一目了然地识别它们。"
L["Show in Spellbook"] = "在法术书中显示"
L["Display the |A:UI-RefreshButton:16:16:0:0|a icon overlay on spells in your spellbook that are included in the single-button combat rotation."] = "在您的法术书中包含在单键战斗循环的法术上显示 |A:UI-RefreshButton:16:16:0:0|a 图标覆盖。"
L["Show on Action Bars"] = "在动作条上显示"
L["Display the |A:UI-RefreshButton:16:16:0:0|a icon overlay on action bar buttons for spells included in the rotation."] = "在包含在循环中的法术的动作条按钮上显示 |A:UI-RefreshButton:16:16:0:0|a 图标覆盖。"
L["Only when Single-Button is used"] = "仅在使用单键时"
L["Only show the |A:UI-RefreshButton:16:16:0:0|a icon overlay on action bars if the Single-Button Assistant spell is currently placed on an action bar."] = "仅当单键助手法术当前放置在动作条上时，才在动作条上显示 |A:UI-RefreshButton:16:16:0:0|a 图标覆盖。"

-- PersistentUnsheath Options
L["Persistent Unsheath"] = "持久武器状态"
L["Automatically maintain your desired weapon sheath state."] = "自动保持您期望的武器收拔状态。"
L["Restore sheathed"] = "恢复收起武器"
L["Remembers if your last sheath/unsheath toggle was into the sheathed state and automatically returns to sheathed whenever a game action changes the state to unsheathed (for example, after combat)."] = "记住您最后是将武器收起，并在游戏动作改变状态为拔出（例如战斗后）时自动恢复为收起状态。"
L["Restore unsheathed"] = "恢复拔出武器"
L["Remembers if your last sheath/unsheath toggle was into the unsheathed state and automatically returns to unsheathed whenever a game action changes the state to sheathed (for example, after casting or interacting with NPCs)."] = "记住您最后是将武器拔出，并在游戏动作改变状态为收起（例如施法或与 NPC 互动后）时自动恢复为拔出状态。"
L["Silent restoration"] = "静音恢复"
L["Mutes the sheath and unsheath sound effects when the addon automatically restores your weapon state. The sounds from manual toggling are not affected."] = "当插件自动恢复您的武器状态时，静音收拔武器的音效。手动切换的声音不受影响。"

-- PersistentCompanion Options
L["Persistent Companion"] = "持久伙伴"
L["Automatically resummon your last active pet companion after it disappears. For example, after flying or stepping through portals."] = "在最后激活的宠物伙伴消失后自动重新召唤。例如，在飞行或穿过传送门之后。"
L["Dismiss pet while stealthed"] = "潜行时解散宠物"
L["Automatically dismiss your pet when entering stealth and resummon it when leaving stealth."] = "进入潜行时自动解散宠物，离开潜行时重新召唤。"
L["Dismiss pet in combat"] = "战斗中解散宠物"
L["Automatically dismiss your pet when entering combat and resummon it when combat ends."] = "进入战斗时自动解散宠物，战斗结束时重新召唤。"
L["Mute automatic summon sound"] = "静音自动召唤音效"
L["Mute the pet summon sound when automatically resummoning your pet. The sound from manual summoning is not affected.\n\nThis works for most pets (the ones using the \"huntertrapopen\" sound). Feel free to let the addon author know the IDs of other pet summing sounds to be added."] = "自动重新召唤宠物时静音召唤音效。手动召唤的声音不受影响。\n\n这适用于大多数宠物（使用“huntertrapopen”声音的宠物）。欢迎告诉插件作者其他需要添加的宠物召唤声音 ID。"

-- Welcome Message
L["Welcome to LudiusPlus! Type /ldp to pick modules to enable."] = "欢迎使用 LudiusPlus！输入 /ldp 选择要启用的模块。"
