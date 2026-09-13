#!/bin/bash
# Fast socket bridge - skips Python startup (saves ~0.4s per call)
SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/omargram/omargram.sock"
PLUGIN_DIR="$(dirname "$(readlink -f "$0")")"
PY="${OMARGRAM_PYTHON:-$(command -v python3)}"
[ -x "$PY" ] || PY=/usr/bin/python3

jesc() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\t'/\\t}"; s="${s//$'\r'/\\r}"; printf '%s' "$s"; }

# Check if daemon is active and responsive on the socket
is_daemon_alive() {
  [ -S "$SOCK" ] || return 1
  echo '{"action":"status"}' | socat -t 2 - UNIX-CONNECT:"$SOCK" >/dev/null 2>&1
}

if ! is_daemon_alive; then
  _alive=0
  for _try in 1 2 3; do
    is_daemon_alive && { _alive=1; break; }
    sleep 0.2
  done
  if [ "$_alive" -eq 0 ]; then
  RUN_DIR="$(dirname "$SOCK")"
  mkdir -p "$RUN_DIR"
  exec 9>"$RUN_DIR/omargram.lock"
  if ! flock -n 9; then
    for i in $(seq 1 25); do
      is_daemon_alive && break
      sleep 0.2
    done
  else
    if pkill -f "python3.*omargram_daemon\.py" 2>/dev/null; then
      for _w in $(seq 1 20); do
        pkill -0 -f "python3.*omargram_daemon\.py" 2>/dev/null || break
        sleep 0.1
      done
    fi
    rm -f "$SOCK" 2>/dev/null
    nohup "$PY" "$PLUGIN_DIR/omargram_daemon.py" > "$RUN_DIR/daemon.log" 2>&1 &
    for i in $(seq 1 25); do
      is_daemon_alive && break
      sleep 0.2
    done
  fi
  if ! is_daemon_alive; then
    echo "{\"success\":false,\"error\":\"daemon failed to start — see $RUN_DIR/daemon.log\"}"
    omarchy-notification-send -u critical -g "󰅙" "OmarGram" "Daemon failed to start — check $RUN_DIR/daemon.log" 2>/dev/null
    exit 1
  fi
  fi
fi

action="$1"; shift

# Fallback to Python ctl for local operations
case "$action" in
  search_files|find|search|list_files|browse|browse_files|paste_image|pick_file)
    exec "$PY" "$PLUGIN_DIR/omargram_ctl.py" "$action" "$@"
    ;;
esac

# Build JSON for daemon commands
json=""
case "$action" in
  dialogs|chats)
    limit="${1:-40}"
    [[ "$limit" =~ ^-?[0-9]+$ ]] || { echo '{"success":false,"error":"limit must be numeric"}'; exit 1; }
    json="{\"action\":\"dialogs\",\"limit\":$limit}"
    ;;
  messages)
    chat_id="$1"; limit="${2:-50}"; topic_id="$3"
    [[ "$limit" =~ ^-?[0-9]+$ ]] || { echo '{"success":false,"error":"limit must be numeric"}'; exit 1; }
    if [ -n "$topic_id" ]; then
      json="{\"action\":\"messages\",\"chat_id\":\"$(jesc "$chat_id")\",\"limit\":$limit,\"topic_id\":\"$(jesc "$topic_id")\"}"
    else
      json="{\"action\":\"messages\",\"chat_id\":\"$(jesc "$chat_id")\",\"limit\":$limit}"
    fi
    ;;
  topics|forum_topics)
    chat_id="$1"
    json="{\"action\":\"forum_topics\",\"chat_id\":\"$(jesc "$chat_id")\"}"
    ;;
  send)
    chat_id="$1"; shift
    topic_id=""
    reply_to=""
    args=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --reply-to)
          reply_to="$2"; shift 2 ;;
        --topic)
          topic_id="$2"; shift 2 ;;
        *)
          args+=("$1"); shift ;;
      esac
    done
    if [ "${#args[@]}" -gt 1 ] && [ -z "$topic_id" ] && [ -z "$reply_to" ]; then
      last_arg="${args[-1]}"
      if [[ "$last_arg" =~ ^-?[0-9]+$ ]]; then
        topic_id="$last_arg"
        unset 'args[${#args[@]}-1]'
      fi
    fi
    text="$(jesc "${args[*]}")"
    json="{\"action\":\"send\",\"chat_id\":\"$(jesc "$chat_id")\",\"text\":\"$text\""
    if [ -n "$topic_id" ]; then json="$json,\"topic_id\":\"$(jesc "$topic_id")\""; fi
    if [ -n "$reply_to" ]; then json="$json,\"reply_to\":\"$(jesc "$reply_to")\""; fi
    json="$json}"
    ;;
  send_file|send_media)
    chat_id="$1"; file_path="$2"; shift 2
    caption=""
    reply_to=""
    topic_id=""
    args=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --reply-to)
          reply_to="$2"; shift 2 ;;
        --topic)
          topic_id="$2"; shift 2 ;;
        *)
          args+=("$1"); shift ;;
      esac
    done
    if [ "${#args[@]}" -ge 1 ]; then caption="${args[0]}"; fi
    if [ "${#args[@]}" -ge 2 ] && [ -z "$reply_to" ]; then reply_to="${args[1]}"; fi
    if [ "${#args[@]}" -ge 3 ] && [ -z "$topic_id" ]; then topic_id="${args[2]}"; fi
    caption="$(jesc "$caption")"
    json="{\"action\":\"send_file\",\"chat_id\":\"$(jesc "$chat_id")\",\"file_path\":\"$(jesc "$file_path")\",\"caption\":\"$caption\""
    if [ -n "$reply_to" ]; then json="$json,\"reply_to\":\"$(jesc "$reply_to")\""; fi
    if [ -n "$topic_id" ]; then json="$json,\"topic_id\":\"$(jesc "$topic_id")\""; fi
    json="$json}"
    ;;
  mark_read)
    chat_id="$1"; topic_id="${2:-}"
    if [ -n "$topic_id" ]; then
      json="{\"action\":\"mark_read\",\"chat_id\":\"$(jesc "$chat_id")\",\"topic_id\":\"$(jesc "$topic_id")\"}"
    else
      json="{\"action\":\"mark_read\",\"chat_id\":\"$(jesc "$chat_id")\"}"
    fi
    ;;
  delete_chat)
    json="{\"action\":\"delete_chat\",\"chat_id\":\"$(jesc "$1")\"}"
    ;;
  leave_chat)
    json="{\"action\":\"leave_chat\",\"chat_id\":\"$(jesc "$1")\"}"
    ;;
  report_spam|report_spam_and_leave)
    json="{\"action\":\"report_spam_and_leave\",\"chat_id\":\"$(jesc "$1")\"}"
    ;;
  delete_message)
    json="{\"action\":\"delete_message\",\"chat_id\":\"$(jesc "$1")\",\"message_id\":\"$(jesc "$2")\"}"
    ;;
  delete_batch|delete_messages)
    chat_id="$1"; shift
    ids=""
    for id in "$@"; do ids="$ids\"$(jesc "$id")\","; done
    ids="${ids%,}"
    json="{\"action\":\"delete_messages\",\"chat_id\":\"$(jesc "$chat_id")\",\"message_ids\":[$ids]}"
    ;;
  edit)
    chat_id="$1"; msg_id="$2"; shift 2
    text="$(jesc "$*")"
    json="{\"action\":\"edit_message\",\"chat_id\":\"$(jesc "$chat_id")\",\"message_id\":\"$(jesc "$msg_id")\",\"text\":\"$text\"}"
    ;;
  pin)
    json="{\"action\":\"pin_message\",\"chat_id\":\"$(jesc "$1")\",\"message_id\":\"$(jesc "$2")\"}"
    ;;
  unpin)
    chat_id="$1"; msg_id="${2:-}"
    if [ -z "$msg_id" ]; then
      echo '{"success":false,"error":"unpin requires a message id"}'; exit 1
    fi
    json="{\"action\":\"unpin_message\",\"chat_id\":\"$(jesc "$chat_id")\",\"message_id\":\"$(jesc "$msg_id")\"}"
    ;;
  forward)
    from_chat="$1"; to_chat="$2"; shift 2
    ids=""
    for id in "$@"; do ids="$ids\"$(jesc "$id")\","; done
    ids="${ids%,}"
    json="{\"action\":\"forward_messages\",\"from_chat_id\":\"$(jesc "$from_chat")\",\"to_chat_id\":\"$(jesc "$to_chat")\",\"message_ids\":[$ids]}"
    ;;
  reaction|send_reaction)
    chat_id="$1"; msg_id="$2"; emoticon="${3:-👍}"
    json="{\"action\":\"send_reaction\",\"chat_id\":\"$(jesc "$chat_id")\",\"message_id\":\"$(jesc "$msg_id")\",\"emoticon\":\"$(jesc "$emoticon")\"}"
    ;;
  start_qr)
    json="{\"action\":\"start_qr\"}"
    ;;
  send_code)
    json="{\"action\":\"send_code\",\"phone\":\"$(jesc "$1")\"}"
    ;;
  submit_code)
    code="$1"; pwd="${2:-}"
    json="{\"action\":\"submit_code\",\"code\":\"$(jesc "$code")\",\"password\":\"$(jesc "$pwd")\"}"
    ;;
  download_media)
    chat_id="$1"; msg_id="$2"; media_type="${3:-video}"
    json="{\"action\":\"download_media\",\"chat_id\":\"$(jesc "$chat_id")\",\"message_id\":\"$(jesc "$msg_id")\",\"media_type\":\"$(jesc "$media_type")\"}"
    ;;
  open_external)
    file_path="$1"; app="${2:-xdg-open}"
    json="{\"action\":\"open_external\",\"file_path\":\"$(jesc "$file_path")\",\"app\":\"$(jesc "$app")\"}"
    ;;
  logout)
    json="{\"action\":\"logout\"}"
    ;;
  status)
    json="{\"action\":\"status\"}"
    ;;
  *)
    echo '{"success":false,"error":"unknown action"}'; exit 1
    ;;
esac

echo "$json" | socat -t 15 - UNIX-CONNECT:"$SOCK" 2>/dev/null
