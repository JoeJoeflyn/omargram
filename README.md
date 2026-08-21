# OmarGram 💬

**Native, blazing-fast Telegram status bar client for the Omarchy Quattro Desktop.**

OmarGram brings your Telegram chats directly into the Omarchy bar — read messages, check unread counts, search conversations, and send replies instantly without keeping heavy Electron desktop apps or browser tabs open.

---

## ✨ Features

- 💬 **Live Unread Badge**: Real-time unread message counter directly in the Omarchy bar.
- 📱 **1-Click QR Code Login**: Scan the QR code with your phone (*Telegram Settings → Devices → Link Desktop Device*) to log in in 3 seconds.
- ⚡ **Two-Column Fluid Layout**: Sidebar with Direct Messages, Groups, and Channels + smooth-scrolling conversation stream.
- 🚀 **Instant Message Composer**: Quick-reply input with Enter to send and Shift+Enter for multiline formatting.
- 🎨 **Theme-Native Visuals**: Matches your active Omarchy colorway, dynamic accent colors, smooth spring transitions, and custom typography.
- 🪶 **Ultra Lightweight**: Consumes only ~15MB RAM vs 500MB+ for Telegram Desktop / Web.
- 🔒 **End-to-End MTProto Security**: Connects directly to Telegram MTProto servers via official Telegram API encryption.

---

## 📦 External Dependencies

OmarGram requires the following Python libraries for MTProto communication and QR code rendering:

| Dependency | Purpose | Package |
| :--- | :--- | :--- |
| `python-telethon` | Native Telegram MTProto API client | `python-telethon` (or `pip install telethon`) |
| `python-qrcode` | QR code generation for instant phone pairing | `python-qrcode` (or `pip install qrcode[pil]`) |
| `python-pillow` | Image handling and profile avatar caching | `python-pillow` (or `pip install pillow`) |

### Install Dependencies:

```bash
python3 -m pip install --user telethon qrcode[pil] pillow
```

---

## 📥 Installation

Install OmarGram using the Omarchy CLI:

```bash
omarchy plugin add https://github.com/JoeJoeflyn/omargram --enable
omarchy restart shell
```

### Manual Bar Configuration

Add `"omargram"` to your desired status bar section in `~/.config/omarchy/shell.json`:

```jsonc
{
  "bar": {
    "sections": {
      "right": [
        "omargram",
        "omarmail",
        "omaramp",
        "omarchy.audio"
      ]
    }
  }
}
```

---

## ⌨️ Shortcuts & Navigation

| Key | Action |
| :--- | :--- |
| `Click Bar Icon` | Toggle OmarGram popout window |
| `Enter` (in composer) | Send message immediately |
| `Shift + Enter` | Insert newline in message |
| `Click Chat` | Open chat & mark messages as read |
| `Esc` | Close active chat or hide panel |

---

## 🗑️ Removal & Uninstallation

To disable and remove OmarGram:

```bash
omarchy plugin disable omargram
omarchy plugin remove omargram
omarchy restart shell
```

To purge cached avatars and session data:

```bash
rm -rf ~/.config/omargram ~/.cache/omargram
```

---

## 📄 License

MIT © [JoeJoeflyn](https://github.com/JoeJoeflyn)
