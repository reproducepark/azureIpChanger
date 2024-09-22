#!/bin/bash

# 1. 사용중인 public ip 목록 확보, ipv4 주소 확인
echo "Retrieving list of public IPs in the resource group..."
JSON_PUB_IP=$(az network public-ip list --resource-group "$RESOURCE_GROUP")

if [ -n "$JSON_PUB_IP" ]; then
    names=($(echo "$JSON_PUB_IP" | jq -r '.[].name'))

    if [ ${#names[@]} -eq 1 ]; then
        export PREV_PUBLIC_IP_NAME="${names[0]}"
        echo "Previous Public IP Name: $PREV_PUBLIC_IP_NAME"
        echo "Retrieving current IP address for $PREV_PUBLIC_IP_NAME..."
        az network public-ip show --resource-group "$RESOURCE_GROUP" \
                                --name "$PREV_PUBLIC_IP_NAME" \
                                --query "ipAddress" \
                                --output tsv
    elif [ ${#names[@]} -gt 1 ]; then
        echo "Error: More than one public IP name found."
        exit 1
    else
        echo "No public IPs found in the specified resource group."
        exit 1
    fi
else
    echo "No public IPs found in the specified resource group."
    exit 1
fi

# 2. 새로운 public ip 생성 및 ipv4 주소 확인
echo "Generating new public IP name..."
numeric_part=$(echo "$PREV_PUBLIC_IP_NAME" | grep -o '[0-9]*')

if [ -n "$numeric_part" ]; then
    new_numeric_part=$((numeric_part + 1))
else
    new_numeric_part=1
fi

new_public_ip_name=$(echo "$PREV_PUBLIC_IP_NAME" | sed "s/[0-9]*$/$new_numeric_part/")
echo "Creating new public IP: $new_public_ip_name..."

az network public-ip create --name "$new_public_ip_name" \
                        --resource-group "$RESOURCE_GROUP" > /dev/null 2>&1

echo "Retrieving new IP address for $new_public_ip_name..."
new_ip_address=$(az network public-ip show --resource-group "$RESOURCE_GROUP" \
                                        --name "$new_public_ip_name" \
                                        --query "ipAddress" \
                                        --output tsv)
echo "New IP Address: $new_ip_address"

# 3. 새로운 public ip로 update
echo "Updating NIC configuration with new public IP..."
az network nic ip-config update --name "$IPCONFIG" \
                            --resource-group "$RESOURCE_GROUP" \
                            --nic-name "$NIC_NAME" \
                            --public-ip-address "$new_public_ip_name" > /dev/null 2>&1

# 4. ssh 연결 및 tailscale 재시작
echo "Connecting via SSH to restart Tailscale..."
sshpass -p "$SSH_PW" ssh -o StrictHostKeyChecking=no $SSH_ID@$new_ip_address << EOF
sudo tailscale down
sudo tailscale up --advertise-exit-node
logout
EOF

# 5. public ip 삭제
echo "Deleting previous public IP: $PREV_PUBLIC_IP_NAME..."
az network public-ip delete --resource-group ali2_group --name "$PREV_PUBLIC_IP_NAME"

echo "Script completed."