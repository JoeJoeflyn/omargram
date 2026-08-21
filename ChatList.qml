import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Sidebar displaying chats, search, filters, and unread badges
Item {
  id: root
  property var p  // Panel root

  width: Style.space(220)
  height: parent.height

  Column {
    anchors.fill: parent
    spacing: Style.space(6)

    // Search Box
    BorderSurface {
      width: parent.width
      implicitHeight: Style.space(28)
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
          width: parent.width - Style.space(40)
          anchors.verticalCenter: parent.verticalCenter
          color: p.foreground
          font.family: p.fontFamily
          font.pixelSize: Style.font.caption
          selectByMouse: true
          clip: true
          text: p.searchQuery
          onTextChanged: p.searchQuery = text

          Text {
            visible: !searchInput.text && !searchInput.activeFocus
            text: "Search chats..."
            color: p.dim
            font.family: p.fontFamily
            font.pixelSize: Style.font.caption
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

    // Filter Chips (All, DMs, Groups, Channels)
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
          implicitHeight: Style.space(20)
          implicitWidth: chipText.implicitWidth + Style.space(12)
          radius: Style.space(10)
          color: isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"
          borderSpec: isSelected ? Border.flat(Color.accent, 1) : Border.flat(Qt.rgba(1, 1, 1, 0.08), 1)

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

    // Chats ListView
    ListView {
      id: chatListView
      width: parent.width
      height: parent.height - y
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
        width: chatListView.width
        implicitHeight: Style.space(48)
        radius: Style.cornerRadius
        color: isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18) : (rowMouse.containsMouse ? Style.hoverFillFor(p.foreground, Color.accent) : "transparent")
        borderSpec: isSelected ? Border.flat(Color.accent, 1) : Border.none

        MouseArea {
          id: rowMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: p.selectChat(modelData)
        }

        Row {
          anchors.fill: parent
          anchors.leftMargin: Style.space(6)
          anchors.rightMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          // Avatar Item
          Item {
            width: Style.space(34); height: Style.space(34)
            anchors.verticalCenter: parent.verticalCenter

            BorderSurface {
              anchors.fill: parent
              radius: width / 2.0
              color: modelData.color || Color.accent
              borderSpec: Border.none
              clip: true

              Image {
                visible: modelData.avatar !== "" && modelData.avatar !== undefined
                anchors.fill: parent
                source: modelData.avatar ? "file://" + modelData.avatar : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 68; sourceSize.height: 68
              }

              Text {
                visible: !modelData.avatar
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: modelData.initials || "TG"
                color: "#ffffff"
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
              color: "#4caf50"
              border.color: "#181a20"; border.width: 1.5
              anchors.bottom: parent.bottom; anchors.right: parent.right
            }
          }

          // Content Column
          Column {
            width: parent.width - Style.space(46)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            // Top row: Title + Time
            Row {
              width: parent.width
              spacing: Style.space(4)

              Text {
                width: parent.width - timeText.implicitWidth - Style.space(4)
                textFormat: Text.PlainText
                text: modelData.title || "Chat"
                color: (modelData.unread_count > 0 || isSelected) ? p.foreground : Qt.darker(p.foreground, 1.2)
                font.family: p.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: modelData.unread_count > 0 || isSelected
                elide: Text.ElideRight
              }

              Text {
                id: timeText
                textFormat: Text.PlainText
                text: (modelData.last_message && modelData.last_message.time) ? modelData.last_message.time : ""
                color: modelData.unread_count > 0 ? Color.accent : p.dim
                font.family: p.fontFamily
                font.pixelSize: Style.font.caption * 0.8
              }
            }

            // Bottom row: Last message snippet + unread badge
            Row {
              width: parent.width
              spacing: Style.space(4)

              Text {
                width: parent.width - (badgePill.visible ? badgePill.implicitWidth + Style.space(4) : 0)
                textFormat: Text.PlainText
                text: {
                  if (!modelData.last_message) return ""
                  var prefix = modelData.last_message.out ? "✓ " : ""
                  return prefix + (modelData.last_message.text || "")
                }
                color: modelData.unread_count > 0 ? p.foreground : p.dim
                font.family: p.fontFamily
                font.pixelSize: Style.font.caption * 0.88
                font.bold: modelData.unread_count > 0
                elide: Text.ElideRight
              }

              BorderSurface {
                id: badgePill
                visible: modelData.unread_count > 0
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: Style.space(16)
                implicitWidth: Math.max(Style.space(16), unreadText.implicitWidth + Style.space(6))
                radius: Style.space(8)
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
            }
          }
        }
      }
    }
  }
}
