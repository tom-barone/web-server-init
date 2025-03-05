#!/usr/bin/env bash
# shellcheck disable=SC2046
set -o allexport; source .env; set +o allexport

# Convenience script to push to all servers defined in .env
for server in $SERVERS; do
	echo "Pushing to $server"
	SSH_CONNECTION_STRING=root@$server ./push.sh
done
