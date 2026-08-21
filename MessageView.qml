import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Chat message stream with message bubbles, media previews, and auto-scroll
Item {
  id: root
  property var p  // Panel root

  anchors.fill: parent

  Column {
    anchors.fill: parent
    spacing: 0

    // Chat Header
    BorderSurface {
      width: parent.width
      implicitHeight: Style.space(42)
      radius: Style.cornerRadius
      color: Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.04)
      borderSpec: Border.none

      Row {
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(8)

        // Avatar
        BorderSurface {
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(30); height: Style.space(30)
          radius: width / 2.0
          color: (p.selectedChat && p.selectedChat.color) ? p.selectedChat.color : Color.accent
          borderSpec: Border.none
          clip: true

          Image {
            visible: p.selectedChat && p.selectedChat.avatar !== ""
            anchors.fill: parent
            source: p.selectedChat && p.selectedChat.avatar ? "file://" + p.selectedChat.avatar : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 60; sourceSize.height: 60
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

        // Title and Status
        Column {
          width: parent.width - Style.space(120)
          anchors.verticalCenter: parent.verticalCenter
          spacing: 1

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: p.selectedChat ? p.selectedChat.title : ""
            color: p.foreground
            font.family: p.fontFamily
            font.pixelSize: Style.font.bodySmall
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
            font.pixelSize: Style.font.caption * 0.8
          }
        }

        // Header Actions
        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(4)

          PanelActionButton {
            iconText: "\uf021"
            tooltipText: "Refresh messages"
            foreground: p.foreground; hoverColor: Color.accent; fontFamily: p.fontFamily
            onClicked: p.loadMessages(p.selectedChat.id)
            RotationAnimator on rotation { running: p.messagesProcRunning; from: 0; to: 360; duration: 800; loops: Animation.Infinite }
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

    // Separator line
    Rectangle {
      width: parent.width; height: 1
      color: Qt.rgba(1, 1, 1, 0.06)
    }

    // Message List View
    ListView {
      id: msgListView
      width: parent.width
      height: parent.height - Style.space(43) - composerComp.height
      clip: true
      spacing: Style.space(8)
      topMargin: Style.space(8)
      bottomMargin: Style.space(8)
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

      delegate: Item {
        id: msgDelegate
        required property var modelData
        required property int index
        readonly property bool isOut: modelData.out === true
        width: msgListView.width
        implicitHeight: bubbleCol.implicitHeight

        Column {
          id: bubbleCol
          anchors.right: msgDelegate.isOut ? parent.right : undefined
          anchors.left: !msgDelegate.isOut ? parent.left : undefined
          anchors.rightMargin: msgDelegate.isOut ? Style.space(8) : 0
          anchors.leftMargin: !msgDelegate.isOut ? Style.space(8) : 0
          spacing: Style.space(2)
          width: Math.min(parent.width * 0.78, bubbleCard.implicitWidth)

          BorderSurface {
            id: bubbleCard
            implicitWidth: Math.min(msgListView.width * 0.78, Math.max(Style.space(80), bubbleContent.implicitWidth + Style.space(20)))
            implicitHeight: bubbleContent.implicitHeight + Style.space(12)
            radius: Style.space(12)
            color: msgDelegate.isOut ? Color.accent : Qt.rgba(1, 1, 1, 0.08)
            borderSpec: msgDelegate.isOut ? Border.none : Border.flat(Qt.rgba(1, 1, 1, 0.06), 1)

            Column {
              id: bubbleContent
              anchors.left: parent.left; anchors.right: parent.right
              anchors.margins: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)

              // Sender name for group chats
              Text {
                visible: !msgDelegate.isOut && modelData.sender_name !== "" && (p.selectedChat && (p.selectedChat.is_group || p.selectedChat.is_channel))
                textFormat: Text.PlainText
                text: modelData.sender_name || ""
                color: modelData.sender_color || Color.accent
                font.family: p.fontFamily
                font.pixelSize: Style.font.caption * 0.85
                font.bold: true
              }

              // Media photo preview
              Image {
                visible: modelData.media_path !== "" && modelData.media_path !== undefined
                width: Math.min(parent.width, Style.space(240))
                height: Style.space(140)
                source: modelData.media_path ? "file://" + modelData.media_path : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 480; sourceSize.height: 280
              }

              // Message Body Text
              Text {
                visible: modelData.text !== ""
                width: parent.width
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                text: modelData.text || ""
                color: msgDelegate.isOut ? "#ffffff" : p.foreground
                font.family: p.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              // Metadata Row (Time + Sent tick)
              Row {
                anchors.right: parent.right
                spacing: Style.space(3)

                Text {
                  textFormat: Text.PlainText
                  text: modelData.time || ""
                  color: msgDelegate.isOut ? Qt.rgba(1, 1, 1, 0.75) : p.dim
                  font.family: p.fontFamily
                  font.pixelSize: Style.space(8)
                }

                Text {
                  visible: msgDelegate.isOut
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

    // Bottom Message Composer
    Composer {
      id: composerComp
      p: root.p
      width: parent.width
    }
  }
}
