# fwlink Update Deployment Guide

This guide covers how to deploy updates to your fwlink application **without losing any data**. Your database and Redis data will remain intact during updates.

## 🔄 Update Types

### 1. Code Updates (Most Common)
- Application code changes
- UI improvements
- Bug fixes
- New features

### 2. Configuration Updates
- Environment variables
- Settings changes
- Domain updates

### 3. Infrastructure Updates
- Database scaling
- Resource allocation changes

## 🚀 Quick Update (Code Changes)

For most updates, you only need one command:

```bash
# Deploy latest code changes
./fwx/scripts/deploy.sh
```

**What this does:**
1. ✅ **Builds** new Docker image with your latest code
2. ✅ **Pushes** image to Artifact Registry  
3. ✅ **Deploys** to Cloud Run with zero downtime
4. ✅ **Runs** database migrations (if any)
5. ✅ **Preserves** all existing data
6. ✅ **Updates** environment configuration

**Time estimate:** 2-4 minutes

## 📋 Detailed Update Process

### Step 1: Prepare for Update

```bash
# 1. Check current deployment status
gcloud run services describe fwlink-prod --region=europe-west4

# 2. View recent logs to ensure app is healthy
gcloud run services logs read fwlink-prod --region=europe-west4 --limit=10

# 3. Optional: Create database backup
gcloud sql backups create --instance=fwlink-db-prod --description="Pre-update backup $(date +%Y%m%d-%H%M)"
```

### Step 2: Deploy Update

```bash
# Deploy the update
./fwx/scripts/deploy.sh
```

**Expected output:**
```
🚀 Deploying fwlink to Google Cloud Run...
Project: fynewo
Environment: prod
Region: europe-west4
Service: fwlink-prod
----------------------------------------
🔍 Getting Redis IP address...
✅ Redis IP: 10.158.123.45
🔨 Starting Cloud Build...
⚡ Updating Redis configuration...
✅ Deployment complete!

🌐 Service URL: https://fwlink-prod-xyz-ew.a.run.app
```

### Step 3: Verify Update

```bash
# 1. Test the service is responding
curl -I $(gcloud run services describe fwlink-prod --region=europe-west4 --format="value(status.url)")

# 2. Check application logs for any errors
gcloud run services logs read fwlink-prod --region=europe-west4 --limit=20

# 3. Verify database connectivity
gcloud sql connect fwlink-db-prod --user=fwlink-user --database=fwlink
# Run: \dt to list tables and verify data exists
```

## 🔧 Configuration Updates

**Important:** fwlink uses **Google Cloud Secret Manager** for sensitive configuration, not .env files.

### Update Environment Variables

```bash
# Update single environment variable
gcloud run services update fwlink-prod \
    --update-env-vars SITE_NAME="New Site Name" \
    --region=europe-west4

# Update multiple variables
gcloud run services update fwlink-prod \
    --update-env-vars SITE_NAME="fwLink Pro",LINK_LENGTH=8 \
    --region=europe-west4
```

### Update Secrets

```bash
# Update JWT secret
echo "new-jwt-secret-32-chars-minimum" | gcloud secrets versions add fwlink-jwt-secret --data-file=-

# Update database password  
echo "new-secure-password" | gcloud secrets versions add fwlink-db-password --data-file=-

# Update Mailgun API key
echo "key-your-new-mailgun-api-key" | gcloud secrets versions add fwlink-mailgun-api-key --data-file=-

# After updating secrets, redeploy to pick up changes
./fwx/scripts/deploy.sh
```

**For complete secrets management, see:** [`fwx/SECRETS-MANAGEMENT.md`](SECRETS-MANAGEMENT.md)

### Update Domain Configuration

```bash
# Add new custom domain
gcloud run domain-mappings create \
    --service=fwlink-prod \
    --domain=new-domain.com \
    --region=europe-west4

# Update default domain in app
gcloud run services update fwlink-prod \
    --update-env-vars DEFAULT_DOMAIN="new-domain.com" \
    --region=europe-west4
```

## 📊 Database Migrations

Database migrations run automatically during deployment, but you can also run them manually:

### Automatic Migrations (Recommended)
Migrations run automatically when the container starts. This is the default behavior.

### Manual Migration Control

If you want more control over migrations:

1. **Disable auto-migrations** (edit Dockerfile):
   ```bash
   # Comment out migration in Dockerfile CMD and rebuild
   # CMD ["sh", "-c", "cloud-sql-proxy --port 5432 fynewo:europe-west4:fwlink-db & npm start"]
   ```

2. **Run migrations separately**:
   ```bash
   # Connect to Cloud SQL directly
   gcloud sql connect fwlink-db-prod --user=fwlink-user --database=fwlink
   
   # Or run migration via Cloud Run job
   gcloud run jobs create fwlink-migrate \
       --image=europe-west4-docker.pkg.dev/fynewo/fwlink/fwlink:latest \
       --task-completion-delay=60s \
       --command="npm" \
       --args="run,migrate" \
       --region=europe-west4
   ```

## 🔄 Rollback Process

If something goes wrong, you can quickly rollback:

### Quick Rollback to Previous Version

```bash
# List recent revisions
gcloud run revisions list --service=fwlink-prod --region=europe-west4

# Rollback to previous revision
PREVIOUS_REVISION=$(gcloud run revisions list --service=fwlink-prod --region=europe-west4 --format="value(metadata.name)" --limit=2 | tail -1)

gcloud run services update-traffic fwlink-prod \
    --to-revisions=$PREVIOUS_REVISION=100 \
    --region=europe-west4
```

### Rollback Database (If Needed)

```bash
# List available backups
gcloud sql backups list --instance=fwlink-db-prod

# Restore from backup (creates new instance)
gcloud sql backups restore BACKUP_ID \
    --restore-instance=fwlink-db-prod-restored \
    --backup-instance=fwlink-db-prod
```

## 📈 Scaling Updates

### Vertical Scaling (More Resources)

```bash
# Increase memory and CPU
gcloud run services update fwlink-prod \
    --memory=1Gi \
    --cpu=2 \
    --region=europe-west4

# Adjust concurrency
gcloud run services update fwlink-prod \
    --concurrency=100 \
    --region=europe-west4
```

### Database Scaling

```bash
# Upgrade database tier
gcloud sql instances patch fwlink-db-prod \
    --tier=db-n1-standard-1

# Increase storage (if needed)
gcloud sql instances patch fwlink-db-prod \
    --storage-size=20GB
```

### Redis Scaling

```bash
# Scale Redis instance
gcloud redis instances update fwlink-redis-prod \
    --size=2 \
    --region=europe-west4
```

## 🔍 Monitoring Updates

### Check Deployment Status

```bash
# Monitor deployment progress
gcloud run services describe fwlink-prod --region=europe-west4

# Watch logs during deployment
gcloud logs tail --filter='resource.type=cloud_run_revision AND resource.labels.service_name=fwlink-prod'
```

### Health Checks

```bash
# Basic health check
SERVICE_URL=$(gcloud run services describe fwlink-prod --region=europe-west4 --format="value(status.url)")
curl -f "$SERVICE_URL" && echo "✅ Service is healthy"

# Database connectivity check
gcloud sql connect fwlink-db-prod --user=fwlink-user --database=fwlink -c "SELECT 1;"

# Redis connectivity (from within app logs)
gcloud run services logs read fwlink-prod --region=europe-west4 --filter="Redis"
```

## 📅 Update Schedule Recommendations

### Regular Updates
- **Code updates**: As needed (bug fixes, features)
- **Security updates**: Monthly or as needed
- **Dependency updates**: Quarterly

### Maintenance Windows
- **Best time**: Low traffic hours (typically 2-6 AM local time)
- **Notifications**: Consider notifying users of major updates

### Backup Schedule
```bash
# Set up automated daily backups (already configured)
gcloud sql instances patch fwlink-db-prod \
    --backup-start-time=03:00 \
    --enable-bin-log
```

## 🛡️ Safe Update Practices

### Pre-Update Checklist
- [ ] Code tested locally
- [ ] Database backup created (if major changes)
- [ ] Current service is healthy
- [ ] Low traffic period chosen
- [ ] Rollback plan ready

### During Update
- [ ] Monitor logs for errors
- [ ] Test critical functionality
- [ ] Check database connectivity
- [ ] Verify external integrations

### Post-Update
- [ ] Full functionality test
- [ ] Performance check
- [ ] Error log review
- [ ] User feedback monitoring

## 🚨 Emergency Procedures

### Service Down
```bash
# Quick rollback to previous version
gcloud run revisions list --service=fwlink-prod --region=europe-west4
gcloud run services update-traffic fwlink-prod --to-revisions=PREVIOUS_REVISION=100 --region=europe-west4
```

### Database Issues
```bash
# Check database status
gcloud sql operations list --instance=fwlink-db-prod --limit=5

# Connect for manual inspection
gcloud sql connect fwlink-db-prod --user=fwlink-user
```

### Redis Issues
```bash
# Check Redis status
gcloud redis instances describe fwlink-redis-prod --region=europe-west4

# Restart Redis if needed
gcloud redis instances failover fwlink-redis-prod --region=europe-west4
```

## 📊 Update Tracking

Keep track of your updates:

```bash
# View deployment history
gcloud run revisions list --service=fwlink-prod --region=europe-west4

# View Cloud Build history
gcloud builds list --limit=10

# Tag releases in git
git tag -a v1.1.0 -m "Release v1.1.0 with new features"
git push origin v1.1.0
```

## 💡 Best Practices

1. **Always test locally first**
2. **Use feature flags** for major changes
3. **Monitor logs** during and after updates
4. **Keep backups** before significant changes
5. **Document changes** in git commits
6. **Update staging environment** first (if you have one)

---

**Remember**: Your database data is always preserved during updates. The deployment process is designed to be safe and maintain data integrity.

**Need help?** Check `fwx/TROUBLESHOOTING.md` for common issues and solutions.