local L = LibStub("AceLocale-3.0"):NewLocale("LudiusPlus", "ruRU")
if not L then return end

-- DismountToggle Options
L["Dismount/Mount Toggle"] = "Переключение Транспорт/Спешивание"
L["Assign dismounting and re-mounting to a single key, so you can comfortably switch between both. The addon will remember your last mount and re-mount it when you press the hotkey again."] = "Назначает спешивание и повторное использование транспорта на одну клавишу для удобного переключения. Аддон запомнит ваше последнее средство передвижения и призовет его снова при повторном нажатии клавиши."
L["Enable"] = "Включить"
L["Assigned Hotkey:"] = "Назначенная клавиша:"
L["Not Bound"] = "Не назначено"
L["New Key Bind"] = "Новое назначение"
L["Assign a new hotkey binding."] = "Назначает новую клавишу."
L["Unbind"] = "Удалить"
L["Unassign the current binding."] = "Удаляет текущее назначение."
L["When mounting, switch automatically to Action Bar:"] = "При использовании транспорта переключать на Панель команд:"
L["Automatically switch to this action bar when you mount up, so you have your flying/mount abilities easily accessible. Set to \"disabled\" to keep your current action bar."] = "Автоматически переключается на эту панель команд, когда вы садитесь на транспорт, для доступа к способностям полета. Установите на «отключено», чтобы оставить текущую панель."
L["Druid Travel Form instead of mounting"] = "Походный облик друида вместо транспорта"
L["Druids only: Use Travel Form or Flight Form as \"mounting\", and Humanoid form as \"dismounting\", instead of standard mounts."] = "Только друиды: Использовать Походный облик или Облик птицы как «транспорт» и гуманоидный облик как «спешивание», вместо стандартного транспорта."
L["Dracthyr Soar instead of mounting"] = "Драктир Парение вместо транспорта"
L["Dracthyr only: Use Soar as \"mounting\" and humanoid form as \"dismounting\", instead of standard mounts."] = "Только драктиры: Использовать Парение как «транспорт» и гуманоидный облик как «спешивание», вместо стандартного транспорта."
L["Mounts to ignore (comma-separated Mount IDs)"] = "Игнорируемые маунты (ID через запятую)"
L["Enter Mount IDs to ignore when storing your last mount. Useful for utility mounts like Yak or Brutosaur that you use temporarily but don't want to summon with your hotkey.\n\nFind Mount IDs at: https://www.wowhead.com/spells/mounts"] = "Введите ID маунтов, которые нужно игнорировать при запоминании последнего транспорта. Полезно для Яка или Брутозавра, которых вы не хотите вызывать горячей клавишей.\n\nID маунтов можно найти здесь: https://www.wowhead.com/spells/mounts"
L["Fill in Utility Mounts"] = "Добавить полезных маунтов"
L["Adds commonly used utility mounts to the ignore list:"] = "Добавляет часто используемых полезных маунтов (ремонт/торговцы) в список игнорирования:"
L["Auto-mount last non-ignored mount when on ignored mounts"] = "Авто-маунт последнего неигнорируемого маунта"
L["While on an ignored mount, the hotkey will dismount and immediately mount the last non-ignored mount. Disable to only dismount."] = "Если вы на игнорируемом маунте, клавиша спешит вас и сразу призовет последнего неигнорируемого маунта. Отключите, чтобы только спешиваться."
L["Dismount/Mount Toggle module is disabled. Enable it in the addon options."] = "Модуль Переключение Транспорт/Спешивание отключен. Включите его в настройках аддона."

-- RaceOnLastMount Options
L["Race on Last Mount"] = "Гонка на последнем маунте"
L["When you start a Skyriding race while not mounted, you're automatically placed on the Renewed Proto-Drake with no way to choose your preferred mount. This addon automatically switches to your last active flying mount during the race countdown (after a 2-second delay required by the game).\n\nNote: Cannot automatically switch to Druid Flight Form due to API limitations."] = "Если вы начинаете гонку (Высший пилотаж), не сидя на маунте, вы обычно автоматически оказываетесь на Возрожденном протодраконе. Этот аддон автоматически переключает вас на вашего последнего использованного летающего маунта во время отсчета (после 2-секундной задержки).\n\nПримечание: Автоматическое переключение в облик птицы друида невозможно из-за ограничений API."

-- Flashlight Options
L["Flashlight (Torch)"] = "Фонарик (Факел)"
L["Toggles the \"%s\" toy on and off with a hotkey."] = "Включает и выключает игрушку \"%s\" горячей клавишей."
L["Torch Toggle"] = "Переключить факел"
L["Toy Missing:"] = "Игрушка отсутствует:"
L["You don't have the %s!\nGet it from the Illuminated Footlocker:\nhttps://www.wowhead.com/object=437211/illuminated-footlocker"] = "У вас нет игрушки «%s»!\nПолучите ее из Сияющего сундука:\nhttps://www.wowhead.com/ru/object=437211/сияющий-сундук"
L["Flashlight module is disabled. Enable it in the addon options."] = "Модуль Фонарик отключен. Включите его в настройках аддона."

-- MuteSounds Options
L["Mute Sounds"] = "Отключить звуки"
L["Mute specific sounds by their Sound File IDs.\n\nFind IDs on Wago (https://wago.tools/sounds), Wowhead (https://www.wowhead.com/sounds/) or learn about other methods at https://warcraft.wiki.gg/wiki/API_MuteSoundFile.\n\nExample: 598079, 598187 (Dutiful Squire summon sounds)."] = "Отключает определенные звуки по их ID файла звука.\n\nНайдите ID на Wago (https://wago.tools/sounds), Wowhead (https://www.wowhead.com/sounds/) или узнайте о других методах на https://warcraft.wiki.gg/wiki/API_MuteSoundFile.\n\nПример: 598079, 598187 (звуки призыва Верного оруженосца)."
L["Sound IDs to mute (comma-separated)"] = "ID звуков для отключения (через запятую)"
L["Enter Sound File IDs separated by commas."] = "Введите ID звуковых файлов через запятую."

-- DialogSkipper Options
L["Dialog Skipper"] = "Пропуск диалогов"
L["Automatically skip confirmation dialogs."] = "Автоматически пропускает диалоги подтверждения."
L["Skip auction house buyout confirmations"] = "Пропускать подтверждение выкупа на аукционе"
L["Back to previous item list after buyout"] = "Вернуться к предыдущему списку после покупки"
L["After buying out an item, the addon automatically returns you to the previous item list overview. This is useful when you typically purchase one listing of an item and then want to go back to browse other items."] = "После выкупа предмета аддон автоматически возвращает вас к предыдущему обзору списка предметов. Это полезно, когда вы обычно покупаете одно предложение предмета, а затем хотите вернуться, чтобы просматривать другие предметы."
L["Only skip if price is below (gold)"] = "Пропускать только если цена ниже (золото)"
L["Set the maximum price in gold for automatically confirming auctions."] = "Установите максимальную цену в золоте для автоматического подтверждения аукционов."
L["Skip Polished Pet Charm purchases"] = "Пропускать подтверждение покупок за Отполированные обереги"
L["Skip Order Resources purchases"] = "Пропускать подтверждение покупок за Ресурсы оплота"
L["Skip equip bind confirmations"] = "Пропускать подтверждение персональных предметов"
L["Automatically confirm \"Bind on Equip\" dialogs when equipping gear from quest rewards, vendors, or other sources."] = "Автоматически подтверждает диалоги «Становится персональным при надевании» при экипировке предметов из наград за задания, от торговцев или других источников."

-- VendorItemOverlay Options
L["Vendor Item Overlay"] = "Наложение предметов торговца"
L["Display useful information as overlays for items at vendors."] = "Показывает полезную информацию в виде наложений для предметов у торговцев."
L["Ownership for decor items"] = "Владение декором"
L["Display ownership information for housing decor items when visiting vendors. Shows the count as [in storage]/[total owned] in the top-right corner of each item icon."] = "Показывает информацию о владении предметами декора жилья при посещении торговцев. Количество отображается как [на складе]/[всего принадлежит] в правом верхнем углу каждого значка предмета."
L["Already known for toys"] = "Уже известно для игрушек"
L["Grey out and mark toys that you already know."] = "Затеняет и отмечает игрушки, которые вы уже знаете."
L["Already known for mounts"] = "Уже известно для транспорта"
L["Grey out and mark mounts that you already know."] = "Затеняет и отмечает транспорт, который вы уже знаете."
L["Already known for transmogs and heirlooms"] = "Уже известно для трансмогрификации и наследуемых предметов"
L["Grey out and mark transmog items/ensembles and heirlooms that you already know."] = "Затеняет и отмечает предметы/комплекты трансмогрификации и наследуемые предметы, которые вы уже знаете."
L["Treat non-appearance items as known"] = "Считать предметы без внешнего вида известными"
L["Necklaces, rings and trinkets will be marked as already known even though they technically cannot be learned. This prevents them from looking like uncollected items in the vendor."] = "Ожерелья, кольца и аксессуары будут отмечены как уже известные, даже если технически их нельзя изучить. Это предотвращает их отображение как несобранных предметов у торговца."
L["Already known for pets"] = "Уже известно для питомцев"
L["Grey out and mark battle pets that you have already collected."] = "Затеняет и отмечает боевых питомцев, которых вы уже собрали."
L["Already known for recipes"] = "Уже известно для рецептов"
L["Grey out and mark recipes that you already know."] = "Затеняет и отмечает рецепты, которые вы уже знаете."

-- SpellIconOverlay Options
L["Spell Icon Overlay"] = "Наложение значка заклинания"
L["Display an |A:UI-RefreshButton:16:16:0:0|a icon overlay on spells in the spellbook or action bars that are included in the single-button combat rotation. So you can identify them at a glance."] = "Отображает наложение значка |A:UI-RefreshButton:16:16:0:0|a на заклинаниях в книге заклинаний или на панелях команд, которые включены в однокнопочную боевую ротацию. Так вы сможете сразу их определить."
L["Show in Spellbook"] = "Показывать в книге заклинаний"
L["Display the |A:UI-RefreshButton:16:16:0:0|a icon overlay on spells in your spellbook that are included in the single-button combat rotation."] = "Отображает наложение значка |A:UI-RefreshButton:16:16:0:0|a на заклинаниях в вашей книге заклинаний, которые включены в однокнопочную боевую ротацию."
L["Spellbook Icon Position"] = "Позиция значка в книге заклинаний"
L["Choose the corner where the overlay icon appears on spellbook buttons."] = "Выберите угол, где будет отображаться значок наложения на кнопках книги заклинаний."
L["Show on Action Bars"] = "Показывать на панелях команд"
L["Display the |A:UI-RefreshButton:16:16:0:0|a icon overlay on action bar buttons for spells included in the rotation."] = "Отображает наложение значка |A:UI-RefreshButton:16:16:0:0|a на кнопках панели команд для заклинаний, включенных в ротацию."
L["Action Bar Icon Position"] = "Позиция значка на панели команд"
L["Choose the corner where the overlay icon appears on action bar buttons."] = "Выберите угол, где будет отображаться значок наложения на кнопках панели команд."
L["Only when Single-Button is used"] = "Только при использовании одной кнопки"
L["Only show the |A:UI-RefreshButton:16:16:0:0|a icon overlay on action bars if the Single-Button Assistant spell is currently placed on an action bar."] = "Показывать наложение значка |A:UI-RefreshButton:16:16:0:0|a на панелях команд только в том случае, если заклинание Однокнопочный помощник в данный момент размещено на панели команд."
L["Top Left"] = "Сверху слева"
L["Top Right"] = "Сверху справа"
L["Bottom Left"] = "Снизу слева"
L["Bottom Right"] = "Снизу справа"

-- PersistentUnsheath Options
L["Persistent Unsheath"] = "Постоянное оружие"
L["Automatically maintain your desired weapon sheath state."] = "Автоматически поддерживает желаемое состояние оружия (в ножнах/в руках)."
L["Restore sheathed"] = "Восстанавливать в ножнах"
L["Remembers if your last sheath/unsheath toggle was into the sheathed state and automatically returns to sheathed whenever a game action changes the state to unsheathed (for example, after combat)."] = "Запоминает, если вы убрали оружие, и автоматически убирает его снова, если какое-либо действие заставило достать его (например, после боя)."
L["Restore unsheathed"] = "Восстанавливать в руках"
L["Remembers if your last sheath/unsheath toggle was into the unsheathed state and automatically returns to unsheathed whenever a game action changes the state to sheathed (for example, after casting or interacting with NPCs)."] = "Запоминает, если вы достали оружие, и автоматически достает его снова, если какое-либо действие заставило убрать его (например, после заклинаний или общения с NPC)."
L["Silent restoration"] = "Тихое восстановление"
L["Mutes the sheath and unsheath sound effects when the addon automatically restores your weapon state. The sounds from manual toggling are not affected."] = "Отключает звуки доставания и убирания оружия, когда аддон автоматически восстанавливает состояние. Звуки от ручного переключения не затрагиваются."

-- PersistentCompanion Options
L["Persistent Companion"] = "Постоянный спутник"
L["Automatically resummon your last active pet companion after it disappears. For example, after flying or stepping through portals."] = "Автоматически повторно призывает вашего последнего активного спутника после его исчезновения. Например, после полета или прохождения через порталы."
L["Dismiss pet while stealthed"] = "Отпускать питомца в незаметности"
L["Automatically dismiss your pet when entering stealth and resummon it when leaving stealth."] = "Автоматически отпускает питомца при входе в незаметность и призывает его снова при выходе."
L["Dismiss pet in combat"] = "Отпускать питомца в бою"
L["Automatically dismiss your pet when entering combat and resummon it when combat ends."] = "Автоматически отпускает питомца при входе в бой и призывает его снова, когда бой заканчивается."
L["Mute automatic summon sound"] = "Отключить звук автоматического призыва"
L["Mute the pet summon sound when automatically resummoning your pet. The sound from manual summoning is not affected.\n\nThis works for most pets (the ones using the \"huntertrapopen\" sound). Feel free to let the addon author know the IDs of other pet summing sounds to be added."] = "Отключает звук призыва питомца при его автоматическом перепризыве. Звук от ручного призыва не затрагивается.\n\nЭто работает для большинства питомцев (тех, кто использует звук \"huntertrapopen\"). Не стесняйтесь сообщать автору аддона ID других звуков призыва питомцев, которые нужно добавить."

-- Welcome Message
L["Welcome to LudiusPlus! Type /ldp to pick modules to enable."] = "Добро пожаловать в LudiusPlus! Введите /ldp, чтобы выбрать модули для включения."

-- Dangerous Scripts Warning
L["To use certain features (like Dismount Toggle and Flashlight), LudiusPlus needs your permission to run macros.\n\nPlease click \"Allow Scripts\" below, then \"Yes\" in the game's confirmation pop-up to enable these modules."] = "Для использования определенных функций (таких как Переключение Транспорт/Спешивание и Фонарик), LudiusPlus требуется ваше разрешение на выполнение макросов.\n\nПожалуйста, нажмите \"Разрешить скрипты\" ниже, затем \"Да\" в подтверждении игры, чтобы включить эти модули."
L["Allow Scripts"] = "Разрешить скрипты"
