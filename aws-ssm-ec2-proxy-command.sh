#!/bin/bash
######## Source ################################################################
#
# enhanced version of https://github.com/qoomon/aws-ssm-ec2-proxy-command
#
######## Usage #################################################################
# https://github.com/qoomon/aws-ssm-ec2-proxy-command/blob/master/README.md
#
# Install Proxy Command
#   - Move this script to ~/.ssh/aws-ssm-ec2-proxy-command.sh
#   - Ensure it is executable (chmod +x ~/.ssh/aws-ssm-ec2-proxy-command.sh)
#
# Add following SSH Config Entry to ~/.ssh/config
#   host i-* mi-*
#     IdentityFile ~/.ssh/id_rsa
#     ProxyCommand ~/.ssh/aws-ssm-ec2-proxy-command.sh %h %r %p ~/.ssh/id_rsa.pub
#     StrictHostKeyChecking no
#
# Ensure SSM Permissions for Target Instance Profile
#   https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-instance-profile.html
#
# Open SSH Connection
#   ssh <INSTANCE_USER>@<INSTANCE_ID>
#
#   Ensure AWS CLI environment variables are set properly
#   e.g. AWS_PROFILE='default' ssh ec2-user@i-xxxxxxxxxxxxxxxx
#
#   If default region does not match instance region you need to provide it like this
#   ssh <INSTANCE_USER>@<INSTANCE_ID>--<INSTANCE_REGION>
#
################################################################################
set -eu

REGION_SEPARATOR='--'

ec2_instance_id="$1"
ssh_user="$2"
ssh_port="$3"
ssh_public_key_path="${4-$HOME/.ssh/id_rsa.pub}"
ssh_public_key="$(cat "${ssh_public_key_path}")"
ssh_public_key_timeout=60

# echo "Host: $ec2_instance_id"
# echo "User: $ssh_user"
# echo "Port: $ssh_port"

fetch_instances_by_name_prefix() {
    local name_prefix=$1
    local result=$(aws ec2 describe-instances \
        --query 'Reservations[].Instances[].[InstanceId, Tags[?Key==`Name`].Value | [0]]' \
        --output text)
    result=$(echo "$result" | awk -v prefix="$name_prefix" 'tolower($2) ~ tolower(prefix) {print $1}')
    echo "$result"
}
select_instance_by_index_or_first() {
    local instances=($1) # Assuming instance IDs are space-separated
    local index=$2
    # Adjust the index to be zero-based for array indexing
    ((index--))
    if [ -z "${instances[index]}" ]; then
        # If the specific index is not found, return the first instance ID
        echo "${instances[0]}"
    else
        # Return the instance ID at the specified index
        echo "${instances[index]}"
    fi
}

if [[ "${ec2_instance_id}" == *"${REGION_SEPARATOR}"* ]]
then
  export AWS_DEFAULT_REGION="${ec2_instance_id##*${REGION_SEPARATOR}}"
  ec2_instance_id="${ec2_instance_id%%${REGION_SEPARATOR}*}"
else
  export AWS_REGION=$(aws configure get region)
fi

if [[ $ec2_instance_id != i-* ]]; then
  if [[ $ec2_instance_id =~ [1-9]$ ]]; then
    index="${ec2_instance_id: -1}"
    name_prefix="${ec2_instance_id%?}"
    echo "Looking up instances by tag:Name prefix..."

    instances=$(fetch_instances_by_name_prefix "$name_prefix")
    if [ -n "$instances" ]; then
        # Convert newline-separated list to space-separated for array
        readarray -t instance_array <<<"$instances"
        ec2_instance_id=$(select_instance_by_index_or_first "${instance_array[*]}" "$index")
        if [ -n "$ec2_instance_id" ]; then
            echo "Selected EC2 instance ID: $ec2_instance_id"
        else
            echo "No instances found for the given tag:Name prefix."
            exit 1
        fi
    else
        echo "No instances found with tag:Name starting with ${name_prefix}."
        exit 1
    fi
  else
    first_instance_id=$(fetch_instances_by_name_prefix "$ec2_instance_id" | awk '{print $1}')

    if [[ $first_instance_id == "None" || -z $first_instance_id ]]; then
        echo "No instances found with tag:Name starting with ${ec2_instance_id}."
        exit 1
    else
        ec2_instance_id=$first_instance_id
        # echo "Found EC2 instance ID: $ec2_instance_id"
    fi
  fi
fi


instance_state=$(aws ec2 describe-instances --instance-ids "${ec2_instance_id}" --query 'Reservations[].Instances[].State.Name' --output text)

if [[ $instance_state != "running" ]]; then
    echo "Instance ${ec2_instance_id} is not running (current state: ${instance_state})."
    exit 1
fi

>/dev/stderr echo "Add public key ${ssh_public_key_path} for ${ssh_user} at instance ${ec2_instance_id} for ${ssh_public_key_timeout} seconds"
aws ssm send-command \
  --instance-ids "${ec2_instance_id}" \
  --document-name 'AWS-RunShellScript' \
  --comment "Add an SSH public key to authorized_keys for ${ssh_public_key_timeout} seconds" \
  --parameters commands="\"
    mkdir -p ~${ssh_user}/.ssh && cd ~${ssh_user}/.ssh || exit 1

    authorized_key='${ssh_public_key} ssm-session'
    echo \\\"\${authorized_key}\\\" >> authorized_keys

    sleep ${ssh_public_key_timeout}

    grep -v -F \\\"\${authorized_key}\\\" authorized_keys > .authorized_keys
    mv .authorized_keys authorized_keys
  \""

>/dev/stderr echo "Start ssm session to instance ${ec2_instance_id}"
aws ssm start-session \
  --target "${ec2_instance_id}" \
  --document-name 'AWS-StartSSHSession' \
  --parameters "portNumber=${ssh_port}"
