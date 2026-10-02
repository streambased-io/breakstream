def kafka_config():
    return {'bootstrap.servers': 'kafka1:9092'}

def schema_registry_config():
    return {'url' : 'http://schema-registry:8081'}