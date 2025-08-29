import asyncio
import json
from typing import List, Dict, Any
from datetime import datetime
import numpy as np
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
import ollama
import re
from collections import Counter

class AIAnalyzer:
    def __init__(self):
        self.ollama_client = None
        self.model_name = "llama3.2"
        self.isolation_forest = IsolationForest(contamination=0.1, random_state=42)
        self.scaler = StandardScaler()
        
    async def initialize(self):
        try:
            self.ollama_client = ollama.Client()
            models = await asyncio.to_thread(self.ollama_client.list)
            if not any(m['name'].startswith('llama') for m in models.get('models', [])):
                print("Pulling Llama model for AI analysis...")
                await asyncio.to_thread(self.ollama_client.pull, self.model_name)
        except Exception as e:
            print(f"Warning: Could not initialize Ollama: {e}")
            self.ollama_client = None
    
    async def analyze_logs(self, logs: List[Dict[str, Any]]) -> Dict[str, Any]:
        analysis = {
            "summary": {},
            "anomalies": [],
            "patterns": [],
            "security_issues": [],
            "recommendations": [],
            "statistics": {}
        }
        
        analysis["statistics"] = await self._calculate_statistics(logs)
        
        analysis["anomalies"] = await self._detect_anomalies(logs)
        
        analysis["patterns"] = await self._identify_patterns(logs)
        
        analysis["security_issues"] = await self._identify_security_issues(logs)
        
        if self.ollama_client:
            try:
                ai_insights = await self._get_ai_insights(logs)
                analysis["ai_insights"] = ai_insights
                analysis["recommendations"] = ai_insights.get("recommendations", [])
            except Exception as e:
                print(f"AI analysis error: {e}")
                analysis["ai_insights"] = {"error": str(e)}
        
        analysis["summary"] = await self._generate_summary(analysis)
        
        return analysis
    
    async def _calculate_statistics(self, logs: List[Dict[str, Any]]) -> Dict[str, Any]:
        stats = {
            "total_logs": len(logs),
            "unique_ips": len(set(log.get("ip", "") for log in logs if log.get("ip"))),
            "severity_distribution": {},
            "status_codes": {},
            "top_ips": [],
            "top_paths": [],
            "error_rate": 0
        }
        
        severities = Counter(log.get("severity", "INFO") for log in logs)
        stats["severity_distribution"] = dict(severities)
        
        status_codes = Counter(log.get("status", "") for log in logs if log.get("status"))
        stats["status_codes"] = dict(status_codes.most_common(10))
        
        ips = Counter(log.get("ip", "") for log in logs if log.get("ip"))
        stats["top_ips"] = [{"ip": ip, "count": count} for ip, count in ips.most_common(10)]
        
        paths = Counter(log.get("path", "") for log in logs if log.get("path"))
        stats["top_paths"] = [{"path": path, "count": count} for path, count in paths.most_common(10)]
        
        error_count = sum(1 for log in logs if log.get("severity") in ["ERROR", "CRITICAL"])
        stats["error_rate"] = (error_count / len(logs) * 100) if logs else 0
        
        return stats
    
    async def _detect_anomalies(self, logs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        anomalies = []
        
        ip_counts = Counter(log.get("ip", "") for log in logs if log.get("ip"))
        mean_count = np.mean(list(ip_counts.values()))
        std_count = np.std(list(ip_counts.values()))
        
        for ip, count in ip_counts.items():
            if count > mean_count + 3 * std_count:
                anomalies.append({
                    "type": "high_frequency_ip",
                    "ip": ip,
                    "count": count,
                    "severity": "high",
                    "description": f"IP {ip} has unusually high activity ({count} requests)"
                })
        
        error_bursts = await self._detect_error_bursts(logs)
        anomalies.extend(error_bursts)
        
        suspicious_patterns = await self._detect_suspicious_patterns(logs)
        anomalies.extend(suspicious_patterns)
        
        return anomalies
    
    async def _detect_error_bursts(self, logs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        bursts = []
        error_logs = [log for log in logs if log.get("severity") in ["ERROR", "CRITICAL"]]
        
        if len(error_logs) > 10:
            time_windows = {}
            for log in error_logs:
                if "timestamp" in log:
                    try:
                        ts = datetime.fromisoformat(log["timestamp"])
                        window = ts.replace(second=0, microsecond=0)
                        time_windows[window] = time_windows.get(window, 0) + 1
                    except:
                        pass
            
            for window, count in time_windows.items():
                if count > 5:
                    bursts.append({
                        "type": "error_burst",
                        "timestamp": window.isoformat(),
                        "count": count,
                        "severity": "high",
                        "description": f"Error burst detected: {count} errors in one minute"
                    })
        
        return bursts
    
    async def _detect_suspicious_patterns(self, logs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        suspicious = []
        
        sql_injection_pattern = re.compile(r'(union|select|insert|delete|update|drop|create)\s+', re.IGNORECASE)
        xss_pattern = re.compile(r'(<script|javascript:|onerror=|onload=)', re.IGNORECASE)
        path_traversal_pattern = re.compile(r'(\.\./|\.\.\\|%2e%2e)', re.IGNORECASE)
        
        for log in logs:
            path = log.get("path", "")
            message = log.get("message", "")
            combined = f"{path} {message}"
            
            if sql_injection_pattern.search(combined):
                suspicious.append({
                    "type": "sql_injection_attempt",
                    "severity": "critical",
                    "details": log,
                    "description": "Potential SQL injection attempt detected"
                })
            
            if xss_pattern.search(combined):
                suspicious.append({
                    "type": "xss_attempt",
                    "severity": "high",
                    "details": log,
                    "description": "Potential XSS attack attempt detected"
                })
            
            if path_traversal_pattern.search(combined):
                suspicious.append({
                    "type": "path_traversal_attempt",
                    "severity": "high",
                    "details": log,
                    "description": "Potential path traversal attempt detected"
                })
        
        return suspicious
    
    async def _identify_patterns(self, logs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        patterns = []
        
        user_agents = Counter(log.get("user_agent", "") for log in logs if log.get("user_agent"))
        bot_pattern = re.compile(r'(bot|crawler|spider|scraper)', re.IGNORECASE)
        
        for ua, count in user_agents.most_common(5):
            if bot_pattern.search(ua):
                patterns.append({
                    "type": "bot_activity",
                    "user_agent": ua,
                    "count": count,
                    "description": f"Bot/crawler activity detected: {count} requests"
                })
        
        failed_logins = [log for log in logs if "login" in str(log).lower() and 
                        (log.get("status") == "401" or "failed" in str(log).lower())]
        if len(failed_logins) > 5:
            patterns.append({
                "type": "brute_force_attempt",
                "count": len(failed_logins),
                "severity": "high",
                "description": f"Potential brute force attack: {len(failed_logins)} failed login attempts"
            })
        
        return patterns
    
    async def _identify_security_issues(self, logs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        issues = []
        
        unencrypted_sensitive = re.compile(r'(password|passwd|pwd|api_key|token|secret)=', re.IGNORECASE)
        
        for log in logs:
            log_str = str(log)
            
            if unencrypted_sensitive.search(log_str):
                issues.append({
                    "type": "sensitive_data_exposure",
                    "severity": "critical",
                    "description": "Potential sensitive data exposure in logs"
                })
                break
        
        http_errors = [log for log in logs if log.get("status", "").startswith("5")]
        if len(http_errors) > len(logs) * 0.05:
            issues.append({
                "type": "high_error_rate",
                "severity": "medium",
                "percentage": len(http_errors) / len(logs) * 100,
                "description": f"High server error rate: {len(http_errors)} 5xx errors"
            })
        
        return issues
    
    async def _get_ai_insights(self, logs: List[Dict[str, Any]]) -> Dict[str, Any]:
        if not self.ollama_client or not logs:
            return {}
        
        sample_logs = logs[:100]
        log_summary = json.dumps(sample_logs[:10], default=str)
        
        prompt = f"""Analyze these log entries and provide security insights:

Log Sample:
{log_summary}

Total logs: {len(logs)}
Error rate: {sum(1 for l in logs if l.get('severity') == 'ERROR') / len(logs) * 100:.2f}%

Provide:
1. Main security concerns
2. Potential attack patterns
3. Recommendations for improvement
4. Priority actions

Format as JSON with keys: concerns, patterns, recommendations, priority_actions"""
        
        try:
            response = await asyncio.to_thread(
                self.ollama_client.generate,
                model=self.model_name,
                prompt=prompt
            )
            
            response_text = response.get('response', '')
            
            try:
                json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
                if json_match:
                    insights = json.loads(json_match.group())
                else:
                    insights = {
                        "concerns": [response_text[:200]],
                        "patterns": [],
                        "recommendations": ["Review logs manually"],
                        "priority_actions": ["Investigate anomalies"]
                    }
            except:
                insights = {
                    "raw_analysis": response_text,
                    "recommendations": ["Review AI analysis manually"]
                }
            
            return insights
            
        except Exception as e:
            return {"error": f"AI analysis failed: {str(e)}"}
    
    async def _generate_summary(self, analysis: Dict[str, Any]) -> Dict[str, Any]:
        summary = {
            "risk_level": "low",
            "total_anomalies": len(analysis.get("anomalies", [])),
            "critical_issues": 0,
            "main_concerns": [],
            "immediate_actions": []
        }
        
        critical_count = sum(1 for a in analysis.get("anomalies", []) 
                           if a.get("severity") == "critical")
        high_count = sum(1 for a in analysis.get("anomalies", []) 
                        if a.get("severity") == "high")
        
        summary["critical_issues"] = critical_count
        
        if critical_count > 0:
            summary["risk_level"] = "critical"
        elif high_count > 2:
            summary["risk_level"] = "high"
        elif high_count > 0:
            summary["risk_level"] = "medium"
        
        if analysis.get("security_issues"):
            summary["main_concerns"] = [
                issue["description"] for issue in analysis["security_issues"][:3]
            ]
        
        if analysis.get("ai_insights", {}).get("priority_actions"):
            summary["immediate_actions"] = analysis["ai_insights"]["priority_actions"][:3]
        
        return summary