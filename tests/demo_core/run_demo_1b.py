from subprocess import Popen, PIPE, DEVNULL
import sys
import os
from runner_utils import run_section

# start shell
p = Popen(['spark-shell --driver-memory 2g'], stdout=PIPE, stdin=PIPE, stderr=DEVNULL, text=True, shell=True)

# run sections
run_section(p,'/tmp/describe_transactions_hotset_after.scala')
run_section(p,'/tmp/fetch_transactions_hotset_after.scala')
#  shut down
p.stdin.close()
os._exit(0)