import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Bottom message input composer capsule with instant send, media attach, and paste support
Item {
  id: root
  property var p  // Panel root

  implicitHeight: ((p.replyingTo || p.editingMessage) ? Style.space(28) : 0)
    + (p.attachedFile ? Style.space(48) : 0)
    + Math.max(Style.space(42), inputCapsule.implicitHeight + Style.space(8))

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
          color: cancelBannerMouse.containsMouse ? p.danger : p.dim
          font.family: p.fontFamily
          font.pixelSize: Style.font.caption * 0.8
          anchors.verticalCenter: parent.verticalCenter

          ToolTip.visible: cancelBannerMouse.containsMouse
          ToolTip.delay: 350
          ToolTip.text: p.editingMessage ? "Cancel editing" : "Cancel reply"

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

    // Attached Media Banner
    BorderSurface {
      visible: p.attachedFile !== null
      width: parent.width
      height: Style.space(44)
      radius: Style.space(8)
      color: Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.08)
      borderSpec: Border.controlSpec("normal", p.foreground, Color.accent)

      Row {
        anchors.fill: parent
        anchors.margins: Style.space(6)
        spacing: Style.space(8)

        // Thumbnail / File Icon
        BorderSurface {
          width: Style.space(32); height: Style.space(32)
          radius: Style.space(6)
          color: Qt.rgba(0, 0, 0, 0.3)
          borderSpec: Border.none
          clip: true
          anchors.verticalCenter: parent.verticalCenter

          Image {
            visible: p.attachedFile && p.attachedFile.isImage
            anchors.fill: parent
            source: (p.attachedFile && p.attachedFile.isImage) ? p.attachedFile.preview : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 64
            sourceSize.height: 64
            asynchronous: true
            cache: true
            smooth: true
          }

          Text {
            visible: !p.attachedFile || !p.attachedFile.isImage
            anchors.centerIn: parent
            text: "\uf15b"
            color: Color.accent
            font.family: p.fontFamily
            font.pixelSize: Style.font.body
          }
        }

        // File metadata
        Column {
          width: parent.width - Style.space(70)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(1)

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: p.attachedFile ? p.attachedFile.name : ""
            color: p.foreground
            font.family: p.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            textFormat: Text.PlainText
            text: "Ready to send • Add optional caption below"
            color: p.dim
            font.family: p.fontFamily
            font.pixelSize: Style.font.caption * 0.85
          }
        }

        // Remove Attachment Button
        BorderSurface {
          anchors.verticalCenter: parent.verticalCenter
          implicitWidth: Style.space(22); implicitHeight: Style.space(22)
          radius: width / 2.0
          color: removeAttachMouse.containsMouse ? Qt.rgba(p.danger.r, p.danger.g, p.danger.b, 0.25) : Qt.rgba(p.foreground.r, p.foreground.g, p.foreground.b, 0.1)
          borderSpec: Border.none

          Text {
            anchors.centerIn: parent
            text: "\uf00d"
            color: removeAttachMouse.containsMouse ? p.danger : p.dim
            font.family: p.fontFamily
            font.pixelSize: Style.font.caption * 0.8
          }

          ToolTip.visible: removeAttachMouse.containsMouse
          ToolTip.delay: 350
          ToolTip.text: "Remove attachment"

          MouseArea {
            id: removeAttachMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: p.clearAttachedFile()
          }
        }
      }
    }

    // Input Capsule
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
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(4)
        spacing: Style.space(6)

        // Attach Media Button
        BorderSurface {
          id: attachBtn
          anchors.verticalCenter: parent.verticalCenter
          implicitWidth: Style.space(26); implicitHeight: Style.space(26)
          radius: width / 2.0
          color: attachMouse.containsMouse ? Style.hoverFillFor(p.foreground, Color.accent) : Qt.transparent
          borderSpec: Border.none

          Text {
            anchors.centerIn: parent
            text: "\uf0c6"
            color: attachMouse.containsMouse ? Color.accent : p.dim
            font.family: p.fontFamily
            font.pixelSize: Style.font.caption
          }

          ToolTip.visible: attachMouse.containsMouse
          ToolTip.delay: 350
          ToolTip.text: "Attach image or file"

          MouseArea {
            id: attachMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: p.openFilePicker()
          }
        }

        // Multiline Input Text Area
        Flickable {
          id: flick
          width: parent.width - attachBtn.width - sendBtn.width - Style.space(20)
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
            placeholderText: p.editingMessage ? "Edit message..." : (p.attachedFile ? "Add a caption..." : (p.selectedChat ? "Message " + p.selectedChat.title + "..." : "Type a message..."))
            placeholderTextColor: p.dim

            Keys.onPressed: function(event) {
              if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
                p.checkAndPasteClipboardImage()
              }
            }

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
          color: (inputArea.text.trim().length > 0 || p.attachedFile !== null) ? Color.accent : Qt.rgba(1, 1, 1, 0.05)
          borderSpec: Border.none
          scale: sendMouse.pressed ? 0.92 : (sendMouse.containsMouse ? 1.05 : 1.0)
          Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

          Text {
            anchors.centerIn: parent
            text: p.editingMessage ? "\uf00c" : "\uf1d8"
            color: (inputArea.text.trim().length > 0 || p.attachedFile !== null) ? "#ffffff" : p.dim
            font.family: p.fontFamily
            font.pixelSize: Style.font.caption
          }

          ToolTip.visible: sendMouse.containsMouse
          ToolTip.delay: 350
          ToolTip.text: p.editingMessage ? "Save edit (Enter)" : (p.attachedFile ? "Send file (Enter)" : "Send message (Enter)")

          MouseArea {
            id: sendMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: (inputArea.text.trim().length > 0 || p.attachedFile !== null) ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.sendMessage()
          }
        }
      }
    }
  }

  function sendMessage() {
    if (!p.selectedChat) return
    var txt = inputArea.text.trim()
    if (p.attachedFile) {
      p.sendFileToActiveChat(p.attachedFile.path, txt)
      inputArea.text = ""
      return
    }
    if (!txt) return
    inputArea.text = ""
    if (p.editingMessage) {
      p.submitEditMessage(p.selectedChat.id, p.editingMessage.id, txt)
    } else {
      p.clearReply()
      p.sendMessageToActiveChat(txt)
    }
  }
}
