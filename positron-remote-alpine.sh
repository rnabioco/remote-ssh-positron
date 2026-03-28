#!/bin/bash

#SBATCH --job-name=positron-%j
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=08:00:00
#SBATCH --mem=24gb
#SBATCH --output=logs/positron-%j.out
#SBATCH --partition=amilan
#SBATCH --qos=normal
#SBATCH --comment="positron-%j"
#SBATCH --export=ALL,POSITRON_SLURM_EXEC=true

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display connection info
show_connection_info() {
    local job_id=$1
    local hostname=$2
    local status=$3

    echo -e "${CYAN}========================================${NC}"
    echo -e "${GREEN}Positron Remote SSH Connection Info${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Job ID:${NC} ${job_id}"
    echo -e "${YELLOW}Status:${NC} ${status}"
    if [ -n "${hostname}" ]; then
        echo -e "${YELLOW}Compute node:${NC} ${hostname}"
    fi
    echo ""

    if [ -z "${hostname}" ]; then
        echo -e "${BLUE}Once your job is running:${NC}"
        echo ""
        echo "1. Get the compute node hostname:"
        echo -e "   ${CYAN}cat logs/positron-${job_id}.out${NC}"
        echo ""
        hostname="<HOSTNAME-from-step-1>"
    fi

    echo -e "${BLUE}Connect from Positron:${NC}"
    echo ""
    echo "  Cmd/Ctrl+Shift+P → \"Remote-SSH: Connect to Host\""
    echo "  Select \"Add New SSH Host\", paste then save this config:"
    echo ""
    echo -e "${CYAN}Host positron-alpine-${job_id}${NC}"
    echo "    HostName ${hostname}"
    echo "    User ${USER}"
    echo "    ProxyJump ${USER}@login-ci.rc.colorado.edu"
    echo "    ForwardAgent yes"
    echo ""
    echo -e "Then connect to: ${GREEN}positron-alpine-${job_id}${NC}"
    echo ""
    echo -e "Check job status: ${CYAN}squeue -u \$USER${NC}"
    echo -e "When done: ${CYAN}scancel ${job_id}${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# If not running as the actual SLURM job, submit to SLURM and get node assignment
# Use a marker env var to detect if this is the actual SLURM execution
if [ "${POSITRON_SLURM_EXEC}" != "true" ]; then
    mkdir -p logs
    JOB_ID=$(sbatch --parsable "$0")

    echo -e "${CYAN}========================================${NC}"
    echo -e "${GREEN}Positron job submitted${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${YELLOW}Job ID:${NC} ${JOB_ID}"
    echo ""
    echo -e "${BLUE}Waiting for job to start...${NC}"

    # Wait for job to start and get assigned to a node
    HOSTNAME=""
    MAX_WAIT=60
    WAITED=0

    while [ -z "${HOSTNAME}" ] && [ ${WAITED} -lt ${MAX_WAIT} ]; do
        sleep 2
        WAITED=$((WAITED + 2))
        # Get hostname from squeue (only shows when job is running)
        HOSTNAME=$(squeue -j ${JOB_ID} -h -o "%N" 2>/dev/null | grep -v "^$" | grep -v "Priority" | grep -v "Resources")
    done

    if [ -z "${HOSTNAME}" ]; then
        echo -e "${YELLOW}Job still pending after ${MAX_WAIT} seconds.${NC}"
        echo -e "Check status with: ${CYAN}squeue -u \$USER${NC}"
        echo -e "View log when ready: ${CYAN}cat logs/positron-${JOB_ID}.out${NC}"
        echo ""
    else
        echo -e "${GREEN}Job is running on ${HOSTNAME}${NC}"
        echo ""
    fi

    show_connection_info "${JOB_ID}" "${HOSTNAME}" "$([ -n "${HOSTNAME}" ] && echo "Running" || echo "Pending")"
    exit 0
fi

mkdir -p logs

# Get the compute node hostname
NODE_HOSTNAME=$(hostname)

# Show connection info in the log file
show_connection_info "${SLURM_JOB_ID}" "${NODE_HOSTNAME}" "Running"

# Keep the job alive
while true; do
    sleep 60
done
