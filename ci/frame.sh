# frame.sh
E_PATH=${E_PATH_OVERRIDE:-/opt/tool/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin}
path_shape_ok "$E_PATH" || { echo "bad shape"; exit 2; }
path_valid "$E_PATH"     || { echo "dirs missing/!x"; exit 1; }
export PATH="$E_PATH"
exec "$@"

