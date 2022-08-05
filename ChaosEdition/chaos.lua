print("TF2 Chaos Edition v0.5 or smth by Nerdicous (https://lmaobox.net/forum/v/profile/34539432/Nerdicous)")

--Do not change these values
local STATE_DAMAGE_SHARED <const> = 1
local STATE_RGB_MATERIALS <const> = 2
local STATE_RGB_MODELS <const> = 3
local STATE_INSANE_FOV <const> = 4
local STATE_LEFT_RIGHT_SWITCHED <const> = 5
local STATE_BACKWARDS_WALK <const> = 6
local STATE_ONLY_MELEE <const> = 7
local STATE_RANDOM_TAUNT <const> = 8
local STATE_SLOW_SPEED <const> = 9
local STATE_TAUNT_AFTER_KILL <const> = 10
local STATE_CONSTANT_SIDE_MOVEMENT <const> = 11
local STATE_NODRAW_SKYBOX <const> = 12
local STATE_LOWERED_COOLDOWN <const> = 13
local STATE_INCREASED_COOLDOWN <const> = 14

--Do not change these values
ChaosState = {}
ChaosState[STATE_DAMAGE_SHARED] = false			--Player shares damage dealt to the opponent
ChaosState[STATE_RGB_MATERIALS] = false			--Material recoloring
ChaosState[STATE_RGB_MODELS] = false			--Model recoloring
ChaosState[STATE_INSANE_FOV] = false			--Jitter around 110 FOV
ChaosState[STATE_LEFT_RIGHT_SWITCHED] = false		--Left/Right mouse buttons are switched
ChaosState[STATE_BACKWARDS_WALK] = false		--Player's movement is reversed
ChaosState[STATE_ONLY_MELEE] = false			--Player is forced to only use their melee weapon, but only when switching weapons
ChaosState[STATE_RANDOM_TAUNT] = false			--Player is forced to taunt, and the time to roll another effect is lowered by half
ChaosState[STATE_SLOW_SPEED] = false			--Player is forced to walk around slower
ChaosState[STATE_TAUNT_AFTER_KILL] = false		--Player taunts after killing someone
ChaosState[STATE_CONSTANT_SIDE_MOVEMENT] = false	--The player's side movement is always 1
ChaosState[STATE_NODRAW_SKYBOX] = false			--The skybox texture is set to not draw (results in smearing)
ChaosState[STATE_LOWERED_COOLDOWN] = false		--When true, decreases the cooldown by 3 seconds
ChaosState[STATE_INCREASED_COOLDOWN] = false		--When true, increases the cooldown by 3 seconds


local TimeBetweenActivations = 10
local TimeToNextRandomization = os.time() + TimeBetweenActivations
local DontUpdateState = false
local FinishedUpdateState = true	

local SavedFOVStates = {}
SavedFOVStates["enabled"] = gui.GetValue("enable custom fov")
SavedFOVStates["value"] = gui.GetValue("custom fov value")
local ChosenFOV = 0
local FOVIntensityLow = 1
local FOVIntensityHigh = 1

local accumulated_damage = 0 --Damage dealt to other people, for STATE_DAMAGE_SHARED

local DoingMaterialRainbowEffects = false --Variable for tracking when we exit/enter STATE_RGB_MATERIALS
local DoingTransparentEffects = false	--Same as above but for transparency

local TauntState = 0	--state for taunting

--Material helpers
local AllMaterials = {}
local SkyboxTextures = {}
local MaterialColorByIndex = {}
for _ModelIndex=1, 2048 do
	local NewVector = Vector3(math.random(), math.random(), math.random())

	--TODO: this is a placeholder for colors on models, they're handled differently
	--find a way to set a model's color value without changing the texture, or find out how to edit the texture
	local MaterialKeyValues = [["UnlitGeneric"
	{
		"$basetexture"	"vgui/white_additive"
		"$model"	1
		"$color2" "[ ]] .. tostring(NewVector.x) .. " " .. tostring(NewVector.y) .. " " .. tostring(NewVector.z) .. [[ ]"
		"$alpha"	0.5
		"$translucent"	1
	}]]
	
	local CreatedMaterial = materials.Find("_chaos_mat_color_override_" .. _ModelIndex)
	if CreatedMaterial == nil then
		CreatedMaterial = materials.Create("_chaos_mat_color_override_" .. _ModelIndex, MaterialKeyValues)
	end

	table.insert(MaterialColorByIndex, CreatedMaterial)
end

local function RandomizeAllMaterialColors()
	for i, Material in ipairs(AllMaterials) do
		Material:ColorModulate(math.random(), math.random(), math.random())
	end
end

local function ResetAllMaterialColors()
	for i, Material in ipairs(AllMaterials) do
		Material:ColorModulate(1, 1, 1)
	end
end

local function SetMaterialsTransparent()
	for i, Material in ipairs(SkyboxTextures) do
		Material:SetMaterialVarFlag(MATERIAL_VAR_NO_DRAW, true)
	end
end

local function SetMaterialsOpaque()
	for i, Material in ipairs(SkyboxTextures) do
		Material:SetMaterialVarFlag(MATERIAL_VAR_NO_DRAW, false)
	end
end

local function ClientKill(explode)
	if explode then client.Command("explode")
	else client.Command("kill")
	end
end

local function OnGameDraw()
	if DontUpdateState and FinishedUpdateState then return
	elseif DontUpdateState then
		DoingMaterialRainbowEffects = true
		DoingTransparentEffects = true
		for i=0, #ChaosState do
			ChaosState[i] = false
		end
	end

	if gamerules.GetRoundState() == 0 then
		DontUpdateState = true
		for i=1, #ChaosState do
			ChaosState[i] = false
		end
	else
		if os.time() > TimeToNextRandomization then
			TimeToNextRandomization = os.time() + TimeBetweenActivations
			--10% chance to disable all effects, because it takes a while sometimes for something to get disabled
			if math.random(1, 10) == 1 then for i=1, #ChaosState do ChaosState[i] = false end
			else
				ChaosState[math.random(1, #ChaosState)] = false
			end
		
			local ThisState = math.random(1, #ChaosState)
			ChaosState[ThisState] = not ChaosState[ThisState]

			TimeBetweenActivations = 2*(math.random()-0.5) + TimeBetweenActivations

			if ChaosState[STATE_LOWERED_COOLDOWN] then
				ChaosState[STATE_LOWERED_COOLDOWN] = false
				TimeBetweenActivations = TimeBetweenActivations - 3
			end
			if ChaosState[STATE_INCREASED_COOLDOWN] then
				ChaosState[STATE_INCREASED_COOLDOWN] = false
				TimeBetweenActivations = TimeBetweenActivations + 3
			end

			if TimeBetweenActivations <= 3 then TimeBetweenActivations = 15
			elseif TimeBetweenActivations >= 17 then TimeBetweenActivations = 4 end
		end
	end
	if ChaosState[STATE_RGB_MATERIALS] and not DoingMaterialRainbowEffects then
		DoingMaterialRainbowEffects = true
		RandomizeAllMaterialColors()
	end
	if  DoingMaterialRainbowEffects and not ChaosState[STATE_RGB_MATERIALS] then
		DoingMaterialRainbowEffects = false
		ResetAllMaterialColors()
	end
	
	if ChaosState[STATE_NODRAW_SKYBOX] and not DoingTransparentEffects then
		DoingTransparentEffects = true
		SetMaterialsTransparent()
	end
	if DoingTransparentEffects and not ChaosState[STATE_NODRAW_SKYBOX] then
		DoingTransparentEffects = false
		SetMaterialsOpaque()
	end
	if ChaosState[STATE_INSANE_FOV] then
		if ChosenFOV == 0 then
			ChosenFOV = math.random(75, 120)
			FOVIntensityLow = math.random(1, 3)
			FOVIntensityHigh = math.random(1, 3)
			SavedFOVStates["enabled"] = gui.GetValue("enable custom fov")
			SavedFOVStates["value"] = gui.GetValue("custom fov value")
		end
		gui.SetValue("enable custom fov", 1)
		gui.SetValue("custom fov value", math.random(-FOVIntensityLow, FOVIntensityHigh) + ChosenFOV)
	elseif ChosenFOV ~= 0 then
		ChosenFOV = 0
		gui.SetValue("enable custom fov", SavedFOVStates["enabled"])
		gui.SetValue("custom fov value", SavedFOVStates["value"])
	end

	FinishedUpdateState = true
end

local function OnModelDraw(Context)
	if not ChaosState[STATE_RGB_MODELS] then
		return
	end

	local Entity = Context:GetEntity()
	if Entity == nil then
		return
	end

	local ForcedMaterial = MaterialColorByIndex[Entity:GetIndex()]
	Context:ForcedMaterialOverride(ForcedMaterial)
end

local function OnMovement(UserCommand)
	if TauntState == 1 then client.Command("+taunt", true); TauntState = 0
	end

	local EndButtons = UserCommand:GetButtons()

	if ChaosState[STATE_LEFT_RIGHT_SWITCHED] then
		if EndButtons | IN_ATTACK == EndButtons then
			EndButtons = EndButtons & ~IN_ATTACK
			EndButtons = EndButtons | IN_ATTACK2
		elseif EndButtons | IN_ATTACK2 == EndButtons then
			EndButtons = EndButtons | IN_ATTACK
			EndButtons = EndButtons & ~IN_ATTACK2
		end
	end
	
	if ChaosState[STATE_ONLY_MELEE] and UserCommand.weaponselect ~= 0 then
		client.Command("slot3", true)
	end
	
	if ChaosState[STATE_SLOW_SPEED] then
		UserCommand:SetForwardMove(UserCommand:GetForwardMove()*0.5)
		UserCommand:SetSideMove(UserCommand:GetSideMove()*0.5)
		UserCommand:SetUpMove(UserCommand:GetUpMove()*0.5)
	end
	
	if ChaosState[STATE_CONSTANT_SIDE_MOVEMENT] then
		UserCommand:SetSideMove(1000)
	end
	
	if ChaosState[STATE_BACKWARDS_WALK] then
		UserCommand:SetForwardMove(-UserCommand:GetForwardMove())
		UserCommand:SetSideMove(-UserCommand:GetSideMove())
		UserCommand:SetUpMove(-UserCommand:GetUpMove())
	end

	if ChaosState[STATE_RANDOM_TAUNT] then
		ChaosState[STATE_RANDOM_TAUNT] = false
		TauntState = 1
		TimeToNextRandomization = TimeToNextRandomization - (TimeBetweenActivations*0.5)
	end
	
	UserCommand:SetButtons(EndButtons)
end

local function OnEventFire(GameEvent)
	if gamerules.GetRoundState() == 0 then
		DontUpdateState = true
		FinishedUpdateState = false
		return
	end
	DontUpdateState = false

	local EventName = GameEvent:GetName()
	local LocalPlayer = entities.GetLocalPlayer()
	if LocalPlayer == nil then
		DontUpdateState = true
		return
	end
	local LocalPlayerIndex = LocalPlayer:GetIndex()

	if EventName == "player_hurt" then
		local Victim = entities.GetByUserID(GameEvent:GetInt("userid"))
		local Attacker = entities.GetByUserID(GameEvent:GetInt("attacker"))
		
		if Attacker == nil then
			return
		end
		
		if ChaosState[STATE_DAMAGE_SHARED] and LocalPlayerIndex == Attacker:GetIndex() then
			accumulated_damage = accumulated_damage + GameEvent:GetInt("damageamount")
			if accumulated_damage >= LocalPlayer:GetHealth() then
				ClientKill(math.random(1, 100) == 1 or GameEvent:GetInt("crit") == 1)
			end
		end
	end
	
	if EventName == "player_death" then
		local WhoDied = entities.GetByUserID(GameEvent:GetInt("userid"))
		local Attacker = entities.GetByUserID(GameEvent:GetInt("attacker"))
		if LocalPlayerIndex == WhoDied:GetIndex() then
			accumulated_damage = 0
		end
		if LocalPlayerIndex == Attacker and ChaosState[STATE_TAUNT_AFTER_KILL] then
			ChaosState[STATE_TAUNT_AFTER_KILL] = false
			TauntState = 1
		end
	end
end

local function OnStringCmd(StringCommand)
	local Command = StringCommand:Get()
	if string.find(Command, "slot") then
		StringCommand:Set("slot3")
	end
end

local function OnScriptUnload()
	ResetAllMaterialColors()
	SetMaterialsOpaque()
	gui.SetValue("enable custom fov", SavedFOVStates["enabled"])
	gui.SetValue("custom fov value", SavedFOVStates["value"])
end

callbacks.Register("Draw", "ChaosEditionDraw", OnGameDraw)
callbacks.Register("DrawModel", "ChaosEditionDrawModel", OnModelDraw)
callbacks.Register("CreateMove", "ChaosEditionCreateMove", OnMovement)
callbacks.Register("FireGameEvent", "ChaosEditionFireGameEvent", OnEventFire)
callbacks.Register("SendStringCmd", "ChaosEditionStringCmd", OnStringCmd)
callbacks.Register("Unload", "ChaosEditionUnload", OnScriptUnload)


local function RegisterMaterialColors(MaterialType)
	table.insert(AllMaterials, MaterialType)
	if string.find(MaterialType:GetName(), "sky") then
		table.insert(SkyboxTextures, MaterialType)
	end
end
materials.Enumerate(RegisterMaterialColors)
