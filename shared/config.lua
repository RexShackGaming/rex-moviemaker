Config = {}

---------------------------------
-- access
---------------------------------
Config.Command      = 'moviemaker'
Config.Permission   = 'admin'      -- rsg-core permission group needed to use the tool (false = everyone)
Config.MaxScenes    = 25           -- saved scenes per character
Config.MaxKeyframes = 60           -- keyframes per scene
Config.MaxSceneSize = 60000        -- max JSON bytes stored per scene

---------------------------------
-- free camera
---------------------------------
Config.FreeCam = {
    BaseSpeed   = 0.15,  -- metres per frame
    FastMult    = 5.0,   -- holding sprint
    SlowMult    = 0.2,   -- holding duck
    MouseSens   = 6.0,
    RollSpeed   = 0.6,
    FovStep     = 2.0,
    MinFov      = 5.0,
    MaxFov      = 120.0,
    MaxDistance = 300.0, -- max distance from player ped (keeps world streamed, stops abuse)
}

---------------------------------
-- control hashes (keyboard names from rdr3_discoveries/Controls)
-- verify against your redm-brain data/rdr3_discoveries controls list if a key misbehaves
---------------------------------
Config.Keys = {
    Forward   = 0x8FD015D8, -- W  INPUT_MOVE_UP_ONLY
    Back      = 0xD27782E3, -- S  INPUT_MOVE_DOWN_ONLY
    Left      = 0x7065027D, -- A  INPUT_MOVE_LEFT_ONLY
    Right     = 0xB4E465B4, -- D  INPUT_MOVE_RIGHT_ONLY
    Up        = 0xDE794E3E, -- Q  INPUT_COVER
    Down      = 0x26E9DC00, -- Z
    Fast      = 0x8FFC75D6, -- Shift INPUT_SPRINT
    Slow      = 0xDB096B85, -- Ctrl  INPUT_DUCK
    LookLR    = 0xA987235F, -- INPUT_LOOK_LR
    LookUD    = 0xD2047988, -- INPUT_LOOK_UD
    FovIn     = 0xCC1075A7, -- Scroll up   INPUT_PREV_WEAPON
    FovOut    = 0xFD0F0C2C, -- Scroll down INPUT_NEXT_WEAPON
    RollLeft  = 0x8CC9CD42, -- X
    RollRight = 0x9959A6F0, -- C
    AddKey    = 0xCEFD9220, -- E  add keyframe
    Focus     = 0xB2F377E8, -- F  lock focus on entity under crosshair
    Back2Menu = 0x156F7119, -- Backspace INPUT_FRONTEND_CANCEL
}

---------------------------------
-- playback defaults
---------------------------------
Config.DefaultDuration = 4000  -- ms travel to next keyframe
Config.DefaultHold     = 0     -- ms pause at keyframe
Config.DefaultFov      = 50.0
Config.DefaultEase     = 'easeInOut'
Config.Easings = { 'linear', 'easeIn', 'easeOut', 'easeInOut', 'smoothstep' }

---------------------------------
-- visual effects
-- label = locale key in locales/*.json; names below are presets only; the NUI also accepts any custom name typed in.
-- check names against data/rdr3_discoveries graphics (timecycles / animpostfx) before release
---------------------------------
Config.Timecycles = {
    { label = 'fx_none', value = '' },
}
Config.PostFx = {
    { label = 'fx_none', value = '' },
    { label = 'fx_drunk', value = 'PlayerDrunk01' },
}
-- camera shake
-- Lua styles: freq = wobble speed, pitch/yaw/roll = degrees of movement at amplitude 1.0 (can never crash)
-- Native styles: real game shakes via ShakeCam. ONLY use names found in the RDR3 decompiled scripts -
--   an unknown name crashes the game. scale converts the 0-5 slider into the game's amplitude
--   (the game's own scripts use roughly 0.02 - 1.0).
-- All native names below were verified in Desktop/decompile (e.g. HAND_SHAKE x112, SMALL_EXPLOSION_SHAKE x28)
-- label = locale key in locales/*.json
Config.ShakeStyles = {
    -- Lua
    handheld   = { label = 'shake_handheld', freq = 0.9, pitch = 0.6, yaw = 0.8, roll = 0.4 },
    breathing  = { label = 'shake_breathing', freq = 0.35, pitch = 0.5, yaw = 0.2, roll = 0.1 },
    horseback  = { label = 'shake_horseback', freq = 2.2, pitch = 1.2, yaw = 0.5, roll = 0.6 },
    vibration  = { label = 'shake_vibration', freq = 9.0, pitch = 0.25, yaw = 0.25, roll = 0.15 },
    earthquake = { label = 'shake_earthquake', freq = 5.0, pitch = 1.8, yaw = 1.4, roll = 1.2 },
    -- Native
    n_hand      = { label = 'shake_n_hand', native = 'HAND_SHAKE',             scale = 0.2 },
    n_drunk     = { label = 'shake_n_drunk', native = 'DRUNK_SHAKE',            scale = 0.2 },
    n_povdrunk  = { label = 'shake_n_povdrunk', native = 'POV_DRUNK_SHAKE',        scale = 0.2 },
    n_jolt      = { label = 'shake_n_jolt', native = 'JOLT_SHAKE',             scale = 0.2 },
    n_idle      = { label = 'shake_n_idle', native = 'TABLE_GAMES_IDLE_SHAKE', scale = 0.2 },
    n_expl_s    = { label = 'shake_n_expl_s', native = 'SMALL_EXPLOSION_SHAKE',  scale = 0.2 },
    n_expl_m    = { label = 'shake_n_expl_m', native = 'MEDIUM_EXPLOSION_SHAKE', scale = 0.2 },
    n_expl_l    = { label = 'shake_n_expl_l', native = 'LARGE_EXPLOSION_SHAKE',  scale = 0.2 },
}
Config.ShakeOrder = {
    'handheld', 'breathing', 'horseback', 'vibration', 'earthquake',
    'n_hand', 'n_drunk', 'n_povdrunk', 'n_jolt', 'n_idle', 'n_expl_s', 'n_expl_m', 'n_expl_l',
}
