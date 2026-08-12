local programs = require("config/programs")
local mod = "SUPER"

hl.bind(mod .. " + Return", hl.dsp.exec_cmd(programs.terminal))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(programs.file_manager))
hl.bind(mod .. " + R", hl.dsp.exec_cmd("qs ipc call pill toggleLauncher"))
hl.bind(mod .. " + X", hl.dsp.exec_cmd(programs.scripts .. "/powermenu.sh"))
hl.bind(mod .. " + V", hl.dsp.exec_cmd("qs ipc call pill toggleClipboard"))
hl.bind(mod .. " + Period", hl.dsp.exec_cmd("qs ipc call pill toggleEmoji"))
hl.bind("ALT + SPACE", hl.dsp.exec_cmd("pkill -USR2 -x handy"))
hl.bind(mod .. " + LEFT", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + RIGHT", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("PRINT", hl.dsp.exec_cmd(programs.scripts .. "/screenshot.sh output"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd(programs.scripts .. "/screenshot.sh region-clipboard"))
hl.bind(mod .. " + CTRL + S", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/wf-record-fuzzel"))
hl.bind(mod .. " + PRINT", hl.dsp.exec_cmd(programs.scripts .. "/screenshot.sh region"))
hl.bind(mod .. " + P", hl.dsp.exec_cmd("hyprpicker --autocopy"))
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd(programs.scripts .. "/reload-hypr.sh"))
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd("qs ipc call pill toggleWallpaper || " .. programs.scripts .. "/random-wallpaper.sh"))
hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd("qs ipc call pill toggleTheme || " .. programs.scripts .. "/theme-mode.sh"))
hl.bind(mod .. " + ALT + L", hl.dsp.exec_cmd("loginctl lock-session"))

for key, direction in pairs({ h = "l", l = "r", j = "u", k = "d" }) do
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = direction }))
end

for workspace = 1, 10 do
    local key = workspace % 10
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

for key, direction in pairs({ H = "l", L = "r", K = "u", J = "d" }) do
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = direction }))
end

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

for key, command in pairs({
    XF86AudioRaiseVolume = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+",
    XF86AudioLowerVolume = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
    XF86AudioMute = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
    XF86AudioMicMute = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",
    XF86MonBrightnessUp = "brightnessctl set +2%",
    XF86MonBrightnessDown = "brightnessctl set 2%-",
}) do
    hl.bind(key, hl.dsp.exec_cmd(command), { locked = true, repeating = true })
end

for key, command in pairs({
    XF86AudioNext = "playerctl next",
    XF86AudioPause = "playerctl play-pause",
    XF86AudioPlay = "playerctl play-pause",
    XF86AudioPrev = "playerctl previous",
}) do
    hl.bind(key, hl.dsp.exec_cmd(command), { locked = true })
end
