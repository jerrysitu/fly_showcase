#!/usr/bin/env bash
# exit on error
set -o errexit

# Initial setup
npm install --prefix ./assets
mix deps.get --only prod
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix compile

# Compile assets

# npm install --prefix ./assets
# npm run deploy --prefix ./assets
# mix phx.digest

# Build the release and overwrite the existing release directory
# MIX_ENV=prod mix release --overwrite