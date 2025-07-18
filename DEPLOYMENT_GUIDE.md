# 🚀 NovaCare Deployment Guide

## Overview
This guide covers multiple deployment options for the NovaCare healthcare application, including backend APIs and Flutter mobile app.

## 📋 Prerequisites

### System Requirements
- **Python 3.8+** for backend APIs
- **Flutter 3.0+** for mobile app
- **Docker & Docker Compose** (optional, for containerized deployment)
- **Git** for version control

### Network Requirements
- **Port 8000**: Disease Prediction API
- **Port 8001**: Hospital Referral API
- **Port 3000**: Grafana (monitoring)
- **Port 9090**: Prometheus (metrics)

## 🎯 Deployment Options

### Option 1: Quick Start (Automated)

Use the deployment script for automated setup:

```bash
# Make script executable
chmod +x deploy.sh

# Run deployment script
./deploy.sh
```

The script provides these options:
1. **Docker Deployment** (Production)
2. **Local Development** (Testing)
3. **Flutter App Build**
4. **Service Management**

### Option 2: Manual Local Deployment

#### Step 1: Backend APIs

**Disease Prediction API:**
```bash
cd Dataset
pip3 install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

**Hospital Referral API:**
```bash
cd hospital_referal
pip3 install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8001
```

#### Step 2: Flutter Mobile App

```bash
cd novacare
flutter pub get
flutter run
```

### Option 3: Docker Deployment (Recommended)

#### Prerequisites
```bash
# Install Docker
sudo apt update
sudo apt install docker.io docker-compose

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker
```

#### Deploy with Docker Compose
```bash
# Build and start all services
docker-compose up -d --build

# Check service status
docker-compose ps

# View logs
docker-compose logs -f
```

#### Services Included
- **Disease Prediction API** (Port 8000)
- **Hospital Referral API** (Port 8001)
- **Redis Cache** (Port 6379)
- **Nginx Reverse Proxy** (Port 80/443)
- **Prometheus Monitoring** (Port 9090)
- **Grafana Dashboard** (Port 3000)
- **ELK Stack Logging** (Ports 9200, 5601)

## 📱 Flutter App Deployment

### Android APK
```bash
cd novacare
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### iOS App (macOS only)
```bash
cd novacare
flutter build ios --release
```

### Web App
```bash
cd novacare
flutter build web --release
# Output: build/web/
```

## 🔧 Configuration

### API Endpoints
Update the API endpoints in the Flutter app:

**File:** `novacare/lib/services/hospital_service.dart`
```dart
static const String _baseUrl = 'http://YOUR_SERVER_IP:8001';
```

### Environment Variables
Create `.env` files for configuration:

**Dataset/.env:**
```env
LOG_LEVEL=INFO
MODEL_PATH=models/
CACHE_TTL=300
```

**hospital_referal/.env:**
```env
LOG_LEVEL=INFO
REDIS_URL=redis://localhost:6379
SECRET_KEY=your-secret-key
```

## 🌐 Production Deployment

### Cloud Deployment Options

#### 1. AWS Deployment
```bash
# Using AWS ECS with Docker
aws ecs create-cluster --cluster-name novacare-cluster
aws ecs register-task-definition --cli-input-json file://task-definition.json
```

#### 2. Google Cloud Platform
```bash
# Using Google Cloud Run
gcloud run deploy disease-api --source=./Dataset --port=8000
gcloud run deploy hospital-api --source=./hospital_referal --port=8001
```

#### 3. DigitalOcean App Platform
```yaml
# app.yaml
name: novacare
services:
- name: disease-api
  source_dir: Dataset
  github:
    repo: your-repo
    branch: main
  run_command: uvicorn main:app --host 0.0.0.0 --port 8000
```

### SSL/HTTPS Setup
```bash
# Using Let's Encrypt with Nginx
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
```

## 📊 Monitoring & Logging

### Health Checks
- Disease API: `http://localhost:8000/health`
- Hospital API: `http://localhost:8001/health`

### Monitoring Dashboards
- **Grafana**: `http://localhost:3000` (admin/admin123)
- **Prometheus**: `http://localhost:9090`
- **Kibana**: `http://localhost:5601`

### Log Files
- Disease API: `Dataset/logs/app.log`
- Hospital API: `hospital_referal/logs/hospital_api.log`

## 🔒 Security Considerations

### API Security
- Enable authentication for production
- Use HTTPS for all communications
- Implement rate limiting
- Validate all inputs

### Mobile App Security
- Use secure storage for sensitive data
- Implement certificate pinning
- Obfuscate release builds

## 🚨 Troubleshooting

### Common Issues

#### Connection Refused
```bash
# Check if services are running
curl http://localhost:8000/health
curl http://localhost:8001/health

# Check logs
tail -f Dataset/logs/app.log
tail -f hospital_referal/logs/hospital_api.log
```

#### Port Already in Use
```bash
# Find process using port
sudo lsof -i :8000
sudo lsof -i :8001

# Kill process
sudo kill -9 <PID>
```

#### Docker Issues
```bash
# Restart Docker services
docker-compose down
docker-compose up -d --build

# Clean Docker system
docker system prune -a
```

### Performance Optimization
- Enable Redis caching
- Use connection pooling
- Implement CDN for static assets
- Optimize database queries

## 📞 Support

### Service Status Commands
```bash
# Check all services
./deploy.sh  # Select option 5

# Manual checks
systemctl status docker
docker-compose ps
flutter doctor
```

### Backup & Recovery
```bash
# Backup database
docker exec -t postgres pg_dump -U user database > backup.sql

# Backup models
tar -czf models_backup.tar.gz Dataset/models/
```

## 🎉 Success Indicators

✅ **APIs Running**: Both health endpoints return 200 OK
✅ **Flutter App**: Connects to APIs successfully
✅ **Monitoring**: Grafana shows service metrics
✅ **Logs**: No error messages in log files
✅ **Mobile**: App installs and runs on device

---

**Deployment Complete!** 🚀

Your NovaCare application is now ready for use with:
- Disease prediction capabilities
- Hospital finder functionality
- Real-time monitoring
- Scalable architecture
