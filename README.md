# AI Log Analyzer Pro

Professional AI-powered log analysis platform with advanced security features, IP reputation checking, and comprehensive reporting capabilities.

## Features

### Core Functionality
- **Multi-format Log Support**: Apache, Nginx, Syslog, JSON, CSV, XML, Windows Event Logs
- **AI-Powered Analysis**: Uses Ollama/Llama models for intelligent log analysis
- **IP Reputation Checking**: Integration with VirusTotal and AbuseIPDB APIs
- **Real-time Processing**: Asynchronous log processing with background tasks
- **Server Connection**: Direct SSH connection to servers for remote log analysis
- **Advanced Filtering**: Filter logs by IP, user, severity, timeframe

### Security Analysis
- Anomaly detection using machine learning
- SQL injection attempt detection
- XSS attack pattern recognition
- Path traversal detection
- Brute force attack identification
- Sensitive data exposure warnings

### Export Options
- PDF reports with comprehensive analysis
- Excel spreadsheets with multiple sheets
- Word documents with formatted content
- CSV files for manual analysis

### Dashboard Features
- Real-time statistics
- Analysis history
- Severity distribution charts
- Trend analysis
- Recent analyses overview

## Tech Stack

### Backend
- **FastAPI**: High-performance Python web framework
- **PostgreSQL**: Primary database
- **Redis**: Caching and session management
- **Ollama**: Local LLM for AI analysis
- **Celery**: Background task processing
- **SQLAlchemy**: ORM for database operations

### Frontend
- **Next.js 14**: React framework with App Router
- **Tailwind CSS**: Utility-first CSS framework
- **React Query**: Data fetching and caching
- **Recharts**: Data visualization
- **Framer Motion**: Animations
- **Lucide Icons**: Icon library

### Infrastructure
- **Docker & Docker Compose**: Containerization
- **Nginx**: Reverse proxy
- **AWS CloudFormation**: Infrastructure as Code
- **GitHub Actions**: CI/CD pipeline

## Installation

### Prerequisites
- Docker and Docker Compose
- Node.js 18+ (for local development)
- Python 3.11+ (for local development)
- PostgreSQL 15+ (for local development)
- Redis 7+ (for local development)

### Quick Start with Docker

1. Clone the repository:
```bash
git clone https://github.com/yourusername/AI_Log_Analyzer.git
cd AI_Log_Analyzer
```

2. Create environment file:
```bash
cp backend/.env.example backend/.env
# Edit .env with your API keys
```

3. Start the application:
```bash
docker-compose up -d
```

4. Access the application:
- Frontend: http://localhost:3000
- Backend API: http://localhost:8000
- API Documentation: http://localhost:8000/docs

### Local Development

#### Backend Setup
```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

#### Frontend Setup
```bash
cd frontend
npm install
npm run dev
```

## Configuration

### Environment Variables

#### Backend (.env)
```env
DATABASE_URL=postgresql+asyncpg://user:password@localhost/loganalyzer
REDIS_URL=redis://localhost:6379
SECRET_KEY=your-secret-key-change-in-production
VIRUSTOTAL_API_KEY=your-virustotal-api-key
ABUSEIPDB_API_KEY=your-abuseipdb-api-key
```

#### Frontend (.env.local)
```env
NEXT_PUBLIC_API_URL=http://localhost:8000
```

## API Documentation

The API documentation is available at http://localhost:8000/docs when running the backend.

### Key Endpoints

- `POST /api/upload`: Upload log files for analysis
- `GET /api/analysis/{id}`: Get analysis results
- `POST /api/connect-server`: Connect to remote server
- `GET /api/export/{id}`: Export analysis report
- `GET /api/dashboard`: Get dashboard statistics
- `POST /api/filter-logs`: Filter analyzed logs
- `GET /api/ip-reputation/{ip}`: Check IP reputation

## Deployment

### AWS Deployment

1. Deploy infrastructure:
```bash
aws cloudformation create-stack \
  --stack-name loganalyzer \
  --template-body file://deployment/aws/cloudformation.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=Production
```

2. Build and push Docker images to ECR:
```bash
./deployment/aws/deploy.sh
```

### Production Docker Compose

```bash
docker-compose -f docker-compose.prod.yml up -d
```

## Security Considerations

- All passwords should be changed from defaults
- Use strong SECRET_KEY for JWT tokens
- Enable HTTPS in production
- Regularly update dependencies
- Implement rate limiting for API endpoints
- Use firewall rules to restrict access
- Enable audit logging
- Regularly backup database

## Docker Management & Cleanup

### Quick Cleanup Commands

```bash
# Stop and remove all project containers, images, and volumes
docker-compose down -v --rmi all

# Clean up all Docker resources (CAREFUL - removes everything!)
docker system prune -a --volumes -f

# Check Docker disk usage
docker system df

# Remove only this project's images
docker images | grep loganalyzer | awk '{print $3}' | xargs docker rmi -f
```

### Common Docker Commands

```bash
# Rebuild without cache
docker-compose build --no-cache

# View logs
docker-compose logs -f [service_name]

# Enter container
docker-compose exec backend bash
docker-compose exec frontend sh

# Restart service
docker-compose restart backend

# Check service status
docker-compose ps
```

See [DOCKER_COMMANDS.md](./DOCKER_COMMANDS.md) for comprehensive Docker management guide.

## Testing

```bash
# Backend tests
cd backend
pytest tests/

# Frontend tests  
cd frontend
npm run test
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This software is proprietary and intended for commercial sale. All rights reserved.

## Support

For support and inquiries, please contact: support@loganalyzerpro.com

## Roadmap

- [ ] Machine learning model fine-tuning
- [ ] Real-time log streaming
- [ ] Custom alert rules
- [ ] Integration with SIEM platforms
- [ ] Mobile application
- [ ] Multi-tenancy support
- [ ] Advanced visualization dashboard
- [ ] Automated remediation actions