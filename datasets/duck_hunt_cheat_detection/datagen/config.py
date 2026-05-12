import configparser
import os

_config = configparser.ConfigParser()
_config.read(os.path.join(os.path.dirname(os.path.abspath(__file__)), "duck-hunt.properties"))


def kafka_config():
    return dict(_config["kafka"])


def schema_registry_config():
    return dict(_config["schema_registry"])
