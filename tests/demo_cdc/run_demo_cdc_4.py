from subprocess import Popen, PIPE, DEVNULL
import os
from runner_utils import run_section

# start shell
p = Popen(['spark-shell --driver-memory 2g'], stdout=PIPE, stdin=PIPE, stderr=DEVNULL, text=True, shell=True)

# Part 3: Roll hotset to coldset
run_section(p, '/tmp/pre_roll.scala')
run_section(p, '/tmp/roll_to_coldset.scala')
run_section(p, '/tmp/post_roll.scala')

# shut down
p.stdin.close()
os._exit(0)
