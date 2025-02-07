#!/bin/bash

# Blue background
echo -e -n "\033[44m"

# Grey foreground
echo -e -n "\033[37m"

# Disable screen blanking
echo -e -n "\033[9;0]"

# Clear the screen
echo -e -n "\033[2J"

# Function to check server status by pinging a hardcoded IP address
print_server_status() {
    local server_ip="192.168.20.143"  # Replace with the desired IP address

    # Ping the server (4 packets, wait 1 second per packet)
    if ping -c 4 -W 1 "$server_ip" > /dev/null 2>&1; then
        # If the server is online, print green background
        echo -e "\e[1;37m\e[42m SERVER ONLINE ($server_ip) \e[0m"
    else
        # If the server is offline, print red background
        echo -e "\e[1;37m\e[41m SERVER OFFLINE ($server_ip) \e[0m"
    fi
}
# Function to show confirmation popup with simulated center alignment
success_confirmation() {
    whiptail --title "Confirmation" \
    --msgbox "\n SUCCESS" 10 40 --ok-button "OK"
}

# Function to show confirmation popup with simulated center alignment
error_confirmation() {
    whiptail --title "Confirmation" \
    --msgbox "\n CANT SEND DATA TO SERVER" 10 40 --ok-button "OK"
}


clear
# ASCII Art for "Hardware Report & Wipe"
ascii_art=$(cat <<'EOF'
  _    _               _                          _____                       _             __          ___       _
 | |  | |             | |                        |  __ \                     | |     ___    \ \        / (_)     (_)
 | |__| | __ _ _ __ __| |_      ____ _ _ __ ___  | |__) |___ _ __   ___  _ __| |_   ( _ )    \ \  /\  / / _ _ __  _ _ __   __ _
 |  __  |/ _` | '__/ _` \ \ /\ / / _` | '__/ _ \ |  _  // _ \ '_ \ / _ \| '__| __|  / _ \/\   \ \/  \/ / | | '_ \| | '_ \ / _` |
 | |  | | (_| | | | (_| |\ V  V / (_| | | |  __/ | | \ \  __/ |_) | (_) | |  | |_  | (_>  <    \  /\  /  | | |_) | | | | | (_| |
 |_|  |_|\__,_|_|  \__,_| \_/\_/ \__,_|_|  \___| |_|  \_\___| .__/ \___/|_|   \__|  \___/\/     \/  \/   |_| .__/|_|_| |_|\__, |
                                                            | |                                            | |             __/ |
                                                            |_|                                            |_|            |___/

                                           Hardware Report & Data Wipe Tool By Null Labz
                                                          www.nullabz.com
                                        ====================================================

EOF
)


# Display ASCII art
echo "$ascii_art"


# Define WiFi SSID and Password as variables
WIFI_SSID="2nds IT"
WIFI_PASSWORD="farman0786"

# Use whiptail to prompt for WiFi or LAN selection
connection_type=$(whiptail --title "Connection Type" --menu "Choose your connection type" 15 60 2 \
"1" "LAN" \
"2" "WiFi" 3>&1 1>&2 2>&3)

# Check if the user selected LAN
if [[ "$connection_type" == "1" ]]; then
    # Do nothing if LAN is selected
    whiptail --msgbox "You selected LAN" 8 45
else
    # Connect to WiFi using nmcli
    sudo systemctl start NetworkManager
    sudo nmcli dev wifi connect "$WIFI_SSID" password "$WIFI_PASSWORD"
    sleep 5

    if [ $? -eq 0 ]; then
        whiptail --msgbox "Connected to WiFi: $WIFI_SSID" 8 45
    else
        whiptail --msgbox "Failed to connect to WiFi: $WIFI_SSID" 8 45
    fi
fi



echo "Checking Server Active Status"
sleep 1
echo "."
sleep 1
echo "."
sleep 1
echo "."



print_server_status
echo "Collection Hardware Report . . . . . . . . . . . . . . ."



# Check if the system has a battery and store the result in asset_type
if [ -d "/sys/class/power_supply/BAT0" ]; then
    asset_type="Laptop"
else
    asset_type="Desktop"
fi




# Get total RAM in GB
ram_total=$(grep MemTotal /proc/meminfo | awk '{print $2 / 1024 / 1024}')
rounded_ram=$(echo "$ram_total" | awk '{print ($1 == int($1)) ? $1 : int($1)+1}')

# Get processor model
processor=$(grep -m 1 'model name' /proc/cpuinfo | cut -d ':' -f2 | xargs)

# Detect HDD/SSD and exclude USB/removable drives

drivelist=""
driveserials=""
for i in /dev/sd[a-z]; do
    if [ ${#i} -le 8 ]; then
        is_removable=$(lsblk -dno RM "$i")
        if [ "$is_removable" -eq 0 ]; then
            curdrive=$(hdparm -I "$i" 2>/dev/null | grep "1000\*1000" | cut -d "(" -f 2 | cut -d ")" -f 1)
            curdriveserial=$(hdparm -I "$i" | grep "Serial Number:" | awk '{print $3}')

            if [ -n "$curdrive" ] && [ -n "$curdriveserial" ]; then
                echo "Detected Drive: $i"
                echo "Drive Size: $curdrive GB"
                echo "Drive Serial: $curdriveserial"

                drivelist="$drivelist $curdrive"
                driveserials="$driveserials $curdriveserial"

                # Wipe and format the drive
                echo "Wiping and formatting $i..."
                sudo fsdisk --delete "$i"
                sudo mkfs.ext4 "$i"
            fi
        fi
    fi
done

if [ -z "$drivelist" ]; then
    echo "No HDD/SSD detected."
fi

# Process NVME Drives
for i in /dev/nvme[0-9]n[0-9]; do
    curdrive=$(nvme list | grep -i "$i" | sed -n "s/^\/dev\/nv.*\?\/\s\([0-9]*\.[0-9]*\)\s*\(\w*\).*/\1 \2/p")
    curdriveserial=$(nvme id-ctrl "$i" | grep "sn" | awk '{print $3}')

    if [ -n "$curdrive" ] && [ -n "$curdriveserial" ]; then
        echo "Detected NVMe Drive: $i"
        echo "Drive Size: $curdrive"
        echo "Drive Serial: $curdriveserial"

        drivelist="$drivelist $curdrive"
        driveserials="$driveserials $curdriveserial"

        # Wipe and format the NVMe drive
        echo "Wiping and formatting $i..."
        sudo fsdisk --delete "$i"
        sudo mkfs.ext4 "$i"
    fi
done

if [ -z "$curdrive" ]; then
    echo "No NVMe drives detected."
fi

drive_serials=$(echo "$driveserials" | head -n 1)


# Get laptop brand and model
brand_name=$(sudo dmidecode -s system-manufacturer)
model_number=$(sudo dmidecode -s system-product-name)
serial_number=$(sudo dmidecode -s system-serial-number)





# Display existing data using whiptail
whiptail --title "System Information" --msgbox "Brand: $brand_name\nModel Number: $model_number\nProcessor: $processor\nRAM Size Total (GB): ${rounded_ram}\nHDD/NVMe Sizes: $drivelist\nHDD/NVMe Serials: $drive_serials\nAsset Type: $asset_type" 15 60

# Get user input for location, ATR, and note using whiptail
location=$(whiptail --inputbox "Enter Location:" 10 60 3>&1 1>&2 2>&3)
if [[ -z "$location" ]]; then
  whiptail --title "Error" --msgbox "Location is required. Exiting." 8 45
  exit 1
fi

atr=$(whiptail --inputbox "Enter ATR (optional):" 10 60 3>&1 1>&2 2>&3)
note=$(whiptail --inputbox "Enter Note (optional):" 10 60 3>&1 1>&2 2>&3)

# Display final information
whiptail --title "Final Input" --msgbox "Brand: $brand_name\nModel Number: $model_number\nProcessor: $processor\nRAM Size Total (GB): ${rounded_ram}\nHDD/NVMe Sizes: $drivelist\nHDD/NVMe Serials: $drive_serials\nAsset Type: $asset_type\nLocation: $location\nATR: ${atr:-N/A}\nNote: ${note:-N/A}" 20 70



# Prepare JSON data
json_data=$(cat <<EOF
{
    "location": "$location",
    "atr": "$atr",
    "note": "$note",
    "ram_total_gb": "${rounded_ram}GB",
    "processor": "$processor",
    "hard_disk_size_gb": "$drivelist",
    "laptop_brand": "$brand_name",
    "model_number": "$model_number",
    "serial_number": "$serial_number",
    "hard_disk_serial_number": "$drive_serials",
    "asset_type": "$asset_type"
}
EOF
)

# Post the JSON data to the API
api_url="192.168.20.143/api/data"
curl -X POST "$api_url" -H "Content-Type: application/json" -d "$json_data"

# Check if data was posted successfully
if [ $? -eq 0 ]; then
    success_confirmation
else
    error_confirmation
fi
