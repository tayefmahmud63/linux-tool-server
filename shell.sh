#!/bin/bash

# Blue background
echo -e -n "\033[44m"

# Grey foreground
echo -e -n "\033[37m"

# Disable screen blanking
echo -e -n "\033[9;0]" 

# Clear the screen
echo -e -n "\033[2J"

clear
echo " Hardware Report and Data Wiping Tool"

echo "************************************************************************************************************************"

# Collect input from user
#read -p "Enter Location: " location
read -p "Enter ATR: " atr
read -p "Enter Note: " note

# Collect input for Asset Type
#echo "Select Asset Type:"
#echo "1. Laptop"
#echo "2. Desktop"
#read -p "Enter choice [1 or 2]: " asset_choice

#if [ "$asset_choice" -eq 1 ]; then
#    asset_type="Laptop"
#elif [ "$asset_choice" -eq 2 ]; then
#    asset_type="Desktop"
#else
#    echo "Invalid option. Defaulting to Laptop."
#    asset_type="Laptop"
#fi

echo "************************************************************************************************************************"
echo "Collection Hardware Report . . . . . . . . . . . . . . ."



# Check if the system has a battery and store the result in asset_type
if [ -d "/sys/class/power_supply/BAT0" ]; then
    asset_type="Laptop"
else
    asset_type="Desktop"
fi

# Echo the result
#echo "This is a $asset_type."




# Get total RAM in GB
ram_total=$(grep MemTotal /proc/meminfo | awk '{print $2 / 1024 / 1024}')
rounded_ram=$(echo "$ram_total" | awk '{print ($1 == int($1)) ? $1 : int($1)+1}')

# Get processor model
processor=$(grep -m 1 'model name' /proc/cpuinfo | cut -d ':' -f2 | xargs)

# Sanitieze the hdd serial
sanitize_data() {
    local input="$1"
    # Extract the first word before any space
    echo "$input" | awk '{print $1}'
}


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

# Get laptop brand and model
brand_name=$(sudo dmidecode -s system-manufacturer)
model_number=$(sudo dmidecode -s system-product-name)
serial_number=$(sudo dmidecode -s system-serial-number)

sanitized_serial=$(sanitize_data "$driveserials")
echo "Sanitized Serial: $sanitized_serial"

echo " Brand: $brand_name"
echo " Model Number: $model_number"
echo " Processor: $processor"
echo " Ram Size Total (GB): ${rounded_ram}"
echo " HDD/NVMe Sizes: $drivelist"
echo " HDD/NVMe Serials: $sanitized_serial"
echo " Location: $location"
echo " ATR: $atr"
echo " Note: $note"
echo " Asset Type: $asset_type"
echo "************************************************************************************************************************"

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
    "hard_disk_serial_number": "$sanitized_serial",
    "asset_type": "$asset_type"
}
EOF
)

# Post the JSON data to the API
api_url="http://192.168.20.143/api/data"
curl -X POST "$api_url" -H "Content-Type: application/json" -d "$json_data"

# Check if data was posted successfully
if [ $? -eq 0 ]; then
    echo "************************************************************************************************************************"
    echo "Data posted to API successfully."
    echo "************************************************************************************************************************"
    echo "Wiping the detected drives completed."
else
    echo "Failed to post data to API."
fi
