hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 8,
        border_size = 3,
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
        col = {
            active_border = "rgba(2d4f67ee)",
            inactive_border = "rgba(16161daa)",
        },
    },
    decoration = {
        rounding = 14,
        rounding_power = 5,
        active_opacity = 1,
        shadow = { enabled = false },
        blur = { enabled = true },
    },
    dwindle = { preserve_split = true },
    master = { new_status = "master", mfact = 0.7 },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        middle_click_paste = false,
    },
})
