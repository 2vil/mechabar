#!/usr/bin/env bash
#
# Check for official and AUR package updates and upgrade them. When run with the
# "module" argument, output the status icon and update counts in JSON format for
# Waybar
#
# Requirements:
# 	checkupdates (pacman-contrib)
# 	notify-send (libnotify)
# 	Optional: An AUR helper
#
# Author:  Jesse Mirabel <sejjymvm@gmail.com>
# Date:    August 16, 2025
# License: MIT

GREEN="\e[32m"
BLUE="\e[34m"
RESET="\e[39m"

TIMEOUT=10
HELPERS=("aura" "paru" "pikaur" "trizen" "yay")

detect-helper() {
	local h
	for h in "${HELPERS[@]}"; do
		if command -v "$h" > /dev/null; then
			helper=$h
			break
		fi
	done
}

check-updates() {
	success=true
	pacman=0
	aur=0

	local p_output p_status
	p_output=$(timeout $TIMEOUT checkupdates)
	p_status=$?

	if ((p_status != 0 && p_status != 2)); then
		success=false
		return 1
	fi

	pacman=$(grep -cve "^\s*$" <<< "$p_output")

	if [[ -z $helper ]]; then
		return 0
	fi

	local a_output a_status
	a_output=$(timeout $TIMEOUT "$helper" -Quaq)
	a_status=$?

	if ((${#a_output} > 0 && a_status != 0)); then
		success=false
		return 1
	fi

	aur=$(grep -cve "^\s*$" <<< "$a_output")
}

update-packages() {
 	printf "\n%bMise à jour des paquets pacman...%b\n" "$BLUE" "$RESET"
	sudo pacman -Syu

	if [[ -n $helper ]]; then
 		printf "\n%bMise à jour des paquets AUR...%b\n" "$BLUE" "$RESET"
		command "$helper" -Syu
	fi

 	notify-send "Mise à jour terminée" -i "package-install"

 	printf "\n%bMise à jour terminée !%b\n" "$GREEN" "$RESET"
	read -rsn 1 -p "Press any key to exit..."
}

display-module() {
	if [[ $success == false ]]; then
 		echo "{ \"text\": \"󰒑\", \"tooltip\": \"Impossible de récupérer les mises à jour. Clic droit pour réessayer.\" }"
		return 0
	fi

 	local tooltip="<b>Officiel</b>: $pacman"
 	if [[ -n $helper ]]; then
 		tooltip+="\n<b>AUR($helper)</b>: $aur"
 	fi

	if ((pacman + aur == 0)); then
 		echo "{ \"text\": \"󰸟\", \"tooltip\": \"Aucune mise à jour disponible\" }"
	else
		echo "{ \"text\": \"󰄠\", \"tooltip\": \"$tooltip\" }"
	fi
}

main() {
	detect-helper

	case $1 in
		"module")
			check-updates
			display-module
			;;
		*)
 		printf "%bVérification des mises à jour...%b" "$BLUE" "$RESET"
			check-updates
			update-packages
			pkill -RTMIN+1 waybar
			;;
	esac
}

main "$@"
