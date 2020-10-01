#!/bin/bash

echo "Generate Credentials Code"
echo "$SRCROOT/credentials/add_credentials_to_env.sh"
CREDENTIALS_DIR="$SRCROOT/credentials"

# Set credentials if local script for env-vars exists
if [ -f "$CREDENTIALS_DIR/add_credentials_to_env.sh" ]; then
  echo "Add credentials to environement"
  source "$CREDENTIALS_DIR/add_credentials_to_env.sh"
fi

$SRCROOT/Pods/Sourcery/bin/sourcery --templates "$CREDENTIALS_DIR/Credentials.stencil" --sources . --output "$SRCROOT/Runner" --args mapsApiKey=$MAPS_API_KEY
