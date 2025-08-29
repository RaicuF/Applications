import redis.asyncio as redis
import json
from typing import Any, Optional
import os
from datetime import timedelta

class CacheManager:
    def __init__(self):
        self.redis_client = None
        self.local_cache = {}
        
    async def initialize(self):
        try:
            redis_url = os.getenv("REDIS_URL", "redis://localhost:6379")
            self.redis_client = await redis.from_url(redis_url)
            await self.redis_client.ping()
            print("Redis cache connected")
        except Exception as e:
            print(f"Redis connection failed, using local cache: {e}")
            self.redis_client = None
    
    async def get(self, key: str) -> Optional[Any]:
        if self.redis_client:
            try:
                value = await self.redis_client.get(key)
                if value:
                    return json.loads(value)
            except Exception as e:
                print(f"Cache get error: {e}")
        else:
            return self.local_cache.get(key)
        
        return None
    
    async def set(self, key: str, value: Any, ttl: int = 3600) -> bool:
        if self.redis_client:
            try:
                await self.redis_client.setex(
                    key,
                    ttl,
                    json.dumps(value, default=str)
                )
                return True
            except Exception as e:
                print(f"Cache set error: {e}")
        else:
            self.local_cache[key] = value
            return True
        
        return False
    
    async def delete(self, key: str) -> bool:
        if self.redis_client:
            try:
                await self.redis_client.delete(key)
                return True
            except Exception as e:
                print(f"Cache delete error: {e}")
        else:
            if key in self.local_cache:
                del self.local_cache[key]
                return True
        
        return False
    
    async def clear(self) -> bool:
        if self.redis_client:
            try:
                await self.redis_client.flushdb()
                return True
            except Exception as e:
                print(f"Cache clear error: {e}")
        else:
            self.local_cache.clear()
            return True
        
        return False

cache_manager = CacheManager()