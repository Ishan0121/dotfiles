-- This is an example Hyprland Lua config file.
-- Refer to the wiki for more information.
-- https://wiki.hypr.land/Configuring/Start/

-- Please note not all available settings / options are set here.
-- For a full list, see the wiki

-- You can (and should!!) split this configuration into multiple files
-- Create your files separately and then require them like this:
-- require("myColors")


------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- External monitors (Left)
hl.monitor({
    output   = "HDMI-A-1",
    mode     = "1920x1080@60",
    position = "0x0",
    scale    = "1",
})
hl.monitor({
    output   = "DP-1",
    mode     = "preferred",
    position = "0x0",
    scale    = "1",
})

-- Laptop monitor (Right)
hl.monitor({
    output   = "eDP-1",
    mode     = "preferred",
    position = "1920x0",
    scale    = "1",
})

-- Fallback for any other monitors
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "1",
})

---------------------
---- MY PROGRAMS ----
---------------------

-- ACTIVE SHELL SELECTION
-- Switch this variable to "noctalia", "caelestia", or "dms"
local active_shell = "noctalia" 

-- LIVE WALLPAPER CONFIGURATION
local use_live_wallpaper = false
local live_wallpaper_dir = "~/Pictures/live wallpapers/" -- Change to your folder path

-- Set programs that you use
local terminal    = "kitty"
local fileManager = "strata"
local menu
if active_shell == "noctalia" then
    menu = "noctalia msg panel-toggle launcher"
elseif active_shell == "caelestia" then
    menu = "caelestia shell drawers toggle launcher"
elseif active_shell == "dms" then
    menu = "dms ipc call launcher toggle"
end


-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
hl.on("hyprland.start", function () 
    -- hl.exec_cmd(terminal)
    -- hl.exec_cmd("waybar & hyprpaper & firefox")
    
    -- NetworkManager applet
    -- hl.exec_cmd("nm-applet --indicator")
    
    -- Polkit for authentication
    -- hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    
    -- Clipboard manager (cliphist)
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "20")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "20")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("GTK_THEME", "Colloid-Dark-Nord")


-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 7,

        border_size = 2,

        col = {
            active_border   = { colors = {"rgba(33ccffee)", "rgba(00ff99ee)"}, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 5,
        rounding_power = 2,

        -- Change transparency of focused and unfocused windows
        active_opacity   = 0.99,
        inactive_opacity = 0.96,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled   = false,
            size      = 3,
            passes    = 2,
            vibrancy  = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- Default springs
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "master",
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = -1,    -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = false, -- If true disables the random hyprland logo / anime girl background. :(
        focus_on_activate = true,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        numlock_by_default = true,

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            disable_while_typing = true, -- true/false
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- 1. Software / Applications (SUPER + SHIFT + [char])
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal)) -- Kept as SUPER+Return per user preference
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd("google-chrome-stable")) -- Browser (OmaCheatSheet)
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("google-chrome-stable")) -- Browser (Legacy)
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ action = "toggle" })) -- Fullscreen (matches Niri Mod+Shift+F)
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(fileManager)) -- File Manager (Legacy & Niri)
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("code"))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd("antigravity-ide"))
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.exec_cmd(terminal .. " -- agy")) -- Agent (OmaCheatSheet)
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.exec_cmd("google-chrome-stable --app=https://gemini.google.com")) -- Custom mapping
hl.bind(mainMod .. " + SHIFT + O", hl.dsp.exec_cmd("google-chrome-stable --app=https://chatgpt.com")) -- Custom mapping
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("youtube-music")) -- Music (Added from OmaCheatSheet)
hl.bind(mainMod .. " + SHIFT + Y", hl.dsp.exec_cmd("google-chrome-stable --app=https://youtube.com")) -- YouTube (Added from OmaCheatSheet)
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("google-chrome-stable --app=https://photos.google.com")) -- Photos (Added from OmaCheatSheet)
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd("discord")) -- Discord (Added)
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("voxtype record toggle")) -- Kept as SUPER+H per user preference
hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd("code ~/.config/hypr")) -- Open hypr config in VS Code
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("emote")) -- Open emote emoji picker

-- 2. Core Window Management (SUPER + [char])
hl.bind(mainMod .. " + Q", hl.dsp.window.close()) -- Close Window (Kept per user preference)
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" })) -- Toggle float/tiling (OmaCheatSheet)
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("~/.config/hypr/maximize_isolate.sh")) -- Maximize and isolate
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))    -- dwindle only
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload")) -- Reload Hyprland

-- 3. Utilities & System (SUPER + CTRL / ALT + [char] or special)
hl.bind(mainMod .. " + escape", hl.dsp.exec_cmd("nwgbar")) -- Garuda power menu
hl.bind(mainMod .. " + slash", hl.dsp.exec_cmd("python3 ~/.config/hypr/cheatsheet.py")) -- Show keybinds cheatsheet (Legacy)
hl.bind(mainMod .. " + K", hl.dsp.exec_cmd("python3 ~/.config/hypr/cheatsheet.py")) -- Show keybinds cheatsheet (OmaCheatSheet)
hl.bind(mainMod .. " + SHIFT + slash", hl.dsp.exec_cmd("noctalia msg panel-toggle kenn/keybind-cheatsheet:cheatsheet")) -- Noctalia cheatsheet
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("noctalia msg panel-toggle clipboard")) -- Noctalia clipboard history
hl.bind("CTRL + ALT + delete", hl.dsp.exec_cmd("hyprctl dispatch exit")) -- Exit compositor

-- Resize Submap (Garuda style)
hl.bind(mainMod .. " + R", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
    hl.bind("right", hl.dsp.window.resize({ x = 50,  y = 0,   relative = true }), { repeating = true })
    hl.bind("L",     hl.dsp.window.resize({ x = 50,  y = 0,   relative = true }), { repeating = true })
    hl.bind("left",  hl.dsp.window.resize({ x = -50, y = 0,   relative = true }), { repeating = true })
    hl.bind("H",     hl.dsp.window.resize({ x = -50, y = 0,   relative = true }), { repeating = true })
    hl.bind("up",    hl.dsp.window.resize({ x = 0,   y = -50, relative = true }), { repeating = true })
    hl.bind("K",     hl.dsp.window.resize({ x = 0,   y = -50, relative = true }), { repeating = true })
    hl.bind("down",  hl.dsp.window.resize({ x = 0,   y = 50,  relative = true }), { repeating = true })
    hl.bind("J",     hl.dsp.window.resize({ x = 0,   y = 50,  relative = true }), { repeating = true })
    hl.bind("escape", hl.dsp.submap("reset"))
end)

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Move window in direction with mainMod + SHIFT + arrow keys
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))

-- Switch workspaces with mainMod + CTRL + arrow keys (left/right)
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.focus({ workspace = "e+1" }))

-- -- Window Grouping (Tiling Tabs)
-- hl.bind(mainMod .. " + T", hl.dsp.group.toggle())
-- hl.bind(mainMod .. " + Tab", hl.dsp.group.next())
-- hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.group.prev())

-- Go to empty workspace
hl.bind(mainMod .. " + equal", hl.dsp.focus({ workspace = "empty" }))
hl.bind(mainMod .. " + plus",  hl.dsp.focus({ workspace = "empty" }))

-- Move window to workspace with mainMod + CTRL + SHIFT + arrow keys (left/right)
hl.bind(mainMod .. " + CTRL + SHIFT + left",  hl.dsp.window.move({ workspace = "e-1" }))
hl.bind(mainMod .. " + CTRL + SHIFT + right", hl.dsp.window.move({ workspace = "e+1" }))

-- Switch monitors with mainMod + ALT + arrow keys (left/right)
hl.bind(mainMod .. " + ALT + left",  hl.dsp.focus({ monitor = "l" }))
hl.bind(mainMod .. " + ALT + right", hl.dsp.focus({ monitor = "r" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Example special workspace (scratchpad) (Commented out to use Mod+S for Noctalia Control Center)
-- hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
-- hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness



--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    name = "float-noctalia",
    match = { class = "dev.noctalia.noctalia" },
    float = true,
    size = "1080 920",
})

-- Garuda tools window rules
hl.window_rule({ match = { class = "garuda-assistant" },         float = true })
hl.window_rule({ match = { class = "garuda-boot-options" },      float = true })
hl.window_rule({ match = { class = "garuda-boot-repair" },       float = true })
hl.window_rule({ match = { class = "garuda-gamer" },             float = true })
hl.window_rule({ match = { class = "garuda-network-assistant" }, float = true })
hl.window_rule({ match = { class = "garuda-settings-manager" },  float = true })
hl.window_rule({ match = { class = "garuda-welcome" },           float = true })
hl.window_rule({ match = { class = "calamares" },                float = true })

-- overview
-- hl.on("hyprland.start", function () 
--     hl.exec_cmd("qs -c overview")
-- end)

-- hl.bind("SUPER + TAB", hl.dsp.exec_cmd("qs ipc -c overview call overview toggle"))

--------------------
----- SHELL SETUP -----
--------------------
if active_shell == "noctalia" then
    hl.on("hyprland.start", function()
        hl.exec_cmd("noctalia")
    end)
    require("noctalia_settings")
elseif active_shell == "caelestia" then
    hl.on("hyprland.start", function()
        hl.exec_cmd("qs -c caelestia")
    end)
    require("caelestia_settings")
elseif active_shell == "dms" then
    hl.on("hyprland.start", function()
        hl.exec_cmd("dms run")
    end)
    require("dms/layout")
    require("dms/windowrules")
    require("dms_settings")
end

-- Live Wallpaper Setup
if use_live_wallpaper then
    hl.on("hyprland.start", function()
        -- Ensure any existing instance is killed
        hl.exec_cmd("killall mpvpaper")
        
        -- Start mpvpaper in the background with a random video from the directory
        -- using the newly created helper script
        hl.exec_cmd("~/.config/hypr/scripts/live_wallpaper.sh")
        
        -- Try to clear the native shell wallpapers after a short delay
        -- so they don't consume resources behind mpvpaper
        if active_shell == "dms" then
            hl.exec_cmd("sleep 2 && dms ipc call wallpaper clear")
        elseif active_shell == "noctalia" then
            -- Noctalia doesn't have a clear command but we can try setting an empty wallpaper
            -- Note: mpvpaper covers it automatically since it spawns later on the same layer
        elseif active_shell == "caelestia" then
            -- Similar to Noctalia, mpvpaper will cover it.
        end
    end)

    -- Override wallpaper keybindings to work with mpvpaper
    local override_msg = "notify-send 'Live Wallpaper' 'Picker not available for live wallpapers.'"
    hl.bind("SUPER + W", hl.dsp.exec_cmd(override_msg))
    hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("~/.config/hypr/scripts/live_wallpaper.sh"))
    hl.bind("SUPER + CTRL + W", hl.dsp.exec_cmd("~/.config/hypr/scripts/live_wallpaper.sh"))
end

-- Brain_ShellKeybinds
-- dofile(os.getenv("HOME") .. "/.config/Brain_Shell/Brain_ShellKeybinds.lua")

-- HyprMod managed settings
require("hyprland-gui")


-- For Noctalia Color templates
require("noctalia").apply_theme()


-- >>> HYPRLAND VISUAL EDITOR (HVE) <<<
pcall(function() dofile(os.getenv("HOME") .. "/.cache/noctalia/HVE/overlay.lua") end)
-- <<< HYPRLAND VISUAL EDITOR (HVE) <<<
