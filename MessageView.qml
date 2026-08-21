import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Chat message stream with avatars, sender info, photos/media, and auto-scroll
Item {
  id: root
  property var p  // Panel root

  anchors.fill: parent

  // 1. Top Chat Header Bar
  BorderSurface {
    id: chatHeader
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: Style.space(46)
    radius: Style.cornerRadius
    color: Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.04)
    borderSpec: Border.none

    Row {
      anchors.fill: parent
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(8)

      // Header Avatar
      BorderSurface {
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(32); height: Style.space(32)
        radius: width / 2.0
        color: (p.selectedChat && p.selectedChat.color) ? p.selectedChat.color : Color.accent
        borderSpec: Border.none
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
          color: "#ffffff"
          font.family: p.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }

      // Title & Status Column
      Column {
        width: parent.width - Style.space(130)
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
          textFormat: Text.PlainText
          text: {
            if (!p.selectedChat) return ""
            if (p.selectedChat.online) return "online"
            if (p.selectedChat.is_channel) return "channel"
            if (p.selectedChat.is_group) return "group"
            return p.selectedChat.username ? "@" + p.selectedChat.username : "last seen recently"
          }
          color: (p.selectedChat && p.selectedChat.online) ? "#4caf50" : p.dim
          font.family: p.fontFamily
          font.pixelSize: Style.font.caption * 0.85
        }
      }

      // Header Action Buttons
      Row {
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

  // 3. Middle Messages Stream ListView
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
    model: p.activeMessages

    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Connections {
      target: p
      function onActiveMessagesChanged() {
        Qt.callLater(function() {
          msgListView.positionViewAtEnd()
        })
      }
    }

    // Message Row Delegate
    delegate: Item {
      id: msgRow
      required property var modelData
      required property int index
      readonly property bool isOut: modelData.out === true
      width: msgListView.width
      height: bubbleContentCol.implicitHeight + Style.space(16)

      // Incoming Sender Avatar (Positioned left of the bubble)
      Item {
        id: avatarContainer
        visible: !msgRow.isOut
        anchors.left: parent.left
        anchors.leftMargin: Style.space(6)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(8)
        width: Style.space(28); height: Style.space(28)

        BorderSurface {
          anchors.fill: parent
          radius: width / 2.0
          color: modelData.sender_color || Color.accent
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
            color: "#ffffff"
            font.family: p.fontFamily
            font.pixelSize: Style.font.caption * 0.8
            font.bold: true
          }
        }
      }

      // Message Bubble Surface
      BorderSurface {
        id: bubbleSurface
        anchors.left: msgRow.isOut ? undefined : avatarContainer.right
        anchors.leftMargin: msgRow.isOut ? 0 : Style.space(6)
        anchors.right: msgRow.isOut ? parent.right : undefined
        anchors.rightMargin: msgRow.isOut ? Style.space(8) : 0
        anchors.top: parent.top
        width: Math.min(msgListView.width * 0.72, Math.max(Style.space(100), bubbleContentCol.implicitWidth + Style.space(24)))
        height: bubbleContentCol.implicitHeight + Style.space(16)
        radius: Style.space(14)
        color: msgRow.isOut ? Color.accent : Qt.rgba(1, 1, 1, 0.08)
        borderSpec: msgRow.isOut ? Border.none : Border.flat(Qt.rgba(1, 1, 1, 0.06), 1)

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
            color: modelData.sender_color || Color.accent
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

          // Timestamp and status row
          Row {
            anchors.right: parent.right
            spacing: Style.space(4)

            Text {
              textFormat: Text.PlainText
              text: modelData.time || ""
              color: msgRow.isOut ? Qt.rgba(1, 1, 1, 0.75) : p.dim
              font.family: p.fontFamily
              font.pixelSize: Style.space(8)
            }

            Text {
              visible: msgRow.isOut
              text: "\uf00c"
              color: Qt.rgba(1, 1, 1, 0.85)
              font.family: p.fontFamily
              font.pixelSize: Style.space(8)
            }
          }
        }
      }
    }
  }
}
