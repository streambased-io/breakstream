import config
from orders import NUM_DELETES, Orders, initial_orders


def generate_deletes(orders: Orders):
    """One delete (op=d) for each of OrderIDs 1..100."""
    state = initial_orders()
    for order_id in range(1, NUM_DELETES + 1):
        orders.record_order_event(order_id, "d", state[order_id], None)
    orders.producer.flush()
    print("Done.")


if __name__ == "__main__":
    orders = Orders(config.kafka_config(), config.schema_registry_config())
    generate_deletes(orders)
