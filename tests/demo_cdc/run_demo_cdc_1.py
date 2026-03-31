from subprocess import Popen, PIPE, DEVNULL
import os
from runner_utils import run_section

# start shell
p = Popen(['spark-shell --driver-memory 2g'], stdout=PIPE, stdin=PIPE, stderr=DEVNULL, text=True, shell=True)

# Part 1: Environment exploration
run_section(p, '/tmp/show_databases.scala')
run_section(p, '/tmp/describe_orders.scala')
run_section(p, '/tmp/count_sets.scala')
run_section(p, '/tmp/fetch_sample_orders.scala')

# shut down
p.stdin.close()
os._exit(0)
