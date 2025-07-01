#logger_wrappers.sh

 
log_success() { log "SUCCESS" "$1" "" "0" return 0; }
log_info()    { log "INFO" "$1" "" "0"; }
log_error()   { log "ERROR" "$1" "$2" "$3"; }
log_fatal()   { log "FATAL" "$1" "$2" "$3"; exit "$3"; }



