local BUILDER, PART = pac.PartTemplate("base")

PART.ClassName = "health_modifier"

PART.Group = "combat"
PART.Icon = "icon16/heart.png"

BUILDER:StartStorableVars()
	BUILDER:GetSet("ActivateOnShow", true)
	BUILDER:GetSet("ActivateOnWear", true)

	BUILDER:SetPropertyGroup("Health")
		BUILDER:GetSet("ChangeHealth", false)
		BUILDER:GetSet("FollowHealth", true, {description = "whether changing the max health should try to set your health at the same time"})
		BUILDER:GetSet("MaxHealth", 100, {editor_onchange = function(self,num) return math.floor(math.Clamp(num,0,math.huge)) end})

	BUILDER:SetPropertyGroup("ExtraHpBars")
		BUILDER:GetSet("FollowHealthBars", true, {description = "whether changing the extra health bars should try to update them at the same time"})
		BUILDER:GetSet("HealthBars", 0, {editor_onchange = function(self,num) return math.floor(math.Clamp(num,0,100)) end, description = "Extra health bars taking damage before the main health.\nThey work as multiple bars for convenience. The total will be bars * amount."})
		BUILDER:GetSet("BarsAmount", 100, {editor_onchange = function(self,num) return math.floor(math.Clamp(num,0,math.huge)) end, description = "Extra health bars taking damage before the main health.\nThey work as multiple bars for convenience. The total will be bars * amount."})
		BUILDER:GetSet("BarsLayer", 1, {editor_onchange = function(self,num) return math.floor(math.Clamp(num,0,15)) end, description = "The layer decides which bars get damaged first. Outer layers are bigger numbers."})
		BUILDER:GetSet("AbsorbFactor", 0, {editor_onchange = function(self,num) return math.Clamp(num,-1,1) end, description = "How much damage to extra health bars should carry over to the main health. 1 is ineffective, 0 is normal, -1 is a healing conversion."})
		BUILDER:GetSet("HPBarsResetOnHide", false)
		BUILDER:GetSet("CountedHits", false, {description = "Instead of a quantity of HP points, make counted hits as a number.\nIt will spend 1 unit of the healthbar per hit."})
		BUILDER:GetSet("NoOverflow", false, {description = "When shield breaks, remaining damage will be forgiven.\nIt won't affect the main health or any remaining healthbar."})

	BUILDER:SetPropertyGroup("Armor")
		BUILDER:GetSet("ChangeArmor", false)
		BUILDER:GetSet("FollowArmor", true, {description = "whether changing the max armor should try to set your armor at the same time"})
		BUILDER:GetSet("MaxArmor", 100, {editor_onchange = function(self,num) return math.floor(math.Clamp(num,0,math.huge)) end})

	BUILDER:SetPropertyGroup("DamageMultipliers")
		BUILDER:GetSet("DamageMultiplier", 1, {description = "Damage multiplier to the hits you take. They stack but might not help with hardcoded addons that directly edit your HP or something."})
		BUILDER:GetSet("ModifierId", "", {description = "Putting an ID lets you update a damage multiplier from multiple health modifier parts so they don't stack, without using proxies."})
		BUILDER:GetSet("MultiplierResetOnHide", false)

BUILDER:EndStorableVars()

pac.healthmod_part_UID_caches = {}
--wait a minute can we just assume uids will be unique? what if people give each other pacs, the uids will be the same
local function register_UID(self, str, ply)
	pac.healthmod_part_UID_caches[ply] = pac.healthmod_part_UID_caches[ply] or {}
	pac.healthmod_part_UID_caches[ply][str] = self
end

function PART:GetNiceName()
	ply = self:GetPlayerOwner()
	local str = "health_modifier"

	if self.DamageMultiplier ~= 1 then
		str = str .. " [dmg " .. self.DamageMultiplier .. "x]"
	end

	if self.ChangeHealth then
		if ply:Health() ~= self.MaxHealth then
			str = str .. " [" .. ply:Health() .. " / " .. self.MaxHealth .. " health]"
		else
			str = str .. " [" .. self.MaxHealth .. " health]"
		end
	end

	if self.ChangeArmor then
		if ply:Armor() ~= self.MaxArmor then
			str = str .. " [" .. ply:Armor() .. " / " .. self.MaxArmor .. " armor]"
		else
			str = str .. " [" .. self.MaxArmor .. " armor]"
		end
	end

	if ply.pac_healthbars_uidtotals then
		if ply.pac_healthbars_uidtotals[self.UniqueID] then
			if self.HealthBars == 1 then
				str = str .. " [" .. ply.pac_healthbars_uidtotals[self.UniqueID] .. " / " .. self.BarsAmount .. " EX]"
			elseif self.HealthBars >= 1 then
				str = str .. " [" .. ply.pac_healthbars_uidtotals[self.UniqueID] .. " EX (" .. (self.healthbar_index or "0") .. " / " .. self.HealthBars .. ")]"
			end
		end
	end
	return str
end

function PART:SendModifier(str)
	--pac.healthmod_part_UID_caches[string.sub(self.UniqueID,1,8)] = self
	register_UID(self, string.sub(self.UniqueID,1,8), self:GetPlayerOwner())

	if self:IsHidden() then return end
	if LocalPlayer() ~= self:GetPlayerOwner() then return end
	if not GetConVar("pac_sv_health_modifier"):GetBool() then return end
	if util.NetworkStringToID( "pac_request_healthmod" ) == 0 then self:SetError("This part is deactivated on the server") return end
	pac.Blocked_Combat_Parts = pac.Blocked_Combat_Parts or {}
	if pac.Blocked_Combat_Parts then
		if pac.Blocked_Combat_Parts[self.ClassName] then return end
	end
	if not GetConVar("pac_sv_combat_enforce_netrate_monitor_serverside"):GetBool() then
		if not pac.CountNetMessage() then self:SetInfo("Went beyond the allowance") return end
	end
	--pac.healthmod_part_UID_caches[self.UniqueID] = self
	register_UID(self, self.UniqueID, self:GetPlayerOwner())
	if self.Name ~= "" then pac.healthmod_part_UID_caches[self.Name] = self end
	register_UID(self, self.Name, self:GetPlayerOwner())

	if str == "MaxHealth" and self.ChangeHealth then
		net.Start("pac_request_healthmod")
		net.WriteString(self.UniqueID)
		net.WriteString(self.ModifierId)
		net.WriteString("MaxHealth")
		net.WriteUInt(self.MaxHealth, 32)
		net.WriteBool(self.FollowHealth)
		net.SendToServer()
	elseif str == "MaxArmor" and self.ChangeArmor then
		net.Start("pac_request_healthmod")
		net.WriteString(self.UniqueID)
		net.WriteString(self.ModifierId)
		net.WriteString("MaxArmor")
		net.WriteUInt(self.MaxArmor, 32)
		net.WriteBool(self.FollowArmor)
		net.SendToServer()
	elseif str == "DamageMultiplier" then
		net.Start("pac_request_healthmod")
		net.WriteString(self.UniqueID)
		net.WriteString(self.ModifierId)
		net.WriteString("DamageMultiplier")
		net.WriteFloat(self.DamageMultiplier)
		net.WriteBool(true)
		net.SendToServer()
	elseif str == "HealthBars" then
		net.Start("pac_request_healthmod")
		net.WriteString(self.UniqueID)
		net.WriteString(self.ModifierId)
		net.WriteString("HealthBars")
		net.WriteUInt(self.HealthBars, 32)
		net.WriteUInt(self.BarsAmount, 32)
		net.WriteUInt(self.BarsLayer, 4)
		net.WriteFloat(self.AbsorbFactor)
		net.WriteBool(self.FollowHealthBars)
		net.WriteBool(self.CountedHits)
		net.WriteBool(self.NoOverflow)
		net.SendToServer()

	elseif str == "all" then
		self:SendModifier("MaxHealth")
		self:SendModifier("MaxArmor")
		self:SendModifier("DamageMultiplier")
		self:SendModifier("HealthBars")
	end
end

function PART:SetHealthBars(val)
	self.HealthBars = val
	if pac.LocalPlayer ~= self:GetPlayerOwner() then return end
	self:SendModifier("HealthBars")
end

function PART:SetBarsAmount(val)
	self.BarsAmount = val
	if pac.LocalPlayer ~= self:GetPlayerOwner() then return end
	self:SendModifier("HealthBars")
	self:UpdateHPBars()
end

function PART:SetBarsLayer(val)
	self.BarsLayer = val
	if pac.LocalPlayer ~= self:GetPlayerOwner() then return end
	self:SendModifier("HealthBars")
	self:UpdateHPBars()
end

function PART:SetAbsorbFactor(val)
	self.AbsorbFactor = val
	if pac.LocalPlayer ~= self:GetPlayerOwner() then return end
	self:SendModifier("HealthBars")
end

function PART:SetMaxHealth(val)
	self.MaxHealth = val
	if pac.LocalPlayer ~= self:GetPlayerOwner() then return end
	self:SendModifier("MaxHealth")
end

function PART:SetMaxArmor(val)
	self.MaxArmor = val
	if pac.LocalPlayer ~= self:GetPlayerOwner() then return end
	self:SendModifier("MaxArmor")
end

function PART:SetDamageMultiplier(val)
	self.DamageMultiplier = val
	if pac.LocalPlayer ~= self:GetPlayerOwner() then return end
	self:SendModifier("DamageMultiplier")
	local sv_min = GetConVar("pac_sv_health_modifier_min_damagescaling"):GetInt()
	if self.DamageMultiplier < sv_min then
		self:SetInfo("Your damage scaling is beyond the server's minimum permitted! Server minimum is " .. sv_min)
	else
		self:SetInfo(nil)
	end
end

function PART:OnRemove()
	--pac.healthmod_part_UID_caches = {} --we'll need this part removed from the cache
	register_UID(nil, string.sub(self.UniqueID,1,8), self:GetPlayerOwner())
	register_UID(nil, self.UniqueID, self:GetPlayerOwner())
	register_UID(nil, self.Name, self:GetPlayerOwner())

	if pac.LocalPlayer ~= self:GetPlayerOwner() then return end
	if util.NetworkStringToID( "pac_request_healthmod" ) == 0 then return end
	local found_remaining_healthmod = false
	for _,part in pairs(pac.GetLocalParts()) do
		if part.ClassName == "health_modifier" and part ~= self then
			found_remaining_healthmod = true
		end
	end
	net.Start("pac_request_healthmod")
	net.WriteString(self.UniqueID)
	net.WriteString(self.ModifierId)
	net.WriteString("OnRemove")
	net.WriteFloat(0)
	net.WriteBool(true)
	net.SendToServer()

	if not found_remaining_healthmod then
		net.Start("pac_request_healthmod")
		net.WriteString(self.UniqueID)
		net.WriteString(self.ModifierId)
		net.WriteString("MaxHealth")
		net.WriteUInt(100,32)
		net.WriteBool(true)
		net.SendToServer()

		net.Start("pac_request_healthmod")
		net.WriteString(self.UniqueID)
		net.WriteString(self.ModifierId)
		net.WriteString("MaxArmor")
		net.WriteUInt(100,32)
		net.WriteBool(false)
		net.SendToServer()
	end

	hook.Remove("HUDPaint", "extrahealth_total")
	hook.Remove("HUDPaint", "extrahealth_"..self.UniqueID)
	hook.Remove("HUDPaint", "extrahealth_layer_"..self.BarsLayer)
end

function PART:OnShow()
	if self.ActivateOnShow then self:SendModifier("all") end
end
function PART:OnWorn()
	if self.ActivateOnWear then self:SendModifier("all") end
end

function PART:OnHide()
	if util.NetworkStringToID( "pac_request_healthmod" ) == 0 then self:SetError("This part is deactivated on the server") return end
	if self.HPBarsResetOnHide then
		net.Start("pac_request_healthmod")
		net.WriteString(self.UniqueID)
		net.WriteString(self.ModifierId)
		net.WriteString("HealthBars")
		net.WriteUInt(0, 32)
		net.WriteUInt(0, 32)
		net.WriteUInt(self.BarsLayer, 4)
		net.WriteFloat(1)
		net.WriteBool(self.FollowHealthBars)
		net.SendToServer()
	end
	if self.MultiplierResetOnHide then
		net.Start("pac_request_healthmod")
		net.WriteString(self.UniqueID)
		net.WriteString(self.ModifierId)
		net.WriteString("DamageMultiplier")
		net.WriteFloat(1)
		net.WriteBool(true)
		net.SendToServer()
	end
end

function PART:Initialize()
	self.healthbar_index = 0
	--pac.healthmod_part_UID_caches[string.sub(self.UniqueID,1,8)] = self
	register_UID(nil, string.sub(self.UniqueID,1,8), self:GetPlayerOwner())
	if not GetConVar("pac_sv_health_modifier"):GetBool() or pac.Blocked_Combat_Parts[self.ClassName] then self:SetError("health modifiers are disabled on this server!") end
end

function PART:UpdateHPBars()
	local ent = self:GetPlayerOwner()
	if ent.pac_healthbars_uidtotals and ent.pac_healthbars_uidtotals[self.UniqueID] then
		self.healthbar_index = math.ceil(ent.pac_healthbars_uidtotals[self.UniqueID] / self.BarsAmount)
		if ent.pac_healthbars_uidtotals[self.UniqueID] then
			self:SetInfo("Extra healthbars:\nHP is " .. ent.pac_healthbars_uidtotals[self.UniqueID] .. "/" .. self.HealthBars * self.BarsAmount .. "\n" .. self.healthbar_index .. " of " .. self.HealthBars .. " bars")
		end
	end
end

--expected structure : pac_healthbars uid_or_name action number
--actions: set, add, subtract, refill, replenish, remove
concommand.Add("pac_healthbar", function(ply, cmd, args)
	local uid_or_name = args[1]
	local num = tonumber(args[3]) or 0
	pac.healthmod_part_UID_caches[ply] = pac.healthmod_part_UID_caches[ply] or {}
	if pac.healthmod_part_UID_caches[ply][uid_or_name] ~= nil and args[2] ~= nil then
		local part = pac.healthmod_part_UID_caches[ply][uid_or_name]
		uid = part.UniqueID
		local action = args[2] or ""

		--doesnt make sense to add or subtract 0
		if ((action == "add" or action == "subtract") and num == 0) or (action == "") then return end
		--replenish means set to full
		if action == "refill" or  action == "replenish" then
			action = "set"
			num = part.BarsAmount * part.HealthBars
		end
		if action == "remove" then action = "set" num = 0 end
		net.Start("pac_request_extrahealthbars_action")
		net.WriteString(uid)
		net.WriteString(action)
		net.WriteInt(num, 16)
		net.SendToServer()
	end
	if args[2] == nil then ply:PrintMessage(HUD_PRINTCONSOLE, "\nthis command needs at least two arguments.\nuid or name: the unique ID or the name of the part\naction: add, subtract, refill, replenish, remove, set\nnumber\n\nexample: pac_healthbar my_healthmod add 50\n") end
end, nil, "changes your health modifier's extra health value. arguments:\nuid or name: the unique ID or the name of the part\naction: add, subtract, refill, replenish, remove, set\nnumber\n\nexample: pac_healthbar my_healthmod add 50")

BUILDER:Register()