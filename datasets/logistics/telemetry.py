from confluent_kafka import Producer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.serialization import MessageField, SerializationContext, StringSerializer

class TruckPositionEvent(object):

    def __init__(self, routeId, timestamp, x, y):
        self.routeId = routeId
        self.timestamp = timestamp
        self.x = x
        self.y = y

class ControlEvent(object):

    def __init__(self, routeId, timestamp, event_type, data):
        self.routeId = routeId
        self.timestamp = timestamp
        self.event_type = event_type
        self.data = data

class StopEvent(object):

    def __init__(self, routeId, timestamp, state, x, y):
        self.routeId = routeId
        self.timestamp = timestamp
        self.state = state
        self.x = x
        self.y = y

class Telemetry(object):

    truck_position_topic = "truck_positions"
    truck_position_str = """
    {
        "name": "TruckPositionEvent",
        "type": "record",
        "fields": [
            {
                "name": "routeId",
                "type": "string"
            },
            {
                "name": "timestamp",
                "type": "long"
            },
            {
                "name": "x",
                "type": "long"
            },
            {
                "name": "y",
                "type": "long"
            }
        ]
    }
    """

    stop_topic = "stops"
    stop_str = """
    {
        "name": "StopEvent",
        "type": "record",
        "fields": [
            {
                "name": "routeId",
                "type": "string"
            },
            {
                "name": "state",
                "type": "string"
            },
            {
                "name": "timestamp",
                "type": "long"
            },
            {
                "name": "x",
                "type": "long"
            },
            {
                "name": "y",
                "type": "long"
            }
        ]
    }
    """

    control_event_topic = "delivery_control_events"
    control_event_str = """
    {
        "name": "ControlEvent",
        "type": "record",
        "fields": [
            {
                "name": "routeId",
                "type": "string"
            },
            {
                "name": "timestamp",
                "type": "long"
            },
            {
                "name": "event_type",
                "type": "string"
            },
            {
                "name": "data",
                "type": "string"
            }
        ]
    }
    """

    def __init__(self, kafka_config, schema_registry_config, enabled=True):
        self.enabled = enabled
        self._last_x = None
        self._last_y = None
        if not self.enabled:
            return
        self.producer = Producer(kafka_config)
        self.schema_registry_client = SchemaRegistryClient(schema_registry_config)
        self.truck_position_serializer = AvroSerializer(self.schema_registry_client, self.truck_position_str, Telemetry.truck_position_to_dict)
        self.stop_serializer = AvroSerializer(self.schema_registry_client, self.stop_str, Telemetry.stop_to_dict)
        self.control_event_serializer = AvroSerializer(self.schema_registry_client, self.control_event_str, Telemetry.control_event_to_dict)

    @staticmethod
    def truck_position_to_dict(event, ctx):
        return dict(routeId=event.routeId, timestamp=event.timestamp, x=event.x, y=event.y)

    def record_truck_position_event(self, routeId, timestamp, x, y):
        if not self.enabled:
            return
        if x == self._last_x and y == self._last_y:
            return
        self._last_x = x
        self._last_y = y
        print(f"Recording truck position event: routeId={routeId}, timestamp={timestamp}, x={x}, y={y}")
        event = TruckPositionEvent(routeId, timestamp, x, y)
        self.producer.produce(self.truck_position_topic, value=self.truck_position_serializer(event, SerializationContext(self.truck_position_topic, MessageField.VALUE)))

    @staticmethod
    def control_event_to_dict(event, ctx):
        return dict(routeId=event.routeId, timestamp=event.timestamp, event_type=event.event_type, data=event.data)

    def record_control_event(self, routeId, timestamp, event_type, data):
        if not self.enabled:
            return
        print(f"Recording control event: routeId={routeId}, timestamp={timestamp}, event_type={event_type}, data={data}")
        event = ControlEvent(routeId, timestamp, event_type, data)
        self.producer.produce(self.control_event_topic, value=self.control_event_serializer(event, SerializationContext(self.control_event_topic, MessageField.VALUE)))

    @staticmethod
    def stop_to_dict(event, ctx):
        return dict(routeId=event.routeId, timestamp=event.timestamp, state=event.state, x=event.x, y=event.y)

    def record_stop_event(self, routeId, timestamp, state, x, y):
        if not self.enabled:
            return
        print(f"Recording stop event: routeId={routeId}, timestamp={timestamp}, state={state}, x={x}, y={y}")
        event = StopEvent(routeId, timestamp, state, x, y)
        self.producer.produce(self.stop_topic, value=self.stop_serializer(event, SerializationContext(self.stop_topic, MessageField.VALUE)))
