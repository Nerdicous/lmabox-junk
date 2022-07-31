print("Rhythm Time Attacking script created by Nerdicous (https://lmaobox.net/forum/v/profile/34539432/Nerdicous)")
--TODO in the future, implement a GUI. I'd consider this done right now, but a GUI will make this more user-friendly.
--[[
	Rhythm Time Attacking -- Nerdicous on LMAOBOX.net
	Makes the player attack at a preset interval (RhythmAttackTime).
	You can change these topmost variables in-game by typing "lua <command> = <value>"
	
	lua RhythmAttackTime = 1
	lua RhythmMaximumDistance = 500
	lua RhythmSafeMode = false
	lua RhythmToggleKey = KEY_Z
--]]

--RhythmAttackTime: The time (in seconds) before you are forced to attack
--RhythmMaximumDistance: The maximum HU distance between you and the target required to automatically fire. 0 to disable
--RhythmToggleKey: The keybind constant to toggle this script

--RhythmSafeMode: If true, the timer will only start when an enemy is able to be shot
--RhythmUltraSafeMode: If true, the player won't attack when there isn't anything to shoot
--RhythmContinueMode: If true, the timer won't reset when an enemy isn't able to be shot (Does nothing when RhythmUltraSafeMode is true)
--RhythmOnlyForceAttacks: If true, the player will be unable to attack on their own, to include the aimbot tools

--RhythmSoundStep: The sound that plays every 1/4th of a beat
--RhythmSoundBeat: The sound that plays every time you are forced to attack
--RhythmNoStepSound: If true, the step sound won't play. Always false if RhythmAttackTime is under 0.6s
--RhythmNoBeatSound: If true, the beat sound won't play

RhythmAttackTime = 2
RhythmMaximumDistance = 2000	--1 foot = 9 HU. 600 is recommended for closer-ranged classes
RhythmToggleKey = MOUSE_4	-- https://lmaobox.net/lua/Lua_Constants/

RhythmSafeMode = false
RhythmUltraSafeMode = true
RhythmContinueMode = true
RhythmOnlyForceAttacks = false

--Sounds in the custom folder work also
RhythmSoundStep = "ui/mm_medal_click.wav"
RhythmSoundBeat = "ui/mm_rank_up_achieved.wav"
RhythmNoStepSound = false
RhythmNoBeatSound = false


local RhythmEnabled = true
local LastRhythmEnabled = true
local NextTime_Attack = 0
local CurrentTickCount = 0
local CurrentAttackingTick = 0
local prevforceattack = false
local WillAttackSomethingNearby = false

local function OnCreateMove(cmd)
	if input.IsButtonDown(RhythmToggleKey) and LastRhythmEnabled == RhythmEnabled then
		RhythmEnabled = not RhythmEnabled
		print("Rhythm Attack Toggled to " .. tostring(RhythmEnabled) .. ".")
		return
	end
	if input.IsButtonDown(RhythmToggleKey) and not LastRhythmEnabled == RhythmEnabled then
		return
	end
	
	LastRhythmEnabled = RhythmEnabled

	if not RhythmEnabled then
		return
	end


	local EndButtons = cmd:GetButtons()
	--Force the client to stop attacking if the script decides they currently shouldn't be
	if RhythmOnlyForceAttacks then
		EndButtons = (EndButtons | IN_ATTACK) ~ IN_ATTACK

		--Disable changing how the user shoots in the GUI. These don't trigger keysend bitfields
		if gui.GetValue("auto shoot") ~= 0 or gui.GetValue("trigger shoot") ~= 0 or not gui.GetValue("auto backstab") == "off" then
			gui.SetValue("auto shoot", 0)
			gui.SetValue("trigger shoot", 0)
			gui.SetValue("auto backstab", "off")
			if prevforceattack then
				engine.PlaySound("vo/engineer_no01.mp3")
			end
		end
	end
	prevforceattack = RhythmOnlyForceAttacks --For the engineer "nope"

	--Check if we're supposed to actually be attacking right now, handled by the script
	--Handled by increments, because attacking is ignored if we're reloading
	if CurrentAttackingTick ~= 0 then
		CurrentAttackingTick = CurrentAttackingTick + 1
		EndButtons = EndButtons | IN_ATTACK --User forced to attack
		if RhythmUltraSafeMode and not WillAttackSomethingNearby then
			EndButtons = EndButtons ~ IN_ATTACK
		end
	end
	if CurrentAttackingTick > 3 then
		CurrentAttackingTick = 0
	end
	cmd:SetButtons(EndButtons)

end

--Realtime updating to determine sounds.
--User doesn't attack when not in an actual game.
--I also don't know how to make this so it doesn't continue if you're texting something in the chat
local function OnScreenDraw()
	--Early-return if the time hasn't elapsed
	if not (NextTime_Attack < os.clock()) then
		return
	end

	WillAttackSomethingNearby = false

	--Start over if we go into a different menu or if we're not active
	if engine.Con_IsVisible() or engine.IsGameUIVisible() or not entities.GetLocalPlayer():IsAlive() or not RhythmEnabled then
		CurrentTickCount = 0
		return
	end

	--Set the time of the next beat
	NextTime_Attack = os.clock() + (RhythmAttackTime / 4)

	WillAttackSomethingNearby = CanHitscanEnemies()

	if RhythmSafeMode and not WillAttackSomethingNearby then
		if not RhythmContinueMode then
			CurrentTickCount = 0
		end
		return
	end

	--Set the beat
	CurrentTickCount = CurrentTickCount + 1

	--If we're on the 4th beat, play a different sound, and force an attack
	if not (CurrentTickCount == 4) then
		if not RhythmNoStepSound and not (RhythmAttackTime < 0.6) then engine.PlaySound(RhythmSoundStep) end
	else
		CurrentTickCount = 0
		CurrentAttackingTick = 1
		if not RhythmNoBeatSound then engine.PlaySound(RhythmSoundBeat) end
	end
end

--Obviously not 100% accurate, since we're just looking at a single point
local boolean function CanHitscanEnemies()
	local LocalPlayer = entities.GetLocalPlayer()
	local LocalPlayerX, LocalPlayerY, LocalPlayerZ = LocalPlayer:GetAbsOrigin():Unpack()
	LocalPlayerZ = LocalPlayerZ + 74.5
	local LocalPlayerPos = Vector3(LocalPlayerX, LocalPlayerY, LocalPlayerZ)
	local LocalPlayerViewAngle = engine.GetViewAngles()
	local PlayerList = entities.FindByClass("CTFPlayer")
	for i=1, #PlayerList do
		::continue::
		if(i > #PlayerList) then
			break
		end
		local EnemyPlayer = PlayerList[i]
		if(EnemyPlayer == nil) then
			i = i + 1
			goto continue
		end

		if (LocalPlayer == EnemyPlayer) then
			i = i + 1
			goto continue
		end

		local EnemyPlayerX, EnemyPlayerY, EnemyPlayerZ = EnemyPlayer:GetAbsOrigin():Unpack()
		EnemyPlayerZ = EnemyPlayerZ + 40
		EnemyPlayerPos = Vector3(EnemyPlayerX, EnemyPlayerY, EnemyPlayerZ)

		--Trace a line between the local player and the target. If you're able to see them, then continue
		--The line will always hit the model
		local TracedLine = engine.TraceLine(LocalPlayerPos, EnemyPlayerPos, 1)
		if not (TracedLine.entity:IsPlayer()) or (TracedLine.entity:IsDormant()) then
			i = i + 1
			goto continue
		end
		
		--Test for distance between you and the target
		if(vector.Distance(LocalPlayerPos, EnemyPlayerPos) > RhythmMaximumDistance) and (RhythmMaximumDistance > 0) then
			i = i + 1
			goto continue
		end
		
		--Account for Aim FOV in the lmaobox GUI to determine when to start attacking
		-- This has -185 because that's when other players enter the Aim FOV line from firstperson
		if gui.GetValue("aim fov") < 170 then
			local Angle = -(GetFOVAngle(LocalPlayerViewAngle, entities.GetLocalPlayer():GetAbsOrigin(), EnemyPlayer:GetAbsOrigin()) - 185)
			if(Angle > gui.GetValue("aim fov")) then
				i = i + 1
				goto continue
			end
		end

		--Don't countdown if any of the "Ignore X" checks are involved

		--Is steam friend
		if gui.GetValue("ignore steam friends") ~= 0 and steam.IsFriend(client.GetPlayerInfo(EnemyPlayer:GetIndex())["SteamID"]) then
			i = i + 1
			goto continue
		end

		--Ignore Taunting
		if gui.GetValue("ignore taunting") ~= 0 and EnemyPlayer:InCond(TFCond_Taunting) then
			i = i + 1
			goto continue
		end

		--Ignore Bonk Immunity
		if gui.GetValue("ignore bonked") ~= 0 and EnemyPlayer:InCond(TFCond_Bonked) then
			i = i + 1
			goto continue
		end

		--Is currently using vaccinator uber
		--TODO: get damage type of currently-held weapon (dont know how to do either of those easily)
		if gui.GetValue("ignore vacc ubercharge") ~= 0 then
			--Bullet Resistance
			if(EnemyPlayer:InCond(TFCond_SmallBulletResist) or EnemyPlayer:InCond(TFCond_UberBulletResist)) then
				i = i + 1
				goto continue
			end
			--Blast Resistance
			if(EnemyPlayer:InCond(TFCond_SmallBlastResist) or EnemyPlayer:InCond(TFCond_UberBlastResist)) then
				i = i + 1
				goto continue
			end
			--Fire Resistance
			if(EnemyPlayer:InCond(TFCond_SmallFireResist) or EnemyPlayer:InCond(TFCond_UberFireResist)) then
				i = i + 1
				goto continue
			end
		end

		--Ignore Disguised
		if gui.GetValue("ignore disguised") ~= 0 and EnemyPlayer:InCond(TFCond_Disguised) then
			i = i + 1
			goto continue
		end

		--Ignore Cloaked
		if gui.GetValue("ignore cloaked") ~= 0 and (EnemyPlayer:InCond(TFCond_Cloaked) or EnemyPlayer:InCond(TFCond_CloakFlicker)) then
			i = i + 1
			goto continue
		end

		--Ignore Deadringer
		if gui.GetValue("ignore deadringer") ~= 0 and EnemyPlayer:InCond(TFCond_DeadRingered) then
			i = i + 1
			goto continue
		end

		return true
	end
	return false
end

--A function that returns the angle in which SourcePos is from TargetPos, accounting for ViewAngle
-- A return of 180 means the Source is looking directly at TargetPos, -180 is the Source looking away from TargetPos
local number function GetFOVAngle(ViewAngle, SourcePos, TargetPos)
	local ForwardPos = Vector3(ViewAngle.x, ViewAngle.y, ViewAngle.z):Forward()
	local RelPos = TargetPos - SourcePos
	
	local MagnitudeA = math.sqrt((ForwardPos.x * ForwardPos.x) + (ForwardPos.y * ForwardPos.y) + (ForwardPos.z * ForwardPos.z))
	local MagnitudeB = math.sqrt((RelPos.x * RelPos.x) + (RelPos.y * RelPos.y) + (RelPos.z * RelPos.z))
	
	MagnitudeA = Vector3(ForwardPos.x / MagnitudeA, ForwardPos.y / MagnitudeA, ForwardPos.z / MagnitudeA)
	MagnitudeB = Vector3(RelPos.x / MagnitudeB, RelPos.y / MagnitudeB, RelPos.z / MagnitudeB)

	return ((MagnitudeA.x * MagnitudeB.x) + (MagnitudeA.y * MagnitudeB.y) + (MagnitudeA.z * MagnitudeB.z)) * 180
	
end

callbacks.Register("Draw", OnScreenDraw) 
callbacks.Register("CreateMove", OnCreateMove)
