import random
import time
import uuid

import config
import datagen
from telemetry import Telemetry


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
    datagen.generate_truck_positions(route_id, route_start_ts, route_end_ts, telemetry)
    datagen.generate_stops(route_id, route_start_ts, route_end_ts, telemetry)
    telemetry.record_control_event(route_id, route_end_ts, "route_end", "")
    telemetry.record_control_event(route_id, score_ts, "route_summary",
                                   datagen.random_score_data(name, route_start_ts, route_end_ts))
    telemetry.producer.flush()
    print(f"Emitted route route_id={route_id} name={name}", flush=True)


if __name__ == "__main__":
    telemetry = Telemetry(config.kafka_config(), config.schema_registry_config())
    print("Live datagen started — emitting one route every 30s", flush=True)
    while True:
        emit_route(telemetry)
        time.sleep(30)
