# This is your bash shell configuration file! You can edit this file to customize your bash shell experience.
# IMPORTANT! The Garuda Linux defaults are set in /usr/share/garuda/garuda-bash-config/bashrc.
# IMPORTANT! Do not edit the defaults file directly, as it will be overwritten during system updates. (You can however read it to learn and get ideas!)
# Instead, you simply add your customizations to this file, and they will override the defaults.
source /usr/share/garuda/garuda-bash-config/bashrc

# -- Insert customizations below this line! --
export GTK_THEME="Colloid-Dark-Nord"

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
