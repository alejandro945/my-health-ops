#!/bin/bash

# Set GitHub username and personal access token
USERNAME="XXXX"
TOKEN="XXXX"

# Set repository name and description
REPO_NAME="my-health-ops"

# Create folder
mkdir my-health-ops
cd my-health-ops
touch README.MD

# Create repository
response=$(curl -u $USERNAME:$TOKEN https://api.github.com/user/repos -d '{"name":"'$REPO_NAME'", "description":"My Health App Infrastructure Repository","homepage":"https:github.com","private":false}')

# Create local repository
git init
git remote add origin https://github.com/$USERNAME/$REPO_NAME.git
git branch -M master
git add .
git commit -m "Repository Auto Creation :tada:"

# Set branch names
branch_names=("dev" "stage" "master")

# Set protection rules for branches

dev_protection_rules='{"required_status_checks":null,"enforce_admins":true,"required_pull_request_reviews":null,"restrictions":null}'

stage_protection_rules='{"required_status_checks":{"strict":true,"contexts":["continuous-integration"]},"enforce_admins":true,"required_pull_request_reviews":{"require_code_owner_reviews":true},"restrictions":null}'

master_protection_rules='{"required_status_checks":{"strict":true,"contexts":["continuous-integration"]},"enforce_admins":true,"required_pull_request_reviews":{"require_code_owner_reviews":true},"restrictions":null}'

# "restrictions":{"users":["user1"],"teams":["team1"]}

# Create branches locally
for branch in "${branch_names[@]}"; do
if [[ "$branch" != 'master' ]]; then
    git branch $branch
fi
done

#SUBIR RAMAS AL REPOSITORIO REMOTO
git push --all origin

# Configure branch protections
for branch in "${branch_names[@]}"; do
    case "$branch" in
        "dev")
            protection_rules="$dev_protection_rules"
            ;;
        "stage")
            protection_rules="$stage_protection_rules"
            ;;
        "master")
            protection_rules="$master_protection_rules"
            ;;
    esac

    # Configure branch protection
    curl -X PUT -H "Authorization: Token $TOKEN" -d "$protection_rules" https://api.github.com/repos/$USERNAME/$REPO_NAME/branches/$branch/protection
done

# Push to GitHub
git push -u origin master
