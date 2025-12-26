modifier_creep_upgrade = class({})
function modifier_creep_upgrade:GetAttributes()
	return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end
function modifier_creep_upgrade:IsHidden() return false end
function modifier_creep_upgrade:IsDebuff() return false end
function modifier_creep_upgrade:IsPurgable() return false end
function modifier_creep_upgrade:OnCreated(kv) 
	self.bonus_health = kv.bonus_health
	self.bonus_damage = kv.bonus_damage
end
function modifier_creep_upgrade:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_EXTRA_HEALTH_BONUS,
		MODIFIER_PROPERTY_BASEATTACK_BONUSDAMAGE,
		}
	return funcs
end
function modifier_creep_upgrade:GetModifierExtraHealthBonus(params)
    return self.bonus_health
end
function modifier_creep_upgrade:GetModifierBaseAttack_BonusDamage(params)
    return self.bonus_damage
end
