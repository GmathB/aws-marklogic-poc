# GitHub Actions Setup Instructions

## Prerequisites
1. GitHub repository created for this Terraform code
2. AWS account with permissions to create IAM OIDC provider

## Step 1: Update GitHub OIDC Configuration

Edit `github_oidc.tf` and replace the following line (line 38):

```terraform
"token.actions.githubusercontent.com:sub" = "repo:YOUR_GITHUB_USERNAME/YOUR_REPO_NAME:*"
```

Replace with your actual GitHub username and repository name:
```terraform
"token.actions.githubusercontent.com:sub" = "repo:yourusername/aws-marklogic:*"
```

## Step 2: Deploy GitHub OIDC Infrastructure

```bash
# Initialize and apply the OIDC configuration
terraform init
terraform apply

# Note the output - you'll need this for GitHub
terraform output github_actions_role_arn
```

Copy the Role ARN output (will look like: `arn:aws:iam::013596899729:role/github-actions-terraform-role`)

## Step 3: Configure GitHub Repository Secrets

Go to your GitHub repository:
1. Navigate to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add the following secret:
   - Name: `AWS_ROLE_ARN`
   - Value: (paste the Role ARN from Step 2)

## Step 4: Configure GitHub Environments (for approval gates)

1. Go to **Settings** → **Environments**
2. Create two environments:

### Production Environment
   - Name: `production`
   - Add protection rules:
     - ✓ Required reviewers (add yourself or team members)
     - ✓ Wait timer: 0 minutes (or set a delay)

### Destroy Environment
   - Name: `destroy`
   - Add protection rules:
     - ✓ Required reviewers (add yourself or team members)
     - ⚠️ This requires manual approval before destroying infrastructure

## Step 5: Push Code to GitHub

```bash
# Initialize git repository (if not already done)
git init
git add .
git commit -m "Initial commit with GitHub Actions workflow"

# Add remote and push
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
git branch -M main
git push -u origin main
```

## Step 6: Verify Workflow

1. Go to your GitHub repository
2. Click on **Actions** tab
3. You should see the workflow running automatically
4. The workflow will:
   - ✓ Validate Terraform code
   - ✓ Run `terraform plan`
   - ⏸️ Wait for manual approval (production environment)
   - ✓ Run `terraform apply` after approval

## Workflow Triggers

The workflow will automatically run when:
- ✅ Push to `main` branch (with `.tf` or `.sh` file changes)
- ✅ Pull request to `main` branch (plan only, no apply)
- ✅ Manual trigger via "Run workflow" button

## Security Features

✓ **OIDC Authentication**: No long-lived AWS credentials stored in GitHub
✓ **Short-lived tokens**: AWS credentials expire after each workflow run
✓ **Repository restriction**: IAM role can only be assumed by your specific repo
✓ **Manual approval**: Production changes require human approval
✓ **PR comments**: Terraform plan is automatically posted to pull requests
✓ **Least privilege**: IAM role has only necessary permissions

## Troubleshooting

### Error: "Not authorized to perform sts:AssumeRoleWithWebIdentity"
- Verify the repository name in `github_oidc.tf` matches your actual repo
- Ensure the OIDC provider is created in AWS
- Check that `AWS_ROLE_ARN` secret is set correctly in GitHub

### Error: "Backend initialization required"
- Ensure S3 bucket exists: `marklogic-terraform-state-013596899729`
- Verify GitHub Actions role has S3 permissions

### Workflow doesn't trigger
- Check that file changes are in `.tf` or `.sh` files
- Verify workflow file is in `.github/workflows/` directory
- Check branch name is `main` (not `master`)

## Manual Workflow Dispatch

To manually trigger the workflow:
1. Go to **Actions** tab
2. Select "Terraform AWS MarkLogic Deployment"
3. Click **Run workflow**
4. Select branch and click **Run workflow**

## Destroying Infrastructure

To destroy infrastructure via GitHub Actions:
1. Go to **Actions** tab
2. Click **Run workflow**
3. This will trigger the `terraform-destroy` job
4. Requires manual approval in the `destroy` environment
5. ⚠️ **WARNING**: This will delete all AWS resources

## Best Practices

1. **Always review the plan** before approving apply
2. **Use pull requests** for infrastructure changes
3. **Test in a separate environment** before production
4. **Monitor workflow runs** for failures
5. **Rotate OIDC thumbprints** if GitHub updates their certificates
6. **Review IAM permissions** regularly for least privilege

## Additional Configuration (Optional)

### Enable Terraform Cloud/Enterprise
Update workflow to use Terraform Cloud for remote state and policy checks.

### Add Cost Estimation
Integrate Infracost to estimate AWS costs in pull requests.

### Add Security Scanning
Integrate tfsec, Checkov, or Snyk for security scanning.

### Slack Notifications
Add Slack notifications for workflow success/failure.
