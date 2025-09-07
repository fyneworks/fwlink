# fwlink Troubleshooting Guide

Common issues and their solutions for fwlink deployment on Google Cloud.

## 🚨 Quick Diagnostic Commands

### First: Run Prerequisite Check
```bash
# Comprehensive system check
./fwx/scripts/check-prerequisites.sh

# Quick readiness check
./fwx/scripts/check-ready.sh
```

### Then: Check Service Status
```bash
# Check service status
gcloud run services describe fwlink-prod --region=europe-west4

# View recent logs
gcloud run services logs read fwlink-prod --region=europe-west4 --limit=50

# Check database status
gcloud sql instances describe fwlink-db-prod

# Check Redis status
gcloud redis instances describe fwlink-redis-prod --region=europe-west4

# List recent builds
gcloud builds list --limit=5
```

## 🏗️ Infrastructure Issues

### Cloud SQL Database Problems

**Issue**: Database connection failed
```
Error: connect ECONNREFUSED 127.0.0.1:5432
```

**Solutions**:
```bash
# 1. Check if Cloud SQL instance is running
gcloud sql instances describe fwlink-db-prod --format="value(state)"

# 2. Check if database exists
gcloud sql databases list --instance=fwlink-db-prod

# 3. Test database connection
gcloud sql connect fwlink-db-prod --user=fwlink-user --database=fwlink

# 4. Check Cloud SQL proxy connection in logs
gcloud run services logs read fwlink-prod --region=europe-west4 --filter="cloud-sql-proxy"

# 5. Restart the service
gcloud run services update fwlink-prod --region=europe-west4 --port=3000
```

**Issue**: Database user authentication failed
```
Error: password authentication failed for user "fwlink-user"
```

**Solutions**:
```bash
# 1. Check if user exists
gcloud sql users list --instance=fwlink-db-prod

# 2. Reset user password
NEW_PASSWORD="your-new-secure-password"
gcloud sql users set-password fwlink-user --instance=fwlink-db-prod --password="$NEW_PASSWORD"

# 3. Update secret with new password
echo "$NEW_PASSWORD" | gcloud secrets versions add fwlink-db-password --data-file=-

# 4. Redeploy to pick up new password
./fwx/scripts/deploy.sh
```

### Redis Connection Issues

**Issue**: Redis connection timeout
```
Error: Connection timeout to Redis
```

**Solutions**:
```bash
# 1. Get current Redis IP
./fwx/scripts/get-redis-ip.sh

# 2. Update Cloud Run with correct Redis IP
REDIS_IP="your-redis-ip-here"
gcloud run services update fwlink-prod \
    --update-env-vars REDIS_HOST=$REDIS_IP \
    --region=europe-west4

# 3. Check Redis instance status
gcloud redis instances describe fwlink-redis-prod --region=europe-west4 --format="value(state)"

# 4. If Redis is down, contact Google Cloud support
```

### Artifact Registry Issues

**Issue**: Push to registry failed
```
Error: denied: Permission "artifactregistry.repositories.uploadArtifacts" denied
```

**Solutions**:
```bash
# 1. Configure Docker authentication
gcloud auth configure-docker europe-west4-docker.pkg.dev

# 2. Check repository exists
gcloud artifacts repositories list --location=europe-west4

# 3. Create repository if missing
gcloud artifacts repositories create fwlink \
    --repository-format=docker \
    --location=europe-west4 \
    --description="fwlink container images"

# 4. Check IAM permissions
gcloud projects get-iam-policy fynewo --filter="bindings.members:user:$(gcloud config get-value account)"
```

## 🚀 Deployment Issues

### Cloud Build Failures

**Issue**: Build timeout
```
Error: build step 0 "gcr.io/cloud-builders/docker" failed: context deadline exceeded
```

**Solutions**:
```bash
# 1. Check build logs
BUILD_ID=$(gcloud builds list --limit=1 --format="value(id)")
gcloud builds log $BUILD_ID

# 2. Retry build with higher timeout
gcloud builds submit \
    --config=fwx/gcp/cloudbuild.yaml \
    --timeout=1200s \
    --substitutions=_ENVIRONMENT=prod,_REGION=europe-west4

# 3. Use more powerful build machine
# Edit fwx/gcp/cloudbuild.yaml and change machineType to E2_HIGHCPU_8
```

**Issue**: Docker build failed
```
Error: failed to build: step 0: build step 0 failed: No such file or directory
```

**Solutions**:
```bash
# 1. Check if Dockerfile exists
ls -la fwx/docker/Dockerfile.production

# 2. Check build context (run from project root)
pwd  # Should be /path/to/fwlink

# 3. Clean build and retry
gcloud builds submit --config=fwx/gcp/cloudbuild.yaml --no-cache
```

### Cloud Run Deployment Issues

**Issue**: Service deployment failed
```
Error: The user-provided container failed to start and listen on the port defined provided by the PORT=3000 environment variable
```

**Solutions**:
```bash
# 1. Check if app is starting correctly
gcloud run services logs read fwlink-prod --region=europe-west4 --limit=100

# 2. Check environment variables
gcloud run services describe fwlink-prod --region=europe-west4 --format="value(spec.template.spec.template.spec.containers[0].env[].name,spec.template.spec.template.spec.containers[0].env[].value)"

# 3. Test locally first
docker build -f fwx/docker/Dockerfile.production -t fwlink-test .
docker run -p 3000:3000 -e NODE_ENV=development fwlink-test

# 4. Deploy with more verbose logging
gcloud run deploy fwlink-prod \
    --image=europe-west4-docker.pkg.dev/fynewo/fwlink/fwlink:latest \
    --region=europe-west4 \
    --set-env-vars=DEBUG=* \
    --verbosity=debug
```

**Issue**: Service getting 502/503 errors
```
Error: upstream connect error or disconnect/reset before headers
```

**Solutions**:
```bash
# 1. Check service health
SERVICE_URL=$(gcloud run services describe fwlink-prod --region=europe-west4 --format="value(status.url)")
curl -I $SERVICE_URL

# 2. Increase memory allocation
gcloud run services update fwlink-prod \
    --memory=1Gi \
    --cpu=2 \
    --region=europe-west4

# 3. Check for startup issues in logs
gcloud run services logs read fwlink-prod --region=europe-west4 --filter="severity>=ERROR"

# 4. Adjust timeout settings
gcloud run services update fwlink-prod \
    --timeout=300 \
    --region=europe-west4
```

## 🔧 Application Issues

### Database Migration Failures

**Issue**: Migration failed during deployment
```
Error: Migration failed: relation "users" already exists
```

**Solutions**:
```bash
# 1. Connect to database and check state
gcloud sql connect fwlink-db-prod --user=fwlink-user --database=fwlink

# In PostgreSQL console:
SELECT * FROM knex_migrations ORDER BY batch DESC LIMIT 10;
\dt  -- List all tables

# 2. If migrations are stuck, manually fix
# Reset migration state (CAREFUL - this can cause data loss)
DELETE FROM knex_migrations WHERE name = 'problematic_migration_name';

# 3. Run migrations manually
npm run migrate

# 4. Redeploy after fixing migration
./fwx/scripts/deploy.sh
```

### Missing Environment Variables

**Issue**: Application errors due to missing config
```
Error: JWT_SECRET is required
```

**Solutions**:
```bash
# 1. Check current environment variables
gcloud run services describe fwlink-prod --region=europe-west4 --format="yaml(spec.template.spec.template.spec.containers[0].env)"

# 2. Add missing environment variables
gcloud run services update fwlink-prod \
    --update-env-vars JWT_SECRET=your-secret-here \
    --region=europe-west4

# 3. Use secrets for sensitive data
echo "your-secret" | gcloud secrets create missing-secret --data-file=-
gcloud run services update fwlink-prod \
    --update-secrets=JWT_SECRET=missing-secret:latest \
    --region=europe-west4
```

### Performance Issues

**Issue**: Slow response times
```
Response times > 5 seconds
```

**Solutions**:
```bash
# 1. Check Cloud Run metrics
gcloud run services describe fwlink-prod --region=europe-west4 --format="value(status.url)"
# Visit Cloud Console for detailed metrics

# 2. Scale up resources
gcloud run services update fwlink-prod \
    --memory=2Gi \
    --cpu=4 \
    --concurrency=50 \
    --region=europe-west4

# 3. Check database performance
gcloud sql instances describe fwlink-db-prod --format="yaml(settings)"

# 4. Upgrade database tier if needed
gcloud sql instances patch fwlink-db-prod --tier=db-n1-standard-1

# 5. Check Redis performance
gcloud redis instances describe fwlink-redis-prod --region=europe-west4
```

## 🔐 Security Issues

### SSL/TLS Certificate Problems

**Issue**: Custom domain SSL not working
```
Error: NET::ERR_CERT_AUTHORITY_INVALID
```

**Solutions**:
```bash
# 1. Check domain mapping status
gcloud run domain-mappings describe your-domain.com --region=europe-west4

# 2. Verify DNS records are correct
nslookup your-domain.com

# 3. Wait for certificate provisioning (can take up to 24 hours)
gcloud run domain-mappings list --region=europe-west4

# 4. Force certificate renewal
gcloud run domain-mappings delete your-domain.com --region=europe-west4
gcloud run domain-mappings create --service=fwlink-prod --domain=your-domain.com --region=europe-west4
```

### Access Control Issues

**Issue**: Cannot access admin panel
```
Error: Unauthorized access
```

**Solutions**:
```bash
# 1. Check if registration is disabled
gcloud run services describe fwlink-prod --region=europe-west4 | grep DISALLOW_REGISTRATION

# 2. Enable registration temporarily
gcloud run services update fwlink-prod \
    --update-env-vars DISALLOW_REGISTRATION=false \
    --region=europe-west4

# 3. Create admin user, then disable registration again
gcloud run services update fwlink-prod \
    --update-env-vars DISALLOW_REGISTRATION=true \
    --region=europe-west4

# 4. Check database for existing users
gcloud sql connect fwlink-db-prod --user=fwlink-user --database=fwlink -c "SELECT email FROM users;"
```

## 📊 Monitoring and Logging

### Log Analysis

```bash
# Application errors
gcloud run services logs read fwlink-prod --region=europe-west4 --filter="severity>=ERROR" --limit=50

# Database connection logs
gcloud run services logs read fwlink-prod --region=europe-west4 --filter="database OR postgres OR sql" --limit=20

# Redis connection logs  
gcloud run services logs read fwlink-prod --region=europe-west4 --filter="redis OR cache" --limit=20

# Performance logs
gcloud run services logs read fwlink-prod --region=europe-west4 --filter="slow OR timeout OR performance" --limit=20

# Search for specific errors
gcloud run services logs read fwlink-prod --region=europe-west4 --filter="textPayload:\"specific error message\""
```

### Setting Up Alerts

```bash
# Create alerting policy for high error rates
gcloud alpha monitoring policies create --policy-from-file=- <<EOF
{
  "displayName": "fwlink High Error Rate",
  "conditions": [{
    "displayName": "Cloud Run Error Rate",
    "conditionThreshold": {
      "filter": "resource.type=\"cloud_run_revision\" resource.label.service_name=\"fwlink-prod\"",
      "comparison": "COMPARISON_GT",
      "thresholdValue": 0.1
    }
  }],
  "notificationChannels": [],
  "alertStrategy": {
    "autoClose": "1800s"
  }
}
EOF
```

## 🔄 Recovery Procedures

### Complete Service Recovery

If everything is broken:

```bash
# 1. Check infrastructure status
gcloud sql instances list --filter="name:fwlink"
gcloud redis instances list --region=europe-west4 --filter="name:fwlink"
gcloud run services list --filter="metadata.name:fwlink"

# 2. If infrastructure is healthy, redeploy from scratch
./fwx/scripts/deploy.sh

# 3. If infrastructure has issues, recreate (DATA WILL BE LOST)
# Only do this as last resort!
# ./fwx/scripts/setup-infrastructure.sh

# 4. Restore from backup if needed
gcloud sql backups list --instance=fwlink-db-prod
gcloud sql backups restore BACKUP_ID --restore-instance=fwlink-db-prod-new
```

### Data Recovery

```bash
# 1. List available backups
gcloud sql backups list --instance=fwlink-db-prod

# 2. Create point-in-time recovery
gcloud sql instances clone fwlink-db-prod fwlink-db-recovery \
    --point-in-time="2024-01-15T10:30:00Z"

# 3. Export specific data
gcloud sql export sql fwlink-db-prod gs://your-bucket/data-export.sql \
    --database=fwlink \
    --table=links
```

## 🆘 Getting Help

### Google Cloud Support

```bash
# Check quotas and limits
gcloud compute project-info describe --format="table(quotas.metric,quotas.usage,quotas.limit)"

# Open support case (requires support plan)
# Visit: https://cloud.google.com/support/

# Community support
# Visit: https://stackoverflow.com/questions/tagged/google-cloud-platform
```

### Application-Specific Support

```bash
# Check application version
SERVICE_URL=$(gcloud run services describe fwlink-prod --region=europe-west4 --format="value(status.url)")
curl "$SERVICE_URL/api/version" 2>/dev/null || echo "Version endpoint not available"

# Export configuration for support
gcloud run services describe fwlink-prod --region=europe-west4 --export > fwlink-config.yaml
```

## 📝 Useful Debug Commands

```bash
# Complete system status
echo "=== Cloud Run Status ===" && \
gcloud run services describe fwlink-prod --region=europe-west4 --format="value(status.conditions[0].type,status.conditions[0].status)" && \
echo "=== Database Status ===" && \
gcloud sql instances describe fwlink-db-prod --format="value(state)" && \
echo "=== Redis Status ===" && \
gcloud redis instances describe fwlink-redis-prod --region=europe-west4 --format="value(state)" && \
echo "=== Recent Builds ===" && \
gcloud builds list --limit=3 --format="table(id,status,createTime)"

# Network connectivity test
gcloud compute networks list
gcloud compute firewall-rules list --filter="name:default"

# Resource usage
gcloud run services describe fwlink-prod --region=europe-west4 --format="value(spec.template.spec.template.spec.containers[0].resources)"
```

---

**Remember**: Always check logs first, they usually contain the exact error message that will lead you to the solution.

**Still stuck?** Create a GitHub issue with:
1. The exact error message
2. Output of diagnostic commands above
3. Recent changes you made
4. Your deployment configuration