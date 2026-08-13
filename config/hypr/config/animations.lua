hl.config({ animations = { enabled = true } })
hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1 } } })

for _, animation in ipairs({
    { leaf = "layers", speed = 2 },
    { leaf = "windows", speed = 2 },
    { leaf = "border", speed = 2 },
    { leaf = "borderangle", speed = 2 },
    { leaf = "fade", speed = 2 },
    { leaf = "workspaces", speed = 2 },
    { leaf = "specialWorkspace", speed = 2, style = "slidefadevert" },
    { leaf = "windowsOut", speed = 2, style = "popin 80%" },
}) do
    animation.enabled = true
    animation.bezier = "default"
    hl.animation(animation)
end
