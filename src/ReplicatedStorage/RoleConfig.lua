-- RoleConfig: the roles a player can hold.
--
-- The abilities themselves are phase 4 (Guard restrain/search, Priest healing, Architect repair). This file
-- is only the vocabulary: what roles exist and what to call them, so the admin commands and the profile can
-- store a role now and the abilities can read it later without another migration.
local RoleConfig = {}

-- Keys are what is stored in the profile; `name` is what a player sees.
RoleConfig.Roles = {
	Guard = { name = "ทหารยาม" },
	Priest = { name = "นักบวช" },
	Architect = { name = "ช่างสร้าง" },
	Merchant = { name = "พ่อค้า" },
}

function RoleConfig.Exists(id)
	return RoleConfig.Roles[id] ~= nil
end

function RoleConfig.DisplayName(id)
	local role = RoleConfig.Roles[id]
	return role and role.name or id
end

-- Matches a role by name, case-insensitively and by prefix, so "/role guard" and "/role gu" both work. Nil
-- when the text matches nothing, or is ambiguous between two roles.
function RoleConfig.Match(text)
	if not text or text == "" then return nil end
	text = text:lower()
	local hit
	for id in pairs(RoleConfig.Roles) do
		if id:lower() == text then return id end -- an exact name always wins over a prefix
		if id:lower():sub(1, #text) == text then
			if hit then return nil end -- ambiguous
			hit = id
		end
	end
	return hit
end

return RoleConfig
