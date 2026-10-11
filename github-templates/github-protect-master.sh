#!/usr/bin/env bash
# Branch protection of the repositories that receive reviewed ABAP code, as
# GitHub rulesets.
#
#   bash github-protect-master.sh <owner> basic  <repository> [repository ...]
#       master (the default branch) and release/* branches cannot be deleted
#       or force-pushed. Normal pushes still work.
#
#   bash github-protect-master.sh <owner> review <repository> [repository ...]
#       Changes reach the default branch only through a pull request with one
#       approval. A new commit on the pull request cancels an approval given
#       before, all review conversations must be resolved, and only squash
#       merging is allowed.
#
# <owner> is the GitHub user or organization. Needs: gh logged in with the
# admin role on the repositories.
# Safe to run again: a ruleset that exists already is updated to the
# definition in this file.
set -u

if [ $# -lt 3 ]; then
  echo "usage: bash github-protect-master.sh <owner> basic|review <repository> [repository ...]"
  exit 1
fi
ORG="$1"
MODE="$2"
shift 2
REPOSITORIES=("$@")

case "$MODE" in
  basic)
    NAME="No deletion, no force push"
    RULESET='{
      "name": "No deletion, no force push",
      "target": "branch",
      "enforcement": "active",
      "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH", "refs/heads/release/*"], "exclude": [] } },
      "rules": [ { "type": "deletion" }, { "type": "non_fast_forward" } ]
    }'
    ;;
  review)
    NAME="Default branch only through reviewed pull requests"
    RULESET='{
      "name": "Default branch only through reviewed pull requests",
      "target": "branch",
      "enforcement": "active",
      "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
      "rules": [ {
        "type": "pull_request",
        "parameters": {
          "required_approving_review_count": 1,
          "dismiss_stale_reviews_on_push": true,
          "require_code_owner_review": false,
          "require_last_push_approval": false,
          "required_review_thread_resolution": true,
          "allowed_merge_methods": ["squash"]
        }
      } ]
    }'
    ;;
  *)
    echo "usage: bash github-protect-master.sh <owner> basic|review <repository> [repository ...]"
    exit 1
    ;;
esac

for repository in "${REPOSITORIES[@]}"; do
  printf '%-28s ' "$repository"
  existing=$(gh api "repos/$ORG/$repository/rulesets" --jq ".[] | select(.name == \"$NAME\") | .id")
  if [ -n "$existing" ]; then
    if printf '%s' "$RULESET" | gh api -X PUT "repos/$ORG/$repository/rulesets/$existing" --input - --silent; then
      echo "ruleset updated: $NAME"
    else
      echo "!! ruleset not updated"
    fi
    continue
  fi
  if printf '%s' "$RULESET" | gh api "repos/$ORG/$repository/rulesets" --input - --silent; then
    echo "ruleset created: $NAME"
  else
    echo "!! ruleset not created"
  fi
done

echo
echo "== rulesets now"
for repository in "${REPOSITORIES[@]}"; do
  printf '%-28s ' "$repository"
  gh api "repos/$ORG/$repository/rulesets" --jq '[.[] | "\(.name) (\(.enforcement))"] | join("; ")'
done
