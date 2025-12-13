modifier_nemesis = class({})
function modifier_nemesis:GetAttributes()
	return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end
function modifier_nemesis:IsHidden() return false end
function modifier_nemesis:IsDebuff() return false end
function modifier_nemesis:IsPurgable() return false end
function modifier_nemesis:OnCreated(kv) 
	self.bonus_range_bonus = kv.bonus_range_bonus
    self.bonus_damage = kv.bonus_damage
	self.bonus_attack_speed = kv.bonus_attack_speed
	self.bonus_projectile_speed = kv.bonus_projectile_speed
	self.attack_point = kv.attack_point
	self.BAT = kv.BAT
end
function modifier_nemesis:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_ATTACK_RANGE_BONUS,
		MODIFIER_PROPERTY_BASEATTACK_BONUSDAMAGE,
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_PROJECTILE_SPEED_BONUS,
		MODIFIER_PROPERTY_ATTACK_POINT_CONSTANT,
		MODIFIER_PROPERTY_BASE_ATTACK_TIME_CONSTANT,
		}
	return funcs
end
function modifier_nemesis:GetModifierAttackRangeBonus(params)
    return self.bonus_range_bonus
end
function modifier_nemesis:GetModifierBaseAttack_BonusDamage(params)
    return self.bonus_damage
end
function modifier_nemesis:GetModifierAttackSpeedBonus_Constant(params)
	return self.bonus_attack_speed
end
function modifier_nemesis:GetModifierProjectileSpeedBonus(params)
	return self.bonus_projectile_speed
end
function modifier_nemesis:GetModifierAttackPointConstant(params)
	return self.attack_point
end
function modifier_nemesis:GetModifierBaseAttackTimeConstant(params)
	return self.BAT
end