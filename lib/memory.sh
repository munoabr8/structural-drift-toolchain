# 1) Run and capture syscalls (SIP may limit), get PID
sudo dtruss -f -- your_cmd args 2> .evidence/mem.log & PID=$!
wait "$PID"
echo "$PID" > .evidence/pid

# 2) Snapshot regions
mkdir -p .evidence
vmmap "$PID" > .evidence/vmmap.$PID.txt

# 3) Queries
no_rwx_maps_darwin() { local f=$1; [[ -r $f ]] || return 2; ! grep -E '\brwx\b' "$f"; }
no_jit_calls_darwin() { local log=$1; [[ -r $log ]] || return 2; ! grep -E 'PROT_EXEC|mprotect\(.+PROT_EXEC' "$log"; }
heap_under_mb_darwin() {
  local f=$1 max=$2; [[ -r $f ]] || return 2
  # crude total of writable regions in MB
  awk '/writable/ {next} /^[0-9a-fx-]+/ && $2 ~ /[0-9]+K|M/ {
         s=$2; sub(/K/,"*1",s); sub(/M/,"*1024",s); cmd="awk \"BEGIN{print " s " }\""; cmd | getline kb; close(cmd); sum+=kb
       } END{exit !((sum/1024) <= max)}' max="$max" "$f"
}

# 4) Use
pid=$(cat .evidence/pid)
no_jit_calls_darwin .evidence/mem.log && no_rwx_maps_darwin .evidence/vmmap.$pid.txt && heap_under_mb_darwin 
.evidence/vmmap.$pid.txt 256
echo $?

