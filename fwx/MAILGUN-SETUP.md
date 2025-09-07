# Mailgun Email Service Setup for fwlink

Configure Mailgun for professional email delivery with your existing account and fwl.ink domain.

## 🎯 Why Mailgun?

- **Existing Account**: Use your current Mailgun subscription
- **Custom Domain**: Send emails from @fwl.ink for brand consistency  
- **High Deliverability**: Industry-leading email delivery rates
- **Easy Integration**: Works seamlessly with your fwlink deployment
- **Reliable Service**: Enterprise-grade email infrastructure

## 📧 Email Features in fwlink

Once configured, Mailgun enables these features:
- **Password reset emails** from noreply@fwl.ink
- **Email verification** for new accounts
- **Account notifications** and updates
- **Usage reports** (if enabled)
- **Link creation notifications**

## 🚀 Setup Process

### Step 1: Configure Domain in Mailgun

1. **Log into Mailgun Dashboard:**
   ```
   https://app.mailgun.com/
   ```

2. **Add fwl.ink Domain:**
   - Go to **Sending** > **Domains**
   - Click **Add New Domain**
   - Enter: `fwl.ink`
   - Choose your region (US or EU)

3. **Configure DNS Records:**
   Mailgun will show DNS records to add to your fwl.ink domain:
   ```
   TXT  @           v=spf1 include:mailgun.org ~all
   TXT  k1._domainkey   [DKIM key from Mailgun]
   CNAME email.fwl.ink   mailgun.org
   ```

4. **Verify Domain:**
   - Add all DNS records to your domain provider
   - Wait for DNS propagation (5-60 minutes)
   - Click **Verify DNS Settings** in Mailgun

### Step 2: Get API Credentials

1. **Get Private API Key:**
   - Go to **Settings** > **API Keys**
   - Copy your **Private API key** (starts with `key-`)
   - Keep this secure - you'll need it during infrastructure setup

2. **Note Your Region:**
   - **US**: Uses `smtp.mailgun.org`
   - **EU**: Uses `smtp.eu.mailgun.org`

### Step 3: Configure During Infrastructure Setup

The setup script will prompt you for Mailgun configuration:

```bash
./fwx/scripts/setup-infrastructure.sh
# When prompted:
# 1. Enter your Mailgun Private API key
# 2. Select your region (US or EU)
```

## 📋 Configuration Details

Your deployment will use these Mailgun settings:

### For US Region:
```bash
MAIL_ENABLED=true
MAIL_HOST=smtp.mailgun.org
MAIL_PORT=587
MAIL_SECURE=true
MAIL_USER=api
MAIL_FROM="fwLink <noreply@fwl.ink>"
MAIL_PASSWORD=[Your Mailgun API Key from Secret Manager]
```

### For EU Region:
```bash
MAIL_ENABLED=true
MAIL_HOST=smtp.eu.mailgun.org
MAIL_PORT=587
MAIL_SECURE=true
MAIL_USER=api
MAIL_FROM="fwLink <noreply@fwl.ink>"
MAIL_PASSWORD=[Your Mailgun API Key from Secret Manager]
```

### Email Addresses Used:
- **App emails**: `noreply@fwl.ink` (password resets, notifications)
- **Support emails**: `support@fyneworks.com` (contact, reports)

## 🔧 Manual Configuration (If Needed)

If you skip Mailgun during initial setup, you can add it later:

### Create the Secrets
```bash
# Store your Mailgun API key
echo "your-mailgun-private-api-key" | gcloud secrets create fwlink-mailgun-api-key --data-file=-

# Store your Mailgun SMTP host
echo "smtp.mailgun.org" | gcloud secrets create fwlink-mailgun-host --data-file=-
# For EU: echo "smtp.eu.mailgun.org" | gcloud secrets create fwlink-mailgun-host --data-file=-
```

### Update Cloud Run Service
```bash
# Enable email with Mailgun settings
gcloud run services update fwlink-prod \
    --update-env-vars MAIL_ENABLED=true \
    --update-env-vars MAIL_PORT=587 \
    --update-env-vars MAIL_SECURE=true \
    --update-env-vars MAIL_USER=api \
    --update-env-vars MAIL_FROM="fwLink <noreply@fwl.ink>" \
    --update-env-vars CONTACT_EMAIL="support@fyneworks.com" \
    --update-secrets MAIL_PASSWORD=fwlink-mailgun-api-key:latest \
    --update-secrets MAIL_HOST=fwlink-mailgun-host:latest \
    --region=europe-west4
```

## 🧪 Testing Email Configuration

### Test via Application
1. **Access your fwlink admin panel**
2. **Try password reset functionality**
3. **Check Mailgun dashboard** for delivery statistics

### Test via Mailgun Console
1. **Mailgun Dashboard** > **Sending** > **Logs**
2. **Send test email** via their interface
3. **Monitor delivery rates** and bounces

### Check DNS Configuration
```bash
# Verify SPF record
dig TXT fwl.ink | grep spf1

# Verify DKIM
dig TXT k1._domainkey.fwl.ink

# Verify CNAME
dig CNAME email.fwl.ink
```

## 📊 Monitoring Email Usage

### Mailgun Dashboard
- **Logs**: Real-time email sending activity and delivery status
- **Statistics**: Delivery rates, bounces, complaints, opens, clicks
- **Events**: Detailed event tracking for troubleshooting
- **Suppressions**: Manage bounced and unsubscribed addresses

### Google Cloud Monitoring
Email-related logs appear in Cloud Run logs:
```bash
# View email-related logs
gcloud run services logs read fwlink-prod --region=europe-west4 --filter="mail OR email OR mailgun"
```

## 💰 Cost Information

Uses your existing Mailgun plan - no additional costs for the integration.

**Mailgun Pricing Tiers:**
- **Free Trial**: 5,000 emails for 3 months
- **Foundation**: $35/month for 50,000 emails
- **Scale**: $80/month for 100,000 emails
- **Pro**: Custom pricing for higher volumes

## 🔐 Security Best Practices

### API Key Security
- **Private API Key**: Keep secure, rotate regularly
- **Domain verification**: Complete DNS verification for best deliverability
- **Monitor usage**: Check for unauthorized sending in Mailgun dashboard

### Domain Authentication Benefits
- **Higher deliverability**: Emails less likely to be marked as spam
- **Brand protection**: Prevents domain spoofing
- **Better reputation**: Improved sender score with ISPs
- **DMARC compatibility**: Works with DMARC policies

## 🛠️ Troubleshooting

### Common Issues

**Domain not verified:**
```bash
# Check DNS records
dig TXT fwl.ink
dig TXT k1._domainkey.fwl.ink
dig CNAME email.fwl.ink
```

**Emails not sending:**
```bash
# Check if secrets exist
gcloud secrets versions list fwlink-mailgun-api-key
gcloud secrets versions list fwlink-mailgun-host

# Check Cloud Run environment
gcloud run services describe fwlink-prod --region=europe-west4 --format="yaml(spec.template.spec.template.spec.containers[0].env)"
```

**Emails going to spam:**
1. **Complete domain verification** in Mailgun dashboard
2. **Verify all DNS records** are properly configured
3. **Check Mailgun reputation** in dashboard
4. **Review email content** for spam triggers

**Wrong region configuration:**
```bash
# Update Mailgun host for correct region
# US:
echo "smtp.mailgun.org" | gcloud secrets versions add fwlink-mailgun-host --data-file=-

# EU:
echo "smtp.eu.mailgun.org" | gcloud secrets versions add fwlink-mailgun-host --data-file=-

# Redeploy to pick up changes
./fwx/scripts/deploy.sh
```

**API authentication failed:**
```bash
# Update the API key secret
echo "new-private-api-key" | gcloud secrets versions add fwlink-mailgun-api-key --data-file=-

# Redeploy to pick up new secret
./fwx/scripts/deploy.sh
```

## 📞 Support Resources

- **Mailgun Support**: Available through Mailgun dashboard
- **Mailgun Documentation**: https://documentation.mailgun.com/
- **Mailgun Status**: https://status.mailgun.com/
- **DNS Verification Help**: https://help.mailgun.com/hc/en-us/articles/203637190

## 🔍 Verification Checklist

Before completing setup, verify:

- [ ] fwl.ink domain added to Mailgun account
- [ ] All DNS records configured and verified
- [ ] Domain shows as "Active" in Mailgun dashboard
- [ ] Private API key copied and stored securely
- [ ] Correct region selected (US/EU)
- [ ] Test email sent successfully
- [ ] Email appears in Mailgun logs
- [ ] No bounces or delivery failures

---

**With Mailgun configured, your fwlink deployment will send professional emails from @fwl.ink with high deliverability and comprehensive tracking.**