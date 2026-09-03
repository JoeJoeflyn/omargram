import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Chat message stream with avatars for both sender and user, Omarchy theme sync, and authentic Telegram Thanos snap particle disintegration
Item {
  id: root
  property var p  // Panel root

  anchors.fill: parent

  function jumpToMessageId(targetId) {
    if (!targetId || !p.activeMessages) return
    for (var idx = 0; idx < p.activeMessages.length; idx++) {
      if (p.activeMessages[idx].id === targetId) {
        msgListView.positionViewAtIndex(idx, ListView.Center)
        break
      }
    }
  }

  function getRepliedMessage(replyToId) {
    if (!replyToId || !p.activeMessages) return null
    for (var i = 0; i < p.activeMessages.length; i++) {
      if (p.activeMessages[i].id === replyToId) {
        return p.activeMessages[i]
      }
    }
    return null
  }

  // 1. Top Chat Header Bar (Anchored layout — 0 text overlap)
  BorderSurface {
    id: chatHeader
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: Style.space(46)
    radius: Style.cornerRadius
    color: Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.04)
    borderSpec: Border.none

    Item {
      anchors.fill: parent
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)

      // Header Chat Avatar (Left)
      BorderSurface {
        id: headerAvatarBox
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(32); height: Style.space(32)
        radius: width / 2.0
        color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
        borderSpec: Border.flat(Color.accent, 1)
        clip: true

        Image {
          visible: p.selectedChat && p.selectedChat.avatar !== "" && p.selectedChat.avatar !== undefined
          anchors.fill: parent
          source: p.selectedChat && p.selectedChat.avatar ? "file://" + p.selectedChat.avatar : ""
          fillMode: Image.PreserveAspectCrop
          sourceSize.width: 64; sourceSize.height: 64
        }

        Text {
          visible: !p.selectedChat || !p.selectedChat.avatar
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: p.selectedChat ? p.selectedChat.initials : "TG"
          color: p.foreground
          font.family: p.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }

      // Header Action Buttons (Right)
      Row {
        id: headerActionBtns
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(4)

        // Sidebar Collapse / Expand Toggle
        PanelActionButton {
          iconText: p.sidebarCollapsed ? "\uf061" : "\uf060"
          tooltipText: p.sidebarCollapsed ? "Expand sidebar" : "Collapse sidebar"
          foreground: p.foreground; hoverColor: Color.accent; fontFamily: p.fontFamily
          onClicked: p.toggleSidebar()
        }

        // Report Spam and Leave (for scam/spam channels or groups)
        PanelActionButton {
          visible: p.selectedChat && (p.selectedChat.is_group || p.selectedChat.is_channel)
          iconText: "\uf071"
          tooltipText: "Report spam and leave"
          foreground: p.danger; hoverColor: p.danger; fontFamily: p.fontFamily
          onClicked: p.reportSpamAndLeave(p.selectedChat.id)
        }

        // Leave Channel / Group
        PanelActionButton {
          visible: p.selectedChat && (p.selectedChat.is_group || p.selectedChat.is_channel)
          iconText: "\uf2f5"
          tooltipText: (p.selectedChat && p.selectedChat.is_channel) ? "Leave channel" : "Leave group"
          foreground: p.foreground; hoverColor: p.danger; fontFamily: p.fontFamily
          onClicked: p.leaveChat(p.selectedChat.id)
        }

        PanelActionButton {
          iconText: "\uf021"
          tooltipText: "Refresh messages"
          foreground: p.foreground; hoverColor: Color.accent; fontFamily: p.fontFamily
          onClicked: p.loadMessages(p.selectedChat.id)
        }

        PanelActionButton {
          iconText: "\uf00c"
          tooltipText: "Mark chat as read"
          foreground: p.foreground; hoverColor: Color.accent; fontFamily: p.fontFamily
          onClicked: p.markChatRead(p.selectedChat.id)
        }

        PanelActionButton {
          iconText: "\uf00d"
          tooltipText: "Close chat"
          foreground: p.foreground; hoverColor: p.urgent; fontFamily: p.fontFamily
          onClicked: p.closeActiveChat()
        }
      }

      // Title & Status Column (Fills space between avatar and actions)
      Column {
        anchors.left: headerAvatarBox.right
        anchors.leftMargin: Style.space(8)
        anchors.right: headerActionBtns.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: p.selectedChat ? p.selectedChat.title : ""
          color: p.foreground
          font.family: p.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: {
            if (!p.selectedChat) return ""
            if (p.selectedChat.online) return "online"
            if (p.selectedChat.is_channel) return "channel"
            if (p.selectedChat.is_group) return "group"
            return p.selectedChat.username ? "@" + p.selectedChat.username : "last seen recently"
          }
          color: (p.selectedChat && p.selectedChat.online) ? Color.accent : p.dim
          font.family: p.fontFamily
          font.pixelSize: Style.font.caption * 0.85
          elide: Text.ElideRight
        }
      }
    }
  }

  // Header separator
  Rectangle {
    anchors.top: chatHeader.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 1
    color: Qt.rgba(1, 1, 1, 0.06)
  }

  // Pinned Messages (Under Header)
  property var pinnedMessages: {
    if (!p.activeMessages) return []
    var result = []
    for (var i = 0; i < p.activeMessages.length; i++) {
      if (p.activeMessages[i].pinned) result.push(p.activeMessages[i])
    }
    return result
  }
  property var pinnedMessage: pinnedMessages.length > 0 ? pinnedMessages[pinnedIndex % pinnedMessages.length] : null
  property int pinnedIndex: 0

  BorderSurface {
    id: pinnedBanner
    visible: root.pinnedMessage !== null
    anchors.top: chatHeader.bottom
    anchors.topMargin: Style.space(6)
    anchors.left: parent.left
    anchors.leftMargin: Style.space(8)
    anchors.right: parent.right
    anchors.rightMargin: Style.space(8)
    height: Style.space(30)
    radius: Style.space(8)
    color: Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.05)
    borderSpec: Border.flat(Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.08), 1)
    z: 10

    // Vertical rail on the left when multiple pinned messages
    Rectangle {
      visible: root.pinnedMessages.length > 1
      anchors.left: parent.left
      anchors.leftMargin: Style.space(10)
      anchors.top: parent.top
      anchors.topMargin: Style.space(5)
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(5)
      width: 2
      radius: 1
      color: Color.accent
    }

    Row {
      anchors.fill: parent
      anchors.leftMargin: Style.space(16)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(6)

      // "Pinned msg" title
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "Pinned Message"
        color: p.foreground
        font.family: p.fontFamily
        font.pixelSize: Style.font.caption * 0.85
        font.bold: true
      }

      // Counter if multiple pinned
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: root.pinnedMessages.length > 1 ? (root.pinnedIndex + 1 + "/" + root.pinnedMessages.length) : ""
        color: p.dim
        font.family: p.fontFamily
        font.pixelSize: Style.font.caption * 0.7
        visible: root.pinnedMessages.length > 1
      }

      // Truncated message preview
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - Style.space(110)
        textFormat: Text.PlainText
        text: root.pinnedMessage ? (root.pinnedMessage.text || "Media").replace(/\n/g, " ") : ""
        color: p.dim
        font.family: p.fontFamily
        font.pixelSize: Style.font.caption * 0.8
        elide: Text.ElideRight
        maximumLineCount: 1
        wrapMode: Text.NoWrap
        visible: text !== ""
      }

      // Pin icon on the right
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf08d"
        color: p.dim
        font.family: p.fontFamily
        font.pixelSize: Style.space(11)
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        if (root.pinnedMessages.length === 0) return
        var nextIdx = (root.pinnedIndex + 1) % root.pinnedMessages.length
        root.pinnedIndex = nextIdx
        var target = root.pinnedMessages[nextIdx]
        for (var idx = 0; idx < p.activeMessages.length; idx++) {
          if (p.activeMessages[idx].id === target.id) {
            msgListView.positionViewAtIndex(idx, ListView.Center)
            break
          }
        }
      }
    }
  }

  // 2. Bottom Message Composer
  Composer {
    id: composerComp
    visible: !p.selectMode
    p: root.p
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottomMargin: Style.space(4)
  }

  // Multi-Select Floating Action Bar
  BorderSurface {
    id: multiSelectBar
    visible: p.selectMode
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.space(10)
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.min(parent.width - Style.space(32), Style.space(360))
    height: Style.space(42)
    radius: Style.space(21)
    color: Color.popups.background
    borderSpec: Border.flat(Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.18), 1)
    z: 80

    Row {
      anchors.fill: parent
      anchors.leftMargin: Style.space(14)
      anchors.rightMargin: Style.space(14)
      spacing: Style.space(14)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: String(p.selectedMsgIds.length) + " selected"
        color: p.foreground
        font.family: p.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }

      // Forward button
      Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(3)
        opacity: p.selectedMsgIds.length > 0 ? 1.0 : 0.4

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "\uf064"
          color: Color.accent
          font.family: p.fontFamily
          font.pixelSize: Style.space(11)
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "Forward"
          color: Color.accent
          font.family: p.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        ToolTip.visible: fwdSelM.containsMouse
        ToolTip.delay: 350
        ToolTip.text: "Forward selected messages"

        MouseArea {
          id: fwdSelM
          anchors.fill: parent
          anchors.margins: -4
          hoverEnabled: true
          cursorShape: p.selectedMsgIds.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: {
            if (p.selectedMsgIds.length > 0) p.openForwardDialog(p.selectedMsgIds)
          }
        }
      }

      // Copy text button
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf0c5"
        color: copySelM.containsMouse ? Color.accent : p.foreground
        font.family: p.fontFamily
        font.pixelSize: Style.space(12)
        opacity: p.selectedMsgIds.length > 0 ? 1.0 : 0.4

        ToolTip.visible: copySelM.containsMouse
        ToolTip.delay: 350
        ToolTip.text: "Copy text"

        MouseArea {
          id: copySelM
          anchors.fill: parent
          anchors.margins: -6
          hoverEnabled: true
          cursorShape: p.selectedMsgIds.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: {
            if (p.selectedMsgIds.length > 0) p.copySelectedMessagesText()
          }
        }
      }

      // Delete button
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf1f8"
        color: delSelM.containsMouse ? p.danger : p.danger
        font.family: p.fontFamily
        font.pixelSize: Style.space(12)
        opacity: p.selectedMsgIds.length > 0 ? 1.0 : 0.4

        ToolTip.visible: delSelM.containsMouse
        ToolTip.delay: 350
        ToolTip.text: "Delete selected messages"

        MouseArea {
          id: delSelM
          anchors.fill: parent
          anchors.margins: -6
          hoverEnabled: true
          cursorShape: p.selectedMsgIds.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: {
            if (p.selectedMsgIds.length > 0) p.deleteSelectedMessages()
          }
        }
      }

      // Cancel button
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf00d"
        color: cancelSelM.containsMouse ? p.danger : p.dim
        font.family: p.fontFamily
        font.pixelSize: Style.space(12)

        ToolTip.visible: cancelSelM.containsMouse
        ToolTip.delay: 350
        ToolTip.text: "Cancel selection"

        MouseArea {
          id: cancelSelM
          anchors.fill: parent
          anchors.margins: -6
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: p.exitSelectMode()
        }
      }
    }
  }

  // 3. Middle Messages Stream ListView (BottomToTop = latest message at index 0 pinned to bottom)
  ListView {
    id: msgListView
    anchors.top: pinnedBanner.visible ? pinnedBanner.bottom : chatHeader.bottom
    anchors.topMargin: Style.space(6)
    anchors.bottom: p.selectMode ? multiSelectBar.top : composerComp.top
    anchors.bottomMargin: Style.space(6)
    anchors.left: parent.left
    anchors.right: parent.right
    clip: true
    spacing: Style.space(8)
    boundsBehavior: Flickable.DragOverBounds
    verticalLayoutDirection: ListView.BottomToTop
    model: p.activeMessages

    cacheBuffer: 2500
    pixelAligned: true
    flickDeceleration: 1400
    maximumFlickVelocity: 4500

    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    property int lastVisibleIndex: 0
    property bool isChatSwitching: false

    onMovementEnded: updateVisibleIndex()
    onFlickEnded: updateVisibleIndex()
    onContentYChanged: {
      if (!isChatSwitching && (moving || flicking)) {
        updateVisibleIndex()
      }
    }

    function updateVisibleIndex() {
      if (atYBeginning || contentY <= 15) {
        lastVisibleIndex = 0
      } else {
        var idx = indexAt(width / 2, height / 2)
        if (idx >= 0) lastVisibleIndex = idx
      }
    }

    Connections {
      target: p
      function onSelectedChatChanged() {
        msgListView.contentY = 0
        Qt.callLater(function() {
          msgListView.contentY = 0
          msgListView.positionViewAtBeginning()
        })
      }
      function onActiveMessagesChanged() {
        if (msgListView.lastVisibleIndex <= 1 || msgListView.atYBeginning) {
          Qt.callLater(function() {
            msgListView.positionViewAtBeginning()
          })
        }
      }
    }

    // Message Row Delegate
    delegate: Item {
      id: msgRow
      required property var modelData
      required property int index
      readonly property bool isOut: modelData.out === true
      property bool isHovered: bubbleMouse.containsMouse
      property bool isSnapping: false
      property var localReactions: (modelData && modelData.reactions) ? modelData.reactions : []

      onModelDataChanged: {
        if (modelData && modelData.reactions) {
          localReactions = modelData.reactions
        }
      }

      function toggleReaction(emoticon) {
        var normInput = p.normEmoji(emoticon)
        var currentChosen = null
        var rx = localReactions || []
        for (var k = 0; k < rx.length; k++) {
          if (rx[k].chosen) {
            currentChosen = p.normEmoji(rx[k].emoticon)
            break
          }
        }
        var isRemoving = (normInput === "clear" || normInput === "remove" || currentChosen === normInput)
        var targetEmoticon = isRemoving ? "clear" : (normInput || "👍")

        var rList = []
        for (var j = 0; j < rx.length; j++) {
          var item = Object.assign({}, rx[j])
          var itemNorm = p.normEmoji(item.emoticon)
          if (item.chosen) {
            item.count = Math.max(0, item.count - 1)
            item.chosen = false
          }
          if (itemNorm === targetEmoticon && !isRemoving) {
            item.count += 1
            item.chosen = true
          }
          if (item.count > 0) {
            item.emoticon = p.displayEmoji(item.emoticon)
            rList.push(item)
          }
        }
        if (!isRemoving && targetEmoticon && targetEmoticon !== "clear" && !rList.some(function(r) { return p.normEmoji(r.emoticon) === targetEmoticon })) {
          rList.push({ emoticon: p.displayEmoji(emoticon), count: 1, chosen: true })
        }
        localReactions = rList

        // Send to backend without touching the ListView model
        p.sendReactionBackend(p.selectedChat.id, modelData.id, targetEmoticon)
      }

      width: msgListView.width
      height: bubbleSurface.height + Style.space(8)
      opacity: isSnapping ? 0.0 : 1.0

      function snapAndRemove() {
        if (msgRow.isSnapping) return
        msgRow.isSnapping = true
        
        var mapped = bubbleSurface.mapToItem(thanosOverlay, 0, 0)
        var col = msgRow.isOut ? Color.accent : Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.85)
        
        thanosOverlay.disintegrate(mapped.x, mapped.y, bubbleSurface.width, bubbleSurface.height, col, function() {
          p.deleteMessage(p.selectedChat.id, modelData.id)
        })
      }

      readonly property bool isSelected: p.isMessageSelected(modelData.id)

      // Selection Checkbox (Visible in selectMode)
      BorderSurface {
        id: selectCheck
        visible: p.selectMode
        width: Style.space(20); height: Style.space(20)
        radius: width / 2
        anchors.verticalCenter: bubbleSurface.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Style.space(6)
        color: msgRow.isSelected ? Color.accent : Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.1)
        borderSpec: msgRow.isSelected ? Border.none : Border.flat(p.dim, 1)

        Text {
          visible: msgRow.isSelected
          anchors.centerIn: parent
          text: "\uf00c"
          color: "#ffffff"
          font.family: p.fontFamily
          font.pixelSize: Style.space(10)
        }

        MouseArea {
          anchors.fill: parent
          anchors.margins: -4
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: p.toggleSelectMessage(modelData.id)
        }
      }

      // 1. Incoming Sender Avatar (Only in group/channel chats)
      Item {
        id: leftAvatar
        visible: !msgRow.isOut && (p.selectedChat && (p.selectedChat.is_group || p.selectedChat.is_channel))
        anchors.left: selectCheck.visible ? selectCheck.right : parent.left
        anchors.leftMargin: Style.space(8)
        anchors.bottom: bubbleSurface.bottom
        width: Style.space(28); height: Style.space(28)
        opacity: msgRow.isSnapping ? 0.0 : 1.0

        BorderSurface {
          anchors.fill: parent
          radius: width / 2.0
          color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
          borderSpec: Border.none
          clip: true

          Image {
            visible: modelData.sender_avatar !== "" && modelData.sender_avatar !== undefined
            anchors.fill: parent
            source: modelData.sender_avatar ? "file://" + modelData.sender_avatar : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 56; sourceSize.height: 56
          }

          Text {
            visible: !modelData.sender_avatar
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: modelData.sender_initials || "TG"
            color: p.foreground
            font.family: p.fontFamily
            font.pixelSize: Style.font.caption * 0.8
            font.bold: true
          }
        }
      }

      // 2. Message Bubble Surface
      BorderSurface {
        id: bubbleSurface
        anchors.left: msgRow.isOut ? undefined : (leftAvatar.visible ? leftAvatar.right : (selectCheck.visible ? selectCheck.right : parent.left))
        anchors.leftMargin: msgRow.isOut ? 0 : (leftAvatar.visible ? Style.space(6) : (selectCheck.visible ? Style.space(8) : Style.space(10)))
        anchors.right: msgRow.isOut ? parent.right : undefined
        anchors.rightMargin: msgRow.isOut ? Style.space(10) : 0
        anchors.top: parent.top
        width: Math.min(msgListView.width * 0.72, Math.max(timeStatusRow.implicitWidth + Style.space(24), (modelData.reply_to_msg_id ? Style.space(160) : 0), (modelData.media_path || modelData.media_type === "photo" || modelData.media_type === "video" || modelData.media_type === "sticker" || (modelData.webpage && modelData.webpage.photo)) ? (msgListView.width * 0.65) : (bubbleText.implicitWidth + Style.space(20))))
        height: bubbleContentCol.implicitHeight + Style.space(14)
        radius: Style.space(16)
        color: msgRow.isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : (msgRow.isOut ? Color.accent : Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.15))
        borderSpec: msgRow.isOut ? Border.flat(Qt.darker(Color.accent, 1.25), 1) : Border.flat(Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.28), 1)

        MouseArea {
          id: bubbleMouse
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          cursorShape: p.selectMode ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: function(mouse) {
            if (p.selectMode) {
              p.toggleSelectMessage(modelData.id)
              return
            }
            if (mouse.button === Qt.RightButton) {
              var pt = bubbleMouse.mapToItem(root, mouse.x, mouse.y)
              msgContextMenu.targetMsg = modelData
              msgContextMenu.targetRow = msgRow
              msgContextMenu.showAt(pt.x, pt.y)
            }
          }
        }

        Column {
          id: bubbleContentCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.space(8)
          spacing: Style.space(4)

          // Sender name in group chats
          Text {
            visible: !msgRow.isOut && modelData.sender_name !== "" && (p.selectedChat && (p.selectedChat.is_group || p.selectedChat.is_channel))
            width: parent.width
            textFormat: Text.PlainText
            text: modelData.sender_name || ""
            color: Color.accent
            font.family: p.fontFamily
            font.pixelSize: Style.font.caption * 0.85
            font.bold: true
            elide: Text.ElideRight
          }

          // Quoted Reply Banner inside message bubble
          BorderSurface {
            id: replyQuoteBox
            visible: modelData.reply_to_msg_id !== undefined && modelData.reply_to_msg_id !== null && modelData.reply_to_msg_id > 0
            width: parent.width
            height: Style.space(34)
            radius: Style.space(4)
            color: msgRow.isOut ? Qt.rgba(0, 0, 0, 0.16) : Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.08)
            borderSpec: Border.flat(msgRow.isOut ? p.accentForeground : Color.accent, "0 0 0 2")

            readonly property var targetRepliedMsg: root.getRepliedMessage(modelData.reply_to_msg_id)
            readonly property string replySender: (modelData.reply_to_sender && modelData.reply_to_sender.length > 0) ? modelData.reply_to_sender : (targetRepliedMsg ? targetRepliedMsg.sender_name : "Message")
            readonly property string replyText: (modelData.reply_to_text && modelData.reply_to_text.length > 0) ? modelData.reply_to_text : (targetRepliedMsg ? (targetRepliedMsg.text || (targetRepliedMsg.media_type ? "Media" : "")) : ("#" + modelData.reply_to_msg_id))

            Column {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(6)
              spacing: Style.space(1)

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: replyQuoteBox.replySender
                color: msgRow.isOut ? p.accentForeground : Color.accent
                font.family: p.fontFamily
                font.pixelSize: Style.font.caption * 0.8
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: replyQuoteBox.replyText
                color: msgRow.isOut ? Qt.rgba(p.accentForeground.r, p.accentForeground.g, p.accentForeground.b, 0.85) : p.foreground
                font.family: p.fontFamily
                font.pixelSize: Style.font.caption * 0.78
                elide: Text.ElideRight
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              hoverEnabled: true
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onClicked: function(mouse) {
                if (mouse.button === Qt.LeftButton) {
                  root.jumpToMessageId(modelData.reply_to_msg_id)
                } else if (mouse.button === Qt.RightButton) {
                  var pt = replyQuoteBox.mapToItem(root, mouse.x, mouse.y)
                  msgContextMenu.targetMsg = modelData
                  msgContextMenu.targetRow = msgRow
                  msgContextMenu.showAt(pt.x, pt.y)
                }
              }
            }
          }

          // Attached Photo Image (Click to Maximize)
          BorderSurface {
            id: photoBox
            visible: modelData.media_type === "photo" || modelData.media_type === "sticker"
            width: parent.width
            height: Math.min(Style.space(200), width * 0.68)
            radius: Style.space(10)
            color: Qt.rgba(0, 0, 0, 0.25)
            borderSpec: Border.none
            clip: true
            z: 20

            Image {
              id: photoImg
              anchors.fill: parent
              source: modelData.media_path ? ("file://" + modelData.media_path) : (modelData.media_thumb ? ("file://" + modelData.media_thumb) : "")
              fillMode: Image.PreserveAspectCrop
              sourceSize.width: 600; sourceSize.height: 400
              smooth: true
              mipmap: true
            }

            // Placeholder if photo is still downloading
            BorderSurface {
              visible: photoImg.status !== Image.Ready && (!modelData.media_path || photoImg.status === Image.Loading || photoImg.status === Image.Null)
              anchors.fill: parent
              color: Qt.rgba(0, 0, 0, 0.45)
              borderSpec: Border.none

              Column {
                anchors.centerIn: parent
                spacing: Style.space(6)
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "\uf03e"
                  color: Color.accent
                  font.family: p.fontFamily
                  font.pixelSize: Style.space(22)
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "Photo • Click to View"
                  color: "#ffffff"
                  font.family: p.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }
            }

            // Hover overlay with maximize icon
            Rectangle {
              anchors.fill: parent
              color: Qt.rgba(0, 0, 0, 0.35)
              visible: photoMouse.containsMouse

              Row {
                anchors.centerIn: parent
                spacing: Style.space(6)
                Text {
                  text: "\uf00e"
                  color: "#ffffff"
                  font.family: p.fontFamily
                  font.pixelSize: Style.space(13)
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  text: "View Full Photo"
                  color: "#ffffff"
                  font.family: p.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }

            MouseArea {
              id: photoMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              z: 30
              onClicked: {
                var target = modelData.media_path || modelData.media_thumb
                p.openMediaViewer(target, "photo", modelData)
              }
            }
          }

          // Attached Video Card (Click to Play & Maximize)
          BorderSurface {
            id: videoCardBox
            visible: modelData.media_type === "video"
            width: parent.width
            height: Math.min(Style.space(200), width * 0.68)
            radius: Style.space(8)
            color: Qt.rgba(0, 0, 0, 0.35)
            borderSpec: Border.flat(Qt.rgba(1, 1, 1, 0.15), 1)
            clip: true
            z: 20

            // Video Thumbnail
            Image {
              id: vidThumbImg
              anchors.fill: parent
              source: (modelData.media_thumb && modelData.media_thumb !== "") ? ("file://" + modelData.media_thumb) : (modelData.media_path ? ("file://" + modelData.media_path) : "")
              fillMode: Image.PreserveAspectCrop
              sourceSize.width: 600; sourceSize.height: 400
              smooth: true
              mipmap: true
              opacity: 0.85
            }

            // Placeholder if thumbnail is still loading
            BorderSurface {
              visible: !modelData.media_thumb && !modelData.media_path
              anchors.fill: parent
              color: Qt.rgba(0, 0, 0, 0.45)
              borderSpec: Border.none

              Column {
                anchors.centerIn: parent
                spacing: Style.space(6)
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "\uf03d"
                  color: Color.accent
                  font.family: p.fontFamily
                  font.pixelSize: Style.space(24)
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "Video • Click to Play"
                  color: "#ffffff"
                  font.family: p.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }
            }

            // Dark gradient overlay
            Rectangle {
              anchors.fill: parent
              gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.2) }
                GradientStop { position: 0.7; color: Qt.rgba(0, 0, 0, 0.1) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.75) }
              }
            }

            // Large Center Play Button
            BorderSurface {
              anchors.centerIn: parent
              width: Style.space(44); height: Style.space(44)
              radius: width / 2
              color: videoMouse.containsMouse ? Color.accent : Qt.rgba(0, 0, 0, 0.65)
              borderSpec: Border.flat(videoMouse.containsMouse ? "#ffffff" : Color.accent, 1.5)

              Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: Style.space(1.5)
                text: "\uf04b"
                color: videoMouse.containsMouse ? "#ffffff" : Color.accent
                font.family: p.fontFamily
                font.pixelSize: Style.space(16)
              }
            }

            // Bottom Badges: Duration (Bottom Left) and Size (Bottom Right)
            Row {
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.margins: Style.space(8)
              spacing: Style.space(4)

              BorderSurface {
                height: Style.space(20)
                implicitWidth: durTxt.implicitWidth + Style.space(10)
                radius: Style.space(4)
                color: Qt.rgba(0, 0, 0, 0.7)
                borderSpec: Border.none

                Row {
                  anchors.centerIn: parent
                  spacing: Style.space(3)
                  Text {
                    text: "\uf03d"
                    color: Color.accent
                    font.family: p.fontFamily
                    font.pixelSize: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  Text {
                    id: durTxt
                    text: (modelData.media_info && modelData.media_info.formatted_duration) ? modelData.media_info.formatted_duration : "Video"
                    color: "#ffffff"
                    font.family: p.fontFamily
                    font.pixelSize: Style.font.caption * 0.8
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }
            }

            // File Size badge (Bottom Right)
            BorderSurface {
              anchors.bottom: parent.bottom
              anchors.right: parent.right
              anchors.margins: Style.space(8)
              height: Style.space(20)
              implicitWidth: sizeTxt.implicitWidth + Style.space(10)
              radius: Style.space(4)
              color: Qt.rgba(0, 0, 0, 0.7)
              borderSpec: Border.none

              Text {
                id: sizeTxt
                anchors.centerIn: parent
                text: (modelData.media_info && modelData.media_info.size) ? modelData.media_info.size : "Play"
                color: Qt.rgba(1, 1, 1, 0.85)
                font.family: p.fontFamily
                font.pixelSize: Style.font.caption * 0.8
                font.bold: true
              }
            }

            MouseArea {
              id: videoMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              z: 30
              onClicked: {
                p.openMediaViewer(modelData.media_path, "video", modelData)
              }
            }
          }

          // Message text body
          Text {
            id: bubbleText
            visible: modelData.text !== ""
            width: parent.width
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            text: modelData.text || ""
            color: msgRow.isOut ? p.accentForeground : p.foreground
            font.family: p.fontFamily
            font.pixelSize: Style.font.bodySmall
            lineHeight: 1.15
          }

          // Webpage / Social Media Link Preview Card
          BorderSurface {
            visible: modelData.webpage !== null && modelData.webpage !== undefined && (modelData.webpage.title !== "" || modelData.webpage.description !== "" || (modelData.webpage.photo !== "" && modelData.webpage.photo !== undefined))
            width: parent.width
            implicitHeight: metaCol.implicitHeight + Style.space(14)
            radius: Style.space(8)
            color: msgRow.isOut ? Qt.rgba(0, 0, 0, 0.22) : Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.06)
            borderSpec: Border.flat(msgRow.isOut ? p.accentForeground : Color.accent, "0 0 0 3")

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (modelData.webpage && modelData.webpage.url) {
                  Qt.openUrlExternally(modelData.webpage.url)
                }
              }
            }

            Column {
              id: metaCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(8)
              spacing: Style.space(4)

              // Site name badge (e.g. YouTube, Twitter / X, GitHub, Instagram)
              Text {
                visible: modelData.webpage && modelData.webpage.site_name !== ""
                width: parent.width
                textFormat: Text.PlainText
                text: (modelData.webpage && modelData.webpage.site_name) ? modelData.webpage.site_name : ""
                color: msgRow.isOut ? p.accentForeground : Color.accent
                font.family: p.fontFamily
                font.pixelSize: Style.font.caption * 0.85
                font.bold: true
                elide: Text.ElideRight
              }

              // Webpage Title
              Text {
                visible: modelData.webpage && modelData.webpage.title !== ""
                width: parent.width
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 2
                text: (modelData.webpage && modelData.webpage.title) ? modelData.webpage.title : ""
                color: msgRow.isOut ? p.accentForeground : p.foreground
                font.family: p.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                elide: Text.ElideRight
              }

              // Webpage Description snippet
              Text {
                visible: modelData.webpage && modelData.webpage.description !== ""
                width: parent.width
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 3
                text: (modelData.webpage && modelData.webpage.description) ? modelData.webpage.description : ""
                color: msgRow.isOut ? p.accentForegroundDim : Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.85)
                font.family: p.fontFamily
                font.pixelSize: Style.font.caption * 0.9
                elide: Text.ElideRight
              }

              // Webpage Thumbnail Preview Image (Click to View Full Photo)
              BorderSurface {
                visible: modelData.webpage && modelData.webpage.photo !== "" && modelData.webpage.photo !== undefined
                width: parent.width
                height: Math.min(Style.space(130), width * 0.52)
                radius: Style.space(6)
                color: Qt.rgba(0, 0, 0, 0.2)
                borderSpec: Border.none
                clip: true

                Image {
                  anchors.fill: parent
                  source: (modelData.webpage && modelData.webpage.photo) ? "file://" + modelData.webpage.photo : ""
                  fillMode: Image.PreserveAspectCrop
                  sourceSize.width: 500; sourceSize.height: 300
                }

                Rectangle {
                  anchors.fill: parent
                  color: Qt.rgba(0, 0, 0, 0.35)
                  visible: wpPhotoM.containsMouse

                  Text {
                    anchors.centerIn: parent
                    text: "\uf00e"
                    color: "#ffffff"
                    font.family: p.fontFamily
                    font.pixelSize: Style.space(14)
                  }
                }

                MouseArea {
                  id: wpPhotoM
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (modelData.webpage && modelData.webpage.photo) {
                      p.openMediaViewer(modelData.webpage.photo, "photo", modelData)
                    }
                  }
                }
              }
            }
          }

          // Interactive Reactions Flow (Rendered inside/below the message bubble)
          Flow {
            visible: msgRow.localReactions !== undefined && msgRow.localReactions !== null && msgRow.localReactions.length > 0
            width: parent.width
            spacing: Style.space(4)

            Repeater {
              model: msgRow.localReactions || []
              delegate: BorderSurface {
                required property var modelData
                required property int index
                readonly property bool isChosen: modelData.chosen === true

                height: Style.space(20)
                implicitWidth: rxRow.implicitWidth + Style.space(12)
                radius: Style.space(10)
                color: msgRow.isOut
                  ? (isChosen ? Qt.rgba(0, 0, 0, 0.38) : (rxMouse.containsMouse ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(0, 0, 0, 0.25)))
                  : (isChosen ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22) : (rxMouse.containsMouse ? Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.15) : Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.08)))
                borderSpec: msgRow.isOut
                  ? (isChosen ? Border.flat(Qt.rgba(1, 1, 1, 0.95), 1.5) : Border.flat(Qt.rgba(1, 1, 1, 0.3), 1))
                  : (isChosen ? Border.flat(Color.accent, 1.5) : Border.flat(Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.15), 1))

                Row {
                  id: rxRow
                  anchors.centerIn: parent
                  spacing: Style.space(4)

                  Text {
                    text: p.displayEmoji(modelData.emoticon) || "👍"
                    font.family: "Noto Color Emoji, Apple Color Emoji, Segoe UI Emoji, sans-serif"
                    font.pixelSize: Style.space(11)
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    text: String(modelData.count || 1)
                    color: msgRow.isOut ? p.accentForeground : (isChosen ? Color.accent : p.foreground)
                    font.family: p.fontFamily
                    font.pixelSize: Style.space(9)
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                MouseArea {
                  id: rxMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    msgRow.toggleReaction(modelData.emoticon)
                  }
                }
              }
            }
          }

          // Timestamp and status row
          Row {
            id: timeStatusRow
            anchors.right: parent.right
            spacing: Style.space(4)

            // Pinned indicator
            Text {
              visible: modelData.pinned === true
              text: "\uf08d"
              color: msgRow.isOut ? p.accentForegroundDim : Color.accent
              font.family: p.fontFamily
              font.pixelSize: Style.space(7.5)
              anchors.verticalCenter: parent.verticalCenter
            }

            // Edited indicator
            Text {
              visible: modelData.is_edited === true
              textFormat: Text.PlainText
              text: "edited"
              color: msgRow.isOut ? p.accentForegroundDim : p.dim
              font.family: p.fontFamily
              font.pixelSize: Style.space(7.5)
              font.italic: true
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              textFormat: Text.PlainText
              text: modelData.time || ""
              color: msgRow.isOut ? p.accentForegroundDim : p.dim
              font.family: p.fontFamily
              font.pixelSize: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
            }

            // Outgoing Message Status: Sent (single check ✓), Read/Seen (double check ✓✓)
            Row {
              visible: msgRow.isOut
              spacing: -3
              anchors.verticalCenter: parent.verticalCenter

              Text {
                text: "\uf00c"
                color: (modelData.status === "read" || modelData.is_read) ? p.accentForeground : p.accentForegroundDim
                font.family: p.fontFamily
                font.pixelSize: Style.space(8)
              }

              Text {
                visible: modelData.status === "read" || modelData.is_read
                text: "\uf00c"
                color: p.accentForeground
                font.family: p.fontFamily
                font.pixelSize: Style.space(8)
              }
            }
          }
        }
      }
    }

    // Loading overlay — small spinner, doesn't replace messages
    Item {
      visible: p.selectedChat && p.loadingMessages && (!p.activeMessages || p.activeMessages.length === 0)
      anchors.centerIn: parent
      width: Style.space(26)
      height: Style.space(26)

      Text {
        id: loadingIcon
        anchors.centerIn: parent
        text: "\uf110"
        color: p.dim
        font.family: p.fontFamily
        font.pixelSize: Style.space(26)
      }

      RotationAnimation {
        running: parent.visible
        loops: Animation.Infinite
        target: loadingIcon
        from: 0
        to: 360
        duration: 800
      }
    }

    // Empty state — only when chat has genuinely 0 messages
    Column {
      visible: p.selectedChat && p.messagesLoaded && !p.loadingMessages && (!p.activeMessages || p.activeMessages.length === 0)
      anchors.centerIn: parent
      spacing: Style.space(6)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "\uf4ad"
        color: p.dim
        font.family: p.fontFamily
        font.pixelSize: Style.space(26)
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: "No messages yet"
        color: p.dim
        font.family: p.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  // 4. Global Thanos Snap Particle Overlay (Dense, vibrant ash cloud)
  Item {
    id: thanosOverlay
    anchors.fill: msgListView
    z: 99
    clip: true
    enabled: false
    property var particles: []
    property bool running: false
    property var onFinishedCallback: null

    Canvas {
      id: particleCanvas
      anchors.fill: parent
      visible: thanosOverlay.running

      onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        var pts = thanosOverlay.particles
        for (var i = 0; i < pts.length; i++) {
          var pt = pts[i]
          if (pt.alpha > 0.01) {
            ctx.fillStyle = Qt.rgba(pt.r, pt.g, pt.b, pt.alpha)
            ctx.fillRect(pt.x, pt.y, pt.size, pt.size)
          }
        }
      }
    }

    Timer {
      id: particleTimer
      interval: 16
      repeat: true
      running: thanosOverlay.running
      onTriggered: {
        var pts = thanosOverlay.particles
        var aliveCount = 0
        for (var i = 0; i < pts.length; i++) {
          var pt = pts[i]
          if (pt.alpha > 0.01) {
            pt.x += pt.vx
            pt.y += pt.vy
            pt.vx += 0.08 // wind force to right
            pt.vy -= 0.04 // thermal lift
            pt.alpha -= pt.decay
            if (pt.alpha > 0.01) aliveCount++
          }
        }
        if (aliveCount === 0) {
          thanosOverlay.running = false
          thanosOverlay.particles = []
        } else {
          particleCanvas.requestPaint()
        }
      }
    }

    Timer {
      id: completeTimer
      interval: 480
      repeat: false
      onTriggered: {
        if (typeof thanosOverlay.onFinishedCallback === "function") {
          var cb = thanosOverlay.onFinishedCallback
          thanosOverlay.onFinishedCallback = null
          cb()
        }
      }
    }

    function disintegrate(startX, startY, w, h, baseColor, callback) {
      onFinishedCallback = callback
      completeTimer.start()

      var col = Color.accent
      if (baseColor) col = baseColor
      var r = col.r, g = col.g, b = col.b

      var newPts = []
      var count = Math.min(260, Math.max(140, Math.floor((w * h) / 70)))
      for (var i = 0; i < count; i++) {
        var px = startX + Math.random() * w
        var py = startY + Math.random() * h
        var progress = (px - startX) / (w || 1)
        var vx = 0.8 + Math.random() * 4.0 + progress * 2.5
        var vy = -(Math.random() * 4.2 + 1.2)
        var size = Math.random() < 0.3 ? 3.5 : (Math.random() < 0.7 ? 2.5 : 1.5)
        var decay = 0.014 + Math.random() * 0.02

        newPts.push({
          x: px, y: py,
          vx: vx, vy: vy,
          size: size,
          alpha: 1.0,
          decay: decay,
          r: r, g: g, b: b
        })
      }

      particles = particles.concat(newPts)
      running = true
    }
  }

  // Sleek Right-Click Context Menu for Messages (Reactions + Reply + Copy + Delete)
  Item {
    id: msgContextMenu
    anchors.fill: parent
    visible: targetMsg !== null
    z: 999

    property var targetMsg: null
    property var targetRow: null
    property real menuX: 0
    property real menuY: 0

    function showAt(px, py) {
      var estH = Style.space(270)
      var menuW = Style.space(190)
      var targetX = Math.max(Style.space(8), Math.min(px, root.width - menuW - Style.space(8)))
      var targetY = py
      if (py + estH > root.height - Style.space(10)) {
        targetY = Math.max(Style.space(10), py - estH)
      }
      menuX = targetX
      menuY = targetY
    }

    function hide() {
      targetMsg = null
      targetRow = null
    }

    // Dismiss backdrop
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: msgContextMenu.hide()
    }

    BorderSurface {
      id: msgMenuBox
      x: msgContextMenu.menuX
      y: Math.max(Style.space(8), Math.min(msgContextMenu.menuY, root.height - height - Style.space(8)))
      width: Style.space(190)
      height: msgMenuCol.implicitHeight + Style.space(8)
      radius: Style.cornerRadius
      color: Color.popups.background
      borderSpec: Border.flat(Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.15), 1)

      Column {
        id: msgMenuCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(4)
        spacing: Style.space(2)

        // Top Emoji Reactions Row (👍 ❤️ 🔥 😂 👏 🎉)
        BorderSurface {
          width: parent.width
          height: Style.space(34)
          radius: Style.space(6)
          color: Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.05)
          borderSpec: Border.none

          Row {
            anchors.centerIn: parent
            spacing: Style.space(6)

            Repeater {
              model: ["👍", "❤️", "🔥", "😂", "👏", "🎉"]
              delegate: Item {
                required property string modelData
                readonly property bool isChosen: msgContextMenu.targetMsg && msgContextMenu.targetMsg.reactions && msgContextMenu.targetMsg.reactions.some(function(r) { return p.normEmoji(r.emoticon) === p.normEmoji(modelData) && r.chosen })
                width: Style.space(24); height: Style.space(24)

                Rectangle {
                  anchors.fill: parent
                  radius: Style.space(4)
                  color: isChosen ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : (emojiM.containsMouse ? Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.1) : "transparent")
                }

                Text {
                  anchors.centerIn: parent
                  text: p.displayEmoji(modelData)
                  font.family: "Noto Color Emoji, Apple Color Emoji, Segoe UI Emoji, sans-serif"
                  font.pixelSize: Style.space(13)
                  scale: emojiM.containsMouse ? 1.3 : 1.0
                  Behavior on scale { NumberAnimation { duration: 90 } }
                }

                MouseArea {
                  id: emojiM
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (msgContextMenu.targetRow && typeof msgContextMenu.targetRow.toggleReaction === "function") {
                      msgContextMenu.targetRow.toggleReaction(modelData)
                    } else if (msgContextMenu.targetMsg) {
                      p.sendReactionBackend(p.selectedChat.id, msgContextMenu.targetMsg.id, modelData)
                    }
                    msgContextMenu.hide()
                  }
                }
              }
            }
          }
        }

        // Remove Reaction (Shown when message already has a chosen reaction)
        Rectangle {
          visible: (msgContextMenu.targetRow && msgContextMenu.targetRow.localReactions && msgContextMenu.targetRow.localReactions.some(function(r) { return r.chosen === true })) || (msgContextMenu.targetMsg && msgContextMenu.targetMsg.reactions && msgContextMenu.targetMsg.reactions.some(function(r) { return r.chosen === true }))
          width: parent.width
          height: Style.space(28)
          radius: Style.space(4)
          color: rmReactM.containsMouse ? Qt.rgba(p.danger.r, p.danger.g, p.danger.b, 0.12) : "transparent"

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf00d"
              color: p.danger
              font.family: p.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Remove Reaction"
              color: p.danger
              font.family: p.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          MouseArea {
            id: rmReactM
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (msgContextMenu.targetRow && typeof msgContextMenu.targetRow.toggleReaction === "function") {
                msgContextMenu.targetRow.toggleReaction("clear")
              } else if (msgContextMenu.targetMsg) {
                p.sendReactionBackend(p.selectedChat.id, msgContextMenu.targetMsg.id, "clear")
              }
              msgContextMenu.hide()
            }
          }
        }

        // 1. Reply
        Rectangle {
          width: parent.width
          height: Style.space(28)
          radius: Style.space(4)
          color: replyM.containsMouse ? Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.08) : "transparent"

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf112"
              color: p.foreground
              font.family: p.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Reply"
              color: p.foreground
              font.family: p.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          MouseArea {
            id: replyM
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (msgContextMenu.targetMsg) {
                p.replyToMessage(msgContextMenu.targetMsg)
              }
              msgContextMenu.hide()
            }
          }
        }

        // 2. Edit (Only for outgoing messages)
        Rectangle {
          visible: msgContextMenu.targetMsg && msgContextMenu.targetMsg.out === true
          width: parent.width
          height: Style.space(28)
          radius: Style.space(4)
          color: editM.containsMouse ? Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.08) : "transparent"

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf044"
              color: p.foreground
              font.family: p.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Edit Message"
              color: p.foreground
              font.family: p.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          MouseArea {
            id: editM
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (msgContextMenu.targetMsg) {
                p.startEditingMessage(msgContextMenu.targetMsg)
              }
              msgContextMenu.hide()
            }
          }
        }

        // 3. Pin / Unpin
        Rectangle {
          width: parent.width
          height: Style.space(28)
          radius: Style.space(4)
          color: pinM.containsMouse ? Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.08) : "transparent"

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf08d"
              color: p.foreground
              font.family: p.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: (msgContextMenu.targetMsg && msgContextMenu.targetMsg.pinned) ? "Unpin Message" : "Pin Message"
              color: p.foreground
              font.family: p.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          MouseArea {
            id: pinM
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (msgContextMenu.targetMsg) {
                if (msgContextMenu.targetMsg.pinned) {
                  p.unpinMessage(p.selectedChat.id, msgContextMenu.targetMsg.id)
                } else {
                  p.pinMessage(p.selectedChat.id, msgContextMenu.targetMsg.id)
                }
              }
              msgContextMenu.hide()
            }
          }
        }

        // 4. Forward
        Rectangle {
          width: parent.width
          height: Style.space(28)
          radius: Style.space(4)
          color: fwdM.containsMouse ? Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.08) : "transparent"

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf064"
              color: p.foreground
              font.family: p.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Forward"
              color: p.foreground
              font.family: p.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          MouseArea {
            id: fwdM
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (msgContextMenu.targetMsg) {
                p.openForwardDialog([msgContextMenu.targetMsg.id])
              }
              msgContextMenu.hide()
            }
          }
        }

        // 5. Select
        Rectangle {
          width: parent.width
          height: Style.space(28)
          radius: Style.space(4)
          color: selM.containsMouse ? Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.08) : "transparent"

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf058"
              color: p.foreground
              font.family: p.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Select"
              color: p.foreground
              font.family: p.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          MouseArea {
            id: selM
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (msgContextMenu.targetMsg) {
                p.enterSelectMode(msgContextMenu.targetMsg.id)
              }
              msgContextMenu.hide()
            }
          }
        }

        // 6. Copy Text
        Rectangle {
          visible: msgContextMenu.targetMsg && msgContextMenu.targetMsg.text !== ""
          width: parent.width
          height: Style.space(28)
          radius: Style.space(4)
          color: copyM.containsMouse ? Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.08) : "transparent"

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf0c5"
              color: p.foreground
              font.family: p.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Copy Text"
              color: p.foreground
              font.family: p.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          MouseArea {
            id: copyM
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (msgContextMenu.targetMsg) {
                p.copyToClipboard(msgContextMenu.targetMsg.text)
              }
              msgContextMenu.hide()
            }
          }
        }

        // 7. Delete Message (with Thanos Disintegration)
        Rectangle {
          width: parent.width
          height: Style.space(28)
          radius: Style.space(4)
          color: delM.containsMouse ? Qt.rgba(p.danger.r, p.danger.g, p.danger.b, 0.15) : "transparent"

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf1f8"
              color: p.danger
              font.family: p.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Delete Message"
              color: p.danger
              font.family: p.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
          }

          MouseArea {
            id: delM
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var row = msgContextMenu.targetRow
              var msg = msgContextMenu.targetMsg
              msgContextMenu.hide()
              if (row && typeof row.snapAndRemove === "function") {
                row.snapAndRemove()
              } else if (msg) {
                p.deleteMessage(p.selectedChat.id, msg.id)
              }
            }
          }
        }
      }
    }
  }
}
