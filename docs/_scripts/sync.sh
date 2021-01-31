#!/usr/bin/env bash
echo "Syncing the repository using the remote."
pulp file repository sync --name $REPO_NAME --remote $REMOTE_NAME

echo "Inspecting RepositoryVersion."
pulp file repository version --repository $REPO_NAME show --version 1
