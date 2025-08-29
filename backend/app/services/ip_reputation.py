import asyncio
import httpx
from typing import List, Dict, Any
import os
from datetime import datetime, timedelta
from dotenv import load_dotenv
import json

load_dotenv()

class IPReputationChecker:
    def __init__(self):
        self.virustotal_api_key = os.getenv("VIRUSTOTAL_API_KEY", "")
        self.abuseipdb_api_key = os.getenv("ABUSEIPDB_API_KEY", "")
        self.cache = {}
        self.cache_ttl = timedelta(hours=24)
        
    async def check_single(self, ip: str) -> Dict[str, Any]:
        if ip in self.cache:
            cached = self.cache[ip]
            if datetime.now() - cached["checked_at"] < self.cache_ttl:
                return cached["data"]
        
        reputation = {
            "ip": ip,
            "risk_score": 0,
            "is_malicious": False,
            "sources": {},
            "details": {}
        }
        
        tasks = []
        if self.virustotal_api_key:
            tasks.append(self._check_virustotal(ip))
        if self.abuseipdb_api_key:
            tasks.append(self._check_abuseipdb(ip))
        
        if not tasks:
            tasks.append(self._check_public_blocklists(ip))
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        for result in results:
            if isinstance(result, Exception):
                continue
            if result:
                reputation["sources"].update(result.get("sources", {}))
                reputation["risk_score"] = max(reputation["risk_score"], result.get("risk_score", 0))
                reputation["details"].update(result.get("details", {}))
        
        reputation["is_malicious"] = reputation["risk_score"] > 50
        
        self.cache[ip] = {
            "data": reputation,
            "checked_at": datetime.now()
        }
        
        return reputation
    
    async def check_batch(self, ips: List[str]) -> List[Dict[str, Any]]:
        tasks = [self.check_single(ip) for ip in ips if ip]
        results = await asyncio.gather(*tasks)
        return [r for r in results if r.get("risk_score", 0) > 0]
    
    async def _check_virustotal(self, ip: str) -> Dict[str, Any]:
        if not self.virustotal_api_key:
            return None
        
        url = f"https://www.virustotal.com/api/v3/ip_addresses/{ip}"
        headers = {"x-apikey": self.virustotal_api_key}
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(url, headers=headers, timeout=10)
                if response.status_code == 200:
                    data = response.json()
                    attributes = data.get("data", {}).get("attributes", {})
                    
                    malicious = attributes.get("last_analysis_stats", {}).get("malicious", 0)
                    suspicious = attributes.get("last_analysis_stats", {}).get("suspicious", 0)
                    total = sum(attributes.get("last_analysis_stats", {}).values())
                    
                    risk_score = 0
                    if total > 0:
                        risk_score = ((malicious * 2 + suspicious) / total) * 100
                    
                    return {
                        "sources": {"virustotal": True},
                        "risk_score": risk_score,
                        "details": {
                            "virustotal": {
                                "malicious": malicious,
                                "suspicious": suspicious,
                                "total_engines": total,
                                "country": attributes.get("country", ""),
                                "owner": attributes.get("as_owner", "")
                            }
                        }
                    }
        except Exception as e:
            print(f"VirusTotal check failed for {ip}: {e}")
        
        return None
    
    async def _check_abuseipdb(self, ip: str) -> Dict[str, Any]:
        if not self.abuseipdb_api_key:
            return None
        
        url = "https://api.abuseipdb.com/api/v2/check"
        headers = {
            "Key": self.abuseipdb_api_key,
            "Accept": "application/json"
        }
        params = {
            "ipAddress": ip,
            "maxAgeInDays": 90
        }
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(url, headers=headers, params=params, timeout=10)
                if response.status_code == 200:
                    data = response.json()
                    ip_data = data.get("data", {})
                    
                    abuse_score = ip_data.get("abuseConfidenceScore", 0)
                    
                    return {
                        "sources": {"abuseipdb": True},
                        "risk_score": abuse_score,
                        "details": {
                            "abuseipdb": {
                                "abuse_score": abuse_score,
                                "country": ip_data.get("countryCode", ""),
                                "usage_type": ip_data.get("usageType", ""),
                                "isp": ip_data.get("isp", ""),
                                "total_reports": ip_data.get("totalReports", 0),
                                "is_whitelisted": ip_data.get("isWhitelisted", False)
                            }
                        }
                    }
        except Exception as e:
            print(f"AbuseIPDB check failed for {ip}: {e}")
        
        return None
    
    async def _check_public_blocklists(self, ip: str) -> Dict[str, Any]:
        blocklists = [
            "https://raw.githubusercontent.com/stamparm/ipsum/master/ipsum.txt",
            "https://lists.blocklist.de/lists/all.txt"
        ]
        
        is_blocked = False
        blocked_lists = []
        
        try:
            async with httpx.AsyncClient() as client:
                for blocklist_url in blocklists:
                    try:
                        response = await client.get(blocklist_url, timeout=5)
                        if response.status_code == 200:
                            if ip in response.text:
                                is_blocked = True
                                blocked_lists.append(blocklist_url.split("/")[-2])
                    except:
                        continue
        except:
            pass
        
        risk_score = 75 if is_blocked else 0
        
        return {
            "sources": {"public_blocklists": True},
            "risk_score": risk_score,
            "details": {
                "public_blocklists": {
                    "is_blocked": is_blocked,
                    "blocked_lists": blocked_lists
                }
            }
        }