#!/usr/bin/env python3
"""OmarGram background daemon — Telegram MTProto client with UNIX domain socket IPC server."""
import os
import sys
import json
import time
import asyncio
import signal
import socket
import re
import hashlib
from datetime import datetime

# Default Telegram API credentials (Official Telegram Android/Desktop public client IDs)
# Users can also provide custom api_id / api_hash in ~/.config/omargram/config.json
DEFAULT_API_ID = 2040
DEFAULT_API_HASH = "b18441a1ff607e10a989891a5462e627"

CONFIG_DIR = os.path.expanduser("~/.config/omargram")
CACHE_DIR = os.path.expanduser("~/.cache/omargram")
AVATARS_DIR = os.path.join(CACHE_DIR, "avatars")
MEDIA_DIR = os.path.join(CACHE_DIR, "media")
RUN_DIR = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
OMARGRAM_RUN_DIR = os.path.join(RUN_DIR, "omargram")

SOCK_PATH = os.path.join(OMARGRAM_RUN_DIR, "omargram.sock")
PID_PATH = os.path.join(OMARGRAM_RUN_DIR, "daemon.pid")
SESSION_PATH = os.path.join(CONFIG_DIR, "omargram.session")
QR_PATH = os.path.join(CACHE_DIR, "login_qr.png")

os.makedirs(CONFIG_DIR, mode=0o700, exist_ok=True)
os.makedirs(CACHE_DIR, mode=0o700, exist_ok=True)
os.makedirs(AVATARS_DIR, mode=0o700, exist_ok=True)
os.makedirs(MEDIA_DIR, mode=0o700, exist_ok=True)
os.makedirs(OMARGRAM_RUN_DIR, mode=0o700, exist_ok=True)

try:
    from telethon import TelegramClient, events, functions, types
    from telethon.tl.types import User, Chat, Channel, MessageMediaPhoto, MessageMediaDocument
    import qrcode
except ImportError as e:
    print(f"Required library missing: {e}", file=sys.stderr)
    sys.exit(1)

def load_config():
    cfg_file = os.path.join(CONFIG_DIR, "config.json")
    if os.path.exists(cfg_file):
        try:
            with open(cfg_file, "r", encoding="utf-8") as f:
                d = json.load(f)
                return d.get("api_id", DEFAULT_API_ID), d.get("api_hash", DEFAULT_API_HASH)
        except Exception:
            pass
    return DEFAULT_API_ID, DEFAULT_API_HASH

def get_avatar_color(name):
    """Generate consistent aesthetic pastel hue from name."""
    colors = [
        "#e57373", "#f06292", "#ba68c8", "#9575cd",
        "#7986cb", "#64b5f6", "#4fc3f7", "#4dd0e1",
        "#4db6ac", "#81c784", "#aed581", "#ffb74d",
        "#ff8a65", "#a1887f", "#90a4ae"
    ]
    h = sum(ord(c) for c in (name or "T"))
    return colors[h % len(colors)]

def get_initials(name):
    if not name:
        return "TG"
    parts = name.strip().split()
    if len(parts) >= 2:
        return (parts[0][0] + parts[-1][0]).upper()
    return name.strip()[:2].upper()

class OmarGramDaemon:
    def __init__(self):
        api_id, api_hash = load_config()
        self.api_id = api_id
        self.api_hash = api_hash
        self.client = TelegramClient(SESSION_PATH, self.api_id, self.api_hash)
        self.qr_login_obj = None
        self.phone_code_hash = None
        self.phone_number = None
        self.running = True
        self.dialogs_cache = []
        self.unread_total = 0
        self.cached_avatars = {}

    async def start(self):
        # Save PID file with strict permissions
        pid_payload = json.dumps({
            "pid": os.getpid(),
            "starttime": self.get_my_starttime(),
            "started_at": time.time()
        })
        fd = os.open(PID_PATH, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with open(fd, "w", encoding="utf-8") as f:
            f.write(pid_payload)

        # Connect to Telegram
        await self.client.connect()

        # Register live event listeners
        @self.client.on(events.NewMessage)
        async def handler(event):
            await self.update_unread_count()
            asyncio.create_task(self.refresh_dialogs_cache())

        # Start Unix Socket Server
        if os.path.exists(SOCK_PATH):
            try:
                os.unlink(SOCK_PATH)
            except Exception:
                pass

        server = await asyncio.start_unix_server(self.handle_client, path=SOCK_PATH)
        try:
            os.chmod(SOCK_PATH, 0o600)
        except Exception:
            pass

        print(f"OmarGram daemon listening on {SOCK_PATH}")
        asyncio.create_task(self.refresh_dialogs_cache())

        async with server:
            while self.running:
                await asyncio.sleep(1)

    def get_my_starttime(self):
        try:
            with open(f"/proc/{os.getpid()}/stat", "r") as f:
                fields = f.read().split(")")[1].split()
                return int(fields[19])
        except Exception:
            return 0

    async def update_unread_count(self):
        if not await self.client.is_user_authorized():
            self.unread_total = 0
            return 0
        try:
            dialogs = await self.client.get_dialogs(limit=50)
            total = sum(d.unread_count for d in dialogs if not d.is_channel)
            self.unread_total = total
            return total
        except Exception:
            return self.unread_total

    async def get_chat_avatar(self, entity):
        """Fetch and cache entity profile photo as local file path."""
        try:
            ent_id = entity.id
            if ent_id in self.cached_avatars and os.path.exists(self.cached_avatars[ent_id]):
                return self.cached_avatars[ent_id]

            avatar_file = os.path.join(AVATARS_DIR, f"{ent_id}.jpg")
            if os.path.exists(avatar_file) and os.path.getsize(avatar_file) > 0:
                self.cached_avatars[ent_id] = avatar_file
                return avatar_file

            path = await self.client.download_profile_photo(entity, file=avatar_file, download_big=False)
            if path and os.path.exists(path):
                self.cached_avatars[ent_id] = path
                return path
        except Exception:
            pass
        return ""

    async def refresh_dialogs_cache(self, limit=40):
        if not await self.client.is_user_authorized():
            self.dialogs_cache = []
            return []
        try:
            dialogs = await self.client.get_dialogs(limit=limit)
            result = []
            total_unread = 0

            for d in dialogs:
                ent = d.entity
                title = d.name or "Unknown"
                username = getattr(ent, "username", "") or ""
                is_user = isinstance(ent, User)
                is_group = isinstance(ent, (Chat, Channel)) and getattr(ent, "megagroup", False) or isinstance(ent, Chat)
                is_channel = isinstance(ent, Channel) and not getattr(ent, "megagroup", False)

                unread = d.unread_count or 0
                if not is_channel:
                    total_unread += unread

                last_msg_text = ""
                last_msg_date = ""
                last_msg_time = ""
                last_msg_out = False
                media_type = ""

                if d.message:
                    last_msg_out = bool(d.message.out)
                    last_msg_text = d.message.message or ""
                    if d.message.media:
                        if isinstance(d.message.media, MessageMediaPhoto):
                            media_type = "photo"
                            if not last_msg_text:
                                last_msg_text = "📷 Photo"
                        elif isinstance(d.message.media, MessageMediaDocument):
                            media_type = "document"
                            if not last_msg_text:
                                last_msg_text = "📄 Document"
                    
                    dt = d.message.date
                    if dt:
                        last_msg_date = dt.strftime("%Y-%m-%d")
                        now = datetime.now(dt.tzinfo)
                        if dt.date() == now.date():
                            last_msg_time = dt.strftime("%H:%M")
                        else:
                            last_msg_time = dt.strftime("%b %d")

                avatar_path = await self.get_chat_avatar(ent)

                online = False
                if is_user and getattr(ent, "status", None):
                    status_name = type(ent.status).__name__
                    if status_name == "UserStatusOnline":
                        online = True

                result.append({
                    "id": d.id,
                    "title": title,
                    "username": username,
                    "is_user": is_user,
                    "is_group": is_group,
                    "is_channel": is_channel,
                    "unread_count": unread,
                    "avatar": avatar_path,
                    "initials": get_initials(title),
                    "color": get_avatar_color(title),
                    "online": online,
                    "last_message": {
                        "text": last_msg_text,
                        "time": last_msg_time,
                        "date": last_msg_date,
                        "out": last_msg_out,
                        "media_type": media_type
                    }
                })

            self.dialogs_cache = result
            self.unread_total = total_unread
            return result
        except Exception as e:
            print(f"Error refreshing dialogs: {e}", file=sys.stderr)
            return self.dialogs_cache

    async def get_messages_for_chat(self, chat_id, limit=50):
        if not await self.client.is_user_authorized():
            return []
        try:
            cid = int(chat_id)
            entity = await self.client.get_entity(cid)
            messages = await self.client.get_messages(entity, limit=limit)
            result = []

            for m in reversed(messages):
                sender_name = "You" if m.out else ""
                sender_avatar = ""
                sender_color = "#888888"

                if not m.out:
                    try:
                        sender = await m.get_sender()
                        if sender:
                            sender_name = getattr(sender, "first_name", "") or getattr(sender, "title", "User")
                            sender_avatar = await self.get_chat_avatar(sender)
                            sender_color = get_avatar_color(sender_name)
                    except Exception:
                        sender_name = "User"
                    if not sender_avatar and cid in self.cached_avatars:
                        sender_avatar = self.cached_avatars[cid]

                media_type = ""
                media_path = ""
                if m.media:
                    if isinstance(m.media, MessageMediaPhoto):
                        media_type = "photo"
                        photo_f = os.path.join(MEDIA_DIR, f"photo_{m.id}_{cid}.jpg")
                        if not os.path.exists(photo_f):
                            try:
                                await self.client.download_media(m.media, file=photo_f)
                            except Exception:
                                pass
                        if os.path.exists(photo_f):
                            media_path = photo_f
                    elif isinstance(m.media, MessageMediaDocument):
                        media_type = "document"

                dt = m.date
                time_str = dt.strftime("%H:%M") if dt else ""
                date_str = dt.strftime("%b %d, %Y") if dt else ""

                result.append({
                    "id": m.id,
                    "chat_id": cid,
                    "sender_id": m.sender_id,
                    "sender_name": sender_name,
                    "sender_avatar": sender_avatar,
                    "sender_initials": get_initials(sender_name),
                    "sender_color": sender_color,
                    "text": m.message or "",
                    "time": time_str,
                    "date": date_str,
                    "out": bool(m.out),
                    "media_type": media_type,
                    "media_path": media_path,
                    "reply_to_msg_id": m.reply_to_msg_id if hasattr(m, "reply_to_msg_id") else None
                })
            return result
        except Exception as e:
            print(f"Error fetching messages for {chat_id}: {e}", file=sys.stderr)
            return []

    async def send_message_to_chat(self, chat_id, text):
        if not await self.client.is_user_authorized():
            return {"success": False, "error": "Not authorized"}
        try:
            cid = int(chat_id)
            entity = await self.client.get_entity(cid)
            sent = await self.client.send_message(entity, text)
            asyncio.create_task(self.refresh_dialogs_cache())
            return {"success": True, "message_id": sent.id}
        except Exception as e:
            return {"success": False, "error": str(e)}

    async def mark_chat_read(self, chat_id):
        if not await self.client.is_user_authorized():
            return {"success": False, "error": "Not authorized"}
        try:
            cid = int(chat_id)
            entity = await self.client.get_entity(cid)
            await self.client.send_read_acknowledge(entity)
            for d in self.dialogs_cache:
                if d.get("id") == cid:
                    d["unread_count"] = 0
            await self.update_unread_count()
            return {"success": True}
        except Exception as e:
            return {"success": False, "error": str(e)}

    async def execute_command(self, cmd_dict):
        action = cmd_dict.get("action", "")
        
        if action == "status":
            is_auth = await self.client.is_user_authorized()
            user_info = None
            if is_auth:
                me = await self.client.get_me()
                if me:
                    me_avatar = await self.get_chat_avatar(me)
                    my_name = f"{me.first_name or ''} {me.last_name or ''}".strip() or me.username or "Me"
                    user_info = {
                        "id": me.id,
                        "name": my_name,
                        "username": me.username or "",
                        "phone": me.phone or "",
                        "avatar": me_avatar,
                        "initials": get_initials(my_name)
                    }
            return {
                "running": True,
                "authorized": is_auth,
                "user": user_info,
                "unread_total": self.unread_total,
                "chats_count": len(self.dialogs_cache)
            }

        elif action == "delete_chat":
            chat_id = cmd_dict.get("chat_id")
            if not chat_id:
                return {"success": False, "error": "chat_id required"}
            try:
                cid = int(chat_id)
                entity = await self.client.get_entity(cid)
                await self.client.delete_dialog(entity)
                self.dialogs_cache = [d for d in self.dialogs_cache if d.get("id") != cid]
                await self.update_unread_count()
                return {"success": True, "chat_id": cid}
            except Exception as e:
                return {"success": False, "error": str(e)}

        elif action == "dialogs":
            lim = int(cmd_dict.get("limit", 40))
            chats = await self.refresh_dialogs_cache(lim)
            return {"success": True, "chats": chats, "unread_total": self.unread_total}

        elif action == "messages":
            chat_id = cmd_dict.get("chat_id")
            lim = int(cmd_dict.get("limit", 50))
            if not chat_id:
                return {"success": False, "error": "chat_id required"}
            msgs = await self.get_messages_for_chat(chat_id, lim)
            return {"success": True, "chat_id": chat_id, "messages": msgs}

        elif action == "send":
            chat_id = cmd_dict.get("chat_id")
            text = cmd_dict.get("text", "")
            return await self.send_message_to_chat(chat_id, text)

        elif action == "mark_read":
            chat_id = cmd_dict.get("chat_id")
            return await self.mark_chat_read(chat_id)

        elif action == "start_qr":
            if await self.client.is_user_authorized():
                return {"success": True, "already_logged_in": True}
            try:
                self.qr_login_obj = await self.client.qr_login()
                img = qrcode.make(self.qr_login_obj.url)
                img.save(QR_PATH)
                asyncio.create_task(self.wait_for_qr())
                return {"success": True, "qr_path": QR_PATH, "url": self.qr_login_obj.url}
            except Exception as e:
                return {"success": False, "error": str(e)}

        elif action == "send_code":
            phone = cmd_dict.get("phone", "").strip()
            self.phone_number = phone
            try:
                res = await self.client.send_code_request(phone)
                self.phone_code_hash = res.phone_code_hash
                return {"success": True, "phone": phone}
            except Exception as e:
                return {"success": False, "error": str(e)}

        elif action == "submit_code":
            code = cmd_dict.get("code", "").strip()
            password = cmd_dict.get("password", "").strip()
            try:
                if self.phone_number and self.phone_code_hash:
                    await self.client.sign_in(self.phone_number, code, phone_code_hash=self.phone_code_hash)
                    asyncio.create_task(self.refresh_dialogs_cache())
                    return {"success": True}
                else:
                    return {"success": False, "error": "No phone number requested"}
            except types.errors.SessionPasswordNeededError:
                if password:
                    await self.client.sign_in(password=password)
                    asyncio.create_task(self.refresh_dialogs_cache())
                    return {"success": True}
                return {"success": False, "requires_password": True}
            except Exception as e:
                return {"success": False, "error": str(e)}

        elif action == "logout":
            try:
                await self.client.log_out()
                self.dialogs_cache = []
                self.unread_total = 0
                return {"success": True}
            except Exception as e:
                return {"success": False, "error": str(e)}

        elif action == "stop":
            self.running = False
            return {"success": True}

        return {"success": False, "error": f"Unknown action: {action}"}

    async def wait_for_qr(self):
        if not self.qr_login_obj:
            return
        try:
            await self.qr_login_obj.wait(timeout=120)
            print("QR code successfully scanned and authorized!")
            asyncio.create_task(self.refresh_dialogs_cache())
        except Exception as e:
            print(f"QR login wait error or expired: {e}")

    async def handle_client(self, reader, writer):
        try:
            data = await reader.readuntil(b"\n")
            line = data.decode("utf-8").strip()
            if line:
                cmd_dict = json.loads(line)
                response = await self.execute_command(cmd_dict)
                writer.write(json.dumps(response).encode("utf-8") + b"\n")
                await writer.drain()
        except Exception as e:
            try:
                writer.write(json.dumps({"success": False, "error": str(e)}).encode("utf-8") + b"\n")
                await writer.drain()
            except Exception:
                pass
        finally:
            try:
                writer.close()
                await writer.wait_closed()
            except Exception:
                pass

if __name__ == "__main__":
    daemon = OmarGramDaemon()
    try:
        asyncio.run(daemon.start())
    except KeyboardInterrupt:
        pass
