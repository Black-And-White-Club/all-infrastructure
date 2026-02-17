#!/bin/bash
set -euo pipefail

# Configuration - Adjust these or pass as env vars if needed
# We try to detect these from Terraform outputs if possible, otherwise hardcode or use OCI CLI query
BASTION_NAME="k8s-bastion"
TARGET_IP="10.0.1.46" # K8s Control Plane Private IP
TARGET_PORT="6443"
LOCAL_PORT="6443"
COMPARTMENT_ID="ocid1.compartment.oc1..aaaaaaaa5ehb7r5dse3sv7gbmturwzqiuukm2u5d5uaav7lo2aqqlcxa7l2a" # Hardcoded from tfvars for reliability, or use dynamic lookup

REGION="us-ashburn-1"
BASTION_HOST="host.bastion.${REGION}.oci.oraclecloud.com"
SSH_KEY="$HOME/.ssh/id_ed25519"
SSH_PUB_KEY="$HOME/.ssh/id_ed25519.pub"

echo "Looking up Bastion ID for '$BASTION_NAME'..."
BASTION_ID=$(oci bastion bastion list --compartment-id "$COMPARTMENT_ID" --name "$BASTION_NAME" --bastion-lifecycle-state ACTIVE --query "data[0].id" --raw-output)

if [ -z "$BASTION_ID" ] || [ "$BASTION_ID" == "null" ]; then
    echo "Error: Could not find active bastion named '$BASTION_NAME'"
    exit 1
fi

echo "Found Bastion: $BASTION_ID"

echo "Creating Port Forwarding Session..."
SESSION_ID=$(oci bastion session create-port-forwarding \
    --bastion-id "$BASTION_ID" \
    --target-private-ip "$TARGET_IP" \
    --target-port "$TARGET_PORT" \
    --display-name "k8s-api-access-$(date +%s)" \
    --key-type PUB \
    --ssh-public-key-file $SSH_PUB_KEY \
    --query "data.id" --raw-output)

echo "Session created: $SESSION_ID"
echo "Waiting for session to become ACTIVE..."

while true; do
    STATE=$(oci bastion session get --session-id "$SESSION_ID" --query 'data."lifecycle-state"' --raw-output)
    if [ "$STATE" == "ACTIVE" ]; then
        break
    elif [ "$STATE" == "FAILED" ] || [ "$STATE" == "DELETED" ]; then
        echo "Session failed to start. State: $STATE"
        exit 1
    fi
    sleep 2
done

echo "Session is ACTIVE."

echo "Waiting 10s for key propagation..."
sleep 10

# Manually construct the SSH command since ssh-metadata-command is not returned for port forwarding sessions

# Construct the command
# Format: ssh -i <key> -N -L <local>:<remote>:<port> -p 22 <session_id>@<bastion_host>
# We add -o StrictHostKeyChecking=no for convenience with ephemeral bastion hosts
FULL_CMD="ssh -i $SSH_KEY -N -L $LOCAL_PORT:$TARGET_IP:$TARGET_PORT -p 22 -o StrictHostKeyChecking=no -o IdentitiesOnly=yes $SESSION_ID@$BASTION_HOST"

echo "========================================================"
echo "Starting Tunnel to K8s API ($TARGET_IP:$TARGET_PORT)"
echo "Bastion Host: $BASTION_HOST"
echo "Session ID: $SESSION_ID"
echo "Local Address: https://127.0.0.1:$LOCAL_PORT"
echo "Press Ctrl+C to stop."
echo "========================================================"

# Execute
eval "$FULL_CMD"
