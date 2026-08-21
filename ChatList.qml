import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Sidebar displaying chats, search, filters, and user profile header
Item {
  id: root
  property var p  // Panel root

  width: Style.space(260)
  anchors.top: parent.top
  anchors.bottom: parent.bottom
  anchors.left: parent.left

  Column {
    anchors.fill: parent
    spacing: Style.space(6)

    // 1. User Profile Header Card
    BorderSurface {
      width: parent.width
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
      width: parent.width
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
      width: parent.width
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

    // 4. Chats ListView
    ListView {
      id: chatListView
      width: parent.width
      height: parent.height - Style.space(112)
      clip: true
      spacing: Style.space(2)
      boundsBehavior: Flickable.StopAtBounds
      model: p.filteredChats

      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      delegate: BorderSurface {
        id: chatRow
        required property var modelData
        required property int index
        readonly property bool isSelected: p.selectedChat && p.selectedChat.id === modelData.id
        property bool isSnapping: false

        width: chatListView.width
        height: isSnapping ? 0 : Style.space(56)
        opacity: isSnapping ? 0.0 : 1.0
        radius: Style.cornerRadius
        color: isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : (rowMouse.containsMouse ? Style.hoverFillFor(p.foreground, Color.accent) : "transparent")
        borderSpec: isSelected ? Border.flat(Color.accent, 1) : Border.none

        Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.InOutQuad } }
        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutQuad } }

        MouseArea {
          id: rowMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: p.selectChat(modelData)
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

            // Top row: Title + Time / Delete button (Fixed layout, 0 jump/shake)
            Item {
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              height: Style.space(18)

              // Right Action Container (Static width = no shaking)
              Item {
                id: topActionBox
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(46)
                height: parent.height

                // Time (visible by default)
                Text {
                  id: timeText
                  visible: !rowMouse.containsMouse
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: (modelData.last_message && modelData.last_message.time) ? modelData.last_message.time : ""
                  color: modelData.unread_count > 0 ? Color.accent : p.dim
                  font.family: p.fontFamily
                  font.pixelSize: Style.font.caption * 0.8
                }

                // Delete Chat icon on hover (appears in the exact same spot with 0 layout shift)
                Text {
                  visible: rowMouse.containsMouse
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: "\uf2ed"
                  color: delMouse.containsMouse ? p.urgent : p.dim
                  font.family: p.fontFamily
                  font.pixelSize: Style.font.caption * 0.9

                  MouseArea {
                    id: delMouse
                    anchors.fill: parent; anchors.margins: -4
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      chatRow.isSnapping = true
                      snapTimer.start()
                    }
                  }

                  Timer {
                    id: snapTimer
                    interval: 280
                    repeat: false
                    onTriggered: p.deleteChat(modelData.id)
                  }
                }
              }

              // Chat Title (anchored with fixed right margin = 0 jitter)
              Text {
                anchors.left: parent.left
                anchors.right: topActionBox.left
                anchors.rightMargin: Style.space(4)
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

              Text {
                anchors.left: parent.left
                anchors.right: badgePill.visible ? badgePill.left : parent.right
                anchors.rightMargin: badgePill.visible ? Style.space(4) : 0
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                maximumLineCount: 1
                elide: Text.ElideRight
                text: {
                  if (!modelData.last_message) return ""
                  var raw = modelData.last_message.text || ""
                  var singleLine = raw.replace(/[\r\n]+/g, " ").trim()
                  var prefix = modelData.last_message.out ? "✓ " : ""
                  return prefix + (singleLine || (modelData.last_message.media_type ? "📷 Media" : ""))
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
}
