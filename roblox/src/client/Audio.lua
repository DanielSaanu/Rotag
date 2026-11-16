-- Sound (H31, docs/systems/ui.md §5; DESIGN §3 rules 2, 21): music that follows the match and an effect for every
-- move, hit and button. Local only: each client plays what ITS screen shows; nothing is sent or decided.
-- Effects are Roblox's own built-in sounds (rbxasset://sounds, shipped with the client: no upload, no licence, they
-- always load), shaped by pitch and volume. Music is three tracks from Roblox's licensed APM library (free for every
-- experience); the ids are the table below and are Danzo's to swap: he has ears, the builder did not.
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Audio = {}

-- Music: { asset id, volume }. "menu" also plays in the lobby; "end" takes over in the end phase (rule 51).
local MUSIC = {
	menu = { "rbxassetid://9045593366", 0.35 }, -- APM "Life Here Now Forever (b)": glitchy, fun, funky EDM (60 s loop)
	match = { "rbxassetid://1839850159", 0.32 }, -- APM "Aim High": a driving dance bed (5:37)
	["end"] = { "rbxassetid://1839855934", 0.42 }, -- APM "Race Against Time": high-pressure building tension (5:01)
}
local FADE = 0.8

-- Effects: name -> { file under rbxasset://sounds/, volume, pitch, pitch spread }.
local SFX = {
	jump = { "action_jump.mp3", 0.5, 1.15, 0.08 },
	double = { "action_jump.mp3", 0.5, 1.55, 0.08 },
	wall = { "action_jump.mp3", 0.55, 0.9, 0.06 },
	land = { "action_jump_land.mp3", 0.45, 1, 0.1 },
	dash = { "swordlunge.wav", 0.5, 1.5, 0.1 },
	grapple = { "unsheath.wav", 0.45, 1.6, 0.1 },
	pad = { "short spring sound.wav", 0.7, 1.1, 0.05 },
	tag = { "hit.wav", 0.9, 0.85, 0.05 },
	tagged = { "bass.wav", 1, 1.2, 0 },
	burnout = { "impact_explosion_03.mp3", 0.8, 1.15, 0.05 },
	orb = { "electronicpingshort.wav", 0.5, 1.5, 0.1 },
	ice = { "glassbreak.wav", 0.5, 1.4, 0.1 },
	trap = { "snap.mp3", 0.8, 0.8, 0.05 },
	crate = { "collide.wav", 0.6, 1.2, 0.1 },
	hex = { "HalloweenGhost.wav", 0.5, 1.5, 0 },
	place = { "Kerplunk.wav", 0.6, 0.8, 0.1 },
	click = { "clickfast.wav", 0.6, 1, 0.04 },
	hover = { "switch.wav", 0.18, 1.6, 0.05 },
	tick = { "SWITCH3.wav", 0.4, 1.3, 0.06 },
	beep = { "electronicpingshort.wav", 0.4, 0.75, 0 },
	go = { "electronicpingshort.wav", 0.6, 1.1, 0 },
	coin = { "electronicpingshort.wav", 0.5, 2, 0.05 },
	win = { "victory.wav", 0.8, 1, 0 },
	card = { "flashbulb.wav", 0.5, 0.9, 0 },
	prize = { "victory.wav", 0.7, 1.35, 0 },
	walls = { "HalloweenThunder.wav", 0.5, 1.1, 0 },
}

local sounds: { [string]: Sound } = {}
local music: { [string]: Sound } = {}
local current: string? = nil
local lastAt: { [string]: number } = {}

-- Play effect `name`; `pitch` scales its pitch (the fuse beep rises). The same effect at most every 40 ms.
function Audio.play(name: string, pitch: number?)
	local s, def = sounds[name], SFX[name]
	if not (s and def) then return end
	local now = os.clock()
	if now - (lastAt[name] or -math.huge) < 0.04 then return end
	lastAt[name] = now
	s.PlaybackSpeed = def[3] * (pitch or 1) * (1 + (math.random() - 0.5) * 2 * def[4])
	s:Play()
end

-- Crossfade to track `name` ("menu" | "match" | "end"), or to silence with nil.
function Audio.music(name: string?)
	if name == current then return end
	local old = current and music[current]
	current = name
	if old then
		local t = TweenService:Create(old, TweenInfo.new(FADE), { Volume = 0 })
		t.Completed:Connect(function() if current ~= old.Name then old:Pause() end end)
		t:Play()
	end
	local new = name and music[name]
	if new and name then
		new.Volume = 0
		if not new.IsPlaying then new:Resume() end
		if not new.IsPlaying then new:Play() end
		TweenService:Create(new, TweenInfo.new(FADE), { Volume = MUSIC[name][2] }):Play()
	end
end

-- What Movement reported for the LOCAL runner since the last draw.
function Audio.moves(events: any)
	if events.dash then Audio.play("dash") end
	if events.jump then Audio.play(if events.jump == "double" then "double" elseif events.jump == "wall" then "wall" else "jump") end
	if events.landed and events.landed > 20 then Audio.play("land", 0.85 + math.min(0.3, events.landed / 260)) end
end

-- The fuse's beep (rule 2): faster and higher as the fuse runs down under `igniteAt`. Call every frame with the
-- seconds left while a round runs; -1 otherwise.
local nextBeep = 0
function Audio.fuse(left: number, igniteAt: number, mine: boolean)
	if left < 0 or left > igniteAt then return end
	local now = os.clock()
	if now < nextBeep then return end
	local k = 1 - left / igniteAt
	nextBeep = now + 1 - 0.8 * k
	local s = sounds.beep
	if s then
		s.Volume = SFX.beep[2] * (if mine then 1.5 else 0.7)
		Audio.play("beep", 1 + k)
	end
end

function Audio.start()
	local g = Instance.new("SoundGroup")
	g.Name = "RotagAudio"
	g.Parent = SoundService
	for name, def in SFX do
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = "rbxasset://sounds/" .. def[1]
		s.Volume = def[2]
		s.SoundGroup = g
		s.Parent = g
		sounds[name] = s
	end
	for name, def in MUSIC do
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = def[1]
		s.Volume = 0
		s.Looped = true
		s.SoundGroup = g
		s.Parent = g
		music[name] = s
	end
end

return Audio
