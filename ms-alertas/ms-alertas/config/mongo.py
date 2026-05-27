import pymongo
from django.conf import settings

_client = None

def get_db():
    global _client
    if _client is None:
        _client = pymongo.MongoClient(
            host=settings.MONGO_HOST,
            port=settings.MONGO_PORT,
            serverSelectionTimeoutMS=3000
        )
    return _client[settings.MONGO_DB]
