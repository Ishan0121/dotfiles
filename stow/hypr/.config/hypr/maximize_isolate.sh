#!/bin/bash
# maximize_isolate.sh
# Maximizes the current window and moves all other windows on the same workspace to an empty workspace.
# When un-maximizing, it restores the isolated windows back to the original workspace.

ACTIVE_WORKSPACE=$(hyprctl activeworkspace -j | jq -r '.id')
ACTIVE_WINDOW=$(hyprctl activewindow -j)
IS_FULLSCREEN=$(echo "$ACTIVE_WINDOW" | jq -r '.fullscreen')

STATE_FILE="/tmp/hypr_max_state_${ACTIVE_WORKSPACE}"

if [ "$IS_FULLSCREEN" = "true" ] || [ "$IS_FULLSCREEN" = "1" ] || [ "$IS_FULLSCREEN" = "2" ]; then
    # Currently maximized/fullscreen, so we restore
    hyprctl dispatch "hl.dsp.window.fullscreen({ mode = 'maximized', action = 'toggle' })"
    
    if [ -f "$STATE_FILE" ]; then
        while read -r addr; do
            # Move the previously isolated windows back to this workspace
            hyprctl dispatch "hl.dsp.window.move({ workspace = '$ACTIVE_WORKSPACE', window = 'address:$addr', follow = false })"
        done < "$STATE_FILE"
        rm -f "$STATE_FILE"
    fi
else
    # Not maximized, so we isolate and maximize
    ACTIVE_ADDR=$(echo "$ACTIVE_WINDOW" | jq -r '.address')
    
    # Clear old state file if it exists
    rm -f "$STATE_FILE"
    
    # Find other windows on this workspace
    OTHER_WINDOWS=$(hyprctl clients -j | jq -r ".[] | select(.workspace.id == $ACTIVE_WORKSPACE and .address != \"$ACTIVE_ADDR\") | .address")
    
    if [ -n "$OTHER_WINDOWS" ]; then
        # Find the first available empty workspace
        TARGET_WORKSPACE=1
        WORKSPACES_JSON=$(hyprctl workspaces -j)
        while echo "$WORKSPACES_JSON" | jq -e ".[] | select(.id == $TARGET_WORKSPACE)" > /dev/null 2>&1; do
            TARGET_WORKSPACE=$((TARGET_WORKSPACE + 1))
        done
        
        # Move all other windows to this target workspace
        for addr in $OTHER_WINDOWS; do
            echo "$addr" >> "$STATE_FILE"
            hyprctl dispatch "hl.dsp.window.move({ workspace = '$TARGET_WORKSPACE', window = 'address:$addr', follow = false })"
        done
    fi
    
    # Finally, maximize the current window
    hyprctl dispatch "hl.dsp.window.fullscreen({ mode = 'maximized', action = 'toggle' })"
fi
