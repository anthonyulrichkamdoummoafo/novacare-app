#!/bin/bash

# NovaCare Deployment Script
echo "🚀 Starting NovaCare Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    print_status "Docker and Docker Compose are available"
}

# Deploy with Docker Compose
deploy_docker() {
    print_header "Docker Deployment"
    
    # Build and start services
    print_status "Building and starting services..."
    docker-compose up -d --build
    
    # Wait for services to be ready
    print_status "Waiting for services to start..."
    sleep 30
    
    # Check service health
    print_status "Checking service health..."
    
    # Check Disease API
    if curl -f http://localhost:8000/health &> /dev/null; then
        print_status "✅ Disease Prediction API is healthy"
    else
        print_warning "❌ Disease Prediction API is not responding"
    fi
    
    # Check Hospital API
    if curl -f http://localhost:8001/health &> /dev/null; then
        print_status "✅ Hospital Referral API is healthy"
    else
        print_warning "❌ Hospital Referral API is not responding"
    fi
    
    print_status "Docker deployment completed!"
    print_status "Services available at:"
    echo "  - Disease API: http://localhost:8000"
    echo "  - Hospital API: http://localhost:8001"
    echo "  - API Docs: http://localhost:8000/docs and http://localhost:8001/docs"
}

# Deploy locally (development)
deploy_local() {
    print_header "Local Development Deployment"
    
    # Install Python dependencies for Disease API
    print_status "Setting up Disease Prediction API..."
    cd Dataset
    pip3 install -r requirements.txt
    
    # Start Disease API in background
    print_status "Starting Disease Prediction API..."
    nohup uvicorn main:app --host 0.0.0.0 --port 8000 > ../logs/disease_api.log 2>&1 &
    DISEASE_PID=$!
    echo $DISEASE_PID > ../pids/disease_api.pid
    
    cd ..
    
    # Install Python dependencies for Hospital API
    print_status "Setting up Hospital Referral API..."
    cd hospital_referal
    pip3 install -r requirements.txt
    
    # Start Hospital API in background
    print_status "Starting Hospital Referral API..."
    nohup uvicorn main:app --host 0.0.0.0 --port 8001 > ../logs/hospital_api.log 2>&1 &
    HOSPITAL_PID=$!
    echo $HOSPITAL_PID > ../pids/hospital_api.pid
    
    cd ..
    
    # Wait for services to start
    sleep 10
    
    # Check services
    print_status "Checking services..."
    if curl -f http://localhost:8000/health &> /dev/null; then
        print_status "✅ Disease Prediction API is running (PID: $DISEASE_PID)"
    else
        print_error "❌ Disease Prediction API failed to start"
    fi
    
    if curl -f http://localhost:8001/health &> /dev/null; then
        print_status "✅ Hospital Referral API is running (PID: $HOSPITAL_PID)"
    else
        print_error "❌ Hospital Referral API failed to start"
    fi
    
    print_status "Local deployment completed!"
}

# Deploy Flutter app
deploy_flutter() {
    print_header "Flutter App Deployment"
    
    cd novacare
    
    # Get dependencies
    print_status "Getting Flutter dependencies..."
    flutter pub get
    
    # Build for different platforms
    read -p "Build for which platform? (android/ios/web/all): " platform
    
    case $platform in
        android)
            print_status "Building Android APK..."
            flutter build apk --release
            print_status "✅ Android APK built: build/app/outputs/flutter-apk/app-release.apk"
            ;;
        ios)
            print_status "Building iOS app..."
            flutter build ios --release
            print_status "✅ iOS app built"
            ;;
        web)
            print_status "Building web app..."
            flutter build web --release
            print_status "✅ Web app built: build/web/"
            ;;
        all)
            print_status "Building for all platforms..."
            flutter build apk --release
            flutter build web --release
            if [[ "$OSTYPE" == "darwin"* ]]; then
                flutter build ios --release
            fi
            print_status "✅ All platforms built"
            ;;
        *)
            print_error "Invalid platform selected"
            exit 1
            ;;
    esac
    
    cd ..
}

# Create necessary directories
setup_directories() {
    print_status "Creating necessary directories..."
    mkdir -p logs pids
}

# Stop services
stop_services() {
    print_header "Stopping Services"
    
    # Stop Docker services
    if [ -f docker-compose.yml ]; then
        print_status "Stopping Docker services..."
        docker-compose down
    fi
    
    # Stop local services
    if [ -f pids/disease_api.pid ]; then
        DISEASE_PID=$(cat pids/disease_api.pid)
        if kill -0 $DISEASE_PID 2>/dev/null; then
            print_status "Stopping Disease API (PID: $DISEASE_PID)..."
            kill $DISEASE_PID
        fi
        rm pids/disease_api.pid
    fi
    
    if [ -f pids/hospital_api.pid ]; then
        HOSPITAL_PID=$(cat pids/hospital_api.pid)
        if kill -0 $HOSPITAL_PID 2>/dev/null; then
            print_status "Stopping Hospital API (PID: $HOSPITAL_PID)..."
            kill $HOSPITAL_PID
        fi
        rm pids/hospital_api.pid
    fi
    
    print_status "All services stopped"
}

# Main menu
main_menu() {
    echo ""
    print_header "NovaCare Deployment Options"
    echo "1. Deploy with Docker (Recommended for Production)"
    echo "2. Deploy Locally (Development)"
    echo "3. Deploy Flutter App"
    echo "4. Stop All Services"
    echo "5. Check Service Status"
    echo "6. View Logs"
    echo "7. Exit"
    echo ""
    read -p "Select an option (1-7): " choice
    
    case $choice in
        1)
            check_docker
            setup_directories
            deploy_docker
            ;;
        2)
            setup_directories
            deploy_local
            ;;
        3)
            deploy_flutter
            ;;
        4)
            stop_services
            ;;
        5)
            check_status
            ;;
        6)
            view_logs
            ;;
        7)
            print_status "Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid option selected"
            main_menu
            ;;
    esac
}

# Check service status
check_status() {
    print_header "Service Status"
    
    # Check Disease API
    if curl -f http://localhost:8000/health &> /dev/null; then
        print_status "✅ Disease Prediction API: Running"
    else
        print_warning "❌ Disease Prediction API: Not running"
    fi
    
    # Check Hospital API
    if curl -f http://localhost:8001/health &> /dev/null; then
        print_status "✅ Hospital Referral API: Running"
    else
        print_warning "❌ Hospital Referral API: Not running"
    fi
    
    # Check Docker services
    if command -v docker &> /dev/null; then
        print_status "Docker containers:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    fi
}

# View logs
view_logs() {
    print_header "Service Logs"
    echo "1. Disease API Logs"
    echo "2. Hospital API Logs"
    echo "3. Docker Logs"
    echo "4. Back to Main Menu"
    
    read -p "Select log to view (1-4): " log_choice
    
    case $log_choice in
        1)
            if [ -f logs/disease_api.log ]; then
                tail -f logs/disease_api.log
            else
                print_warning "Disease API log file not found"
            fi
            ;;
        2)
            if [ -f logs/hospital_api.log ]; then
                tail -f logs/hospital_api.log
            else
                print_warning "Hospital API log file not found"
            fi
            ;;
        3)
            docker-compose logs -f
            ;;
        4)
            main_menu
            ;;
        *)
            print_error "Invalid option"
            view_logs
            ;;
    esac
}

# Start the deployment script
print_header "NovaCare Deployment Manager"
print_status "Welcome to the NovaCare deployment system!"

# Run main menu
main_menu
