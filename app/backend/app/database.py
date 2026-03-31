from pymongo import MongoClient
from redis import Redis
from .config import settings

mongo_client = MongoClient(settings.mongo_uri)
db = mongo_client[settings.mongo_db]
redis_client = Redis.from_url(settings.redis_url, decode_responses=True)
