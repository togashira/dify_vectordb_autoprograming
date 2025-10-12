#!/usr/bin/env sh
set -e

API_URL="${NEXT_PUBLIC_API_URL:-http://localhost:8080/console/api}"
SEARCH_DIR="/app/.next"
if [ -d "$SEARCH_DIR" ]; then
  find "$SEARCH_DIR" -type f \( -name "*.js" -o -name "*.txt" -o -name "*.json" \) -print0 \
    | xargs -0 -I{} sh -c \
      'sed -i \
        -e "s#http://127\\.0\\.0\\.1:5001#${API_URL}#g" \
        -e "s#https://127\\.0\\.0\\.1:5001#${API_URL}#g" \
        -e "s#http://localhost:5001#${API_URL}#g" \
        -e "s#https://localhost:5001#${API_URL}#g" \
      "$1"' _ {}
fi

# 元の CMD 実行
exec "$@"
