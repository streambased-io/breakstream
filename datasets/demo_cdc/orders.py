import random

from confluent_kafka import Producer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.serialization import MessageField, SerializationContext

NUM_INITIAL_ORDERS = 500
FIRST_NEW_ORDER_ID = 1001
NUM_DELETES = 100

# Seeds the initial order load so that later scripts (live updates, deletes)
# can rebuild the exact same rows for their CDC "before" images.
INITIAL_ORDERS_SEED = 1234


def random_order_value(order_id, status, rng=random):
    return {
        "OrderID": order_id,
        "CustomerID": rng.randint(1000, 9999),
        "Status": status,
        "Amount": round(rng.uniform(10.0, 1000.0), 2),
    }


def initial_orders():
    """The PENDING orders 1..NUM_INITIAL_ORDERS created by datagen.py, keyed by OrderID."""
    rng = random.Random(INITIAL_ORDERS_SEED)
    return {
        order_id: random_order_value(order_id, "PENDING", rng)
        for order_id in range(1, NUM_INITIAL_ORDERS + 1)
    }


class OrderCdcEvent(object):

    def __init__(self, op, before, after):
        self.op = op
        self.before = before
        self.after = after


class Orders(object):

    # Debezium-style CDC envelope (op/before/after) keyed by OrderID
    order_topic = "orders"
    order_key_str = """
    {
        "type": "record",
        "name": "OrderKey",
        "namespace": "io.streambased.demo",
        "fields": [
            {"name": "OrderID", "type": "int"}
        ]
    }
    """
    order_value_str = """
    {
        "type": "record",
        "name": "Envelope",
        "namespace": "io.streambased.demo",
        "fields": [
            {"name": "op", "type": "string"},
            {
                "name": "before",
                "type": [
                    "null",
                    {
                        "type": "record",
                        "name": "OrderValue",
                        "fields": [
                            {"name": "OrderID", "type": "int"},
                            {"name": "CustomerID", "type": "int"},
                            {"name": "Status", "type": "string"},
                            {"name": "Amount", "type": "double"}
                        ]
                    }
                ],
                "default": null
            },
            {
                "name": "after",
                "type": ["null", "io.streambased.demo.OrderValue"],
                "default": null
            }
        ]
    }
    """

    def __init__(self, kafka_config, schema_registry_config):
        self.producer = Producer(kafka_config)
        self.schema_registry_client = SchemaRegistryClient(schema_registry_config)
        self.order_key_serializer = AvroSerializer(self.schema_registry_client, self.order_key_str, Orders.order_key_to_dict)
        self.order_value_serializer = AvroSerializer(self.schema_registry_client, self.order_value_str, Orders.order_value_to_dict)

    @staticmethod
    def order_key_to_dict(orderId, ctx):
        return dict(OrderID=orderId)

    @staticmethod
    def order_value_to_dict(event, ctx):
        return dict(op=event.op, before=event.before, after=event.after)

    def record_order_event(self, orderId, op, before, after):
        print(f"Recording order CDC event: OrderID={orderId}, op={op}", flush=True)
        event = OrderCdcEvent(op, before, after)
        key_bytes = self.order_key_serializer(orderId, SerializationContext(self.order_topic, MessageField.KEY))
        value_bytes = self.order_value_serializer(event, SerializationContext(self.order_topic, MessageField.VALUE))
        self.producer.produce(self.order_topic, key=key_bytes, value=value_bytes)
        # keep the local queue from overflowing during bulk loads
        self.producer.poll(0)
