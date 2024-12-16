#!/bin/bash

# Define WiFi SSID and Password as variables
WIFI_SSID="Your_SSID"
WIFI_PASSWORD="Your_Password"

# Use whiptail to prompt for WiFi or LAN selection
connection_type=$(whiptail --title "Connection Type" --menu "Choose your connection type" 15 60 2 \
"1" "WiFi" \
"2" "LAN" 3>&1 1>&2 2>&3)

# Check if the user selected WiFi
if [[ "$connection_type" == "1" ]]; then
    # Connect to WiFi using nmcli
    nmcli dev wifi connect "$WIFI_SSID" password "$WIFI_PASSWORD"
    
    if [ $? -eq 0 ]; then
        whiptail --msgbox "Connected to WiFi: $WIFI_SSID" 8 45
    else
        whiptail --msgbox "Failed to connect to WiFi: $WIFI_SSID" 8 45
    fi
else
    # Do nothing if LAN is selected
    whiptail --msgbox "You selected LAN" 8 45
fi
