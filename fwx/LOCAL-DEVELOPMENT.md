# fwlink Local Development Guide

Set up fwlink for local development on your machine.

## 🚀 Quick Setup

### **Prerequisites**
- Node.js 18+ installed
- Google Cloud CLI (for connecting to cloud resources)

### **Basic Setup**
```bash
# 1. Install dependencies
npm install

# 2. Set up environment variables
cp fwx/config/.env.development.template .env

# 3. Edit .env with your preferred setup
nano .env

# 4. Run database migrations (if using database)
npm run migrate

# 5. Start development server
npm run dev
```

## 📋 Configuration Options

You have two main approaches for local development:

### **Option 1: Cloud Resources (Recommended for Testing)**

Connect to your actual Cloud SQL and Redis instances to test with real data.

#### Setup:
```bash
# 1. Install Cloud SQL Proxy
curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.8.0/cloud-sql-proxy.linux.amd64
chmod +x cloud-sql-proxy

# 2. Start Cloud SQL Proxy in another terminal
./cloud-sql-proxy fynewo:europe-west4:fwlink-db-prod

# 3. Get database password
gcloud secrets versions access latest --secret=fwlink-db-password

# 4. Configure .env
DB_CLIENT=pg
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=fwlink
DB_USER=fwlink-user
DB_PASSWORD=your-cloud-sql-password

# Optional: Connect to Cloud Redis (requires VPN or complex networking)
REDIS_ENABLED=false  # Recommended to disable for local dev
```

### **Option 2: Local Resources (Easier for Development)**

Use local SQLite and optional local Redis for isolated development.

#### Setup:
```bash
# 1. Configure .env for local SQLite
DB_CLIENT=better-sqlite3
DB_FILENAME=dev-data

# 2. Optional: Run local Redis
docker run -d -p 6379:6379 --name fwlink-redis redis:alpine

# 3. Configure Redis (if using)
REDIS_ENABLED=true
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
```

## 📝 Environment Configuration

### **Complete .env Example**
```bash
# Application
PORT=3000
NODE_ENV=development
SITE_NAME=fwLink Local
DEFAULT_DOMAIN=localhost:3000
JWT_SECRET=local-development-jwt-secret-change-me

# Database - Choose one option:

# Option 1: Cloud SQL (via proxy)
DB_CLIENT=pg
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=fwlink
DB_USER=fwlink-user
DB_PASSWORD=your-cloud-sql-password

# Option 2: Local SQLite
# DB_CLIENT=better-sqlite3
# DB_FILENAME=dev-data

# Redis - Local only
REDIS_ENABLED=false
# REDIS_HOST=127.0.0.1
# REDIS_PORT=6379

# Development settings
TRUST_PROXY=false
DISALLOW_REGISTRATION=false
DISALLOW_ANONYMOUS_LINKS=false
ENABLE_RATE_LIMIT=false
LINK_LENGTH=6

# Email - Disabled for local development
MAIL_ENABLED=false
```

## 🗄️ Database Management

### **Running Migrations**
```bash
# Run all pending migrations
npm run migrate

# Create new migration
npm run migrate:make -- migration_name
```

### **Database Access**

**SQLite (Local):**
```bash
# Access local SQLite database
sqlite3 dev-data

# View tables
.tables

# Query data
SELECT * FROM links LIMIT 5;
```

**PostgreSQL (Cloud):**
```bash
# Connect via Cloud SQL proxy (must be running)
psql -h 127.0.0.1 -p 5432 -U fwlink-user -d fwlink

# Or connect directly via gcloud
gcloud sql connect fwlink-db-prod --user=fwlink-user --database=fwlink
```

## 🔧 Development Commands

### **Available Scripts**
```bash
# Start development server with hot reload
npm run dev

# Run database migrations  
npm run migrate

# Create new migration file
npm run migrate:make -- migration_name

# Start production mode locally
npm start

# Run with specific environment
NODE_ENV=development npm run dev
```

### **Debug Mode**
```bash
# Run with debug output
DEBUG=* npm run dev

# Debug specific modules
DEBUG=kutt:* npm run dev
```

## 🌐 Testing Your Setup

### **Verify Application is Running**
```bash
# Check app is responding
curl http://localhost:3000

# Check health endpoint (if available)
curl http://localhost:3000/api/health
```

### **Test Database Connection**
```bash
# Check database tables exist
npm run migrate

# Should see migration output confirming database connection
```

### **Test API Endpoints**
```bash
# Register a new user (if registration enabled)
curl -X POST http://localhost:3000/api/v2/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"testpassword"}'

# Create a short link (may require authentication)
curl -X POST http://localhost:3000/api/v2/links \
  -H "Content-Type: application/json" \
  -d '{"target":"https://example.com"}'
```

## 🔍 Troubleshooting

### **Common Issues**

**"Cannot find module" errors:**
```bash
# Delete node_modules and reinstall
rm -rf node_modules package-lock.json
npm install
```

**Database connection errors:**
```bash
# For Cloud SQL: ensure proxy is running
./cloud-sql-proxy fynewo:europe-west4:fwlink-db-prod

# For SQLite: ensure directory exists
mkdir -p $(dirname dev-data)

# Check environment variables
echo $DB_CLIENT
echo $DB_HOST
```

**Port already in use:**
```bash
# Kill process on port 3000
lsof -ti:3000 | xargs kill -9

# Or use different port
PORT=3001 npm run dev
```

**JWT Secret errors:**
```bash
# Ensure JWT_SECRET is set in .env
grep JWT_SECRET .env

# Should not be empty
JWT_SECRET=at-least-32-characters-long-secret
```

### **Environment Variable Issues**
```bash
# Verify .env file is loaded
node -e "require('dotenv').config(); console.log(process.env.SITE_NAME)"

# Check if .env is in project root (not fwx/config/)
ls -la .env
```

## 📊 Development Workflow

### **Recommended Development Flow**

1. **Start with local SQLite** for isolated development
2. **Use Cloud SQL** when testing with production-like data
3. **Disable Redis** unless testing cache-dependent features
4. **Enable registration** for easy user creation during development
5. **Disable rate limiting** to avoid throttling during testing

### **Branch Strategy**
```bash
# Create feature branch
git checkout -b feature/new-feature

# Make changes and test locally
npm run dev

# Test with cloud resources before deployment
# (switch .env to use Cloud SQL)

# Deploy to test environment
./fwx/scripts/deploy.sh

# Merge when tested
git checkout main
git merge feature/new-feature
```

## 🔐 Security in Development

### **Don't Use Production Secrets**
- Use different JWT_SECRET for development
- Don't commit real API keys to git
- Use test email addresses

### **Safe Development Practices**
```bash
# Use development-specific values
JWT_SECRET=development-secret-not-for-production
MAIL_ENABLED=false
DISALLOW_REGISTRATION=false

# Never commit .env files
echo ".env" >> .gitignore
```

## 🚀 Moving to Production

When your local changes are ready:

```bash
# 1. Commit changes
git add .
git commit -m "Add new feature"

# 2. Push to repository  
git push origin main

# 3. Deploy to production (no .env needed)
./fwx/scripts/deploy.sh
```

**Remember**: Production doesn't use .env files - it uses Google Cloud Secret Manager and environment variables set directly on Cloud Run.

---

**Happy coding!** 🎉

For production configuration, see [`SECRETS-MANAGEMENT.md`](SECRETS-MANAGEMENT.md).