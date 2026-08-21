import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Sidebar displaying chats, search, filters, and user profile header (100% anchored layout = 0 jump/jitter)
Item {
  id: root
  property var p  // Panel root

  width: Style.space(260)
  anchors.top: parent.top
  anchors.bottom: parent.bottom
  anchors.left: parent.left

  // 1. User Profile Header Card
  BorderSurface {
    id: headerCard
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: Style.space(42)
    radius: Style.cornerRadius
    color: Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.04)
    borderSpec: Border.flat(Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.06), 1)

    Item {
      anchors.fill: parent
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)

      // User Avatar (Left)
      BorderSurface {
        id: userAvatarBox
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(28); height: Style.space(28)
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

      // Logout Button (Right)
      Text {
        id: logoutBtn
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf2f5"
        color: logoutMouse.containsMouse ? p.urgent : p.dim
        font.family: p.fontFamily
        font.pixelSize: Style.font.caption

        MouseArea {
          id: logoutMouse
          anchors.fill: parent; anchors.margins: -4
          hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: p.logout()
        }
      }

      // User Name Column (Fills space between avatar and logout)
      Column {
        anchors.left: userAvatarBox.right
        anchors.leftMargin: Style.space(8)
        anchors.right: logoutBtn.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: p.userName || "Connected"
          color: p.foreground
          font.family: p.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: p.userUsername ? "@" + p.userUsername : "Telegram"
          color: p.dim
          font.family: p.fontFamily
          font.pixelSize: Style.font.caption * 0.8
          elide: Text.ElideRight
        }
      }
    }
  }

  // 2. Search Box
  BorderSurface {
    id: searchBox
    anchors.top: headerCard.bottom
    anchors.topMargin: Style.space(6)
    anchors.left: parent.left
    anchors.right: parent.right
    height: Style.space(32)
    radius: Style.cornerRadius
    color: Color.popups.background
    borderSpec: Border.controlSpec(searchInput.activeFocus ? "focused" : "normal", p.foreground, Color.accent)
    clip: true

    Row {
      anchors.fill: parent
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(6)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf002"
        color: p.dim
        font.family: p.fontFamily
        font.pixelSize: Style.font.caption
      }

      TextInput {
        id: searchInput
        width: parent.width - Style.space(44)
        anchors.verticalCenter: parent.verticalCenter
        color: p.foreground
        font.family: p.fontFamily
        font.pixelSize: Style.font.bodySmall
        selectByMouse: true
        clip: true
        text: p.searchQuery
        onTextChanged: p.searchQuery = text

        Text {
          visible: !searchInput.text && !searchInput.activeFocus
          text: "Search chats..."
          color: p.dim
          font.family: p.fontFamily
          font.pixelSize: Style.font.bodySmall
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      Text {
        visible: searchInput.text.length > 0
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf00d"
        color: clearMouse.containsMouse ? Color.accent : p.dim
        font.family: p.fontFamily
        font.pixelSize: Style.font.caption

        MouseArea {
          id: clearMouse
          anchors.fill: parent; anchors.margins: -4
          hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: searchInput.text = ""
        }
      }
    }
  }

  // 3. Filter Chips (All, DMs, Groups, Channels)
  Row {
    id: filterRow
    anchors.top: searchBox.bottom
    anchors.topMargin: Style.space(6)
    anchors.left: parent.left
    anchors.right: parent.right
    height: Style.space(22)
    spacing: Style.space(4)

    Repeater {
      model: [
        { id: "all", label: "All" },
        { id: "users", label: "DMs" },
        { id: "groups", label: "Groups" },
        { id: "channels", label: "Channels" }
      ]

      delegate: BorderSurface {
        required property var modelData
        readonly property bool isSelected: p.chatFilter === modelData.id
        height: Style.space(22)
        implicitWidth: chipText.implicitWidth + Style.space(12)
        radius: Style.space(11)
        color: isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"
        borderSpec: isSelected ? Border.flat(Color.accent, 1) : Border.flat(Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.08), 1)

        Text {
          id: chipText
          anchors.centerIn: parent
          text: modelData.label
          color: isSelected ? Color.accent : p.dim
          font.family: p.fontFamily
          font.pixelSize: Style.font.caption * 0.85
          font.bold: isSelected
        }

        MouseArea {
          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: p.chatFilter = modelData.id
        }
      }
    }
  }

  // 4. Chats ListView (Anchored rigidly top-to-bottom: 0 recalculation jumps)
  ListView {
    id: chatListView
    anchors.top: filterRow.bottom
    anchors.topMargin: Style.space(6)
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    clip: true
    spacing: Style.space(2)
    boundsBehavior: Flickable.StopAtBounds
    model: p.filteredChats

    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    delegate: Item {
      id: chatRow
      required property var modelData
      required property int index
      readonly property bool isSelected: p.selectedChat && p.selectedChat.id === modelData.id
      readonly property bool isHovered: rowMouse.containsMouse

      width: chatListView.width
      height: Style.space(56)

      Rectangle {
        anchors.fill: parent
        radius: Style.cornerRadius
        color: chatRow.isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : (chatRow.isHovered ? Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.06) : "transparent")
        border.color: chatRow.isSelected ? Color.accent : "transparent"
        border.width: chatRow.isSelected ? 1 : 0
      }

      MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
          if (mouse.button === Qt.RightButton) {
            var pt = rowMouse.mapToItem(root, mouse.x, mouse.y)
            contextMenu.targetChat = modelData
            contextMenu.showAt(pt.x, pt.y)
          } else {
            p.selectChat(modelData)
          }
        }
      }

      Item {
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)

        // Avatar Item
        Item {
          id: avatarBox
          width: Style.space(38); height: Style.space(38)
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter

          BorderSurface {
            anchors.fill: parent
            radius: width / 2.0
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
            borderSpec: Border.none
            clip: true

            Image {
              visible: modelData.avatar !== "" && modelData.avatar !== undefined
              anchors.fill: parent
              source: modelData.avatar ? "file://" + modelData.avatar : ""
              fillMode: Image.PreserveAspectCrop
              sourceSize.width: 76; sourceSize.height: 76
            }

            Text {
              visible: !modelData.avatar
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: modelData.initials || "TG"
              color: p.foreground
              font.family: p.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          // Online Indicator Dot
          Rectangle {
            visible: modelData.online === true
            width: Style.space(8); height: Style.space(8)
            radius: width / 2.0
            color: Color.accent
            border.color: Color.popups.background; border.width: 1.5
            anchors.bottom: parent.bottom; anchors.right: parent.right
          }
        }

        // Content Column
        Item {
          anchors.left: avatarBox.right
          anchors.leftMargin: Style.space(8)
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          height: Style.space(36)

          // Top row: Title + Time
          Item {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Style.space(18)

            // Time
            Text {
              id: timeText
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: (modelData.last_message && modelData.last_message.time) ? modelData.last_message.time : ""
              color: modelData.unread_count > 0 ? Color.accent : p.dim
              font.family: p.fontFamily
              font.pixelSize: Style.font.caption * 0.8
            }

            // Chat Title
            Text {
              anchors.left: parent.left
              anchors.right: timeText.left
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: modelData.title || "Chat"
              color: (modelData.unread_count > 0 || isSelected) ? p.foreground : Qt.darker(p.foreground, 1.2)
              font.family: p.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: modelData.unread_count > 0 || isSelected
              elide: Text.ElideRight
            }
          }

          // Bottom row: Last message snippet + unread badge
          Item {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: Style.space(16)

            BorderSurface {
              id: badgePill
              visible: modelData.unread_count > 0
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              height: Style.space(15)
              implicitWidth: Math.max(Style.space(15), unreadText.implicitWidth + Style.space(6))
              radius: Style.space(7.5)
              color: Color.accent
              borderSpec: Border.none

              Text {
                id: unreadText
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: modelData.unread_count > 99 ? "99+" : String(modelData.unread_count)
                color: "#ffffff"
                font.family: p.fontFamily
                font.pixelSize: Style.space(8)
                font.bold: true
              }
            }

            Row {
              anchors.left: parent.left
              anchors.right: badgePill.visible ? badgePill.left : parent.right
              anchors.rightMargin: badgePill.visible ? Style.space(4) : 0
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(3)

              // Outgoing Status Checks (✓ / ✓✓)
              Row {
                visible: modelData.last_message && modelData.last_message.out === true
                spacing: -3
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  text: "\uf00c"
                  color: (modelData.last_message && (modelData.last_message.status === "read" || modelData.last_message.is_read)) ? Color.accent : p.dim
                  font.family: p.fontFamily
                  font.pixelSize: Style.space(8)
                }

                Text {
                  visible: modelData.last_message && (modelData.last_message.status === "read" || modelData.last_message.is_read)
                  text: "\uf00c"
                  color: Color.accent
                  font.family: p.fontFamily
                  font.pixelSize: Style.space(8)
                }
              }

              // Last message snippet text
              Text {
                width: parent.width - (modelData.last_message && modelData.last_message.out ? Style.space(16) : 0)
                textFormat: Text.PlainText
                maximumLineCount: 1
                elide: Text.ElideRight
                text: {
                  if (!modelData.last_message) return ""
                  var raw = modelData.last_message.text || ""
                  var singleLine = raw.replace(/[\r\n]+/g, " ").trim()
                  return singleLine || (modelData.last_message.media_type ? "📷 Media" : "")
                }
                color: modelData.unread_count > 0 ? p.foreground : p.dim
                font.family: p.fontFamily
                font.pixelSize: Style.font.caption * 0.88
                font.bold: modelData.unread_count > 0
              }
            }
          }
        }
      }
    }
  }

  // Sleek Right-Click Context Menu for Leave / Report Spam / Mark Read / Delete
  Item {
    id: contextMenu
    anchors.fill: parent
    visible: targetChat !== null
    z: 999

    property var targetChat: null
    property real menuX: 0
    property real menuY: 0

    function showAt(px, py) {
      menuX = Math.max(8, Math.min(px, root.width - menuBox.width - 8))
      menuY = Math.max(8, Math.min(py, root.height - menuBox.implicitHeight - 8))
    }

    function hide() {
      targetChat = null
    }

    // Dismiss backdrop
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: contextMenu.hide()
    }

    BorderSurface {
      id: menuBox
      x: contextMenu.menuX
      y: contextMenu.menuY
      width: Style.space(170)
      implicitHeight: menuCol.implicitHeight + Style.space(8)
      radius: Style.cornerRadius
      color: Color.popups.background
      borderSpec: Border.flat(Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.15), 1)

      Column {
        id: menuCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(4)
        spacing: Style.space(2)

        // 1. Mark as read
        Rectangle {
          width: parent.width
          height: Style.space(28)
          radius: Style.space(4)
          color: markReadMouse.containsMouse ? Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.08) : "transparent"

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf00c"
              color: p.foreground
              font.family: p.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Mark as Read"
              color: p.foreground
              font.family: p.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          MouseArea {
            id: markReadMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (contextMenu.targetChat) p.markChatRead(contextMenu.targetChat.id)
              contextMenu.hide()
            }
          }
        }

        // 2. Leave Group / Leave Channel
        Rectangle {
          visible: contextMenu.targetChat && (contextMenu.targetChat.is_group || contextMenu.targetChat.is_channel)
          width: parent.width
          height: Style.space(28)
          radius: Style.space(4)
          color: leaveMouse.containsMouse ? Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.08) : "transparent"

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf2f5"
              color: p.foreground
              font.family: p.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: (contextMenu.targetChat && contextMenu.targetChat.is_channel) ? "Leave Channel" : "Leave Group"
              color: p.foreground
              font.family: p.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          MouseArea {
            id: leaveMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (contextMenu.targetChat) p.leaveChat(contextMenu.targetChat.id)
              contextMenu.hide()
            }
          }
        }

        // 3. Report Spam and Leave (in warning/urgent red)
        Rectangle {
          width: parent.width
          height: Style.space(28)
          radius: Style.space(4)
          color: reportMouse.containsMouse ? Qt.rgba(p.urgent.r, p.urgent.g, p.urgent.b, 0.15) : "transparent"

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf071"
              color: p.urgent
              font.family: p.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Report Spam & Leave"
              color: p.urgent
              font.family: p.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
          }

          MouseArea {
            id: reportMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (contextMenu.targetChat) p.reportSpamAndLeave(contextMenu.targetChat.id)
              contextMenu.hide()
            }
          }
        }

        // 4. Delete Chat (for private DMs)
        Rectangle {
          visible: contextMenu.targetChat && contextMenu.targetChat.is_user
          width: parent.width
          height: Style.space(28)
          radius: Style.space(4)
          color: delChatMouse.containsMouse ? Qt.rgba(p.urgent.r, p.urgent.g, p.urgent.b, 0.15) : "transparent"

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
              text: "Delete Chat"
              color: p.urgent
              font.family: p.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          MouseArea {
            id: delChatMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (contextMenu.targetChat) p.deleteChat(contextMenu.targetChat.id)
              contextMenu.hide()
            }
          }
        }
      }
    }
  }
}
