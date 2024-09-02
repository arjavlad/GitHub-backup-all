# GitHub Organization Repositories Backup Script

This script automates the process of backing up all branches of all repositories from specified GitHub organizations. It retrieves repositories, fetches and tracks all branches locally, handles GitHub API rate limits, and generates detailed and summary reports for each organization.

## Features

- **Backup All Repositories**: Clones all repositories from specified organizations and fetches all branches.
- **Handles Private Repositories**: Supports private repositories using a GitHub personal access token.
- **Rate Limit Management**: Automatically handles GitHub API rate limits by pausing when necessary.
- **Detailed Reporting**: Generates detailed reports on the status of each repository backup.
- **Organization Summaries**: Provides summary reports for each organization and a final summary for all organizations combined.

## Prerequisites

- **Git**: Ensure Git is installed on your system.
- **jq**: A command-line JSON processor. You can install it via Homebrew:

  ```bash
  brew install jq
  ```

- **GitHub Personal Access Token**: You need a GitHub personal access token with access to the repositories you wish to back up. Make sure the token has the `repo` scope for accessing private repositories.

## Usage

1. **Clone the Repository**: First, clone this script repository to your local machine:

   ```bash
   git clone https://github.com/yourusername/your-repo.git
   cd your-repo
   ```

2. **Make the Script Executable**: Ensure the script is executable:

   ```bash
   chmod +x backup_repos.sh
   ```

3. **Run the Script**: Execute the script by providing the necessary inputs:

   ```bash
   ./backup_repos.sh
   ```

4. **Enter Required Inputs**: The script will prompt you to enter the following:

   - **GitHub Token**: Your GitHub personal access token.
   - **Organization Names**: A space-separated list of GitHub organization names you want to back up.
   - **Sleep Time**: The time to wait between API calls to avoid rate limits (default is 2 seconds).

5. **Check Reports**: After the script completes, check the generated reports in the `github_backup` directory:

   - **Details Report**: Contains information on each repository, including the number of branches backed up and any errors encountered.
   - **Summary Report**: Provides a summary for each organization, including the total number of repositories processed and the total branches backed up.
   - **Final Summary Report**: A combined summary for all organizations.

## Example

```bash
Enter the GitHub token (required for private repositories): ghp_yourtoken
Enter the names of GitHub organizations (separated by space): org1 org2
Enter the sleep time between API calls in seconds (default is 2): 2
```

## Output

- The script will create a directory named github_backup in your home directory.
- Separate directories will be created for each organization within github_backup.
- Inside each organization’s directory, the repositories will be cloned, and two report files will be generated:
- details_report.txt
- summary_report.txt
- A final summary for all organizations will be available in final_summary_report.txt.

## Notes

- Ensure your GitHub token has sufficient permissions to access the repositories.
- The script is designed to handle large numbers of repositories and organizations, but be aware of GitHub API rate limits.
