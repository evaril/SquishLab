#!/bin/bash
# inputleap-ssh-client.sh : SSH-tunneled Input Leap client launcher

# --- Configuration ---
SSH_USER="evm"             # Username on SquishLab for SSH login
SSH_HOST="192.168.72.54"                 # SSH host (SquishLab); ensure in ~/.ssh/known_hosts
SSH_PORT=7717                        # SSH daemon port on SquishLab
IDENTITY="$HOME/.ssh/SU_MBRSA"   # Private key for this tunnel (permission 600)
PORT=11100                          # Port for Input Leap (local and remote)
LOGFILE="$HOME/inputleap-client.log" # Log file for client script
CLIENT_NAME="SquishAgent"           # Client screen name (should match server config)
INACTIVITY_TIMEOUT=600             # 10 minutes
MAX_FAILS=10                       # Max reconnect attempts

mkdir -p "$(dirname "$LOGFILE")"
touch "$LOGFILE"

log() {
    local level="$1"; shift
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*" | tee -a "$LOGFILE"
}

log "INFO" "Starting InputLeap client on $CLIENT_NAME, connecting to $SSH_HOST via SSH..."

# Start SSH tunnel with retries
fail_count=0
SSH_OPTS="-p $SSH_PORT -i $IDENTITY -o BatchMode=yes -o ExitOnForwardFailure=yes -o ConnectTimeout=5"
SSH_TUNNEL_PID=""
while [ $fail_count -lt $MAX_FAILS ]; do
    log "INFO" "Opening SSH tunnel (attempt $((fail_count+1))/$MAX_FAILS)..."
    ssh $SSH_OPTS -N -L $PORT:127.0.0.1:$PORT "$SSH_USER@$SSH_HOST" &
    SSH_TUNNEL_PID=$!
    sleep 5  # wait to see if SSH succeeds
    if kill -0 $SSH_TUNNEL_PID 2>/dev/null; then
        log "INFO" "SSH tunnel established (PID $SSH_TUNNEL_PID)."
        break
    else
        wait $SSH_TUNNEL_PID 2>/dev/null  # clean up if it exited
        fail_count=$((fail_count+1))
        log "ERROR" "SSH tunnel connection failed (attempt $fail_count)."
        if [ $fail_count -lt $MAX_FAILS ]; then
            sleep 10  # wait before retrying
        fi
    fi
done

if [ $fail_count -ge $MAX_FAILS ]; then
    log "ERROR" "Could not establish SSH tunnel after $MAX_FAILS attempts. Exiting."
    exit 1
fi

# Launch Input Leap client and monitor connection
fail_count=0
last_connect_time=$(date +%s)
CLIENT_PID=""
trap "log 'INFO' 'Stopping client and closing SSH.'; [ -n \"$CLIENT_PID\" ] && kill $CLIENT_PID 2>/dev/null; [ -n \"$SSH_TUNNEL_PID\" ] && kill $SSH_TUNNEL_PID 2>/dev/null; exit 0" EXIT INT TERM

while [ $fail_count -lt $MAX_FAILS ]; do
    log "INFO" "Starting InputLeap client process..."
    input-leapc --name "$CLIENT_NAME" --disable-crypto -f --no-restart --no-tray 127.0.0.1:$PORT >> "$LOGFILE" 2>&1 &
    CLIENT_PID=$!
    wait $CLIENT_PID   # wait for client to exit
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
        log "INFO" "InputLeap client process exited normally (code 0)."
    else
        log "WARN" "InputLeap client disconnected or crashed (exit code $EXIT_CODE)."
    fi
    # Check if should reconnect
    if [ $EXIT_CODE -ne 0 ]; then
        fail_count=$((fail_count+1))
        log "INFO" "Reconnection attempt $fail_count/$MAX_FAILS will start in 5s..."
        sleep 5
        # If too many failures, break out
        if [ $fail_count -ge $MAX_FAILS ]; then
            log "ERROR" "Reached $fail_count failed client attempts. Giving up."
            break
        fi
        # Continue loop to try reconnect
        continue
    else
        # Exit code 0 (client closed by user or stopped), stop looping
        break
    fi
done

# If still running, ensure tunnel is closed
if [ -n "$SSH_TUNNEL_PID" ] && kill -0 $SSH_TUNNEL_PID 2>/dev/null; then
    kill $SSH_TUNNEL_PID
fi
log "INFO" "Client script exiting."
exit 0
