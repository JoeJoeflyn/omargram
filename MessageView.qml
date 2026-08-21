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
    boundsBehavior: Flickable.StopAtBounds
    verticalLayoutDirection: ListView.BottomToTop
    model: p.activeMessages

    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    // Message Row Delegate
    delegate: Item {
      id: msgRow
      required property var modelData
      required property int index
      readonly property bool isOut: modelData.out === true
      property bool isHovered: bubbleMouse.containsMouse || delBtnMouse.containsMouse
      property bool isSnapping: false

      width: msgListView.width
      height: bubbleContentCol.implicitHeight + Style.space(16)
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

      // 1. Incoming Sender Avatar (Positioned left of the bubble)
      Item {
        id: leftAvatar
        visible: !msgRow.isOut
        anchors.left: parent.left
        anchors.leftMargin: Style.space(6)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(8)
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

      // 2. Outgoing User Avatar (Positioned right of the bubble)
      Item {
        id: rightAvatar
        visible: msgRow.isOut
        anchors.right: parent.right
        anchors.rightMargin: Style.space(6)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(8)
        width: Style.space(28); height: Style.space(28)
        opacity: msgRow.isSnapping ? 0.0 : 1.0

        BorderSurface {
          anchors.fill: parent
          radius: width / 2.0
          color: Color.accent
          borderSpec: Border.none
          clip: true

          Image {
            visible: p.userAvatar !== "" && p.userAvatar !== undefined
            anchors.fill: parent
            source: p.userAvatar ? "file://" + p.userAvatar : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 56; sourceSize.height: 56
          }

          Text {
            visible: !p.userAvatar
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: p.userInitials || "ME"
            color: "#ffffff"
            font.family: p.fontFamily
            font.pixelSize: Style.font.caption * 0.8
            font.bold: true
          }
        }
      }

      // 3. Message Bubble Surface
      BorderSurface {
        id: bubbleSurface
        anchors.left: msgRow.isOut ? undefined : leftAvatar.right
        anchors.leftMargin: msgRow.isOut ? 0 : Style.space(6)
        anchors.right: msgRow.isOut ? rightAvatar.left : undefined
        anchors.rightMargin: msgRow.isOut ? Style.space(6) : 0
        anchors.top: parent.top
        width: Math.min(msgListView.width * 0.68, Math.max(Style.space(110), bubbleContentCol.implicitWidth + Style.space(24)))
        height: bubbleContentCol.implicitHeight + Style.space(16)
        radius: Style.space(14)
        color: msgRow.isOut ? Color.accent : Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.08)
        borderSpec: msgRow.isOut ? Border.none : Border.flat(Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.1), 1)

        MouseArea {
          id: bubbleMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.ArrowCursor
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
            visible: modelData.text !== ""
            width: parent.width
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            text: modelData.text || ""
            color: msgRow.isOut ? "#ffffff" : p.foreground
            font.family: p.fontFamily
            font.pixelSize: Style.font.bodySmall
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

          // Timestamp and status row
          Row {
            anchors.right: parent.right
            spacing: Style.space(6)

            // Delete Message Button (Static footprint with opacity fade = 0 layout resizing on hover)
            Item {
              width: Style.space(16)
              height: Style.space(14)
              opacity: (msgRow.isHovered && !msgRow.isSnapping) ? 1.0 : 0.0
              anchors.verticalCenter: parent.verticalCenter

              Text {
                anchors.centerIn: parent
                text: "\uf2ed"
                color: delBtnMouse.containsMouse ? p.urgent : (msgRow.isOut ? Qt.rgba(1, 1, 1, 0.85) : p.dim)
                font.family: p.fontFamily
                font.pixelSize: Style.space(10)
              }

              MouseArea {
                id: delBtnMouse
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  msgRow.snapAndRemove()
                }
              }
            }

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
}
