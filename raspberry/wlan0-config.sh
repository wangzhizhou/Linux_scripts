#!/usr/bin/env bash

if [ $# -ne 2 ]
then
	echo "You should provide the SSID and PSK in Order"
	exit 0

fi

cat > password <<EOF
$2
EOF

wpa_passphrase "$1" < password >> /etc/wpa_supplicant/wpa_supplicant.conf

rm password

wpa_cli -i wlan0 reconfigure
