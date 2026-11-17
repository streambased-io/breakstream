import json

from confluent_kafka import Producer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.serialization import MessageField, SerializationContext, StringSerializer


class PumpTelemetryEvent(object):

    def __init__(self, wellId, timestamp, stage_number, treating_pressure_psi, slurry_rate_bpm, proppant_conc_ppa):
        self.wellId = wellId
        self.timestamp = timestamp
        self.stage_number = stage_number
        self.treating_pressure_psi = treating_pressure_psi
        self.slurry_rate_bpm = slurry_rate_bpm
        self.proppant_conc_ppa = proppant_conc_ppa


class FracStageEvent(object):

    def __init__(self, wellId, timestamp, stage_number, state, measured_depth_ft, proppant_placed_lbs):
        self.wellId = wellId
        self.timestamp = timestamp
        self.stage_number = stage_number
        self.state = state
        self.measured_depth_ft = measured_depth_ft
        self.proppant_placed_lbs = proppant_placed_lbs


class ControlEvent(object):

    def __init__(self, wellId, timestamp, event_type, data):
        self.wellId = wellId
        self.timestamp = timestamp
        self.event_type = event_type
        self.data = data


class WorkOrderCdcEvent(object):

    def __init__(self, op, before, after):
        self.op = op
        self.before = before
        self.after = after


class Telemetry(object):

    # ------------------------------------------------------------------ schemas
    # Every record and field carries an Avro "doc" describing its type, units, how it
    # relates to the other topics and what it is used for. These descriptions are what
    # schema-aware tools (Schema Registry UIs, catalogs, MCP servers / LLM agents) read to
    # understand the data, so keep them accurate when changing the generator.

    # High-volume surface sensor readings from the frac pumps - the equivalent
    # of logistics' truck_positions.
    pump_telemetry_topic = "pump_telemetry"
    pump_telemetry_str = json.dumps({
        "name": "PumpTelemetryEvent",
        "type": "record",
        "doc": (
            "One surface sensor reading from the hydraulic fracturing (frac) fleet pumping a well, sampled "
            "every few seconds while a frac job is running (roughly 300-400 readings per job, so this is the "
            "highest-volume topic). Each reading belongs to one well (wellId) and one stage of that well's job "
            "(stage_number). Relationships: join to frac_stages on (wellId, stage_number) to learn how the stage "
            "ended ('completed' or 'screenout'); join to well_control_events on wellId for the job's start/end "
            "times and the human-readable well name (job_summary event). Business use: the live treatment chart "
            "(pressure, rate and proppant over time) that a frac crew watches, and early detection of screenouts - "
            "treating pressure climbing steeply above its normal range for that point in the stage while slurry "
            "rate falls is the warning sign that proppant is bridging and the stage is about to be lost. "
            "The Kafka message key is an opaque sequence string ('key<n>') with no business meaning."
        ),
        "fields": [
            {"name": "wellId", "type": "string",
             "doc": "UUID identifying the well's frac job. Foreign key shared by pump_telemetry, frac_stages and "
                    "well_control_events; one well has exactly one job in this dataset, so wellId identifies both "
                    "the well and its job. Not human-readable - use well_control_events job_summary.data.well_name "
                    "for display."},
            {"name": "timestamp", "type": "long",
             "doc": "Time the reading was taken, in epoch milliseconds (UTC). Lies between the job's job_start and "
                    "job_end events in well_control_events, and between the end of the previous stage and this "
                    "stage's frac_stages.timestamp. Order by this field to rebuild the treatment chart."},
            {"name": "stage_number", "type": "int",
             "doc": "Which stage of the job was being pumped when the reading was taken, 1-based. Stage 1 is at "
                    "the toe (deepest point) of the horizontal lateral; stages are pumped in order back toward the "
                    "heel. Together with wellId it is the foreign key to frac_stages."},
            {"name": "treating_pressure_psi", "type": "double",
             "doc": "Surface treating pressure in pounds per square inch (psi). Typically 6,500-10,000 psi during "
                    "normal pumping, rising gently as proppant concentration ramps up. A steep climb toward "
                    "11,000-12,500 psi late in a stage is the signature of a screenout. Because absolute pressure "
                    "varies from well to well, compare stages using pressure relative to the stage's own early "
                    "(pad) pressure."},
            {"name": "slurry_rate_bpm", "type": "double",
             "doc": "Combined pump rate of fluid plus proppant (slurry) in barrels per minute (bbl/min). Ramps from "
                    "0 to a design rate of about 80-100 bbl/min at the start of each stage and holds there; dips "
                    "to near 0 between stages. A rate falling away while pressure rises indicates the crew cutting "
                    "rate in response to a screenout."},
            {"name": "proppant_conc_ppa", "type": "double",
             "doc": "Proppant (sand) concentration in the slurry in pounds of proppant added per gallon of fluid "
                    "(ppa, lb/gal). Each stage follows the pumping schedule: 0 during the pad (first ~15% of the "
                    "stage), ramping up to a maximum of 2-4 ppa during the slurry phase, then 0 again during the "
                    "flush (last ~15%) that clears the wellbore."}
        ]
    })

    # One event per frac stage as it finishes - the equivalent of logistics' stops.
    frac_stage_topic = "frac_stages"
    frac_stage_str = json.dumps({
        "name": "FracStageEvent",
        "type": "record",
        "doc": (
            "Outcome of one frac stage, emitted once when the stage finishes. A frac job treats a horizontal "
            "well in 8-12 stages, each stimulating one interval of the lateral by pumping fluid and proppant to "
            "create and prop open fractures in the shale. Relationships: one row per (wellId, stage_number); "
            "many pump_telemetry readings share the same (wellId, stage_number); wellId joins to "
            "well_control_events for the job's lifecycle and well name. Business use: completion rate and "
            "screenout analysis per well, pad and fleet (e.g. share of stages screened out, proppant placed vs "
            "design), and labelling historical pump_telemetry curves as normal or screenout to define what a "
            "healthy stage looks like."
        ),
        "fields": [
            {"name": "wellId", "type": "string",
             "doc": "UUID of the well's frac job; foreign key to pump_telemetry.wellId and well_control_events.wellId."},
            {"name": "timestamp", "type": "long",
             "doc": "Time the stage finished, in epoch milliseconds (UTC). For a screenout this is the moment "
                    "pumping had to stop. The stage's pump_telemetry readings all precede this time."},
            {"name": "stage_number", "type": "int",
             "doc": "1-based stage number within the job; stage 1 is at the toe of the lateral and numbers "
                    "increase toward the heel. Unique per wellId. Foreign key to pump_telemetry.stage_number "
                    "(together with wellId)."},
            {"name": "state", "type": "string",
             "doc": "How the stage ended. One of: 'completed' - the full pumping schedule was placed; "
                    "'screenout' - proppant bridged in the fractures or wellbore, pressure ran up to the safety "
                    "limit and pumping stopped early, leaving the stage under-stimulated and usually requiring a "
                    "costly coiled-tubing cleanout before the next stage. Roughly 5-20% of stages screen out."},
            {"name": "measured_depth_ft", "type": "long",
             "doc": "Measured depth (MD) along the wellbore to the centre of the stage, in feet. Laterals start "
                    "(heel) at about 9,000-11,000 ft MD and run 7,000-10,000 ft further to the toe. Higher values "
                    "are further from the wellhead; stage 1 has the largest MD."},
            {"name": "proppant_placed_lbs", "type": "long",
             "doc": "Total proppant (sand) actually placed in the formation during the stage, in pounds. Completed "
                    "stages place their full design of about 300,000-450,000 lb; screenouts place only 35-75% of "
                    "design. Summed per wellId it gives the job's total proppant, also reported in the job_summary."}
        ]
    })

    # job_start / job_end / job_summary - the equivalent of delivery_control_events.
    control_event_topic = "well_control_events"
    control_event_str = json.dumps({
        "name": "WellControlEvent",
        "type": "record",
        "doc": (
            "Lifecycle events for a well's frac job: exactly one 'job_start', one 'job_end' and one 'job_summary' "
            "per wellId. Relationships: wellId joins to pump_telemetry and frac_stages; all of a job's telemetry "
            "and stage events fall between its job_start and job_end timestamps. Business use: find the most "
            "recently completed jobs (latest job_end), measure job duration, and get the human-readable well name, "
            "pad and headline results from the job_summary JSON without aggregating the other topics."
        ),
        "fields": [
            {"name": "wellId", "type": "string",
             "doc": "UUID of the well's frac job; foreign key to pump_telemetry.wellId and frac_stages.wellId."},
            {"name": "timestamp", "type": "long",
             "doc": "Event time in epoch milliseconds (UTC). job_start: pumping began; job_end: the last stage "
                    "finished; job_summary: a few seconds after job_end, once results were tallied."},
            {"name": "event_type", "type": "string",
             "doc": "One of 'job_start', 'job_end' or 'job_summary'. Filter on this before using timestamp or data."},
            {"name": "data", "type": "string",
             "doc": "Empty string for job_start and job_end. For job_summary, a JSON object (query with e.g. "
                    "get_json_object(data, '$.well_name')) with keys: well_name (string, display name such as "
                    "'EAGLE-14H'), pad (string, the well pad the well was drilled from, such as 'NORTH-3'), stages "
                    "(int, stages pumped), completed (int), screenouts (int), completion_rate (int, percent of "
                    "stages completed), proppant_placed_lbs (int, total over all stages) and date (string, ISO-8601 "
                    "UTC job start)."}
        ]
    })

    # Debezium-style CDC envelope (op/before/after) over a tiny 5-key table of
    # well-site maintenance work orders. The topic stays "orders" because that is
    # the topic ISK_CDC_TOPICS enables in streambased-union-roll-docker-compose.part.yaml.
    order_topic = "orders"
    order_key_str = json.dumps({
        "type": "record",
        "name": "OrderKey",
        "namespace": "io.streambased.demo",
        "doc": "Primary key of a maintenance work order in the source system; the Kafka message key of the "
               "orders CDC topic. Streambased uses it to apply each change event in place, so isk.hotset.orders "
               "holds one current-state row per OrderID.",
        "fields": [
            {"name": "OrderID", "type": "int",
             "doc": "Work order number, the primary key of the source work-order table (1-5 in this demo)."}
        ]
    })
    order_value_str = json.dumps({
        "type": "record",
        "name": "Envelope",
        "namespace": "io.streambased.demo",
        "doc": (
            "Debezium-style change-data-capture (CDC) envelope for the well-site maintenance work-order table: "
            "one message per insert, update or delete of a work order, keyed by OrderKey. Read raw from Kafka "
            "it is a change log (the same OrderID repeats as it changes); Streambased recognises the envelope "
            "and materialises it, so isk.hotset.orders exposes the flat WorkOrderValue columns with one row per "
            "OrderID showing its latest state, and deleted orders disappear. Business use: tracking open "
            "maintenance and repair work on frac equipment and its estimated cost."
        ),
        "fields": [
            {"name": "op", "type": "string",
             "doc": "Change operation: 'c' = create (work order raised; before is null), 'u' = update (status "
                    "changed; before and after both set), 'd' = delete (work order removed; after is null)."},
            {
                "name": "before",
                "type": [
                    "null",
                    {
                        "type": "record",
                        "name": "WorkOrderValue",
                        "doc": "One maintenance work order raised against a piece of frac-fleet equipment at a well site.",
                        "fields": [
                            {"name": "OrderID", "type": "int",
                             "doc": "Work order number; same value as the message key OrderKey.OrderID."},
                            {"name": "WellID", "type": "string",
                             "doc": "Display name of the well site the equipment is working on, e.g. 'EAGLE-14H'. "
                                    "Same format as well_control_events job_summary data.well_name (not the "
                                    "wellId UUID used by the telemetry topics)."},
                            {"name": "Equipment", "type": "string",
                             "doc": "Equipment the work is on: one of 'frac pump', 'blender', 'data van', "
                                    "'wireline unit', 'sand king' (proppant storage) or 'iron manifold' "
                                    "(high-pressure pipework)."},
                            {"name": "Status", "type": "string",
                             "doc": "Work order status: 'OPEN' (raised, not yet assigned), 'DISPATCHED' "
                                    "(technician assigned or en route) or 'COMPLETED' (work done)."},
                            {"name": "EstimatedCost", "type": "double",
                             "doc": "Estimated cost of the work in US dollars, roughly 2,000-250,000."}
                        ]
                    }
                ],
                "default": None,
                "doc": "Work order as it was before the change; null for creates ('c')."
            },
            {
                "name": "after",
                "type": ["null", "io.streambased.demo.WorkOrderValue"],
                "default": None,
                "doc": "Work order as it is after the change; null for deletes ('d')."
            }
        ]
    })

    def __init__(self, kafka_config, schema_registry_config, enabled=True):
        self.enabled = enabled
        self._pump_telemetry_seq = 0
        self._control_event_seq = 0
        self._frac_stage_seq = 0
        if not self.enabled:
            return
        self.producer = Producer(kafka_config)
        self.schema_registry_client = SchemaRegistryClient(schema_registry_config)
        self.key_serializer = StringSerializer('utf_8')
        self.pump_telemetry_serializer = AvroSerializer(self.schema_registry_client, self.pump_telemetry_str, Telemetry.pump_telemetry_to_dict)
        self.frac_stage_serializer = AvroSerializer(self.schema_registry_client, self.frac_stage_str, Telemetry.frac_stage_to_dict)
        self.control_event_serializer = AvroSerializer(self.schema_registry_client, self.control_event_str, Telemetry.control_event_to_dict)
        self.order_key_serializer = AvroSerializer(self.schema_registry_client, self.order_key_str, Telemetry.order_key_to_dict)
        self.order_value_serializer = AvroSerializer(self.schema_registry_client, self.order_value_str, Telemetry.order_value_to_dict)

    def _next_key(self, topic, counter_attr):
        seq = getattr(self, counter_attr)
        setattr(self, counter_attr, seq + 1)
        return self.key_serializer(f"key{seq}", SerializationContext(topic, MessageField.KEY))

    def _produce(self, topic, counter_attr, serializer, event):
        key = self._next_key(topic, counter_attr)
        value = serializer(event, SerializationContext(topic, MessageField.VALUE))
        try:
            self.producer.produce(topic, key=key, value=value)
        except BufferError:
            # pump telemetry is bursty - let the local queue drain and retry once
            self.producer.flush()
            self.producer.produce(topic, key=key, value=value)

    @staticmethod
    def pump_telemetry_to_dict(event, ctx):
        return dict(wellId=event.wellId, timestamp=event.timestamp, stage_number=event.stage_number,
                    treating_pressure_psi=event.treating_pressure_psi,
                    slurry_rate_bpm=event.slurry_rate_bpm,
                    proppant_conc_ppa=event.proppant_conc_ppa)

    def record_pump_telemetry_event(self, wellId, timestamp, stage_number, pressure, rate, proppant):
        if not self.enabled:
            return
        event = PumpTelemetryEvent(wellId, timestamp, stage_number, pressure, rate, proppant)
        self._produce(self.pump_telemetry_topic, "_pump_telemetry_seq", self.pump_telemetry_serializer, event)

    @staticmethod
    def frac_stage_to_dict(event, ctx):
        return dict(wellId=event.wellId, timestamp=event.timestamp, stage_number=event.stage_number,
                    state=event.state, measured_depth_ft=event.measured_depth_ft,
                    proppant_placed_lbs=event.proppant_placed_lbs)

    def record_frac_stage_event(self, wellId, timestamp, stage_number, state, measured_depth_ft, proppant_placed_lbs):
        if not self.enabled:
            return
        print(f"Recording frac stage event: wellId={wellId}, stage={stage_number}, state={state}, md={measured_depth_ft}")
        event = FracStageEvent(wellId, timestamp, stage_number, state, measured_depth_ft, proppant_placed_lbs)
        self._produce(self.frac_stage_topic, "_frac_stage_seq", self.frac_stage_serializer, event)

    @staticmethod
    def control_event_to_dict(event, ctx):
        return dict(wellId=event.wellId, timestamp=event.timestamp, event_type=event.event_type, data=event.data)

    def record_control_event(self, wellId, timestamp, event_type, data):
        if not self.enabled:
            return
        print(f"Recording control event: wellId={wellId}, timestamp={timestamp}, event_type={event_type}, data={data}")
        event = ControlEvent(wellId, timestamp, event_type, data)
        self._produce(self.control_event_topic, "_control_event_seq", self.control_event_serializer, event)

    @staticmethod
    def order_key_to_dict(orderId, ctx):
        return dict(OrderID=orderId)

    @staticmethod
    def order_value_to_dict(event, ctx):
        return dict(op=event.op, before=event.before, after=event.after)

    def record_order_event(self, orderId, op, before, after):
        if not self.enabled:
            return
        print(f"Recording work order CDC event: OrderID={orderId}, op={op}")
        event = WorkOrderCdcEvent(op, before, after)
        key_bytes = self.order_key_serializer(orderId, SerializationContext(self.order_topic, MessageField.KEY))
        value_bytes = self.order_value_serializer(event, SerializationContext(self.order_topic, MessageField.VALUE))
        self.producer.produce(self.order_topic, key=key_bytes, value=value_bytes)
