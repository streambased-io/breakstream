import random
import threading
import time
import uuid

import config
import datagen
from telemetry import Telemetry

CDC_ORDER_KEYS = 5
CDC_ORDER_STATUSES = ["PENDING", "SHIPPED", "DELIVERED"]


def random_order_value(order_id, status):
    return {
        "OrderID": order_id,
        "CustomerID": random.randint(1000, 9999),
        "Status": status,
        "Amount": round(random.uniform(10.0, 1000.0), 2),
    }


def emit_cdc_events(telemetry: Telemetry):
    """One create/update/delete every second across a fixed set of 5 order keys."""
    state = {}
    print("CDC datagen started — orders topic, 5 keys, one op/sec", flush=True)
    while True:
        order_id = random.randint(1, CDC_ORDER_KEYS)
        current = state.get(order_id)
        if current is None:
            new_value = random_order_value(order_id, "PENDING")
            telemetry.record_order_event(order_id, "c", None, new_value)
            state[order_id] = new_value
        elif random.random() < 0.5:
            new_value = dict(current)
            new_value["Status"] = random.choice([s for s in CDC_ORDER_STATUSES if s != current["Status"]])
            telemetry.record_order_event(order_id, "u", current, new_value)
            state[order_id] = new_value
        else:
            telemetry.record_order_event(order_id, "d", current, None)
            state[order_id] = None
        telemetry.producer.flush()
        time.sleep(1)


def emit_route(telemetry: Telemetry):
    route_id = str(uuid.uuid4())
    name = datagen.random_name()

    duration_ms = int((datagen.ROUTE_DURATION_SECS + random.uniform(0, datagen.ROUTE_DURATION_JITTER_SECS)) * 1000)
    score_delay_ms = int((datagen.SCORE_DELAY_SECS + random.uniform(0, datagen.SCORE_DELAY_JITTER_SECS)) * 1000)

    # Backshift so the route ended just now
    route_end_ts = int(time.time() * 1000)
    route_start_ts = route_end_ts - duration_ms
    score_ts = route_end_ts + score_delay_ms

    telemetry.record_control_event(route_id, route_start_ts, "route_start", "")
    truck_path = datagen.generate_truck_positions(route_id, route_start_ts, route_end_ts, telemetry)
    datagen.generate_stops(route_id, route_start_ts, route_end_ts, telemetry, truck_path)
    telemetry.record_control_event(route_id, route_end_ts, "route_end", "")
    telemetry.record_control_event(route_id, score_ts, "route_summary",
                                   datagen.random_score_data(name, route_start_ts, route_end_ts))
    telemetry.producer.flush()
    print(f"Emitted route route_id={route_id} name={name}", flush=True)


if __name__ == "__main__":
    telemetry = Telemetry(config.kafka_config(), config.schema_registry_config())
    print("Live datagen started — emitting one route every 30s", flush=True)
    threading.Thread(target=emit_cdc_events, args=(telemetry,), daemon=True).start()
    while True:
        emit_route(telemetry)
        time.sleep(30)
