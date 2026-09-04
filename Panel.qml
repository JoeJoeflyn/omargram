import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Core popout window orchestrator for OmarGram Telegram client
Panel {
  id: root
  moduleName: "omargram"
  ipcTarget: "omargram"
  manageIpc: false

  property var anchorItem: null
  property bool openedFromHotkey: false
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color danger: "#ef4444"
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color surface: Color.popups.background
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color accentForeground: (Color.accent.r * 0.299 + Color.accent.g * 0.587 + Color.accent.b * 0.114) > 0.65 ? "#101112" : "#ffffff"
  readonly property color accentForegroundDim: (Color.accent.r * 0.299 + Color.accent.g * 0.587 + Color.accent.b * 0.114) > 0.65 ? Qt.rgba(0.06, 0.07, 0.07, 0.75) : Qt.rgba(1, 1, 1, 0.75)

  // ---- State
  property bool isAuthorized: false
  property string userName: ""
  property string userUsername: ""
  property string userAvatar: ""
  property string userInitials: "ME"
  property int unreadCount: 0

  property var allChats: []
  property var filteredChats: []
  property string chatFilter: "all" // "all", "users", "groups", "channels"
  property string searchQuery: ""
  property bool sidebarCollapsed: false

  function toggleSidebar() {
    sidebarCollapsed = !sidebarCollapsed
  }

  property var selectedChat: null
  property var activeMessages: []
  property bool loadingMessages: false
  property bool messagesLoaded: false

  property var editingMessage: null
  property bool selectMode: false
  property var selectedMsgIds: []
  property bool forwardModalOpen: false
  property var forwardMsgIds: []
  property var attachedFile: null
  property bool filePickerOpen: false
  property string filePickerTab: "pictures"
  property var pickerFiles: []
  property var currentDirEntries: []
  property bool searchRecursive: false
  property string pickerCurrentPath: ""
  property string pickerParentPath: ""
  property string pickerSearchQuery: ""
  property bool reopenAfterPick: false

  property var activeMediaViewer: null

  function openMediaViewer(path, type, msgData) {
    var pth = path || ""
    var thm = (msgData && msgData.media_thumb) ? msgData.media_thumb : pth
    if (!pth && msgData && msgData.id && msgData.chat_id) {
      var ext = (type === "video") ? ".mp4" : ((type === "sticker") ? ".webp" : ".jpg")
      pth = "/home/giogio/.cache/omargram/media/" + (type || "photo") + "_" + msgData.id + "_" + msgData.chat_id + ext
    }
    activeMediaViewer = {
      path: pth,
      thumb: thm || pth,
      type: type || "photo",
      message: msgData || null,
      info: (msgData && msgData.media_info) ? msgData.media_info : null
    }
  }

  function closeMediaViewer() {
    activeMediaViewer = null
  }

  function downloadMedia(chatId, messageId, mediaType) {
    if (!chatId || !messageId) return
    downloadMediaProc.running = false
    downloadMediaProc.command = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "download_media", String(chatId), String(messageId), mediaType || "video"]
    downloadMediaProc.running = true
  }

  function openMediaExternally(filePath, app) {
    if (!filePath) return
    openExtProc.running = false
    openExtProc.command = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "open_external", filePath, app || "xdg-open"]
    openExtProc.running = true
  }

  property string qrPath: ""
  property double qrTimestamp: 0

  readonly property bool messagesProcRunning: messagesProc.running
  readonly property bool dialogsProcRunning: dialogsProc.running

  Component.onCompleted: {
    statusProc.running = true
    dialogsProc.running = true
  }

  onSearchQueryChanged: filterChatsList()
  onChatFilterChanged: filterChatsList()
  onAllChatsChanged: filterChatsList()

  function filterChatsList() {
    var list = allChats || []
    var q = searchQuery.trim().toLowerCase()

    if (chatFilter === "users") list = list.filter(function(c) { return c.is_user })
    else if (chatFilter === "groups") list = list.filter(function(c) { return c.is_group })
    else if (chatFilter === "channels") list = list.filter(function(c) { return c.is_channel })

    if (q) {
      list = list.filter(function(c) {
        var t = (c.title || "").toLowerCase()
        var u = (c.username || "").toLowerCase()
        var m = (c.last_message && c.last_message.text) ? c.last_message.text.toLowerCase() : ""
        return t.indexOf(q) !== -1 || u.indexOf(q) !== -1 || m.indexOf(q) !== -1
      })
    }
    filteredChats = list
  }

  // ---- Lifecycle
  function open() {
    openedFromHotkey = false
    setCenterHoverRevealSuppressed(false)
    root.controller.show()
    root.refresh()
  }

  function openFromHotkey() {
    openedFromHotkey = true
    root.controller.show()
    root.refresh()
    Qt.callLater(function() { if (root.opened) setCenterHoverRevealSuppressed(true) })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  // ---- Actions
  function refresh() {
    if (!statusProc.running) statusProc.running = true
    if (!dialogsProc.running) dialogsProc.running = true
    // Background refresh — don't show loading spinner
    if (selectedChat) {
      _loadingChatKey = String(selectedChat.id) + (activeTopic ? "_" + String(activeTopic.id) : "")
      messagesProc.running = false
      var args = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "messages", String(selectedChat.id), "50"]
      if (activeTopic) args.push(String(activeTopic.id))
      messagesProc.command = args
      messagesProc.running = true
    }
  }

  property var messagesCache: ({})

  function selectChat(chat) {
    if (!chat) return
    // Same chat clicked — just reopen topic list for forum chats
    if (selectedChat && selectedChat.id === chat.id) {
      if (chat.is_forum) {
        activeTopic = null
        if (topicsCache[String(chat.id)]) {
          forumTopics = topicsCache[String(chat.id)]
          // Restore previous topic or select first
          if (forumTopics.length > 0) {
            var lastId = lastTopicPerChat[String(chat.id)]
            var found = null
            if (lastId) {
              for (var i = 0; i < forumTopics.length; i++) {
                if (forumTopics[i].id === lastId) { found = forumTopics[i]; break }
              }
            }
            selectTopic(found || forumTopics[0])
          }
        }
        loadForumTopics(chat.id)
      }
      return
    }
    selectedChat = chat
    activeTopic = null
    // Show cached topics instantly and restore previous topic
    if (chat.is_forum && topicsCache[String(chat.id)]) {
      forumTopics = topicsCache[String(chat.id)]
      if (forumTopics.length > 0) {
        var lastId2 = lastTopicPerChat[String(chat.id)]
        var found2 = null
        if (lastId2) {
          for (var j = 0; j < forumTopics.length; j++) {
            if (forumTopics[j].id === lastId2) { found2 = forumTopics[j]; break }
          }
        }
        selectTopic(found2 || forumTopics[0])
      }
    } else {
      forumTopics = []
    }
    // Show cached messages instantly if available
    var cacheKey = String(chat.id)
    if (messagesCache[cacheKey]) {
      activeMessages = messagesCache[cacheKey]
      loadingMessages = false
      messagesLoaded = true
    } else {
      activeMessages = []
      loadingMessages = true
      messagesLoaded = false
    }
    loadMessages(chat.id)
    markChatRead(chat.id)
    if (chat.is_forum && (chat.is_group || chat.is_channel)) {
      loadForumTopics(chat.id)
    }
  }

  function selectChatById(chatId) {
    for (var i = 0; i < allChats.length; i++) {
      if (allChats[i].id === chatId) {
        selectChat(allChats[i])
        break
      }
    }
  }

  property var replyingTo: null

  // ---- Forum Topics
  property var forumTopics: []
  property var activeTopic: null
  property bool loadingTopics: false
  property var topicsCache: ({})
  property var lastTopicPerChat: ({})
  readonly property bool topicSidebar: (settings && settings.topicLayout) ? settings.topicLayout === "sidebar" : true

  Process {
    id: topicsProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.loadingTopics = false
        try {
          var r = JSON.parse(text || "{}")
          if (r.success && r.topics) {
            root.forumTopics = r.topics
            if (root.selectedChat) {
              var chatKey = String(root.selectedChat.id)
              root.topicsCache[chatKey] = r.topics
              // Auto-select: restore previous topic, or select first
              if (!root.activeTopic && r.topics.length > 0) {
                var lastId = root.lastTopicPerChat[chatKey]
                var found = null
                if (lastId) {
                  for (var i = 0; i < r.topics.length; i++) {
                    if (r.topics[i].id === lastId) { found = r.topics[i]; break }
                  }
                }
                root.selectTopic(found || r.topics[0])
              }
            }
          }
        } catch(e) {}
      }
    }
  }

  function loadForumTopics(chatId) {
    if (!chatId) return
    // Show cached topics instantly
    var cacheKey = String(chatId)
    if (topicsCache[cacheKey]) {
      forumTopics = topicsCache[cacheKey]
      loadingTopics = false
    } else {
      loadingTopics = true
    }
    // Refresh in background
    topicsProc.running = false
    topicsProc.command = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "topics", String(chatId)]
    topicsProc.running = true
  }

  function selectTopic(topic) {
    activeTopic = topic
    if (selectedChat) {
      lastTopicPerChat[String(selectedChat.id)] = topic.id
    }
    var cacheKey = String(selectedChat.id) + "_" + String(topic.id)
    if (messagesCache[cacheKey]) {
      activeMessages = messagesCache[cacheKey]
      loadingMessages = false
      messagesLoaded = true
    } else {
      activeMessages = []
      loadingMessages = true
      messagesLoaded = false
    }
    if (selectedChat) {
      loadMessages(selectedChat.id)
      markChatRead(selectedChat.id)
    }
  }

  function clearTopic() {
    activeTopic = null
    var cacheKey = String(selectedChat.id)
    if (messagesCache[cacheKey]) {
      activeMessages = messagesCache[cacheKey]
      loadingMessages = false
      messagesLoaded = true
    } else {
      activeMessages = []
      loadingMessages = true
      messagesLoaded = false
    }
    if (selectedChat) loadMessages(selectedChat.id)
  }

  function clearTopicSelection() {
    activeTopic = null
    forumTopics = []
    if (selectedChat) loadMessages(selectedChat.id)
  }

  function replyToMessage(msg) {
    if (editingMessage) cancelEditingMessage()
    replyingTo = msg
  }

  function clearReply() {
    replyingTo = null
  }

  Process {
    id: copyProc
  }

  function copyToClipboard(text) {
    if (!text) return
    copyProc.running = false
    copyProc.command = ["wl-copy", text]
    copyProc.running = true
  }

  function closeActiveChat() {
    selectedChat = null
    activeMessages = []
    replyingTo = null
  }

  function deleteChat(chatId) {
    if (!chatId) return
    actionProc.running = false
    actionProc.command = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "delete_chat", String(chatId)]
    actionProc.running = true

    allChats = allChats.filter(function(c) { return c.id !== chatId })
    var dck = String(chatId)
    for (var k in messagesCache) { if (k.indexOf(dck + "_") === 0 || k === dck) delete messagesCache[k] }
    if (selectedChat && selectedChat.id === chatId) {
      closeActiveChat()
    }
  }

  function leaveChat(chatId) {
    if (!chatId) return
    actionProc.running = false
    actionProc.command = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "leave_chat", String(chatId)]
    actionProc.running = true

    allChats = allChats.filter(function(c) { return c.id !== chatId })
    var lck = String(chatId)
    for (var k2 in messagesCache) { if (k2.indexOf(lck + "_") === 0 || k2 === lck) delete messagesCache[k2] }
    if (selectedChat && selectedChat.id === chatId) {
      closeActiveChat()
    }
  }

  function reportSpamAndLeave(chatId) {
    if (!chatId) return
    actionProc.running = false
    actionProc.command = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "report_spam", String(chatId)]
    actionProc.running = true

    allChats = allChats.filter(function(c) { return c.id !== chatId })
    if (messagesCache[chatId]) delete messagesCache[chatId]
    if (selectedChat && selectedChat.id === chatId) {
      closeActiveChat()
    }
  }

  function deleteMessage(chatId, messageId) {
    if (!chatId || !messageId) return
    actionProc.running = false
    actionProc.command = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "delete_message", String(chatId), String(messageId)]
    actionProc.running = true

    // Optimistically remove message from list and cache
    activeMessages = activeMessages.filter(function(m) { return m.id !== messageId })
    var dk = String(chatId) + (activeTopic ? "_" + String(activeTopic.id) : "")
    if (messagesCache[dk]) {
      messagesCache[dk] = messagesCache[dk].filter(function(m) { return m.id !== messageId })
    }
  }

  // ---- Edit Message Actions
  function startEditingMessage(msg) {
    if (!msg) return
    if (replyingTo) clearReply()
    editingMessage = msg
  }

  function cancelEditingMessage() {
    editingMessage = null
  }

  function submitEditMessage(chatId, messageId, newText) {
    if (!chatId || !messageId || !newText) return
    editingMessage = null

    actionProc.running = false
    actionProc.command = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "edit", String(chatId), String(messageId), newText]
    actionProc.running = true

    // Optimistically update message text in cache and activeMessages
    var updated = []
    for (var i = 0; i < activeMessages.length; i++) {
      var m = Object.assign({}, activeMessages[i])
      if (m.id === messageId) {
        m.text = newText
        m.is_edited = true
      }
      updated.push(m)
    }
    activeMessages = updated
    if (messagesCache[chatId]) {
      messagesCache[chatId] = updated
    }
  }

  // ---- Pin / Unpin Actions
  function pinMessage(chatId, messageId) {
    if (!chatId || !messageId) return
    actionProc.running = false
    actionProc.command = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "pin", String(chatId), String(messageId)]
    actionProc.running = true

    var updated = []
    for (var i = 0; i < activeMessages.length; i++) {
      var m = Object.assign({}, activeMessages[i])
      if (m.id === messageId) m.pinned = true
      updated.push(m)
    }
    activeMessages = updated
    if (messagesCache[chatId]) messagesCache[chatId] = updated
  }

  function unpinMessage(chatId, messageId) {
    if (!chatId) return
    actionProc.running = false
    var args = ["unpin", String(chatId)]
    if (messageId) args.push(String(messageId))
    actionProc.command = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", "")].concat(args)
    actionProc.running = true

    var updated = []
    for (var i = 0; i < activeMessages.length; i++) {
      var m = Object.assign({}, activeMessages[i])
      if (!messageId || m.id === messageId) m.pinned = false
      updated.push(m)
    }
    activeMessages = updated
    if (messagesCache[chatId]) messagesCache[chatId] = updated
  }

  // ---- Multi-Select Actions
  function enterSelectMode(initialMsgId) {
    selectMode = true
    selectedMsgIds = initialMsgId ? [initialMsgId] : []
  }

  function exitSelectMode() {
    selectMode = false
    selectedMsgIds = []
  }

  function toggleSelectMessage(msgId) {
    if (!selectMode) selectMode = true
    var list = (selectedMsgIds || []).slice()
    var idx = list.indexOf(msgId)
    if (idx >= 0) {
      list.splice(idx, 1)
    } else {
      list.push(msgId)
    }
    selectedMsgIds = list
  }

  function isMessageSelected(msgId) {
    return (selectedMsgIds || []).indexOf(msgId) >= 0
  }

  function deleteSelectedMessages() {
    if (!selectedChat || !selectedMsgIds || selectedMsgIds.length === 0) return
    var toDelete = selectedMsgIds.slice()
    var cid = selectedChat.id

    actionProc.running = false
    var args = ["delete_batch", String(cid)].concat(toDelete.map(String))
    actionProc.command = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", "")].concat(args)
    actionProc.running = true

    activeMessages = activeMessages.filter(function(m) { return toDelete.indexOf(m.id) < 0 })
    var bk = String(cid) + (activeTopic ? "_" + String(activeTopic.id) : "")
    if (messagesCache[bk]) {
      messagesCache[bk] = messagesCache[bk].filter(function(m) { return toDelete.indexOf(m.id) < 0 })
    }
    exitSelectMode()
  }

  function copySelectedMessagesText() {
    if (!selectedMsgIds || selectedMsgIds.length === 0) return
    var texts = []
    for (var i = 0; i < activeMessages.length; i++) {
      if (selectedMsgIds.indexOf(activeMessages[i].id) >= 0) {
        var m = activeMessages[i]
        texts.push((m.sender_name ? m.sender_name + ": " : "") + (m.text || ""))
      }
    }
    if (texts.length > 0) {
      copyToClipboard(texts.reverse().join("\n\n"))
    }
    exitSelectMode()
  }

  // ---- Forward Message Actions
  function openForwardDialog(msgIds) {
    if (!msgIds || msgIds.length === 0) return
    forwardMsgIds = msgIds
    forwardModalOpen = true
  }

  function closeForwardDialog() {
    forwardModalOpen = false
    forwardMsgIds = []
  }

  function executeForward(toChatId) {
    if (!selectedChat || !toChatId || !forwardMsgIds || forwardMsgIds.length === 0) return
    var fromCid = selectedChat.id
    var ids = forwardMsgIds.slice()

    actionProc.running = false
    var args = ["forward", String(fromCid), String(toChatId)].concat(ids.map(String))
    actionProc.command = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", "")].concat(args)
    actionProc.running = true

    closeForwardDialog()
    exitSelectMode()
  }

  function normEmoji(e) {
    if (!e) return ""
    return String(e).replace(/\uFE0F/g, "")
  }

  function displayEmoji(e) {
    if (!e) return ""
    var n = normEmoji(e)
    if (n === "\u2764" || n === "❤") return "❤️"
    return e
  }

  function sendReactionBackend(chatId, messageId, emoticon) {
    if (!chatId || !messageId) return
    actionProc.running = false
    actionProc.command = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "reaction", String(chatId), String(messageId), emoticon || "clear"]
    actionProc.running = true
  }

  function sendReaction(chatId, messageId, emoticon) {
    if (!chatId || !messageId) return

    var normInput = normEmoji(emoticon)
    var currentChosen = null

    // Find if user already has an active chosen reaction on this message
    for (var i = 0; i < activeMessages.length; i++) {
      if (activeMessages[i].id === messageId) {
        var rx = activeMessages[i].reactions || []
        for (var k = 0; k < rx.length; k++) {
          if (rx[k].chosen) {
            currentChosen = normEmoji(rx[k].emoticon)
            break
          }
        }
        break
      }
    }

    var isRemoving = (normInput === "clear" || normInput === "remove" || currentChosen === normInput)
    var targetEmoticon = isRemoving ? "clear" : (normInput || "👍")

    actionProc.running = false
    actionProc.command = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "reaction", String(chatId), String(messageId), targetEmoticon]
    actionProc.running = true

    // Optimistically update message reaction in cache ONLY (do not reassign activeMessages to avoid ListView scroll resets)
    if (messagesCache[chatId]) {
      var updated = []
      for (var i = 0; i < messagesCache[chatId].length; i++) {
        var m = Object.assign({}, messagesCache[chatId][i])
        if (m.id === messageId) {
          var rList = []
          var rawList = m.reactions || []
          for (var j = 0; j < rawList.length; j++) {
            var item = Object.assign({}, rawList[j])
            var itemNorm = normEmoji(item.emoticon)
            if (item.chosen) {
              item.count = Math.max(0, item.count - 1)
              item.chosen = false
            }
            if (itemNorm === targetEmoticon && !isRemoving) {
              item.count += 1
              item.chosen = true
            }
            if (item.count > 0) {
              item.emoticon = displayEmoji(item.emoticon)
              rList.push(item)
            }
          }
          if (!isRemoving && targetEmoticon && targetEmoticon !== "clear" && !rList.some(function(r) { return normEmoji(r.emoticon) === targetEmoticon })) {
            rList.push({ emoticon: displayEmoji(emoticon), count: 1, chosen: true })
          }
          m.reactions = rList
        }
        updated.push(m)
      }
      messagesCache[chatId] = updated
    }
  }

  function loadMessages(chatId) {
    if (!chatId) return
    _loadingChatKey = String(chatId) + (activeTopic ? "_" + String(activeTopic.id) : "")
    // Only show spinner if no cached messages
    if (!messagesCache[_loadingChatKey]) {
      loadingMessages = true
    }
    messagesProc.running = false
    var args = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "messages", String(chatId), "50"]
    if (activeTopic) args.push(String(activeTopic.id))
    messagesProc.command = args
    messagesProc.running = true
  }

  function sendMessageToActiveChat(text) {
    if (!text || !selectedChat) return
    var cid = selectedChat.id
    
    var now = new Date()
    var hours = now.getHours()
    var mins = now.getMinutes()
    var timeStr = (hours < 10 ? "0" + hours : hours) + ":" + (mins < 10 ? "0" + mins : mins)

    var repId = replyingTo ? String(replyingTo.id) : ""
    var repSender = replyingTo ? (replyingTo.sender_name || "") : ""
    var repText = replyingTo ? (replyingTo.text || (replyingTo.media_type ? "Media" : "")) : ""
    
    var optMsg = {
      id: Date.now(),
      chat_id: cid,
      sender_name: userName || "You",
      sender_avatar: userAvatar,
      sender_initials: userInitials,
      sender_color: Color.accent,
      text: text,
      time: timeStr,
      date: "Today",
      out: true,
      status: "sent",
      is_read: false,
      media_type: "",
      media_path: "",
      reply_to_msg_id: repId ? Number(repId) : null,
      reply_to_sender: repSender,
      reply_to_text: repText
    }
    
    var cacheKey = String(cid) + (activeTopic ? "_" + String(activeTopic.id) : "")
    var currentMsgs = [optMsg].concat(activeMessages)
    activeMessages = currentMsgs
    messagesCache[cacheKey] = currentMsgs

    sendProc.running = false
    var sendArgs = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "send", String(cid), text]
    if (activeTopic) sendArgs.push("--topic", String(activeTopic.id))
    if (repId) sendArgs.push("--reply-to", repId)
    sendProc.command = sendArgs
    sendProc.running = true
    clearReply()
  }

  function attachFile(path) {
    if (!path) return
    var parts = path.split("/")
    var fname = parts[parts.length - 1]
    var isImg = /\.(png|jpe?g|webp|gif|bmp|svg)$/i.test(fname)
    attachedFile = {
      path: path,
      name: fname,
      preview: "file://" + path,
      isImage: isImg
    }
  }

  function clearAttachedFile() {
    attachedFile = null
  }

  function checkAndPasteClipboardImage() {
    pasteImageProc.running = false
    pasteImageProc.running = true
  }

  function openFilePicker(tab) {
    filePickerTab = tab || "pictures"
    pickerSearchQuery = ""
    searchRecursive = false
    filePickerOpen = true
    loadPickerFiles(filePickerTab)
  }

  function loadPickerFiles(tab) {
    filePickerTab = tab
    pickerSearchQuery = ""
    pickerFilesProc.running = false
    pickerFilesProc.command = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "list_files", tab]
    pickerFilesProc.running = true
  }

  function searchPickerFiles(query) {
    pickerSearchQuery = query
    if (!query || query.trim() === "") {
      root.pickerFiles = root.currentDirEntries
      return
    }
    var q = query.trim().toLowerCase()
    
    // 1. Instant fff-style in-memory filter (0ms latency, zero lag, zero process spawns)
    var localMatches = []
    if (root.currentDirEntries && root.currentDirEntries.length > 0) {
      for (var i = 0; i < root.currentDirEntries.length; i++) {
        var e = root.currentDirEntries[i]
        if (e && e.name && e.name.toLowerCase().indexOf(q) !== -1) {
          localMatches.push(e)
        }
      }
    }
    root.pickerFiles = localMatches

    // 2. If recursive search mode is enabled, run background fd search across subfolders
    if (root.searchRecursive) {
      searchFilesProc.running = false
      searchFilesProc.command = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "search", query.trim(), filePickerTab]
      searchFilesProc.running = true
    }
  }

  function runDeepSearch() {
    if (!pickerSearchQuery || pickerSearchQuery.trim() === "") return
    searchRecursive = true
    searchFilesProc.running = false
    searchFilesProc.command = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "search", pickerSearchQuery.trim(), filePickerTab]
    searchFilesProc.running = true
  }

  function closeFilePicker() {
    filePickerOpen = false
    pickerSearchQuery = ""
    searchRecursive = false
  }

  function openNativeFilePicker() {
    closeFilePicker()
    reopenAfterPick = true
    opened = false
    pickFileProc.running = false
    pickFileProc.running = true
  }

  function sendFileToActiveChat(filePath, caption) {
    if (!filePath || !selectedChat) return
    var cid = selectedChat.id
    
    var now = new Date()
    var hours = now.getHours()
    var mins = now.getMinutes()
    var timeStr = (hours < 10 ? "0" + hours : hours) + ":" + (mins < 10 ? "0" + mins : mins)
    
    var parts = filePath.split("/")
    var fname = parts[parts.length - 1]
    var isImg = /\.(png|jpe?g|webp|gif|bmp|svg)$/i.test(fname)
    
    var repId = replyingTo ? String(replyingTo.id) : ""
    var repSender = replyingTo ? (replyingTo.sender_name || "") : ""
    var repText = replyingTo ? (replyingTo.text || (replyingTo.media_type ? "Media" : "")) : ""

    var optMsg = {
      id: Date.now(),
      chat_id: cid,
      sender_name: userName || "You",
      sender_avatar: userAvatar,
      sender_initials: userInitials,
      sender_color: Color.accent,
      text: caption || "",
      time: timeStr,
      date: "Today",
      out: true,
      status: "sent",
      is_read: false,
      media_type: isImg ? "photo" : "document",
      media_path: isImg ? filePath : "",
      reply_to_msg_id: repId ? Number(repId) : null,
      reply_to_sender: repSender,
      reply_to_text: repText
    }
    
    var fileCacheKey = String(cid) + (activeTopic ? "_" + String(activeTopic.id) : "")
    var currentMsgs = [optMsg].concat(activeMessages)
    activeMessages = currentMsgs
    messagesCache[fileCacheKey] = currentMsgs
    clearAttachedFile()

    sendProc.running = false
    var cmd = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "send_file", String(cid), filePath]
    if (caption) cmd.push(caption)
    else cmd.push("")
    if (repId) cmd.push("--reply-to", repId)
    if (activeTopic) cmd.push("--topic", String(activeTopic.id))
    clearReply()

    sendProc.command = cmd
    sendProc.running = true
  }

  function markChatRead(chatId) {
    if (!chatId) return
    actionProc.running = false
    var args = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "mark_read", String(chatId)]
    if (activeTopic) args.push(String(activeTopic.id))
    actionProc.command = args
    actionProc.running = true

    var updated = []
    var unreadDelta = 0
    for (var i = 0; i < allChats.length; i++) {
      var c = Object.assign({}, allChats[i])
      if (String(c.id) === String(chatId)) {
        unreadDelta = c.unread_count || 0
        c.unread_count = 0
      }
      updated.push(c)
    }
    allChats = updated
    filterChatsList()
    if (unreadDelta > 0) {
      unreadCount = Math.max(0, unreadCount - unreadDelta)
    }

    // Clear topic unread count
    if (activeTopic && forumTopics.length > 0) {
      var topics = []
      for (var j = 0; j < forumTopics.length; j++) {
        var t = Object.assign({}, forumTopics[j])
        if (t.id === activeTopic.id) t.unread_count = 0
        topics.push(t)
      }
      forumTopics = topics
    }
  }

  function startQrLogin() {
    qrProc.running = false
    qrProc.command = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "start_qr"]
    qrProc.running = true
  }

  function sendPhoneCode(phone) {
    actionProc.running = false
    actionProc.command = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "send_code", phone]
    actionProc.running = true
  }

  function submitCode(code, pwd) {
    actionProc.running = false
    var args = ["submit_code", code]
    if (pwd) args.push(pwd)
    actionProc.command = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", "")].concat(args)
    actionProc.running = true
  }

  function logout() {
    actionProc.running = false
    actionProc.command = [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "logout"]
    actionProc.running = true
    isAuthorized = false
    selectedChat = null
    allChats = []
    activeMessages = []
    startQrLogin()
  }

  // ---- Processes
  Process {
    id: statusProc
    command: [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text || "{}")
          var wasAuth = root.isAuthorized
          if (d.running === true) {
            root.isAuthorized = d.authorized === true
            root.unreadCount = d.unread_total || 0
            if (d.user) {
              root.userName = d.user.name || ""
              root.userUsername = d.user.username || ""
              root.userAvatar = d.user.avatar || ""
              root.userInitials = d.user.initials || "ME"
            }
            if (d.authorized === false && root.opened && !root.qrPath) {
              root.startQrLogin()
            } else if (!wasAuth && root.isAuthorized) {
              dialogsProc.running = true
            }
          }
        } catch (e) {}
      }
    }
  }

  property string _lastChatsDigest: ""

  Process {
    id: dialogsProc
    command: [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "dialogs", "40"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text || "{}")
          if (d.success && d.chats) {
            if (root.selectedChat) {
              for (var k = 0; k < d.chats.length; k++) {
                if (String(d.chats[k].id) === String(root.selectedChat.id)) {
                  d.chats[k].unread_count = 0
                }
              }
            }
            var digest = JSON.stringify(d.chats)
            if (root._lastChatsDigest !== digest) {
              root._lastChatsDigest = digest
              root.allChats = d.chats
            }
            var count = 0
            if (d.chats) {
              for (var ci = 0; ci < d.chats.length; ci++) {
                count += (d.chats[ci].unread_count || 0)
              }
            }
            root.unreadCount = count
          }
        } catch (e) {}
      }
    }
  }

  property string _lastMsgDigest: ""
  property string _loadingChatKey: ""


  Process {
    id: messagesProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text || "{}")
          if (d.success && d.messages && d.chat_id) {
            var respKey = String(d.chat_id) + (root.activeTopic ? "_" + String(root.activeTopic.id) : "")
            root.messagesCache[respKey] = d.messages
            // Only update if this response is for the chat we're currently viewing
            if (root.selectedChat && (respKey === root._loadingChatKey || String(root.selectedChat.id) === String(d.chat_id))) {
              var digest = JSON.stringify(d.messages || [])
              // Skip reassigning activeMessages when nothing changed: a JS-array
              // model reassignment resets the ListView's contentY, which snaps the
              // view back to the latest message every poll (1500ms) and breaks scrolling.
              if (digest !== root._lastMsgDigest) {
                root._lastMsgDigest = digest
                root.activeMessages = d.messages || []
              }
              root.messagesLoaded = true
              root.loadingMessages = false
            }
          } else {
            root.messagesLoaded = true
            root.loadingMessages = false
          }
        } catch (e) {
          root.messagesLoaded = true
          root.loadingMessages = false
        }
      }
    }
  }

  Process {
    id: sendProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text || "{}")
          if (d.success && root.selectedChat) {
            root.loadMessages(root.selectedChat.id)
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: qrProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text || "{}")
          if (d.success && d.qr_path) {
            root.qrPath = d.qr_path
            root.qrTimestamp = Date.now()
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text || "{}")
          if (d.requires_password) {
            authView.waitingFor2Fa = true
            authView.waitingForCode = false
          } else if (d.success && authView.waitingFor2Fa) {
            authView.waitingFor2Fa = false
            authView.authCode = ""
            authView.twoFaPassword = ""
          } else if (d.error && !d.success) {
            authView.authError = d.error
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: pasteImageProc
    command: [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "paste_image"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text || "{}")
          if (d.success && d.has_image && d.file_path) {
            root.attachFile(d.file_path)
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: pickFileProc
    command: [Qt.resolvedUrl("omargram_sock.sh").toString().replace("file://", ""), "pick_file"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text || "{}")
          if (d.success && d.file_path && !d.cancelled) {
            root.attachFile(d.file_path)
          }
        } catch (e) {}
        if (root.reopenAfterPick) {
          root.reopenAfterPick = false
          root.openFromHotkey()
        }
      }
    }
  }

  Process {
    id: pickerFilesProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text || "{}")
          if (d.success && d.entries) {
            root.currentDirEntries = d.entries
            root.pickerFiles = d.entries
            root.pickerCurrentPath = d.current_path || ""
            root.pickerParentPath = d.parent_path || ""
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: searchFilesProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text || "{}")
          if (d.success && d.entries) {
            root.pickerFiles = d.entries
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: downloadMediaProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text || "{}")
          if (d.success && d.file_path) {
            if (root.activeMediaViewer && root.activeMediaViewer.message && root.activeMediaViewer.message.id === d.message_id) {
              var updated = Object.assign({}, root.activeMediaViewer)
              updated.path = d.file_path
              root.activeMediaViewer = updated
            }
            if (root.selectedChat && root.selectedChat.id === d.chat_id) {
              var msgs = []
              for (var i = 0; i < root.activeMessages.length; i++) {
                var m = Object.assign({}, root.activeMessages[i])
                if (m.id === d.message_id) {
                  m.media_path = d.file_path
                  if (m.media_info) m.media_info.is_downloaded = true
                }
                msgs.push(m)
              }
              root.activeMessages = msgs
              var cacheKey = String(d.chat_id) + (root.activeTopic ? "_" + String(root.activeTopic.id) : "")
              if (root.messagesCache[cacheKey]) root.messagesCache[cacheKey] = msgs
            }
          }
        } catch(e) {}
      }
    }
  }

  Process {
    id: openExtProc
  }

  // Background Poll Timer
  Timer {
    id: pollTimer
    interval: root.opened ? 1500 : 6000
    running: true; repeat: true; triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // IPC
  IpcHandler {
    target: "omargram"
    function open() { root.openFromHotkey() }
    function close() { root.close() }
    function toggle() { root.toggle() }
    function chat(chatId) {
      root.openFromHotkey()
      root.selectChatById(chatId)
    }
    function refresh() {
      root.refresh()
    }
  }

  // ---- Popup Window
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    contentWidth: panel.fittedContentWidth(Style.space(760))
    contentHeight: panel.fittedContentHeight(Style.space(520), Style.space(640))

    onOpenChanged: {
      if (open) {
        root.refresh()
      }
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onCloseRequested: {
        if (root.activeMediaViewer !== null) root.closeMediaViewer()
        else if (root.forwardModalOpen) root.closeForwardDialog()
        else if (root.filePickerOpen) root.closeFilePicker()
        else if (root.selectedChat) root.closeActiveChat()
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }

      BorderSurface {
        anchors.fill: parent
        radius: Style.cornerRadius * 1.5
        color: Color.popups.background
        borderSpec: Border.flat(Qt.rgba(1, 1, 1, 0.08), 1)
        clip: true

        // 1. Auth View (When not logged in)
        AuthView {
          id: authView
          visible: !root.isAuthorized
          p: root
        }

        // 2. Main Two-Column Layout (When logged in)
        Item {
          id: mainView
          visible: root.isAuthorized
          anchors.fill: parent
          anchors.margins: Style.space(8)

          // Left Chats Sidebar
          ChatList {
            id: chatListComp
            p: root
          }

          // Vertical Separator
          Rectangle {
            id: centerDivider
            anchors.left: chatListComp.right
            anchors.leftMargin: Style.space(8)
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: Qt.rgba(1, 1, 1, 0.07)
          }

          // Right Chat Stream / Message Area
          Item {
            id: rightPane
            anchors.left: centerDivider.right
            anchors.leftMargin: Style.space(8)
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            // Empty state (No chat selected)
            Column {
              visible: !root.selectedChat
              anchors.centerIn: parent
              spacing: Style.space(12)

              BorderSurface {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Style.space(58); height: Style.space(58)
                radius: width / 2.0
                color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
                borderSpec: Border.flat(Color.accent, 1)

                Text {
                  anchors.centerIn: parent
                  text: "\uf2c6"
                  color: Color.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title * 1.5
                }
              }

              Text {
                textFormat: Text.PlainText
                text: "Select a conversation to start chatting"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
              }

              Text {
                textFormat: Text.PlainText
                text: "Encrypted MTProto connection via official Telegram API"
                color: Qt.darker(root.dim, 1.2)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                anchors.horizontalCenter: parent.horizontalCenter
              }
            }

            // Active Chat Conversation Area
            MessageView {
              id: messageViewComp
              visible: root.selectedChat !== null
              p: root
              // Reset pinned index only when chat or topic changes
              Connections {
                target: root
                function onSelectedChatChanged() { messageViewComp.pinnedIndex = 0 }
                function onActiveTopicChanged() { messageViewComp.pinnedIndex = 0 }
              }
            }
          }
        }
      }
    }

    // Forward Message Modal
    Item {
      id: forwardModal
      visible: root.forwardModalOpen
      anchors.fill: parent
      z: 999

      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        MouseArea {
          anchors.fill: parent
          onClicked: root.closeForwardDialog()
        }
      }

      BorderSurface {
        width: Style.space(380)
        height: Style.space(460)
        anchors.centerIn: parent
        radius: Style.space(12)
        color: root.surface
        borderSpec: Border.flat(root.dim, 1)

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(14)
          spacing: Style.space(10)

          // Header
          Row {
            width: parent.width
            Text {
              text: "Forward to..."
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              width: parent.width - Style.space(30)
            }
            BorderSurface {
              width: Style.space(24); height: Style.space(24)
              radius: width / 2
              color: closeFwdM.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12) : "transparent"
              borderSpec: Border.none
              Text {
                anchors.centerIn: parent
                text: "\uf00d"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.space(12)
              }
              MouseArea {
                id: closeFwdM
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeForwardDialog()
              }
            }
          }

          // Search bar
          BorderSurface {
            width: parent.width
            height: Style.space(32)
            radius: Style.space(6)
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
            borderSpec: Border.none

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(6)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf002"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.space(11)
              }

              TextInput {
                id: fwdSearchInput
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(24)
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                selectByMouse: true
                clip: true
                Text {
                  visible: !fwdSearchInput.text && !fwdSearchInput.activeFocus
                  text: "Search chats..."
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }
          }

          // Chats list
          ListView {
            width: parent.width
            height: Style.space(340)
            clip: true
            spacing: Style.space(4)
            model: {
              var q = fwdSearchInput.text.trim().toLowerCase()
              var list = root.allChats || []
              if (q) {
                list = list.filter(function(c) {
                  return (c.title || "").toLowerCase().indexOf(q) >= 0 || (c.username || "").toLowerCase().indexOf(q) >= 0
                })
              }
              return list
            }

            delegate: BorderSurface {
              id: fwdChatRow
              required property var modelData
              required property int index
              width: parent.width
              height: Style.space(44)
              radius: Style.space(6)
              color: fwdRowM.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.03)
              borderSpec: Border.none

              Row {
                anchors.fill: parent
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                spacing: Style.space(10)

                // Avatar
                BorderSurface {
                  width: Style.space(30); height: Style.space(30)
                  anchors.verticalCenter: parent.verticalCenter
                  radius: width / 2
                  color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
                  borderSpec: Border.none
                  clip: true

                  Image {
                    visible: modelData.avatar !== "" && modelData.avatar !== undefined
                    anchors.fill: parent
                    source: modelData.avatar ? "file://" + modelData.avatar : ""
                    fillMode: Image.PreserveAspectCrop
                  }
                  Text {
                    visible: !modelData.avatar
                    anchors.centerIn: parent
                    text: modelData.initials || "TG"
                    color: Color.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.space(10)
                    font.bold: true
                  }
                }

                // Title
                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - Style.space(45)
                  spacing: Style.space(2)

                  Text {
                    text: modelData.title || "Chat"
                    textFormat: Text.PlainText
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width
                  }
                  Text {
                    text: modelData.username ? "@" + modelData.username : (modelData.is_channel ? "Channel" : (modelData.is_group ? "Group" : "User"))
                    textFormat: Text.PlainText
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    width: parent.width
                  }
                }
              }

              MouseArea {
                id: fwdRowM
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.executeForward(modelData.id)
                }
              }
            }
          }
        }
      }
    }

    // In-Panel File & Media Picker Modal
    Item {
      id: filePickerModal
      visible: root.filePickerOpen
      anchors.fill: parent
      z: 1000

      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.65)
        MouseArea {
          anchors.fill: parent
          onClicked: root.closeFilePicker()
        }
      }

      BorderSurface {
        width: Style.space(520)
        height: Style.space(500)
        anchors.centerIn: parent
        radius: Style.space(12)
        color: root.surface
        borderSpec: Border.flat(root.dim, 1)

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(14)
          spacing: Style.space(8)

          // Header
          Row {
            width: parent.width
            Text {
              text: "Attach Media & Files"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              width: parent.width - Style.space(30)
            }
            BorderSurface {
              width: Style.space(24); height: Style.space(24)
              radius: width / 2
              color: closeFilePickerM.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12) : "transparent"
              borderSpec: Border.none
              Text {
                anchors.centerIn: parent
                text: "\uf00d"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.space(12)
              }
              MouseArea {
                id: closeFilePickerM
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeFilePicker()
              }
            }
          }

          // Live Search Bar
          BorderSurface {
            width: parent.width
            height: Style.space(34)
            radius: Style.space(6)
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
            borderSpec: Border.controlSpec(pickerSearchInput.activeFocus ? "focused" : "normal", root.foreground, Color.accent)

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(6)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf002"
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.space(12)
              }

              TextInput {
                id: pickerSearchInput
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(48)
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                selectByMouse: true
                clip: true

                Text {
                  visible: !pickerSearchInput.text && !pickerSearchInput.activeFocus
                  text: "Type to search files (e.g. screenshot, image, pdf)..."
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                onTextChanged: {
                  searchDebounceTimer.restart()
                }

                Keys.onReturnPressed: {
                  root.runDeepSearch()
                }
                Keys.onEscapePressed: {
                  root.closeFilePicker()
                }

                Timer {
                  id: searchDebounceTimer
                  interval: 60
                  repeat: false
                  onTriggered: root.searchPickerFiles(pickerSearchInput.text)
                }
              }

              Text {
                visible: pickerSearchInput.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf00d"
                color: clearSearchM.containsMouse ? root.danger : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.space(11)

                MouseArea {
                  id: clearSearchM
                  anchors.fill: parent
                  anchors.margins: -4
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    pickerSearchInput.text = ""
                    root.loadPickerFiles(root.filePickerTab)
                  }
                }
              }
            }
          }

          // Scope / Shortcuts Bar
          Row {
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: [
                { id: "pictures", label: "Pictures", icon: "\uf03e" },
                { id: "downloads", label: "Downloads", icon: "\uf019" },
                { id: "home", label: "Home", icon: "\uf015" }
              ]

              delegate: BorderSurface {
                required property var modelData
                height: Style.space(26)
                radius: Style.space(6)
                color: root.filePickerTab === modelData.id ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : (tabM.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04))
                borderSpec: root.filePickerTab === modelData.id ? Border.controlSpec("active", root.foreground, Color.accent) : Border.none
                implicitWidth: tabRow.implicitWidth + Style.space(14)

                Row {
                  id: tabRow
                  anchors.centerIn: parent
                  spacing: Style.space(5)

                  Text {
                    text: modelData.icon
                    color: root.filePickerTab === modelData.id ? Color.accent : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption * 0.9
                  }

                  Text {
                    text: modelData.label
                    color: root.filePickerTab === modelData.id ? root.foreground : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption * 0.9
                    font.bold: root.filePickerTab === modelData.id
                  }
                }

                MouseArea {
                  id: tabM
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.filePickerTab = modelData.id
                    if (pickerSearchInput.text.trim() !== "") {
                      root.searchPickerFiles(pickerSearchInput.text)
                    } else {
                      root.loadPickerFiles(modelData.id)
                    }
                  }
                }
              }
            }
          }

          // Path / Search Status Bar
          BorderSurface {
            width: parent.width
            height: Style.space(28)
            radius: Style.space(6)
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
            borderSpec: Border.none

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(6)
              anchors.rightMargin: Style.space(6)
              spacing: Style.space(6)

              // Up button (when browsing)
              BorderSurface {
                visible: pickerSearchInput.text === "" && root.pickerParentPath !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(20); height: Style.space(20)
                radius: Style.space(4)
                color: upBtnM.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"
                borderSpec: Border.none

                Text {
                  anchors.centerIn: parent
                  text: "\uf062"
                  color: Color.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(10)
                }

                MouseArea {
                  id: upBtnM
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.pickerParentPath) root.loadPickerFiles(root.pickerParentPath)
                  }
                }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (upBtnM.parent.visible ? Style.space(28) : 0)
                text: pickerSearchInput.text !== "" ? ("Search results for \"" + pickerSearchInput.text + "\" (" + (root.pickerFiles ? root.pickerFiles.length : 0) + " matches)") : root.pickerCurrentPath.replace(/^\/home\/[^\/]+/, "~")
                textFormat: Text.PlainText
                color: pickerSearchInput.text !== "" ? Color.accent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption * 0.95
                elide: Text.ElideMiddle
              }
            }
          }

          // Files & Folders List
          ListView {
            id: pickerList
            width: parent.width
            height: Style.space(310)
            clip: true
            spacing: Style.space(4)
            model: root.pickerFiles

            delegate: BorderSurface {
              id: fileRow
              required property var modelData
              required property int index
              width: parent.width
              height: Style.space(44)
              radius: Style.space(6)
              color: fileRowM.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.03)
              borderSpec: fileRowM.containsMouse ? Border.flat(Color.accent, 1) : Border.none

              Row {
                anchors.fill: parent
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                spacing: Style.space(10)

                // Thumbnail / Icon
                BorderSurface {
                  width: Style.space(32); height: Style.space(32)
                  anchors.verticalCenter: parent.verticalCenter
                  radius: Style.space(6)
                  color: Qt.rgba(0, 0, 0, 0.3)
                  borderSpec: Border.none
                  clip: true

                  Image {
                    visible: !modelData.is_dir && modelData.is_image
                    anchors.fill: parent
                    source: (!modelData.is_dir && modelData.is_image) ? ("file://" + modelData.path) : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 64
                    sourceSize.height: 64
                    asynchronous: true
                    cache: true
                    smooth: true
                  }

                  Text {
                    visible: modelData.is_dir || !modelData.is_image
                    anchors.centerIn: parent
                    text: modelData.is_dir ? "\uf07b" : "\uf15b"
                    color: modelData.is_dir ? "#eab308" : Color.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                  }
                }

                // Info
                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - Style.space(50)
                  spacing: Style.space(2)

                  Text {
                    text: modelData.name || "File"
                    textFormat: Text.PlainText
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: modelData.is_dir
                    elide: Text.ElideRight
                    width: parent.width
                  }

                  Text {
                    text: (modelData.is_dir ? "Folder" : ((modelData.dir ? (modelData.dir + " • ") : "") + (modelData.size ? ((modelData.size / 1024 > 1024) ? ((modelData.size / (1024*1024)).toFixed(1) + " MB") : (Math.round(modelData.size / 1024) + " KB")) : "")))
                    textFormat: Text.PlainText
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption * 0.85
                    elide: Text.ElideRight
                    width: parent.width
                  }
                }
              }

              MouseArea {
                id: fileRowM
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (modelData.is_dir) {
                    pickerSearchInput.text = ""
                    root.loadPickerFiles(modelData.path)
                  } else {
                    root.attachFile(modelData.path)
                    root.closeFilePicker()
                  }
                }
              }
            }
          }
        }
      }
    }

    // 5. Fullscreen Media Viewer Modal (Photos & Videos)
    MediaModal {
      id: mediaModalComp
      p: root
      z: 10000
    }
  }
}
