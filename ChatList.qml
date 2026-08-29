import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Sidebar displaying chats, search, filters, and user profile header (100% anchored layout = 0 jump/jitter)
Item {
  id: root
  property var p  // Panel root

  width: p.sidebarCollapsed ? Style.space(56) : Style.space(260)
  Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

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

      // Clickable Profile Area (Avatar + User Name)
      Item {
        id: profileClickArea
        anchors.left: parent.left
        anchors.right: collapseBtn.left
        anchors.rightMargin: Style.space(6)
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        // User Avatar (Left)
        BorderSurface {
          id: userAvatarBox
          anchors.left: p.sidebarCollapsed ? undefined : parent.left
          anchors.horizontalCenter: p.sidebarCollapsed ? parent.horizontalCenter : undefined
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

        // User Name Column (Fills space between avatar and collapse button)
        Column {
          visible: !p.sidebarCollapsed
          anchors.left: userAvatarBox.right
          anchors.leftMargin: Style.space(8)
          anchors.right: parent.right
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

        ToolTip.visible: profileMouse.containsMouse
        ToolTip.delay: 350
        ToolTip.text: "Account & Settings"

        MouseArea {
          id: profileMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: profileMenu.toggle()
        }
      }

      // Sidebar Collapse / Expand Toggle Button (Right)
      Text {
        id: collapseBtn
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: p.sidebarCollapsed ? "\uf061" : "\uf060"
        color: collapseMouse.containsMouse ? Color.accent : p.dim
        font.family: p.fontFamily
        font.pixelSize: Style.font.caption

        ToolTip.visible: collapseMouse.containsMouse
        ToolTip.delay: 350
        ToolTip.text: p.sidebarCollapsed ? "Expand sidebar" : "Collapse sidebar"

        MouseArea {
          id: collapseMouse
          anchors.fill: parent
          anchors.margins: -4
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: p.toggleSidebar()
        }
      }
    }
  }

  // 2. Search Box (Hidden when sidebar is collapsed)
  BorderSurface {
    id: searchBox
    visible: !topicsView.visible && !p.sidebarCollapsed
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

        ToolTip.visible: clearMouse.containsMouse
        ToolTip.delay: 350
        ToolTip.text: "Clear search"

        MouseArea {
          id: clearMouse
          anchors.fill: parent; anchors.margins: -4
          hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: searchInput.text = ""
        }
      }
    }
  }

  // 3. Filter Chips (All, DMs, Groups, Channels) (Hidden when sidebar is collapsed)
  Row {
    id: filterRow
    visible: !topicsView.visible && !p.sidebarCollapsed
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

  // 3b. Topics View (replaces chat list when a forum chat is open)
  Item {
    id: topicsView
    visible: p.selectedChat && p.selectedChat.is_forum && (p.forumTopics.length > 0 || p.loadingTopics) && !p.sidebarCollapsed
    anchors.top: headerCard.bottom
    anchors.topMargin: Style.space(6)
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right

    // Back button (standalone)
    Item {
      id: topicsHeader
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: Style.space(32)

      Text {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf060"
        color: backMouse.containsMouse ? Color.accent : p.dim
        font.family: p.fontFamily
        font.pixelSize: Style.space(14)

        MouseArea {
          id: backMouse
          anchors.fill: parent
          anchors.margins: -6
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: p.clearTopicSelection()
        }
      }

      Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.06)
      }
    }

    // Topics loading indicator
    Item {
      visible: p.loadingTopics && p.forumTopics.length === 0
      anchors.top: topicsHeader.bottom
      anchors.topMargin: Style.space(20)
      anchors.horizontalCenter: parent.horizontalCenter
      width: Style.space(24)
      height: Style.space(24)

      Text {
        id: topicsLoadingIcon
        anchors.centerIn: parent
        text: "\uf110"
        color: p.dim
        font.family: p.fontFamily
        font.pixelSize: Style.space(24)
      }

      RotationAnimation {
        running: parent.visible
        loops: Animation.Infinite
        target: topicsLoadingIcon
        from: 0
        to: 360
        duration: 800
      }
    }

    ListView {
      id: topicsListView
      anchors.top: topicsHeader.bottom
      anchors.topMargin: Style.space(4)
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      clip: true
      spacing: Style.space(2)
      boundsBehavior: Flickable.DragOverBounds
      cacheBuffer: 1500
      model: p.forumTopics

      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      delegate: Item {
        id: topicRow
        required property var modelData
        readonly property bool isActive: p.activeTopic && p.activeTopic.id === modelData.id

        width: topicsListView.width
        height: Style.space(48)
        clip: true

        Rectangle {
          anchors.fill: parent
          anchors.leftMargin: Style.space(4)
          anchors.rightMargin: Style.space(4)
          radius: Style.space(6)
          color: topicRow.isActive
            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
            : (topicMouse.containsMouse ? Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.06) : "transparent")
          Behavior on color { ColorAnimation { duration: 120 } }

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            // Content column
            Item {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - Style.space(8)
              height: Style.space(36)

              // Top row: Title + Time
              Item {
                id: topicTopRow
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: Style.space(18)

                // Time
                Text {
                  id: topicTime
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: modelData.last_time || ""
                  color: p.dim
                  font.family: p.fontFamily
                  font.pixelSize: Style.font.caption * 0.8
                  visible: modelData.last_time !== ""
                }

                // Title
                Text {
                  anchors.left: parent.left
                  anchors.right: topicTime.visible ? topicTime.left : parent.right
                  anchors.rightMargin: Style.space(6)
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: modelData.title || "Topic"
                  color: topicRow.isActive ? Color.accent : p.foreground
                  font.family: p.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: topicRow.isActive
                  elide: Text.ElideRight
                }
              }

              // Bottom row: Last message + unread badge
              Item {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: Style.space(16)

                // Unread badge
                BorderSurface {
                  id: topicBadge
                  visible: modelData.unread_count > 0
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  height: Style.space(15)
                  implicitWidth: Math.max(Style.space(15), topicUnreadText.implicitWidth + Style.space(6))
                  radius: Style.space(7.5)
                  color: Color.accent
                  borderSpec: Border.none

                  Text {
                    id: topicUnreadText
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: modelData.unread_count > 99 ? "99+" : String(modelData.unread_count)
                    color: "#ffffff"
                    font.family: p.fontFamily
                    font.pixelSize: Style.space(8)
                    font.bold: true
                  }
                }

                // Last message preview
                Text {
                  anchors.left: parent.left
                  anchors.right: topicBadge.visible ? topicBadge.left : parent.right
                  anchors.rightMargin: topicBadge.visible ? Style.space(4) : 0
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: {
                    var s = modelData.last_sender || ""
                    var t = (modelData.last_text || "").replace(/\n/g, " ")
                    if (s && t) return s + ": " + t
                    if (t) return t
                    if (s) return s
                    return ""
                  }
                  color: p.dim
                  font.family: p.fontFamily
                  font.pixelSize: Style.space(10)
                  elide: Text.ElideRight
                }
              }
            }
          }

          MouseArea {
            id: topicMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (topicRow.isActive) {
                p.clearTopic()
              } else {
                p.selectTopic(modelData)
              }
            }
          }
        }
      }
    }
  }

  // 4. Chats ListView (Anchored rigidly top-to-bottom: 0 recalculation jumps)
  ListView {
    id: chatListView
    visible: !topicsView.visible
    anchors.top: p.sidebarCollapsed ? headerCard.bottom : filterRow.bottom
    anchors.topMargin: Style.space(6)
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    clip: true
    spacing: Style.space(2)
    boundsBehavior: Flickable.DragOverBounds
    cacheBuffer: 1500
    pixelAligned: true
    flickDeceleration: 1400
    maximumFlickVelocity: 4500
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

      ToolTip {
        visible: rowMouse.containsMouse && p.sidebarCollapsed
        delay: 250
        contentItem: Text {
          textFormat: Text.PlainText
          text: modelData.unread_count > 0 ? (modelData.title + " (" + modelData.unread_count + " unread)") : (modelData.title || "")
          color: Color.popups.foreground
          font.family: p.fontFamily
          font.pixelSize: Style.font.caption
        }
        background: BorderSurface {
          color: Color.popups.background
          radius: Style.cornerRadius
          borderSpec: Border.flat(Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.15), 1)
        }
      }

      Item {
        anchors.fill: parent
        anchors.leftMargin: p.sidebarCollapsed ? 0 : Style.space(8)
        anchors.rightMargin: p.sidebarCollapsed ? 0 : Style.space(8)

        // Avatar Item
        Item {
          id: avatarBox
          width: Style.space(38); height: Style.space(38)
          anchors.left: p.sidebarCollapsed ? undefined : parent.left
          anchors.horizontalCenter: p.sidebarCollapsed ? parent.horizontalCenter : undefined
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

          // Unread badge dot when collapsed
          Rectangle {
            visible: p.sidebarCollapsed && modelData.unread_count > 0 && !chatRow.isSelected
            width: Style.space(10); height: Style.space(10)
            radius: width / 2.0
            color: Color.accent
            border.color: Color.popups.background; border.width: 1.5
            anchors.top: parent.top; anchors.right: parent.right
          }
        }

        // Content Column (Hidden when sidebar is collapsed)
        Item {
          visible: !p.sidebarCollapsed
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
              color: (modelData.unread_count > 0 && !chatRow.isSelected) ? Color.accent : p.dim
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
              color: (modelData.unread_count > 0 && !chatRow.isSelected || isSelected) ? p.foreground : Qt.darker(p.foreground, 1.2)
              font.family: p.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: (modelData.unread_count > 0 && !chatRow.isSelected) || isSelected
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
              visible: modelData.unread_count > 0 && !chatRow.isSelected
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

    // Empty State Placeholder
    Column {
      visible: p.filteredChats.length === 0
      anchors.centerIn: parent
      spacing: Style.space(6)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "\uf086"
        color: p.dim
        font.family: p.fontFamily
        font.pixelSize: Style.space(24)
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: p.searchQuery ? "No conversations found" : "No conversations yet"
        color: p.dim
        font.family: p.fontFamily
        font.pixelSize: Style.font.caption
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

        // 3. Report Spam and Leave (in vivid red)
        Rectangle {
          width: parent.width
          height: Style.space(28)
          radius: Style.space(4)
          color: reportMouse.containsMouse ? Qt.rgba(p.danger.r, p.danger.g, p.danger.b, 0.15) : "transparent"

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf071"
              color: p.danger
              font.family: p.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Report Spam & Leave"
              color: p.danger
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
          color: delChatMouse.containsMouse ? Qt.rgba(p.danger.r, p.danger.g, p.danger.b, 0.15) : "transparent"

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
              text: "Delete Chat"
              color: p.danger
              font.family: p.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
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

  // 6. User Account Profile Dropdown Menu (Clean & secure location for Log Out)
  Item {
    id: profileMenu
    anchors.fill: parent
    visible: false
    z: 1000

    function toggle() {
      visible = !visible
    }

    function hide() {
      visible = false
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: profileMenu.hide()
    }

    BorderSurface {
      id: profileBox
      anchors.top: headerCard.bottom
      anchors.topMargin: Style.space(4)
      anchors.left: parent.left
      anchors.leftMargin: Style.space(4)
      width: Style.space(220)
      implicitHeight: profileCol.implicitHeight + Style.space(12)
      radius: Style.cornerRadius
      color: Color.popups.background
      borderSpec: Border.flat(Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.15), 1)

      Column {
        id: profileCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(8)
        spacing: Style.space(8)

        // Account Profile Row
        Row {
          width: parent.width
          spacing: Style.space(10)

          BorderSurface {
            width: Style.space(34); height: Style.space(34)
            radius: width / 2.0
            color: Color.accent
            borderSpec: Border.none
            clip: true

            Image {
              visible: p.userAvatar !== "" && p.userAvatar !== undefined
              anchors.fill: parent
              source: p.userAvatar ? "file://" + p.userAvatar : ""
              fillMode: Image.PreserveAspectCrop
              sourceSize.width: 68; sourceSize.height: 68
            }

            Text {
              visible: !p.userAvatar
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: p.userInitials || "ME"
              color: "#ffffff"
              font.family: p.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Style.space(48)
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
              text: p.userUsername ? "@" + p.userUsername : "Telegram Account"
              color: p.dim
              font.family: p.fontFamily
              font.pixelSize: Style.font.caption * 0.85
              elide: Text.ElideRight
            }
          }
        }

        // Divider
        Rectangle {
          width: parent.width
          height: 1
          color: Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.08)
        }

        // Log out action item
        Rectangle {
          width: parent.width
          height: Style.space(30)
          radius: Style.space(4)
          color: logoutM.containsMouse ? Qt.rgba(p.danger.r, p.danger.g, p.danger.b, 0.15) : "transparent"

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf2f5"
              color: p.danger
              font.family: p.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Log Out of Telegram"
              color: p.danger
              font.family: p.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
          }

          MouseArea {
            id: logoutM
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              profileMenu.hide()
              p.logout()
            }
          }
        }
      }
    }
  }
}
