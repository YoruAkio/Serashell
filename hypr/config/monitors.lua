hl.monitor({ output = "eDP-1", mode = "1920x1080@60.03", position = "1920x0", scale = 1 })
hl.monitor({ output = "HDMI-A-2", mode = "1920x1080@120", position = "0x0", scale = 1, transform = 2 })

for workspace = 1, 5 do
    hl.workspace_rule({ workspace = tostring(workspace), monitor = "eDP-1", default = workspace == 1 })
end

for workspace = 6, 10 do
    hl.workspace_rule({ workspace = tostring(workspace), monitor = "HDMI-A-2", default = workspace == 6 })
end
