#!/usr/bin/env python3
"""OmarGram CLI controller — communicates with OmarGram background daemon over local UNIX socket."""
import os
import sys
import json
import time
import socket
import subprocess

RUN_DIR = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
OMARGRAM_RUN_DIR = os.path.join(RUN_DIR, "omargram")
SOCK_PATH = os.path.join(OMARGRAM_RUN_DIR, "omargram.sock")
PID_PATH = os.path.join(OMARGRAM_RUN_DIR, "daemon.pid")

def get_daemon_script_path():
    plugin_dir = os.path.dirname(os.path.realpath(__file__))
    return os.path.join(plugin_dir, "omargram_daemon.py")

def is_daemon_running():
    if not os.path.exists(SOCK_PATH):
        return False
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(0.5)
        s.connect(SOCK_PATH)
        s.close()
        return True
    except Exception:
        return False

def ensure_daemon_running():
    if is_daemon_running():
        return True
    os.makedirs(OMARGRAM_RUN_DIR, mode=0o700, exist_ok=True)
    daemon_script = get_daemon_script_path()
    try:
        subprocess.Popen(
            [sys.executable, daemon_script],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True
        )
        for _ in range(60):
            time.sleep(0.1)
            if is_daemon_running():
                return True
    except Exception:
        pass
    return False

def send_daemon_cmd(cmd_dict, timeout=8.0):
    if not ensure_daemon_running():
        return {"success": False, "error": "Daemon unavailable", "running": False, "authorized": False}
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(timeout)
        s.connect(SOCK_PATH)
        payload = json.dumps(cmd_dict) + "\n"
        s.sendall(payload.encode("utf-8"))
        
        chunks = []
        while True:
            chunk = s.recv(4096)
            if not chunk:
                break
            chunks.append(chunk)
            if b"\n" in chunk:
                break
        s.close()
        raw = b"".join(chunks).decode("utf-8").strip()
        if raw:
            return json.loads(raw)
    except Exception as e:
        return {"success": False, "error": str(e)}
    return {"success": False, "error": "Empty response"}

def main():
    if len(sys.argv) < 2:
        print(json.dumps(send_daemon_cmd({"action": "status"})))
        sys.exit(0)

    action = sys.argv[1]

    if action == "status":
        print(json.dumps(send_daemon_cmd({"action": "status"})))
    elif action in ("dialogs", "chats"):
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 40
        print(json.dumps(send_daemon_cmd({"action": "dialogs", "limit": limit})))
    elif action == "messages":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Usage: omargram_ctl.py messages <chat_id> [limit]"}))
            sys.exit(1)
        chat_id = sys.argv[2]
        limit = int(sys.argv[3]) if len(sys.argv) > 3 else 50
        print(json.dumps(send_daemon_cmd({"action": "messages", "chat_id": chat_id, "limit": limit})))
    elif action == "send":
        if len(sys.argv) < 4:
            print(json.dumps({"success": False, "error": "Usage: omargram_ctl.py send <chat_id> <text>"}))
            sys.exit(1)
        chat_id = sys.argv[2]
        text = " ".join(sys.argv[3:])
        print(json.dumps(send_daemon_cmd({"action": "send", "chat_id": chat_id, "text": text})))
    elif action == "mark_read":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Usage: omargram_ctl.py mark_read <chat_id>"}))
            sys.exit(1)
        chat_id = sys.argv[2]
        print(json.dumps(send_daemon_cmd({"action": "mark_read", "chat_id": chat_id})))
    elif action == "delete_chat":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Usage: omargram_ctl.py delete_chat <chat_id>"}))
            sys.exit(1)
        chat_id = sys.argv[2]
        print(json.dumps(send_daemon_cmd({"action": "delete_chat", "chat_id": chat_id})))
    elif action == "leave_chat":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Usage: omargram_ctl.py leave_chat <chat_id>"}))
            sys.exit(1)
        chat_id = sys.argv[2]
        print(json.dumps(send_daemon_cmd({"action": "leave_chat", "chat_id": chat_id})))
    elif action in ("report_spam", "report_spam_and_leave"):
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Usage: omargram_ctl.py report_spam <chat_id>"}))
            sys.exit(1)
        chat_id = sys.argv[2]
        print(json.dumps(send_daemon_cmd({"action": "report_spam_and_leave", "chat_id": chat_id})))
    elif action == "delete_message":
        if len(sys.argv) < 4:
            print(json.dumps({"success": False, "error": "Usage: omargram_ctl.py delete_message <chat_id> <message_id>"}))
            sys.exit(1)
        chat_id = sys.argv[2]
        msg_id = sys.argv[3]
        print(json.dumps(send_daemon_cmd({"action": "delete_message", "chat_id": chat_id, "message_id": msg_id})))
    elif action in ("reaction", "send_reaction"):
        if len(sys.argv) < 4:
            print(json.dumps({"success": False, "error": "Usage: omargram_ctl.py reaction <chat_id> <message_id> [emoticon]"}))
            sys.exit(1)
        chat_id = sys.argv[2]
        msg_id = sys.argv[3]
        emoticon = sys.argv[4] if len(sys.argv) > 4 else "👍"
        print(json.dumps(send_daemon_cmd({"action": "send_reaction", "chat_id": chat_id, "message_id": msg_id, "emoticon": emoticon})))
    elif action == "start_qr":
        print(json.dumps(send_daemon_cmd({"action": "start_qr"})))
    elif action == "send_code":
        phone = sys.argv[2] if len(sys.argv) > 2 else ""
        print(json.dumps(send_daemon_cmd({"action": "send_code", "phone": phone})))
    elif action == "submit_code":
        code = sys.argv[2] if len(sys.argv) > 2 else ""
        pwd = sys.argv[3] if len(sys.argv) > 3 else ""
        print(json.dumps(send_daemon_cmd({"action": "submit_code", "code": code, "password": pwd})))
    elif action == "logout":
        print(json.dumps(send_daemon_cmd({"action": "logout"})))
    elif action == "stop":
        print(json.dumps(send_daemon_cmd({"action": "stop"})))
    else:
        print(json.dumps({"success": False, "error": f"Unknown action: {action}"}))

if __name__ == "__main__":
    main()
