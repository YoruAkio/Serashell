local scripts = os.getenv("HOME") .. "/.config/scripts"

hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")
    hl.exec_cmd("nm-applet & blueman-applet")
    hl.exec_cmd("waybar & dunst")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd(scripts .. "/load-wallpaper.sh")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)
