#!/usr/bin/env bash
#
# Scan, select, and connect to Wi-Fi networks
#
# Requirements:
# 	nmcli (networkmanager)
# 	fzf
# 	notify-send (libnotify)
#
# Author:  Jesse Mirabel <sejjymvm@gmail.com>
# Date:    August 11, 2025
# License: MIT

# shellcheck disable=SC1090
colors=()
source ~/.config/waybar/scripts/fzf-colorizer.sh &> /dev/null || true

RED="\e[31m"
RESET="\e[39m"

TIMEOUT=5

ensure-enabled() {
	local state
	state=$(nmcli radio wifi)

	if [[ $state == "enabled" ]]; then
		return 0
	fi

	nmcli radio wifi on

	local i new_state
	for ((i = 1; i <= TIMEOUT; i++)); do
 		printf "\rActivation du Wi-Fi... (%d/%d)" $i $TIMEOUT

		new_state=$(nmcli -t -f STATE general)
		if [[ $new_state != "connected (local only)" ]]; then
			break
		fi

		sleep 1
	done

 	notify-send "Wi-Fi activé" -i "network-wireless-on" \
		-h string:x-canonical-private-synchronous:network
}

get-network-list() {
	nmcli device wifi rescan

	local i
	for ((i = 1; i <= TIMEOUT; i++)); do
 		printf "\rRecherche de réseaux... (%d/%d)" $i $TIMEOUT

		list=$(timeout 1 nmcli device wifi list)
		networks=$(tail -n +2 <<< "$list" | awk '$2 != "--"')

		if [[ -n $networks ]]; then
			break
		fi
	done

 	printf "\n%bRecherche arrêtée.%b\n\n" "$RED" "$RESET"

	if [[ -z $networks ]]; then
 		notify-send "Wi-Fi" "Aucun réseau trouvé" -i "package-broken"
		return 1
	fi
}

select-network() {
	local header
	header=$(head -n 1 <<< "$list")

	local options=(
		"--border=sharp"
 		"--border-label= Réseaux Wi-Fi "
		"--ghost=Search"
		"--header=$header"
		"--height=~100%"
		"--highlight-line"
		"--info=inline-right"
		"--pointer="
		"--reverse"
		"${colors[@]}"
	)

	bssid=$(fzf "${options[@]}" <<< "$networks" | awk '{print $1}')

	case $bssid in
		"") return 1 ;;
		"*")
 			notify-send "Wi-Fi" "Déjà connecté à ce réseau" \
				-i "package-install"
			return 1
			;;
	esac
}

connect() {
 	printf "Connexion...\n"

	if ! nmcli -a device wifi connect "$bssid"; then
 		notify-send "Wi-Fi" "Échec de la connexion" -i "package-purge"
		return 1
	fi

 	notify-send "Wi-Fi" "Connexion réussie" -i "package-install"
}

main() {
	printf "\e[?25l"
	ensure-enabled || exit 1
	get-network-list || exit 1
	printf "\e[?25h"
	select-network || exit 1
	connect || exit 1
}

main
