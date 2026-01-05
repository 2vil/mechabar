#!/usr/bin/env bash
#
# Scan, select, pair, and connect to Bluetooth devices
#
# Requirements:
# 	bluetoothctl (bluez-utils)
# 	fzf
# 	notify-send (libnotify)
#
# Author:  Jesse Mirabel <sejjymvm@gmail.com>
# Date:    August 19, 2025
# License: MIT

# shellcheck disable=SC1090
colors=()
source ~/.config/waybar/scripts/fzf-colorizer.sh &> /dev/null || true

RED="\e[31m"
RESET="\e[39m"

TIMEOUT=10

ensure-on() {
	local state
	state=$(bluetoothctl show | awk '/PowerState/ {print $2}')

	case $state in
		"off") bluetoothctl power on > /dev/null ;;
		"off-blocked")
			rfkill unblock bluetooth

			local i new_state
			for ((i = 1; i <= TIMEOUT; i++)); do
 				printf "\rDéblocage du Bluetooth... (%d/%d)" $i $TIMEOUT

				new_state=$(bluetoothctl show | awk '/PowerState/ {print $2}')
				if [[ $new_state == "on" ]]; then
					break
				fi

				sleep 1
			done

			if [[ $new_state != "on" ]]; then
 			notify-send "Bluetooth" "Échec du déblocage" -i "package-purge"
				return 1
			fi
			;;
		*) return 0 ;;
	esac

 	notify-send "Bluetooth activé" -i "network-bluetooth-activated" \
		-h string:x-canonical-private-synchronous:bluetooth
}

get-device-list() {
	bluetoothctl -t $TIMEOUT scan on > /dev/null &

	local i num
	for ((i = 1; i <= TIMEOUT; i++)); do
		 		printf "\rRecherche d'appareils... (%d/%d)\n" $i $TIMEOUT
 		printf "%bAppuyez sur [q] pour arrêter%b\n" "$RED" "$RESET"

		num=$(bluetoothctl devices | grep -c "Device")
		printf "\nDevices: %s" "$num"
		printf "\e[0;0H"

		read -rsn 1 -t 1
		if [[ $REPLY == [Qq] ]]; then
			break
		fi
	done

 	printf "\n%bRecherche arrêtée.%b\n\n" "$RED" "$RESET"

	list=$(bluetoothctl devices | sed "s/^Device //")
	if [[ -z $list ]]; then
 		notify-send "Bluetooth" "Aucun appareil trouvé" -i "package-broken"
		return 1
	fi
}

select-device() {
 	local header
 	header=$(printf "%-17s %s" "Adresse" "Nom")

	local options=(
		"--border=sharp"
 		"--border-label= Appareils Bluetooth "
		"--ghost=Search"
		"--header=$header"
		"--height=~100%"
		"--highlight-line"
		"--info=inline-right"
		"--pointer="
		"--reverse"
		"${colors[@]}"
	)

	address=$(fzf "${options[@]}" <<< "$list" | awk '{print $1}')
	if [[ -z $address ]]; then
		return 1
	fi

	local connected
	connected=$(bluetoothctl info "$address" | awk '/Connected/ {print $2}')

	if [[ $connected == "yes" ]]; then
 		notify-send "Bluetooth" "Déjà connecté à cet appareil" \
			-i "package-install"
		return 1
	fi
}

pair-and-connect() {
	local paired
	paired=$(bluetoothctl info "$address" | awk '/Paired/ {print $2}')

	if [[ $paired == "no" ]]; then
		printf "Pairing..."

		if ! timeout $TIMEOUT bluetoothctl pair "$address" > /dev/null; then
 			notify-send "Bluetooth" "Échec de l'appairage" -i "package-purge"
			return 1
		fi
	fi

	printf "\nConnecting..."

	if ! timeout $TIMEOUT bluetoothctl connect "$address" > /dev/null; then
 		notify-send "Bluetooth" "Échec de la connexion" -i "package-purge"
		return 1
	fi

 	notify-send "Bluetooth" "Connexion réussie" -i "package-install"
}

main() {
	printf "\e[?25l"
	ensure-on || exit 1
	get-device-list || exit 1
	printf "\e[?25h"
	select-device || exit 1
	pair-and-connect || exit 1
}

main
