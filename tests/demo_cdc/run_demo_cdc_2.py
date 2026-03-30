from subprocess import Popen, PIPE, DEVNULL
import os
from runner_utils import run_section

# start shell
p = Popen(['spark-shell --driver-memory 2g'], stdout=PIPE, stdin=PIPE, stderr=DEVNULL, text=True, shell=True)

# Part 2: CDC dedup demonstration
run_section(p, '/tmp/count_distinct_check.scala')
run_section(p, '/tmp/show_shipped_orders.scala')
run_section(p, '/tmp/pre_delete_count.scala')

# shut down
p.stdin.close()
os._exit(0)
