# Custom Domains Infrastructure Setup

## Overview
This document describes the infrastructure setup that allows users to point any custom domain to the fwlink service without requiring additional Google Cloud configuration.

📋 **See Also**: [Architecture Overview](ARCHITECTURE.md) - Complete system architecture with diagrams

## Architecture
- **Google Cloud Run**: Hosts the fwlink application
- **Global External Application Load Balancer**: Routes traffic from any domain to Cloud Run
- **Static IP Address**: Provides a stable endpoint for user DNS configuration

## Infrastructure Components

### 1. Static IP Address
- **Name**: `fwlink-static-ip`
- **IP**: `34.128.151.185`
- **Type**: Global External IPv4
- **Purpose**: Provides stable endpoint for user DNS configuration

### 2. Network Endpoint Group (NEG)
- **Name**: `fwlink-neg`
- **Type**: Serverless
- **Region**: `europe-west4`
- **Target**: `fwlink-prod` Cloud Run service

### 3. Backend Service
- **Name**: `fwlink-backend`
- **Type**: Global External
- **Backend**: `fwlink-neg`
- **Protocol**: HTTP

### 4. Load Balancer Components
- **URL Map**: `fwlink-urlmap` - Routes all traffic to `fwlink-backend`
- **HTTP Target Proxy**: `fwlink-http-proxy` - Handles HTTP traffic
- **Forwarding Rule**: `fwlink-http-rule` - Routes port 80 to HTTP proxy

### 5. Cloud Run Configuration
- **Service**: `fwlink-prod`
- **Ingress**: `internal-and-cloud-load-balancing` (blocks direct access)
- **Region**: `europe-west4`

## User Instructions

Users can now point their custom domains to the fwlink service using either:

### Option A: A Record (Recommended)
```
Type: A
Name: go (or any subdomain)
Value: 34.128.151.185
TTL: 300 (or your preference)
```

### Option B: CNAME Record (Alternative)
```
Type: CNAME  
Name: go (or any subdomain)
Value: custom.fwl.ink
TTL: 300 (or your preference)
```

## Application Configuration

The application displays these DNS configuration options to users through environment variables:

- `SERVER_IP_ADDRESS=34.128.151.185`
- `SERVER_CNAME_ADDRESS=custom.fwl.ink`

These are configured in:
1. Cloud Run deployment (current running service)
2. `fwx/gcp/cloudbuild.yaml` (for future deployments)

## How It Works

1. User configures DNS: `go.example.com` → `34.128.151.185`
2. Request hits Google's Global Load Balancer at static IP
3. Load Balancer forwards request to Cloud Run service with original `Host` header
4. fwlink application receives request with `Host: go.example.com`
5. Application looks up `go.example.com` in domains table
6. If domain exists and link found, redirects to target URL

## Benefits

✅ **Zero Google Cloud Setup**: No need to add domains to Google Cloud
✅ **Any Domain Works**: Users can use any domain/subdomain they own  
✅ **Automatic SSL**: Load balancer can be extended with SSL certificates
✅ **High Performance**: Global load balancer with CDN capabilities
✅ **Security**: Direct Cloud Run access blocked, only load balancer can reach it
✅ **Scalable**: Handles unlimited custom domains

## Deployment Commands Summary

```bash
# 1. Reserve static IP
gcloud compute addresses create fwlink-static-ip --global

# 2. Update Cloud Run ingress
gcloud run services update fwlink-prod \
  --ingress internal-and-cloud-load-balancing \
  --region europe-west4

# 3. Create Network Endpoint Group
gcloud compute network-endpoint-groups create fwlink-neg \
  --region=europe-west4 \
  --network-endpoint-type=serverless \
  --cloud-run-service=fwlink-prod

# 4. Create Backend Service
gcloud compute backend-services create fwlink-backend \
  --load-balancing-scheme=EXTERNAL \
  --global

gcloud compute backend-services add-backend fwlink-backend \
  --global \
  --network-endpoint-group=fwlink-neg \
  --network-endpoint-group-region=europe-west4

# 5. Create URL Map and Proxies
gcloud compute url-maps create fwlink-urlmap \
  --default-service=fwlink-backend

gcloud compute target-http-proxies create fwlink-http-proxy \
  --url-map=fwlink-urlmap

# 6. Create SSL Certificates for HTTPS
gcloud compute ssl-certificates create fwlink-ssl-cert \
  --domains=custom.fwl.ink \
  --global

gcloud compute ssl-certificates create fwl-ink-ssl-cert \
  --domains=fwl.ink \
  --global

gcloud compute target-https-proxies create fwlink-https-proxy \
  --url-map=fwlink-urlmap \
  --ssl-certificates=fwlink-ssl-cert,fwl-ink-ssl-cert

# 7. Create Forwarding Rules (HTTP + HTTPS)
gcloud compute forwarding-rules create fwlink-http-rule \
  --address=fwlink-static-ip \
  --target-http-proxy=fwlink-http-proxy \
  --global \
  --ports=80

gcloud compute forwarding-rules create fwlink-https-rule \
  --address=fwlink-static-ip \
  --target-https-proxy=fwlink-https-proxy \
  --global \
  --ports=443

# 8. Update Cloud Run with DNS info
gcloud run services update fwlink-prod \
  --region=europe-west4 \
  --update-env-vars="SERVER_IP_ADDRESS=34.128.151.185,SERVER_CNAME_ADDRESS=custom.fwl.ink"

# 9. Remove old Cloud Run domain mapping (if exists)
gcloud beta run domain-mappings delete --domain=fwl.ink --region=europe-west4 --quiet
```

## 🚨 Critical DNS Update Required

**You must update your DNS for fwl.ink:**

**Old (Cloud Run domain mapping):**
```
fwl.ink A → 216.239.32.21, 216.239.34.21, 216.239.36.21, 216.239.38.21
```

**New (Load Balancer):**
```
fwl.ink A → 34.128.151.185
```

This change routes fwl.ink through the same load balancer as custom domains for unified infrastructure.

## Testing

Test the load balancer:
```bash
# Test HTTP
curl -H "Host: fwl.ink" http://34.128.151.185

# Test HTTPS (after certificate provisions)
curl -H "Host: fwl.ink" https://34.128.151.185

# Test custom domain (after DNS setup)
curl http://custom.fwl.ink
curl https://custom.fwl.ink

# Test main domain (after DNS update)
curl http://fwl.ink
curl https://fwl.ink
```

## SSL Certificate Status

Check certificate provisioning:
```bash
gcloud compute ssl-certificates describe fwlink-ssl-cert --global --format="value(managed.status)"
```

## Current Features

✅ **HTTPS Support**: SSL certificate with automatic renewal  
✅ **HTTP + HTTPS**: Both port 80 and 443 supported  
✅ **Custom Domains**: A records and CNAME records supported  
✅ **Auto SSL**: Google-managed certificates for custom.fwl.ink  

## Future Enhancements

- **CDN**: Enable Cloud CDN for faster response times
- **Security**: Add Cloud Armor for DDoS protection  
- **Monitoring**: Add uptime monitoring and alerting
- **Multi-domain SSL**: Support SSL for any custom domain

## Costs

### Load Balancer Infrastructure
- **Global External Load Balancer**: $18.00/month base fee
- **Static IP Address**: $0 (free when used by load balancer)
- **SSL Certificates (2x)**: $0 (Google-managed certificates)
- **Data Processing**: $0.008/GB (first 1TB/month included)
- **All other components**: $0 (NEG, proxies, rules included)

### Total Infrastructure Cost Impact
| Monthly Traffic | Load Balancer Cost | Total Added Cost |
|----------------|-------------------|------------------|
| < 1 TB | $18.00 | **+$18/month** |
| 1-5 TB | $18 + ~$33 | **+$51/month** |
| 5-15 TB | $18 + ~$65 | **+$83/month** |
| 15+ TB | Volume discounts apply | **+$100+/month** |

**Note**: This is additional cost on top of existing Cloud Run, Cloud SQL, and Redis expenses (~$60-110/month).