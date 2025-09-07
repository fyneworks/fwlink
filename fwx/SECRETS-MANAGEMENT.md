# fwlink Secrets Management Guide

**Important: fwlink production deployment uses Google Cloud Secret Manager, NOT .env files.**

## 🔐 Production Secrets (Google Cloud Secret Manager)

All production configuration is managed via Google Cloud services:

### **Automatically Created Secrets**

These secrets are created during infrastructure setup:

| Secret Name | Purpose | Created By |
|-------------|---------|------------|
| `fwlink-jwt-secret` | JWT signing key | Infrastructure setup (auto-generated) |
| `fwlink-db-password` | Database password | Infrastructure setup (you provide) |
| `fwlink-mailgun-api-key` | Mailgun API key | Infrastructure setup (you provide) |
| `fwlink-mailgun-host` | Mailgun SMTP host | Infrastructure setup (auto-selected) |

### **Environment Variables Set Automatically**

These are set directly on Cloud Run (no secrets needed):

```bash
# Application Configuration
NODE_ENV=production
DEFAULT_DOMAIN=fwl.ink
SITE_NAME=fwLink
TRUST_PROXY=true

# Database Configuration  
DB_CLIENT=pg
DB_HOST=/cloudsql/fynewo:europe-west4:fwlink-db-prod
DB_PORT=5432
DB_NAME=fwlink
DB_USER=fwlink-user
DB_SSL=false

# Redis Configuration
REDIS_ENABLED=true
REDIS_HOST=10.x.x.x  # Auto-detected during deployment
REDIS_PORT=6379

# Email Configuration
MAIL_ENABLED=true
MAIL_PORT=587
MAIL_SECURE=true
MAIL_USER=api
MAIL_FROM="fwLink <noreply@fwl.ink>"
CONTACT_EMAIL=support@fyneworks.com
```

## 🛠️ Managing Production Secrets

### **View Current Secrets**
```bash
# List all fwlink secrets
gcloud secrets list --filter="name:fwlink"

# View secret metadata (not values)
gcloud secrets describe fwlink-jwt-secret
gcloud secrets describe fwlink-db-password  
gcloud secrets describe fwlink-mailgun-api-key
gcloud secrets describe fwlink-mailgun-host
```

### **Update Secrets**
```bash
# Update database password
echo "new-secure-password" | gcloud secrets versions add fwlink-db-password --data-file=-

# Update JWT secret  
echo "new-jwt-secret-32-chars-minimum" | gcloud secrets versions add fwlink-jwt-secret --data-file=-

# Update Mailgun API key
echo "key-your-new-mailgun-api-key" | gcloud secrets versions add fwlink-mailgun-api-key --data-file=-

# Update Mailgun region (US or EU)
echo "smtp.mailgun.org" | gcloud secrets versions add fwlink-mailgun-host --data-file=-          # US
echo "smtp.eu.mailgun.org" | gcloud secrets versions add fwlink-mailgun-host --data-file=-      # EU
```

### **Apply Secret Changes**
After updating secrets, redeploy to pick up the changes:
```bash
./fwx/scripts/deploy.sh
```

### **Helper Script for Mailgun**
Use the provided helper for easier Mailgun secret management:
```bash
./fwx/scripts/update-mailgun-secret.sh
```

## 🎯 Environment Variable Management

### **View Current Production Configuration**
```bash
# See all environment variables on Cloud Run
gcloud run services describe fwlink-prod --region=europe-west4 --format="yaml(spec.template.spec.template.spec.containers[0].env)"

# See specific variables
gcloud run services describe fwlink-prod --region=europe-west4 --format="table(spec.template.spec.template.spec.containers[0].env[].name,spec.template.spec.template.spec.containers[0].env[].value)"
```

### **Update Environment Variables**
```bash
# Update single variable
gcloud run services update fwlink-prod \
    --update-env-vars LINK_LENGTH=8 \
    --region=europe-west4

# Update multiple variables
gcloud run services update fwlink-prod \
    --update-env-vars LINK_LENGTH=8,ENABLE_RATE_LIMIT=true \
    --region=europe-west4

# Remove variable
gcloud run services update fwlink-prod \
    --remove-env-vars SOME_VARIABLE \
    --region=europe-west4
```

## 🏠 Local Development

**For local development only**, you can use a `.env` file:

### **Setup Local Development Environment**
```bash
# Copy template to project root
cp fwx/config/.env.development.template .env

# Edit .env with your local settings
nano .env

# Run locally
npm run dev
```

### **Local Development Options**

**Option 1: Connect to Cloud Resources**
```bash
# Start Cloud SQL proxy
cloud-sql-proxy fynewo:europe-west4:fwlink-db-prod

# Get database password from Secret Manager
gcloud secrets versions access latest --secret=fwlink-db-password

# Update .env with the password and run locally
```

**Option 2: Local SQLite (Easier)**
```bash
# In .env, use:
DB_CLIENT=better-sqlite3
DB_FILENAME=dev-data

# No additional setup needed
npm run dev
```

## 🔒 Security Best Practices

### **Secret Rotation**
- **JWT Secret**: Rotate every 6 months (invalidates all sessions)
- **Database Password**: Rotate every 3 months
- **Mailgun API Key**: Rotate when compromised or yearly

### **Access Control**
```bash
# View who has access to secrets
gcloud secrets get-iam-policy fwlink-jwt-secret

# Grant access to specific user/service account
gcloud secrets add-iam-policy-binding fwlink-jwt-secret \
    --member="user:developer@fyneworks.com" \
    --role="roles/secretmanager.secretAccessor"
```

### **Audit Trail**
```bash
# View secret access logs
gcloud logging read "resource.type=secretmanager.googleapis.com/Secret AND protoPayload.resourceName:fwlink-jwt-secret" --limit=50
```

## ❌ What NOT to Do

- ❌ **Don't create .env files in production** - They won't be used
- ❌ **Don't commit .env files** - They're in .gitignore for a reason  
- ❌ **Don't put secrets in environment variables** - Use Secret Manager
- ❌ **Don't share secrets via chat/email** - Use secure sharing methods

## 🆘 Troubleshooting

### **Secret Access Issues**
```bash
# Test secret access
gcloud secrets versions access latest --secret=fwlink-jwt-secret

# Check Cloud Run service account permissions
gcloud run services describe fwlink-prod --region=europe-west4 --format="value(spec.template.spec.serviceAccountName)"
```

### **Environment Variable Issues**
```bash
# View exact variables sent to container
gcloud run services logs read fwlink-prod --region=europe-west4 --filter="environment" --limit=10
```

### **Configuration Validation**
The app will fail to start if required secrets are missing or invalid. Check logs:
```bash
gcloud run services logs read fwlink-prod --region=europe-west4 --limit=20
```

## 📋 Configuration Checklist

### **Production Deployment**
- [ ] All 4 secrets exist in Secret Manager
- [ ] Cloud Run service has access to secrets
- [ ] Environment variables are set via Cloud Build/Run
- [ ] No .env files in production deployment
- [ ] Mailgun domain is verified
- [ ] Database user has correct permissions

### **Local Development**
- [ ] `.env` file created from template
- [ ] Database connection configured (Cloud SQL or SQLite)
- [ ] JWT_SECRET set to development value
- [ ] Email disabled or configured for testing

---

**Key Point**: Production uses Google Cloud Secret Manager + environment variables. Local development can optionally use .env files. No manual .env file management needed for production!