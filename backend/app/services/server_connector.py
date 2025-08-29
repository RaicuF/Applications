import asyncio
import paramiko
import asyncssh
from typing import List, Dict, Any, Optional
import re
from datetime import datetime

class ServerConnector:
    def __init__(self):
        self.ssh_client = None
        
    async def fetch_logs(
        self,
        host: str,
        port: int = 22,
        username: str = None,
        password: str = None,
        key_path: str = None,
        log_paths: List[str] = None
    ) -> List[Dict[str, Any]]:
        
        if not log_paths:
            log_paths = [
                "/var/log/syslog",
                "/var/log/auth.log",
                "/var/log/apache2/access.log",
                "/var/log/nginx/access.log"
            ]
        
        all_logs = []
        
        try:
            if key_path:
                conn = await asyncssh.connect(
                    host,
                    port=port,
                    username=username,
                    client_keys=[key_path],
                    known_hosts=None
                )
            else:
                conn = await asyncssh.connect(
                    host,
                    port=port,
                    username=username,
                    password=password,
                    known_hosts=None
                )
            
            async with conn:
                for log_path in log_paths:
                    try:
                        result = await conn.run(f'tail -n 1000 {log_path}', check=False)
                        if result.returncode == 0:
                            logs = self._parse_log_content(result.stdout, log_path)
                            all_logs.extend(logs)
                    except Exception as e:
                        print(f"Error reading {log_path}: {e}")
                
                system_info = await self._get_system_info(conn)
                for log in all_logs:
                    log['server_info'] = system_info
        
        except Exception as e:
            raise Exception(f"Failed to connect to server: {str(e)}")
        
        return all_logs
    
    async def _get_system_info(self, conn) -> Dict[str, Any]:
        info = {}
        
        try:
            result = await conn.run('hostname', check=False)
            info['hostname'] = result.stdout.strip() if result.returncode == 0 else 'unknown'
            
            result = await conn.run('uname -a', check=False)
            info['system'] = result.stdout.strip() if result.returncode == 0 else 'unknown'
            
            result = await conn.run('date', check=False)
            info['server_time'] = result.stdout.strip() if result.returncode == 0 else 'unknown'
            
        except Exception as e:
            print(f"Error getting system info: {e}")
        
        return info
    
    def _parse_log_content(self, content: str, source_path: str) -> List[Dict[str, Any]]:
        logs = []
        lines = content.split('\n')
        
        for line in lines:
            if not line.strip():
                continue
            
            log_entry = {
                'raw': line,
                'source': source_path,
                'timestamp': datetime.now().isoformat()
            }
            
            if 'apache' in source_path or 'access' in source_path:
                parsed = self._parse_apache_log(line)
                if parsed:
                    log_entry.update(parsed)
            elif 'auth' in source_path:
                parsed = self._parse_auth_log(line)
                if parsed:
                    log_entry.update(parsed)
            elif 'syslog' in source_path:
                parsed = self._parse_syslog(line)
                if parsed:
                    log_entry.update(parsed)
            
            logs.append(log_entry)
        
        return logs
    
    def _parse_apache_log(self, line: str) -> Optional[Dict[str, Any]]:
        pattern = r'(?P<ip>\d+\.\d+\.\d+\.\d+) - (?P<user>[\w-]+) \[(?P<timestamp>[^\]]+)\] "(?P<method>\w+) (?P<path>[^ ]+) (?P<protocol>[^"]+)" (?P<status>\d+) (?P<size>\d+)'
        match = re.match(pattern, line)
        
        if match:
            return match.groupdict()
        return None
    
    def _parse_auth_log(self, line: str) -> Optional[Dict[str, Any]]:
        patterns = {
            'failed_login': r'(?P<timestamp>\w+ \d+ \d+:\d+:\d+).*Failed password for (?P<user>\w+) from (?P<ip>\d+\.\d+\.\d+\.\d+)',
            'successful_login': r'(?P<timestamp>\w+ \d+ \d+:\d+:\d+).*Accepted (?P<method>\w+) for (?P<user>\w+) from (?P<ip>\d+\.\d+\.\d+\.\d+)',
            'sudo': r'(?P<timestamp>\w+ \d+ \d+:\d+:\d+).*sudo:\s+(?P<user>\w+).*COMMAND=(?P<command>.*)'
        }
        
        for event_type, pattern in patterns.items():
            match = re.search(pattern, line)
            if match:
                result = match.groupdict()
                result['event_type'] = event_type
                return result
        
        return None
    
    def _parse_syslog(self, line: str) -> Optional[Dict[str, Any]]:
        pattern = r'(?P<timestamp>\w+ \d+ \d+:\d+:\d+) (?P<hostname>[\w\.-]+) (?P<service>[\w\[\]]+): (?P<message>.*)'
        match = re.match(pattern, line)
        
        if match:
            result = match.groupdict()
            
            if 'error' in result['message'].lower():
                result['severity'] = 'ERROR'
            elif 'warning' in result['message'].lower():
                result['severity'] = 'WARNING'
            else:
                result['severity'] = 'INFO'
            
            return result
        
        return None
    
    async def test_connection(
        self,
        host: str,
        port: int = 22,
        username: str = None,
        password: str = None,
        key_path: str = None
    ) -> Dict[str, Any]:
        
        try:
            if key_path:
                conn = await asyncssh.connect(
                    host,
                    port=port,
                    username=username,
                    client_keys=[key_path],
                    known_hosts=None,
                    connect_timeout=10
                )
            else:
                conn = await asyncssh.connect(
                    host,
                    port=port,
                    username=username,
                    password=password,
                    known_hosts=None,
                    connect_timeout=10
                )
            
            async with conn:
                result = await conn.run('echo "Connection successful"', check=False)
                
                return {
                    'success': True,
                    'message': 'Connection successful',
                    'output': result.stdout.strip()
                }
        
        except asyncssh.Error as e:
            return {
                'success': False,
                'message': f'SSH connection failed: {str(e)}',
                'error': str(e)
            }
        except Exception as e:
            return {
                'success': False,
                'message': f'Connection failed: {str(e)}',
                'error': str(e)
            }