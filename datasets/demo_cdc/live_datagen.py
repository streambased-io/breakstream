import random
import time

import config
from orders import FIRST_NEW_ORDER_ID, NUM_INITIAL_ORDERS, Orders, initial_orders, random_order_value


def emit_cdc_events(orders: Orders):
    """Every second: one new order (op=c, OrderID 1001+) and one PENDING -> SHIPPED
    update (op=u) to a random order from the initial load."""
    state = initial_orders()
    next_order_id = FIRST_NEW_ORDER_ID
    while True:
        new_value = random_order_value(next_order_id, "PENDING")
        orders.record_order_event(next_order_id, "c", None, new_value)
        next_order_id += 1

        order_id = random.randint(1, NUM_INITIAL_ORDERS)
        before = state[order_id]
        after = dict(before, Status="SHIPPED")
        orders.record_order_event(order_id, "u", before, after)
        state[order_id] = after

        orders.producer.flush()
        time.sleep(1)


if __name__ == "__main__":
    orders = Orders(config.kafka_config(), config.schema_registry_config())
    print("Live CDC datagen started — one create and one update per second", flush=True)
    emit_cdc_events(orders)
