#!/bin/bash

#SBATCH --job-name=positron
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=08:00:00
#SBATCH --output=logs/positron-%j.out
#SBATCH --qos=normal
#SBATCH --comment="positron"
#SBATCH --export=ALL,POSITRON_SLURM_EXEC=true

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Set cluster-specific configuration
get_cluster_config() {
    local cluster=$1
    case $cluster in
        alpine)
            PARTITION="amilan"
            MEM="24gb"
            PROXY_HOST="login-ci.rc.colorado.edu"
            LOGIN_HOST="login.rc.colorado.edu"
            HOST_PREFIX="positron-alpine"
            SCRATCH_DIR="/scratch/alpine/${USER}/.positron-server"
            VPN_REQUIRED=false
            ;;
        bodhi)
            PARTITION="positron"
            QOS="positron"
            CPUS=8
            MEM="24G"
            PROXY_HOST="amc-bodhi.ucdenver.pvt"
            LOGIN_HOST="amc-bodhi.ucdenver.pvt"
            HOST_PREFIX="positron-bodhi"
            SCRATCH_DIR=""
            VPN_REQUIRED=true
            ;;
        *)
            echo -e "${YELLOW}Unknown cluster: ${cluster}${NC}"
            echo ""
            echo "Usage: $0 [setup] {alpine|bodhi}"
            echo ""
            echo "Commands:"
            echo "  $0 alpine          Submit a Positron job on Alpine"
            echo "  $0 bodhi           Submit a Positron job on amc-bodhi"
            echo "  $0 setup alpine    One-time setup for Alpine"
            echo "  $0 setup bodhi     One-time setup for amc-bodhi"
            exit 1
            ;;
    esac
}

# One-time setup (run from local machine)
do_setup() {
    local cluster=$1
    get_cluster_config "$cluster"

    echo -e "${CYAN}========================================${NC}"
    echo -e "${GREEN}Positron Remote SSH Setup (${cluster})${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""

    # Prompt for cluster username (may differ from local username)
    read -r -p "Cluster username [${USER}]: " REMOTE_USER
    REMOTE_USER="${REMOTE_USER:-${USER}}"
    echo ""

    # Recalculate scratch dir with remote username
    if [ -n "${SCRATCH_DIR}" ]; then
        SCRATCH_DIR="/scratch/alpine/${REMOTE_USER}/.positron-server"
    fi

    if $VPN_REQUIRED; then
        echo -e "${YELLOW}IMPORTANT: You must be connected to the AMC VPN${NC}"
        echo ""
    fi

    # Step 1: SSH key exchange
    echo -e "${BLUE}Step 1: Copying SSH key to ${cluster}...${NC}"
    echo -e "Running: ${CYAN}ssh-copy-id ${REMOTE_USER}@${LOGIN_HOST}${NC}"
    echo ""
    ssh-copy-id "${REMOTE_USER}@${LOGIN_HOST}"

    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}ssh-copy-id failed. You may need to set up SSH access manually.${NC}"
        echo "See README.md for manual instructions."
        exit 1
    fi
    echo ""

    # Step 2: Positron Server symlink (Alpine only)
    if [ -n "${SCRATCH_DIR}" ]; then
        echo -e "${BLUE}Step 2: Setting up Positron Server on scratch storage...${NC}"
        echo -e "Running remote command on ${cluster} to create symlink..."
        echo ""
        ssh "${REMOTE_USER}@${LOGIN_HOST}" "mkdir -p ${SCRATCH_DIR} && ln -sf ${SCRATCH_DIR} ~/.positron-server && echo 'Symlink created: ~/.positron-server -> ${SCRATCH_DIR}'"

        if [ $? -ne 0 ]; then
            echo -e "${YELLOW}Failed to create scratch symlink. You can do this manually:${NC}"
            echo "  ssh ${REMOTE_USER}@${LOGIN_HOST}"
            echo "  mkdir -p ${SCRATCH_DIR}"
            echo "  ln -sf ${SCRATCH_DIR} ~/.positron-server"
            echo ""
        fi
        echo ""
    fi

    # Step 3: Local Positron settings recommendation
    echo -e "${BLUE}Recommended Positron settings:${NC}"
    echo ""
    echo "Add this to your local Positron settings.json to keep R/Python"
    echo "sessions alive across brief network interruptions:"
    echo ""
    echo -e "${CYAN}  \"kernelSupervisor.shutdownTimeout\": \"never\"${NC}"
    echo ""
    echo -e "${GREEN}Setup complete!${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# Display connection info
show_connection_info() {
    local job_id=$1
    local hostname=$2
    local status=$3
    local time_limit=$(squeue -j ${job_id} -h -o "%l" 2>/dev/null)

    echo -e "${CYAN}========================================${NC}"
    echo -e "${GREEN}Positron Remote SSH Connection Info${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Job ID:${NC} ${job_id}"
    echo -e "${YELLOW}Status:${NC} ${status}"
    echo -e "${YELLOW}Time limit:${NC} ${time_limit}"
    if [ -n "${hostname}" ]; then
        echo -e "${YELLOW}Compute node:${NC} ${hostname}"
    fi
    echo ""

    if $VPN_REQUIRED; then
        echo -e "${YELLOW}IMPORTANT: You must be connected to the AMC VPN${NC}"
        echo ""
    fi

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
    echo -e "${CYAN}Host ${HOST_PREFIX}-${job_id}${NC}"
    echo "    HostName ${hostname}"
    echo "    User ${USER}"
    echo "    ProxyJump ${USER}@${PROXY_HOST}"
    echo "    ForwardAgent yes"
    echo "    ServerAliveInterval 60"
    echo "    ServerAliveCountMax 3"
    echo ""
    echo -e "Then connect to: ${GREEN}${HOST_PREFIX}-${job_id}${NC}"
    echo ""
    echo -e "Check job status: ${CYAN}squeue -u \$USER${NC}"
    echo -e "When done: ${CYAN}scancel ${job_id}${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# --- Main ---

# If running inside SLURM, show connection info and sleep
if [ "${POSITRON_SLURM_EXEC}" = "true" ]; then
    CLUSTER="${POSITRON_CLUSTER:-alpine}"
    get_cluster_config "$CLUSTER"

    mkdir -p logs
    NODE_HOSTNAME=$(hostname)
    show_connection_info "${SLURM_JOB_ID}" "${NODE_HOSTNAME}" "Running"

    while true; do
        sleep 60
    done
fi

# Parse arguments
if [ "$1" = "setup" ]; then
    CLUSTER="${2:-alpine}"
    do_setup "$CLUSTER"
    exit 0
fi

CLUSTER="${1:-alpine}"
get_cluster_config "$CLUSTER"

# Verify we're on the cluster (sbatch must be available)
if ! command -v sbatch &>/dev/null; then
    echo -e "${YELLOW}Error: sbatch not found. This command must be run from the cluster login node.${NC}"
    echo ""
    echo "To submit a job, SSH into the cluster first:"
    echo -e "  ${CYAN}ssh ${USER}@${LOGIN_HOST}${NC}"
    echo ""
    echo "For first-time setup from your local machine:"
    echo -e "  ${CYAN}$0 setup ${CLUSTER}${NC}"
    exit 1
fi

# Verify user has access to the partition
if ! sacctmgr show associations user=$USER format=QOS%80 -n -p 2>/dev/null | grep -q "${QOS:-${PARTITION}}"; then
    echo -e "${YELLOW}Error: You do not have access to the '${QOS:-${PARTITION}}' QOS.${NC}"
    echo ""
    echo "Your current partition associations:"
    sacctmgr show associations user=$USER format=Account,Partition,QOS
    exit 1
fi

# Check for existing job on this partition
EXISTING_JOB=$(squeue -u $USER -p "${PARTITION}" -h -o "%i %T" 2>/dev/null | head -1)
if [ -n "${EXISTING_JOB}" ]; then
    EXISTING_ID=$(echo "${EXISTING_JOB}" | awk '{print $1}')
    EXISTING_STATE=$(echo "${EXISTING_JOB}" | awk '{print $2}')
    echo -e "${YELLOW}You already have a ${EXISTING_STATE} job on the '${PARTITION}' partition (Job ${EXISTING_ID}).${NC}"
    echo -e "This partition only allows 1 job per user."
    echo ""
    echo -e "View log:    ${CYAN}cat logs/positron-${EXISTING_ID}.out${NC}"
    echo -e "Cancel it:   ${CYAN}scancel ${EXISTING_ID}${NC}"
    exit 1
fi

# Submit to SLURM
mkdir -p logs
SBATCH_ARGS=(--parsable --partition="${PARTITION}" --mem="${MEM}")
[ -n "${QOS}" ] && SBATCH_ARGS+=(--qos="${QOS}")
[ -n "${CPUS}" ] && SBATCH_ARGS+=(--cpus-per-task="${CPUS}")
SBATCH_ARGS+=(--export="ALL,POSITRON_SLURM_EXEC=true,POSITRON_CLUSTER=${CLUSTER}")
JOB_ID=$(sbatch "${SBATCH_ARGS[@]}" "$0")
scontrol update JobId=${JOB_ID} JobName="positron-${JOB_ID}" Comment="positron-${JOB_ID}"

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
