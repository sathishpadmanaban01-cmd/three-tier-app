import asyncio
import json
import logging
import os
from aiokafka import AIOKafkaConsumer
from pymongo import MongoClient
from pythonjsonlogger import jsonlogger

logger = logging.getLogger()
handler = logging.StreamHandler()
handler.setFormatter(jsonlogger.JsonFormatter())
logger.handlers = [handler]
logger.setLevel(logging.INFO)

KAFKA_BOOTSTRAP_SERVERS = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
KAFKA_TOPIC_ORDERS = os.getenv('KAFKA_TOPIC_ORDERS', 'order.created')
MONGO_URI = os.getenv('MONGO_URI', 'mongodb://localhost:27017')
MONGO_DB = os.getenv('MONGO_DB', 'three_tier_demo')

mongo = MongoClient(MONGO_URI)
db = mongo[MONGO_DB]

async def main():
    consumer = AIOKafkaConsumer(
        KAFKA_TOPIC_ORDERS,
        bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
        group_id='order-worker'
    )
    await consumer.start()
    try:
        async for msg in consumer:
            event = json.loads(msg.value.decode('utf-8'))
            db.order_audit.insert_one({
                "order_id": event['id'],
                "event": "ORDER_CONSUMED",
                "payload": event
            })
            db.orders.update_one(
                {"id": event['id']},
                {"$set": {"status": "PROCESSED"}}
            )
            logger.info({"event": "order_processed", "order_id": event['id']})
    finally:
        await consumer.stop()

if __name__ == '__main__':
    asyncio.run(main())
