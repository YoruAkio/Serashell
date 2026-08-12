hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ name = "fix-xwayland-drags", match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false }, no_focus = true })

for _, rule in ipairs({
    { name = "float-pip", match = { title = "^(Picture-in-Picture)$" }, float = true, size = "960 540", move = "25%- 0" },
    { name = "float-media", match = { title = "^(imv|mpv|danmufloat|termfloat|nemo|ncmpcpp)$" }, float = true, size = "960 540", move = "25%- 0" },
    { name = "float-waydroid", match = { class = "^(Waydroid)$" }, float = true, size = "1280 720", center = true },
    { name = "float-pavucontrol", match = { class = "^(org.pulseaudio.pavucontrol|pavucontrol-qt)$" }, float = true },
    { name = "float-picture-in-picture", match = { class = "^()$", title = "^(Picture in picture)$" }, float = true },
    { name = "float-save-file", match = { class = "^()$", title = "^(Save File)$" }, float = true },
    { name = "float-open-file", match = { class = "^()$", title = "^(Open File)$" }, float = true },
    { name = "float-zen-pip", match = { class = "^(ZenBrowser)$", title = "^(Picture-in-Picture)$" }, float = true },
    { name = "float-blueman", match = { class = "^(blueman-manager)$" }, float = true },
    { name = "float-bitwarden", match = { class = "^(chrome-nngceckbapebfimnlniiiahkandclblb-Default)$" }, float = true },
    { name = "float-xdg-portal", match = { class = "^(xdg-desktop-portal-gtk|xdg-desktop-portal-kde|xdg-desktop-portal-hyprland)(.*)$" }, float = true },
    { name = "float-polkit", match = { class = "^(polkit-gnome-authentication-agent-1|hyprpolkitagent|org.org.kde.polkit-kde-authentication-agent-1)(.*)$" }, float = true },
    { name = "float-zenity", match = { class = "^(zenity)$" }, float = true },
    { name = "float-steam-updater", match = { class = "^()$", title = "^(Steam - Self Updater)$" }, float = true },
    { name = "float-dell-controller", match = { class = "^(python3)$", title = "^(Dell G Series Controller)$" }, float = true },
    { name = "float-thunar-rename", match = { class = "^(thunar)$", title = "^(Rename.*)$" }, float = true, size = "500 200" },
    { name = "float-thunar-progress", match = { class = "^(thunar)$", title = "^(File Operation Progress)$" }, float = true },
    { name = "float-thunar-confirm", match = { class = "^(thunar)$", title = "^(Confirm.*)$" }, float = true },
    { name = "float-thunar-question", match = { class = "^(thunar)$", title = "^(Question)$" }, float = true },
    { name = "float-thunar-create", match = { class = "^(thunar)$", title = "^(Create.*)$" }, float = true },
    { name = "float-thunar-properties", match = { class = "^(thunar)$", title = "^(Properties)$" }, float = true, size = "600 500" },
    { name = "center-thunar-dialogs", match = { class = "^(thunar)$", title = "^(Rename.*|File Operation Progress|Confirm.*|Question|Create.*|Properties)$" }, center = true },
}) do
    hl.window_rule(rule)
end
