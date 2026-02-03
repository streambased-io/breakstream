from subprocess import Popen, PIPE, DEVNULL
import sys
import os
from runner_utils import run_section

# start shell
p = Popen(['spark-shell --driver-memory 2g'], stdout=PIPE, stdin=PIPE, stderr=DEVNULL, text=True, shell=True)

# run sections
run_section(p,'/tmp/pre_move.scala')
run_section(p,'/tmp/move.scala')
run_section(p,'/tmp/post_move.scala')

#  shut down
p.stdin.close()
os._exit(0)