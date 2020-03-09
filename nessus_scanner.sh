#!/bin/bash
# When assigning a name, please use the following naming standard:
#    ITSecOps-<Your User Name>
#    ITAppSec-<Your User Name>

# Make sure to set your API token and Scanner settings in $scanner_settings and $nessus_api set files. 
#  If you run this script without these set, it will create the files and abort.

# Config Variables
config_dir="$HOME/.nessus_config"
scanner_settings="$config_dir/scanner_settings.conf"
nessus_api="$config_dir/nessus_api.conf"

# Var For Checks
exitstatus="0"

# Checking to make sure the Config Directory Exists
if [[ ! -d "$config_dir" ]]; then
  echo "Config dir does not exist, creating in $config_dir"
  mkdir "$config_dir"
  exitstatus="1"
fi

# Checking to make sure that the Config Files exist
if [ ! -f "$scanner_settings" ]; then
  echo "Scanner config not found, creating.."
  cat >"$scanner_settings" <<EOL
scanner_key=""
scanner_name="\$HOSTNAME"
scanner_group=""
EOL
else
  source "$scanner_settings"
fi

# Checking to make sure that the API tokens are present
if [ ! -f "$nessus_api" ]; then
  echo "Nessus API tokens not found, creating.."
  cat >"$nessus_api" <<EOL
#!/usr/bin/env bash
secretKey=""
accessKey=""
EOL
else
  source "$nessus_api"
fi

# Make Sure Scanner Name is Set!
if [[ -z "$scanner_name" ]]; then
  echo "Error: Invalid Scanner Name.."
  echo "Tip: you can set this value in $scanner_settings"
  exitstatus="1"
fi

# Make Sure Scanner Key is Set!
if [[ -z "$scanner_key" ]]; then
  echo "Error: Invalid Scanner Key.."
  echo "Tip: you can set this value in $scanner_settings"
  exitstatus="1"
fi

# Make Sure Scanner Group is Set!
if [[ -z "$scanner_group" ]]; then
  echo "Error: Invalid Scanner Group.."
  echo "Tip: you can set this value in $scanner_settings"
  exitstatus="1"
fi

# Check if JQ is present, you need this for parsing JSON responses.
if [[ -z $(command -v jq) ]]; then
  echo "jq was not detected, installing.."
  apt update
  apt install jq -y
fi

# Check if cURL is present
if [[ -z $(command -v curl) ]]; then
  echo "curl was not detected, installing.."
  apt update
  apt install curl -y
fi

# Abort if errors were encountered
if [[ "$exitstatus" == "1" ]]; then
  echo "Errors were encountered when checking config, please fix these before continuing.."
  exit 1
fi

# Making sure the imaage is up to date
docker pull stevemcgrath/nessus_scanner

# Make sure Scanner Name isn't already taken
scanner_info=$(curl -s --request GET --url https://cloud.tenable.com/scanners -H "X-ApiKeys: accessKey=$accessKey; secretKey=$secretKey;" | jq ".scanners[] | select(.name==\"$scanner_name\")")
if [[ -n "$scanner_info" ]]; then
  echo "======================================"
  echo "Scanner Exists in Console, Aborting..."
  echo "======================================"
  echo "$scanner_info" | jq
  echo "======================================"
  exit 1
fi

# Doing stuff
docker run -dt \
    -e LINKING_KEY="$scanner_key"\
    -e SCANNER_NAME="$scanner_name"\
    -e ADMIN_USER="itsecops"\
    -e ADMIN_PASS="0l51FlC6r2jHQYs1H"\
    --name nessus_scanner\
    stevemcgrath/nessus_scanner:latest

# Sleeping for a couple minutes while Scanner is built.
echo "Sleeping while container is building (and checking every 20 seconds)..."
while : ; do
  scanner_info=$(curl -s --request GET --url https://cloud.tenable.com/scanners -H "X-ApiKeys: accessKey=$accessKey; secretKey=$secretKey;" | jq ".scanners[] | select(.name==\"$scanner_name\")")
  if [[ -n "$scanner_info" ]]; then
    break
  fi
  sleep 20
done

# Scanner Group Assignments via API
if [[ -n "$accessKey" ]] || [[ -n "$secretKey" ]] || [[ -n "$scanner_group" ]]; then
  group_info=$(curl -s --request GET --url https://cloud.tenable.com/scanner-groups -H "X-ApiKeys: accessKey=$accessKey; secretKey=$secretKey;" | jq ".scanner_pools[] | select(.name==\"$scanner_group\")")
  if [[ -n group_info ]]; then
    # Getting Group ID
    group_id=$(echo "$group_info" | jq '.id')
    # Getting Scanner ID
      # Commenting out this call as we can reuse the info grabbed from the timer in previous block.
    #scanner_info=$(curl -s --request GET --url https://cloud.tenable.com/scanners -H "X-ApiKeys: accessKey=$accessKey; secretKey=$secretKey;" | jq ".scanners[] | select(.name==\"$scanner_name\")")
    scanner_id=$(echo "$scanner_info" | jq '.id')
    # Adding Scanner to Group
    curl --request POST --url "https://cloud.tenable.com/scanner-groups/$group_id/scanners/$scanner_id" -H "X-ApiKeys: accessKey=$accessKey; secretKey=$secretKey;"
  else
    # We can add an API call to build the group here.
    echo "No Group Detected, aborting adding sensor to group.."
  fi
else
  echo "Invalid API or Group Info Set, aborting adding sensor to group..."
  exit 1
fi
