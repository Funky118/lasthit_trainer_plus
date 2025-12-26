modifier_bonus_health = class({})
function modifier_bonus_health:GetAttributes()
	return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end
function modifier_bonus_health:IsHidden() return false end
function modifier_bonus_health:IsDebuff() return false end
function modifier_bonus_health:IsPurgable() return false end
function modifier_bonus_health:OnCreated(kv) 
	self.bonus_health = kv.bonus_health
end
function modifier_bonus_health:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_EXTRA_HEALTH_BONUS,
		}
	return funcs
end
function modifier_bonus_health:GetModifierExtraHealthBonus(params)
    return self.bonus_health
end