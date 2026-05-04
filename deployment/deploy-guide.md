# Deployment Guide - TailorShop MVP

## Prerequisites
- A VPS with 1GB+ RAM (Hetzner CX11 ~€4/mo, Contabo VPS S ~€5/mo)
- Ubuntu 22.04 or Debian 12
- Domain name (optional but recommended for HTTPS)

## Step 1: Server Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install docker-compose-plugin -y

# Firewall
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

## Step 2: Deploy Application

```bash
# Clone or upload project
cd /opt
git clone <your-repo-url> tailorshop
cd tailorshop/deployment

# Configure environment
cp .env.example .env
nano .env  # Edit all values, especially passwords and JWT secret

# Build and start
docker compose up -d --build

# Check status
docker compose ps
docker compose logs -f backend-api
```

## Step 3: HTTPS with Certbot (if you have a domain)

```bash
# First, make sure DNS A record points to your server IP
# Then get certificate:
docker compose run --rm certbot certonly \
  --webroot --webroot-path=/var/www/certbot \
  -d yourdomain.com

# Uncomment HTTPS server block in nginx.conf
# Replace yourdomain.com with your actual domain
nano nginx.conf

# Reload nginx
docker compose restart nginx
```

## Step 4: Backups

### Database Backup (daily cron)
```bash
# Create backup script
cat > /opt/tailorshop/backup.sh << 'SCRIPT'
#!/bin/bash
BACKUP_DIR="/opt/tailorshop/backups"
mkdir -p $BACKUP_DIR
DATE=$(date +%Y%m%d_%H%M%S)

# Database
docker compose -f /opt/tailorshop/deployment/docker-compose.yml exec -T postgres \
  pg_dump -U postgres tailorshop | gzip > $BACKUP_DIR/db_$DATE.sql.gz

# Uploads
tar -czf $BACKUP_DIR/uploads_$DATE.tar.gz \
  $(docker volume inspect deployment_uploads_data -f '{{.Mountpoint}}')

# Keep only last 7 days
find $BACKUP_DIR -mtime +7 -delete
SCRIPT

chmod +x /opt/tailorshop/backup.sh

# Add to cron (daily at 2 AM)
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/tailorshop/backup.sh") | crontab -
```

### Restore from Backup
```bash
# Database
gunzip < backups/db_YYYYMMDD_HHMMSS.sql.gz | \
  docker compose exec -T postgres psql -U postgres tailorshop

# Uploads
docker compose down
tar -xzf backups/uploads_YYYYMMDD_HHMMSS.tar.gz -C /
docker compose up -d
```

## Step 5: Monitoring

```bash
# View logs
docker compose logs -f backend-api
docker compose logs -f postgres

# Check disk space
df -h

# Check memory
free -h
```

## Step 6: Updates

```bash
cd /opt/tailorshop
git pull
cd deployment
docker compose up -d --build
```

## Mobile App

### Build APK
```bash
cd mobile
flutter build apk --release
# APK will be at build/app/outputs/flutter-apk/app-release.apk
```

Share the APK via WhatsApp or email to the tailor's phone.

## Cost Summary

| Service | Monthly Cost |
|---------|-------------|
| Hetzner CX11 VPS (1 vCPU, 2GB RAM) | ~€4 (~$4.50) |
| Domain (optional) | ~$1/mo |
| Email (Brevo free tier) | Free |
| Storage (local disk) | Free (included) |
| **Total** | **~$5-6/month** |

## Upgrade Path

When the business grows:
1. **Storage**: Switch to Cloudflare R2 (free 10GB tier, then $0.015/GB)
2. **VPS**: Upgrade to CX21 (2 vCPU, 4GB RAM) for ~€6/mo
3. **Database**: Move to managed PostgreSQL if needed
4. **OCR**: Integrate Tesseract properly or use cloud OCR
