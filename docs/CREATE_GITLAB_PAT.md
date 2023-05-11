# Create Personal Access Token for GitLab

This project assumes the use of GitLab for gitops. If another gitops manager is prefered, please work with your Google Cloud CE to determine viability and implementation

## 
1. [Create a new PAT token](https://docs.gitlab.com/ee/user/project/deploy_tokens/) and save the credentials for the steps below. ![gitlab token](Gitlab_token.png)
    1. Go to user **Preferences** on the top right corner. On the left menu, select **Access Tokens**
    2. Choose a "Token name" name that will be used later in this installation as an environment variable
        **SCM_TOKEN_USER**.
    3. Create the PAT with **read_repository** privilege.
    4. The produced token value that will be uesd later in this installation as an environment variable
        **SCM_TOKEN_TOKEN**.