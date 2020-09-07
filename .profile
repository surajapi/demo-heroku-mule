#export MULE_HOME="/app"

# Script to start Mule Runtime & handle Server registration
hybridAPI=https://anypoint.mulesoft.com/hybrid/api/v1
accAPI=https://anypoint.mulesoft.com/accounts

username=${MULE_USERNAME}
password=${MULE_PASSWORD}
orgName=${MULE_ORG}
envName=${MULE_ENV}
serverGroupName=${HEROKU_APP_NAME}_GROUP


# Authenticate with user credentials (Note the APIs will NOT authorize for tokens received from the OAuth call. A user credentials is essential)
echo "Getting access token from $accAPI/login..."
accessToken=$(curl -s $accAPI/login -X POST -d "username=$username&password=$password" | jq --raw-output .access_token)
echo "Access Token: $accessToken"

# Pull org id from my profile info
echo "Getting org ID from $accAPI/api/me..."
jqParam=".user.contributorOfOrganizations[] | select(.name==\"$orgName\").id"
orgId=$(curl -s $accAPI/api/me -H "Authorization:Bearer $accessToken" | jq --raw-output "$jqParam")
echo "Organization ID: $orgId"

# Pull env id from matching env name
echo "Getting env ID from $accAPI/api/organizations/$orgId/environments..."
jqParam=".data[] | select(.name==\"$envName\").id"
envId=$(curl -s $accAPI/api/organizations/$orgId/environments -H "Authorization:Bearer $accessToken" | jq --raw-output "$jqParam")
echo "Environment ID: $envId"

# Request ARM token
echo "Getting registrion token from $hybridAPI/servers/registrationToken..."
amcToken=$(curl -s $hybridAPI/servers/registrationToken -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" | jq --raw-output .data)
echo "AMC Token: $amcToken"

# Get Server ID from AMC
echo "Getting server details from $hybridAPI/servers..."
serverData=$(curl -s $hybridAPI/servers/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")
jqParam=".data[] | select(.name==\"${HEROKU_APP_NAME}_${DYNO}\").id"
serverId=$(echo $serverData | jq --raw-output "$jqParam")
echo "ServerId ${HEROKU_APP_NAME}_${DYNO}: $serverId"

# Check to see if Server is already regsistered
if [ -z $serverId ]; then
    echo "$serverId None"
else
    echo "$serverId Exists"
    # Deregister any existing Mule Runtime from ARM
    echo "Deregistering Server at $hybridAPI/servers/$serverId..."
    curl -s -X "DELETE" "$hybridAPI/servers/$serverId" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken"
fi

# Register new Mule Runtime with ARM
./bin/amc_setup -H $amcToken "${HEROKU_APP_NAME}_${DYNO}"

# Get Server ID from AMC
#echo "Getting server details from $hybridAPI/servers..."
#serverData=$(curl -s $hybridAPI/servers/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")
#jqParam=".data[] | select(.name==\"${HEROKU_APP_NAME}_${DYNO}\").id"
#serverId=$(echo $serverData | jq --raw-output "$jqParam")
#echo "ServerId ${HEROKU_APP_NAME}_${DYNO}: $serverId"

# TODO: Create Group if more than one Dyno
# Note: 3/20/2020 - Currently not supported because of race condition that prevents creating group with Gateway and Server
if [ "${DYNO}" != "web.1" ]; then
  echo "${DYNO} Group"
  # Obtain server group ID
  #echo "Getting group ID"
  #jqParam=".data[] | select(.name==\"$serverGroupName\").id"
  #groupId=$(curl -s $hybridAPI/serverGroups -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" | jq --raw-output "$jqParam")
  #echo "Group $serverGroupName id: $groupId"
  # Add server to existing group
  #echo "Add server to group"
  #groupData=$(curl -s $hybridAPI/serverGroups/$groupId/servers/$serverId -H "Content-Type: application/json" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" --request POST)
  #echo $groupData
else  
  echo "${DYNO} Single"
  # Create new group & add server
  #echo "Creating new group and add server"
  #createGroup=$(curl -s -X "POST" $hybridAPI/serverGroups -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" -H "Content-Type: application/json" -d "{ \"name\": \"$serverGroupName\", \"serverIds\": [$serverId]}")    
fi  

# TODO: Setup Anypoint Monitoring
# Note: 3/20/2020 - Currently not supported on Heroku Dyno
# Get Server ID from AMC
#echo "Getting server details from $hybridAPI/servers..."
#serverData=$(curl -s $hybridAPI/servers/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")
#jqParam=".data[] | select(.name==\"${HEROKU_APP_NAME}_${DYNO}\").id"
#serverId=$(echo $serverData | jq --raw-output "$jqParam")
#echo "ServerId ${HEROKU_APP_NAME}_${DYNO}: $serverId"

# Setup monitoring agent & background start it
#echo "Setting up monitoring"
#./am/bin/install -x true -s $serverId