import re
import json
import csv
import xml.etree.ElementTree as ET
from datetime import datetime
from typing import List, Dict, Any
import asyncio
from pathlib import Path

class LogParser:
    def __init__(self):
        self.patterns = {
            "apache": re.compile(
                r'(?P<ip>\d+\.\d+\.\d+\.\d+) - (?P<user>[\w-]+) \[(?P<timestamp>[^\]]+)\] "(?P<method>\w+) (?P<path>[^ ]+) (?P<protocol>[^"]+)" (?P<status>\d+) (?P<size>\d+)'
            ),
            "nginx": re.compile(
                r'(?P<ip>\d+\.\d+\.\d+\.\d+) - (?P<user>[\w-]+) \[(?P<timestamp>[^\]]+)\] "(?P<method>\w+) (?P<path>[^ ]+) (?P<protocol>[^"]+)" (?P<status>\d+) (?P<size>\d+) "(?P<referer>[^"]*)" "(?P<user_agent>[^"]*)"'
            ),
            "syslog": re.compile(
                r'(?P<timestamp>\w+ \d+ \d+:\d+:\d+) (?P<hostname>[\w\.-]+) (?P<service>[\w\[\]]+): (?P<message>.*)'
            ),
            "windows_event": re.compile(
                r'(?P<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) (?P<level>\w+) (?P<source>[\w\.]+) (?P<event_id>\d+) (?P<message>.*)'
            ),
            "json": None,
            "csv": None,
            "xml": None
        }
        
        self.severity_patterns = {
            "ERROR": re.compile(r'\b(error|err|fatal|critical|failed)\b', re.IGNORECASE),
            "WARNING": re.compile(r'\b(warning|warn|alert)\b', re.IGNORECASE),
            "INFO": re.compile(r'\b(info|information|notice)\b', re.IGNORECASE),
            "DEBUG": re.compile(r'\b(debug|trace|verbose)\b', re.IGNORECASE)
        }
    
    async def parse_file(self, file_path: str) -> List[Dict[str, Any]]:
        file_ext = Path(file_path).suffix.lower()
        
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        if file_ext == '.json':
            return await self._parse_json(content)
        elif file_ext == '.csv':
            return await self._parse_csv(content)
        elif file_ext == '.xml':
            return await self._parse_xml(content)
        else:
            return await self._parse_text_logs(content)
    
    async def _parse_text_logs(self, content: str) -> List[Dict[str, Any]]:
        logs = []
        lines = content.split('\n')
        
        for line in lines:
            if not line.strip():
                continue
            
            log_entry = None
            
            for log_type, pattern in self.patterns.items():
                if pattern and (match := pattern.match(line)):
                    log_entry = match.groupdict()
                    log_entry['type'] = log_type
                    break
            
            if not log_entry:
                log_entry = {
                    'raw': line,
                    'type': 'unknown',
                    'timestamp': datetime.now().isoformat()
                }
            
            log_entry['severity'] = self._detect_severity(line)
            
            if 'ip' in log_entry:
                log_entry['ip'] = self._normalize_ip(log_entry['ip'])
            
            logs.append(log_entry)
        
        return logs
    
    async def _parse_json(self, content: str) -> List[Dict[str, Any]]:
        try:
            data = json.loads(content)
            if isinstance(data, list):
                return data
            else:
                return [data]
        except json.JSONDecodeError:
            lines = content.split('\n')
            logs = []
            for line in lines:
                if line.strip():
                    try:
                        logs.append(json.loads(line))
                    except:
                        logs.append({'raw': line, 'type': 'json_error'})
            return logs
    
    async def _parse_csv(self, content: str) -> List[Dict[str, Any]]:
        logs = []
        reader = csv.DictReader(content.splitlines())
        for row in reader:
            log_entry = dict(row)
            log_entry['type'] = 'csv'
            logs.append(log_entry)
        return logs
    
    async def _parse_xml(self, content: str) -> List[Dict[str, Any]]:
        logs = []
        try:
            root = ET.fromstring(content)
            for element in root:
                log_entry = {
                    'type': 'xml',
                    'tag': element.tag,
                    'attributes': element.attrib,
                    'text': element.text or ''
                }
                for child in element:
                    log_entry[child.tag] = child.text
                logs.append(log_entry)
        except ET.ParseError:
            logs.append({'raw': content, 'type': 'xml_error'})
        return logs
    
    def _detect_severity(self, text: str) -> str:
        for severity, pattern in self.severity_patterns.items():
            if pattern.search(text):
                return severity
        return "INFO"
    
    def _normalize_ip(self, ip: str) -> str:
        parts = ip.split('.')
        if len(parts) == 4:
            try:
                return '.'.join(str(int(part)) for part in parts)
            except:
                pass
        return ip
    
    async def extract_ips(self, logs: List[Dict[str, Any]]) -> List[str]:
        ip_pattern = re.compile(r'\b(?:\d{1,3}\.){3}\d{1,3}\b')
        ips = set()
        
        for log in logs:
            if 'ip' in log:
                ips.add(log['ip'])
            else:
                text = str(log)
                found_ips = ip_pattern.findall(text)
                ips.update(found_ips)
        
        return list(ips)