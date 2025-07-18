"""
Performance optimization utilities for Hospital Referral API
"""
import asyncio
import time
from functools import wraps
from typing import Dict, Any, Optional
import redis
import json
import hashlib
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

class CacheManager:
    """Redis-based caching for API responses"""
    
    def __init__(self, redis_url: str = "redis://localhost:6379"):
        try:
            self.redis_client = redis.from_url(redis_url, decode_responses=True)
            self.redis_client.ping()
            self.enabled = True
            logger.info("Redis cache enabled")
        except Exception as e:
            logger.warning(f"Redis not available, caching disabled: {e}")
            self.redis_client = None
            self.enabled = False
    
    def _generate_key(self, prefix: str, **kwargs) -> str:
        """Generate cache key from parameters"""
        key_data = json.dumps(kwargs, sort_keys=True)
        key_hash = hashlib.md5(key_data.encode()).hexdigest()
        return f"{prefix}:{key_hash}"
    
    def get(self, key: str) -> Optional[Any]:
        """Get value from cache"""
        if not self.enabled:
            return None
        
        try:
            value = self.redis_client.get(key)
            return json.loads(value) if value else None
        except Exception as e:
            logger.error(f"Cache get error: {e}")
            return None
    
    def set(self, key: str, value: Any, ttl: int = 300):
        """Set value in cache with TTL"""
        if not self.enabled:
            return
        
        try:
            self.redis_client.setex(key, ttl, json.dumps(value, default=str))
        except Exception as e:
            logger.error(f"Cache set error: {e}")
    
    def delete(self, key: str):
        """Delete key from cache"""
        if not self.enabled:
            return
        
        try:
            self.redis_client.delete(key)
        except Exception as e:
            logger.error(f"Cache delete error: {e}")

# Global cache instance
cache = CacheManager()

def cached_response(prefix: str, ttl: int = 300):
    """Decorator for caching API responses"""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Generate cache key
            cache_key = cache._generate_key(prefix, args=args, kwargs=kwargs)
            
            # Try to get from cache
            cached_result = cache.get(cache_key)
            if cached_result is not None:
                logger.info(f"Cache hit for {cache_key}")
                return cached_result
            
            # Execute function
            result = await func(*args, **kwargs)
            
            # Cache result
            cache.set(cache_key, result, ttl)
            logger.info(f"Cached result for {cache_key}")
            
            return result
        return wrapper
    return decorator

class PerformanceMonitor:
    """Monitor API performance metrics"""
    
    def __init__(self):
        self.metrics = {
            'request_count': 0,
            'total_response_time': 0,
            'error_count': 0,
            'cache_hits': 0,
            'cache_misses': 0
        }
        self.start_time = time.time()
    
    def record_request(self, response_time: float, error: bool = False):
        """Record request metrics"""
        self.metrics['request_count'] += 1
        self.metrics['total_response_time'] += response_time
        if error:
            self.metrics['error_count'] += 1
    
    def record_cache_hit(self):
        """Record cache hit"""
        self.metrics['cache_hits'] += 1
    
    def record_cache_miss(self):
        """Record cache miss"""
        self.metrics['cache_misses'] += 1
    
    def get_stats(self) -> Dict[str, Any]:
        """Get performance statistics"""
        uptime = time.time() - self.start_time
        avg_response_time = (
            self.metrics['total_response_time'] / self.metrics['request_count']
            if self.metrics['request_count'] > 0 else 0
        )
        
        cache_hit_rate = (
            self.metrics['cache_hits'] / (self.metrics['cache_hits'] + self.metrics['cache_misses'])
            if (self.metrics['cache_hits'] + self.metrics['cache_misses']) > 0 else 0
        )
        
        return {
            'uptime_seconds': uptime,
            'total_requests': self.metrics['request_count'],
            'error_rate': self.metrics['error_count'] / max(self.metrics['request_count'], 1),
            'average_response_time': avg_response_time,
            'cache_hit_rate': cache_hit_rate,
            'requests_per_second': self.metrics['request_count'] / max(uptime, 1)
        }

# Global performance monitor
performance_monitor = PerformanceMonitor()

def monitor_performance(func):
    """Decorator to monitor function performance"""
    @wraps(func)
    async def wrapper(*args, **kwargs):
        start_time = time.time()
        error = False
        
        try:
            result = await func(*args, **kwargs)
            return result
        except Exception as e:
            error = True
            raise
        finally:
            response_time = time.time() - start_time
            performance_monitor.record_request(response_time, error)
    
    return wrapper

class DatabaseOptimizer:
    """Optimize database operations"""
    
    @staticmethod
    def optimize_hospital_query(df, lat: float, lon: float, radius_km: float = 50):
        """Pre-filter hospitals by approximate distance before expensive calculations"""
        # Rough degree approximation (1 degree ≈ 111 km)
        lat_delta = radius_km / 111.0
        lon_delta = radius_km / (111.0 * abs(lat))  # Adjust for latitude
        
        # Filter by bounding box first
        filtered_df = df[
            (df['latitude'].between(lat - lat_delta, lat + lat_delta)) &
            (df['longitude'].between(lon - lon_delta, lon + lon_delta))
        ]
        
        logger.info(f"Pre-filtered hospitals: {len(df)} -> {len(filtered_df)}")
        return filtered_df
    
    @staticmethod
    def batch_distance_calculation(df, patient_coords, batch_size: int = 1000):
        """Calculate distances in batches for better performance"""
        from geopy.distance import geodesic
        
        distances = []
        for i in range(0, len(df), batch_size):
            batch = df.iloc[i:i + batch_size]
            batch_distances = batch.apply(
                lambda row: geodesic(patient_coords, (row['latitude'], row['longitude'])).km,
                axis=1
            )
            distances.extend(batch_distances.tolist())
        
        return distances

# Connection pooling for database connections
class ConnectionPool:
    """Simple connection pool implementation"""
    
    def __init__(self, max_connections: int = 10):
        self.max_connections = max_connections
        self.connections = asyncio.Queue(maxsize=max_connections)
        self.created_connections = 0
    
    async def get_connection(self):
        """Get connection from pool"""
        if self.connections.empty() and self.created_connections < self.max_connections:
            # Create new connection
            connection = self._create_connection()
            self.created_connections += 1
            return connection
        else:
            # Wait for available connection
            return await self.connections.get()
    
    async def return_connection(self, connection):
        """Return connection to pool"""
        await self.connections.put(connection)
    
    def _create_connection(self):
        """Create new database connection"""
        # Implement actual connection creation
        pass
