# GitHub Deployment Issues - Troubleshooting Guide

## Common Issues and Solutions

### 1. "location is not a known attribute of class SiteSourceControl"

**Problem**: This error occurs when there's a version mismatch between Azure CLI and the Azure Python SDK.

**Solutions**:

1. **Update Azure CLI**:
   ```bash
   # Update Azure CLI to latest version
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   
   # Or use pip
   pip install --upgrade azure-cli
   ```

2. **Use alternative deployment method**:
   The updated scripts now include fallback configuration using app settings instead of source control configuration.

### 2. "Operation returned an invalid status 'OK'"

**Problem**: This error indicates that the operation succeeded but the response parsing failed.

**Solutions**:

1. **Suppress output and ignore status parsing**:
   ```bash
   az webapp deployment source config \
       --name $APP_NAME \
       --resource-group $RESOURCE_GROUP \
       --repo-url https://github.com/danipopa/ai-receptionist \
       --branch main \
       --manual-integration \
       --output none 2>/dev/null
   ```

2. **Check deployment status manually**:
   ```bash
   az webapp deployment source show \
       --name $APP_NAME \
       --resource-group $RESOURCE_GROUP
   ```

### 3. Improved Deployment Scripts

The deployment scripts have been updated with:

- **Error handling**: Commands now suppress stderr and use fallback methods
- **Status checking**: Scripts check if deployment source is already configured
- **Alternative configuration**: Uses app settings as fallback when source control fails
- **Better logging**: Added warning messages for non-critical issues

### 4. Manual GitHub Deployment Configuration

If automated configuration fails, you can configure GitHub deployment manually:

1. **Via Azure Portal**:
   - Go to your App Service in Azure Portal
   - Navigate to Deployment Center
   - Select GitHub as source
   - Authorize and configure repository

2. **Via Azure CLI (alternative method)**:
   ```bash
   # Set repository URL as app setting
   az webapp config appsettings set \
       --name $APP_NAME \
       --resource-group $RESOURCE_GROUP \
       --settings \
           DEPLOYMENT_BRANCH=main \
           REPOSITORY_URL=https://github.com/danipopa/ai-receptionist
   ```

### 5. Verification Commands

After deployment, verify the configuration:

```bash
# Check deployment source
az webapp deployment source show \
    --name $APP_NAME \
    --resource-group $RESOURCE_GROUP

# Check app settings
az webapp config appsettings list \
    --name $APP_NAME \
    --resource-group $RESOURCE_GROUP

# Check deployment logs
az webapp log deployment list \
    --name $APP_NAME \
    --resource-group $RESOURCE_GROUP
```

### 6. Environment Requirements

Ensure your environment meets these requirements:

- **Azure CLI**: Version 2.30.0 or later
- **Git**: Version 2.20.0 or later
- **Bash**: Version 4.0 or later

Check versions:
```bash
az --version
git --version
bash --version
```

### 7. Alternative Deployment Methods

If GitHub deployment continues to fail, consider these alternatives:

1. **Local Git deployment**:
   ```bash
   az webapp deployment source config-local-git \
       --name $APP_NAME \
       --resource-group $RESOURCE_GROUP
   ```

2. **ZIP deployment**:
   ```bash
   # Build locally and deploy ZIP
   cd frontend
   npm run build
   zip -r ../app.zip dist/
   az webapp deployment source config-zip \
       --name $APP_NAME \
       --resource-group $RESOURCE_GROUP \
       --src ../app.zip
   ```

3. **Container deployment**:
   Use Docker containers instead of source code deployment.

## Prevention

To avoid these issues in the future:

1. Keep Azure CLI updated
2. Use the improved deployment scripts
3. Test deployment in a development environment first
4. Monitor Azure service health for known issues

## Support

If issues persist:

1. Check Azure Service Health dashboard
2. Review Azure CLI release notes
3. Contact Azure Support for service-specific issues
4. Use Azure Cloud Shell as an alternative environment
