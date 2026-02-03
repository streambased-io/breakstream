from subprocess import Popen, PIPE, DEVNULL
import sys
import os
from runner_utils import run_section

# start shell
p = Popen(['spark-shell --driver-memory 2g'], stdout=PIPE, stdin=PIPE, stderr=DEVNULL, text=True, shell=True)

# run sections
run_section(p,'/tmp/show_databases.scala')
run_section(p,'/tmp/show_tables_in_hotset.scala')
run_section(p,'/tmp/show_tables_in_coldset.scala')
run_section(p,'/tmp/show_tables_in_merged.scala')
run_section(p,'/tmp/count_coldset_transactions.scala')
run_section(p,'/tmp/count_hotset_transactions.scala')
run_section(p,'/tmp/count_merged_transactions.scala')

#  shut down
p.stdin.close()
os._exit(0)