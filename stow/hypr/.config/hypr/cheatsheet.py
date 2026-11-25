#!/usr/bin/env python3
import os
import re
import subprocess
import shutil

hypr_dir = os.path.expanduser("~/.config/hypr")
hyprland_file = os.path.join(hypr_dir, "hyprland.lua")

active_shell = "noctalia"
if os.path.exists(hyprland_file):
    with open(hyprland_file, "r") as f:
        for line in f:
            m = re.match(r'^local\s+active_shell\s*=\s*"([^"]+)"', line.strip())
            if m:
                active_shell = m.group(1)
                break

files_to_parse = [hyprland_file, os.path.join(hypr_dir, f"{active_shell}_settings.lua")]
binds = []

for file in files_to_parse:
    if not os.path.exists(file): continue
    last_comment = ""
    with open(file, "r") as f:
        for line in f:
            sline = line.strip()
            # Capture section comments for context
            if sline.startswith("--") and not sline.startswith("---") and not sline.startswith("-- hl.") and not sline.startswith("-- Brain_Shell"):
                last_comment = sline[2:].strip()
            elif sline.startswith("hl.bind("):
                # Extract keys
                keys_part = sline.split(',', 1)[0].replace('hl.bind(', '').strip()
                keys = keys_part.replace('mainMod .. " + ', 'SUPER + ').replace('mainMod', 'SUPER').replace('"', '').replace(' ', '')
                keys = keys.replace('+', ' + ')
                
                # Extract command/action
                cmd = ""
                exec_m = re.search(r'exec_cmd\("([^"]+)"\)', sline)
                if exec_m:
                    cmd = exec_m.group(1)
                else:
                    dsp_m = re.search(r'hl\.dsp\.([^,\)]+)', sline)
                    if dsp_m:
                        cmd = dsp_m.group(1)
                
                if not cmd:
                    cmd = sline.split(',', 1)[1].strip()
                        
                # Prefer inline comments for description, fallback to section block comment
                inline_m = re.search(r'\}\)\s*--\s*(.*)$', sline)
                if not inline_m:
                    inline_m = re.search(r'\)\s*--\s*(.*)$', sline)
                    
                desc = inline_m.group(1) if inline_m else last_comment
                
                if desc:
                    binds.append(f"{keys.ljust(25)} │ {desc[:35].ljust(35)} │ {cmd}")
                else:
                    binds.append(f"{keys.ljust(25)} │ {''.ljust(35)} │ {cmd}")

output = "\n".join(binds)

if shutil.which("fuzzel"):
    subprocess.run(["fuzzel", "--dmenu", "-w", "100", "-p", f"Keybinds ({active_shell}) > "], input=output.encode('utf-8'))
elif shutil.which("rofi"):
    subprocess.run(["rofi", "-dmenu", "-i", "-p", f"Keybinds ({active_shell})", "-theme-str", "window {width: 60%;}"], input=output.encode('utf-8'))
