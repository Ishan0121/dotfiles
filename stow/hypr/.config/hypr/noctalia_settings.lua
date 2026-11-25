local mainMod = "SUPER"

-- Laptop multimedia keys for volume and LCD brightness (Noctalia)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("noctalia msg volume-up"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("noctalia msg volume-down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("noctalia msg volume-mute"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("noctalia msg mic-mute"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("noctalia msg brightness-up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("noctalia msg brightness-down"), { locked = true, repeating = true })

-- Media control (Noctalia)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("noctalia msg media next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("noctalia msg media toggle"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("noctalia msg media toggle"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("noctalia msg media previous"),   { locked = true })
hl.bind("XF86AudioStop",  hl.dsp.exec_cmd("noctalia msg media stop"), { locked = true })

-- Noctalia Panels
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("noctalia msg panel-toggle clipboard"))
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("noctalia msg panel-toggle ishan0121/wallpaper-deck:picker"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("noctalia msg wallpaper-next"))
hl.bind(mainMod .. " + CTRL + W", hl.dsp.exec_cmd("noctalia msg wallpaper-previous"))
hl.bind("ALT + Tab", hl.dsp.exec_cmd("noctalia msg window-switcher"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("noctalia msg panel-toggle control-center"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("noctalia msg settings-toggle"))
hl.bind(mainMod .. " + SHIFT + slash", hl.dsp.exec_cmd("noctalia msg panel-toggle kenn/keybind-cheatsheet:cheatsheet"))

-- Noctalia Session and System Controls
hl.bind(mainMod .. " + ALT + L", hl.dsp.exec_cmd("noctalia msg session lock"))
hl.bind(mainMod .. " + ALT + S", hl.dsp.exec_cmd("noctalia msg session suspend"))
hl.bind(mainMod .. " + ALT + R", hl.dsp.exec_cmd("noctalia msg session reboot"))
hl.bind(mainMod .. " + ALT + P", hl.dsp.exec_cmd("noctalia msg session shutdown"))
hl.bind(mainMod .. " + ALT + Q", hl.dsp.exec_cmd("noctalia msg session logout"))
-- hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("noctalia msg session logout"))

-- Noctalia Toggles
hl.bind(mainMod .. " + ALT + W", hl.dsp.exec_cmd("noctalia msg wifi-toggle"))
hl.bind(mainMod .. " + ALT + B", hl.dsp.exec_cmd("noctalia msg bluetooth-toggle"))
hl.bind(mainMod .. " + ALT + M", hl.dsp.exec_cmd("noctalia msg mic-mute"))
hl.bind(mainMod .. " + ALT + V", hl.dsp.exec_cmd("noctalia msg volume-mute"))
hl.bind(mainMod .. " + ALT + T", hl.dsp.exec_cmd("noctalia msg theme-mode-toggle"))
hl.bind(mainMod .. " + ALT + I", hl.dsp.exec_cmd("noctalia msg nightlight-toggle"))
hl.bind(mainMod .. " + ALT + C", hl.dsp.exec_cmd("noctalia msg caffeine-toggle"))
hl.bind(mainMod .. " + ALT + D", hl.dsp.exec_cmd("noctalia msg dock-toggle"))
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd("noctalia msg desktop-widgets-toggle"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("noctalia msg notification-clear-active"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("noctalia msg notification-dnd-toggle"))

-- Screenshots
hl.bind("Print", hl.dsp.exec_cmd("noctalia msg screenshot-fullscreen"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("noctalia msg screenshot-region"))


