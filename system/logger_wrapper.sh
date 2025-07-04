 #!/usr/bin/env bash
 #logger_wrapper.sh

log_success() { log_json "SUCCESS" "$1" "" "0" return 0; }
log_info()    { log_json "INFO" "$1" "" "0"; }
log_error()   { log_json "ERROR" "$1" "$2" "$3"; }
log_fatal()   { log_json "FATAL" "$1" "$2" "$3"; exit "$3"; }



