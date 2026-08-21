import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Bottom message input composer capsule with instant send and edit support
Item {
  id: root
  property var p  // Panel root

  implicitHeight: ((p.replyingTo || p.editingMessage) ? Style.space(28) : 0) + Math.max(Style.space(42), inputCapsule.implicitHeight + Style.space(8))

  Connections {
    target: p
    function onEditingMessageChanged() {
      if (p.editingMessage) {
        inputArea.text = p.editingMessage.text || ""
        inputArea.cursorPosition = inputArea.text.length
        inputArea.forceActiveFocus()
      }
    }
  }

  Column {
    anchors.fill: parent
    spacing: Style.space(2)

    // Edit / Reply Banner
    BorderSurface {
      visible: p.replyingTo !== null || p.editingMessage !== null
      width: parent.width
      height: Style.space(26)
      radius: Style.space(6)
      color: Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.06)
      borderSpec: Border.leftSpec(Color.accent, 2)

      Row {
        anchors.fill: parent
        anchors.leftMargin: Style.space(6)
        anchors.rightMargin: Style.space(6)
        spacing: Style.space(6)

        Text {
          text: p.editingMessage ? "\uf044" : "\uf112"
          color: Color.accent
          font.family: p.fontFamily
          font.pixelSize: Style.font.caption * 0.8
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          width: parent.width - Style.space(40)
          textFormat: Text.PlainText
          text: p.editingMessage ? ("Edit: " + (p.editingMessage.text || "")) : (p.replyingTo ? (p.replyingTo.sender_name + ": " + (p.replyingTo.text || "Media")) : "")
          color: p.foreground
          font.family: p.fontFamily
          font.pixelSize: Style.font.caption * 0.85
          elide: Text.ElideRight
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: "\uf00d"
          color: cancelBannerMouse.containsMouse ? p.urgent : p.dim
          font.family: p.fontFamily
          font.pixelSize: Style.font.caption * 0.8
          anchors.verticalCenter: parent.verticalCenter

          MouseArea {
            id: cancelBannerMouse
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (p.editingMessage) {
                p.cancelEditingMessage()
                inputArea.text = ""
              } else {
                p.clearReply()
              }
            }
          }
        }
      }
    }

    BorderSurface {
      id: inputCapsule
      width: parent.width
      anchors.margins: Style.space(4)
      implicitHeight: Math.max(Style.space(34), Math.min(Style.space(100), inputArea.implicitHeight + Style.space(10)))
      radius: Style.space(17)
      color: Color.popups.background
      borderSpec: Border.controlSpec(inputArea.activeFocus ? "focused" : "normal", p.foreground, Color.accent)

    Row {
      anchors.fill: parent
      anchors.leftMargin: Style.space(12)
      anchors.rightMargin: Style.space(4)
      spacing: Style.space(6)

      // Multiline Input Text Area
      Flickable {
        id: flick
        width: parent.width - sendBtn.width - Style.space(14)
        height: Math.min(Style.space(80), inputArea.contentHeight)
        anchors.verticalCenter: parent.verticalCenter
        contentWidth: width
        contentHeight: inputArea.contentHeight
        clip: true

        TextArea.flickable: TextArea {
          id: inputArea
          width: flick.width
          wrapMode: Text.Wrap
          color: p.foreground
          font.family: p.fontFamily
          font.pixelSize: Style.font.bodySmall
          selectByMouse: true
          background: null
          leftPadding: 0; rightPadding: 0; topPadding: 0; bottomPadding: 0
          placeholderText: p.editingMessage ? "Edit message..." : (p.selectedChat ? "Message " + p.selectedChat.title + "..." : "Type a message...")
          placeholderTextColor: p.dim

          Keys.onReturnPressed: function(event) {
            if (event.modifiers & Qt.ShiftModifier) {
              inputArea.insert(inputArea.cursorPosition, "\n")
            } else {
              event.accepted = true
              root.sendMessage()
            }
          }
        }
      }

      // Send Button
      BorderSurface {
        id: sendBtn
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: Style.space(28); implicitHeight: Style.space(28)
        radius: width / 2.0
        color: (inputArea.text.trim().length > 0) ? Color.accent : Qt.rgba(1, 1, 1, 0.05)
        borderSpec: Border.none
        scale: sendMouse.pressed ? 0.92 : (sendMouse.containsMouse ? 1.05 : 1.0)
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

        Text {
          anchors.centerIn: parent
          text: p.editingMessage ? "\uf00c" : "\uf1d8"
          color: (inputArea.text.trim().length > 0) ? "#ffffff" : p.dim
          font.family: p.fontFamily
          font.pixelSize: Style.font.caption
        }

        MouseArea {
          id: sendMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: inputArea.text.trim().length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: root.sendMessage()
        }
      }
    }
  }
}

  function sendMessage() {
    var txt = inputArea.text.trim()
    if (!txt || !p.selectedChat) return
    inputArea.text = ""
    if (p.editingMessage) {
      p.submitEditMessage(p.selectedChat.id, p.editingMessage.id, txt)
    } else {
      p.clearReply()
      p.sendMessageToActiveChat(txt)
    }
  }
}
