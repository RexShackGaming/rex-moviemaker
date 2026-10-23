# rex-moviemaker

A cinematic camera system for RSG Framework (RedM). Build smooth camera travels from multiple positions, add visual effects, lock focus on any entity and play back clean shots ready to record.

## Features
- **Director free camera:** fly, look, roll and zoom, with fast and slow speed modifiers. It stays within a set distance of your character.
- **Keyframe camera travels:**
  - the camera follows a smooth curve through every point and always takes the short way round when it turns
  - each keyframe has its own travel time, hold time, easing, FOV and roll
  - keyframes can be viewed, set to the current view, reordered, deleted, or played from
  - the total clip length is shown live
- **Entity focus:** lock the camera onto any ped, animal, horse, wagon or object under the crosshair, or yourself, and choose which keyframes track it.
- **Visual effects:**
  - timecycle colour grading with strength
  - animated post FX
  - camera shake: smooth Lua styles, plus real game shakes verified against the decompiled RDR3 scripts
  - letterbox bars, fade in and fade out
  - live preview of the current settings
- **Clean recording:** the HUD and editor are hidden during playback, your character can be hidden too, playback can loop, and Backspace stops it.
- **Saved scenes:** save, load and delete scenes for each character in the database. The database table is created automatically.
- **NUI:** styled to the house look, with custom HTML dropdowns (no native popups) and all text in `locales/en.json`.

## Requirements
- rsg-core
- ox_lib
- oxmysql

## Installation
1. Place `rex-moviemaker` in your resources folder.
2. Add `ensure rex-moviemaker` after rsg-core, ox_lib and oxmysql.
3. Restart the server. The `rex_moviemaker_scenes` table is created on first start. `installation/rex-moviemaker.sql` is included if you prefer to install it by hand.
4. Set `Config.Permission` in `shared/config.lua`. The default is `admin`; set it to `false` to let everyone use it.

## Usage
Use `/moviemaker` to open the editor. Press the ◉ button to fly the camera.

| Key | Fly mode |
|---|---|
| W / A / S / D | Move |
| Q / Z | Up / Down |
| Mouse | Look |
| X / C | Roll |
| Scroll | Zoom (FOV) |
| Shift / Ctrl | Fast / Slow |
| E | Add keyframe |
| F | Lock focus on the entity under the crosshair |
| Backspace | Back to editor (or stop playback) |

Esc closes the editor.

## Languages
Included: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. All notifications and all UI text (panel, fly-mode help, dropdown labels) come from `locales/*.json`.
Set the language with the ox_lib convar in `server.cfg`, e.g. `setr ox:locale de`. To add a language, copy `locales/en.json` to `locales/<code>.json` and translate the values (keep every `%s`).

## Configuration notes
- **Effect presets:** `Config.Timecycles` and `Config.PostFx` are presets only, and the panel also accepts any name typed in. Check names against rdr3_discoveries before adding them.
- **Game shakes:** a shake name the game doesn't have will crash it. Only add names found in the decompiled RDR3 scripts.
- **Focus targets:** an entity focus target is not saved with a scene. Lock onto it again after loading.
- **Hide my character:** this uses `SetEntityVisible`, so other players won't see you during playback either.

## Security
- The server checks permission for the command and again when the editor opens, so the free camera can't be opened by triggering the client event.
- All scene data is rebuilt and range-checked on the server, with size, keyframe and scene-count limits.
- Players can only read, load or delete their own scenes.
- Reads and writes are rate-limited.

Support: https://buymeacoffee.com/rexshack
