from fastapi import FastAPI, HTTPException, Depends, UploadFile, File, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, StreamingResponse
from sqlalchemy.orm import Session
from typing import List, Optional, Dict, Any
import asyncio
import uuid
from datetime import datetime
import os
import json

from app.database import get_db, init_db
from app.models import LogAnalysis, User, AnalysisHistory
from app.auth import get_current_user, create_access_token
from app.services.log_parser import LogParser
from app.services.ai_analyzer import AIAnalyzer
from app.services.ip_reputation import IPReputationChecker
from app.services.export_service import ExportService
from app.services.server_connector import ServerConnector
from app.utils.cache import cache_manager

app = FastAPI(
    title="AI Log Analyzer Pro",
    description="Professional AI-powered log analysis platform",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:8000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

log_parser = LogParser()
ai_analyzer = AIAnalyzer()
ip_checker = IPReputationChecker()
export_service = ExportService()
server_connector = ServerConnector()

@app.on_event("startup")
async def startup_event():
    await init_db()
    await ai_analyzer.initialize()
    await cache_manager.initialize()

@app.post("/api/upload")
async def upload_logs(
    background_tasks: BackgroundTasks,
    files: List[UploadFile] = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    analysis_id = str(uuid.uuid4())
    uploaded_files = []
    
    for file in files:
        file_path = f"/tmp/uploads/{analysis_id}/{file.filename}"
        os.makedirs(os.path.dirname(file_path), exist_ok=True)
        
        content = await file.read()
        with open(file_path, "wb") as f:
            f.write(content)
        
        uploaded_files.append({
            "filename": file.filename,
            "path": file_path,
            "size": len(content)
        })
    
    background_tasks.add_task(
        process_logs_background,
        analysis_id,
        uploaded_files,
        current_user.id,
        db
    )
    
    return {
        "analysis_id": analysis_id,
        "status": "processing",
        "files": [f["filename"] for f in uploaded_files]
    }

async def process_logs_background(
    analysis_id: str,
    files: List[Dict],
    user_id: int,
    db: Session
):
    try:
        all_logs = []
        for file_info in files:
            parsed_logs = await log_parser.parse_file(file_info["path"])
            all_logs.extend(parsed_logs)
        
        suspicious_ips = await ip_checker.check_batch(
            list(set([log.get("ip") for log in all_logs if log.get("ip")]))
        )
        
        ai_insights = await ai_analyzer.analyze_logs(all_logs)
        
        analysis = LogAnalysis(
            id=analysis_id,
            user_id=user_id,
            files=json.dumps([f["filename"] for f in files]),
            total_logs=len(all_logs),
            suspicious_ips=json.dumps(suspicious_ips),
            ai_insights=json.dumps(ai_insights),
            status="completed",
            created_at=datetime.utcnow()
        )
        
        db.add(analysis)
        db.commit()
        
        await cache_manager.set(f"analysis_{analysis_id}", {
            "logs": all_logs,
            "suspicious_ips": suspicious_ips,
            "ai_insights": ai_insights
        }, ttl=3600)
        
    except Exception as e:
        db.query(LogAnalysis).filter(LogAnalysis.id == analysis_id).update({
            "status": "failed",
            "error": str(e)
        })
        db.commit()

@app.get("/api/analysis/{analysis_id}")
async def get_analysis(
    analysis_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    analysis = db.query(LogAnalysis).filter(
        LogAnalysis.id == analysis_id,
        LogAnalysis.user_id == current_user.id
    ).first()
    
    if not analysis:
        raise HTTPException(status_code=404, detail="Analysis not found")
    
    cached_data = await cache_manager.get(f"analysis_{analysis_id}")
    
    return {
        "id": analysis.id,
        "status": analysis.status,
        "created_at": analysis.created_at,
        "files": json.loads(analysis.files) if analysis.files else [],
        "total_logs": analysis.total_logs,
        "suspicious_ips": json.loads(analysis.suspicious_ips) if analysis.suspicious_ips else [],
        "ai_insights": json.loads(analysis.ai_insights) if analysis.ai_insights else {},
        "detailed_logs": cached_data.get("logs") if cached_data else []
    }

@app.post("/api/connect-server")
async def connect_to_server(
    server_config: Dict[str, Any],
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        logs = await server_connector.fetch_logs(
            host=server_config["host"],
            port=server_config.get("port", 22),
            username=server_config["username"],
            password=server_config.get("password"),
            key_path=server_config.get("key_path"),
            log_paths=server_config.get("log_paths", ["/var/log/syslog"])
        )
        
        analysis_id = str(uuid.uuid4())
        
        suspicious_ips = await ip_checker.check_batch(
            list(set([log.get("ip") for log in logs if log.get("ip")]))
        )
        
        ai_insights = await ai_analyzer.analyze_logs(logs)
        
        analysis = LogAnalysis(
            id=analysis_id,
            user_id=current_user.id,
            source="server",
            server_info=json.dumps({"host": server_config["host"]}),
            total_logs=len(logs),
            suspicious_ips=json.dumps(suspicious_ips),
            ai_insights=json.dumps(ai_insights),
            status="completed",
            created_at=datetime.utcnow()
        )
        
        db.add(analysis)
        db.commit()
        
        return {
            "analysis_id": analysis_id,
            "status": "completed",
            "total_logs": len(logs)
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/export/{analysis_id}")
async def export_analysis(
    analysis_id: str,
    format: str = "pdf",
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    analysis = db.query(LogAnalysis).filter(
        LogAnalysis.id == analysis_id,
        LogAnalysis.user_id == current_user.id
    ).first()
    
    if not analysis:
        raise HTTPException(status_code=404, detail="Analysis not found")
    
    cached_data = await cache_manager.get(f"analysis_{analysis_id}")
    
    export_data = {
        "id": analysis.id,
        "created_at": analysis.created_at.isoformat(),
        "total_logs": analysis.total_logs,
        "suspicious_ips": json.loads(analysis.suspicious_ips) if analysis.suspicious_ips else [],
        "ai_insights": json.loads(analysis.ai_insights) if analysis.ai_insights else {},
        "logs": cached_data.get("logs") if cached_data else []
    }
    
    if format == "pdf":
        file_path = await export_service.export_pdf(export_data)
    elif format == "excel":
        file_path = await export_service.export_excel(export_data)
    elif format == "word":
        file_path = await export_service.export_word(export_data)
    elif format == "csv":
        file_path = await export_service.export_csv(export_data)
    else:
        raise HTTPException(status_code=400, detail="Unsupported export format")
    
    return FileResponse(
        file_path,
        media_type="application/octet-stream",
        filename=f"analysis_{analysis_id}.{format}"
    )

@app.get("/api/dashboard")
async def get_dashboard(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    analyses = db.query(LogAnalysis).filter(
        LogAnalysis.user_id == current_user.id
    ).order_by(LogAnalysis.created_at.desc()).limit(10).all()
    
    total_analyses = db.query(LogAnalysis).filter(
        LogAnalysis.user_id == current_user.id
    ).count()
    
    dashboard_data = {
        "total_analyses": total_analyses,
        "recent_analyses": [
            {
                "id": a.id,
                "created_at": a.created_at.isoformat(),
                "status": a.status,
                "total_logs": a.total_logs,
                "files": json.loads(a.files) if a.files else []
            }
            for a in analyses
        ],
        "statistics": {
            "total_logs_processed": sum(a.total_logs for a in analyses),
            "suspicious_ips_found": sum(
                len(json.loads(a.suspicious_ips)) if a.suspicious_ips else 0
                for a in analyses
            )
        }
    }
    
    return dashboard_data

@app.post("/api/filter-logs")
async def filter_logs(
    analysis_id: str,
    filters: Dict[str, Any],
    current_user: User = Depends(get_current_user)
):
    cached_data = await cache_manager.get(f"analysis_{analysis_id}")
    
    if not cached_data or "logs" not in cached_data:
        raise HTTPException(status_code=404, detail="Analysis data not found")
    
    logs = cached_data["logs"]
    filtered_logs = logs
    
    if filters.get("ip"):
        filtered_logs = [l for l in filtered_logs if l.get("ip") == filters["ip"]]
    
    if filters.get("user"):
        filtered_logs = [l for l in filtered_logs if filters["user"] in str(l.get("user", ""))]
    
    if filters.get("start_time") and filters.get("end_time"):
        start = datetime.fromisoformat(filters["start_time"])
        end = datetime.fromisoformat(filters["end_time"])
        filtered_logs = [
            l for l in filtered_logs
            if start <= datetime.fromisoformat(l.get("timestamp", "")) <= end
        ]
    
    if filters.get("severity"):
        filtered_logs = [l for l in filtered_logs if l.get("severity") == filters["severity"]]
    
    return {
        "total": len(filtered_logs),
        "logs": filtered_logs[:1000]
    }

@app.get("/api/ip-reputation/{ip}")
async def check_ip_reputation(
    ip: str,
    current_user: User = Depends(get_current_user)
):
    reputation = await ip_checker.check_single(ip)
    return reputation

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)