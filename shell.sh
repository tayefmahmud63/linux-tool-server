#!/bin/bash

# Blue background
echo -e -n "\033[44m"

# Grey foreground. 
echo -e -n "\033[37m"

# Disable screen blanking.
echo -e -n "\033[9;0]" 

# Clear the screen.
echo -e -n "\033[2J"

clear
echo " Hardware Report and Data Wiping Tool"

echo "************************************************************************************************************************"

# Collect input from user
read -p "Enter Location: " location
read -p "Enter ATR: " atr
read -p "Enter Note: " note

echo "************************************************************************************************************************"
echo "Collection Hardware Report . . . . . . . . . . . . . . ."

# Get total RAM in GB
ram_total=$(grep MemTotal /proc/meminfo | awk '{print $2 / 1024 / 1024}')
rounded_ram=$(echo "$ram_total" | awk '{print ($1 == int($1)) ? $1 : int($1)+1}')

# Get processor model
processor=$(grep -m 1 'model name' /proc/cpuinfo | cut -d ':' -f2 | xargs)

# Detect HDD/SSD/NVMe and exclude USB/removable drives
storage_detected=false
for i in /dev/sd[a-z]; do
    if [ ${#i} -le 8 ]; then
        is_removable=$(lsblk -dno RM "$i")
        if [ "$is_removable" -eq 0 ]; then
            curdrive=$(hdparm -I "$i" 2>/dev/null | grep "1000\*1000" | cut -d "(" -f 2 | cut -d ")" -f 1)
            curdriveserial=$(hdparm -I "$i" | grep "Serial Number:" | awk '{print $3}')
            sudo fsdisk --delete "$i"
            sudo mkfs.ext4 "$i"
            
            if [ -n "$curdrive" ]; then
                echo "Drive Size: $curdrive GB"
                echo "Drive Serial: $curdriveserial"
                storage_detected=true
                break
            fi
        fi
    fi
done


if ! $storage_detected; then
    echo "No HDD/SSD detected."
    
fi

#Process NVME Drives
for i in /dev/nvme[0-9]n[0-9]
do
   if [ `expr length $i` -eq 12 ]; then
      nohdd=1
      echo -n "Drive detected: "
      echo -n "$i "
      curdrive=`nvme list | grep -i /dev/nvme0n1 | sed -n "s/^\/dev\/nv.*\?\/\s\([0-9]*\.[0-9]*\)\s*\(\w*\).*/\1 \2/p"`
      curdriveserial=`nvme list | grep -i /dev/nvme0n1 | awk '{print $3}'`
      echo "$curdrive [$curdriveserial]"
      drivelist="$drivelist $curdrive\n"
      driveserials="$driveserials $curdriveserial\n"
      sudo fsdisk --delete "$i"
      sudo mkfs.ext4 "$i"
   fi
done
if [ $nohdd -eq 0 ]; then
   echo "No hard drives found!"
   drivelist=`echo -n "None"`
fi


# Get laptop brand and model
brand_name=$(sudo dmidecode -s system-manufacturer)
model_number=$(sudo dmidecode -s system-product-name)
serial_number=$(sudo dmidecode -s system-serial-number)

echo " Brand: $brand_name"
echo " Model Number: $model_number"
echo " Processor: $processor"
echo " Ram Size Total (GB): ${rounded_ram}"
echo " HDD Size: $curdrive"
echo " HDD Serial: $curdriveserial"
echo " Location: $location"
echo " ATR: $atr"
echo " Note: $note"
echo "************************************************************************************************************************"

# Prepare JSON data
json_data=$(cat <<EOF
{
    "location": "$location",
    "atr": "$atr",
    "note": "$note",
    "ram_total_gb": "${rounded_ram}G",
    "processor": "$processor",
    "hard_disk_size_gb": "$curdrive",
    "laptop_brand": "$brand_name",
    "model_number": "$model_number",
    "serial_number": "$serial_number",
    "hard_disk_serial_number": "$curdriveserial"
}
EOF
)

# Post the JSON data to the API
api_url="http://192.168.1.102:5000/api/data"
curl -X POST "$api_url" -H "Content-Type: application/json" -d "$json_data"

# Check if data was posted successfully
if [ $? -eq 0 ]; then
    echo "************************************************************************************************************************"
    echo "Data posted to API successfully."
    echo "************************************************************************************************************************"
    echo "Wiping the detected drive..."

    # Wipe the detected drive securely
    #sudo shred -v -n 1 "$i"
    #sudo dd if=/dev/zero of="$i" bs=100M status=progress
    #sudo sfdisk --delete "$i"
    #sudo mkfs.ext4 "$i"
    echo "Hard disk wiped successfully."
else
    echo "Failed to post data to API."
fi
