import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Chat message stream with avatars for both sender and user, Omarchy theme sync, and authentic Telegram Thanos snap particle disintegration
Item {
  id: root
  property var p  // Panel root

  anchors.fill: parent

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

        // Report Spam and Leave (for scam/spam channels or groups)
        PanelActionButton {
          visible: p.selectedChat && (p.selectedChat.is_group || p.selectedChat.is_channel)
          iconText: "\uf071"
          tooltipText: "Report spam and leave"
          foreground: p.urgent; hoverColor: p.urgent; fontFamily: p.fontFamily
          onClicked: p.reportSpamAndLeave(p.selectedChat.id)
        }

        // Leave Channel / Group
        PanelActionButton {
          visible: p.selectedChat && (p.selectedChat.is_group || p.selectedChat.is_channel)
          iconText: "\uf2f5"
          tooltipText: (p.selectedChat && p.selectedChat.is_channel) ? "Leave channel" : "Leave group"
          foreground: p.foreground; hoverColor: p.urgent; fontFamily: p.fontFamily
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

  // 2. Bottom Message Composer
  Composer {
    id: composerComp
    p: root.p
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottomMargin: Style.space(4)
  }

  // 3. Middle Messages Stream ListView (BottomToTop = latest message at index 0 pinned to bottom)
  ListView {
    id: msgListView
    anchors.top: chatHeader.bottom
    anchors.topMargin: Style.space(6)
    anchors.bottom: composerComp.top
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
        // Preserve scroll position when reading history; never jump on reaction or background refresh!
        if (!msgListView.moving && msgListView.atYBeginning) {
          Qt.callLater(function() {
            if (msgListView.atYBeginning) {
              msgListView.positionViewAtBeginning()
            }
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
      property bool isHovered: bubbleMouse.containsMouse || actionCapsuleMouse.containsMouse
      property bool isSnapping: false

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

      // 1. Incoming Sender Avatar (Only in group/channel chats)
      Item {
        id: leftAvatar
        visible: !msgRow.isOut && (p.selectedChat && (p.selectedChat.is_group || p.selectedChat.is_channel))
        anchors.left: parent.left
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
        anchors.left: msgRow.isOut ? undefined : (leftAvatar.visible ? leftAvatar.right : parent.left)
        anchors.leftMargin: msgRow.isOut ? 0 : (leftAvatar.visible ? Style.space(6) : Style.space(10))
        anchors.right: msgRow.isOut ? parent.right : undefined
        anchors.rightMargin: msgRow.isOut ? Style.space(10) : 0
        anchors.top: parent.top
        width: Math.min(msgListView.width * 0.72, Math.max(timeStatusRow.implicitWidth + Style.space(24), (modelData.media_path || (modelData.webpage && modelData.webpage.photo)) ? (msgListView.width * 0.65) : (bubbleText.implicitWidth + Style.space(20))))
        height: bubbleContentCol.implicitHeight + Style.space(14)
        radius: Style.space(16)
        color: msgRow.isOut ? Color.accent : Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.08)
        borderSpec: msgRow.isOut ? Border.none : Border.flat(Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.1), 1)

        MouseArea {
          id: bubbleMouse
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          cursorShape: Qt.ArrowCursor
          onClicked: function(mouse) {
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

          // Attached Photo Image
          Image {
            visible: modelData.media_path !== "" && modelData.media_path !== undefined
            width: parent.width
            height: Math.min(Style.space(160), width * 0.6)
            source: modelData.media_path ? "file://" + modelData.media_path : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 500; sourceSize.height: 300
          }

          // Message text body
          Text {
            id: bubbleText
            visible: modelData.text !== ""
            width: parent.width
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            text: modelData.text || ""
            color: msgRow.isOut ? "#ffffff" : p.foreground
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
            borderSpec: Border.leftSpec(msgRow.isOut ? "#ffffff" : Color.accent, 3)

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
                color: msgRow.isOut ? Qt.rgba(1, 1, 1, 0.95) : Color.accent
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
                color: msgRow.isOut ? "#ffffff" : p.foreground
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
                color: msgRow.isOut ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.85)
                font.family: p.fontFamily
                font.pixelSize: Style.font.caption * 0.9
                elide: Text.ElideRight
              }

              // Webpage Thumbnail Preview Image
              Image {
                visible: modelData.webpage && modelData.webpage.photo !== "" && modelData.webpage.photo !== undefined
                width: parent.width
                height: Math.min(Style.space(130), width * 0.52)
                source: (modelData.webpage && modelData.webpage.photo) ? "file://" + modelData.webpage.photo : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 500; sourceSize.height: 300
              }
            }
          }

          // Interactive Reactions Flow (Rendered inside/below the message bubble)
          Flow {
            visible: modelData.reactions !== undefined && modelData.reactions !== null && modelData.reactions.length > 0
            width: parent.width
            spacing: Style.space(4)

            Repeater {
              model: modelData.reactions || []
              delegate: BorderSurface {
                required property var modelData
                required property int index
                readonly property bool isChosen: modelData.chosen === true

                height: Style.space(20)
                implicitWidth: rxRow.implicitWidth + Style.space(10)
                radius: Style.space(10)
                color: isChosen ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : (rxMouse.containsMouse ? Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.15) : (msgRow.isOut ? Qt.rgba(0, 0, 0, 0.22) : Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.08)))
                borderSpec: isChosen ? Border.flat(Color.accent, 1) : Border.none

                Row {
                  id: rxRow
                  anchors.centerIn: parent
                  spacing: Style.space(3)

                  Text {
                    text: modelData.emoticon || "👍"
                    font.pixelSize: Style.space(10)
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    text: String(modelData.count || 1)
                    color: msgRow.isOut ? "#ffffff" : p.foreground
                    font.family: p.fontFamily
                    font.pixelSize: Style.space(8.5)
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
                    p.sendReaction(p.selectedChat.id, msgRow.modelData.id, modelData.emoticon)
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

            Text {
              textFormat: Text.PlainText
              text: modelData.time || ""
              color: msgRow.isOut ? Qt.rgba(1, 1, 1, 0.75) : p.dim
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
                color: (modelData.status === "read" || modelData.is_read) ? "#ffffff" : Qt.rgba(1, 1, 1, 0.7)
                font.family: p.fontFamily
                font.pixelSize: Style.space(8)
              }

              Text {
                visible: modelData.status === "read" || modelData.is_read
                text: "\uf00c"
                color: "#ffffff"
                font.family: p.fontFamily
                font.pixelSize: Style.space(8)
              }
            }
          }
        }
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
      menuX = Math.max(8, Math.min(px, root.width - msgMenuBox.width - 8))
      menuY = Math.max(8, Math.min(py, root.height - msgMenuBox.implicitHeight - 8))
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
      y: msgContextMenu.menuY
      width: Style.space(200)
      implicitHeight: msgMenuCol.implicitHeight + Style.space(8)
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
                readonly property bool isChosen: msgContextMenu.targetMsg && msgContextMenu.targetMsg.reactions && msgContextMenu.targetMsg.reactions.some(function(r) { return r.emoticon === modelData && r.chosen })
                width: Style.space(24); height: Style.space(24)

                Rectangle {
                  anchors.fill: parent
                  radius: Style.space(4)
                  color: isChosen ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : (emojiM.containsMouse ? Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.1) : "transparent")
                }

                Text {
                  anchors.centerIn: parent
                  text: modelData
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
                    if (msgContextMenu.targetMsg) {
                      p.sendReaction(p.selectedChat.id, msgContextMenu.targetMsg.id, modelData)
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
          visible: msgContextMenu.targetMsg && msgContextMenu.targetMsg.reactions && msgContextMenu.targetMsg.reactions.some(function(r) { return r.chosen === true })
          width: parent.width
          height: Style.space(28)
          radius: Style.space(4)
          color: rmReactM.containsMouse ? Qt.rgba(p.urgent.r, p.urgent.g, p.urgent.b, 0.12) : "transparent"

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf00d"
              color: p.urgent
              font.family: p.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Remove Reaction"
              color: p.urgent
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
              if (msgContextMenu.targetMsg) {
                p.sendReaction(p.selectedChat.id, msgContextMenu.targetMsg.id, "clear")
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

        // 2. Copy Text
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

        // 3. Delete Message (with Thanos Disintegration)
        Rectangle {
          width: parent.width
          height: Style.space(28)
          radius: Style.space(4)
          color: delM.containsMouse ? Qt.rgba(p.urgent.r, p.urgent.g, p.urgent.b, 0.15) : "transparent"

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf2ed"
              color: p.urgent
              font.family: p.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Delete Message"
              color: p.urgent
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
