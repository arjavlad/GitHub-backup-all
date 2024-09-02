#!/bin/bash

# Initialize final summary report file
FINAL_SUMMARY_REPORT="$HOME/github_backup/final_summary_report.txt"

# Start the final summary report with a header
echo "GitHub Backup Final Summary Report" > "$FINAL_SUMMARY_REPORT"
echo "==================================" >> "$FINAL_SUMMARY_REPORT"
echo "" >> "$FINAL_SUMMARY_REPORT"

# Function to check if a repository exists in the organization
repo_exists() {
    local org=$1
    local repo=$2
    local result=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$org/$repo")
    if echo "$result" | grep -q '"Not Found"'; then
        return 1
    else
        return 0
    fi
}

# Function to clone a repository if it exists
clone_repo() {
    local org=$1
    local repo=$2
    local dir="$BACKUP_DIR/$org/$repo"
    
    if repo_exists "$org" "$repo"; then
        echo "Cloning $repo..."
        git clone "https://$GITHUB_TOKEN@github.com/$org/$repo.git" "$dir"
        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to clone $repo. Skipping to the next repository." | tee -a "$DETAILS_REPORT"
            return 1
        fi
        cd "$dir" || return 1
    else
        echo "ERROR: Repository $repo not found in organization $org. Skipping." | tee -a "$DETAILS_REPORT"
        return 1
    fi
}

# Print a description of what the script does
echo "############################################################"
echo "# GitHub Repositories Backup Script                         #"
echo "#                                                          #"
echo "# This script automates the process of backing up all      #"
echo "# branches of all repositories from specified GitHub       #"
echo "# organizations. The script performs the following steps:  #"
echo "# 1. Validates the provided GitHub token.                  #"
echo "# 2. Retrieves and clones repositories from the specified  #"
echo "#    GitHub organizations.                                 #"
echo "# 3. Fetches and tracks all branches locally.              #"
echo "# 4. Handles GitHub API rate limits by pausing if needed.  #"
echo "# 5. Generates a detailed and summary report for each org. #"
echo "# 6. Provides a final summary report for all organizations.#"
echo "#                                                          #"
echo "# Note: This script will save the backups to a directory   #"
echo "# named 'github_backup' in your home directory.            #"
echo "############################################################"
echo ""

# Prompt user for input
read -p "Enter the GitHub token (required for private repositories): " GITHUB_TOKEN
read -p "Enter the names of GitHub organizations (separated by space): " -a GITHUB_ORGS
read -p "Enter the sleep time between API calls in seconds (default is 2): " SLEEP_TIME

# Set default sleep time if not provided
if [ -z "$SLEEP_TIME" ]; then
    SLEEP_TIME=2
fi

# Set base directory for backups
BACKUP_DIR="$HOME/github_backup"
RATE_LIMIT_URL="https://api.github.com/rate_limit"

# Function to find jq
find_jq() {
    if command -v jq >/dev/null 2>&1; then
        echo "$(command -v jq)"
    else
        echo ""
    fi
}

# Attempt to find jq path
JQ_PATH=$(find_jq)

# Check if jq is installed
if [ -z "$JQ_PATH" ]; then
    echo "Error: jq is not installed. Please install jq to continue."
    echo "You can install it by running: brew install jq"
    exit 1
fi

# Function to validate the GitHub token
validate_token() {
    RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" $RATE_LIMIT_URL)
    if echo "$RESPONSE" | grep -q "Bad credentials"; then
        echo "Error: Invalid GitHub token. Please check your token and try again."
        exit 1
    fi
    echo "GitHub token is valid. Proceeding with the backup process..."
}

# Function to check rate limit and wait if necessary
check_rate_limit() {
    RATE_LIMIT_REMAINING=$(curl -s -H "Authorization: token $GITHUB_TOKEN" $RATE_LIMIT_URL | $JQ_PATH -r '.rate.remaining')
    if [ "$RATE_LIMIT_REMAINING" -lt 10 ]; then
        RESET_TIME=$(curl -s -H "Authorization: token $GITHUB_TOKEN" $RATE_LIMIT_URL | $JQ_PATH -r '.rate.reset')
        CURRENT_TIME=$(date +%s)
        WAIT_TIME=$((RESET_TIME - CURRENT_TIME + 60))  # Adding a buffer of 60 seconds
        echo "Rate limit exceeded. Waiting for $WAIT_TIME seconds..."
        sleep $WAIT_TIME
    fi
}

# Validate the GitHub token before proceeding
validate_token

# Initialize final summary counts
TOTAL_ORGS_REPO_COUNT=0
TOTAL_ORGS_BRANCH_COUNT=0
TOTAL_ORGS_FAILED_COUNT=0

# Process each organization
for GITHUB_ORG in "${GITHUB_ORGS[@]}"; do
    echo "Processing organization: $GITHUB_ORG"
    
    # Initialize report files for the organization
    ORG_DIR="$BACKUP_DIR/$GITHUB_ORG"
    mkdir -p "$ORG_DIR"
    DETAILS_REPORT="$ORG_DIR/details_report.txt"
    SUMMARY_REPORT="$ORG_DIR/summary_report.txt"
    
    echo "GitHub Backup Details Report - $GITHUB_ORG" > "$DETAILS_REPORT"
    echo "===========================================" >> "$DETAILS_REPORT"
    echo "" >> "$DETAILS_REPORT"

    echo "GitHub Backup Summary Report - $GITHUB_ORG" > "$SUMMARY_REPORT"
    echo "===========================================" >> "$SUMMARY_REPORT"
    echo "" >> "$SUMMARY_REPORT"

    ORG_REPO_COUNT=0
    ORG_BRANCH_COUNT=0
    ORG_FAILED_COUNT=0
    
    # Get the list of repositories from the organization
    check_rate_limit
    REPOS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/orgs/$GITHUB_ORG/repos?per_page=100" | $JQ_PATH -r '.[].name')
    
    # Clone and back up each repository
    for REPO in $REPOS; do
        echo "Processing $REPO..."
        echo "Repository: $REPO" >> "$DETAILS_REPORT"
        
        if clone_repo "$GITHUB_ORG" "$REPO"; then
            ORG_REPO_COUNT=$((ORG_REPO_COUNT + 1))
            echo "Fetching all branches..."
            git fetch --all
            BRANCH_COUNT=$(git branch -r | grep -v '\->' | wc -l)
            ORG_BRANCH_COUNT=$((ORG_BRANCH_COUNT + BRANCH_COUNT))
            echo "Number of branches: $BRANCH_COUNT" >> "$DETAILS_REPORT"
            
            echo "Tracking all remote branches locally..."
            for branch in `git branch -r | grep -v '\->'`; do
                git branch --track ${branch#origin/} $branch 2>/dev/null || true
            done
            
            echo "Pulling all branches..."
            git pull --all
            
            echo "Backup of $REPO completed." >> "$DETAILS_REPORT"
            cd "$ORG_DIR"
        else
            ORG_FAILED_COUNT=$((ORG_FAILED_COUNT + 1))
        fi
        
        echo "" >> "$DETAILS_REPORT"
        
        # Check rate limit after each repository
        check_rate_limit
        
        # Introduce a small delay to avoid rate limiting
        sleep $SLEEP_TIME
    done
    
    # Write summary for the organization
    echo "Organization: $GITHUB_ORG" >> "$SUMMARY_REPORT"
    echo "----------------------------" >> "$SUMMARY_REPORT"
    echo "Total Repositories Processed: $ORG_REPO_COUNT" >> "$SUMMARY_REPORT"
    echo "Total Branches Backed Up: $ORG_BRANCH_COUNT" >> "$SUMMARY_REPORT"
    echo "Total Repositories Failed: $ORG_FAILED_COUNT" >> "$SUMMARY_REPORT"
    echo "" >> "$SUMMARY_REPORT"

    # Add organization summary to the final summary report
    echo "Organization: $GITHUB_ORG" >> "$FINAL_SUMMARY_REPORT"
    echo "----------------------------" >> "$FINAL_SUMMARY_REPORT"
    echo "Total Repositories Processed: $ORG_REPO_COUNT" >> "$FINAL_SUMMARY_REPORT"
    echo "Total Branches Backed Up: $ORG_BRANCH_COUNT" >> "$FINAL_SUMMARY_REPORT"
    echo "Total Repositories Failed: $ORG_FAILED_COUNT" >> "$FINAL_SUMMARY_REPORT"
    echo "" >> "$FINAL_SUMMARY_REPORT"
    
    # Accumulate final summary counts
    TOTAL_ORGS_REPO_COUNT=$((TOTAL_ORGS_REPO_COUNT + ORG_REPO_COUNT))
    TOTAL_ORGS_BRANCH_COUNT=$((TOTAL_ORGS_BRANCH_COUNT + ORG_BRANCH_COUNT))
    TOTAL_ORGS_FAILED_COUNT=$((TOTAL_ORGS_FAILED_COUNT + ORG_FAILED_COUNT))
    
    echo "Completed processing organization: $GITHUB_ORG"
done

# Write final summary for all organizations
echo "Final Summary for All Organizations" >> "$FINAL_SUMMARY_REPORT"
echo "-----------------------------------" >> "$FINAL_SUMMARY_REPORT"