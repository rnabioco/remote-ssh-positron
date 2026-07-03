#!/bin/bash
# shellcheck disable=SC2218
# ^ SC2218 misfires on this file: bash defines every function before the "Main"
# section executes, so all calls resolve at runtime (shellcheck even flags
# get_cluster_config, the first function defined). Verified by exercising the
# dispatch paths directly.

#SBATCH --job-name=positron
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --output=logs/positron-%j.out
#SBATCH --qos=normal
#SBATCH --comment="positron"
# Note: --export, --job-name, --partition, etc. are set at submission time (see
# SBATCH_ARGS below) so the selected cluster and its resources propagate to the
# SLURM execution; the directives above are only fallback defaults.

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Set cluster-specific configuration
get_cluster_config() {
    local cluster=$1
    ACCOUNT=""   # optional; overridden by POSITRON_ACCOUNT at submit time
    case $cluster in
        alpine)
            PARTITION="amilan"
            # amilan bills max(cores, mem/3.8GB). 8 cores entitles ~30GB, so
            # 24gb is billed by cores and you get all 8. QOS 'normal' = 24h max.
            CPUS=8
            MEM="24gb"
            TIME="24:00:00"
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
            TIME="08:00:00"
            PROXY_HOST="amc-bodhi.ucdenver.pvt"
            LOGIN_HOST="amc-bodhi.ucdenver.pvt"
            HOST_PREFIX="positron-bodhi"
            SCRATCH_DIR=""
            VPN_REQUIRED=true
            ;;
        *)
            echo -e "${YELLOW}Unknown cluster: ${cluster}${NC}"
            echo ""
            print_usage
            exit 1
            ;;
    esac
}

print_usage() {
    echo "Usage: $0 <command> {alpine|bodhi}"
    echo ""
    echo "Commands:"
    echo "  $0 {alpine|bodhi}          Submit a Positron job (default command)"
    echo "  $0 setup {alpine|bodhi}    One-time setup (run from your LOCAL machine)"
    echo "  $0 status {alpine|bodhi}   Show your Positron job's state and node"
    echo "  $0 connect {alpine|bodhi}  Reprint connection instructions"
    echo "  $0 stop {alpine|bodhi}     Cancel your Positron job"
    echo "  $0 reset {alpine|bodhi}    Wipe the remote Positron server (fixes version drift)"
    echo ""
    echo "Environment variables:"
    echo "  POSITRON_ACCOUNT        SLURM account/allocation to bill (Alpine)"
    echo "  POSITRON_IDLE_TIMEOUT   Minutes with no SSH session before auto-release (0=off)"
}

# Return the login host to reach for a cluster (the ProxyJump/ProxyCommand hop).
# Used by the stable SSH alias so reconnects resolve the current node on the fly.
proxy_login_host() { echo "${PROXY_HOST}"; }

# Write (idempotently) a stable Host alias into the LOCAL ~/.ssh/config so the
# user can reconnect to a fresh job/node without editing anything. The alias
# resolves the currently-running Positron node via squeue on the login node.
write_ssh_alias() {
    local cluster=$1 ru=$2 login=$3
    local cfg="${HOME}/.ssh/config"
    local start="# >>> positron-remote ${cluster} >>>"
    local end="# <<< positron-remote ${cluster} <<<"
    local block
    # In the file, $USER and $(...) must stay LITERAL so they are evaluated on
    # the login node at connect time; %%N escapes ssh's token expansion so the
    # remote squeue receives a literal %N. The single quotes keep the command
    # substitution from running on the local machine.
    block=$(cat <<EOF
${start}
Host positron-${cluster}
    User ${ru}
    ForwardAgent yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ProxyCommand ssh ${ru}@${login} 'nc \$(squeue -u \$USER -n positron-${cluster} -h -t R -o %%N | head -1) 22'
${end}
EOF
)

    mkdir -p "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh" 2>/dev/null
    touch "${cfg}"

    if grep -qF "${start}" "${cfg}"; then
        # Replace the existing block in place.
        awk -v s="${start}" -v e="${end}" '
            $0==s {skip=1}
            !skip {print}
            $0==e {skip=0}
        ' "${cfg}" > "${cfg}.tmp" && mv "${cfg}.tmp" "${cfg}"
        echo -e "${GREEN}Updated${NC} SSH alias 'positron-${cluster}' in ${cfg}"
    else
        echo -e "${GREEN}Added${NC} SSH alias 'positron-${cluster}' to ${cfg}"
    fi
    printf '%s\n' "${block}" >> "${cfg}"
    chmod 600 "${cfg}" 2>/dev/null

    echo ""
    printf '%s\n' "${block}"
    echo ""
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
    if ! ssh-copy-id "${REMOTE_USER}@${LOGIN_HOST}"; then
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
        # shellcheck disable=SC2029  # expanding SCRATCH_DIR client-side is intended
        if ! ssh "${REMOTE_USER}@${LOGIN_HOST}" "mkdir -p ${SCRATCH_DIR} && ln -sf ${SCRATCH_DIR} ~/.positron-server && echo 'Symlink created: ~/.positron-server -> ${SCRATCH_DIR}'"; then
            echo -e "${YELLOW}Failed to create scratch symlink. You can do this manually:${NC}"
            echo "  ssh ${REMOTE_USER}@${LOGIN_HOST}"
            echo "  mkdir -p ${SCRATCH_DIR}"
            echo "  ln -sf ${SCRATCH_DIR} ~/.positron-server"
            echo ""
        fi
        echo ""
    fi

    # Step 3: Stable SSH alias for editless reconnects
    echo -e "${BLUE}Step 3: Writing a stable SSH alias to ~/.ssh/config...${NC}"
    echo -e "Reconnect to any future job by choosing ${GREEN}positron-${cluster}${NC} — no editing."
    echo ""
    write_ssh_alias "${cluster}" "${REMOTE_USER}" "$(proxy_login_host)"

    # Step 4: Local Positron settings recommendation
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

# Locate the user's Positron job on a cluster.
# Prints "JOBID|STATE|NODE|TIMELEFT" (single line) or nothing.
find_positron_job() {
    local cluster=$1
    squeue -u "$USER" -n "positron-${cluster}" -h -o "%i|%T|%N|%L" 2>/dev/null | head -1
}

require_cluster_tools() {
    if ! command -v squeue &>/dev/null; then
        echo -e "${YELLOW}Error: SLURM tools not found. Run this on the cluster login node.${NC}"
        echo -e "  ${CYAN}ssh ${USER}@${LOGIN_HOST}${NC}"
        exit 1
    fi
}

# Show job state and node
do_status() {
    local cluster=$1
    get_cluster_config "$cluster"
    require_cluster_tools

    local line id state node left
    line=$(find_positron_job "$cluster")
    if [ -z "${line}" ]; then
        echo -e "${YELLOW}No Positron job found on ${cluster}.${NC}"
        echo -e "Submit one: ${CYAN}$0 ${cluster}${NC}"
        return 0
    fi
    IFS='|' read -r id state node left <<< "${line}"
    echo -e "${YELLOW}Job ID:${NC} ${id}"
    echo -e "${YELLOW}State:${NC} ${state}"
    echo -e "${YELLOW}Node:${NC} ${node:-<pending>}"
    echo -e "${YELLOW}Time left:${NC} ${left}"
    if [ "${state}" = "RUNNING" ]; then
        echo ""
        echo -e "Connect in Positron to: ${GREEN}positron-${cluster}${NC}"
        echo -e "Full instructions: ${CYAN}$0 connect ${cluster}${NC}"
    fi
}

# Cancel the job
do_stop() {
    local cluster=$1
    get_cluster_config "$cluster"
    require_cluster_tools

    local id ans
    id=$(find_positron_job "$cluster" | cut -d'|' -f1)
    if [ -z "${id}" ]; then
        echo -e "${YELLOW}No Positron job found on ${cluster}.${NC}"
        return 0
    fi
    read -r -p "Cancel Positron job ${id} on ${cluster}? [y/N]: " ans
    case "${ans}" in
        [yY]*) scancel "${id}" && echo -e "${GREEN}Cancelled job ${id}.${NC}" ;;
        *)     echo "Aborted." ;;
    esac
}

# Reprint connection instructions for the running job
do_connect() {
    local cluster=$1
    get_cluster_config "$cluster"
    require_cluster_tools

    local line id state node
    line=$(find_positron_job "$cluster")
    if [ -z "${line}" ]; then
        echo -e "${YELLOW}No Positron job found on ${cluster}.${NC}"
        echo -e "Submit one: ${CYAN}$0 ${cluster}${NC}"
        return 0
    fi
    IFS='|' read -r id state node _ <<< "${line}"
    show_connection_info "${id}" "${node}" "${state}"
}

# Wipe the remote Positron server install (fixes client/server version drift)
do_reset() {
    local cluster=$1
    get_cluster_config "$cluster"
    require_cluster_tools

    # Guard: never delete the server out from under a running session.
    local running
    running=$(squeue -u "$USER" -n "positron-${cluster}" -h -t R -o "%i" 2>/dev/null | head -1)
    if [ -n "${running}" ]; then
        echo -e "${YELLOW}A Positron job (${running}) is running on ${cluster}.${NC}"
        echo -e "Stop it first: ${CYAN}$0 stop ${cluster}${NC}"
        exit 1
    fi

    local dir
    if [ "${cluster}" = "alpine" ]; then
        dir="/scratch/alpine/${USER}/.positron-server"
    else
        dir="${HOME}/.positron-server"
    fi

    echo -e "This will delete the Positron server install at:"
    echo -e "  ${CYAN}${dir}${NC}"
    local ans
    read -r -p "Continue? [y/N]: " ans
    case "${ans}" in
        [yY]*) ;;
        *) echo "Aborted."; return 0 ;;
    esac
    rm -rf "${dir:?}"/* 2>/dev/null
    echo -e "${GREEN}Cleared. Positron will reinstall the server on your next connect.${NC}"
}

# Display connection info
show_connection_info() {
    local job_id=$1
    local hostname=$2
    local status=$3
    local time_limit
    time_limit=$(squeue -j "${job_id}" -h -o "%l" 2>/dev/null)

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

    # Preferred path: the stable alias written by 'setup'.
    echo -e "${BLUE}Connect from Positron (recommended):${NC}"
    echo ""
    echo "  Cmd/Ctrl+Shift+P → \"Remote-SSH: Connect to Host\""
    echo -e "  Choose: ${GREEN}${HOST_PREFIX}${NC}"
    echo ""
    echo -e "  (This alias is added by ${CYAN}$0 setup ${HOST_PREFIX#positron-}${NC} and"
    echo "   auto-resolves the current node — no editing between jobs.)"
    echo ""

    # Fallback: explicit job-specific block for users who skipped setup.
    echo -e "${BLUE}Fallback — add this to your LOCAL ~/.ssh/config instead:${NC}"
    echo ""
    if [ -z "${hostname}" ]; then
        echo "  (Job not running yet — get the node with: cat logs/positron-${job_id}.out)"
        hostname="<HOSTNAME-when-running>"
    fi
    echo -e "${CYAN}Host ${HOST_PREFIX}-${job_id}${NC}"
    echo "    HostName ${hostname}"
    echo "    User ${USER}"
    echo "    ProxyJump ${USER}@${PROXY_HOST}"
    echo "    ForwardAgent yes"
    echo "    ServerAliveInterval 60"
    echo "    ServerAliveCountMax 3"
    echo ""

    # Runtime check: confirm the server runs inside the SLURM allocation.
    echo -e "${BLUE}Verify resources are enforced${NC} (in a Positron terminal after connecting):"
    echo -e "  ${CYAN}cat /proc/self/cgroup${NC}   # expect a path containing job_${job_id}"
    echo "  If it does NOT reference your job, the session was not adopted into the"
    echo "  allocation (pam_slurm_adopt) and runs outside your CPU/memory limits."
    echo ""

    echo -e "Check status: ${CYAN}$0 status ${HOST_PREFIX#positron-}${NC}"
    echo -e "When done:    ${CYAN}$0 stop ${HOST_PREFIX#positron-}${NC}  (or: scancel ${job_id})"
    echo -e "${CYAN}========================================${NC}"
}

# Is there an active inbound SSH session on this compute node?
# shellcheck disable=SC2329  # invoked from the idle-timeout loop in the SLURM branch
session_active() {
    if command -v ss &>/dev/null; then
        ss -tnH state established '( sport = :22 )' 2>/dev/null | grep -q . && return 0
        return 1
    fi
    # Fallback: any interactive login for the user.
    who 2>/dev/null | grep -q . && return 0
    return 1
}

# --- Main ---

# If running inside SLURM, show connection info and hold the allocation.
if [ "${POSITRON_SLURM_EXEC}" = "true" ]; then
    CLUSTER="${POSITRON_CLUSTER:-alpine}"
    get_cluster_config "$CLUSTER"

    mkdir -p logs
    NODE_HOSTNAME=$(hostname)
    show_connection_info "${SLURM_JOB_ID}" "${NODE_HOSTNAME}" "Running"

    # Graceful teardown: on scancel/walltime SLURM sends SIGTERM before SIGKILL.
    # Stop the server cleanly so the next connect doesn't hit a stale lock.
    # shellcheck disable=SC2329  # invoked via the trap below
    cleanup() {
        echo ""
        echo "[positron] Allocation ending (job ${SLURM_JOB_ID}); stopping positron-server..."
        pkill -u "$USER" -f positron-server 2>/dev/null
        exit 0
    }
    trap cleanup SIGTERM SIGINT

    IDLE_LIMIT="${POSITRON_IDLE_TIMEOUT:-0}"   # minutes; 0 disables idle teardown
    if ! [ "${IDLE_LIMIT}" -eq "${IDLE_LIMIT}" ] 2>/dev/null; then IDLE_LIMIT=0; fi

    if [ "${IDLE_LIMIT}" -le 0 ]; then
        # Hold until scancel/walltime. Background sleep + wait so the trap fires.
        sleep infinity &
        wait $!
    else
        echo "[positron] Idle teardown enabled: releasing after ${IDLE_LIMIT} idle minute(s)."
        idle=0
        while true; do
            sleep 60 &
            wait $!
            if session_active; then
                idle=0
            else
                idle=$((idle + 1))
                if [ "${idle}" -ge "${IDLE_LIMIT}" ]; then
                    echo "[positron] No active session for ${IDLE_LIMIT} min; releasing allocation."
                    scancel "${SLURM_JOB_ID}"
                    exit 0
                fi
            fi
        done
    fi
    exit 0
fi

# Parse subcommand (bare cluster arg = submit; keeps backward compatibility).
case "$1" in
    setup)   do_setup   "${2:-alpine}"; exit 0 ;;
    reset)   do_reset   "${2:-alpine}"; exit 0 ;;
    status)  do_status  "${2:-alpine}"; exit 0 ;;
    stop)    do_stop    "${2:-alpine}"; exit 0 ;;
    connect) do_connect "${2:-alpine}"; exit 0 ;;
    -h|--help|help) print_usage; exit 0 ;;
esac

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

# Verify user has access to the QOS (only for clusters that gate on a
# dedicated QOS, e.g. bodhi's 'positron'). Alpine's 'amilan' is a general
# partition with no special QOS, so there's nothing to pre-check there.
if [ -n "${QOS}" ]; then
    if ! sacctmgr show associations user="$USER" format=QOS%80 -n -p 2>/dev/null | tr ',|' '\n' | grep -qx "${QOS}"; then
        echo -e "${YELLOW}Error: You do not have access to the '${QOS}' QOS.${NC}"
        echo ""
        echo "Your current partition associations:"
        sacctmgr show associations user="$USER" format=Account,Partition,QOS
        exit 1
    fi
fi

# Check for an existing Positron job on this cluster (one per cluster).
EXISTING=$(find_positron_job "${CLUSTER}")
if [ -n "${EXISTING}" ]; then
    EXISTING_ID=$(echo "${EXISTING}" | cut -d'|' -f1)
    EXISTING_STATE=$(echo "${EXISTING}" | cut -d'|' -f2)
    echo -e "${YELLOW}You already have a ${EXISTING_STATE} Positron job on ${CLUSTER} (Job ${EXISTING_ID}).${NC}"
    echo -e "Only one Positron job per cluster is supported."
    echo ""
    echo -e "View it:   ${CYAN}$0 connect ${CLUSTER}${NC}"
    echo -e "Cancel it: ${CYAN}$0 stop ${CLUSTER}${NC}"
    exit 1
fi

# Resolve optional account (env override wins over per-cluster default).
ACCOUNT="${POSITRON_ACCOUNT:-${ACCOUNT}}"
if [ "${CLUSTER}" = "alpine" ] && [ -z "${ACCOUNT}" ]; then
    echo -e "${YELLOW}Note:${NC} no --account set; Alpine will bill your default allocation."
    echo -e "  Choose one with: ${CYAN}POSITRON_ACCOUNT=<alloc> $0 ${CLUSTER}${NC}"
    echo -e "  List allocations: ${CYAN}sacctmgr show assoc user=\$USER format=account -n -p${NC}  or  ${CYAN}curc-quota${NC}"
    echo ""
fi

# Submit to SLURM
mkdir -p logs
SBATCH_ARGS=(--parsable --no-requeue --job-name="positron-${CLUSTER}" --partition="${PARTITION}" --mem="${MEM}")
[ -n "${ACCOUNT}" ] && SBATCH_ARGS+=(--account="${ACCOUNT}")
[ -n "${QOS}" ]     && SBATCH_ARGS+=(--qos="${QOS}")
[ -n "${CPUS}" ]    && SBATCH_ARGS+=(--cpus-per-task="${CPUS}")
[ -n "${TIME}" ]    && SBATCH_ARGS+=(--time="${TIME}")
SBATCH_ARGS+=(--export="ALL,POSITRON_SLURM_EXEC=true,POSITRON_CLUSTER=${CLUSTER},POSITRON_IDLE_TIMEOUT=${POSITRON_IDLE_TIMEOUT:-0}")
JOB_ID=$(sbatch "${SBATCH_ARGS[@]}" "$0") || {
    echo -e "${YELLOW}Error: sbatch failed to submit the job.${NC}"
    exit 1
}

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
    HOSTNAME=$(squeue -j "${JOB_ID}" -h -o "%N" 2>/dev/null)
done

if [ -z "${HOSTNAME}" ]; then
    echo -e "${YELLOW}Job still pending after ${MAX_WAIT} seconds.${NC}"
    echo -e "Check status with: ${CYAN}$0 status ${CLUSTER}${NC}"
    echo -e "View log when ready: ${CYAN}cat logs/positron-${JOB_ID}.out${NC}"
    echo ""
else
    echo -e "${GREEN}Job is running on ${HOSTNAME}${NC}"
    echo ""
fi

show_connection_info "${JOB_ID}" "${HOSTNAME}" "$([ -n "${HOSTNAME}" ] && echo "Running" || echo "Pending")"
exit 0
