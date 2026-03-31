import os

class Settings:
    app_name = os.getenv('APP_NAME', 'three-tier-backend')
    mongo_uri = os.getenv('MONGO_URI', 'mongodb://localhost:27017')
    mongo_db = os.getenv('MONGO_DB', 'three_tier_demo')
    redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
    kafka_bootstrap_servers = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
    kafka_topic_orders = os.getenv('KAFKA_TOPIC_ORDERS', 'order.created')
    otel_endpoint = os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT', 'http://localhost:4318')

settings = Settings()
