from pydantic import BaseModel

class OrderCreate(BaseModel):
    customer_name: str
    product_id: str
    quantity: int
