local L = LibStub("AceLocale-3.0"):NewLocale("LudiusPlus", "koKR")
if not L then return end

-- DismountToggle Options
L["Dismount/Mount Toggle"] = "내리기/타기 전환"
L["Assign dismounting and re-mounting to a single key, so you can comfortably switch between both. The addon will remember your last mount and re-mount it when you press the hotkey again."] = "내리기와 다시 타기를 단일 키에 할당하여 편안하게 전환할 수 있습니다. 애드온이 마지막 탈것을 기억하여 단축키를 다시 누르면 해당 탈것을 다시 소환합니다."
L["Enable"] = "활성화"
L["Assigned Hotkey:"] = "할당된 단축키:"
L["Not Bound"] = "할당 안 됨"
L["New Key Bind"] = "새 단축키 지정"
L["Assign a new hotkey binding."] = "새로운 키를 할당합니다."
L["Unbind"] = "삭제"
L["Unassign the current binding."] = "현재 할당을 제거합니다."
L["When mounting, switch automatically to Action Bar:"] = "탈것 탑승 시 다음 행동 단축바로 자동 전환:"
L["Automatically switch to this action bar when you mount up, so you have your flying/mount abilities easily accessible. Set to \"disabled\" to keep your current action bar."] = "탈것에 탈 때 이 행동 단축바로 자동으로 전환하여 비행/탈것 능력을 쉽게 사용할 수 있습니다. 현재 행동 단축바를 유지하려면 \"비활성화됨\"으로 설정하십시오."
L["Druid Travel Form instead of mounting"] = "탈것 대신 드루이드 여행 변신 사용"
L["Druids only: Use Travel Form or Flight Form as \"mounting\", and Humanoid form as \"dismounting\", instead of standard mounts."] = "드루이드 전용: 표준 탈것 대신 여행 변신 또는 빠른 날개 변신을 \"타기\"로, 인간 형상을 \"내리기\"로 사용합니다."
L["Dracthyr Soar instead of mounting"] = "탈것 대신 드랙타르 비상 사용"
L["Dracthyr only: Use Soar as \"mounting\" and humanoid form as \"dismounting\", instead of standard mounts."] = "드랙타르 전용: 표준 탈것 대신 비상을 \"타기\"로, 인간 형상을 \"내리기\"로 사용합니다."
L["Mounts to ignore (comma-separated Mount IDs)"] = "무시할 탈것 (쉼표로 구분된 탈것 ID)"
L["Enter Mount IDs to ignore when storing your last mount. Useful for utility mounts like Yak or Brutosaur that you use temporarily but don't want to summon with your hotkey.\n\nFind Mount IDs at: https://www.wowhead.com/spells/mounts"] = "마지막 탈것을 저장할 때 무시할 탈것 ID를 입력하십시오. 야크나 브루토사우루스와 같이 일시적으로 사용하지만 단축키로 소환하고 싶지 않은 편의성 탈것에 유용합니다.\n\n탈것 ID 찾기: https://www.wowhead.com/spells/mounts"
L["Fill in Utility Mounts"] = "편의성 탈것 채우기"
L["Adds commonly used utility mounts to the ignore list:"] = "자주 사용하는 편의성 탈것을 무시 목록에 추가합니다:"
L["Auto-mount last non-ignored mount when on ignored mounts"] = "무시된 탈것 탑승 시 마지막 비무시 탈것 자동 탑승"
L["While on an ignored mount, the hotkey will dismount and immediately mount the last non-ignored mount. Disable to only dismount."] = "무시된 탈것에 탑승한 상태에서 단축키를 누르면 내린 후 즉시 마지막으로 무시되지 않은 탈것에 탑승합니다. 내리기만 하려면 비활성화하십시오."
L["Dismount/Mount Toggle module is disabled. Enable it in the addon options."] = "내리기/타기 전환 모듈이 비활성화되어 있습니다. 애드온 설정에서 활성화하세요."

-- RaceOnLastMount Options
L["Race on Last Mount"] = "마지막 탈것으로 경주"
L["When you start a Skyriding race while not mounted, you're automatically placed on the Renewed Proto-Drake with no way to choose your preferred mount. This addon automatically switches to your last active flying mount during the race countdown (after a 2-second delay required by the game).\n\nNote: Cannot automatically switch to Druid Flight Form due to API limitations."] = "탈것에 탑승하지 않은 상태로 하늘비행 경주를 시작하면, 보통 자동으로 소생한 원시비룡에 탑승하게 됩니다. 이 애드온은 카운트다운 중에 마지막으로 사용한 비행 탈것으로 자동 전환합니다(2초 지연 후).\n\n참고: API 제한으로 인해 드루이드 빠른 날개 변신으로 자동 전환은 불가능합니다."

-- Flashlight Options
L["Flashlight (Torch)"] = "손전등 (횃불)"
L["Toggles the \"%s\" toy on and off with a hotkey."] = "단축키로 \"%s\" 장난감을 켜고 끕니다."
L["Torch Toggle"] = "횃불 켜기/끄기"
L["Toy Missing:"] = "장난감 없음:"
L["You don't have the %s!\nGet it from the Illuminated Footlocker:\nhttps://www.wowhead.com/object=437211/illuminated-footlocker"] = "\"%s\" 장난감을 가지고 있지 않습니다!\n빛나는 사물함에서 획득하세요:\nhttps://www.wowhead.com/ko/object=437211/빛나는-사물함"
L["Flashlight module is disabled. Enable it in the addon options."] = "횜래시 모듈이 비활성화되어 있습니다. 애드온 설정에서 활성화하세요."

-- MuteSounds Options
L["Mute Sounds"] = "소리 음소거"
L["Mute specific sounds by their Sound File IDs.\n\nFind IDs on Wago (https://wago.tools/sounds), Wowhead (https://www.wowhead.com/sounds/) or learn about other methods at https://warcraft.wiki.gg/wiki/API_MuteSoundFile.\n\nExample: 598079, 598187 (Dutiful Squire summon sounds)."] = "사운드 파일 ID로 특정 소리를 음소거합니다.\n\nWago(https://wago.tools/sounds), Wowhead(https://www.wowhead.com/sounds/)에서 ID를 찾거나 https://warcraft.wiki.gg/wiki/API_MuteSoundFile에서 다른 방법에 대해 알아보세요.\n\n예: 598079, 598187 (충직한 종자 소환 소리)."
L["Sound IDs to mute (comma-separated)"] = "음소거할 사운드 ID (쉼표로 구분)"
L["Enter Sound File IDs separated by commas."] = "쉼표로 구분하여 사운드 파일 ID를 입력하십시오."

-- DialogSkipper Options
L["Dialog Skipper"] = "대화 건너뛰기"
L["Automatically skip confirmation dialogs."] = "확인 대화 상자를 자동으로 건너뜁니다."
L["Skip auction house buyout confirmations"] = "경매장 즉시 구입 확인 건너뛰기"
L["Back to previous item list after buyout"] = "구매 후 이전 목록으로 돌아가기"
L["After buying out an item, the addon automatically returns you to the previous item list overview. This is useful when you typically purchase one listing of an item and then want to go back to browse other items."] = "아이템을 구매한 후 애드온이 자동으로 이전 아이템 목록 개요로 돌아갑니다. 일반적으로 아이템의 한 목록을 구매한 다음 돌아가서 다른 아이템을 탐색하려는 경우 유용합니다."
L["Only skip if price is below (gold)"] = "가격이 다음 미만일 경우에만 건너뛰기 (골드)"
L["Set the maximum price in gold for automatically confirming auctions."] = "경매를 자동으로 확인할 최대 가격(골드)을 설정합니다."
L["Skip Polished Pet Charm purchases"] = "윤나는 애완동물 부적 구매 확인 건너뛰기"
L["Skip Order Resources purchases"] = "연맹 자원 구매 확인 건너뛰기"
L["Skip equip bind confirmations"] = "착용 시 귀속 확인 건너뛰기"
L["Automatically confirm \"Bind on Equip\" dialogs when equipping gear from quest rewards, vendors, or other sources."] = "퀘스트 보상, 상인 또는 기타 출처의 장비를 착용할 때 \"착용 시 귀속\" 대화 상자를 자동으로 확인합니다."

-- VendorItemOverlay Options
L["Vendor Item Overlay"] = "상인 아이템 오버레이"
L["Display useful information as overlays for items at vendors."] = "상인의 아이템에 유용한 정보를 오버레이로 표시합니다."
L["Ownership for decor items"] = "장식 아이템 소유 정보"
L["Display ownership information for housing decor items when visiting vendors. Shows the count as [in storage]/[total owned] in the top-right corner of each item icon."] = "상인 방문 시 주거 장식 아이템의 소유 정보를 표시합니다. 각 아이템 아이콘의 오른쪽 상단에 [보관 중]/[총 소유] 형식으로 수량이 표시됩니다."
L["Already known for toys"] = "이미 알고 있는 장난감"
L["Grey out and mark toys that you already know."] = "이미 알고 있는 장난감을 회색으로 표시하고 체크합니다."
L["Already known for mounts"] = "이미 알고 있는 탈것"
L["Grey out and mark mounts that you already know."] = "이미 알고 있는 탈것을 회색으로 표시하고 체크합니다."
L["Already known for transmogs and heirlooms"] = "이미 알고 있는 형상변환 및 계승품"
L["Grey out and mark transmog items/ensembles and heirlooms that you already know."] = "이미 알고 있는 형상변환 아이템/세트 및 계승품을 회색으로 표시하고 체크합니다."
L["Treat non-appearance items as known"] = "외형이 없는 아이템을 아는 것으로 취급"
L["Necklaces, rings and trinkets will be marked as already known even though they technically cannot be learned. This prevents them from looking like uncollected items in the vendor."] = "목걸이, 반지, 장신구는 기술적으로 배울 수 없더라도 이미 아는 것으로 표시됩니다. 이렇게 하면 상인에게서 수집하지 않은 아이템처럼 보이는 것을 방지할 수 있습니다."
L["Already known for pets"] = "이미 알고 있는 애완동물"
L["Grey out and mark battle pets that you have already collected."] = "이미 수집한 애완동물을 회색으로 표시하고 체크합니다."
L["Already known for recipes"] = "이미 알고 있는 조리법"
L["Grey out and mark recipes that you already know."] = "이미 알고 있는 조리법을 회색으로 표시하고 체크합니다."

-- SpellIconOverlay Options
L["Spell Icon Overlay"] = "주문 아이콘 오버레이"
L["Display an |A:UI-RefreshButton:16:16:0:0|a icon overlay on spells in the spellbook or action bars that are included in the single-button combat rotation. So you can identify them at a glance."] = "단일 버튼 전투 로테이션에 포함된 주문책이나 행동 단축바의 주문에 |A:UI-RefreshButton:16:16:0:0|a 아이콘 오버레이를 표시합니다. 한눈에 식별할 수 있습니다."
L["Show in Spellbook"] = "주문책에 표시"
L["Display the |A:UI-RefreshButton:16:16:0:0|a icon overlay on spells in your spellbook that are included in the single-button combat rotation."] = "단일 버튼 전투 로테이션에 포함된 주문책의 주문에 |A:UI-RefreshButton:16:16:0:0|a 아이콘 오버레이를 표시합니다."
L["Show on Action Bars"] = "행동 단축바에 표시"
L["Display the |A:UI-RefreshButton:16:16:0:0|a icon overlay on action bar buttons for spells included in the rotation."] = "로테이션에 포함된 주문의 행동 단축바 버튼에 |A:UI-RefreshButton:16:16:0:0|a 아이콘 오버레이를 표시합니다."
L["Only when Single-Button is used"] = "단일 버튼 사용 시에만"
L["Only show the |A:UI-RefreshButton:16:16:0:0|a icon overlay on action bars if the Single-Button Assistant spell is currently placed on an action bar."] = "단일 버튼 도우미 주문이 현재 행동 단축바에 배치된 경우에만 행동 단축바에 |A:UI-RefreshButton:16:16:0:0|a 아이콘 오버레이를 표시합니다."

-- PersistentUnsheath Options
L["Persistent Unsheath"] = "무기 상태 유지"
L["Automatically maintain your desired weapon sheath state."] = "원하는 무기 무장/해제 상태를 자동으로 유지합니다."
L["Restore sheathed"] = "무기 넣기 복원"
L["Remembers if your last sheath/unsheath toggle was into the sheathed state and automatically returns to sheathed whenever a game action changes the state to unsheathed (for example, after combat)."] = "마지막으로 무기를 넣은 상태였는지 기억하고, 게임 동작으로 인해 무기를 꺼내게 될 때(예: 전투 후) 자동으로 무기를 넣은 상태로 돌아갑니다."
L["Restore unsheathed"] = "무기 꺼내기 복원"
L["Remembers if your last sheath/unsheath toggle was into the unsheathed state and automatically returns to unsheathed whenever a game action changes the state to sheathed (for example, after casting or interacting with NPCs)."] = "마지막으로 무기를 꺼낸 상태였는지 기억하고, 게임 동작으로 인해 무기를 넣게 될 때(예: 주문 시전 또는 NPC와 상호작용 후) 자동으로 무기를 꺼낸 상태로 돌아갑니다."
L["Silent restoration"] = "조용한 복원"
L["Mutes the sheath and unsheath sound effects when the addon automatically restores your weapon state. The sounds from manual toggling are not affected."] = "애드온이 무기 상태를 자동으로 복원할 때 무기 넣기/꺼내기 효과음을 음소거합니다. 수동 전환 소리는 영향을 받지 않습니다."

-- PersistentCompanion Options
L["Persistent Companion"] = "지속적인 동료"
L["Automatically resummon your last active pet companion after it disappears. For example, after flying or stepping through portals."] = "사라진 후 마지막 활성 애완동물 동료를 자동으로 다시 소환합니다. 예: 비행 후 또는 포털을 통과한 후."
L["Dismiss pet while stealthed"] = "은신 시 애완동물 소환 해제"
L["Automatically dismiss your pet when entering stealth and resummon it when leaving stealth."] = "은신 상태에 들어갈 때 자동으로 애완동물을 소환 해제하고 은신이 풀리면 다시 소환합니다."
L["Dismiss pet in combat"] = "전투 중 애완동물 소환 해제"
L["Automatically dismiss your pet when entering combat and resummon it when combat ends."] = "전투가 시작되면 자동으로 애완동물을 소환 해제하고 전투가 끝나면 다시 소환합니다."
L["Mute automatic summon sound"] = "자동 소환 소리 음소거"
L["Mute the pet summon sound when automatically resummoning your pet. The sound from manual summoning is not affected.\n\nThis works for most pets (the ones using the \"huntertrapopen\" sound). Feel free to let the addon author know the IDs of other pet summing sounds to be added."] = "애드온이 애완동물을 자동으로 재소환할 때 소환 소리를 음소거합니다. 수동 소환 소리는 영향을 받지 않습니다.\n\n이 기능은 대부분의 애완동물(\"huntertrapopen\" 소리를 사용하는 애완동물)에서 작동합니다. 추가할 다른 애완동물 소환 소리의 ID를 애드온 제작자에게 알려주세요."

-- Welcome Message
L["Welcome to LudiusPlus! Type /ldp to pick modules to enable."] = "LudiusPlus에 오신 것을 환영합니다! /ldp를 입력하여 활성화할 모듈을 선택하세요."

-- Dangerous Scripts Warning
L["To use certain features (like Dismount Toggle and Flashlight), LudiusPlus needs your permission to run macros.\n\nPlease click \"Allow Scripts\" below, then \"Yes\" in the game's confirmation pop-up to enable these modules."] = "특정 기능(내리기/타기 전환 및 손전등 등)을 사용하려면 LudiusPlus가 매크로를 실행할 수 있는 권한이 필요합니다.\n\n아래의 \"스크립트 허용\"을 클릭한 다음 게임의 확인 창에서 \"예\"를 클릭하여 이러한 모듈을 활성화하세요."
L["Allow Scripts"] = "스크립트 허용"
