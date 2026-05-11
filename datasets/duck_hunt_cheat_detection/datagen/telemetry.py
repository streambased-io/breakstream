from confluent_kafka import Producer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.serialization import MessageField, SerializationContext


class GunPositionEvent(object):
    def __init__(self, sessionId, timestamp, x, y):
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.x = x
        self.y = y


class ControlEvent(object):
    def __init__(self, sessionId, timestamp, event_type, data):
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.event_type = event_type
        self.data = data


class ShotEvent(object):
    def __init__(self, sessionId, timestamp, state, x, y, duck_positions):
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.state = state
        self.x = x
        self.y = y
        self.duck_positions = duck_positions


class DuckSpawnEvent(object):
    def __init__(self, sessionId, timestamp, duck_id, x, y, direction):
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.duck_id = duck_id
        self.x = x
        self.y = y
        self.direction = direction


class Telemetry(object):

    gun_position_topic = "gun_positions"
    gun_position_str = """
    {
        "name": "GunPositionEvent",
        "type": "record",
        "fields": [
            {"name": "sessionId", "type": "string"},
            {"name": "timestamp", "type": "long"},
            {"name": "x", "type": "long"},
            {"name": "y", "type": "long"}
        ]
    }
    """

    shot_topic = "shots"
    shot_str = """
    {
        "name": "ShotEvent",
        "type": "record",
        "fields": [
            {"name": "sessionId", "type": "string"},
            {"name": "state", "type": "string"},
            {"name": "timestamp", "type": "long"},
            {"name": "x", "type": "long"},
            {"name": "y", "type": "long"},
            {
                "name": "duck_positions",
                "type": {
                    "type": "array",
                    "items": {
                        "type": "record",
                        "name": "DuckPosition",
                        "fields": [
                            {"name": "x", "type": "long"},
                            {"name": "y", "type": "long"}
                        ]
                    }
                },
                "default": []
            }
        ]
    }
    """

    control_event_topic = "control_events"
    control_event_str = """
    {
        "name": "ControlEvent",
        "type": "record",
        "fields": [
            {"name": "sessionId", "type": "string"},
            {"name": "timestamp", "type": "long"},
            {"name": "event_type", "type": "string"},
            {"name": "data", "type": "string"}
        ]
    }
    """

    duck_spawn_topic = "duck_spawns"
    duck_spawn_str = """
    {
        "name": "DuckSpawnEvent",
        "type": "record",
        "fields": [
            {"name": "sessionId", "type": "string"},
            {"name": "timestamp", "type": "long"},
            {"name": "duck_id", "type": "string"},
            {"name": "x", "type": "long"},
            {"name": "y", "type": "long"},
            {"name": "direction", "type": "int"}
        ]
    }
    """

    def __init__(self, kafka_config, schema_registry_config):
        self._last_x = None
        self._last_y = None
        self.producer = Producer(kafka_config)
        self.schema_registry_client = SchemaRegistryClient(schema_registry_config)
        self.gun_position_serializer = AvroSerializer(
            self.schema_registry_client, self.gun_position_str, Telemetry.gun_position_to_dict
        )
        self.shot_serializer = AvroSerializer(
            self.schema_registry_client, self.shot_str, Telemetry.shot_to_dict
        )
        self.control_event_serializer = AvroSerializer(
            self.schema_registry_client, self.control_event_str, Telemetry.control_event_to_dict
        )
        self.duck_spawn_serializer = AvroSerializer(
            self.schema_registry_client, self.duck_spawn_str, Telemetry.duck_spawn_to_dict
        )

    @staticmethod
    def gun_position_to_dict(event, ctx):
        return dict(sessionId=event.sessionId, timestamp=event.timestamp, x=event.x, y=event.y)

    def record_gun_position_event(self, sessionId, timestamp, x, y):
        if x == self._last_x and y == self._last_y:
            return
        self._last_x = x
        self._last_y = y
        event = GunPositionEvent(sessionId, timestamp, x, y)
        self.producer.produce(
            self.gun_position_topic,
            value=self.gun_position_serializer(event, SerializationContext(self.gun_position_topic, MessageField.VALUE))
        )

    @staticmethod
    def control_event_to_dict(event, ctx):
        return dict(sessionId=event.sessionId, timestamp=event.timestamp, event_type=event.event_type, data=event.data)

    def record_control_event(self, sessionId, timestamp, event_type, data):
        event = ControlEvent(sessionId, timestamp, event_type, data)
        self.producer.produce(
            self.control_event_topic,
            value=self.control_event_serializer(event, SerializationContext(self.control_event_topic, MessageField.VALUE))
        )

    @staticmethod
    def shot_to_dict(event, ctx):
        return dict(
            sessionId=event.sessionId, timestamp=event.timestamp, state=event.state,
            x=event.x, y=event.y, duck_positions=event.duck_positions
        )

    def record_shot_event(self, sessionId, timestamp, state, x, y, duck_positions):
        event = ShotEvent(sessionId, timestamp, state, x, y, duck_positions)
        self.producer.produce(
            self.shot_topic,
            value=self.shot_serializer(event, SerializationContext(self.shot_topic, MessageField.VALUE))
        )

    @staticmethod
    def duck_spawn_to_dict(event, ctx):
        return dict(
            sessionId=event.sessionId, timestamp=event.timestamp, duck_id=event.duck_id,
            x=event.x, y=event.y, direction=event.direction
        )

    def record_duck_spawn_event(self, sessionId, timestamp, duck_id, x, y, direction):
        event = DuckSpawnEvent(sessionId, timestamp, duck_id, x, y, direction)
        self.producer.produce(
            self.duck_spawn_topic,
            value=self.duck_spawn_serializer(event, SerializationContext(self.duck_spawn_topic, MessageField.VALUE))
        )
