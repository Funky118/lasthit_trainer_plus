-- This is the primary barebones gamemode script and should be used to assist in initializing your game mode
BAREBONES_VERSION = "2.1.1"

-- Selection library (by Noya) provides player selection inspection and management from server lua
require('libraries/selection')

-- settings.lua is where you can specify many different properties for your game mode and is one of the core barebones files.
require('settings')
-- events.lua is where you can specify the actions to be taken when any event occurs and is one of the core barebones files.
require('events')
-- filters.lua
require('filters')

if USE_CUSTOM_ROSHAN then
	require('components/roshan/init')
end

--[[
  This function should be used to set up Async precache calls at the beginning of the gameplay.

  In this function, place all of your PrecacheItemByNameAsync and PrecacheUnitByNameAsync.  These calls will be made
  after all players have loaded in, but before they have selected their heroes. PrecacheItemByNameAsync can also
  be used to precache dynamically-added datadriven abilities instead of items.  PrecacheUnitByNameAsync will
  precache the precache{} block statement of the unit and all precache{} block statements for every Ability#
  defined on the unit.

  This function should only be called once.  If you want to/need to precache more items/abilities/units at a later
  time, you can call the functions individually (for example if you want to precache units in a new wave of
  holdout).

  This function should generally only be used if the Precache() function in addon_game_mode.lua is not working.
]]
function barebones:PostLoadPrecache()
	DebugPrint("[BAREBONES] Performing Post-Load precache.")
	--PrecacheItemByNameAsync("item_example_item", function(...) end)
	--PrecacheItemByNameAsync("example_ability", function(...) end)

	--PrecacheUnitByNameAsync("npc_dota_hero_viper", function(...) end)
	--PrecacheUnitByNameAsync("npc_dota_hero_enigma", function(...) end)
end

--[[
  This function is called once and only once after all players have loaded into the game, right as the hero selection time begins.
  It can be used to initialize non-hero player state or adjust the hero selection (i.e. force random etc)
]]
function barebones:OnAllPlayersLoaded()
	DebugPrint("[BAREBONES] All Players have loaded into the game.")
end

--[[
  This function is called once and only once when the game completely begins (about 0:00 on the clock).  At this point,
  gold will begin to go up in ticks if configured, creeps will spawn, towers will become damageable etc.  This function
  is useful for starting any game logic timers/thinkers, beginning the first round, etc.
]]
function barebones:OnGameInProgress()
	DebugPrint("[BAREBONES] The game has officially begun.")

	-- If the day/night is not changed at 00:00, the following line is needed:
	GameRules:SetTimeOfDay(0.251)
end

-- This function initializes the game mode and is called before anyone loads into the game
-- It can be used to pre-initialize any values/tables that will be needed later
function barebones:InitGameMode()
	--Non-barebones: This has been edited but the edits are hopefully self-explenatory
	DebugPrint("[BAREBONES] Starting to load Game Rules.")

	-- This causes vectorws error messages
	LinkLuaModifier("modifier_nemesis", LUA_MODIFIER_MOTION_NONE )
	LinkLuaModifier("modifier_bonus_health", LUA_MODIFIER_MOTION_NONE )
	LinkLuaModifier("modifier_creep_upgrade", LUA_MODIFIER_MOTION_NONE )

	-- Hero spawn point
	local hero_spawn = Entities:FindByName(nil,"radiant_hero")
	local nemesis_spawn = Entities:FindByName(nil,"dire_nemesis")
	self.HeroSpawnPos = hero_spawn:GetAbsOrigin()
	self.NemesisSpawnPos = nemesis_spawn:GetAbsOrigin()
	-- HeroDamage plays role in Nemesis' last hitting logic
	self.HeroDamage = 40 -- Updates when Hero spawns but in case something goes wrong, this is a good default
	self.NemesisDamage = 40
	self.NemesisBonusAttackRange = 1000
	self.NemesisBonusAttackSpeed = 0
	self.NemesisBonusProjectileSpeed = 5000
	self.NemesisBonusHealth = 0
	self.NemesisUnfair = false
	self.NemesisNotSniper = false

	-- Starting positions of the creeps defined in Hammer
	local rms = Entities:FindByName(nil,"radiant_melee")
	local rrs = Entities:FindByName(nil,"radiant_ranged")
	local dms = Entities:FindByName(nil,"dire_melee")
	local drs = Entities:FindByName(nil,"dire_ranged")
	local nct = Entities:FindByName(nil,"neutral_camp_top")
	local ncb = Entities:FindByName(nil,"neutral_camp_bottom")
	local ncs = Entities:FindByName(nil,"neutral_camp_secret")

	self.RadiantMeeleePos = rms:GetOrigin()
	self.RadiantRangedPos = rrs:GetOrigin()
	self.DireMeeleePos = dms:GetOrigin()
	self.DireRangedPos = drs:GetOrigin()
	self.NeutralsTopPos = nct:GetOrigin()
	self.NeutralsBotPos = ncb:GetOrigin()
	self.NeutralsSecretPos = ncs:GetOrigin()

	-- Give towers health regen
	local towers = Entities:FindAllByClassname("npc_dota_tower")
	for _,v in pairs(towers) do
		v:SetBaseHealthRegen(100)
	end

	-- Colors for last hit particle (same as Valve's last hit trainer) TODO: UNUSED
	self.CSTier1 = Vector( 100, 250, 30 )
	self.CSTier2 = Vector( 180, 190, 30 )
	self.CSTier3 = Vector( 200, 170, 30 )
	self.CSTier4 = Vector( 220, 145, 30 )
	self.CSTier5 = Vector( 240, 110, 30 )
	self.CSTier6 = Vector( 250, 75, 30 )
	self.CSTier7 = Vector( 250, 45, 30 )
	self.CSTier8 = Vector( 250, 0, 30 )

	-- Counter initialization
	self.CreepSpawnInterval = 30
	self.LastWaveSpawnTime = -1 -- This is initialized -1 just like in Valve's code
	self.CreepWavesSpawned = 0
	self.MeleeCreepsSpawned = 0
	self.RangedCreepsSpawned = 0
	self.FlagbearerCreepsSpawned = 0
	self.SiegeCreepsSpawned = 0
	self.LaneUpgrade = 0
	self.LowHealthTargets = {}
	self.CurrentTarget = nil
	self.HighlightEnabled = false
	self.ExperienceGainEnabled = false
	self.NeutralExpList = {}


	-- Setup rules
	GameRules:SetSameHeroSelectionEnabled(ALLOW_SAME_HERO_SELECTION)
	GameRules:SetUseUniversalShopMode(UNIVERSAL_SHOP_MODE)
	GameRules:SetHeroRespawnEnabled(ENABLE_HERO_RESPAWN)

	GameRules:SetHeroSelectionTime(HERO_SELECTION_TIME) -- THIS IS IGNORED when "EnablePickRules" is "1" in 'addoninfo.txt' !
	GameRules:SetHeroSelectPenaltyTime(HERO_SELECTION_PENALTY_TIME)

	GameRules:SetCustomGameSetupTimeout( 0 ) -- FROM lasthit_trainer
	GameRules:SetPreGameTime(PRE_GAME_TIME)
	GameRules:SetPostGameTime(POST_GAME_TIME)
	GameRules:SetShowcaseTime(SHOWCASE_TIME)
	GameRules:SetStrategyTime(STRATEGY_TIME)

	GameRules:SetTreeRegrowTime(TREE_REGROW_TIME)

	if USE_CUSTOM_HERO_LEVELS then
		GameRules:SetUseCustomHeroXPValues(true)
	end

	--GameRules:SetGoldPerTick(GOLD_PER_TICK) -- Doesn't work; Last time tested: 24.2.2020
	--GameRules:SetGoldTickTime(GOLD_TICK_TIME) -- Doesn't work; Last time tested: 24.2.2020
	GameRules:SetStartingGold(NORMAL_START_GOLD)

	if USE_CUSTOM_HERO_GOLD_BOUNTY then
		GameRules:SetUseBaseGoldBountyOnHeroes(false) -- if true Heroes will use their default base gold bounty which is similar to creep gold bounty, rather than DOTA specific formulas
	end

	GameRules:SetHeroMinimapIconScale(MINIMAP_ICON_SIZE)
	GameRules:SetCreepMinimapIconScale(MINIMAP_CREEP_ICON_SIZE)
	GameRules:SetRuneMinimapIconScale(MINIMAP_RUNE_ICON_SIZE)
	GameRules:SetFirstBloodActive(ENABLE_FIRST_BLOOD)
	GameRules:SetHideKillMessageHeaders(HIDE_KILL_BANNERS)
	GameRules:LockCustomGameSetupTeamAssignment(LOCK_TEAMS)
	GameRules:FinishCustomGameSetup() -- We're done here, launch the game -- FROM lasthit_trainer

	-- This is multi-team configuration stuff
	if USE_AUTOMATIC_PLAYERS_PER_TEAM then
		local num = math.floor(10 / MAX_NUMBER_OF_TEAMS)
		local count = 0
		for team, number in pairs(TEAM_COLORS) do
			if count >= MAX_NUMBER_OF_TEAMS then
				GameRules:SetCustomGameTeamMaxPlayers(team, 0)
			else
				GameRules:SetCustomGameTeamMaxPlayers(team, num)
			end
			count = count + 1
		end
	else
		local count = 0
		for team, number in pairs(CUSTOM_TEAM_PLAYER_COUNT) do
			if count >= MAX_NUMBER_OF_TEAMS then
				GameRules:SetCustomGameTeamMaxPlayers(team, 0)
			else
				GameRules:SetCustomGameTeamMaxPlayers(team, number)
			end
			count = count + 1
		end
	end

	if USE_CUSTOM_TEAM_COLORS then
		for team, color in pairs(TEAM_COLORS) do
			SetTeamCustomHealthbarColor(team, color[1], color[2], color[3])
		end
	end

	DebugPrint("[BAREBONES] Done with setting Game Rules.")

	-- Event Hooks / Listeners
	DebugPrint("[BAREBONES] Setting Event Hooks / Listeners.")
	ListenToGameEvent('dota_player_gained_level', Dynamic_Wrap(barebones, 'OnPlayerLevelUp'), self)
	ListenToGameEvent('dota_player_learned_ability', Dynamic_Wrap(barebones, 'OnPlayerLearnedAbility'), self)
	ListenToGameEvent('entity_killed', Dynamic_Wrap(barebones, 'OnEntityKilled'), self)
	ListenToGameEvent('player_connect_full', Dynamic_Wrap(barebones, 'OnConnectFull'), self)
	ListenToGameEvent('player_disconnect', Dynamic_Wrap(barebones, 'OnDisconnect'), self)
	ListenToGameEvent('dota_item_picked_up', Dynamic_Wrap(barebones, 'OnItemPickedUp'), self)
	ListenToGameEvent('last_hit', Dynamic_Wrap(barebones, 'OnLastHit'), self)
	ListenToGameEvent('dota_rune_activated_server', Dynamic_Wrap(barebones, 'OnRuneActivated'), self)
	ListenToGameEvent('tree_cut', Dynamic_Wrap(barebones, 'OnTreeCut'), self)
	ListenToGameEvent('entity_hurt', Dynamic_Wrap(barebones, 'OnEntityHurt'), self)

	ListenToGameEvent('dota_player_used_ability', Dynamic_Wrap(barebones, 'OnAbilityUsed'), self)
	ListenToGameEvent('game_rules_state_change', Dynamic_Wrap(barebones, 'OnGameRulesStateChange'), self)
	ListenToGameEvent('npc_spawned', Dynamic_Wrap(barebones, 'OnNPCSpawned'), self)
	ListenToGameEvent('dota_player_pick_hero', Dynamic_Wrap(barebones, 'OnPlayerPickHero'), self)
	ListenToGameEvent("player_reconnected", Dynamic_Wrap(barebones, 'OnPlayerReconnect'), self)
	ListenToGameEvent("player_chat", Dynamic_Wrap(barebones, 'OnPlayerChat'), self)

	ListenToGameEvent("dota_player_selected_custom_team", Dynamic_Wrap(barebones, 'OnPlayerSelectedCustomTeam'), self)
	ListenToGameEvent("dota_npc_goal_reached", Dynamic_Wrap(barebones, 'OnNPCGoalReached'), self)
	ListenToGameEvent("dota_item_purchased", Dynamic_Wrap(barebones, 'OnItemPurchased'), self)

	-- Panorama listeners
	CustomGameEventManager:RegisterListener( "LeaveButtonPressed", function(...) return self:OnLeaveButtonPressed( ... ) end )
	CustomGameEventManager:RegisterListener( "SwitchToNewHero", function(...) return self:OnSwitchToNewHero( ... ) end )
	CustomGameEventManager:RegisterListener( "SwitchToNewEnemyHero", function(...) return self:OnSwitchToNewEnemyHero( ... ) end )
	CustomGameEventManager:RegisterListener( "RoundRestartButtonPressed", function(...) return self:OnRoundRestartButtonPressed( ... ) end )
	CustomGameEventManager:RegisterListener( "NemesisAttackSpeedChange", function(...) return self:OnNemesisAttackSpeedChange( ... ) end )
	CustomGameEventManager:RegisterListener( "HighlightCreepsButtonPressed", function(...) return self:OnHighlightCreepsButtonPressed( ... ) end )
	CustomGameEventManager:RegisterListener( "EnableExperienceButtonPressed", function(...) return self:OnEnableExperienceButtonPressed( ... ) end )
	CustomGameEventManager:RegisterListener( "EnableUnfairButtonPressed", function(...) return self:OnEnableUnfairButtonPressed( ... ) end )

	-- Change random seed for math.random function
	local timeTxt = string.gsub(string.gsub(GetSystemTime(), ':', ''), '0','')
	local timeNumber = tonumber(timeTxt)
	if timeNumber then
		math.randomseed(timeNumber) -- use 'RandomInt' or 'RandomFloat' instead of math.random
	end

	DebugPrint("[BAREBONES] Setting Filters.")

	local gamemode = GameRules:GetGameModeEntity()

	-- Setting the Order filter
	gamemode:SetExecuteOrderFilter(Dynamic_Wrap(barebones, "OrderFilter"), self)

	-- Setting the Damage filter
	gamemode:SetDamageFilter(Dynamic_Wrap(barebones, "DamageFilter"), self)

	-- Setting the Modifier filter
	gamemode:SetModifierGainedFilter(Dynamic_Wrap(barebones, "ModifierFilter"), self)

	-- Setting the Experience filter
	gamemode:SetModifyExperienceFilter(Dynamic_Wrap(barebones, "ExperienceFilter"), self)

	-- Setting the Tracking Projectile filter
	gamemode:SetTrackingProjectileFilter(Dynamic_Wrap(barebones, "ProjectileFilter"), self)

	-- Setting the bounty rune pickup filter
	gamemode:SetBountyRunePickupFilter(Dynamic_Wrap(barebones, "BountyRuneFilter"), self)

	-- Setting the Healing filter
	gamemode:SetHealingFilter(Dynamic_Wrap(barebones, "HealingFilter"), self)

	-- Setting the Gold Filter
	gamemode:SetModifyGoldFilter(Dynamic_Wrap(barebones, "GoldFilter"), self)

	-- Setting the Inventory filter
	gamemode:SetItemAddedToInventoryFilter(Dynamic_Wrap(barebones, "InventoryFilter"), self)

	DebugPrint("[BAREBONES] Done with setting Filters.")

	-- Global Lua Modifiers
	LinkLuaModifier("modifier_custom_invulnerable", "modifiers/modifier_custom_invulnerable.lua", LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("modifier_custom_passive_gold", "modifiers/modifier_custom_passive_gold_example.lua", LUA_MODIFIER_MOTION_NONE)

	print("[BAREBONES] initialized.")
	DebugPrint("[BAREBONES] Done loading the game mode!\n\n")

	-- Increase/decrease maximum item limit per hero
	Convars:SetInt('dota_max_physical_items_purchase_limit', 64)

	-- Spawn a global shop
	SpawnDOTAShopTriggerRadiusApproximate(Vector(), 999999); 
	self:InitializeNetworkStats()
	self:InitNeutralCamps()
end

function barebones:InitializeNetworkStats()
	self.NetTableStats = {
		LastHitCount = 0, 
		LastHitTotal= 0,
		DenyCount= 0,
		DenyTotal= 0,
		CumLasthitTime= 0,
		MeleeCreepsKilled= 0,
		MeleeCreepsDenied= 0,
		MeleeCreepsBadguysMissed=0,
		MeleeCreepsLost=0,
		FlagCreepsKilled= 0,
		FlagCreepsDenied= 0,
		FlagCreepsBadguysMissed=0,
		FlagCreepsLost=0,
		RangedCreepsKilled= 0,
		RangedCreepsDenied= 0,
		RangedCreepsBadguysMissed=0,
		RangedCreepsLost=0,
		SiegeCreepsKilled = 0,
		SiegeCreepsDenied = 0,
		SiegeCreepsBadguysMissed = 0,
		SiegeCreepsLost = 0
	}
end

-- This function is called as the first player loads and sets up the game mode parameters
function barebones:CaptureGameMode()
	local gamemode = GameRules:GetGameModeEntity()

	--Non-barebones gamemode stuff
	gamemode:SetThink( "OnThink", self, "GlobalThink", 0.1 )

	-- Set GameMode parameters
	gamemode:SetRecommendedItemsDisabled(RECOMMENDED_BUILDS_DISABLED)
	gamemode:SetCameraDistanceOverride(CAMERA_DISTANCE_OVERRIDE)
	gamemode:SetBuybackEnabled(BUYBACK_ENABLED)
	gamemode:SetCustomBuybackCostEnabled(CUSTOM_BUYBACK_COST_ENABLED)
	gamemode:SetCustomBuybackCooldownEnabled(CUSTOM_BUYBACK_COOLDOWN_ENABLED)
	gamemode:SetTopBarTeamValuesOverride(USE_CUSTOM_TOP_BAR_VALUES) -- Probably does nothing, but I will leave it
	gamemode:SetTopBarTeamValuesVisible(TOP_BAR_VISIBLE)

	if USE_CUSTOM_XP_VALUES then
		gamemode:SetUseCustomHeroLevels(true)
		gamemode:SetCustomXPRequiredToReachNextLevel(XP_PER_LEVEL_TABLE)
	elseif MAX_LEVEL ~= 30 then
		gamemode:SetCustomHeroMaxLevel(MAX_LEVEL) -- this is not needed if SetCustomXPRequiredToReachNextLevel is used
	end

	gamemode:SetBotThinkingEnabled(USE_STANDARD_DOTA_BOT_THINKING)
	gamemode:SetTowerBackdoorProtectionEnabled(ENABLE_TOWER_BACKDOOR_PROTECTION)

	gamemode:SetFogOfWarDisabled(DISABLE_FOG_OF_WAR_ENTIRELY)
	gamemode:SetGoldSoundDisabled(DISABLE_GOLD_SOUNDS)
	--gamemode:SetRemoveIllusionsOnDeath(REMOVE_ILLUSIONS_ON_DEATH) -- Didnt work last time I tried

	gamemode:SetAlwaysShowPlayerInventory(SHOW_ONLY_PLAYER_INVENTORY)
	--gamemode:SetAlwaysShowPlayerNames(true) -- use this when you need to hide real hero names
	gamemode:SetAnnouncerDisabled(DISABLE_ANNOUNCER)

	if FORCE_PICKED_HERO then -- FORCE_PICKED_HERO must be a string name of an existing hero, or there will be a big fat error
		gamemode:SetCustomGameForceHero(FORCE_PICKED_HERO) -- THIS WILL NOT WORK when "EnablePickRules" is "1" in 'addoninfo.txt' !
	else
		gamemode:SetDraftingHeroPickSelectTimeOverride(HERO_SELECTION_TIME)
		gamemode:SetDraftingBanningTimeOverride(0)
		if ENABLE_BANNING_PHASE then
			gamemode:SetDraftingBanningTimeOverride(BANNING_PHASE_TIME)
			GameRules:SetCustomGameBansPerTeam(5)
		end
	end

	gamemode:SetFixedRespawnTime(FIXED_RESPAWN_TIME) -- FIXED_RESPAWN_TIME should be float
	gamemode:SetFountainConstantManaRegen(FOUNTAIN_CONSTANT_MANA_REGEN)
	gamemode:SetFountainPercentageHealthRegen(FOUNTAIN_PERCENTAGE_HEALTH_REGEN)
	gamemode:SetFountainPercentageManaRegen(FOUNTAIN_PERCENTAGE_MANA_REGEN)
	gamemode:SetLoseGoldOnDeath(LOSE_GOLD_ON_DEATH)
	gamemode:SetMaximumAttackSpeed(MAXIMUM_ATTACK_SPEED)
	gamemode:SetMinimumAttackSpeed(MINIMUM_ATTACK_SPEED)
	gamemode:SetStashPurchasingDisabled(DISABLE_STASH_PURCHASING)

	if USE_DEFAULT_RUNE_SYSTEM then
		gamemode:SetUseDefaultDOTARuneSpawnLogic(true)
	else
		-- Some runes are broken by Valve, RuneSpawnFilter also didn't work last time I tried
		for rune, spawn in pairs(ENABLED_RUNES) do
			gamemode:SetRuneEnabled(rune, spawn)
		end
		gamemode:SetBountyRuneSpawnInterval(BOUNTY_RUNE_SPAWN_INTERVAL)
		gamemode:SetPowerRuneSpawnInterval(POWER_RUNE_SPAWN_INTERVAL)
	end

	gamemode:SetUnseenFogOfWarEnabled(USE_UNSEEN_FOG_OF_WAR)
	gamemode:SetDaynightCycleDisabled(DISABLE_DAY_NIGHT_CYCLE)
	PlayerResource:SetCustomTeamAssignment( 0, DOTA_TEAM_GOODGUYS ) -- put player 0 on Radiant team -- FROM lasthit_trainer
	gamemode:SetKillingSpreeAnnouncerDisabled(DISABLE_KILLING_SPREE_ANNOUNCER)
	gamemode:SetStickyItemDisabled(DISABLE_STICKY_ITEM)
	gamemode:SetPauseEnabled(ENABLE_PAUSING)
	gamemode:SetCustomScanCooldown(CUSTOM_SCAN_COOLDOWN)
	gamemode:SetCustomGlyphCooldown(CUSTOM_GLYPH_COOLDOWN)
	gamemode:DisableHudFlip(FORCE_MINIMAP_ON_THE_LEFT)

	gamemode:SetFreeCourierModeEnabled(false) -- without this, passive GPM doesn't work, Thanks Valve
end

-- Non-barebones functions below:

-- Creep spawning function, I am using Timers to delay attack orders because otherwise they didn't go through at game start
function barebones:SpawnLaneCreeps()
	local spawn_delay = 0.5
	local meleeToSpawn = 3
	self.CreepWavesSpawned = self.CreepWavesSpawned + 1
	-- Lane upgrade every 7 minutes (real game does it 7:30 but whatever)
	if (self.CreepWavesSpawned % 15) == 0 then
		-- Let's keep this uncapped just for fun :P
		self.LaneUpgrade = self.LaneUpgrade + 1
	end

	-- Spawn flagbearers
	if self.CreepWavesSpawned >= 5 then
		if ((self.CreepWavesSpawned - 5) % 2) == 0 then
			local creep_flag_good = CreateUnitByName("npc_dota_creep_goodguys_flagbearer", self.RadiantMeeleePos, true, nil, nil, DOTA_TEAM_GOODGUYS)
			creep_flag_good:AddNewModifier(creep_flag_good, nil, "modifier_creep_upgrade", {bonus_health = 12*self.LaneUpgrade, bonus_damage = 1*self.LaneUpgrade})
			
			if creep_flag_good ~= nil then
				Timers:CreateTimer(spawn_delay, function ()
					ExecuteOrderFromTable({
					UnitIndex = creep_flag_good:entindex(),
					OrderType = DOTA_UNIT_ORDER_ATTACK_MOVE,
					Position = self.DireMeeleePos,
					Queue = true
				})
				end)
				self.FlagbearerCreepsSpawned = self.FlagbearerCreepsSpawned + 1
				--self.NetTableStats["FlagCreepsBadguysMissed"] = self.NetTableStats["FlagCreepsBadguysMissed"] + 1
			end
			local creep_flag_bad = CreateUnitByName("npc_dota_creep_badguys_flagbearer", self.DireMeeleePos, true, nil, nil, DOTA_TEAM_BADGUYS)
			creep_flag_bad:AddNewModifier(creep_flag_bad, nil, "modifier_creep_upgrade", {bonus_health = 12*self.LaneUpgrade, bonus_damage = 1*self.LaneUpgrade})
			if creep_flag_bad ~= nil then
				Timers:CreateTimer(spawn_delay, function ()
					ExecuteOrderFromTable({
					UnitIndex = creep_flag_bad:entindex(),
					OrderType = DOTA_UNIT_ORDER_ATTACK_MOVE,
					Position = self.RadiantMeeleePos,
					Queue = true
				})
				end)
				self.FlagbearerCreepsSpawned = self.FlagbearerCreepsSpawned + 1
				--self.NetTableStats["FlagCreepsBadguysMissed"] = self.NetTableStats["FlagCreepsBadguysMissed"] + 1
			end
			meleeToSpawn = meleeToSpawn - 1
		end
	end


	-- Spawn 3 melee radiant creeps and send them to attack dire spawn point
	for i = 1, meleeToSpawn do
		local creep_melee_good = CreateUnitByName("npc_dota_creep_goodguys_melee", self.RadiantMeeleePos, true, nil, nil, DOTA_TEAM_GOODGUYS)
		creep_melee_good:AddNewModifier(creep_melee_good, nil, "modifier_creep_upgrade", {bonus_health = 12*self.LaneUpgrade, bonus_damage = 1*self.LaneUpgrade})
		if creep_melee_good ~= nil then
			Timers:CreateTimer(spawn_delay, function ()
				ExecuteOrderFromTable({
				UnitIndex = creep_melee_good:entindex(),
				OrderType = DOTA_UNIT_ORDER_ATTACK_MOVE,
				Position = self.DireMeeleePos,
				Queue = true
			})
				
			end)

			self.MeleeCreepsSpawned = self.MeleeCreepsSpawned+ 1
			--self.NetTableStats["MeleeCreepsBadguysMissed"] = self.NetTableStats["MeleeCreepsBadguysMissed"] + 1
		end
	end

	-- Spawn 1 ranged randiant creep
	local creep_ranged_good = CreateUnitByName("npc_dota_creep_goodguys_ranged", self.RadiantRangedPos, true, nil, nil, DOTA_TEAM_GOODGUYS)
	creep_ranged_good:AddNewModifier(creep_ranged_good, nil, "modifier_creep_upgrade", {bonus_health = 12*self.LaneUpgrade, bonus_damage = 2*self.LaneUpgrade})
	if creep_ranged_good ~= nil then
		Timers:CreateTimer(spawn_delay, function ()
			ExecuteOrderFromTable({
			UnitIndex = creep_ranged_good:entindex(),
			OrderType = DOTA_UNIT_ORDER_ATTACK_MOVE,
			Position = self.DireMeeleePos,
			Queue = true
		})
			
		end)

		self.RangedCreepsSpawned = self.RangedCreepsSpawned	+ 1
		--self.NetTableStats["RangedCreepsBadguysMissed"] = self.NetTableStats["RangedCreepsBadguysMissed"] + 1
	end

	-- Spawn 3 melee dire creeps and send them to attack radiant spawn point
	for i = 1, meleeToSpawn do
		local creep_melee_bad = CreateUnitByName("npc_dota_creep_badguys_melee", self.DireMeeleePos, true, nil, nil, DOTA_TEAM_BADGUYS)
		creep_melee_bad:AddNewModifier(creep_melee_bad, nil, "modifier_creep_upgrade", {bonus_health = 12*self.LaneUpgrade, bonus_damage = 1*self.LaneUpgrade})
		if creep_melee_bad ~= nil then
			Timers:CreateTimer(1, function ()
				ExecuteOrderFromTable({
				UnitIndex = creep_melee_bad:entindex(),
				OrderType = DOTA_UNIT_ORDER_ATTACK_MOVE,
				Position = self.RadiantMeeleePos,
				Queue = true
			})
				
			end)

			self.MeleeCreepsSpawned = self.MeleeCreepsSpawned+ 1
			--self.NetTableStats["MeleeCreepsBadguysMissed"] = self.NetTableStats["MeleeCreepsBadguysMissed"] + 1
		end
	end

	-- Spawn 1 ranged dire creep
	local creep_ranged_bad = CreateUnitByName("npc_dota_creep_badguys_ranged", self.DireRangedPos, true, nil, nil, DOTA_TEAM_BADGUYS)
	creep_ranged_bad:AddNewModifier(creep_ranged_bad, nil, "modifier_creep_upgrade", {bonus_health = 12*self.LaneUpgrade, bonus_damage = 2*self.LaneUpgrade})
	if creep_ranged_bad ~= nil then
		Timers:CreateTimer(1, function ()
			ExecuteOrderFromTable({
			UnitIndex = creep_ranged_bad:entindex(),
			OrderType = DOTA_UNIT_ORDER_ATTACK_MOVE,
			Position = self.RadiantMeeleePos,
			Queue = true
		})
			
		end)

		self.RangedCreepsSpawned = self.RangedCreepsSpawned	+ 1
		--self.NetTableStats["RangedCreepsBadguysMissed"] = self.NetTableStats["RangedCreepsBadguysMissed"] + 1
	end

	-- Siege spawn
	if self.CreepWavesSpawned >= 11 then
		if ((self.CreepWavesSpawned - 11) % 10) == 0 then
			local creep_siege_good = CreateUnitByName("npc_dota_goodguys_siege", self.RadiantRangedPos, true, nil, nil, DOTA_TEAM_GOODGUYS)
			if creep_siege_good ~= nil then
				Timers:CreateTimer(spawn_delay, function ()
					ExecuteOrderFromTable({
					UnitIndex = creep_siege_good:entindex(),
					OrderType = DOTA_UNIT_ORDER_ATTACK_MOVE,
					Position = self.DireMeeleePos,
					Queue = true
				})
				end)
				self.SiegeCreepsSpawned = self.SiegeCreepsSpawned + 1
				--self.NetTableStats["SiegeCreepsBadguysMissed"] = self.NetTableStats["SiegeCreepsBadguysMissed"] + 1
			end
			local creep_siege_bad = CreateUnitByName("npc_dota_badguys_siege", self.DireRangedPos, true, nil, nil, DOTA_TEAM_BADGUYS)
			if creep_siege_bad ~= nil then
				Timers:CreateTimer(spawn_delay, function ()
					ExecuteOrderFromTable({
					UnitIndex = creep_siege_bad:entindex(),
					OrderType = DOTA_UNIT_ORDER_ATTACK_MOVE,
					Position = self.RadiantMeeleePos,
					Queue = true
				})
				end)
				self.SiegeCreepsSpawned = self.SiegeCreepsSpawned + 1
				--self.NetTableStats["SiegeCreepsBadguysMissed"] = self.NetTableStats["SiegeCreepsBadguysMissed"] + 1
			end
		end
	end

	self.LastWaveSpawnTime = GameRules:GetGameTime()
end

function barebones:InitNeutralCamps()
	self.small_camps = {	
		{
			"npc_dota_neutral_kobold",
			"npc_dota_neutral_kobold",
			"npc_dota_neutral_kobold",
			"npc_dota_neutral_kobold_tunneler",
			"npc_dota_neutral_kobold_taskmaster"
		},
		{
			"npc_dota_neutral_forest_troll_berserker",		--"Hill Troll Berserker"
			"npc_dota_neutral_forest_troll_berserker",		--"Hill Troll Berserker"
			"npc_dota_neutral_forest_troll_high_priest"		--"Hill Troll Priest"
		},
		{
			"npc_dota_neutral_forest_troll_berserker",		--"Hill Troll Berserker"
			"npc_dota_neutral_forest_troll_berserker",		--"Hill Troll Berserker"
			"npc_dota_neutral_kobold_taskmaster"
		},
		{
			"npc_dota_neutral_gnoll_assassin",				--"Vhoul Assassin"
			"npc_dota_neutral_gnoll_assassin",				--"Vhoul Assassin"
			"npc_dota_neutral_gnoll_assassin"				--"Vhoul Assassin"
		},
		{
			"npc_dota_neutral_ghost",						--"Ghost"
			"npc_dota_neutral_fel_beast",					--"Fell Spirit"
			"npc_dota_neutral_fel_beast"					--"Fell Spirit"
		},
		{
			"npc_dota_neutral_harpy_scout",					--"Harpy Scout"
			"npc_dota_neutral_harpy_scout",					--"Harpy Scout"
			"npc_dota_neutral_harpy_storm"					--"Harpy Stormcrafter"
		},
		{
			"npc_dota_neutral_tadpole",						--"Pollywog"
			"npc_dota_neutral_tadpole",						--"Pollywog"
			"npc_dota_neutral_tadpole"						--"Pollywog"
		}
	}
	self.medium_camps = {
		{
			"npc_dota_neutral_centaur_outrunner",			--"Centaur Courser"
			"npc_dota_neutral_centaur_khan"					--"Centaur Conqueror"
		},
		{
			"npc_dota_neutral_giant_wolf",					--"Giant Wolf"
			"npc_dota_neutral_alpha_wolf",					--"Alpha Wolf"
			"npc_dota_neutral_alpha_wolf"					--"Alpha Wolf"
		},
		{
			"npc_dota_neutral_satyr_soulstealer",			--"Satyr Mindstealer"
			"npc_dota_neutral_satyr_soulstealer",			--"Satyr Mindstealer"
			"npc_dota_neutral_satyr_trickster",				--"Satyr Banisher"
			"npc_dota_neutral_satyr_trickster"				--"Satyr Banisher"
		},
		{
			"npc_dota_neutral_ogre_magi",					--"Ogre Frostmage"
			"npc_dota_neutral_ogre_mauler",					--"Ogre Bruiser"
			"npc_dota_neutral_ogre_mauler"					--"Ogre Bruiser"
		},
		{
			"npc_dota_neutral_mud_golem",					--"Mud Golem"
			"npc_dota_neutral_mud_golem"					--"Mud Golem"
		},
		{
			"npc_dota_neutral_froglet_mage",				--"Marshmage Apprentice"
			"npc_dota_neutral_froglet",						--"Boglet"
			"npc_dota_neutral_froglet",						--"Boglet"
		},
		-- Redundant seventh element because other camps have seven elements, to cycle correctly
		{
			"npc_dota_neutral_centaur_outrunner",			--"Centaur Courser"
			"npc_dota_neutral_centaur_khan"					--"Centaur Conqueror"
		}
	}
	self.large_camps = {
		{
			"npc_dota_neutral_centaur_outrunner",			--"Centaur Courser"
			"npc_dota_neutral_centaur_outrunner",			--"Centaur Courser"
			"npc_dota_neutral_centaur_khan"					--"Centaur Conqueror"
		},
		{
			"npc_dota_neutral_satyr_soulstealer",			--"Satyr Mindstealer"
			"npc_dota_neutral_satyr_trickster",				--"Satyr Banisher"
			"npc_dota_neutral_satyr_hellcaller"				--"Satyr Tormenter"
		},
		{
			"npc_dota_neutral_polar_furbolg_champion",		--"Hellbear"
			"npc_dota_neutral_polar_furbolg_ursa_warrior"	--"Hellbear Smasher"
		},
		{
			"npc_dota_neutral_wildkin",						--"Wildwing"
			"npc_dota_neutral_wildkin",						--"Wildwing"
			"npc_dota_neutral_enraged_wildkin"				--"Wildwing Ripper"
		},
		{
			"npc_dota_neutral_dark_troll",					--"Hill Troll"
			"npc_dota_neutral_dark_troll",					--"Hill Troll"
			"npc_dota_neutral_dark_troll_warlord"			--"Dark Troll Summoner"
		},
		{
			"npc_dota_neutral_warpine_raider",				--"Warpine Raider"
			"npc_dota_neutral_warpine_raider"				--"Warpine Raider"
		},
		{
			"npc_dota_neutral_grown_frog",					--"Croaker"
			"npc_dota_neutral_grown_frog",					--"Croaker"
			"npc_dota_neutral_grown_frog_mage"				--"Marshmage"
		}
	}
	self.NeutralCampIdx = 1
end

function barebones:SpawnNeutralCreeps()
	local top_creeps = self:FindNeutrals(self.NeutralsTopPos, 400)
	local bot_creeps = self:FindNeutrals(self.NeutralsBotPos, 400)
	
	if next(top_creeps) == nil then
		for k, v in pairs(self.large_camps[self.NeutralCampIdx]) do
			CreateUnitByName(v, self.NeutralsTopPos, true, nil, nil, DOTA_TEAM_NEUTRALS)
		end
	end
	if next(bot_creeps) == nil then
		for k, v in pairs(self.medium_camps[self.NeutralCampIdx]) do
			CreateUnitByName(v, self.NeutralsBotPos, true, nil, nil, DOTA_TEAM_NEUTRALS)
		end
	end
	-- Old map compatibility (secret and bottom camps overlap)
	local sec_creeps = self:FindNeutrals(self.NeutralsSecretPos, 400)
	if next(sec_creeps) == nil then
		for k, v in pairs(self.small_camps[self.NeutralCampIdx]) do
			CreateUnitByName(v, self.NeutralsSecretPos, true, nil, nil, DOTA_TEAM_NEUTRALS)
		end
	end
	if self.NeutralCampIdx >= 7 then
		self.NeutralCampIdx = 1
	else
		self.NeutralCampIdx = self.NeutralCampIdx + 1
	end
end

function barebones:FindEnemyCreeps(eUnit, iRange)
	local ret = FindUnitsInRadius(
		eUnit:GetTeamNumber(),
		eUnit:GetAbsOrigin(),
		nil,
		iRange,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_CREEP,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)
	return ret
end

function barebones:FindFriendlyCreeps(eUnit)
	local ret = FindUnitsInRadius(
		eUnit:GetTeamNumber(),
		eUnit:GetAbsOrigin(),
		nil,
		9999,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY,
		DOTA_UNIT_TARGET_CREEP,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)
	return ret
end

function barebones:FindAllCreeps(eUnit)
	local ret = FindUnitsInRadius(
		eUnit:GetTeamNumber(),
		eUnit:GetAbsOrigin(),
		nil,
		9999,
		DOTA_UNIT_TARGET_TEAM_BOTH,
		DOTA_UNIT_TARGET_CREEP,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)
	return ret
end

function barebones:FindNeutrals(iLoc, iRadius)
	local ret = FindUnitsInRadius(
		DOTA_TEAM_NEUTRALS,
		iLoc,
		nil,
		iRadius,
		DOTA_UNIT_TARGET_TEAM_BOTH,
		DOTA_UNIT_TARGET_CREEP,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)
	return ret
end