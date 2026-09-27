-- Remotes.lua: idempotent RemoteEvent/RemoteFunction bootstrap. The server creates them; the client waits for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"JoinChannel", "ChannelList", "JoinFailed", "RequestReturnToLobby", "RequestChannelRefresh",
	-- The trip back to the lobby, which is not instant: the server saves, then Roblox has to build or find a
	-- lobby server and move the player to it. That wait used to happen behind a screen where nothing changed,
	-- so the button read as broken and got pressed again. Now it is a bar -- and a bar implies a window in
	-- which something can go wrong, which is the other half: a blow, a fall or going down calls the trip off.
	"LobbyTravelChanged",
	-- ปาร์ตี้ของโหมด PVP ในล็อบบี้ (ผู้ใช้ส่งภาพร่างมา 2026-09-23)
	--
	-- **คนละตี้กับตี้ในเกม** — ตี้ในเกมอยู่ในเซิร์ฟช่อง มีหลอดเลือดและระยะ ส่วนอันนี้อยู่ในล็อบบี้
	-- ซึ่งไม่เปิดเซสชันโปรไฟล์และไม่มี Vitals · ใช้ `Party.lua` ตัวเดียวกันเป็นสถานะ แต่คนละ remote
	"PvpPartyUpdate", "RequestPvpParty",
	-- โหมด PVP ในสนาม (เพลส Arena) — คนละชุดกับหน้าปาร์ตี้ในล็อบบี้ข้างบน
	--
	-- `ArenaState` คือภาพเดียวที่หน้าจอทุกชิ้นในสนามวาดตาม (รอบ ตัวนับเวลา ซิลเวอร์ ของที่ถืออยู่ ใครยังยืน)
	-- ส่งทั้งก้อนทุกครั้งแทนที่จะส่งทีละสนาม: แมตช์ยาวสิบกว่านาที ส่งวินาทีละครั้งให้หกคนยังเบามาก
	-- และหน้าจอที่ประกอบจากอีเวนต์หลายตัวคือหน้าจอที่ค้างผิดสถานะเมื่อมีอีเวนต์ไหนมาไม่ถึง
	"ArenaState", "RequestArenaBuy", "RequestArenaRefund", "ArenaMatchEnd", "ArenaNotice", "ArenaKillBanner",
	"SetSprintIntent", "ToggleWalk", -- movement (client intent in; stamina goes out via VitalsUpdate)
	"RequestAttack", "CombatStateChanged", "RequestUnscope", "RequestBlock", "PvpRankInfo", "PvpRankUp", "PvpRankSeen", -- combat (click intent in, guard/attack playback out) · ยกการ์ด + แร็งก์ PVP (เฟส 3)
	-- กับดัก (เฟส 3): เขวี้ยง/วาง · เลือกกระสุน · ภาพ (เขวี้ยง/ระเบิด) ถึงทุกเครื่อง
	"RequestTrap", "RequestTrapAmmo", "TrapEvent",
	-- เนื้อเรื่อง (ผู้มากับแสงวิบวับ): ภาพความคืบหน้า · บทพูด/คัทซีน/ความทรงจำ · ready/cutscene_done จากไคลเอนต์
	"StoryState", "StoryPlay", "RequestStory",
	"VitalsUpdate", "DownedStateChanged", "RequestRespawn", -- vitals (hp/hunger/stamina/armor out, downed UI, respawn in)
	"RequestRoll", "RequestSlide", "MoveStateChanged", -- roll/slide (client intent in, animation playback out)
	"RequestRevive", "RequestCarry", "RequestDrop", "CarryStateChanged", -- reviving and carrying a downed player
	"ProgressionUpdate", "LevelUp", -- exp/level out, plus a one-shot for the level-up effect
	-- Inventory: contents out, player intents in (move/equip/use/sort), equipment broadcast so everyone can
	-- see what each other is holding.
	"InventoryUpdate", "EquipmentChanged",
	"RequestEquip", "RequestUnequip", "RequestUseItem", "RequestDropItem", "RequestAutoSort",
	"RequestInventoryRefresh",
	-- Hotbar: assigning an item to one of the six slots, and pressing one. Assignment is a drag in the bag
	-- UI; pressing is a number key or a tap.
	"RequestSetHotbar", "RequestUseHotbar",
	-- Classes: the card offering a choice at level 5 and 50, the choice itself, and the confirmation. The
	-- client asks for an offer on join too, since the level that unlocked it may be from an old session.
	"ClassOffer", "RequestChooseClass", "ClassChanged", "RequestClassOffer",
	-- Class actions on a nearby player: one request in, and one broadcast out telling both parties what
	-- happened so each can show it. ClassActionPrompt asks the target to agree, refuse, or defend.
	"RequestClassAction", "ClassActionResult", "ClassActionPrompt", "RespondClassAction",
	-- Trading. The offer is server state: both sides are sent the same picture of it after every change, so
	-- neither can be looking at something the other is not.
	"TradeStateChanged", "RequestTradeOffer", "RequestTradeConfirm", "RequestTradeCancel",
	-- Arrest. One-sided: the guard takes, the prisoner gives. The prisoner is told so their own screen can
	-- show what is being done to them, and so the hold ends on their client too.
	"ArrestStateChanged", "RequestArrestTake", "RequestArrestConfirm", "RequestArrestRelease",
	-- คุมขัง: ยึดของและปรับเงินตามที่เลือกไว้ แล้วส่งเข้าคุกตามระยะเวลาที่กด (5/10/30 นาที)
	"RequestArrestJail",
	-- The announcement a class command makes. The command itself is typed into the console, so it arrives
	-- through AdminCommand like every other slash command rather than needing one of its own.
	"ClassAnnouncement",
	-- Riding the monowheel. The server owns the bike, but the CAMERA is the client's alone -- no server can
	-- set another machine's camera -- so getting on and off is broadcast and the rider's own client locks
	-- itself into first person for as long as it is seated.
	"MonowheelRideChanged",
	-- Handing one item to a player standing next to you, from the bag menu.
	"RequestGiveItem",
	-- Eating and drinking take time; every client needs to know so it can play the animation and hold the
	-- item to the mouth.
	"ConsumeStateChanged", -- client asks for a resend: the join broadcast can land before it connects
	"RequestSkill", "SkillUsed", -- the weapon's Q skill: intent in, playback out
	"StatusChanged", -- knockdown / slow, so every client can render them
	-- Emotes. The ANIMATION needs no remote: a client playing on its own character's Animator replicates to
	-- everyone by itself. What does need the server is the part a client must not be trusted with -- holding
	-- the player still while they sit or lie down. PlayerMovement rewrites WalkSpeed every tick from the
	-- server's own idea of it, so a client setting WalkSpeed = 0 would be overwritten within the frame.
	"RequestEmotePose",
	-- The admin command's leg back down to a client. An emote plays on the poser's OWN Animator -- that is how
	-- it reaches everybody else for free -- so a server that wants someone to strike a pose has to ask them,
	-- rather than playing it itself and having the client's own animations overwrite it a frame later.
	"PlayEmote",
	-- The admin chest. The chest MODEL is drawn on each admin's own client -- that is the only way "only
	-- admins can see it" is true of a thing standing in the world -- so these are where the actual granting
	-- happens, and the server checks the roster on every one of them.
	"RequestAdminItem", "RequestAdminGold",
	-- Footsteps: each client times its OWN steps (it knows its material and gait without asking) and reports
	-- them; the server relays to everyone else so you hear people around you. Relaying rather than having
	-- each client time every other character keeps one authority on who stepped when, and costs one small
	-- event per step instead of every client running a state machine per player.
	"Footstep",
	-- A real blow landing, sent to the two people in it so their music can react. Not fired for a swing at
	-- air: music that swells every time someone practises on nothing would be constant.
	"CombatHit",
	-- Something hurt YOU -- a monster's bite, or hunger eating into your blood. Sent to that one player
	-- because the sound is theirs alone to hear: played into the world it meant everyone within earshot heard
	-- every bite taken out of everyone else. Fired only when the damage actually landed, so a blow that armor
	-- ate, a respawn blinked away, or that hit a player already crawling makes no noise.
	-- Player-on-player blows are deliberately not routed this way -- a fight is worth overhearing.
	"HurtSound",
	-- Admin console: the command text in, the reply out. AdminCommand is guarded by a UserId allow-list on
	-- the SERVER, so a non-admin firing it is refused exactly as if they had never found it.
	"AdminCommand", "AdminMessage",
	-- Flight is driven on the CLIENT because the character physics belongs to it; the server only says
	-- whether an admin may fly, which is the part that has to be trusted.
	"AdminFly",
	-- Social (the speaking stone): the client asks and the server answers. Every inbound one is validated
	-- server-side -- amounts, names and lengths are never trusted as sent.
	"RequestSocialData", "SocialUpdate", "SocialNotify",
	"RequestGuildPost", "GuildPostAdded", -- the board, plus a push for the floating feed
	"RequestFriendAction", "RequestPigeonMessage", "PigeonMessage",
	"RequestBankAction",
	"RequestShowCard", "CardStateChanged", -- profile card raised over a player, seen by everyone nearby
	"RequestCall", "CallStateChanged", -- telepathy: ring, answer, decline, hang up (UI only, no audio yet)
	-- ปาร์ตี้: คำขอเข้ามาทางเดียว (ชวน/รับ/ปฏิเสธ/ออก) · สถานะออกไปให้ทุกคนในตี้พร้อมเลือด-ความหิวของกันและกัน
	-- · คำเชิญยิงถึงคนที่ถูกชวนคนเดียว หน้าต่างถาม "ตกลงไหม" จึงขึ้นได้แม้หินสื่อสารปิดอยู่
	"RequestPartyAction", "PartyStateChanged", "PartyInvite",
	-- The shopkeeper. ShopOpen carries the whole price list down when a player walks up, so the client
	-- never computes a price and never has one to lie about; RequestShopAction is buy/sell by slot or id.
	"RequestShopOpen", "ShopOpen", "RequestShopAction",
	-- The blacksmith. CraftOpen carries the whole recipe list down along with how much of each material the
	-- player already has, so the client never counts a bag and never has a cost to lie about; RequestCraft
	-- names nothing but a position in that list.
	-- CraftStarted tells the client to run its progress bar and for how long; CraftFinished says whether the
	-- attempt worked. Both are needed because the swing takes a couple of seconds and the roll happens at
	-- the END of it, so the window cannot know the outcome when the button is pressed.
	"RequestCraftOpen", "CraftOpen", "RequestCraft", "CraftStarted", "CraftFinished", "RequestEnhance",
	-- ท่าทำงานที่เตา/เครื่องปั่น/เครื่องต้มยา ยิงหาทุกคนเหมือน ConsumeStateChanged ไม่ใช่เฉพาะคนคราฟ:
	-- คนที่เดินผ่านครัวต้องเห็นว่ามีคนกำลังคนหม้ออยู่ ไม่ใช่เห็นคนยืนเฉยๆ หน้าเตาที่มีไฟลุก
	-- (player, station | nil = หยุด, seconds, stationPosition)
	"CraftPoseChanged",
	-- Gathering: the server draws the [F] prompt on a node and fires this to tell the client to toggle its
	-- own auto-farm loop. The loop lives on the client because it drives the local character's movement.
	"ToggleAutoFarm",
	-- The banker-and-warehouse NPC. Shaped exactly like the shop: the server pushes a whole picture of the
	-- purse, the bag and the vault, and the client names a row in it. No amount the client sends is believed
	-- without being clamped against what the server can see.
	"RequestVaultOpen", "VaultOpen", "RequestVaultAction",
	-- The minigames (V1). One pair for both of them: the server decides that a minigame should happen and
	-- describes it, the client plays it and reports the single bit that came out. The server never takes the
	-- client's word for anything but that bit -- what the attempt was worth, and whether it was allowed at
	-- all, were both decided before MinigameStart was ever sent.
	"MinigameStart", "MinigameFinish",
	-- Repairing a transformer during the blackout: the thirty-second hold, and everything that ends it.
	"RepairStateChanged",
	-- World events. One event in, one out: the banner at the top of the screen is driven entirely by these,
	-- and a player joining mid-event is sent the live ones as they load in.
	"EventStateChanged", "RequestEventState",
	-- Treasure chests. The server holds the rolled loot and sends a picture of it; the client names a row to
	-- take, or asks for everything. Shaped like the vault rather than the shop because the contents are a
	-- one-off pile that exists only while the window is open -- closing it destroys the chest and the loot
	-- with it, so there is nothing to reconcile afterwards.
	"RequestChestOpen", "ChestOpen", "RequestChestTake", "RequestChestClose", "ChestClose",
	-- หีบเก็บของในเมือง คนละอย่างกับหีบสมบัติข้างบน: อันนั้นเปิดครั้งเดียวได้ของแล้วหาย อันนี้เป็น
	-- ที่เก็บของสาธารณะที่ใครยัดอะไรไว้คนอื่นก็เห็น ของในหีบเป็นสถานะร่วม จึงส่งภาพทั้งใบทุกครั้งที่
	-- มีอะไรเปลี่ยน ให้ทุกคนที่เปิดอยู่เห็นตรงกัน
	-- สมุดสะสมและตารางอันดับในหินสื่อสาร ทั้งสองอ่านอย่างเดียว ไคลเอนต์ขอแล้วเซิร์ฟเวอร์ส่งภาพทั้งชุด
	-- บอร์ดเควส: เซิร์ฟเวอร์ส่งภาพทั้งบอร์ด ไคลเอนต์ส่งกลับแค่ว่ากดอะไรกับงานไหน
	"QuestUpdate", "RequestQuestAction",
	-- แคลน: เซิร์ฟเวอร์ส่งภาพทั้งชุด (รายการแคลน + แคลนของเรา) ไคลเอนต์ส่งกลับแค่ว่ากดอะไร
	"ClanUpdate", "RequestClanAction",
	-- คลังเมือง: ของเมืองที่แคลนผู้ยึดใช้ร่วมกัน เปิดด้วยปุ่ม F ที่อนุสาวรีย์ (คนละหน้าต่างกับคลังแคลน)
	-- สแนปช็อตมีทั้งของในคลังและ log 10 รายการล่าสุด ไคลเอนต์ไม่เคยคำนวณอะไรเอง
	"RequestTownVault", "TownVaultUpdate",
	-- พ่อค้าประจำเมือง: รับซื้อเฉพาะของถิ่นนั้น คนในแคลนเจ้าของเมืองได้ราคาดีกว่า
	"TownBuyerUpdate", "RequestTownSell",
	-- ร้านพรีเมียม/กาชา/แบทเทิลพาส: ภาพเดียวส่งกลับทุกครั้งที่กดอะไร และการติดตั้ง/ถอดสกิน
	"PremiumUpdate", "RequestPremium", "RequestSkin",
	-- ปิดหน้าคราฟ: เซิร์ฟเวอร์จะได้ลืมว่ายืนอยู่สถานีไหน
	"RequestCraftClose",
	"RequestCollection", "CollectionUpdate", "RequestTitle", "GlobalAnnounce",
	"RequestLeaderboards", "LeaderboardUpdate",
	"StorageChestOpen", "StorageChestUpdate",
	"RequestStorageChestPut", "RequestStorageChestTake", "RequestStorageChestClose",
	-- The admin panel (F3). One request in, one whole picture out -- the same shape as the shop and the
	-- vault, and for the same reason: the client names a row and an action, never a value the server would
	-- have to believe. Every handler re-checks the roster, because a RemoteEvent is reachable by anyone.
	"RequestAdminPanel", "AdminPanelData", "RequestAdminAction",
	-- The town sign's Discord invite. One direction: the server says "show them the panel", and the address
	-- itself lives in SocialConfig where the client can read it -- nothing about it is secret.
	"ShowDiscord",
	-- Weather. One way only: the server decides what the sky is doing and the client draws it. Carries the
	-- kind now, the kind arriving, and how far along the change is -- everything else the client reads out
	-- of the shared WeatherConfig rather than being told.
	"WeatherChanged",
	-- เกาะฟาร์ม: วาง (slot, cx, cz, r) เข้า → ตอบกลับทางเดียวกัน (ok, remaining) · เก็บ (uid) เข้า
	-- IslandMove: ย้าย/หมุนของที่วางแล้ว (uid, cx, cz, r) เข้า → ตอบ (ok) ทางเดียวกัน (โหมดจัดเกาะมุมสูง)
	"IslandPlace", "IslandPickup", "IslandMove",
	-- IslandPetDrop: คนอุ้มหมา/แมวสั่งวางลง (ปุ่ม E/F บนตัวสัตว์ถูกปิดระหว่างอุ้ม จึงต้องมีทางของตัวเอง)
	"IslandPetDrop",
	-- IslandPetHearts: ลูบหัวสำเร็จ → ทุกเครื่องวาดหัวใจลอยจากตัวสัตว์เอง (ลื่นกว่าให้เซิร์ฟเวอร์ขยับของ)
	"IslandPetHearts",
	-- คอกสัตว์บนเกาะ: เซิร์ฟเวอร์ส่งภาพรวมทั้งก้อน (IslandPenOpen) ไคลเอนต์ตอบแค่ "ซื้อชนิดนี้ n ตัว"
	-- IslandPenClose: ไคลเอนต์บอกว่าปิดหน้าต่างแล้ว เซิร์ฟเวอร์จะได้เลิกส่งภาพใหม่ทุก 3 วิ
	-- IslandPenRelease: ปล่อยฝูงทิ้งเพื่อเปลี่ยนชนิดสัตว์ที่เลี้ยง (คอกที่มีสัตว์อยู่เก็บคืนไม่ได้)
	"IslandPenOpen", "IslandPenBuy", "IslandPenClose", "IslandPenRelease",
	-- เฟส 2c รถส่งออก: เซิร์ฟเวอร์ส่งภาพรวมทั้งก้อน (ExportOpen · `open = true` เฉพาะตอนกด E) ไคลเอนต์ตอบแค่
	-- RequestExport(action, slot) — "ship" / "reroll" / "close" · ไม่เคยส่งของหรือราคา
	"ExportOpen", "RequestExport",
	-- ฉลองเลเวลฟาร์ม: เซิร์ฟ → { from, to } · ไคลเอนต์ → "ready" (จอโหลดจบ) / "seen", to (เห็นแบนเนอร์แล้ว)
	"FarmCelebrate",
	-- เลือกเมล็ด (มีเมล็ดมากกว่าหนึ่งชนิด): เซิร์ฟ → IslandSeedChoice(uid, ตัวเลือก) · ไคลเอนต์ → IslandPlantSeed(uid, seedId)
	-- ไคลเอนต์ → IslandSeedChoice("clear") = เลิกจำเมล็ดที่เลือกไว้ (ปุ่ม "เปลี่ยน")
	"IslandSeedChoice", "IslandPlantSeed",
	-- กล่องจดหมายในหินเวท: คำขอเดียวเข้า (op + อาร์กิวเมนต์) ภาพกล่องทั้งก้อนออก — ทรงเดียวกับตลาด/คลัง
	"RequestMail", "MailUpdate",
}
local FUNCTIONS = { "GetSpawnPosition" } -- DataStore-backed lookups can only run server-side; the client must ask

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if RunService:IsServer() then
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(EVENTS) do
		if not folder:FindFirstChild(name) then
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
	end
	for _, name in ipairs(FUNCTIONS) do
		if not folder:FindFirstChild(name) then
			local fn = Instance.new("RemoteFunction")
			fn.Name = name
			fn.Parent = folder
		end
	end
else
	folder = folder or ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}
for _, name in ipairs(EVENTS) do
	Remotes[name] = folder:WaitForChild(name)
end
for _, name in ipairs(FUNCTIONS) do
	Remotes[name] = folder:WaitForChild(name)
end
return Remotes
