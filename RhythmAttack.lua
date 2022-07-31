print("Rhythm Time Attacking script created by Nerdicous (https://lmaobox.net/forum/v/profile/34539432/Nerdicous)")
--[[
	Rhythm Time Attacking -- Nerdicous on LMAOBOX.net
	Makes the player attack at a preset interval (RhythmAttackTime).
	You can change these topmost variables in-game by typing "lua <command> = <value>"
--]]

--RhythmAttackTime: The time (in seconds) before you are forced to attack
--RhythmSoundStep: The sound that plays every 1/4th of a beat
--RhythmSoundBeat: The sound that plays every time you are forced to attack
--RhythmSafeMode: If true, the timer will only start when an enemy is able to be shot
	--RhythmContinueMode: If true, the timer won't reset when an enemy isn't able to be shot
--RhythmOnlyForceAttacks: If true, the player will be unable to attack on their own, to include the aimbot tools
--RhythmNoSounds: If true, script sounds won't play
RhythmAttackTime = 2.5
RhythmSoundStep = "ui/mm_medal_click.wav"
RhythmSoundBeat = "ui/mm_rank_up_achieved.wav"
RhythmSafeMode = true
RhythmContinueMode = false
RhythmOnlyForceAttacks = false
RhythmNoSounds = false


local NextTime_Attack = 0
local CurrentTickCount = 0
local CurrentAttackingTick = 0
local prevforceattack = false

local function OnCreateMove( cmd )
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
	--Start over if we go into a different menu
	if engine.Con_IsVisible() or engine.IsGameUIVisible() or not entities.GetLocalPlayer():IsAlive() then
		CurrentTickCount = 0
		return
	end

	--Set the time of the next beat
	NextTime_Attack = os.clock() + (RhythmAttackTime / 4)

	if RhythmSafeMode and not CanHitscanEnemies() then
		if not RhythmContinueMode then
			CurrentTickCount = 0
		end
		return
	end

	--Set the beat
	CurrentTickCount = CurrentTickCount + 1

	--If we're on the 4th beat, play a different sound, and force an attack
	if not (CurrentTickCount == 4) then
		if not RhythmNoSounds and not (RhythmAttackTime < 0.6) then engine.PlaySound(RhythmSoundStep) end
	else
		CurrentTickCount = 0
		CurrentAttackingTick = 1
		if not RhythmNoSounds then engine.PlaySound(RhythmSoundBeat) end
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
		
		--Account for Aim FOV in the lmaobox GUI to determine when to start attacking
		-- This has -185 because that's when other players enter the Aim FOV line from firstperson
		if gui.GetValue("aim fov") < 170 then
			local Angle = -(GetFOVAngle(LocalPlayerViewAngle, entities.GetLocalPlayer():GetAbsOrigin(), EnemyPlayer:GetAbsOrigin()) - 185)
			print(Angle)
			if(Angle > gui.GetValue("aim fov")) then
				i = i + 1
				goto continue
			end
		end

		--Don't countdown if any of the "Ignore X" checks are involved

		--Is steam friend
		if(gui.GetValue("ignore steam friends") and steam.IsFriend(client.GetPlayerInfo(EnemyPlayer:GetIndex())["SteamID"])) then
			i = i + 1
			goto continue
		end

		--Ignore Taunting
		if(gui.GetValue("ignore taunting") and EnemyPlayer:InCond(TFCond_Taunting)) then
			i = i + 1
			goto continue
		end

		--Ignore Bonk Immunity
		if(gui.GetValue("ignore bonked") and EnemyPlayer:InCond(TFCond_Bonked)) then
			i = i + 1
			goto continue
		end

		--Is currently using vaccinator uber
		--TODO: get damage type of currently-held weapon (dont know how to do either of those easily)
		if(gui.GetValue("ignore vacc ubercharge") == "On") then
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
		if(gui.GetValue("ignore disguised") and EnemyPlayer:InCond(TFCond_Disguised)) then
			i = i + 1
			goto continue
		end

		--Ignore Cloaked
		if(gui.GetValue("ignore cloaked")) and (EnemyPlayer:InCond(TFCond_Cloaked) or EnemyPlayer:InCond(TFCond_CloakFlicker)) then
			i = i + 1
			goto continue
		end

		--Ignore Deadringer
		if(gui.GetValue("ignore deadringer") and EnemyPlayer:InCond(TFCond_DeadRingered)) then
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