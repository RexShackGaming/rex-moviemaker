lib.locale()

---------------------------------
-- state
---------------------------------
local isOpen, mode = false, 'editor'   -- editor | fly | play
local cam = nil
local camPos, camRot, camFov = vector3(0, 0, 0), vector3(0, 0, 0), Config.DefaultFov
local keyframes = {}
local focusEntity = nil
local fx = { timecycle = '', tcStrength = 1.0, postfx = '', shake = '', shakeAmp = 0.0, letterbox = 0, fadeIn = 0, fadeOut = 0 }
local settings = { loop = false, hidePlayer = false, focusSelf = false }
local stopPlayback = false
local shakePreview = false
local ZERO = vector3(0, 0, 0)

---------------------------------
-- helpers
---------------------------------
local function notify(desc, ntype)
    lib.notify({ title = locale('title'), description = desc, type = ntype or 'inform' })
end

local function clamp(v, min, max) return math.max(min, math.min(max, v)) end

local function wrap180(a)
    a = (a + 180.0) % 360.0
    return a - 180.0
end

local function rotToDir(rot)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local c = math.abs(math.cos(rx))
    return vector3(-math.sin(rz) * c, math.cos(rz) * c, math.sin(rx))
end

local function rotToRight(rot)
    local rz = math.rad(rot.z)
    return vector3(math.cos(rz), math.sin(rz), 0.0)
end

local Ease = {
    linear     = function(t) return t end,
    easeIn     = function(t) return t * t * t end,
    easeOut    = function(t) local u = 1 - t return 1 - u * u * u end,
    easeInOut  = function(t) if t < 0.5 then return 4 * t * t * t end local u = -2 * t + 2 return 1 - u * u * u / 2 end,
    smoothstep = function(t) return t * t * (3 - 2 * t) end,
}

local function catmull(p0, p1, p2, p3, t)
    local t2, t3 = t * t, t * t * t
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

local function sendUI(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function pushKeyframes()
    sendUI('keyframes', keyframes)
end

local function shakeOffset()
    local style = Config.ShakeStyles[fx.shake]
    if not style or style.native or fx.shakeAmp <= 0 then return ZERO end
    local t = GetGameTimer() / 1000.0 * style.freq * 2 * math.pi
    local a = fx.shakeAmp
    -- layered sines at unrelated rates give organic, non-repeating motion
    local p = (math.sin(t) * 0.6 + math.sin(t * 2.31 + 1.3) * 0.3 + math.sin(t * 4.77 + 0.4) * 0.1) * style.pitch * a
    local y = (math.sin(t * 0.83 + 2.1) * 0.6 + math.sin(t * 1.97 + 0.7) * 0.3 + math.sin(t * 5.13) * 0.1) * style.yaw * a
    local r = (math.sin(t * 0.71 + 4.2) * 0.7 + math.sin(t * 2.63 + 3.1) * 0.3) * style.roll * a
    return vector3(p, r, y)
end

local function setCam(pos, rot, fov)
    camPos, camRot, camFov = pos, rot, fov
    local applied = (mode == 'play' or shakePreview) and (rot + shakeOffset()) or rot
    SetCamCoord(cam, pos.x, pos.y, pos.z)
    SetCamRot(cam, applied.x, applied.y, applied.z, 2)
    SetCamFov(cam, fov)
    SetFocusPosAndVel(pos.x, pos.y, pos.z, 0.0, 0.0, 0.0)
end

local function setCamToKeyframe(k)
    setCam(vector3(k.x, k.y, k.z), vector3(k.rx, k.ry, k.rz), k.fov)
end

local function setFocusPoint(enabled)
    local ent = settings.focusSelf and PlayerPedId() or focusEntity
    if enabled and ent and DoesEntityExist(ent) then
        PointCamAtEntity(cam, ent, 0.0, 0.0, 0.6, true)
    else
        StopCamPointing(cam)
    end
end

---------------------------------
-- effects
---------------------------------
local function stopEffects()
    ClearTimecycleModifier()
    AnimpostfxStopAll()
    if cam then StopCamShaking(cam, true) end
end

local function applyFx()
    stopEffects()
    local style = Config.ShakeStyles[fx.shake]
    if style and style.native and fx.shakeAmp > 0 then
        ShakeCam(cam, style.native, math.min(2.0, fx.shakeAmp * (style.scale or 0.2)) + 0.0)
    end
    if fx.timecycle ~= '' then
        SetTimecycleModifier(fx.timecycle)
        SetTimecycleModifierStrength(fx.tcStrength + 0.0)
    end
    if fx.postfx ~= '' then AnimpostfxPlay(fx.postfx) end
    sendUI('letterbox', fx.letterbox)
end

local function clearFx()
    stopEffects()
    shakePreview = false
    sendUI('letterbox', 0)
end

---------------------------------
-- open / close
---------------------------------
local function closeEditor()
    if not isOpen then return end
    stopPlayback = true
    isOpen, mode = false, 'editor'
    clearFx()
    SetNuiFocus(false, false)
    sendUI('close')
    RenderScriptCams(false, true, 500, true, true, 0)
    if cam then DestroyCam(cam, false) cam = nil end
    ClearFocus()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true)
    DisplayRadar(true)
    DisplayHud(true)
    if IsScreenFadedOut() or IsScreenFadingOut() then DoScreenFadeIn(500) end
end

local function editorMode()
    mode = 'editor'
    shakePreview = false
    StopCamShaking(cam, true)
    StopCamPointing(cam)
    SetEntityVisible(PlayerPedId(), true)
    DisplayRadar(true)
    DisplayHud(true)
    SetNuiFocus(true, true)
    sendUI('editor')
    pushKeyframes()
end

local function uiStrings()
    local out = {}
    local all = lib.getLocales and lib.getLocales() or {}
    for k, v in pairs(all) do
        if k:sub(1, 3) == 'ui_' then out[k] = v end
    end
    return out
end

local function openEditor()
    if isOpen then return end
    -- server confirms permission, so a triggered client event can't open the free camera
    if not lib.callback.await('rex-moviemaker:server:canUse', false) then
        return notify(locale('no_permission'), 'error')
    end
    isOpen = true
    FreezeEntityPosition(PlayerPedId(), true)
    local p = GetGameplayCamCoord()
    local r = GetGameplayCamRot(2)
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', p.x, p.y, p.z, r.x, 0.0, r.z, Config.DefaultFov, false, 0)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, true, 0)
    setCam(p, vector3(r.x, 0.0, r.z), Config.DefaultFov)

    local shakeList = {}
    for _, id in ipairs(Config.ShakeOrder) do
        local s = Config.ShakeStyles[id]
        if s then shakeList[#shakeList + 1] = { value = id, label = locale(s.label) } end
    end
    local function presets(list)
        local out = {}
        for i, p in ipairs(list) do out[i] = { value = p.value, label = locale(p.label) } end
        return out
    end
    sendUI('open', {
        keyframes = keyframes, fx = fx, settings = settings, ui = uiStrings(),
        easings = Config.Easings, timecycles = presets(Config.Timecycles), postfx = presets(Config.PostFx), shakes = shakeList,
        minFov = Config.FreeCam.MinFov, maxFov = Config.FreeCam.MaxFov,
    })
    editorMode()
end

RegisterNetEvent('rex-moviemaker:client:open', openEditor)

---------------------------------
-- keyframes
---------------------------------
local function addKeyframe()
    if #keyframes >= Config.MaxKeyframes then return notify(locale('max_keyframes'), 'error') end
    keyframes[#keyframes + 1] = {
        x = camPos.x, y = camPos.y, z = camPos.z,
        rx = camRot.x, ry = camRot.y, rz = camRot.z,
        fov = camFov, duration = Config.DefaultDuration, hold = Config.DefaultHold,
        ease = Config.DefaultEase, focus = false,
    }
    notify(locale('keyframe_added', #keyframes), 'success')
    pushKeyframes()
end

---------------------------------
-- entity focus (raycast from camera centre)
---------------------------------
local function focusUnderCrosshair()
    local to = camPos + rotToDir(camRot) * 250.0
    local ray = StartShapeTestRay(camPos.x, camPos.y, camPos.z, to.x, to.y, to.z, -1, 0, 7)
    local status, hit, _, _, ent = GetShapeTestResult(ray)
    local tries = 0
    while status == 1 and tries < 50 do
        Wait(0)
        status, hit, _, _, ent = GetShapeTestResult(ray)
        tries = tries + 1
    end
    if hit == 1 and ent and ent ~= 0 and DoesEntityExist(ent) and GetEntityType(ent) ~= 0 then
        focusEntity = ent
        settings.focusSelf = false
        notify(locale('focus_locked'), 'success')
        sendUI('focus', { has = true, self = false })
    else
        notify(locale('focus_none'), 'error')
    end
end

---------------------------------
-- free fly camera
---------------------------------
local function startFly()
    if mode == 'fly' then return end
    mode = 'fly'
    SetNuiFocus(false, false)
    sendUI('fly', { fov = camFov })
    local K, F = Config.Keys, Config.FreeCam
    CreateThread(function()
        local warned = false
        while isOpen and mode == 'fly' do
            Wait(0)
            DisableAllControlActions(0)

            local mx = GetDisabledControlNormal(0, K.LookLR) * F.MouseSens
            local my = GetDisabledControlNormal(0, K.LookUD) * F.MouseSens
            local roll = camRot.y
            if IsDisabledControlPressed(0, K.RollLeft) then roll = roll - F.RollSpeed end
            if IsDisabledControlPressed(0, K.RollRight) then roll = roll + F.RollSpeed end
            -- wrap yaw/roll so stored values stay in -180..180 (server rejects anything outside -360..360)
            local rot = vector3(clamp(camRot.x - my, -89.0, 89.0), wrap180(roll), wrap180(camRot.z - mx))

            local speed = F.BaseSpeed
            if IsDisabledControlPressed(0, K.Fast) then speed = speed * F.FastMult end
            if IsDisabledControlPressed(0, K.Slow) then speed = speed * F.SlowMult end
            local fwd, right = rotToDir(rot), rotToRight(rot)
            local move = ZERO
            if IsDisabledControlPressed(0, K.Forward) then move = move + fwd end
            if IsDisabledControlPressed(0, K.Back) then move = move - fwd end
            if IsDisabledControlPressed(0, K.Right) then move = move + right end
            if IsDisabledControlPressed(0, K.Left) then move = move - right end
            if IsDisabledControlPressed(0, K.Up) then move = move + vector3(0, 0, 1) end
            if IsDisabledControlPressed(0, K.Down) then move = move - vector3(0, 0, 1) end

            local newPos = camPos + move * speed
            if #(newPos - GetEntityCoords(PlayerPedId())) > F.MaxDistance then
                newPos = camPos
                if not warned then notify(locale('too_far'), 'error') warned = true end
            else
                warned = false
            end

            local fov = camFov
            if IsDisabledControlJustPressed(0, K.FovIn) then fov = math.max(F.MinFov, fov - F.FovStep) end
            if IsDisabledControlJustPressed(0, K.FovOut) then fov = math.min(F.MaxFov, fov + F.FovStep) end
            if fov ~= camFov then sendUI('flyFov', fov) end

            setCam(newPos, rot, fov)

            if IsDisabledControlJustPressed(0, K.AddKey) then addKeyframe() end
            if IsDisabledControlJustPressed(0, K.Focus) then focusUnderCrosshair() end
            if IsDisabledControlJustPressed(0, K.Back2Menu) then editorMode() end
        end
    end)
end

---------------------------------
-- playback
---------------------------------
local function buildPath()
    -- keep yaw/roll continuous so the camera always takes the short way round
    local list, prevZ, prevY = {}, nil, nil
    for i, k in ipairs(keyframes) do
        local rz, ry = k.rz, k.ry
        if prevZ then
            rz = prevZ + wrap180(rz - prevZ)
            ry = prevY + wrap180(ry - prevY)
        end
        prevZ, prevY = rz, ry
        list[i] = { pos = vector3(k.x, k.y, k.z), rot = vector3(k.rx, ry, rz), fov = k.fov, src = k }
    end
    return list
end

local function checkStop()
    DisableAllControlActions(0)
    if IsDisabledControlJustPressed(0, Config.Keys.Back2Menu) then stopPlayback = true end
end

local function play(startIndex)
    if #keyframes < 2 then return notify(locale('need_two_keys'), 'error') end
    if mode == 'play' then return end
    mode = 'play'
    stopPlayback = false
    SetNuiFocus(false, false)
    sendUI('play')
    DisplayRadar(false)
    DisplayHud(false)
    if settings.hidePlayer then SetEntityVisible(PlayerPedId(), false) end

    CreateThread(function()
        local pts = buildPath()
        local n = #pts
        repeat
            local first = pts[startIndex]
            setCam(first.pos, first.rot, first.fov)
            applyFx()
            if fx.fadeIn > 0 then
                DoScreenFadeOut(0)
                Wait(50)
                DoScreenFadeIn(math.floor(fx.fadeIn))
            elseif IsScreenFadedOut() then
                DoScreenFadeIn(0)
            end

            for i = startIndex, n - 1 do
                if stopPlayback then break end
                local a, b = pts[i], pts[i + 1]
                local p0, p3 = pts[i - 1] or a, pts[i + 2] or b
                setFocusPoint(a.src.focus)

                local holdEnd = GetGameTimer() + a.src.hold
                while GetGameTimer() < holdEnd and not stopPlayback do
                    Wait(0)
                    checkStop()
                    setCam(a.pos, a.rot, a.fov) -- keeps Lua shake alive during holds
                end

                local dur = math.max(1, a.src.duration)
                local ease = Ease[a.src.ease] or Ease.linear
                local fadeAt = (i == n - 1 and fx.fadeOut > 0) and math.max(0, dur - fx.fadeOut) or nil
                local t0 = GetGameTimer()
                while not stopPlayback do
                    Wait(0)
                    checkStop()
                    local el = GetGameTimer() - t0
                    if fadeAt and el >= fadeAt then DoScreenFadeOut(math.floor(fx.fadeOut)) fadeAt = nil end
                    local raw = math.min(1.0, el / dur)
                    local t = ease(raw)
                    setCam(catmull(p0.pos, a.pos, b.pos, p3.pos, t), catmull(p0.rot, a.rot, b.rot, p3.rot, t), a.fov + (b.fov - a.fov) * t)
                    if raw >= 1.0 then break end
                end
            end
            -- let the fade-out finish before looping or returning
            if fx.fadeOut > 0 and not stopPlayback then Wait(math.floor(fx.fadeOut)) end
            startIndex = 1
        until not settings.loop or stopPlayback or not isOpen

        if not isOpen then return end
        clearFx()
        DoScreenFadeIn(300)
        notify(locale('playback_done'), 'inform')
        editorMode()
    end)
end

---------------------------------
-- NUI callbacks
---------------------------------
local function kf(data) return type(data) == 'table' and keyframes[tonumber(data.index) or 0] end

RegisterNUICallback('close', function(_, cb) closeEditor() cb('ok') end)
RegisterNUICallback('fly', function(_, cb) startFly() cb('ok') end)
RegisterNUICallback('addHere', function(_, cb) addKeyframe() cb('ok') end)

RegisterNUICallback('play', function(data, cb)
    local idx = math.floor(tonumber(data and data.from) or 1)
    if idx < 1 or idx >= #keyframes then idx = 1 end
    play(idx)
    cb('ok')
end)

RegisterNUICallback('updateKeyframe', function(data, cb)
    local k = kf(data)
    if k then
        local f, v = data.field, data.value
        if f == 'duration' or f == 'hold' then k[f] = clamp(tonumber(v) or k[f], 0, 120000)
        elseif f == 'fov' then k.fov = clamp(tonumber(v) or k.fov, Config.FreeCam.MinFov, Config.FreeCam.MaxFov)
        elseif f == 'ry' then k.ry = wrap180(tonumber(v) or k.ry)
        elseif f == 'ease' and Ease[v] then k.ease = v
        elseif f == 'focus' then k.focus = v == true end
    end
    cb('ok')
end)

RegisterNUICallback('deleteKeyframe', function(data, cb)
    local i = tonumber(data.index)
    if i and keyframes[i] then table.remove(keyframes, i) end
    pushKeyframes()
    cb('ok')
end)

RegisterNUICallback('moveKeyframe', function(data, cb)
    local i, d = tonumber(data.index), tonumber(data.dir)
    if i and (d == 1 or d == -1) and keyframes[i] and keyframes[i + d] then
        keyframes[i], keyframes[i + d] = keyframes[i + d], keyframes[i]
    end
    pushKeyframes()
    cb('ok')
end)

RegisterNUICallback('previewKeyframe', function(data, cb)
    local k = kf(data)
    if k then setCamToKeyframe(k) end
    cb('ok')
end)

RegisterNUICallback('replaceKeyframe', function(data, cb)
    local k = kf(data)
    if k then
        k.x, k.y, k.z = camPos.x, camPos.y, camPos.z
        k.rx, k.ry, k.rz, k.fov = camRot.x, camRot.y, camRot.z, camFov
    end
    pushKeyframes()
    cb('ok')
end)

RegisterNUICallback('clearKeyframes', function(_, cb) keyframes = {} pushKeyframes() cb('ok') end)

RegisterNUICallback('setFx', function(data, cb)
    if type(data) == 'table' then
        fx.timecycle = tostring(data.timecycle or ''):sub(1, 64)
        fx.tcStrength = clamp(tonumber(data.tcStrength) or 1, 0, 1)
        fx.postfx = tostring(data.postfx or ''):sub(1, 64)
        fx.shake = Config.ShakeStyles[data.shake] and data.shake or ''
        fx.shakeAmp = clamp(tonumber(data.shakeAmp) or 0, 0, 5)
        fx.letterbox = clamp(tonumber(data.letterbox) or 0, 0, 25)
        fx.fadeIn = clamp(tonumber(data.fadeIn) or 0, 0, 10000)
        fx.fadeOut = clamp(tonumber(data.fadeOut) or 0, 0, 10000)
    end
    cb('ok')
end)

RegisterNUICallback('previewFx', function(_, cb)
    applyFx()
    local st = Config.ShakeStyles[fx.shake]
    if st and not st.native and fx.shakeAmp > 0 and not shakePreview then
        shakePreview = true
        CreateThread(function()
            while shakePreview and isOpen and mode == 'editor' do
                Wait(0)
                setCam(camPos, camRot, camFov)
            end
            shakePreview = false
            if cam and isOpen then SetCamRot(cam, camRot.x, camRot.y, camRot.z, 2) end
        end)
    end
    cb('ok')
end)

RegisterNUICallback('clearFx', function(_, cb) clearFx() cb('ok') end)

RegisterNUICallback('setSettings', function(data, cb)
    settings.loop = data.loop == true
    settings.hidePlayer = data.hidePlayer == true
    cb('ok')
end)

RegisterNUICallback('focusSelf', function(_, cb)
    settings.focusSelf = true
    focusEntity = nil
    notify(locale('focus_locked'), 'success')
    sendUI('focus', { has = true, self = true })
    cb('ok')
end)

RegisterNUICallback('clearFocus', function(_, cb)
    settings.focusSelf = false
    focusEntity = nil
    StopCamPointing(cam)
    notify(locale('focus_cleared'), 'inform')
    sendUI('focus', { has = false })
    cb('ok')
end)

---------------------------------
-- scenes
---------------------------------
local function sceneList()
    return lib.callback.await('rex-moviemaker:server:getScenes', false) or false
end

RegisterNUICallback('getScenes', function(_, cb) cb(sceneList()) end)

RegisterNUICallback('saveScene', function(data, cb)
    local ok = lib.callback.await('rex-moviemaker:server:saveScene', false, tostring(data.name or ''),
        { keyframes = keyframes, fx = fx, settings = settings })
    cb(ok and sceneList() or false)
end)

RegisterNUICallback('loadScene', function(data, cb)
    local res = lib.callback.await('rex-moviemaker:server:loadScene', false, tonumber(data.id))
    if not (res and res.scene) then return cb(false) end
    keyframes = res.scene.keyframes or {}
    for k, v in pairs(res.scene.fx or {}) do
        if fx[k] ~= nil then fx[k] = v end
    end
    local st = res.scene.settings or {}
    settings.loop, settings.hidePlayer, settings.focusSelf = st.loop == true, st.hidePlayer == true, st.focusSelf == true
    focusEntity = nil
    sendUI('focus', { has = settings.focusSelf, self = settings.focusSelf })
    if keyframes[1] then setCamToKeyframe(keyframes[1]) end
    notify(locale('scene_loaded', res.name), 'success')
    cb({ keyframes = keyframes, fx = fx, settings = settings })
end)

RegisterNUICallback('deleteScene', function(data, cb)
    lib.callback.await('rex-moviemaker:server:deleteScene', false, tonumber(data.id))
    cb(sceneList())
end)

---------------------------------
-- cleanup
---------------------------------
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    closeEditor()
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', closeEditor)
