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
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color surface: Color.popups.background
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

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

  property var selectedChat: null
  property var activeMessages: []
  property bool loadingMessages: false

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
    if (selectedChat) loadMessages(selectedChat.id)
  }

  property var messagesCache: ({})

  function selectChat(chat) {
    if (!chat) return
    root._lastMsgDigest = ""
    selectedChat = chat
    if (messagesCache[chat.id]) {
      activeMessages = messagesCache[chat.id]
    } else {
      activeMessages = []
    }
    loadMessages(chat.id)
    markChatRead(chat.id)
  }

  function selectChatById(chatId) {
    for (var i = 0; i < allChats.length; i++) {
      if (allChats[i].id === chatId) {
        selectChat(allChats[i])
        break
      }
    }
  }

  function closeActiveChat() {
    selectedChat = null
    activeMessages = []
  }

  function deleteChat(chatId) {
    if (!chatId) return
    actionProc.running = false
    actionProc.command = ["python3", Qt.resolvedUrl("omargram_ctl.py").toString().replace("file://", ""), "delete_chat", String(chatId)]
    actionProc.running = true

    allChats = allChats.filter(function(c) { return c.id !== chatId })
    if (messagesCache[chatId]) delete messagesCache[chatId]
    if (selectedChat && selectedChat.id === chatId) {
      closeActiveChat()
    }
  }

  function leaveChat(chatId) {
    if (!chatId) return
    actionProc.running = false
    actionProc.command = ["python3", Qt.resolvedUrl("omargram_ctl.py").toString().replace("file://", ""), "leave_chat", String(chatId)]
    actionProc.running = true

    allChats = allChats.filter(function(c) { return c.id !== chatId })
    if (messagesCache[chatId]) delete messagesCache[chatId]
    if (selectedChat && selectedChat.id === chatId) {
      closeActiveChat()
    }
  }

  function reportSpamAndLeave(chatId) {
    if (!chatId) return
    actionProc.running = false
    actionProc.command = ["python3", Qt.resolvedUrl("omargram_ctl.py").toString().replace("file://", ""), "report_spam", String(chatId)]
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
    actionProc.command = ["python3", Qt.resolvedUrl("omargram_ctl.py").toString().replace("file://", ""), "delete_message", String(chatId), String(messageId)]
    actionProc.running = true

    // Optimistically remove message from list and cache
    activeMessages = activeMessages.filter(function(m) { return m.id !== messageId })
    if (messagesCache[chatId]) {
      messagesCache[chatId] = messagesCache[chatId].filter(function(m) { return m.id !== messageId })
    }
  }

  function loadMessages(chatId) {
    if (!chatId) return
    loadingMessages = true
    messagesProc.running = false
    messagesProc.command = ["python3", Qt.resolvedUrl("omargram_ctl.py").toString().replace("file://", ""), "messages", String(chatId), "50"]
    messagesProc.running = true
  }

  function sendMessageToActiveChat(text) {
    if (!text || !selectedChat) return
    var cid = selectedChat.id
    
    var now = new Date()
    var hours = now.getHours()
    var mins = now.getMinutes()
    var timeStr = (hours < 10 ? "0" + hours : hours) + ":" + (mins < 10 ? "0" + mins : mins)
    
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
      media_path: ""
    }
    
    var currentMsgs = [optMsg].concat(activeMessages)
    activeMessages = currentMsgs
    messagesCache[cid] = currentMsgs

    sendProc.running = false
    sendProc.command = ["python3", Qt.resolvedUrl("omargram_ctl.py").toString().replace("file://", ""), "send", String(cid), text]
    sendProc.running = true
  }

  function markChatRead(chatId) {
    if (!chatId) return
    actionProc.running = false
    actionProc.command = ["python3", Qt.resolvedUrl("omargram_ctl.py").toString().replace("file://", ""), "mark_read", String(chatId)]
    actionProc.running = true

    var updated = []
    for (var i = 0; i < allChats.length; i++) {
      var c = Object.assign({}, allChats[i])
      if (c.id === chatId) c.unread_count = 0
      updated.push(c)
    }
    allChats = updated
  }

  function startQrLogin() {
    qrProc.running = false
    qrProc.command = ["python3", Qt.resolvedUrl("omargram_ctl.py").toString().replace("file://", ""), "start_qr"]
    qrProc.running = true
  }

  function sendPhoneCode(phone) {
    actionProc.running = false
    actionProc.command = ["python3", Qt.resolvedUrl("omargram_ctl.py").toString().replace("file://", ""), "send_code", phone]
    actionProc.running = true
  }

  function submitCode(code, pwd) {
    actionProc.running = false
    var args = ["submit_code", code]
    if (pwd) args.push(pwd)
    actionProc.command = ["python3", Qt.resolvedUrl("omargram_ctl.py").toString().replace("file://", "")].concat(args)
    actionProc.running = true
  }

  function logout() {
    actionProc.running = false
    actionProc.command = ["python3", Qt.resolvedUrl("omargram_ctl.py").toString().replace("file://", ""), "logout"]
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
    command: ["python3", Qt.resolvedUrl("omargram_ctl.py").toString().replace("file://", ""), "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text || "{}")
          var wasAuth = root.isAuthorized
          root.isAuthorized = d.authorized === true
          root.unreadCount = d.unread_total || 0
          if (d.user) {
            root.userName = d.user.name || ""
            root.userUsername = d.user.username || ""
            root.userAvatar = d.user.avatar || ""
            root.userInitials = d.user.initials || "ME"
          }
          if (!root.isAuthorized && root.opened && !root.qrPath) {
            root.startQrLogin()
          } else if (!wasAuth && root.isAuthorized) {
            dialogsProc.running = true
          }
        } catch (e) {}
      }
    }
  }

  property string _lastChatsDigest: ""

  Process {
    id: dialogsProc
    command: ["python3", Qt.resolvedUrl("omargram_ctl.py").toString().replace("file://", ""), "dialogs", "40"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text || "{}")
          if (d.success && d.chats) {
            var digest = JSON.stringify(d.chats)
            if (root._lastChatsDigest !== digest) {
              root._lastChatsDigest = digest
              root.allChats = d.chats
            }
            root.unreadCount = d.unread_total || 0
          }
        } catch (e) {}
      }
    }
  }

  property string _lastMsgDigest: ""

  Process {
    id: messagesProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.loadingMessages = false
        try {
          var d = JSON.parse(text || "{}")
          if (d.success && d.messages && d.chat_id) {
            root.messagesCache[d.chat_id] = d.messages
            if (root.selectedChat && String(root.selectedChat.id) === String(d.chat_id)) {
              var digest = JSON.stringify(d.messages)
              if (root._lastMsgDigest !== digest) {
                root._lastMsgDigest = digest
                root.activeMessages = d.messages
              }
            }
          }
        } catch (e) {}
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
    onExited: function() {
      root.refresh()
    }
  }

  // Background Poll Timer
  Timer {
    id: pollTimer
    interval: root.opened ? 2000 : 8000
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
        if (!root.isAuthorized) root.startQrLogin()
      }
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onCloseRequested: {
        if (root.selectedChat) root.closeActiveChat()
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
                text: "End-to-end MTProto encrypted via Telegram API"
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
            }
          }
        }
      }
    }
  }
}
