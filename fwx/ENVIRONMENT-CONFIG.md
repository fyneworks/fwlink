# fwlink Environment Configuration Guide

Understanding how environment variables work in your fwlink deployment.

## 🔧 Environment Configuration Workflow

### **You DON'T need to create `.env.production` manually!**

The deployment process handles environment configuration through Google Cloud services, not local `.env` files. Here's how it works:

## 📋 Configuration Sources (in order of precedence)

1. **Cloud Build/Cloud Run** (Primary) - Set via `gcloud` commands
2. **Secret Manager** (Sensitive data) - JWT secrets, database passwords  
3. **Application defaults** (Fallback) - Built into the application code

## 🚀 How Configuration Works During Deployment

### Infrastructure Setup (`./fwx/scripts/setup-infrastructure.sh`)
Creates the secrets but **doesn't require any `.env` files**:

```bash
# Creates these secrets automatically:
✅ fwlink-jwt-secret (randomly generated)
✅ fwlink-db-password (you'll be prompted to enter)
```

### Deployment (`./fwx/scripts/deploy.sh`)
Sets environment variables directly on Cloud Run:

```bash
# These are set automatically by the deployment script:
✅ NODE_ENV=production
✅ DB_CLIENT=pg
✅ DB_HOST=/cloudsql/fynewo:europe-west4:fwlink-db-prod
✅ DB_PORT=5432
✅ DB_NAME=fwlink
✅ DB_USER=fwlink-user
✅ REDIS_ENABLED=true
✅ REDIS_HOST=10.x.x.x (detected automatically)
✅ REDIS_PORT=6379
✅ TRUST_PROXY=true
```

**Secrets are injected automatically:**
```bash
✅ DB_PASSWORD (from Secret Manager)
✅ JWT_SECRET (from Secret Manager)
```

## 📝 When to Use the Templates

### `.env.production.template` - **Reference Only**
- Shows you what variables are being set
- Use for **understanding** the configuration
- Use for **customizing** after deployment
- **Don't create .env.production** - it won't be used!

### `.env.local.template` - **Local Development**
- Copy to `.env.local` for local development
- Used when running locally with `npm run dev`
- Connects to your cloud resources during development

## 🎯 Customizing Your Deployment

### Option 1: Customize During Initial Setup

Edit the deployment script before running it:

```bash
# Edit fwx/scripts/deploy.sh to customize default values
# Find this section and modify:
--set-env-vars \
'NODE_ENV=production,DB_CLIENT=pg,DEFAULT_DOMAIN=fwl.ink,SITE_NAME=fwLink'
```

### Option 2: Customize After Deployment

Update environment variables on the running service:

```bash
# Set your custom domain
gcloud run services update fwlink-prod \
    --update-env-vars DEFAULT_DOMAIN=fwl.ink \
    --region=europe-west4

# Set site name
gcloud run services update fwlink-prod \
    --update-env-vars SITE_NAME="fwLink" \
    --region=europe-west4

# Multiple variables at once
gcloud run services update fwlink-prod \
    --update-env-vars DEFAULT_DOMAIN=fwl.ink,SITE_NAME="fwLink",DISALLOW_REGISTRATION=false \
    --region=europe-west4
```

## 🔍 Current Configuration

Your deployment will use these values:

### Application Settings
- **Site Name**: `fwLink`
- **Default Domain**: `fwl.ink` ← Updated for you!
- **Email Domain**: `fyneworks.com` ← For email addresses

### Database (Automatic)
- **Type**: PostgreSQL on Cloud SQL
- **Host**: Cloud SQL Proxy connection
- **Database**: `fwlink`
- **User**: `fwlink-user`

### Redis (Automatic)  
- **Type**: Cloud Memorystore
- **Host**: Auto-detected IP address
- **Port**: `6379`

### Security (Automatic)
- **JWT Secret**: Random 32-character string
- **DB Password**: What you enter during setup
- **SSL**: Handled by Cloud Run

## 🛠️ Configuration Examples

### Minimal Production Config (Already Set)
```bash
# These are set by default in the deployment:
DEFAULT_DOMAIN=fwl.ink
SITE_NAME=fwLink  
TRUST_PROXY=true
DISALLOW_REGISTRATION=true
DISALLOW_ANONYMOUS_LINKS=false
```

### Email Configuration (Optional)
```bash
gcloud run services update fwlink-prod \
    --update-env-vars MAIL_ENABLED=true \
    --update-env-vars MAIL_FROM="fwLink <noreply@fyneworks.com>" \
    --update-env-vars CONTACT_EMAIL="support@fyneworks.com" \
    --region=europe-west4
```

### Advanced Configuration (Optional)
```bash
gcloud run services update fwlink-prod \
    --update-env-vars LINK_LENGTH=8 \
    --update-env-vars ENABLE_RATE_LIMIT=true \
    --update-env-vars CUSTOM_DOMAIN_USE_HTTPS=true \
    --region=europe-west4
```

## 📊 Viewing Current Configuration

```bash
# See all environment variables
gcloud run services describe fwlink-prod \
    --region=europe-west4 \
    --format="table(spec.template.spec.template.spec.containers[0].env[].name,spec.template.spec.template.spec.containers[0].env[].value)"

# See only custom variables (easier to read)
gcloud run services describe fwlink-prod \
    --region=europe-west4 \
    --format="value(spec.template.spec.template.spec.containers[0].env[].name,spec.template.spec.template.spec.containers[0].env[].value)" | \
    grep -E "(DOMAIN|SITE_NAME|MAIL|LINK_LENGTH)"
```

## 🔐 Secret Management

### View Secrets
```bash
# List all secrets
gcloud secrets list --filter="name:fwlink"

# View secret versions (not values)
gcloud secrets versions list fwlink-jwt-secret
```

### Update Secrets
```bash
# Update JWT secret
echo "new-super-secure-jwt-secret-32-chars" | gcloud secrets versions add fwlink-jwt-secret --data-file=-

# Update database password
echo "new-secure-db-password" | gcloud secrets versions add fwlink-db-password --data-file=-

# Redeploy to pick up new secrets
./fwx/scripts/deploy.sh
```

## 💡 Key Takeaways

1. **No manual `.env` files needed** - Everything is managed by Google Cloud
2. **Secrets are secure** - Stored in Secret Manager, not in environment variables
3. **Easy to update** - Use `gcloud run services update` commands
4. **Development setup** - Copy `.env.local.template` to `.env.local` for local work
5. **Domain is set** - `fwl.ink` for app, `fyneworks.com` for emails

## 🎯 Your Next Steps

1. **Run the deployment as-is** - Configuration is already optimized for `fwl.ink`
2. **Set up your domain** - Point `fwl.ink` DNS to your Cloud Run service
3. **Customize later** - Use `gcloud` commands to adjust settings after deployment

---

**Remember**: The templates are for **reference and local development only**. Production configuration is managed entirely through Google Cloud services!