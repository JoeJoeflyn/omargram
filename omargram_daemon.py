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
    from telethon.tl.types import User, Chat, Channel, MessageMediaPhoto, MessageMediaDocument, MessageMediaWebPage, WebPage, InputReportReasonSpam, ReactionEmoji
    from telethon.tl.functions.channels import LeaveChannelRequest
    from telethon.tl.functions.messages import DeleteChatUserRequest, ReportSpamRequest, SendReactionRequest
    from telethon.tl.functions.account import ReportPeerRequest
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

                read_outbox_max_id = getattr(d.dialog, 'read_outbox_max_id', 0) if hasattr(d, 'dialog') else 0
                last_msg_is_read = False
                last_msg_status = ""
                if d.message and d.message.out:
                    last_msg_is_read = bool(read_outbox_max_id > 0 and d.message.id <= read_outbox_max_id)
                    last_msg_status = "read" if last_msg_is_read else "sent"

                result.append({
                    "id": d.id,
                    "title": title,
                    "username": username,
                    "is_user": is_user,
                    "is_group": is_group,
                    "is_channel": is_channel,
                    "unread_count": unread,
                    "read_outbox_max_id": read_outbox_max_id,
                    "avatar": avatar_path,
                    "initials": get_initials(title),
                    "color": get_avatar_color(title),
                    "online": online,
                    "last_message": {
                        "text": last_msg_text,
                        "time": last_msg_time,
                        "date": last_msg_date,
                        "out": last_msg_out,
                        "is_read": last_msg_is_read,
                        "status": last_msg_status,
                        "media_type": media_type
                    }
                })

            self.dialogs_cache = result
            self.unread_total = total_unread
            return result
        except Exception as e:
            print(f"Error refreshing dialogs: {e}", file=sys.stderr)
            return self.dialogs_cache

    async def download_media_bg(self, media, target_path):
        try:
            if not os.path.exists(target_path):
                await self.client.download_media(media, file=target_path)
        except Exception:
            pass

    async def get_messages_for_chat(self, chat_id, limit=50):
        if not await self.client.is_user_authorized():
            return []
        try:
            cid = int(chat_id)
            entity = await self.client.get_entity(cid)
            messages = await self.client.get_messages(entity, limit=limit)
            
            read_outbox_max_id = 0
            chat_title = getattr(entity, "first_name", "") or getattr(entity, "title", "User")
            chat_avatar = self.cached_avatars.get(cid, "")
            is_group_or_channel = isinstance(entity, (Chat, Channel))

            for d in self.dialogs_cache:
                if d.get("id") == cid:
                    read_outbox_max_id = d.get("read_outbox_max_id", 0)
                    if d.get("avatar"):
                        chat_avatar = d["avatar"]
                    break

            if not hasattr(self, 'cached_senders'):
                self.cached_senders = {}

            result = []
            for m in messages:
                sender_name = "You" if m.out else chat_title
                sender_avatar = chat_avatar if not m.out else ""
                sender_color = get_avatar_color(sender_name)

                if not m.out and is_group_or_channel and m.sender_id:
                    if m.sender_id in self.cached_senders:
                        cached = self.cached_senders[m.sender_id]
                        sender_name = cached["name"]
                        sender_avatar = cached["avatar"]
                        sender_color = cached["color"]
                    else:
                        sender_name = "User"

                media_type = ""
                media_path = ""
                webpage_meta = None
                if m.media:
                    if isinstance(m.media, MessageMediaPhoto):
                        media_type = "photo"
                        photo_f = os.path.join(MEDIA_DIR, f"photo_{m.id}_{cid}.jpg")
                        if os.path.exists(photo_f):
                            media_path = photo_f
                        else:
                            asyncio.create_task(self.download_media_bg(m.media, photo_f))
                    elif isinstance(m.media, MessageMediaDocument):
                        media_type = "document"
                    elif isinstance(m.media, MessageMediaWebPage) and isinstance(m.media.webpage, WebPage):
                        media_type = "webpage"
                        wp = m.media.webpage
                        wp_photo = ""
                        if wp.photo:
                            wp_photo_f = os.path.join(MEDIA_DIR, f"webpage_{m.id}_{cid}.jpg")
                            if os.path.exists(wp_photo_f):
                                wp_photo = wp_photo_f
                            else:
                                asyncio.create_task(self.download_media_bg(wp.photo, wp_photo_f))

                        webpage_meta = {
                            "site_name": getattr(wp, "site_name", "") or "",
                            "title": getattr(wp, "title", "") or "",
                            "description": getattr(wp, "description", "") or "",
                            "url": getattr(wp, "url", "") or getattr(wp, "display_url", "") or "",
                            "photo": wp_photo
                        }

                dt = m.date
                time_str = dt.strftime("%H:%M") if dt else ""
                date_str = dt.strftime("%b %d, %Y") if dt else ""

                is_read = bool(m.out and read_outbox_max_id > 0 and m.id <= read_outbox_max_id)
                msg_status = "read" if is_read else ("sent" if m.out else "")

                reactions_list = []
                if hasattr(m, "reactions") and m.reactions and hasattr(m.reactions, "results"):
                    for r in m.reactions.results:
                        emoticon = ""
                        if isinstance(r.reaction, ReactionEmoji):
                            emoticon = r.reaction.emoticon
                        elif hasattr(r.reaction, "document_id"):
                            emoticon = "⭐"
                        if emoticon:
                            if emoticon in ("\u2764", "❤"):
                                emoticon = "❤️"
                            is_chosen = (getattr(r, "chosen_order", None) is not None) or bool(getattr(r, "chosen", False))
                            reactions_list.append({
                                "emoticon": emoticon,
                                "count": r.count,
                                "chosen": is_chosen
                            })

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
                    "status": msg_status,
                    "is_read": is_read,
                    "pinned": bool(getattr(m, "pinned", False)),
                    "is_edited": bool(getattr(m, "edit_date", None) is not None),
                    "reactions": reactions_list,
                    "media_type": media_type,
                    "media_path": media_path,
                    "webpage": webpage_meta,
                    "reply_to_msg_id": m.reply_to_msg_id if hasattr(m, "reply_to_msg_id") else None
                })
            
            if not hasattr(self, 'chat_messages_cache'):
                self.chat_messages_cache = {}
            self.chat_messages_cache[cid] = result
            return result
        except Exception as e:
            print(f"Error fetching messages for {chat_id}: {e}", file=sys.stderr)
            return getattr(self, 'chat_messages_cache', {}).get(int(chat_id) if str(chat_id).isdigit() else 0, [])

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
                await self.client.delete_dialog(entity, revoke=True)
                self.dialogs_cache = [d for d in self.dialogs_cache if d.get("id") != cid]
                await self.update_unread_count()
                return {"success": True, "chat_id": cid}
            except Exception as e:
                return {"success": False, "error": str(e)}

        elif action == "leave_chat":
            chat_id = cmd_dict.get("chat_id")
            if not chat_id:
                return {"success": False, "error": "chat_id required"}
            try:
                cid = int(chat_id)
                entity = await self.client.get_entity(cid)
                try:
                    if isinstance(entity, Channel):
                        await self.client(LeaveChannelRequest(channel=entity))
                    elif isinstance(entity, Chat):
                        await self.client(DeleteChatUserRequest(chat_id=cid, user_id='me'))
                    else:
                        await self.client.delete_dialog(entity, revoke=True)
                except Exception:
                    await self.client.delete_dialog(entity)
                self.dialogs_cache = [d for d in self.dialogs_cache if d.get("id") != cid]
                await self.update_unread_count()
                return {"success": True, "chat_id": cid}
            except Exception as e:
                return {"success": False, "error": str(e)}

        elif action == "report_spam_and_leave":
            chat_id = cmd_dict.get("chat_id")
            if not chat_id:
                return {"success": False, "error": "chat_id required"}
            try:
                cid = int(chat_id)
                entity = await self.client.get_entity(cid)
                try:
                    await self.client(ReportSpamRequest(peer=entity))
                except Exception:
                    try:
                        await self.client(ReportPeerRequest(peer=entity, reason=InputReportReasonSpam(), message="Spam and scam"))
                    except Exception:
                        pass
                try:
                    if isinstance(entity, Channel):
                        await self.client(LeaveChannelRequest(channel=entity))
                    elif isinstance(entity, Chat):
                        await self.client(DeleteChatUserRequest(chat_id=cid, user_id='me'))
                    else:
                        await self.client.delete_dialog(entity, revoke=True)
                except Exception:
                    await self.client.delete_dialog(entity)
                self.dialogs_cache = [d for d in self.dialogs_cache if d.get("id") != cid]
                await self.update_unread_count()
                return {"success": True, "chat_id": cid}
            except Exception as e:
                return {"success": False, "error": str(e)}

        elif action == "delete_message":
            chat_id = cmd_dict.get("chat_id")
            msg_id = cmd_dict.get("message_id")
            if not chat_id or not msg_id:
                return {"success": False, "error": "chat_id and message_id required"}
            try:
                cid = int(chat_id)
                mid = int(msg_id)
                entity = await self.client.get_entity(cid)
                try:
                    await self.client.delete_messages(entity, [mid], revoke=True)
                except Exception:
                    await self.client.delete_messages(entity, [mid])
                if cid in getattr(self, "chat_messages_cache", {}):
                    del self.chat_messages_cache[cid]
                return {"success": True, "chat_id": cid, "message_id": mid}
            except Exception as e:
                return {"success": False, "error": str(e)}

        elif action == "delete_messages":
            chat_id = cmd_dict.get("chat_id")
            msg_ids = cmd_dict.get("message_ids", [])
            if not chat_id or not msg_ids:
                return {"success": False, "error": "chat_id and message_ids required"}
            try:
                cid = int(chat_id)
                entity = await self.client.get_entity(cid)
                mids = [int(m) for m in msg_ids if str(m).isdigit()]
                try:
                    await self.client.delete_messages(entity, mids, revoke=True)
                except Exception:
                    await self.client.delete_messages(entity, mids)
                if cid in getattr(self, "chat_messages_cache", {}):
                    del self.chat_messages_cache[cid]
                return {"success": True, "chat_id": cid, "deleted_count": len(mids)}
            except Exception as e:
                return {"success": False, "error": str(e)}

        elif action == "edit_message":
            chat_id = cmd_dict.get("chat_id")
            msg_id = cmd_dict.get("message_id")
            text = cmd_dict.get("text", "")
            if not chat_id or not msg_id:
                return {"success": False, "error": "chat_id and message_id required"}
            try:
                cid = int(chat_id)
                mid = int(msg_id)
                entity = await self.client.get_entity(cid)
                await self.client.edit_message(entity, mid, text)
                if cid in getattr(self, "chat_messages_cache", {}):
                    del self.chat_messages_cache[cid]
                return {"success": True, "chat_id": cid, "message_id": mid, "text": text}
            except Exception as e:
                return {"success": False, "error": str(e)}

        elif action == "pin_message":
            chat_id = cmd_dict.get("chat_id")
            msg_id = cmd_dict.get("message_id")
            if not chat_id or not msg_id:
                return {"success": False, "error": "chat_id and message_id required"}
            try:
                cid = int(chat_id)
                mid = int(msg_id)
                entity = await self.client.get_entity(cid)
                await self.client.pin_message(entity, mid, notify=True)
                if cid in getattr(self, "chat_messages_cache", {}):
                    del self.chat_messages_cache[cid]
                return {"success": True, "chat_id": cid, "message_id": mid}
            except Exception as e:
                return {"success": False, "error": str(e)}

        elif action == "unpin_message":
            chat_id = cmd_dict.get("chat_id")
            msg_id = cmd_dict.get("message_id")
            if not chat_id:
                return {"success": False, "error": "chat_id required"}
            try:
                cid = int(chat_id)
                entity = await self.client.get_entity(cid)
                mid = int(msg_id) if msg_id else None
                await self.client.unpin_message(entity, mid)
                if cid in getattr(self, "chat_messages_cache", {}):
                    del self.chat_messages_cache[cid]
                return {"success": True, "chat_id": cid}
            except Exception as e:
                return {"success": False, "error": str(e)}

        elif action == "forward_messages":
            from_chat_id = cmd_dict.get("from_chat_id")
            to_chat_id = cmd_dict.get("to_chat_id")
            msg_ids = cmd_dict.get("message_ids", [])
            if not from_chat_id or not to_chat_id or not msg_ids:
                return {"success": False, "error": "from_chat_id, to_chat_id, and message_ids required"}
            try:
                fcid = int(from_chat_id)
                tcid = int(to_chat_id)
                f_entity = await self.client.get_entity(fcid)
                t_entity = await self.client.get_entity(tcid)
                mids = [int(m) for m in msg_ids if str(m).isdigit()]
                await self.client.forward_messages(t_entity, mids, f_entity)
                if tcid in getattr(self, "chat_messages_cache", {}):
                    del self.chat_messages_cache[tcid]
                return {"success": True, "to_chat_id": tcid, "forwarded_count": len(mids)}
            except Exception as e:
                return {"success": False, "error": str(e)}

        elif action == "send_reaction":
            chat_id = cmd_dict.get("chat_id")
            msg_id = cmd_dict.get("message_id")
            emoticon = cmd_dict.get("emoticon")
            if not chat_id or not msg_id:
                return {"success": False, "error": "chat_id and message_id required"}
            if emoticon in ("clear", "remove", "none", "rm", "delete", "empty", "", None):
                emoticon = ""
            try:
                cid = int(chat_id)
                mid = int(msg_id)
                entity = await self.client.get_entity(cid)
                reaction_list = [ReactionEmoji(emoticon=emoticon)] if emoticon else []
                await self.client(SendReactionRequest(peer=entity, msg_id=mid, reaction=reaction_list))
                if cid in getattr(self, "chat_messages_cache", {}):
                    del self.chat_messages_cache[cid]
                return {"success": True, "chat_id": cid, "message_id": mid, "emoticon": emoticon}
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
