#!/usr/bin/env bash
#
# Launch a power menu
#
# Requirement: fzf
#
# Author:  Jesse Mirabel <sejjymvm@gmail.com>
# Date:    August 19, 2025
# License: MIT

# shellcheck disable=SC1090
colors=()
source ~/.config/waybar/scripts/fzf-colorizer.sh &> /dev/null || true

main() {
 	local list=(
 		"Verrouiller"
 		"Éteindre"
 		"Redémarrer"
 		"Déconnexion"
 		"Hibernation"
 		"Suspension"
 	)

	local options=(
		"--border=sharp"
 		"--border-label= Menu d'alimentation "
		"--height=~100%"
		"--highlight-line"
		"--no-input"
		"--pointer="
		"--reverse"
		"${colors[@]}"
	)

	local selected
	selected=$(printf "%s\n" "${list[@]}" | fzf "${options[@]}")

 	case $selected in
 		"Verrouiller") loginctl lock-session ;;
 		"Éteindre") systemctl poweroff ;;
 		"Redémarrer") systemctl reboot ;;
 		"Déconnexion") loginctl terminate-session "$XDG_SESSION_ID" ;;
 		"Hibernation") systemctl hibernate ;;
 		"Suspension") systemctl suspend ;;
 		*) exit 1 ;;
 	esac
}

main
