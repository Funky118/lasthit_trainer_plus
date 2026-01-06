-- This file contains all barebones-registered events and has already set up the passed-in parameters for you to use.
-- You should comment out or remove the stuff you don't need!

-- Handle stuff when a player disconnects
function barebones:OnDisconnect(keys)
	DebugPrint("[BAREBONES] A Player has disconnected")
	--PrintTable(keys)

	local name = keys.name
	local networkID = keys.networkid
	local reason = keys.reason
	local userID = keys.userid
	local playerID = keys.PlayerID
end

-- The overall game state has changed
function barebones:OnGameRulesStateChange(keys)
	--PrintTable(keys)

	local new_state = GameRules:State_Get()

	if new_state == DOTA_GAMERULES_STATE_INIT then
		DebugPrint("[BAREBONES] Game State changed to: DOTA_GAMERULES_STATE_INIT")

	elseif new_state == DOTA_GAMERULES_STATE_WAIT_FOR_PLAYERS_TO_LOAD then
		DebugPrint("[BAREBONES] Game State changed to: DOTA_GAMERULES_STATE_WAIT_FOR_PLAYERS_TO_LOAD")

	elseif new_state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
		DebugPrint("[BAREBONES] Game State changed to: DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP")
		GameRules:SetCustomGameSetupAutoLaunchDelay(CUSTOM_GAME_SETUP_TIME)

	elseif new_state == DOTA_GAMERULES_STATE_HERO_SELECTION then
		DebugPrint("[BAREBONES] Game State changed to: DOTA_GAMERULES_STATE_HERO_SELECTION")
		self:PostLoadPrecache()
		self:OnAllPlayersLoaded()

	elseif new_state == DOTA_GAMERULES_STATE_STRATEGY_TIME then
		DebugPrint("[BAREBONES] Game State changed to: DOTA_GAMERULES_STATE_STRATEGY_TIME")

		-- Force Random a hero for every player that didnt picked or randomed a hero 
		-- We do this as a failsafe so players don't end up without a hero
		for playerID = 0, DOTA_MAX_TEAM_PLAYERS-1 do
			if PlayerResource:IsValidPlayerID(playerID) and PlayerResource:IsValidPlayer(playerID) then
				-- If this player still hasn't picked a hero, random one
				-- PlayerResource:IsConnected(index) is custom-made! Can be found in 'player_resource.lua' library
				if not PlayerResource:HasSelectedHero(playerID) and PlayerResource:IsConnected(playerID) then
					PlayerResource:GetPlayer(playerID):MakeRandomHeroSelection() -- this will cause an error if player is disconnected, that's why we check if player is connected
					PlayerResource:SetHasRandomed(playerID)
					PlayerResource:SetCanRepick(playerID, false)
					DebugPrint("[BAREBONES] Randomed a hero for a player number "..playerID)
				end
			end
		end

	elseif new_state == DOTA_GAMERULES_STATE_TEAM_SHOWCASE then
		DebugPrint("[BAREBONES] Game State changed to: DOTA_GAMERULES_STATE_TEAM_SHOWCASE")

	elseif new_state == DOTA_GAMERULES_STATE_WAIT_FOR_MAP_TO_LOAD then
		DebugPrint("[BAREBONES] Game State changed to: DOTA_GAMERULES_STATE_WAIT_FOR_MAP_TO_LOAD")

	elseif new_state == DOTA_GAMERULES_STATE_PRE_GAME then
		DebugPrint("[BAREBONES] Game State changed to: DOTA_GAMERULES_STATE_PRE_GAME")
		local gamemode = GameRules:GetGameModeEntity()
		gamemode:SetCustomDireScore(0)
		gamemode:SetCustomRadiantScore(0)

	elseif new_state == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		DebugPrint("[BAREBONES] Game State changed to: DOTA_GAMERULES_STATE_GAME_IN_PROGRESS")
		self:OnGameInProgress()

	elseif new_state == DOTA_GAMERULES_STATE_POST_GAME then
		DebugPrint("[BAREBONES] Game State changed to: DOTA_GAMERULES_STATE_POST_GAME")

	elseif new_state == DOTA_GAMERULES_STATE_DISCONNECT then
		DebugPrint("[BAREBONES] Game State changed to: DOTA_GAMERULES_STATE_DISCONNECT")

	end
end

-- An NPC has spawned somewhere in game. This includes heroes
function barebones:OnNPCSpawned(keys)
	-- Non-barebones: Added zero experience and Nemesis spawning with the player
	local npc 
	if keys.entindex then
		npc = EntIndexToHScript(keys.entindex)
		local npc_name = npc:GetUnitName()
		if npc:GetClassname() == "npc_dota_creep_neutral" then
			table.insert(self.NeutralExpList, {id = npc, exp = npc:GetDeathXP()})
		end
		-- Radiant creeps never give experience
		if not self.ExperienceGainEnabled or npc_name == "npc_dota_creep_goodguys_melee" or npc_name == "npc_dota_creep_goodguys_ranged" or npc_name == "npc_dota_creep_goodguys_flagbearer" or npc_name == "npc_dota_goodguys_siege" then
			npc:SetDeathXP( 0 ) -- TODO: Add a variable to enable experience gain
		end
	else
		print("npc_spawned event doesn't have entindex key")
		return
	end

	-- This also spawns Nemesis
	-- And sends the creep wave (I used to do this in GameInit but on server the first wave wouldn't move)
	if not self.PlayerHero then
		if npc:IsRealHero() and npc:GetTeamNumber() == DOTA_TEAM_GOODGUYS then
			self.PlayerHero = npc
			self.HeroDamage = npc:GetAverageTrueAttackDamage(nil)
			local nemesis = "npc_dota_hero_sniper"
			PrecacheUnitByNameAsync(nemesis, function() self:SpawnNemesis(nemesis) end)
			self:SpawnLaneCreeps() -- The OnThink for this is in gamemode.lua

			local gamemode = GameRules:GetGameModeEntity()
			gamemode:SetThink( "OnNeutralThink", self, "NeutralsThink", 60 ) -- There's probably a better way to do this
		end
	end

	-- Put things here that will happen for every unit or hero when they spawn

	-- OnHeroInGame
	if npc:IsRealHero() and not npc.bFirstSpawned then
		npc.bFirstSpawned = true
		self:OnHeroInGame(npc)
	end
end

--[[
  Hero spawned for the first time. It can happen if the player's hero is replaced with a new hero for any reason.  
  This can be used for initializing heroes, such as adding levels, changing the starting gold, removing/adding abilities, adding physics, etc.
  This happens to bot and custom created heroes as well.
  The hero parameter is the hero entity that just spawned.
  
]]
function barebones:OnHeroInGame(hero)
	-- Innate abilities like Earth Spirit Stone Remnant (abilities that a hero needs to have auto-leveled up at the start of the game)
	-- Take a look at this guide: https://moddota.com/abilities/creating-innate-abilities
	local innate_abilities = {
		"innate_ability1",
		"innate_ability2"
	}

	-- Cycle through any innate abilities found, then set their level to 1
	for i = 1, #innate_abilities do
		local current_ability = hero:FindAbilityByName(innate_abilities[i])
		if current_ability then
			current_ability:SetLevel(1)
		end
	end

	Timers:CreateTimer(0.5, function()
		local playerID = hero:GetPlayerID()	-- never nil (-1 by default), needs delay 1 or more frames

		if PlayerResource:IsFakeClient(playerID) or playerID == nil or playerID == -1 then
			-- This is happening only for bots
			DebugPrint("[BAREBONES] OnHeroInGame - Bot hero "..hero:GetUnitName().." (re)spawned in the game.")
			-- Set starting gold for bots
			hero:SetGold(NORMAL_START_GOLD, false)
		else
			DebugPrint("[BAREBONES] OnHeroInGame running for a non-bot player!")
			-- if not PlayerResource.PlayerData[playerID] and PlayerResource:IsValidPlayerID(playerID) then
			-- 	PlayerResource:InitPlayerDataForID(playerID)
			-- end
			if hero:IsClone() then
				DebugPrint("[BAREBONES] OnHeroInGame - Spawned hero is a Meepo Clone")
				return
			elseif hero:IsTempestDouble() then
				DebugPrint("[BAREBONES] OnHeroInGame - Spawned hero is a Tempest Double")
				return
			elseif IsMonkeyKingCloneCustom(hero) then
				DebugPrint("[BAREBONES] OnHeroInGame - Spawned hero is a Monkey King soldier or invalid entity")
				return
			elseif hero:IsSpiritBearCustom() then
				DebugPrint("[BAREBONES] OnHeroInGame - Spawned hero is a Spirit Bear")
				return
			end
			-- Set some hero stuff on first spawn or on every spawn (custom or not)
			if PlayerResource.PlayerData[playerID].already_set_hero == true then
				-- This is happening only when players create new heroes or replace them
			else
				-- This is happening for players when their primary hero spawns for the first time
				DebugPrint("[BAREBONES] OnHeroInGame - Hero "..hero:GetUnitName().." spawned in the game for the first time for the player with ID: "..playerID)

				-- Make heroes briefly visible on spawn (to prevent bad fog of war interactions)
				hero:MakeVisibleToTeam(DOTA_TEAM_GOODGUYS, 0.5)
				hero:MakeVisibleToTeam(DOTA_TEAM_BADGUYS, 0.5)

				-- Set the starting gold for the player's hero 
				-- Use 'PlayerResource:ModifyGold(playerID, NORMAL_START_GOLD-600, false, 0)' if GameRules:SetStartingGold breaks again
				-- If the NORMAL_START_GOLD is less than 600, disable Strategy Time and use 'hero:SetGold(NORMAL_START_GOLD, false)' instead
				-- Why? Because OnHeroInGame is triggering during PreGame (after Strategy Time) and players can buy items during Strategy Time (starting gold will remain default 600)
				
				if ADDITIONAL_GPM then
					hero:AddNewModifier(hero, nil, "modifier_custom_passive_gold", {})
				end

				-- Create an item and add it to the player's hero, effectively ensuring they start with the item
				if ADD_ITEM_TO_HERO_ON_SPAWN then
					local item = CreateItem("item_example_item", hero, hero)
					hero:AddItem(item)
				end

				-- Make sure that stuff above will not happen again for the player if some other hero spawns
				-- for him for the first time during the game 
				PlayerResource.PlayerData[playerID].already_set_hero = true
				DebugPrint("[BAREBONES] OnHeroInGame - Hero "..hero:GetUnitName().." set for the player with ID: "..playerID)
			end
		end
	end)
end

-- An item was picked up off the ground
function barebones:OnItemPickedUp(keys)
	DebugPrint("[BAREBONES] OnItemPickedUp event")
	--PrintTable(keys)

	-- Find who picked up the item
	local unit_entity
	if keys.UnitEntitIndex then -- keys.UnitEntitIndex may be always nil
		unit_entity = EntIndexToHScript(keys.UnitEntitIndex)
	elseif keys.HeroEntityIndex then
		unit_entity = EntIndexToHScript(keys.HeroEntityIndex)
	end

	local item_entity
	if keys.ItemEntityIndex then
		item_entity = EntIndexToHScript(keys.ItemEntityIndex)
	end
	local playerID = keys.PlayerID
	local item_name = keys.itemname
end

-- A player has reconnected to the game. This function can be used to repaint Player-based particles or change state as necessary
function barebones:OnPlayerReconnect(keys)
	DebugPrint("[BAREBONES] A Player has reconnected.")
	--PrintTable(keys)

	local new_state = GameRules:State_Get()
	if new_state > DOTA_GAMERULES_STATE_HERO_SELECTION then
		local playerID = keys.PlayerID or keys.player_id

		if not playerID or not PlayerResource:IsValidPlayerID(playerID) then
			print("OnPlayerReconnect - Reconnected player ID isn't valid!")
		end

		if PlayerResource:HasSelectedHero(playerID) or PlayerResource:HasRandomed(playerID) then
			-- This playerID already had a hero before disconnect
		else
			-- PlayerResource:IsConnected(playerID) is custom-made; can be found in 'player_resource.lua' library
			if PlayerResource:IsConnected(playerID) and not PlayerResource:IsBroadcaster(playerID) then
				PlayerResource:GetPlayer(playerID):MakeRandomHeroSelection()
				PlayerResource:SetHasRandomed(playerID)
				PlayerResource:SetCanRepick(playerID, false)
				DebugPrint("[BAREBONES] OnPlayerReconnect - Randomed a hero for a player ID "..playerID.." that reconnected.")
			end
		end
	end
end

-- An ability was used by a player; Doesn't trigger on disconnected players.
function barebones:OnAbilityUsed(keys)
	--PrintTable(keys)

	local playerID = keys.PlayerID
	local ability_name = keys.abilityname

	-- If you need to adjust abilities before or during their cast, use Order Filter or modifier events, not this
end

-- A player leveled up an ability; Note: IT DOESN'T TRIGGER WHEN YOU USE SetLevel() ON THE ABILITY!
function barebones:OnPlayerLearnedAbility(keys)
	DebugPrint("[BAREBONES] OnPlayerLearnedAbility event")
	--PrintTable(keys)

	local player
	if keys.player then
		player = EntIndexToHScript(keys.player)
	end

	local ability_name = keys.abilityname

	local playerID
	if player then
		playerID = player:GetPlayerID()
	else
		playerID = keys.PlayerID
	end

	-- PlayerResource:GetBarebonesAssignedHero(index) is custom-made; can be found in 'player_resource.lua' library
	-- This could return a wrong hero if you change your hero often during gameplay
	local hero = PlayerResource:GetBarebonesAssignedHero(playerID)
end

-- A player leveled up
function barebones:OnPlayerLevelUp(keys)
	DebugPrint("[BAREBONES] OnPlayerLevelUp event")
	--PrintTable(keys)

	-- Non-barebones edit: Ensure Nemesis can keep up with hero
	self.NemesisHero:RemoveModifierByName("modifier_bonus_health")
	self.NemesisBonusHealth = self.NemesisBonusHealth + 150
	self.NemesisHero:AddNewModifier(self.NemesisHero, nil, "modifier_bonus_health", {bonus_health = self.NemesisBonusHealth})
	Timers:CreateTimer(0.5, function ()
		self.HeroDamage = self.PlayerHero:GetAverageTrueAttackDamage(nil)
		self:NemesisAddAttackModifier(self.NemesisHero:GetUnitName())
	end)

	local level = keys.level
	local playerID = keys.player_id or keys.PlayerID

	local hero 
	if keys.hero_entindex then
		hero = EntIndexToHScript(keys.hero_entindex)
	else
		hero = PlayerResource:GetBarebonesAssignedHero(playerID)
	end

	if hero then
		-- Update hero gold bounty when a hero gains a level
		if USE_CUSTOM_HERO_GOLD_BOUNTY then
			local hero_level = hero:GetLevel() or level
			local hero_streak = hero:GetStreak()

			local gold_bounty
			if hero_streak > 2 then
				gold_bounty = HERO_KILL_GOLD_BASE + hero_level*HERO_KILL_GOLD_PER_LEVEL + (hero_streak-2)*HERO_KILL_GOLD_PER_STREAK
			else
				gold_bounty = HERO_KILL_GOLD_BASE + hero_level*HERO_KILL_GOLD_PER_LEVEL
			end

			hero:SetMinimumGoldBounty(gold_bounty)
			hero:SetMaximumGoldBounty(gold_bounty)
		end

		-- Example how to add an extra skill point when a hero levels up
		--[[
		local levels_without_ability_point = {17, 19, 21, 22, 23, 24}	-- on this levels you should get a skill point (edit this if needed)
		for i = 1, #levels_without_ability_point do
			if level == levels_without_ability_point[i] then
				local unspent_ability_points = hero:GetAbilityPoints()
				hero:SetAbilityPoints(unspent_ability_points + 1)
			end
		end
		]]

		-- If you want to remove skill points when a hero levels up then uncomment the following line:
		-- hero:SetAbilityPoints(0)
	end
end

-- A unit last hit a creep, a tower, or a hero
function barebones:OnLastHit(keys)
	-- Non-barebones: This function has been edited
	
	--print("Who got the lasthit: "..keys.PlayerID)
	local playerID = 0
	local player = PlayerResource:GetPlayer(playerID)
	-- Killed unit (creep, hero, tower etc.)
	local victim 
	if keys.EntKilled then
		victim = EntIndexToHScript(keys.EntKilled)
	else
		return
	end

	-- Traverse Nemesis' hitlist and check for creep type
	local tmpMelee = 0
	local tmpRanged = 0
	local tmpSiege = 0
	local tmpFlag = 0
	local delay_time = -1
	local attacker = 0 -- The unit which got the creep below HP threshold
	if victim:GetClassname() == "npc_dota_creep_lane" or victim:GetClassname() == "npc_dota_creep_siege" then
		-- Nemesis hit list update
		for k, v in pairs(self.LowHealthTargets) do
			if v[1] == victim then -- v contains [~, CreepID, TimeSinceLasthittable, HeroOrNot]
				table.remove(self.LowHealthTargets, k)
				-- If victim was his current target, set to nil
				if victim == self.CurrentTarget then
					self.CurrentTarget = nil
				end
				delay_time = Time() - v[2]
				attacker = v[3]
				break
			end
		end

		-- Score update tmps
		local victim_name = victim:GetName()
		if victim:GetClassname() == "npc_dota_creep_siege" then
			tmpSiege = 1
		elseif victim:IsRangedAttacker() then
			tmpMelee = 0
			tmpRanged = 1
		else
			tmpMelee = 1
			tmpRanged = 0
			if victim_name == "npc_dota_creep_goodguys_flagbearer" or victim_name == "npc_dota_creep_badguys_flagbearer" then
				tmpFlag = 1
			end
		end
	else
		return
	end

	-- If player 0 got the kill award cs/deny, otherwise missed cs/deny (PlayerID includes LD's bear - for now)
	-- Send results to Panorma for desplaying
	if keys.PlayerID == playerID then
		
		if player:GetTeamNumber() == victim:GetTeamNumber() then
			-- DENIES
			self.NetTableStats["DenyTotal"] = self.NetTableStats["DenyTotal"] + 1
			self.NetTableStats["DenyCount"] = self.NetTableStats["DenyCount"] + tmpMelee + tmpRanged + tmpSiege
			self.NetTableStats["MeleeCreepsDenied"] = self.NetTableStats["MeleeCreepsDenied"] + tmpMelee -- TODO: Will be used later
			self.NetTableStats["RangedCreepsDenied"] = self.NetTableStats["RangedCreepsDenied"] + tmpRanged	-- for gold/xp stats
			self.NetTableStats["SiegeCreepsDenied"] = self.NetTableStats["SiegeCreepsDenied"] + tmpSiege
			self.NetTableStats["FlagCreepsDenied"] = self.NetTableStats["FlagCreepsDenied"] + tmpFlag
			if delay_time ~= -1 then
				CustomGameEventManager:Send_ServerToAllClients("show_notification", {text="Deny delay: ", time=delay_time, killer="hero"})
				self.NetTableStats["CumLasthitTime"] = self.NetTableStats["CumLasthitTime"] + delay_time
			else
				CustomGameEventManager:Send_ServerToAllClients("show_notification", {text="Impossible cs", killer="other"})
			end
		else
			-- LASTHITS
			self.NetTableStats["LastHitTotal"] = self.NetTableStats["LastHitTotal"] + 1
			self.NetTableStats["LastHitCount"] = self.NetTableStats["LastHitCount"] + tmpMelee + tmpRanged + tmpSiege
			self.NetTableStats["MeleeCreepsKilled"] = self.NetTableStats["MeleeCreepsKilled"] + tmpMelee
			self.NetTableStats["RangedCreepsKilled"] = self.NetTableStats["RangedCreepsKilled"] + tmpRanged	
			self.NetTableStats["SiegeCreepsKilled"] = self.NetTableStats["SiegeCreepsKilled"] + tmpSiege
			self.NetTableStats["FlagCreepsKilled"] = self.NetTableStats["FlagCreepsKilled"] + tmpFlag
			if delay_time ~= -1 then
				CustomGameEventManager:Send_ServerToAllClients("show_notification", {text="Lasthit delay: ", time=delay_time, killer="hero"})
				self.NetTableStats["CumLasthitTime"] = self.NetTableStats["CumLasthitTime"] + delay_time
			else
				CustomGameEventManager:Send_ServerToAllClients("show_notification", {text="Impossible cs", killer="other"})
			end
		end
	else
		local popup_text = (attacker) and "Too early " or "Too late " -- Lil ternary operator magic (I'm suprised Lua has it)
		if player:GetTeamNumber() == victim:GetTeamNumber() then
			-- MISSED DENIES
			self.NetTableStats["DenyTotal"] = self.NetTableStats["DenyTotal"] + 1
			if delay_time ~= -1 then
				CustomGameEventManager:Send_ServerToAllClients("show_notification", {text=popup_text, time=delay_time, killer="other"})
			else
				CustomGameEventManager:Send_ServerToAllClients("show_notification", {text="Impossible cs", killer="other"})
			end
		else
			-- MISSED LASTHITS
			self.NetTableStats["LastHitTotal"] = self.NetTableStats["LastHitTotal"] + 1
			self.NetTableStats["MeleeCreepsBadguysMissed"] = self.NetTableStats["MeleeCreepsBadguysMissed"] + tmpMelee
			self.NetTableStats["RangedCreepsBadguysMissed"] = self.NetTableStats["RangedCreepsBadguysMissed"] + tmpRanged	
			self.NetTableStats["SiegeCreepsBadguysMissed"] = self.NetTableStats["SiegeCreepsBadguysMissed"] + tmpSiege
			self.NetTableStats["FlagCreepsBadguysMissed"] = self.NetTableStats["FlagCreepsBadguysMissed"] + tmpFlag
			if delay_time ~= -1 then
				CustomGameEventManager:Send_ServerToAllClients("show_notification", {text=popup_text, time=delay_time, killer="other"})
			else
				CustomGameEventManager:Send_ServerToAllClients("show_notification", {text="Impossible cs", killer="other"})
			end
		end
	end

	-- Update JS nettables
	self:SendStatisticsToClient()
end

-- A tree was cut down by tango, quelling blade, etc
function barebones:OnTreeCut(keys)
	DebugPrint("[BAREBONES] OnTreeCut event")
	--PrintTable(keys)

	-- Tree coordinates on the map
	local treeX = keys.tree_x
	local treeY = keys.tree_y
end

-- A rune was activated by a player
function barebones:OnRuneActivated(keys)
	DebugPrint("[BAREBONES] OnRuneActivated event")
	--PrintTable(keys)

  local playerID = keys.PlayerID
  local rune = keys.rune

  -- For Bounty Runes use BountyRuneFilter
  -- For modifying which runes spawn use RuneSpawnFilter (if it works)
  -- This event can be used for adding more effects to existing runes.
end

-- A player picked or randomed a hero, it actually happens on spawn (this is sometimes happening before OnHeroInGame).
function barebones:OnPlayerPickHero(keys)
	DebugPrint("[BAREBONES] OnPlayerPickHero event")
	--PrintTable(keys)

	local hero_name = keys.hero
	local hero_entity
	if keys.heroindex then
		hero_entity = EntIndexToHScript(keys.heroindex)
	end
	local player
	if keys.player then
		player = EntIndexToHScript(keys.player)
	end

	-- Timers:CreateTimer(0.5, function()
	-- 	if not hero_entity then
	-- 		return
	-- 	end
	-- 	local playerID = hero_entity:GetPlayerID() -- or player:GetPlayerID() if player is not disconnected
	-- 	if PlayerResource:IsFakeClient(playerID) then
	-- 		-- This is happening only for bots when they spawn for the first time or if they use custom hero-create spells (Custom Illusion spells)
	-- 	else
	-- 		if not PlayerResource.PlayerData[playerID] and PlayerResource:IsValidPlayerID(playerID) then
	-- 			PlayerResource:InitPlayerDataForID(playerID)
	-- 		end
	-- 		if PlayerResource.PlayerData[playerID].already_assigned_hero == true then
	-- 			-- This is happening only when players create new heroes or replacing heroes
	-- 			DebugPrint("[BAREBONES] OnPlayerPickHero - Player with playerID "..playerID.." got another hero: "..hero_entity:GetUnitName())
	-- 		else
	-- 			PlayerResource:AssignHero(playerID, hero_entity)
	-- 			PlayerResource.PlayerData[playerID].already_assigned_hero = true
	-- 		end
	-- 	end
	-- end)
end

-- An entity died (an entity killed an entity)
function barebones:OnEntityKilled(keys)
    --DebugPrint("[BAREBONES] An entity was killed.")
    --PrintTable(keys)

    -- Indexes:
    local killed_entity_index = keys.entindex_killed
    local attacker_entity_index = keys.entindex_attacker
    local inflictor_index = keys.entindex_inflictor -- it can be nil if not killed by an item/ability

    -- Find the entity that was killed
    local killed_unit
    if killed_entity_index then
      killed_unit = EntIndexToHScript(killed_entity_index)
    end

    -- Find the entity (killer) that killed the entity mentioned above
    local killer_unit
    if attacker_entity_index then
      killer_unit = EntIndexToHScript(attacker_entity_index)
    end

    if killed_unit == nil or killer_unit == nil then
      -- Don't continue if killer or killed entity doesn't exist
      return
    end

	-- Find the ability/item used to kill, or nil if not killed by an item/ability
    local killing_ability
    if inflictor_index then
      killing_ability = EntIndexToHScript(inflictor_index)
    end
	
	-- Non-barebones: When Nemesis gets the last hit show a little indication
	if killer_unit:IsRealHero() and killer_unit:GetPlayerID() == -1 then
			local gold = ParticleManager:CreateParticle("particles/generic_gameplay/lasthit_coins.vpcf", PATTACH_CUSTOMORIGIN, self)
			ParticleManager:SetParticleControl(gold, 0, killer_unit:GetAbsOrigin())
			ParticleManager:SetParticleControl(gold, 1, killer_unit:GetAbsOrigin())
			ParticleManager:SetParticleControl(gold, 3, killer_unit:GetAbsOrigin())
			ParticleManager:ReleaseParticleIndex(gold)
			local victim_name = killed_unit:GetUnitName()
			if victim_name == "npc_dota_creep_badguys_flagbearer" then
				self.NetTableStats["FlagCreepsLost"] = self.NetTableStats["FlagCreepsLost"] + 1
				self:SendStatisticsToClient()
			elseif victim_name == "npc_dota_creep_badguys_melee" then
				self.NetTableStats["MeleeCreepsLost"] = self.NetTableStats["MeleeCreepsLost"] + 1
				self:SendStatisticsToClient()
			elseif victim_name == "npc_dota_creep_badguys_ranged" then
				self.NetTableStats["RangedCreepsLost"] = self.NetTableStats["RangedCreepsLost"] + 1
				self:SendStatisticsToClient()
			elseif victim_name == "npc_dota_badguys_siege" then
				self.NetTableStats["SiegeCreepsLost"] = self.NetTableStats["SiegeCreepsLost"] + 1
				self:SendStatisticsToClient()
			end
			
	end

    -- For Meepo clones, find the original
    if killed_unit:IsClone() then
      if killed_unit.GetCloneSource and killed_unit:GetCloneSource() then
        killed_unit = killed_unit:GetCloneSource()
      end
    end

	-- Killed Unit is a hero (not an illusion) and he is not reincarnating
	if killed_unit:IsRealHero() and not killed_unit:IsTempestDouble() and not killed_unit:IsReincarnating() and not killed_unit:IsSpiritBearCustom() then
		-- Hero gold bounty update for the killer
		if USE_CUSTOM_HERO_GOLD_BOUNTY then
			if killer_unit:IsRealHero() and not killer_unit:IsSpiritBearCustom() and not killer_unit:IsTempestDouble() and not killer_unit:IsClone() and not IsMonkeyKingCloneCustom(killer_unit) then
				-- Get his killing streak
				local hero_streak = killer_unit:GetStreak()
				-- Get his level
				local hero_level = killer_unit:GetLevel()
				-- Adjust Gold bounty
				local gold_bounty
				if hero_streak > 2 then
					gold_bounty = HERO_KILL_GOLD_BASE + hero_level*HERO_KILL_GOLD_PER_LEVEL + (hero_streak-2)*HERO_KILL_GOLD_PER_STREAK
				else
					gold_bounty = HERO_KILL_GOLD_BASE + hero_level*HERO_KILL_GOLD_PER_LEVEL
				end

				killer_unit:SetMinimumGoldBounty(gold_bounty)
				killer_unit:SetMaximumGoldBounty(gold_bounty)
			end
		end

		-- Hero Respawn time configuration
		if ENABLE_HERO_RESPAWN then
			local killed_unit_level = killed_unit:GetLevel()

			-- Calculating respawn time without buyback penalty
			local respawn_time = 1
			if USE_CUSTOM_RESPAWN_TIMES then
				-- Get respawn time from the table that we defined
				respawn_time = CUSTOM_RESPAWN_TIME[killed_unit_level]
			else
				-- Get dota default respawn time
				respawn_time = killed_unit:GetRespawnTime()
				DebugPrint("[BAREBONES] OnEntityKilled - Default respawn time for "..killed_unit:GetUnitName().." is "..respawn_time.." seconds.")
			end

			-- Fixing respawn time after level 30, this is usually bugged in custom games if default respawn times are used -> respawn time are either too long or too short. We fix that.
			local respawn_time_after_30 = 100 + (killed_unit_level-30)*5
			if killed_unit_level > 30 and respawn_time ~= respawn_time_after_30 and not USE_CUSTOM_RESPAWN_TIMES then
				respawn_time = respawn_time_after_30
			end

			-- Killer is a neutral creep
			if killer_unit:IsNeutralUnitType() then
				-- If a hero is killed by a neutral creep, respawn time can be modified here
			end

			-- Capping Respawn Time (MAX respawn time)
			if respawn_time > MAX_RESPAWN_TIME then
				DebugPrint("[BAREBONES] OnEntityKilled - Reducing respawn time of "..killed_unit:GetUnitName().." because it was too long.")
				respawn_time = MAX_RESPAWN_TIME
			end

			-- If hero is actually reincarnating don't change his respawn time:
			if not killed_unit:IsReincarnating() then
				killed_unit:SetTimeUntilRespawn(respawn_time)
			end
		end

		-- Hero Buyback Cooldown
		if CUSTOM_BUYBACK_COOLDOWN_ENABLED then
			PlayerResource:SetCustomBuybackCooldown(killed_unit:GetPlayerID(), CUSTOM_BUYBACK_COOLDOWN_TIME)
		end

		-- Hero Buyback Gold Cost, you can replace BUYBACK_FIXED_GOLD_COST with your formula
		if CUSTOM_BUYBACK_COST_ENABLED then
			PlayerResource:SetCustomBuybackCost(killed_unit:GetPlayerID(), BUYBACK_FIXED_GOLD_COST)
		end

		-- Killer is not a real hero but it killed a hero; IsFountain() is custom-made, can be found in 'util.lua'
		if killer_unit:IsTower() or killer_unit:IsCreep() or killer_unit:IsFountain() then
			-- Put stuff here that you want to happen if a hero is killed by a creep, tower or fountain.
		end

		-- When team hero kill limit is reached declare the winner
		if END_GAME_ON_KILLS and GetTeamHeroKills(killer_unit:GetTeam()) >= KILLS_TO_END_GAME_FOR_TEAM then
			GameRules:SetGameWinner(killer_unit:GetTeam())
		end

		-- Setting top bar values
		if SHOW_KILLS_ON_TOPBAR then
			local gamemode = GameRules:GetGameModeEntity()
			--gamemode:SetTopBarTeamValue(DOTA_TEAM_BADGUYS, GetTeamHeroKills(DOTA_TEAM_BADGUYS))   -- Doesn't work since Diretide 2020
			--gamemode:SetTopBarTeamValue(DOTA_TEAM_GOODGUYS, GetTeamHeroKills(DOTA_TEAM_GOODGUYS)) -- Doesn't work since Diretide 2020
			gamemode:SetCustomRadiantScore(GetTeamHeroKills(DOTA_TEAM_GOODGUYS))
			gamemode:SetCustomDireScore(GetTeamHeroKills(DOTA_TEAM_BADGUYS))
		end
	end

	-- Ancient destruction detection (if the map doesn't have ancients with these names, this will never happen)
	if killed_unit:GetUnitName() == "npc_dota_badguys_fort" then
		GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS)
		GameRules:SetCustomVictoryMessage("#dota_post_game_radiant_victory")
		GameRules:SetCustomVictoryMessageDuration(POST_GAME_TIME)
	elseif killed_unit:GetUnitName() == "npc_dota_goodguys_fort" then
		GameRules:SetGameWinner(DOTA_TEAM_BADGUYS)
		GameRules:SetCustomVictoryMessage("#dota_post_game_dire_victory")
		GameRules:SetCustomVictoryMessageDuration(POST_GAME_TIME)
	end

	-- Remove dead non-hero units from selection -> fixing bugged ability/cast bar
	if killed_unit:IsIllusion() or (killed_unit:IsControllableByAnyPlayer() and not killed_unit:IsRealHero() and not killed_unit:IsCourier() and not killed_unit:IsClone() and not killed_unit:IsTempestDouble()) then
		local player = killed_unit:GetPlayerOwner()
		local playerID
		if not player then
			playerID = killed_unit:GetPlayerOwnerID()
		else
			playerID = player:GetPlayerID()
		end

		if Selection then
			-- Without Selection library this will return an error
			PlayerResource:RemoveFromSelection(playerID, killed_unit)
		end
	end
end

-- This function is called once when the player fully connects and becomes "Ready" during Loading
function barebones:OnConnectFull(keys)
	DebugPrint("[BAREBONES] A Player fully connected.")
	--PrintTable(keys)

	self:CaptureGameMode()

	-- PlayerResource:OnPlayerConnect(event) is custom-made; can be found in 'player_resource.lua' library
	PlayerResource:OnPlayerConnect(keys)
end

-- This function is called whenever a player changes their custom team selection during Custom Game Setup 
function barebones:OnPlayerSelectedCustomTeam(keys)
	DebugPrint("[BAREBONES] OnPlayerSelectedCustomTeam event")
	--PrintTable(keys)

	local playerID = keys.player_id
	local success = keys.success == 1
	local team = keys.team_id
end

-- This function is called whenever an NPC reaches its goal position/target (npc can be a lane creep, goal entity can be a path corner)
function barebones:OnNPCGoalReached(keys)
	--DebugPrint("[BAREBONES] OnNPCGoalReached")
	--PrintTable(keys)

	local goal_entity_index = keys.goal_entindex             -- Entity index of the next goal entity on the path (if any) which the npc will now be pathing towards
	local next_goal_entity_index = keys.next_goal_entindex   -- Entity index of the path goal entity which has been reached
	local npc_index = keys.npc_entindex                      -- Entity index of the npc which was following a path and has reached a goal entity

	local npc
	local goal_entity

	if npc_index and goal_entity_index then
		npc = EntIndexToHScript(npc_index)
		goal_entity = EntIndexToHScript(goal_entity_index)
	end

	local next_goal_entity
	if next_goal_entity_index then
		next_goal_entity = EntIndexToHScript(next_goal_entity_index)
	end

	if npc and goal_entity then
		-- Your code here
	end
end

-- This function is called whenever any player sends a chat message to team or to All
function barebones:OnPlayerChat(keys)
	DebugPrint("[BAREBONES] A Player has used the chat")
	--PrintTable(keys)

	local team_only = keys.teamonly == 1
	local userID = keys.userid
	local playerID = keys.playerid
	local text = keys.text
end

-- Non-barebones functions
function barebones:OnLeaveButtonPressed(keys)
	GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS)
	SendToServerConsole("disconnect")
end

function barebones:OnSwitchToNewHero(keys, data)
	-- Kill all creeps and erase nemesis' target list
	local creeps = self:FindAllCreeps(self.PlayerHero)
	for _,v in pairs(creeps) do
		v:ForceKill(false)
	end

	-- Precache the new hero and nemesis and call their spawning functions
	local nHeroID = tonumber( data.str )
	local sHeroClass = DOTAGameManager:GetHeroUnitNameByID( nHeroID )
	local nPlayerID = 0--self.PlayerHero:GetPlayerID()
	local nemesis = "npc_dota_hero_sniper"
	self.NemesisBonusHealth = 0

	PrecacheUnitByNameAsync( sHeroClass, function() self:AssignNewHero( sHeroClass, nPlayerID ) end, nPlayerID )
	PrecacheUnitByNameAsync(nemesis, function() self:SpawnNemesis(nemesis) end)

	-- Reset player state, statistics and wave time
	PlayerResource:SetGold(0, 600, false)
	PlayerResource:SetGold(0, 0, true)
	self:InitializeNetworkStats()
	self:SendStatisticsToClient()
	self:SpawnNeutralCreeps()
	self.LastWaveSpawnTime = -self.CreepSpawnInterval
	self.LaneUpgrade = 0
	self.CreepWavesSpawned = 0
	self.NeutralExpList = {}
	print("Hero: "..sHeroClass)
end

function barebones:SpawnNemesis(sHero)
	-- Destroy nemesis if it exists
	if self.NemesisHero ~= nil then
		if not self.NemesisHero:IsNull() then
			self:DontPanic(self.NemesisHero)
			self.NemesisHero:Destroy()
		end
	end

	-- Reset Nemesis' target and hitlist
	self.LowHealthTargets = {}
	self.CurrentTarget = nil
	
	-- Spawn enemy unit to contest last hits
	-- Regen and armor are set same as in Polygon, range and damage are set with a modifier (see gamemode.lua)
	self.NemesisHero = CreateUnitByName(sHero, self.NemesisSpawnPos, true, nil, nil, DOTA_TEAM_BADGUYS)
	self.NemesisHero:SetBaseHealthRegen(100)
	self.NemesisHero:SetPhysicalArmorBaseValue(50)
	self.NemesisHero:AddNewModifier(self.NemesisHero, nil, "modifier_bonus_health", {bonus_health = self.NemesisBonusHealth})

	
	Timers:CreateTimer(1, function ()
		self:NemesisAddAttackModifier(sHero)
		if self.NemesisUnfair then
			local tmp1 = ParticleManager:CreateParticle("particles/econ/events/ti10/high_five/towers/dire_tower_2021/high_five_dire_tower_2021_travel_fire.vpcf", PATTACH_OVERHEAD_FOLLOW, self.NemesisHero)
			local tmp2 = ParticleManager:CreateParticle("particles/units/heroes/hero_warlock/warlock_fatal_bonds_icon_skull.vpcf", PATTACH_OVERHEAD_FOLLOW, self.NemesisHero)
			local tmp3 = ParticleManager:CreateParticle("particles/econ/events/fall_2022/agh/agh_aura_fall2022_plus_lvl2.vpcf", PATTACH_ABSORIGIN_FOLLOW, self.NemesisHero)
			ParticleManager:SetParticleControl(tmp1, 0, self.NemesisHero:GetAbsOrigin())
			ParticleManager:SetParticleControl(tmp2, 0, self.NemesisHero:GetAbsOrigin())
			ParticleManager:SetParticleControl(tmp3, 0, self.NemesisHero:GetAbsOrigin())
			ParticleManager:ReleaseParticleIndex(tmp1)
			ParticleManager:ReleaseParticleIndex(tmp2)
			ParticleManager:ReleaseParticleIndex(tmp3)
			self.NemesisHero:SetRenderColor(255,0,0)
		end
	end)
	self.NemesisHero:SetIdleAcquire(false)
	self.NemesisHero:SetThink("NemesisThink", self)
	self.NemesisHero:SetThink("NemesisMove", self, 1)
	self.NemesisHero:SetControllableByPlayer(0, false)
end

function barebones:NemesisAddAttackModifier(sHero)
	if self.NemesisHero:IsNull() then
		return
	end
	self.NemesisHero:RemoveModifierByName("modifier_nemesis")
	-- Set damage to be competetive with Hero
	local nemesis_damage = self.NemesisHero:GetAverageTrueAttackDamage(nil)
	local nemesis_bonus_damage = self.HeroDamage - nemesis_damage
	local nemesis_bonus_projectile_speed = 0
	local nemesis_bonus_attack_range = 0
	self.NemesisDamage = nemesis_damage + nemesis_bonus_damage
	if sHero == "npc_dota_hero_sniper" then
		nemesis_bonus_projectile_speed = self.NemesisBonusProjectileSpeed
		nemesis_bonus_attack_range = self.NemesisBonusAttackRange
		self.NemesisNotSniper = false
	end
	if not self.NemesisUnfair then
		CustomGameEventManager:Send_ServerToAllClients("update_nemesis_attack_speed", {attack_speed = self.NemesisBonusAttackSpeed})
		self.NemesisHero:AddNewModifier(self.NemesisHero, nil, "modifier_nemesis", { bonus_range_bonus = nemesis_bonus_attack_range,
																					bonus_damage = nemesis_bonus_damage,
																					bonus_attack_speed = self.NemesisBonusAttackSpeed,
																					bonus_projectile_speed = nemesis_bonus_projectile_speed,
																					-- attack_point = 0,
																					--BAT = 1,
																				})
	else
		self.NemesisHero:AddNewModifier(self.NemesisHero, nil, "modifier_nemesis", { bonus_range_bonus = self.NemesisBonusAttackRange,
																		bonus_damage = nemesis_bonus_damage,
																		bonus_attack_speed = 5000,
																		bonus_projectile_speed = 15000,
																		-- attack_point = 0,
																		BAT = 1,
																	})
	end
end

function barebones:NemesisThink()
	-- Looks for the oldest target on hitlist and executes attack order
	for k, v in pairs(self.LowHealthTargets) do
		if self.CurrentTarget == nil then
			self.CurrentTarget = v[1]
			ExecuteOrderFromTable({
				UnitIndex = self.NemesisHero:entindex(),
				OrderType = DOTA_UNIT_ORDER_ATTACK_TARGET,
				TargetIndex = self.CurrentTarget:entindex()
			})
			--DebugDrawCircle(self.CurrentTarget:GetAbsOrigin(), Vector(0,0,255), 20, 20, true, 5) -- TODO: Add helper functions to highlight lasthittable creep and almost lasthittable creep
			print("Nemesis attacked at: "..(Time() - v[2]))
		elseif not self.NemesisHero:IsAttacking() then
			ExecuteOrderFromTable({
				UnitIndex = self.NemesisHero:entindex(),
				OrderType = DOTA_UNIT_ORDER_ATTACK_TARGET,
				TargetIndex = self.CurrentTarget:entindex()
			})
		end

	end
	return 0
end

function barebones:NemesisMove()
	-- Nemesis tries to stay const_distance range from the mean of positions of all creeps
	-- There is some asymetrical hysterisis in this range to vary the lasthit timing
	if self.NemesisHero == nil then
		return 1
	end
	local range = self.NemesisHero:GetBaseAttackRange()
	local is_ranged = self.NemesisHero:IsRangedAttacker()
	local too_close_range = (is_ranged) and (range-140) or 120
	too_close_range = (too_close_range < 120) and 120 or too_close_range
	if self.NemesisHero:GetUnitName() == "npc_dota_hero_sniper" then
		range = 600
	end
	local melee_too_close = self:FindEnemyCreeps(self.NemesisHero, too_close_range)
	local chicken_out = false

	for k,v in pairs(melee_too_close) do
		chicken_out = true
		break
	end
	if chicken_out == false then
		-- Special case for ranged creeps (siege creeps have higher range but are rare)
		local ranged_too_close = self:FindEnemyCreeps(self.NemesisHero, range)
		for k,v in pairs(ranged_too_close) do
			if v:IsRangedAttacker() then
				chicken_out = true
			end
			break
		end
	end

	-- Solo ranged creep check
	if chicken_out == false then
		local creeps = self:FindAllCreepsRadius(self.NemesisHero, 600)
		local melee_found = false
		local ranged_found = false
		for k,v in pairs(creeps) do
			if not v:IsRangedAttacker() then
				melee_found = true
				break
			elseif v:GetUnitName() == "npc_dota_creep_goodguys_ranged" then
				ranged_found = true
			end
		end
		chicken_out = not melee_found and ranged_found
	end
	

	local const_distance = range
	local hyst = 100
	if not self.NemesisHero:IsRangedAttacker() then
		hyst = 40
	end

	local creep_center = self:CreepsCenter()
	local new_pos = self.NemesisHero:GetAbsOrigin()
	local dist = VectorDistance(creep_center,new_pos)
	local rel_pos = VectorDistance(creep_center, self.DireMeeleePos) - VectorDistance(new_pos, self.DireMeeleePos)
	-- Fortunately the lane is on the diagonal of 1. and 3. quadrant, so direction is easy
	local away_from_center = (new_pos-creep_center):Normalized()
	local towards_center = (creep_center-new_pos):Normalized()
	if chicken_out or rel_pos <= 0 then
		-- bok bok 
		print("RUN AWAY!")
		new_pos = self.DireRangedPos
	elseif dist <= const_distance-hyst then
		new_pos = new_pos + (const_distance-dist) * away_from_center -- TODO:Bug here and in the other elseif, if center is behind sniper, he will run towards Hero
		new_pos.z = 0
	elseif dist >= const_distance+hyst*2 then
		new_pos = new_pos + (dist-const_distance) * towards_center
		new_pos.z = 0
	else
		-- Always face the creeps
		new_pos = new_pos + towards_center
		new_pos.z = 0
	end
	-- Don't interrupt an attack order from NemesisThink
	if not self.NemesisHero:IsAttacking() then
		ExecuteOrderFromTable({
			UnitIndex = self.NemesisHero:entindex(),
			OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
			Position = new_pos,
		})
	end
	--[[
		local color1=Vector(0,255,0)
		DebugDrawCircle(new_pos, color1, 20, 20, true, 5)
	--]]
	return 1
end

function barebones:CreepsCenter()
	-- Calculate waypoint for Nemesis, either middle of creep wave or inbetween towers
	local creeps = self:FindAllCreeps(self.NemesisHero)

	local center_of_gravity = 0
	local num_creeps = 0

	if next(creeps) ~= nil then
		for _,v in pairs(creeps) do
			if v:IsAlive() and not v:IsNeutralUnitType() then
				center_of_gravity = center_of_gravity + v:GetAbsOrigin()
				num_creeps = num_creeps + 1
			end
		end
		center_of_gravity = center_of_gravity/num_creeps
	else
		-- This shouldn't happen
		print("Creeps nil!")
		center_of_gravity = self.NemesisSpawnPos+self.HeroSpawnPos/2
	end

	if num_creeps <= 0 then
		center_of_gravity = self.NemesisSpawnPos+self.HeroSpawnPos/2 -- Set default to halfway between radiant and dire
	end
	--[[
	local color1=Vector(255,0,0)
	local color2=Vector(0,0,255)
	DebugDrawCircle(center_of_gravity, color1, 20, 20, true, 5)
	DebugDrawCircle(self.HeroSpawnPos, color2, 20, 20, true, 5)
	DebugDrawCircle(self.NemesisSpawnPos, color2, 20, 20, true, 5)
	--]]
	return center_of_gravity
end

function barebones:highlightUnit(ent)
	-- local highlight = ParticleManager:CreateParticle("particles/ui_mouseactions/range_finder_cp_color_creep_plus.vpcf", PATTACH_ABSORIGIN_FOLLOW, ent)
	-- ParticleManager:SetParticleControl( highlight, 6, Vector( 1,0,0 ) )
	-- ParticleManager:SetParticleControl(highlight, 7, ent:GetAbsOrigin())

	local highlight = ParticleManager:CreateParticle("particles/ui_mouseactions/ping_waypoint_vertical_energy_plus.vpcf", PATTACH_ABSORIGIN_FOLLOW, ent)
	ParticleManager:SetParticleControl(highlight, 0, ent:GetAbsOrigin())
	-- ParticleManager:SetParticleControl(highlight, 2, Vector(0,2,0)) -- First emission duration
	-- ParticleManager:SetParticleControl(highlight, 3, Vector(0,0,0)) -- Enabled x=0
	ParticleManager:SetParticleControl(highlight, 7, Vector(1,0,0)) -- Color RGB 0-1
	ParticleManager:SetParticleControl(highlight, 21, Vector(0,0,0)) -- Alpha x

	ParticleManager:ReleaseParticleIndex(highlight)
end

function barebones:OnRoundRestartButtonPressed(keys)
	print("Restart button pressed")
	self:RoundRestart()
end

function barebones:WriteRedTempNumber(iNum, ent)
	local ones_path = "particles/msg_fx/msg_lasthitcounter_ones_plus.vpcf"
	local tens_path = "particles/msg_fx/msg_lasthitcounter_tens_plus.vpcf"
	local hundreds_path = "particles/msg_fx/msg_lasthitcounter_hundreds_plus.vpcf"

	-- print(math.floor(iNum/100))
	-- print(math.floor((iNum%100)/10))
	-- print(math.floor(iNum%10))
	
	-- ONEDS AND HUNDREDS ARE SWAPPED HERE! I couldn't be bothered to figure out why, so I just kept it like this
	if math.floor(iNum/100) > 0 then
		local ones = ParticleManager:CreateParticle(ones_path, PATTACH_CUSTOMORIGIN, self)
		ParticleManager:SetParticleControl(ones, 3, ent:GetAbsOrigin() + Vector(0, 0,200))
		ParticleManager:SetParticleControl(ones, 1, Vector( 0, 0, math.floor(iNum/100))) -- This is actually hundreds
		ParticleManager:ReleaseParticleIndex(ones)
	end
	if math.floor(iNum/100) > 0 or math.floor((iNum%100)/10) > 0 then
		local tens = ParticleManager:CreateParticle(tens_path, PATTACH_CUSTOMORIGIN, self)
		ParticleManager:SetParticleControl(tens, 3, ent:GetAbsOrigin() + Vector(0, 0,200))
		ParticleManager:SetParticleControl(tens, 1, Vector( 0, math.floor((iNum%100)/10), 0))
		ParticleManager:ReleaseParticleIndex(tens)
	end
	local hundreds = ParticleManager:CreateParticle(hundreds_path, PATTACH_CUSTOMORIGIN, self)
	ParticleManager:SetParticleControl(hundreds, 3, ent:GetAbsOrigin() + Vector(0, 0,200))
	ParticleManager:SetParticleControl(hundreds, 1, Vector( math.floor(iNum%10), 0, 0)) -- This is actually ones
	ParticleManager:ReleaseParticleIndex(hundreds)
end
local a = 0
function barebones:RoundRestart()
	-- Spoof a new hero pick and just call the existing function
	local heroid = self.PlayerHero:GetHeroID()
	self:OnSwitchToNewHero(0, {str = tostring(heroid)})

	-- if a == 0  then
	-- 	self:FreezeTime()
	-- 	a = 1
	-- else
	-- 	self:UnFreezeTime()
	-- 	print("Unfreezing")
	-- 	a = 0
	-- end
end

function barebones:OnEntityHurt(keys)
	-- Calculate effective HP of the damaged creep and add it to Nemesis's list if below average Hero base damage
	local victim = EntIndexToHScript(keys.entindex_killed)
	local attacker = EntIndexToHScript(keys.entindex_attacker)

	if victim:GetClassname() == "npc_dota_creep_lane" then
		local victim_armor = victim:GetPhysicalArmorBaseValue()
		local armor_factor = 1-((0.06*victim_armor)/(1+0.06*math.abs(victim_armor)))
		local eHP = victim:GetHealth() / armor_factor
		if eHP <= (self.HeroDamage) then
			self:AddCreepToTable(victim, attacker:IsRealHero())
		end
	elseif victim:GetClassname() == "npc_dota_creep_siege" then
		local victim_armor = victim:GetPhysicalArmorBaseValue()
		local armor_factor = 1-((0.06*victim_armor)/(1+0.06*math.abs(victim_armor)))
		local eHP = victim:GetHealth() / armor_factor / 0.5 -- Reinforced unit
		if eHP <= (self.HeroDamage) then
			self:AddCreepToTable(victim, attacker:IsRealHero())
		end
	end
	
end

function barebones:AddCreepToTable(eCreep, isAttackerHero)
	-- Traverse LowHealthTargets of Nemesis and append new target and time if not present
	if self.LowHealthTargets ~= nil then
		for _, v in pairs(self.LowHealthTargets) do
			if v[1] == eCreep then
				return 0
			end
		end
	end
	if self.HighlightEnabled then
		self:highlightUnit(eCreep)
		-- One day I will figure out how mouseover highlights work for creeps!
		--DebugDrawSphere(eCreep:GetAbsOrigin() + Vector(0,0,100), Vector(255,0,0), 1, 10, true, 2)
		--eCreep:SetRenderColor(255,0,0)
	end
	local tmp = {eCreep, Time(), isAttackerHero}
	table.insert(self.LowHealthTargets, tmp)
	if self.NemesisUnfair or self.NemesisNotSniper then
		self:NemesisThink()
	end
	-- If creep fell below threshold HP by player's attack, it means the player attacked too early
	if isAttackerHero and eCreep:GetHealth() > 0 then
		self:WriteRedTempNumber(eCreep:GetHealth(), eCreep)
	end
end

-- Unused for now, for later error handling
function barebones:SanityCheck()
	if #(self.LowHealthTargets) > 20 then
		print("Way too many creeps in the LowHealthTargets table! "..#(self.LowHealthTargets))
	end
end

-- Handle some fun Destroy() and RemoveSelf() interactions
function barebones:DontPanic(ent)
	local old_hero_name = ent:GetUnitName()
	-- Brood web crash workaround
	if old_hero_name == "npc_dota_hero_broodmother" then
		local webs = Entities:FindAllByName("npc_dota_broodmother_web") --This literally breaks the game if not handled
		for k, web in pairs(webs) do
			if not web:IsNull() then
				web:RemoveSelf()
			end
		end
	elseif old_hero_name == "npc_dota_hero_meepo" then
		local meepers = Entities:FindAllByName("npc_dota_hero_meepo")
		for k, meep in pairs(meepers) do
			if not meep:IsNull() and meep ~= ent then
				meep:RemoveSelf()
			end
		end
	elseif old_hero_name == "npc_dota_hero_templar_assassin" then
		local traps = Entities:FindAllByName("npc_dota_templar_assassin_psionic_trap")
		for k, traps in pairs(traps) do
			if not traps:IsNull() then
				traps:RemoveSelf()
			end
		end
	end
end

function barebones:AssignNewHero(sHero, iPlayerID)
	--print("Assigning new hero!")
	local player = PlayerResource:GetPlayer(iPlayerID)
	local old_hero = player:GetAssignedHero()
	
	-- Get rid of old hero
	if not old_hero:IsNull() then
		self:DontPanic(old_hero)
		old_hero:Destroy()
	end
	

	-- This is the prefered easy way to replace a player's hero...
	local newHero = CreateHeroForPlayer(sHero, player)
	newHero:SetAbsOrigin(self.HeroSpawnPos)
	newHero:SetControllableByPlayer(iPlayerID, false)
	newHero:Hold()
	newHero:SetIdleAcquire(false)
	newHero:SetAcquisitionRange(0)
	player:SetAssignedHeroEntity(newHero)
	self.PlayerHero = newHero
	self.HeroDamage = newHero:GetAverageTrueAttackDamage(nil) -- TODO: Here it's possible that Nemesis will spawn before HeroDamage is updated

	-- ...alternatively use DebugCreateHeroWithVariant()

	-- -- Disconnect the substitude bot, if exists (it should have id = 1 but loop through a couple just to be sure)
	-- for i = 1, 5 do
	-- 	local id = PlayerResource:GetNthPlayerIDOnTeam(DOTA_TEAM_GOODGUYS, i)
	-- 	if id > 0 then
	-- 		DisconnectClient(id, true)
	-- 		print("Disconnected bot id: "..id)
	-- 	end
	-- end
	-- Now here comes the fun part. Let's create and assign a new hero!
	-- You are like a little baby, watch this!
	-- Timers:CreateTimer(0, function ()
	-- 	DebugCreateHeroWithVariant(player, sHero, 0, DOTA_TEAM_GOODGUYS, false,
	-- 		function(newHero)
	-- 			newHero:SetControllableByPlayer(iPlayerID, false)
	-- 			newHero:SetRespawnPosition(self.HeroSpawnPos)
	-- 			FindClearSpaceForUnit(newHero, self.HeroSpawnPos, false)
	-- 			newHero:Hold()
	-- 			newHero:SetIdleAcquire(false)
	-- 			newHero:SetAcquisitionRange(0)
	-- 			player:SetAssignedHeroEntity(newHero)
	-- 			print("Hero assigned!")
	-- 			-- local active_hero = player:GetAssignedHero()
	-- 			-- active_hero:SetAbsOrigin(self.HeroSpawnPos)
	-- 			-- active_hero:SetMoveCapability(1)
	-- 		end
	-- 		)
	-- end)
	-- Without this facets will occasionally crash the game :)
end


-- Just a creep spawner
function barebones:OnThink()
	if (GameRules:GetGameTime() >= (self.LastWaveSpawnTime + self.CreepSpawnInterval)) then
		self:SpawnLaneCreeps()
	end
	return 0.5
end

-- Neutrals spawner
function barebones:OnNeutralThink()
	self:SpawnNeutralCreeps()
	return 60
end

-- Send last hit statistics to be displayed in Panorama
function barebones:SendStatisticsToClient()
	CustomNetTables:SetTableValue( "last_hit_trainer_stats", "stats", self.NetTableStats )
end

function barebones:OnItemPurchased(keys) --TODO: Fix nemesis mode not updating damage
	-- HAHA! No cheating allowed! Nemesis now tracks Hero damage dynamically.
	self.HeroDamage = self.PlayerHero:GetAverageTrueAttackDamage(nil)
	self:NemesisAddAttackModifier(self.NemesisHero:GetUnitName())
end

function barebones:OnNemesisAttackSpeedChange(keys, data)
	if not self.NemesisUnfair then
		self.NemesisBonusAttackSpeed = 0+data.str -- Really? The INT variable is retyped to string, come on...
		self:NemesisAddAttackModifier(self.NemesisHero:GetUnitName())
	end
end

-- 
function barebones:OnHighlightCreepsButtonPressed(keys)
	if self.HighlightEnabled == true then
		self.HighlightEnabled = false
	else
		self.HighlightEnabled = true
	end
end

function barebones:OnEnableExperienceButtonPressed(keys)
	if self.ExperienceGainEnabled == true then
		self.ExperienceGainEnabled = false
		self:ZeroExpValues()
	else
		self.ExperienceGainEnabled = true
		self:ReturnExpValues()
	end
	

end

function barebones:ZeroExpValues()
	local creeps = self:FindEnemyCreeps(self.PlayerHero, 9999)
	self.NeutralExpList = {}
	for k,v in pairs(creeps) do
		if v:GetClassname() == "npc_dota_creep_neutral" then
			table.insert(self.NeutralExpList, {id = v, exp = v:GetDeathXP()})
		end
		v:SetDeathXP(0)
	end
end

function barebones:ReturnExpValues()
	local creeps = self:FindEnemyCreeps(self.PlayerHero, 9999)
	for k,v in pairs(creeps) do
		local name = v:GetClassname()
		if name == "npc_dota_creep_lane" then
			if v:IsRangedAttacker() then
				v:SetDeathXP(69) -- Nice!
			else
				v:SetDeathXP(57)
			end
		elseif name == "npc_dota_creep_siege" then
			v:SetDeathXP(88)
		end
	end
	for k,v in pairs(self.NeutralExpList) do
		if not v.id:IsNull() then
			v.id:SetDeathXP(v.exp)
		end
	end
	self.NeutralExpList = {}
end

function barebones:OnEnableUnfairButtonPressed(keys)
	if self.NemesisUnfair == true then
		self.NemesisUnfair = false
	else
		self.NemesisUnfair = true
	end
	self.CurrentTarget = nil
	local nemesis = "npc_dota_hero_sniper" -- TODO: Allow player to choose oppotent (including vanilla without modifier)
	PrecacheUnitByNameAsync(nemesis, function() self:SpawnNemesis(nemesis) end)
end

function barebones:OnSwitchToNewEnemyHero(keys, data)
	local nNemesisID = tonumber( data.str )
	local sNemesisClass = DOTAGameManager:GetHeroUnitNameByID( nNemesisID )

	-- Reset Nemesis' target and hitlist

	self.NemesisNotSniper = true -- Used to call NemesisThink a frame earlier
	-- Precache the new hero and nemesis and call their spawning functions
	PrecacheUnitByNameAsync(sNemesisClass, function() self:SpawnNemesis(sNemesisClass) end)

	print("Enemy: "..sNemesisClass)
end

function barebones:FreezeTime()
	SendToServerConsole("host_timescale 0.1")
end

function barebones:UnFreezeTime()
	SendToServerConsole("host_timescale 1")
end