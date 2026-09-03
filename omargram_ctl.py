#!/usr/bin/env python3
"""OmarGram CLI controller — communicates with OmarGram background daemon over local UNIX socket."""
import os
import sys
import json
import time
import socket
import subprocess
import shutil

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

def get_proc_starttime(pid):
    try:
        with open(f"/proc/{pid}/stat", "r") as f:
            fields = f.read().split(")")[1].split()
            return int(fields[19])
    except Exception:
        return None

def is_omargram_proc(pid, expected_starttime=None):
    try:
        if expected_starttime is not None:
            st = get_proc_starttime(pid)
            if st != expected_starttime:
                return False
        with open(f"/proc/{pid}/cmdline", "r") as f:
            cmdline = f.read()
            return "omargram_daemon.py" in cmdline
    except Exception:
        return False

def stop_daemon():
    # 1. Try graceful IPC stop
    if is_daemon_running():
        try:
            send_daemon_cmd({"action": "stop"}, timeout=1.5)
        except Exception:
            pass
    # 2. Check PID file and verify starttime + cmdline before sending signal
    if os.path.exists(PID_PATH):
        try:
            with open(PID_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
                pid = int(data.get("pid"))
                expected_st = data.get("starttime")
                if is_omargram_proc(pid, expected_st):
                    import signal
                    os.kill(pid, signal.SIGTERM)
                    for _ in range(20):
                        time.sleep(0.05)
                        if not is_omargram_proc(pid, expected_st):
                            break
                    else:
                        if is_omargram_proc(pid, expected_st):
                            os.kill(pid, signal.SIGKILL)
        except Exception:
            pass
        try:
            if os.path.exists(PID_PATH):
                os.unlink(PID_PATH)
        except Exception:
            pass
        try:
            if os.path.exists(SOCK_PATH):
                os.unlink(SOCK_PATH)
        except Exception:
            pass
    return {"success": True}

def find_python():
    """Find a python3 that has telethon installed."""
    # 1. Check common venv locations relative to the plugin dir
    plugin_dir = os.path.dirname(os.path.realpath(__file__))
    home = os.path.expanduser("~")
    candidates = [
        os.path.join(home, ".venv", "omargram", "bin", "python3"),
        os.path.join(home, ".venv", "bin", "python3"),
        os.path.join(home, ".local", "pipx", "venvs", "telethon", "bin", "python3"),
        os.path.join(plugin_dir, ".venv", "bin", "python3"),
        sys.executable,
    ]
    for py in candidates:
        if os.path.exists(py):
            try:
                result = subprocess.run(
                    [py, "-c", "import telethon"],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
                )
                if result.returncode == 0:
                    return py
            except Exception:
                pass
    return sys.executable

DAEMON_PYTHON = find_python()

def ensure_daemon_running():
    if is_daemon_running():
        return True
    os.makedirs(OMARGRAM_RUN_DIR, mode=0o700, exist_ok=True)
    try:
        os.chmod(OMARGRAM_RUN_DIR, 0o700)
    except Exception:
        pass
    daemon_script = get_daemon_script_path()
    try:
        subprocess.Popen(
            [DAEMON_PYTHON, daemon_script],
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

def extract_clipboard_image():
    cache_dir = os.path.expanduser("~/.cache/omargram/attachments")
    os.makedirs(cache_dir, mode=0o700, exist_ok=True)
    try:
        os.chmod(cache_dir, 0o700)
    except Exception:
        pass

    try:
        types_out = subprocess.check_output(["wl-paste", "--list-types"], stderr=subprocess.DEVNULL, timeout=1.0).decode("utf-8")
    except Exception:
        types_out = ""

    target_type = None
    ext = "png"
    if "image/png" in types_out:
        target_type = "image/png"
        ext = "png"
    elif "image/jpeg" in types_out:
        target_type = "image/jpeg"
        ext = "jpg"
    elif "image/webp" in types_out:
        target_type = "image/webp"
        ext = "webp"

    if not target_type:
        return {"success": True, "has_image": False}

    filename = f"paste_{int(time.time() * 1000)}.{ext}"
    filepath = os.path.join(cache_dir, filename)

    try:
        with open(filepath, "wb") as f:
            proc = subprocess.run(["wl-paste", "--type", target_type], stdout=f, stderr=subprocess.PIPE, timeout=2.5)
        if proc.returncode == 0 and os.path.exists(filepath) and os.path.getsize(filepath) > 0:
            try:
                os.chmod(filepath, 0o600)
            except Exception:
                pass
            return {
                "success": True,
                "has_image": True,
                "file_path": filepath,
                "file_name": filename,
                "file_size": os.path.getsize(filepath),
                "mime": target_type
            }
    except Exception as e:
        return {"success": False, "error": str(e)}
    return {"success": True, "has_image": False}

def pick_file_dialog():
    env = dict(os.environ)
    env["NO_AT_SPI_CLIENT_BUS"] = "1"
    env["GDK_BACKEND"] = "wayland,x11"
    try:
        res = subprocess.check_output(
            ["zenity", "--file-selection", "--title=Select media or file to attach in OmarGram"],
            env=env,
            stderr=subprocess.DEVNULL,
            timeout=120.0
        ).decode("utf-8").strip()
        if res and os.path.exists(res):
            return {
                "success": True,
                "file_path": res,
                "file_name": os.path.basename(res),
                "file_size": os.path.getsize(res)
            }
    except subprocess.TimeoutExpired:
        return {"success": False, "error": "Dialog timed out"}
    except subprocess.CalledProcessError:
        return {"success": True, "cancelled": True}
    except Exception as e:
        return {"success": False, "error": str(e)}
    return {"success": True, "cancelled": True}

def browse_directory(dir_path="pictures", limit=80):
    home = os.path.expanduser("~")
    if dir_path == "pictures":
        path = os.path.join(home, "Pictures")
    elif dir_path == "downloads":
        path = os.path.join(home, "Downloads")
    elif dir_path == "home" or dir_path == "~":
        path = home
    else:
        path = os.path.expanduser(dir_path)
    
    if not os.path.isdir(path):
        path = os.path.join(home, "Pictures") if os.path.exists(os.path.join(home, "Pictures")) else home
    
    entries = []
    parent_path = os.path.dirname(os.path.abspath(path))
    
    try:
        with os.scandir(path) as it:
            for e in it:
                if e.name.startswith("."):
                    continue
                try:
                    is_dir = e.is_dir(follow_symlinks=True)
                    st = e.stat(follow_symlinks=True)
                    ext = os.path.splitext(e.name)[1].lower()
                    is_img = ext in (".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".svg")
                    entries.append({
                        "name": e.name,
                        "path": e.path,
                        "is_dir": is_dir,
                        "is_image": is_img,
                        "size": st.st_size if not is_dir else 0,
                        "mtime": int(st.st_mtime),
                        "preview": "file://" + e.path if is_img else ""
                    })
                except Exception:
                    pass
    except Exception as err:
        return {"success": False, "error": str(err), "entries": [], "current_path": path, "parent_path": parent_path}
    
    # Folders first, then files by latest modification time
    entries.sort(key=lambda x: (not x["is_dir"], -x["mtime"]))
    return {
        "success": True,
        "current_path": path,
        "parent_path": parent_path if parent_path != path else "",
        "entries": entries[:limit]
    }

def search_files(query, root_dir="~", limit=60):
    query = query.strip()
    home = os.path.expanduser("~")
    
    if root_dir == "pictures":
        root = os.path.join(home, "Pictures")
    elif root_dir == "downloads":
        root = os.path.join(home, "Downloads")
    elif root_dir == "home" or root_dir == "~":
        root = home
    else:
        root = os.path.expanduser(root_dir)
    
    if not os.path.exists(root):
        root = home

    if not query:
        return browse_directory(root_dir, limit)
    
    entries = []
    has_fd = shutil.which("fd") is not None
    
    if has_fd:
        try:
            cmd = [
                "fd", "--type", "f",
                "--exclude", ".git",
                "--exclude", "node_modules",
                "--exclude", ".cache",
                "--exclude", "__pycache__",
                "--exclude", "target",
                "--exclude", "dist",
                "--exclude", ".cargo",
                "--exclude", ".venv",
                "--exclude", ".bundle",
                "--max-results", str(limit),
                query,
                root
            ]
            out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL, timeout=1.5).decode("utf-8")
            paths = [p.strip() for p in out.splitlines() if p.strip()]
        except Exception:
            paths = []
    else:
        paths = []
    
    for p in paths:
        try:
            st = os.stat(p)
            ext = os.path.splitext(p)[1].lower()
            is_img = ext in (".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".svg")
            rel_dir = os.path.dirname(p).replace(home, "~")
            entries.append({
                "name": os.path.basename(p),
                "path": p,
                "dir": rel_dir,
                "is_dir": False,
                "is_image": is_img,
                "size": st.st_size,
                "mtime": int(st.st_mtime),
                "preview": "file://" + p if is_img else ""
            })
        except Exception:
            pass
    
    entries.sort(key=lambda x: (not x["is_image"], -x["mtime"]))
    return {
        "success": True,
        "query": query,
        "root": root,
        "entries": entries[:limit]
    }

def main():
    if len(sys.argv) < 2:
        print(json.dumps(send_daemon_cmd({"action": "status"})))
        sys.exit(0)

    action = sys.argv[1]

    if action == "status":
        print(json.dumps(send_daemon_cmd({"action": "status"})))
    elif action in ("search_files", "find", "search"):
        query = sys.argv[2] if len(sys.argv) > 2 else ""
        root_dir = sys.argv[3] if len(sys.argv) > 3 else "~"
        print(json.dumps(search_files(query, root_dir)))
    elif action in ("list_files", "browse", "browse_files"):
        folder = sys.argv[2] if len(sys.argv) > 2 else "pictures"
        print(json.dumps(browse_directory(folder)))
    elif action == "paste_image":
        print(json.dumps(extract_clipboard_image()))
    elif action == "pick_file":
        print(json.dumps(pick_file_dialog()))
    elif action in ("dialogs", "chats"):
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 40
        print(json.dumps(send_daemon_cmd({"action": "dialogs", "limit": limit})))
    elif action == "messages":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Usage: omargram_ctl.py messages <chat_id> [limit] [topic_id]"}))
            sys.exit(1)
        chat_id = sys.argv[2]
        limit = int(sys.argv[3]) if len(sys.argv) > 3 else 50
        topic_id = sys.argv[4] if len(sys.argv) > 4 else None
        cmd = {"action": "messages", "chat_id": chat_id, "limit": limit}
        if topic_id:
            cmd["topic_id"] = topic_id
        result = send_daemon_cmd(cmd)
        print(json.dumps(result))
    elif action == "send":
        if len(sys.argv) < 4:
            print(json.dumps({"success": False, "error": "Usage: omargram_ctl.py send <chat_id> <text> [--reply-to <id>] [--topic <id>]"}))
            sys.exit(1)
        chat_id = sys.argv[2]
        raw_args = sys.argv[3:]
        topic_id = None
        reply_to = None
        pos_args = []
        i = 0
        while i < len(raw_args):
            if raw_args[i] == "--reply-to" and i + 1 < len(raw_args):
                reply_to = raw_args[i + 1]
                i += 2
            elif raw_args[i] == "--topic" and i + 1 < len(raw_args):
                topic_id = raw_args[i + 1]
                i += 2
            else:
                pos_args.append(raw_args[i])
                i += 1
        if len(pos_args) > 1 and topic_id is None and pos_args[-1].lstrip("-").isdigit():
            topic_id = pos_args[-1]
            pos_args = pos_args[:-1]
        text = " ".join(pos_args)
        cmd = {"action": "send", "chat_id": chat_id, "text": text}
        if topic_id:
            cmd["topic_id"] = topic_id
        if reply_to:
            cmd["reply_to"] = reply_to
        print(json.dumps(send_daemon_cmd(cmd)))
    elif action in ("send_file", "send_media"):
        if len(sys.argv) < 4:
            print(json.dumps({"success": False, "error": "Usage: omargram_ctl.py send_file <chat_id> <file_path> [caption] [reply_to] [--reply-to <id>] [--topic <id>]"}))
            sys.exit(1)
        chat_id = sys.argv[2]
        file_path = sys.argv[3]
        raw_args = sys.argv[4:]
        caption = ""
        reply_to = None
        topic_id = None
        pos_args = []
        i = 0
        while i < len(raw_args):
            if raw_args[i] == "--reply-to" and i + 1 < len(raw_args):
                reply_to = raw_args[i + 1]
                i += 2
            elif raw_args[i] == "--topic" and i + 1 < len(raw_args):
                topic_id = raw_args[i + 1]
                i += 2
            else:
                pos_args.append(raw_args[i])
                i += 1
        if len(pos_args) >= 1:
            caption = pos_args[0]
        if len(pos_args) >= 2 and reply_to is None:
            reply_to = pos_args[1]
        if len(pos_args) >= 3 and topic_id is None:
            topic_id = pos_args[2]
        cmd = {
            "action": "send_file",
            "chat_id": chat_id,
            "file_path": file_path,
            "caption": caption,
        }
        if reply_to:
            cmd["reply_to"] = reply_to
        if topic_id:
            cmd["topic_id"] = topic_id
        print(json.dumps(send_daemon_cmd(cmd)))
    elif action == "mark_read":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Usage: omargram_ctl.py mark_read <chat_id> [topic_id]"}))
            sys.exit(1)
        chat_id = sys.argv[2]
        topic_id = sys.argv[3] if len(sys.argv) > 3 else None
        cmd = {"action": "mark_read", "chat_id": chat_id}
        if topic_id:
            cmd["topic_id"] = topic_id
        print(json.dumps(send_daemon_cmd(cmd)))
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
    elif action in ("delete_messages", "delete_batch"):
        if len(sys.argv) < 4:
            print(json.dumps({"success": False, "error": "Usage: omargram_ctl.py delete_batch <chat_id> <msg_id1> [msg_id2...]"}))
            sys.exit(1)
        chat_id = sys.argv[2]
        msg_ids = sys.argv[3:]
        print(json.dumps(send_daemon_cmd({"action": "delete_messages", "chat_id": chat_id, "message_ids": msg_ids})))
    elif action == "edit":
        if len(sys.argv) < 5:
            print(json.dumps({"success": False, "error": "Usage: omargram_ctl.py edit <chat_id> <message_id> <text>"}))
            sys.exit(1)
        chat_id = sys.argv[2]
        msg_id = sys.argv[3]
        text = " ".join(sys.argv[4:])
        print(json.dumps(send_daemon_cmd({"action": "edit_message", "chat_id": chat_id, "message_id": msg_id, "text": text})))
    elif action == "pin":
        if len(sys.argv) < 4:
            print(json.dumps({"success": False, "error": "Usage: omargram_ctl.py pin <chat_id> <message_id>"}))
            sys.exit(1)
        chat_id = sys.argv[2]
        msg_id = sys.argv[3]
        print(json.dumps(send_daemon_cmd({"action": "pin_message", "chat_id": chat_id, "message_id": msg_id})))
    elif action == "unpin":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Usage: omargram_ctl.py unpin <chat_id> [message_id]"}))
            sys.exit(1)
        chat_id = sys.argv[2]
        msg_id = sys.argv[3] if len(sys.argv) > 3 else None
        print(json.dumps(send_daemon_cmd({"action": "unpin_message", "chat_id": chat_id, "message_id": msg_id})))
    elif action == "forward":
        if len(sys.argv) < 5:
            print(json.dumps({"success": False, "error": "Usage: omargram_ctl.py forward <from_chat_id> <to_chat_id> <msg_id1> [msg_id2...]"}))
            sys.exit(1)
        from_chat_id = sys.argv[2]
        to_chat_id = sys.argv[3]
        msg_ids = sys.argv[4:]
        print(json.dumps(send_daemon_cmd({"action": "forward_messages", "from_chat_id": from_chat_id, "to_chat_id": to_chat_id, "message_ids": msg_ids})))
    elif action in ("reaction", "send_reaction"):
        if len(sys.argv) < 4:
            print(json.dumps({"success": False, "error": "Usage: omargram_ctl.py reaction <chat_id> <message_id> [emoticon]"}))
            sys.exit(1)
        chat_id = sys.argv[2]
        msg_id = sys.argv[3]
        emoticon = sys.argv[4] if len(sys.argv) > 4 else "👍"
        if emoticon.lower() in ("clear", "remove", "none", "rm", "delete", "empty"):
            emoticon = ""
        print(json.dumps(send_daemon_cmd({"action": "send_reaction", "chat_id": chat_id, "message_id": msg_id, "emoticon": emoticon})))
    elif action == "start_qr":
        print(json.dumps(send_daemon_cmd({"action": "start_qr"})))
    elif action in ("forum_topics", "topics"):
        chat_id = sys.argv[2] if len(sys.argv) > 2 else ""
        print(json.dumps(send_daemon_cmd({"action": "forum_topics", "chat_id": chat_id})))
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
        print(json.dumps(stop_daemon()))
    else:
        print(json.dumps({"success": False, "error": f"Unknown action: {action}"}))

if __name__ == "__main__":
    main()
