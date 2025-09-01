# On-Premises Deployment Guide
# AI Receptionist Platform

## Overview

This guide provides detailed instructions for deploying the AI Receptionist platform on your own infrastructure, giving you complete control over data, security, and customization.

## Table of Contents
1. [Hardware Requirements](#hardware-requirements)
2. [Software Prerequisites](#software-prerequisites)
3. [Installation Methods](#installation-methods)
4. [Production Setup](#production-setup)
5. [Security Hardening](#security-hardening)
6. [Monitoring & Maintenance](#monitoring--maintenance)
7. [Troubleshooting](#troubleshooting)

## Hardware Requirements

### Minimum Requirements (1-10 concurrent calls)
```
CPU: 8 cores (Intel i7 or AMD Ryzen 7)
RAM: 32GB DDR4
Storage: 500GB NVMe SSD
Network: 1 Gbps ethernet
GPU: Optional (improves AI performance)
```

### Recommended Production (10-50 concurrent calls)
```
CPU: 16-32 cores (Intel Xeon or AMD EPYC)
RAM: 64-128GB DDR4 ECC
Storage: 1-2TB NVMe SSD (RAID 1 recommended)
Network: 10 Gbps ethernet (redundant connections)
GPU: NVIDIA RTX 4090 or Tesla T4 (for AI acceleration)
```

### Enterprise Setup (50+ concurrent calls)
```
CPU: 32+ cores per node (multi-node cluster)
RAM: 128GB+ per node
Storage: 2TB+ NVMe SSD with enterprise backup
Network: 10+ Gbps with redundancy
GPU: Multiple NVIDIA A100 or H100 cards
Load Balancer: Hardware or software-based
```

## Software Prerequisites

### Operating System
- **Ubuntu 22.04 LTS** (recommended)
- **CentOS Stream 9** (alternative)
- **RHEL 9** (enterprise)

### Container Runtime
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### Optional: Kubernetes (for scaling)
```bash
# Install K3s (lightweight Kubernetes)
curl -sfL https://get.k3s.io | sh -
```

## Installation Methods

### Method 1: Docker Compose (Recommended for most users)

1. **Clone the repository:**
```bash
git clone https://github.com/danipopa/ai-receptionist.git
cd ai-receptionist
```

2. **Configure environment:**
```bash
cp .env.example .env
# Edit .env with your settings
nano .env
```

3. **Deploy the stack:**
```bash
docker-compose -f deployment/docker-compose.yml up -d
```

### Method 2: Kubernetes Deployment

1. **Prepare the cluster:**
```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

2. **Deploy with Helm:**
```bash
cd deployment/kubernetes
helm install ai-receptionist ./ai-receptionist-chart
```

### Method 3: Manual Installation

For development or custom setups, see the detailed manual installation guide in `docs/installation/MANUAL_SETUP.md`.

## Production Setup

### 1. SSL/TLS Configuration

#### Using Let's Encrypt (Free)
```bash
# Install Certbot
sudo apt update
sudo apt install certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d your-domain.com -d api.your-domain.com
```

#### Using Custom Certificates
```bash
# Place your certificates
sudo mkdir -p /etc/ssl/ai-receptionist/
sudo cp your-certificate.crt /etc/ssl/ai-receptionist/
sudo cp your-private-key.key /etc/ssl/ai-receptionist/
sudo chmod 600 /etc/ssl/ai-receptionist/*
```

### 2. Database Optimization

#### PostgreSQL Tuning
```sql
-- Edit /etc/postgresql/14/main/postgresql.conf
shared_buffers = '8GB'
effective_cache_size = '24GB'
maintenance_work_mem = '2GB'
checkpoint_completion_target = 0.9
wal_buffers = '16MB'
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = '32MB'
min_wal_size = '1GB'
max_wal_size = '4GB'
```

#### Redis Configuration
```redis
# Edit /etc/redis/redis.conf
maxmemory 8gb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
```

### 3. Asterisk Configuration

#### SIP Trunk Setup
```ini
; /etc/asterisk/pjsip.conf
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060

[ai-receptionist-trunk]
type=endpoint
transport=transport-udp
context=ai-receptionist
disallow=all
allow=ulaw,alaw,g722
direct_media=no
```

#### Dialplan
```ini
; /etc/asterisk/extensions.conf
[ai-receptionist]
exten => _X.,1,NoOp(AI Receptionist Call)
 same => n,Set(CHANNEL(hangup_handler_push)=hangup-handler,s,1)
 same => n,Stasis(ai-receptionist-app)
 same => n,Hangup()

[hangup-handler]
exten => s,1,NoOp(Call ended)
 same => n,Return()
```

### 4. Load Balancing

#### NGINX Configuration
```nginx
upstream ai_receptionist_backend {
    server 127.0.0.1:8000;
    server 127.0.0.1:8001;
    server 127.0.0.1:8002;
}

server {
    listen 80;
    listen [::]:80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /etc/ssl/ai-receptionist/certificate.crt;
    ssl_certificate_key /etc/ssl/ai-receptionist/private.key;
    
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /api/ {
        proxy_pass http://ai_receptionist_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location /ws/ {
        proxy_pass http://ai_receptionist_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```

## Security Hardening

### 1. Firewall Configuration
```bash
# UFW (Ubuntu)
sudo ufw enable
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 5060/udp  # SIP
sudo ufw deny 8000:8010/tcp  # Block direct backend access
```

### 2. User Management
```bash
# Create dedicated user
sudo useradd -r -s /bin/false ai-receptionist
sudo usermod -aG docker ai-receptionist

# Set ownership
sudo chown -R ai-receptionist:ai-receptionist /opt/ai-receptionist/
```

### 3. Database Security
```sql
-- Create database user with limited privileges
CREATE USER 'ai_receptionist'@'localhost' IDENTIFIED BY 'secure_password';
GRANT SELECT, INSERT, UPDATE, DELETE ON ai_receptionist.* TO 'ai_receptionist'@'localhost';
FLUSH PRIVILEGES;
```

### 4. Container Security
```yaml
# docker-compose.override.yml
version: '3.8'
services:
  backend:
    security_opt:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
```

## Monitoring & Maintenance

### 1. Prometheus Configuration
```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'ai-receptionist'
    static_configs:
      - targets: ['localhost:8000']
    metrics_path: '/metrics'
```

### 2. Grafana Dashboards
Import the provided dashboard from `monitoring/grafana/ai-receptionist-dashboard.json`.

### 3. Log Management
```bash
# Configure log rotation
sudo tee /etc/logrotate.d/ai-receptionist << EOF
/var/log/ai-receptionist/*.log {
    daily
    missingok
    rotate 52
    compress
    notifempty
    create 644 ai-receptionist ai-receptionist
    postrotate
        docker-compose restart >> /dev/null 2>&1 || true
    endscript
}
EOF
```

### 4. Backup Strategy
```bash
#!/bin/bash
# backup.sh
BACKUP_DIR="/backup/ai-receptionist"
DATE=$(date +%Y%m%d_%H%M%S)

# Database backup
pg_dump ai_receptionist > "$BACKUP_DIR/db_$DATE.sql"

# Configuration backup
tar czf "$BACKUP_DIR/config_$DATE.tar.gz" /opt/ai-receptionist/

# Cleanup old backups (keep 30 days)
find $BACKUP_DIR -name "*.sql" -mtime +30 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete
```

## Performance Optimization

### 1. CPU Optimization
```bash
# Set CPU governor to performance
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

### 2. Memory Settings
```bash
# Optimize kernel parameters
sudo tee -a /etc/sysctl.conf << EOF
vm.swappiness = 10
vm.dirty_ratio = 80
vm.dirty_background_ratio = 5
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
EOF
sudo sysctl -p
```

### 3. Storage Optimization
```bash
# Mount options for SSD
# Add to /etc/fstab:
# /dev/nvme0n1p1 / ext4 defaults,noatime,discard 0 1
```

## High Availability Setup

### 1. Database Replication
```sql
-- On primary server
CREATE USER 'replicator'@'%' IDENTIFIED BY 'secure_password';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';

-- On secondary server
CHANGE MASTER TO
  MASTER_HOST='primary-server-ip',
  MASTER_USER='replicator',
  MASTER_PASSWORD='secure_password',
  MASTER_LOG_FILE='mysql-bin.000001',
  MASTER_LOG_POS=0;
START SLAVE;
```

### 2. Application Clustering
```yaml
# docker-compose.cluster.yml
version: '3.8'
services:
  backend-1:
    extends:
      file: docker-compose.yml
      service: backend
    ports:
      - "8001:8000"
  
  backend-2:
    extends:
      file: docker-compose.yml
      service: backend
    ports:
      - "8002:8000"
  
  backend-3:
    extends:
      file: docker-compose.yml
      service: backend
    ports:
      - "8003:8000"
```

## Troubleshooting

### Common Issues

#### 1. High Memory Usage
```bash
# Check memory usage
docker stats
free -h

# Restart services if needed
docker-compose restart
```

#### 2. Database Connection Issues
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Check connections
sudo -u postgres psql -c "SELECT * FROM pg_stat_activity;"
```

#### 3. Audio Quality Issues
```bash
# Check Asterisk logs
sudo asterisk -x "core show channels"
tail -f /var/log/asterisk/messages
```

#### 4. AI Model Loading Errors
```bash
# Check GPU usage (if applicable)
nvidia-smi

# Check model files
ls -la /opt/ai-receptionist/models/
```

### Performance Monitoring

#### System Metrics
```bash
# Monitor system resources
htop
iotop
netstat -tulpn
```

#### Application Metrics
```bash
# API response times
curl -w "@curl-format.txt" -s -o /dev/null http://localhost:8000/health

# Database performance
sudo -u postgres psql -c "SELECT * FROM pg_stat_statements;"
```

## Maintenance Schedule

### Daily
- [ ] Check system logs
- [ ] Monitor resource usage
- [ ] Verify backup completion

### Weekly
- [ ] Update system packages
- [ ] Review security logs
- [ ] Test disaster recovery

### Monthly
- [ ] Update container images
- [ ] Performance optimization review
- [ ] Security audit

### Quarterly
- [ ] Hardware health check
- [ ] Capacity planning review
- [ ] Security penetration testing

## Cost Estimation

### Hardware Costs (One-time)
| Component | Minimum | Recommended | Enterprise |
|-----------|---------|-------------|------------|
| Server | $3,000 | $8,000 | $25,000+ |
| Network | $500 | $2,000 | $10,000+ |
| Backup | $500 | $2,000 | $5,000+ |
| **Total** | **$4,000** | **$12,000** | **$40,000+** |

### Operational Costs (Monthly)
| Item | Cost |
|------|------|
| Power ($0.10/kWh) | $50-200 |
| Internet | $100-500 |
| Support | $0-2,000 |
| **Total** | **$150-2,700** |

## Support & Resources

### Documentation
- [API Reference](../api/README.md)
- [Configuration Guide](../configuration/README.md)
- [Development Setup](../development/README.md)

### Community
- GitHub Issues: https://github.com/danipopa/ai-receptionist/issues
- Discord Server: [Join Community]
- Stack Overflow: Tag `ai-receptionist`

### Professional Support
For enterprise support, contact: support@ai-receptionist.com

---

**Note:** This guide covers the basic on-premises deployment. For specific enterprise requirements, custom integrations, or advanced configurations, please consult our professional services team.
