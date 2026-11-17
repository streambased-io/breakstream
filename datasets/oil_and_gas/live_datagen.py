import random
import threading
import time

import config
import datagen
from telemetry import Telemetry

CDC_ORDER_KEYS = 5
CDC_ORDER_STATUSES = ["OPEN", "DISPATCHED", "COMPLETED"]
CDC_EQUIPMENT = ["frac pump", "blender", "data van", "wireline unit", "sand king", "iron manifold"]


def random_work_order(order_id, status):
    return {
        "OrderID": order_id,
        "WellID": datagen.random_well_name(),
        "Equipment": random.choice(CDC_EQUIPMENT),
        "Status": status,
        "EstimatedCost": round(random.uniform(2_000.0, 250_000.0), 2),
    }


def emit_cdc_events(telemetry: Telemetry):
    """One create/update/delete every second across a fixed set of 5 work-order keys."""
    state = {}
    print("CDC datagen started - orders topic, 5 work-order keys, one op/sec", flush=True)
    while True:
        order_id = random.randint(1, CDC_ORDER_KEYS)
        current = state.get(order_id)
        if current is None:
            new_value = random_work_order(order_id, "OPEN")
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


if __name__ == "__main__":
    telemetry = Telemetry(config.kafka_config(), config.schema_registry_config())
    print("Live datagen started - emitting one frac job every 30s", flush=True)
    threading.Thread(target=emit_cdc_events, args=(telemetry,), daemon=True).start()
    while True:
        # Backshift so the job ended just now
        well_id, well_name, _ = datagen.emit_job(telemetry, int(time.time() * 1000))
        print(f"Emitted frac job well_id={well_id} name={well_name}", flush=True)
        time.sleep(30)
