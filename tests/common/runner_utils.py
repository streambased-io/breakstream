import time
import os

filtered_lines = """
Spark context Web UI available at http://spark:4042
Spark context available as 'sc' (master = local[*], app id = local-1769981519113).
Spark session available as 'spark'.
Welcome to
____              __
/ __/__  ___ _____/ /__
_\ \/ _ \/ _ `/ __/  '_/
/___/ .__/\_,_/_/ /_/\_\   version 3.5.5
/_/
Using Scala version 2.12.18 (OpenJDK 64-Bit Server VM, Java 17.0.14)
Type in expressions to have them evaluated.
Type :help for more information.
scala> import scala.io.AnsiColor._
import scala.io.AnsiColor._
Spark context available as 'sc' (master = local[*], app id =
import
"""

prompt_timeout = 30  # seconds
dependency_timeout = 300  # seconds

def should_filter(line):
    for filtered_line in filtered_lines.strip().split("\n"):
        if filtered_line in line or line == "" or line == 'scala>' or line == "scala> println(\"section complete\")" or line == "section complete":
            return True
    return False

def stderr_before_spark_ready(p):
    start_time = time.time()
    err_line = ""
    while "artifacts copied" not in err_line and time.time() - start_time < dependency_timeout:
        err_line = p.stderr.readline().strip()
        print(f"{err_line}")

def wait_for_section_complete(p):
    start_time = time.time()
    line = ""
    while line != "section complete" and time.time() - start_time < prompt_timeout:
        line = p.stdout.readline().strip()
        if not should_filter(line):
            print(f"{line}")
    input("Press Enter to continue...")

def run_section(p, section_path):
    try:
        section_code = open(section_path, 'r').read()
        p.stdin.write(section_code)
        p.stdin.flush()
        wait_for_section_complete(p)
    except:
        os._exit(-1)

def wait_for_key(message):
    print(message)
    input("Press Enter to continue...")
