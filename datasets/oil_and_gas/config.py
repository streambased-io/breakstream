def scale_x():
    return 3.0

def scale_y():
    return 2.5

def telemetry_enabled():
    return True

def kafka_config():
    return {'bootstrap.servers': 'kafka1:9092'}

def schema_registry_config():
    return {'url' : 'http://schema-registry:8081'}