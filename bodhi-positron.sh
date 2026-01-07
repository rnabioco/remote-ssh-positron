#!/bin/bash

#BSUB -J positron
#BSUB -n 4
#BSUB -R "select[mem>20] rusage[mem=20]"
#BSUB -o logs/positron-%J.out
#BSUB -q normal

mkdir -p logs

# Get the compute node hostname
NODE_HOSTNAME=$(hostname)

cat <<END
========================================
Positron Remote SSH Connection Info
========================================

Compute node: ${NODE_HOSTNAME}
Job ID: ${LSB_JOBID}

IMPORTANT: You must be connected to the AMC VPN

CONNECT FROM POSITRON:

1. Add to your local ~/.ssh/config:

Host positron-bodhi-${LSB_JOBID}
    HostName ${NODE_HOSTNAME}
    User ${USER}
    ProxyJump ${USER}@amc-bodhi.ucdenver.pvt
    ForwardAgent yes

2. In Positron: Cmd/Ctrl+Shift+P → "Remote-SSH: Connect to Host"
   Select: positron-bodhi-${LSB_JOBID}

3. Positron will install itself on the remote node automatically

When done: bkill ${LSB_JOBID}
========================================
END

# Keep the job alive
while true; do
    sleep 60
done
