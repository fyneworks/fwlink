# fwlink Initial Deployment Guide

This guide walks you through the complete initial setup of your fwlink URL shortener on Google Cloud Platform.

📋 **Related Documentation**:
- [Architecture Overview](../ARCHITECTURE.md) - Complete system architecture with diagrams
- [Custom Domains Setup](../CUSTOM-DOMAINS-SETUP.md) - Load balancer setup for unlimited custom domains

## 🔧 Prerequisites Check

**Before starting, run the prerequisite checker to avoid setup failures:**

```bash
# Run comprehensive prerequisite check
./fwx/scripts/check-prerequisites.sh
```

This will verify:
- ✅ Google Cloud CLI installed and authenticated
- ✅ Project `fynewo` configured with billing enabled  
- ✅ Required APIs enabled (or offer to enable them)
- ✅ Region availability and quotas
- ✅ No conflicting resources

### Manual Prerequisites (if needed)

If the checker finds issues:

1. **Install Google Cloud CLI**
   ```bash
   curl https://sdk.cloud.google.com | bash
   ```

2. **Authenticate**
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

3. **Configure Project**
   ```bash
   gcloud config set project fynewo
   ```

4. **Enable Billing**
   - Visit [Google Cloud Console](https://console.cloud.google.com/billing)
   - Ensure billing is enabled for project `fynewo`

## 🚀 Step-by-Step Initial Deployment

### Step 1: Setup Infrastructure

This creates all the backend resources you need.

```bash
# Make scripts executable
chmod +x fwx/scripts/*.sh

# Create all GCP resources (includes prerequisite check)
./fwx/scripts/setup-infrastructure.sh
```

**Note**: The setup script automatically runs the prerequisite check first and will stop if any critical issues are found.

**What this creates:**
- ✅ **Cloud SQL PostgreSQL** instance (`fwlink-db-prod`)
- ✅ **Redis/Memorystore** instance (`fwlink-redis-prod`) 
- ✅ **VPC Connector** for Redis connectivity (`fwlink-redis-connector`)
- ✅ **VPC Subnet** for connector (`fwlink-vpc-connector-subnet`)
- ✅ **Artifact Registry** repository for Docker images
- ✅ **Secret Manager** secrets for JWT, database password, and Mailgun SMTP credentials
- ✅ **Database** and **user** in PostgreSQL
- ✅ **Mailgun SMTP** configuration for fwl.ink domain
- ✅ **APIs enabled**: Cloud Run, SQL, Redis, Build, Registry, VPC Access

**Expected output:**
```
🚀 Setting up fwlink infrastructure...
Project: fynewo
Environment: prod
Region: europe-west4
----------------------------------------
📡 Enabling required Google Cloud APIs...
📦 Creating Artifact Registry repository...
🔐 Creating secrets...
Enter database password for fwlink user: [you'll be prompted]
🗄️  Creating Cloud SQL PostgreSQL instance...
👤 Creating database and user...
⚡ Creating Redis instance...
🌐 Setting up VPC connectivity for Redis access...
   Enabling Serverless VPC Access API...
   Creating VPC connector subnet...
   Creating VPC connector (this may take 2-3 minutes)...
✅ Infrastructure setup complete!
```

**Time estimate:** 8-15 minutes (Cloud SQL and VPC connector creation take the longest)

### Step 2: Verify Infrastructure

Check that everything was created successfully:

```bash
# Check Cloud SQL instance
gcloud sql instances list --filter="name:fwlink-db-prod"

# Check Redis instance  
gcloud redis instances list --region=europe-west4 --filter="name:fwlink-redis-prod"

# Check VPC connector
gcloud compute networks vpc-access connectors list --region=europe-west4 --filter="name:fwlink-redis-connector"

# Check secrets
gcloud secrets list --filter="name:fwlink"
```

### Step 3: Deploy the Application

Now deploy your fwlink application:

```bash
# Deploy to Cloud Run
./fwx/scripts/deploy.sh
```

**What this does:**
1. ✅ **Builds** Docker image using multi-stage build
2. ✅ **Pushes** image to Artifact Registry
3. ✅ **Gets** Redis IP automatically
4. ✅ **Deploys** to Cloud Run with:
   - PostgreSQL connection via Cloud SQL proxy
   - Redis connection via VPC connector
   - Secrets injection for JWT and DB password
   - Environment variables for production
5. ✅ **Runs** database migrations automatically
6. ✅ **Starts** the application

**Expected output:**
```
🚀 Deploying fwlink to Google Cloud Run...
Project: fynewo
Environment: prod
Region: europe-west4
Service: fwlink-prod
----------------------------------------
🔨 Starting Cloud Build...
   Building Docker image...
   Getting Redis IP: 10.158.123.45
   Deploying to Cloud Run with VPC connectivity...
✅ Deployment complete!

🌐 Service URL: https://fwlink-prod-xyz-ew.a.run.app
```

**Time estimate:** 3-5 minutes

### Step 4: Test Your Deployment

Test that everything is working:

```bash
# Get your service URL
SERVICE_URL=$(gcloud run services describe fwlink-prod --region=europe-west4 --format="value(status.url)")
echo "Your fwlink URL: $SERVICE_URL"

# Test the health endpoint (if available)
curl "$SERVICE_URL/api/health" || curl "$SERVICE_URL"
```

### Step 5: Configure Your Domain

Your app is configured to use `fwl.ink` as the default domain. Set up DNS:

```bash
# Map your domain to the service
gcloud run domain-mappings create \
    --service=fwlink-prod \
    --domain=fwl.ink \
    --region=europe-west4

# Get DNS records to configure
gcloud run domain-mappings describe \
    --domain=fwl.ink \
    --region=europe-west4
```

**Configure your DNS provider:**
1. Add the CNAME record shown in the command output
2. SSL certificate will be provisioned automatically (takes 15-60 minutes)

## 🔐 Configuration Management

### Production Configuration (Secret Manager)

**Important:** fwlink production uses **Google Cloud Secret Manager** for sensitive configuration, NOT .env files.

**View your production configuration:**
```bash
# List all secrets created during setup
gcloud secrets list --filter="name:fwlink"

# View environment variables on Cloud Run
gcloud run services describe fwlink-prod --region=europe-west4 --format="table(spec.template.spec.template.spec.containers[0].env[].name,spec.template.spec.template.spec.containers[0].env[].value)"
```

**For detailed configuration management, see:**
- [`fwx/SECRETS-MANAGEMENT.md`](SECRETS-MANAGEMENT.md) - Complete secrets and configuration guide

### Update Default Settings

1. **Access the admin panel** at your service URL
2. **Create your admin user account**
3. **Configure these settings:**
   - Site name: "fwLink"
   - Default domain: your custom domain
   - User registration policy

### Environment Variables

Key variables are automatically set, but you can customize:

```bash
# Update site configuration
gcloud run services update fwlink-prod \
    --update-env-vars SITE_NAME="Your Link Shortener" \
    --update-env-vars DEFAULT_DOMAIN="yourdomain.com" \
    --region=europe-west4
```

## 📊 Monitoring Setup

### Enable Logging
```bash
# View real-time logs
gcloud logs tail --filter='resource.type=cloud_run_revision AND resource.labels.service_name=fwlink-prod'

# View application logs
gcloud run services logs read fwlink-prod --region=europe-west4 --limit=100
```

### Set up Monitoring Alerts (Optional)
```bash
# Create uptime check
gcloud alpha monitoring uptime create \
    --display-name="fwlink Health Check" \
    --http-check-path="/api/health" \
    --hostname="your-service-url"
```

## 💰 Cost Summary

**Estimated monthly costs (low traffic):**
- Cloud Run: $0-5 (scales to zero)
- Cloud SQL (f1-micro): ~$7
- Redis (1GB basic): ~$25
- **Total: ~$32-37/month**

**For higher traffic:**
- Upgrade Cloud SQL to db-n1-standard-1: ~$25
- Increase Redis to standard tier: ~$50
- **Total: ~$75-80/month**

## ✅ Deployment Checklist

- [ ] Prerequisites installed and configured
- [ ] Billing enabled on project fynewo
- [ ] Infrastructure setup completed successfully
- [ ] Redis IP obtained and noted
- [ ] Application deployed to Cloud Run
- [ ] Service URL accessible and working
- [ ] Custom domain configured (optional)
- [ ] Admin user created
- [ ] Basic settings configured

## 🆘 Quick Troubleshooting

**Database connection issues:**
```bash
# Check Cloud SQL status
gcloud sql instances describe fwlink-db-prod

# Test database connection
gcloud sql connect fwlink-db-prod --user=fwlink-user
```

**Redis connection issues:**
```bash
# Check VPC connector status
gcloud compute networks vpc-access connectors describe fwlink-redis-connector --region=europe-west4

# Verify Cloud Run has VPC access configured
gcloud run services describe fwlink-prod --region=europe-west4 --format="yaml" | grep -A5 vpc

# Check Redis IP in environment variables
gcloud run services describe fwlink-prod --region=europe-west4 --format="yaml" | grep REDIS_HOST -A1
```

**Build failures:**
```bash
# Check recent builds
gcloud builds list --limit=5

# View build logs
gcloud builds log $(gcloud builds list --limit=1 --format="value(id)")
```

## 🎉 Success!

Your fwlink URL shortener is now live at your Cloud Run service URL! 

**Next steps:**
- See `fwx/UPDATE-DEPLOYMENT.md` for how to deploy updates
- Configure custom domain and SSL
- Set up monitoring and alerting
- Customize the UI and branding

---

**Need help?** Check `fwx/TROUBLESHOOTING.md` or review the logs using the commands above.