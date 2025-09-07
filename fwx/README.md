# fwlink Google Cloud Deployment

Deploy your fwlink URL shortener to Google Cloud Platform with persistent external storage and high performance.

## 🏗️ Architecture

- **Application**: Cloud Run (auto-scaling, zero downtime updates)
- **Database**: Cloud SQL PostgreSQL (persistent, managed backups)
- **Cache**: Cloud Memorystore Redis (high performance)
- **Email**: Mailgun (transactional email service)
- **Build**: Cloud Build (automated CI/CD)

## 📁 Files Structure

```
fwx/
├── INITIAL-DEPLOYMENT.md         # Step-by-step first deployment
├── UPDATE-DEPLOYMENT.md          # How to deploy updates safely
├── TROUBLESHOOTING.md            # Common issues and solutions  
├── ENVIRONMENT-CONFIG.md         # Environment configuration guide
├── MAILGUN-SETUP.md              # Email service configuration
├── docker/Dockerfile.production  # Optimized production container
├── gcp/cloudbuild.yaml          # Cloud Build configuration
├── config/*.template            # Environment variable templates
└── scripts/                     # Deployment automation scripts
```

## 🚀 Quick Commands

### First Time Setup
```bash
./fwx/scripts/check-prerequisites.sh   # Check requirements first
./fwx/scripts/setup-infrastructure.sh  # Create all cloud resources
./fwx/scripts/deploy.sh                # Deploy the application
```

### Deploy Updates (Data Preserved)
```bash
./fwx/scripts/deploy.sh                # Update app, keep all data
```

## 📚 Detailed Guides

| What You Need | Guide |
|---------------|-------|
| **First deployment** | [`INITIAL-DEPLOYMENT.md`](INITIAL-DEPLOYMENT.md) |
| **Deploy updates** | [`UPDATE-DEPLOYMENT.md`](UPDATE-DEPLOYMENT.md) |
| **Fix problems** | [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) |
| **Configure environment** | [`ENVIRONMENT-CONFIG.md`](ENVIRONMENT-CONFIG.md) |

## 🎯 Your Configuration

- **App URL**: `https://fwl.ink` (your custom domain)
- **App emails**: `@fwl.ink` domain (password resets, notifications)
- **Support emails**: `@fyneworks.com` domain (contact, support)
- **Region**: `europe-west4` (Netherlands)
- **Database**: PostgreSQL with daily backups
- **Cache**: Redis for high performance

## 💰 Estimated Costs

- **Low traffic**: ~$37-42/month  
- **Medium traffic**: ~$85-95/month
- Auto-scales based on usage (Cloud Run scales to zero)

## 🔧 Key Features

✅ **Zero downtime** deployments  
✅ **Data persistence** across updates  
✅ **Automatic SSL** certificates  
✅ **Daily backups** with point-in-time recovery  
✅ **Auto-scaling** from 0 to high traffic  
✅ **Email integration** with Mailgun  
✅ **Monitoring** and logging built-in  

## 🆘 Quick Help

**Something not working?** Check [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) first.

**Need to update?** See [`UPDATE-DEPLOYMENT.md`](UPDATE-DEPLOYMENT.md).

**First time?** Start with [`INITIAL-DEPLOYMENT.md`](INITIAL-DEPLOYMENT.md).

---

**Project**: fynewo | **App**: fwlink | **Region**: europe-west4