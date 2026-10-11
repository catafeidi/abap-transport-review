#!/usr/bin/env bash
# Second ruleset: the default branch is merged only by the release of the SAP
# system (through the GitHub App) or by a repository admin. A reviewer who
# approved a pull request then cannot merge it on GitHub; the merge happens
# when the request is released in SAP.
#
#   bash github-restrict-merge.sh <owner> <github-app-id> <repository> [repository ...]
#
# <github-app-id> is the numeric App ID on the settings page of the GitHub App.
# Run it AFTER the GitHub App is installed on the repository: GitHub refuses the
# ruleset while the app is not installed there ("integration must be part of the
# ruleset source or owner organization").
#
# Needs: gh logged in with the admin role on the repositories.
# Safe to run again: an existing ruleset of that name is updated.
set -u

if [ $# -lt 3 ]; then
  echo "usage: bash github-restrict-merge.sh <owner> <github-app-id> <repository> [repository ...]"
  exit 1
fi
ORG="$1"
APP_ID="$2"
shift 2
case "$APP_ID" in
  ''|*[!0-9]*) echo "the GitHub App ID must be a number, got: $APP_ID"; exit 1 ;;
esac
ADMIN_ROLE=5            # repository role "admin"
NAME="Default branch merged only by SAP release or an admin"
RULESET='{
  "name": "'"$NAME"'",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [ { "type": "update" } ],
  "bypass_actors": [
    { "actor_id": '"$ADMIN_ROLE"', "actor_type": "RepositoryRole", "bypass_mode": "always" },
    { "actor_id": '"$APP_ID"', "actor_type": "Integration", "bypass_mode": "always" }
  ]
}'

for repository in "$@"; do
  printf '%-28s ' "$repository"
  existing=$(gh api "repos/$ORG/$repository/rulesets" --jq ".[] | select(.name == \"$NAME\") | .id")
  if [ -n "$existing" ]; then
    if printf '%s' "$RULESET" | gh api -X PUT "repos/$ORG/$repository/rulesets/$existing" --input - --silent; then
      echo "ruleset updated"
    else
      echo "!! ruleset not updated"
    fi
    continue
  fi
  if printf '%s' "$RULESET" | gh api "repos/$ORG/$repository/rulesets" --input - --silent; then
    echo "ruleset created"
  else
    echo "!! ruleset not created (is the GitHub App installed on the repository?)"
  fi
done
