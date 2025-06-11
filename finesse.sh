#!/bin/bash
# Script Name: finesse.sh
# Description: Simple script to change Finesse user state via API
# Author: izzy kestrel
# Date: 2025-06-03
# Usage: `./finesse.sh READY` to login and set status to READY
#        `./finesse.sh LOGOUT` to logout

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/encpass-lite.sh"
source "${SCRIPT_DIR}/kv-bash.sh"

get_auth_hash() {
   AUTH_HASH=$(echo -n "${username}:$(get_secret)" | base64)
}

# $1=endpoint
send_get_request() {
   # return data
   http_response="$(curl -s -o - -w "%{response_code}" \
      --location --request GET "${domain}/finesse/api${1}" \
      --header "Authorization: Basic ${AUTH_HASH}")"

   LAST_HTTP_CODE=${http_response: -3}
   LAST_GET_RESPONSE="${http_response::${#http_response}-4}"
}

# $1=endpoint, $2=data
send_put_request() {
   # return HTTP status code
   LAST_HTTP_CODE=$(curl -s -o /dev/null -w "%{response_code}" \
      --location --request PUT "${domain}/finesse/api${1}" \
      --header "Content-Type: application/xml" \
      --header "Authorization: Basic ${AUTH_HASH}" \
      --data "${2}")
}

if [ "$1" == '--reconfig' ]; then
   kvclear
fi

username=$(kvget username)
ext=$(kvget ext)
domain=$(kvget domain)

if [ -z "${username}" ]; then
   read -r -p "Please enter your Finesse server URL (with port, if necessary): " domain
   read -r -p "Please enter your Finesse username: " username
   read -r -p "Please enter your Finesse extension: " ext
   echo "Prompting for Finesse password (this will be stored locally with encryption)"
   # shellcheck disable=SC2119
   get_secret >/dev/null

   kvset username "${username}"
   kvset ext "${ext}"
   kvset domain "${domain}"

   echo -n "Attempting to auth with Finesse API..."

   get_auth_hash
   send_get_request "/Devices?extension=${ext}"

      if [ "$LAST_HTTP_CODE" == '200' ]; then
      echo "Success!"
   else
      echo "Login failed!"
      exit
   fi

   echo -n "Looking up your primary device..."

   kvset deviceId "$(xmllint --xpath 'string(/Devices/Device/deviceId)' - <<<"${LAST_GET_RESPONSE}")"

   echo "Found $(xmllint --xpath 'string(/Devices/Device/deviceTypeName)' - <<<"${LAST_GET_RESPONSE}")"
   echo ""

   echo "Configuration complete! Try './finesse.sh READY'"

   exit
fi

get_auth_hash

# Get current user state
send_get_request "/User/${username}"
CURRENT_STATE=$(echo "${LAST_GET_RESPONSE}" | xmllint --xpath 'string(/User/state)' -)

# If no `NEW_STATUS` parameter set, return current user status
if [ -z "$1" ]; then
   echo "${CURRENT_STATE}"
   exit
fi

NEW_STATE=$1

loginXml="
   <User>
      <state>LOGIN</state>
      <extension>${ext}</extension>
      <activeDeviceId>$(kvget deviceId)</activeDeviceId>
   </User>"

stateXml="
   <User>
      <state>${NEW_STATE}</state>
      <reasonCodeId>30</reasonCodeId>
   </User>"

# Check if user is logged in, login if not
if [[ $LAST_GET_RESPONSE != *"activeDeviceId"* ]]; then
   send_put_request "/User/${username}" "${loginXml}"

   if [ "$LAST_HTTP_CODE" == '202' ]; then
      # echo "Logging in..."
      sleep 1 # Wait a second before changing state
   else
      echo "Login failed!"
      exit
   fi
fi

if [ "${NEW_STATE}" == 'LOGIN' ]; then
   echo "LOGIN"
   exit
fi

# Request state change
send_put_request "/User/${username}" "${stateXml}"

if [ "${LAST_HTTP_CODE}" == '202' ]; then
   echo "${NEW_STATE}"
else
   echo "Failed to set new state!"
fi