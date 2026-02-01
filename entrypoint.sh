#!/bin/sh
set -o errexit

case "$1" in
    sh|bash)
        set -- "$@"
    ;;
    *)
        while true; do echo "Container running.."; sleep 10;done
    ;;
esac

exec "$@"
