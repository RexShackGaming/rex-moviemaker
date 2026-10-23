local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local cooldown = {}   -- [src] = { write = ms, read = ms }

---------------------------------
-- auto-create database table on start
---------------------------------
CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `rex_moviemaker_scenes` (
                `id` INT(11) NOT NULL AUTO_INCREMENT,
                `citizenid` VARCHAR(50) NOT NULL,
                `name` VARCHAR(50) NOT NULL,
                `data` LONGTEXT NOT NULL,
                `updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`),
                UNIQUE KEY `owner_name` (`citizenid`, `name`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
    end)
    if ok then
        print('^2[rex-moviemaker]^7 database table ready')
    else
        print('^1[rex-moviemaker]^7 failed to create database table: ' .. tostring(err))
    end
end)

local function hasAccess(src)
    if not Config.Permission then return true end
    return RSGCore.Functions.HasPermission(src, Config.Permission)
end

local function notify(src, desc, ntype)
    TriggerClientEvent('ox_lib:notify', src, { title = locale('title'), description = desc, type = ntype or 'inform' })
end

-- kind: 'write' (save/delete, 1s) or 'read' (list/load, 250ms) - stops DB spam from the NUI
local function onCooldown(src, kind)
    local now = GetGameTimer()
    local c = cooldown[src] or {}
    cooldown[src] = c
    local wait = kind == 'write' and 1000 or 250
    if c[kind] and now - c[kind] < wait then return true end
    c[kind] = now
    return false
end

---------------------------------
-- validation of scene data
---------------------------------
local function num(v, min, max)
    v = tonumber(v)
    if not v or v ~= v then return nil end
    return math.max(min, math.min(max, v))
end

local function cleanString(s, maxLen)
    if type(s) ~= 'string' then return '' end
    s = s:gsub('[^%w_%-%. ]', '')
    return s:sub(1, maxLen)
end

local validEase = {}
for _, e in ipairs(Config.Easings) do validEase[e] = true end

local function sanitizeScene(scene)
    if type(scene) ~= 'table' or type(scene.keyframes) ~= 'table' then return nil end
    if #scene.keyframes > Config.MaxKeyframes then return nil end
    local out = { keyframes = {}, fx = {}, settings = {} }
    for i, k in ipairs(scene.keyframes) do
        if type(k) ~= 'table' then return nil end
        local kf = {
            x = num(k.x, -10000, 10000), y = num(k.y, -10000, 10000), z = num(k.z, -500, 3000),
            rx = num(k.rx, -360, 360), ry = num(k.ry, -360, 360), rz = num(k.rz, -360, 360),
            fov = num(k.fov, Config.FreeCam.MinFov, Config.FreeCam.MaxFov),
            duration = num(k.duration, 0, 120000), hold = num(k.hold, 0, 60000),
            ease = validEase[k.ease] and k.ease or 'linear',
            focus = k.focus == true,
        }
        if not (kf.x and kf.y and kf.z and kf.rx and kf.ry and kf.rz and kf.fov and kf.duration and kf.hold) then return nil end
        out.keyframes[i] = kf
    end
    local fx = type(scene.fx) == 'table' and scene.fx or {}
    out.fx = {
        timecycle = cleanString(fx.timecycle, 64),
        tcStrength = num(fx.tcStrength, 0, 1) or 1.0,
        postfx = cleanString(fx.postfx, 64),
        shake = Config.ShakeStyles[fx.shake] and fx.shake or '',
        shakeAmp = num(fx.shakeAmp, 0, 5) or 0,
        letterbox = num(fx.letterbox, 0, 25) or 0,
        fadeIn = num(fx.fadeIn, 0, 10000) or 0,
        fadeOut = num(fx.fadeOut, 0, 10000) or 0,
    }
    local st = type(scene.settings) == 'table' and scene.settings or {}
    out.settings = { loop = st.loop == true, hidePlayer = st.hidePlayer == true, focusSelf = st.focusSelf == true }
    return out
end

---------------------------------
-- command
---------------------------------
RSGCore.Commands.Add(Config.Command, locale('cmd_help'), {}, false, function(source)
    local src = source
    if not hasAccess(src) then return notify(src, locale('no_permission'), 'error') end
    TriggerClientEvent('rex-moviemaker:client:open', src)
end, Config.Permission or 'user')

---------------------------------
-- callbacks
---------------------------------
lib.callback.register('rex-moviemaker:server:canUse', function(source)
    return RSGCore.Functions.GetPlayer(source) ~= nil and hasAccess(source)
end)

lib.callback.register('rex-moviemaker:server:getScenes', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not hasAccess(source) or onCooldown(source, 'read') then return nil end
    return MySQL.query.await('SELECT id, name FROM rex_moviemaker_scenes WHERE citizenid = ? ORDER BY updated DESC',
        { Player.PlayerData.citizenid }) or {}
end)

lib.callback.register('rex-moviemaker:server:loadScene', function(source, id)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not hasAccess(source) or type(id) ~= 'number' or onCooldown(source, 'read') then return nil end
    local row = MySQL.single.await('SELECT name, data FROM rex_moviemaker_scenes WHERE id = ? AND citizenid = ?',
        { id, Player.PlayerData.citizenid })
    if not row then return nil end
    return { name = row.name, scene = json.decode(row.data) }
end)

lib.callback.register('rex-moviemaker:server:saveScene', function(source, name, scene)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not hasAccess(src) or onCooldown(src, 'write') then return false end
    name = cleanString(name, 40)
    if name == '' then return false end
    local clean = sanitizeScene(scene)
    if not clean then notify(src, locale('save_failed'), 'error') return false end
    local encoded = json.encode(clean)
    if #encoded > Config.MaxSceneSize then notify(src, locale('save_failed'), 'error') return false end

    local cid = Player.PlayerData.citizenid
    local exists = MySQL.scalar.await('SELECT id FROM rex_moviemaker_scenes WHERE citizenid = ? AND name = ?', { cid, name })
    if not exists then
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM rex_moviemaker_scenes WHERE citizenid = ?', { cid }) or 0
        if count >= Config.MaxScenes then notify(src, locale('too_many_scenes'), 'error') return false end
        MySQL.insert.await('INSERT INTO rex_moviemaker_scenes (citizenid, name, data) VALUES (?, ?, ?)', { cid, name, encoded })
    else
        MySQL.update.await('UPDATE rex_moviemaker_scenes SET data = ? WHERE id = ?', { encoded, exists })
    end
    notify(src, locale('scene_saved', name), 'success')
    return true
end)

lib.callback.register('rex-moviemaker:server:deleteScene', function(source, id)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not hasAccess(src) or type(id) ~= 'number' or onCooldown(src, 'write') then return false end
    local affected = MySQL.update.await('DELETE FROM rex_moviemaker_scenes WHERE id = ? AND citizenid = ?',
        { id, Player.PlayerData.citizenid })
    if affected and affected > 0 then notify(src, locale('scene_deleted'), 'success') return true end
    return false
end)

AddEventHandler('playerDropped', function() cooldown[source] = nil end)
