import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Authentication view — QR code scanner & Phone login options
Item {
  id: root
  property var p  // Panel root

  anchors.fill: parent

  property string authMode: "qr" // "qr" or "phone"
  property string phoneNumber: ""
  property string authCode: ""
  property string twoFaPassword: ""
  property bool waitingForCode: false
  property bool waitingFor2Fa: false
  property string authError: ""

  Column {
    anchors.centerIn: parent
    spacing: Style.space(12)
    width: Math.min(parent.width - Style.space(40), Style.space(360))

    // Header Logo & Title
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Style.space(8)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf2c6"
        color: Color.accent
        font.family: p.fontFamily
        font.pixelSize: Style.font.title * 1.3
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "Log in to Telegram"
        color: p.foreground
        font.family: p.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
      }
    }

    // Subtitle
    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
      text: root.authMode === "qr" ? "Scan this QR code with the Telegram app on your phone" : "Log in using your phone number"
      color: p.dim
      font.family: p.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    // QR Code Container
    BorderSurface {
      visible: root.authMode === "qr"
      anchors.horizontalCenter: parent.horizontalCenter
      width: Style.space(180); height: Style.space(180)
      radius: Style.cornerRadius
      color: "#ffffff"
      borderSpec: Border.flat(Color.accent, 2)
      clip: true

      Image {
        id: qrImage
        anchors.fill: parent
        anchors.margins: Style.space(8)
        source: p.qrPath ? "file://" + p.qrPath + "?v=" + p.qrTimestamp : ""
        fillMode: Image.PreserveAspectFit
        cache: false
      }

      Text {
        visible: !p.qrPath
        anchors.centerIn: parent
        text: "Generating QR..."
        color: "#333333"
        font.family: p.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    // QR Instructions
    Column {
      visible: root.authMode === "qr"
      width: parent.width
      spacing: Style.space(4)

      Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "1. Open Telegram on your phone"; color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.caption }
      Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "2. Go to Settings > Devices > Link Desktop"; color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.caption }
      Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "3. Point your phone camera at this screen"; color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.caption }
    }

    // Phone Login Fields
    Column {
      visible: root.authMode === "phone"
      width: parent.width
      spacing: Style.space(8)

      // Phone Input
      BorderSurface {
        visible: !root.waitingForCode
        width: parent.width
        implicitHeight: Style.space(32)
        radius: Style.cornerRadius
        color: Color.popups.background
        borderSpec: Border.controlSpec(phoneInput.activeFocus ? "focused" : "normal", p.foreground, Color.accent)

        TextInput {
          id: phoneInput
          anchors.fill: parent; anchors.margins: Style.space(6)
          color: p.foreground; font.family: p.fontFamily; font.pixelSize: Style.font.bodySmall
          selectByMouse: true
          text: root.phoneNumber
          onTextChanged: root.phoneNumber = text
          Text { visible: !phoneInput.text && !phoneInput.activeFocus; text: "Phone (+1234567890)"; color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.bodySmall; anchors.verticalCenter: parent.verticalCenter }
        }
      }

      // Code Input
      BorderSurface {
        visible: root.waitingForCode && !root.waitingFor2Fa
        width: parent.width
        implicitHeight: Style.space(32)
        radius: Style.cornerRadius
        color: Color.popups.background
        borderSpec: Border.controlSpec(codeInput.activeFocus ? "focused" : "normal", p.foreground, Color.accent)

        TextInput {
          id: codeInput
          anchors.fill: parent; anchors.margins: Style.space(6)
          color: p.foreground; font.family: p.fontFamily; font.pixelSize: Style.font.bodySmall
          selectByMouse: true
          text: root.authCode
          onTextChanged: root.authCode = text
          Text { visible: !codeInput.text && !codeInput.activeFocus; text: "Login Code from Telegram"; color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.bodySmall; anchors.verticalCenter: parent.verticalCenter }
        }
      }

      // 2FA Password Input
      BorderSurface {
        visible: root.waitingFor2Fa
        width: parent.width
        implicitHeight: Style.space(32)
        radius: Style.cornerRadius
        color: Color.popups.background
        borderSpec: Border.controlSpec(pwdInput.activeFocus ? "focused" : "normal", p.foreground, Color.accent)

        TextInput {
          id: pwdInput
          anchors.fill: parent; anchors.margins: Style.space(6)
          color: p.foreground; font.family: p.fontFamily; font.pixelSize: Style.font.bodySmall
          selectByMouse: true; echoMode: TextInput.Password
          text: root.twoFaPassword
          onTextChanged: root.twoFaPassword = text
          Text { visible: !pwdInput.text && !pwdInput.activeFocus; text: "2FA Password"; color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.bodySmall; anchors.verticalCenter: parent.verticalCenter }
        }
      }

      // Action Button
      BorderSurface {
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: Style.space(160); implicitHeight: Style.space(30)
        radius: Style.cornerRadius
        color: Color.accent
        borderSpec: Border.none

        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: root.waitingFor2Fa ? "Submit Password" : (root.waitingForCode ? "Confirm Code" : "Send Code")
          color: p.accentForeground
          font.family: p.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
        }

        MouseArea {
          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.waitingFor2Fa) {
              p.submitCode(root.authCode, root.twoFaPassword)
            } else if (root.waitingForCode) {
              p.submitCode(root.authCode, "")
            } else {
              p.sendPhoneCode(root.phoneNumber)
              root.waitingForCode = true
            }
          }
        }
      }
    }

    // Toggle Mode Button (QR <-> Phone)
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.authMode === "qr" ? "Or log in with Phone Number" : "Or log in with QR Code"
      color: switchMouse.containsMouse ? Color.accent : p.dim
      font.family: p.fontFamily
      font.pixelSize: Style.font.caption
      font.underline: true

      MouseArea {
        id: switchMouse
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: {
          root.authMode = root.authMode === "qr" ? "phone" : "qr"
          if (root.authMode === "qr") p.startQrLogin()
        }
      }
    }
  }
}
