import json
import logging
import uuid
from contextlib import asynccontextmanager
from aiokafka import AIOKafkaProducer
from fastapi import FastAPI, HTTPException
from prometheus_fastapi_instrumentator import Instrumentator
from pythonjsonlogger import jsonlogger
from .config import settings
from .database import db, redis_client
from .models import OrderCreate
from .telemetry import configure_telemetry

logger = logging.getLogger()
handler = logging.StreamHandler()
handler.setFormatter(jsonlogger.JsonFormatter())
logger.handlers = [handler]
logger.setLevel(logging.INFO)

PRODUCTS = [
    {"id": "p1", "name": "Laptop", "description": "Demo product", "price": 999},
    {"id": "p2", "name": "Keyboard", "description": "Demo product", "price": 79},
    {"id": "p3", "name": "Mouse", "description": "Demo product", "price": 49},
]

producer: AIOKafkaProducer | None = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global producer
    producer = AIOKafkaProducer(bootstrap_servers=settings.kafka_bootstrap_servers)
    await producer.start()
    try:
        yield
    finally:
        if producer:
            await producer.stop()

app = FastAPI(title=settings.app_name, lifespan=lifespan)
configure_telemetry(app)
Instrumentator().instrument(app).expose(app)

@app.get('/health')
def health():
    return {"status": "ok", "service": settings.app_name}

@app.get('/products')
def get_products():
    cache_key = 'products:all'
    cached = redis_client.get(cache_key)
    if cached:
        return json.loads(cached)
    redis_client.setex(cache_key, 60, json.dumps(PRODUCTS))
    return PRODUCTS

@app.post('/orders')
async def create_order(order: OrderCreate):
    product = next((p for p in PRODUCTS if p['id'] == order.product_id), None)
    if not product:
        raise HTTPException(status_code=404, detail='Product not found')

    order_doc = {
        "id": str(uuid.uuid4()),
        "customer_name": order.customer_name,
        "product_id": order.product_id,
        "quantity": order.quantity,
        "status": "CREATED"
    }
    db.orders.insert_one(order_doc)
    if producer:
        await producer.send_and_wait(
            settings.kafka_topic_orders,
            json.dumps(order_doc).encode('utf-8')
        )
    logger.info({"event": "order_created", "order_id": order_doc['id']})
    return order_doc

@app.get('/orders/{order_id}')
def get_order(order_id: str):
    order = db.orders.find_one({"id": order_id}, {"_id": 0})
    if not order:
        raise HTTPException(status_code=404, detail='Order not found')
    return order
