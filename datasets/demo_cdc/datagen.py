import config
from orders import Orders, initial_orders


def generate_initial_orders(orders: Orders):
    """One create (op=c) per order for OrderIDs 1..500, all PENDING."""
    for order_id, value in initial_orders().items():
        orders.record_order_event(order_id, "c", None, value)
    orders.producer.flush()
    print("Done.")


if __name__ == "__main__":
    orders = Orders(config.kafka_config(), config.schema_registry_config())
    generate_initial_orders(orders)
