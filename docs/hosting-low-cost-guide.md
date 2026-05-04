# Low-Cost Hosting Guide

## Recommended Setup (~$5-6/month)

### VPS Options

| Provider | Plan | Specs | Price |
|----------|------|-------|-------|
| Hetzner | CX11 | 1 vCPU, 2GB RAM, 20GB SSD | €3.79/mo |
| Hetzner | CX21 | 2 vCPU, 4GB RAM, 40GB SSD | €5.39/mo |
| Contabo | VPS S | 4 vCPU, 8GB RAM, 50GB SSD | €5.99/mo |
| DigitalOcean | Basic | 1 vCPU, 1GB RAM, 25GB SSD | $6/mo |

**Recommendation**: Start with Hetzner CX21 (best value).

### Free Services Used

| Service | Free Tier | Used For |
|---------|-----------|----------|
| Brevo SMTP | 300 emails/day | Invoice emails |
| Cloudflare (later) | 10GB R2 storage | File storage upgrade |
| Let's Encrypt | Unlimited certs | HTTPS |

## Resource Usage Estimate

| Component | RAM | CPU |
|-----------|-----|-----|
| PostgreSQL | ~100MB | Low |
| .NET API | ~150MB | Low |
| Nginx | ~10MB | Minimal |
| Web Admin (static) | ~10MB | Minimal |
| **Total** | **~270MB** | Low |

Fits comfortably in 1-2GB RAM VPS.

## Storage Planning

| Data Type | Estimated Size/Month |
|-----------|---------------------|
| Database | ~50MB |
| Photos (compressed) | ~500MB |
| PDFs | ~50MB |
| **Total** | **~600MB/month** |

20GB SSD lasts ~2 years before needing cleanup or R2 migration.

## When to Upgrade

- **More RAM**: If response times slow down (check with `free -h`)
- **More Storage**: When disk > 80% (switch photos to Cloudflare R2)
- **More CPU**: If processing backlogs form (unlikely for this workload)
- **Managed DB**: When you need high availability or automated backups

## Cost Comparison

| Approach | Monthly Cost |
|----------|-------------|
| This MVP (single VPS) | ~$5 |
| Managed DB + VPS | ~$20 |
| Full cloud (AWS/GCP) | ~$50-100 |
| Kubernetes | ~$100+ |

The single VPS approach is ideal for a small tailoring business.
