#!/bin/bash
set -euo pipefail
pushd $(dirname "$0")/..

export RPC_URL="http://localhost:5050"

export WORLD_ADDRESS=$(cat ./manifests/dev/manifest.json | jq -r '.world.address')
export ACTION_ADDRESS=$(cat ./manifests/dev/manifest.json | jq -r '.contracts[] | select(.name == "dragark::systems::actions::actions" ).address')

echo "---------------------------------------------------------------------------"
echo world : $WORLD_ADDRESS
echo action : $ACTION_ADDRESS
echo "---------------------------------------------------------------------------"

# enable system -> models authorizations

# enable system -> component authorizations
MODELS=("Dragon" "DragonIslandCaptureTransport" "DragonIslandTransport" "DragonScoutTransport" "Game" "Island" "IslandDragonDefending" "User" " UserDragonOwned" "UserIslandOwned")
ACTIONS=($ACTION_ADDRESS)

command="sozo auth grant --world $WORLD_ADDRESS --wait writer "
for model in "${MODELS[@]}"; do
    for action in "${ACTIONS[@]}"; do
        command+="$model,$action "
    done
done
eval "$command"

# sozo auth grant --world $WORLD_ADDRESS --wait writer \
#   Dragon,dragark::systems::actions::actions\
#   DragonIslandCaptureTransport,dragark::systems::actions::actions\
#   DragonIslandTransport,dragark::systems::actions::actions\
#   DragonScoutTransport,dragark::systems::actions::actions\
#   Game,dragark::systems::actions::actions\
#   Island,dragark::systems::actions::actions\
#   IslandDragonDefending,dragark::systems::actions::actions\
#   User,dragark::systems::actions::actions\
#   UserDragonOwned,dragark::systems::actions::actions\
#   UserIslandOwned,dragark::systems::actions::actions\

#   >/dev/null

echo "Default authorizations have been successfully set."
