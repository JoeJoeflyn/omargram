import QtQuick
import qs.Commons
import qs.Ui

// Bar widget: Telegram paper airplane icon + live unread badge
BarWidget {
  id: root
  moduleName: "omargram"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  function openChat(chatId) {
    if (panelLoader.item && panelLoader.item.selectChatById) panelLoader.item.selectChatById(chatId)
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.iconSlot
    active: panelLoader.item && (panelLoader.item.opened || panelLoader.item.unreadCount > 0)
    tooltipText: {
      if (!panelLoader.item) return "OmarGram"
      var u = panelLoader.item.unreadCount || 0
      if (u > 0) return "OmarGram: " + u + " unread message" + (u > 1 ? "s" : "")
      if (panelLoader.item.isAuthorized) return "OmarGram (" + (panelLoader.item.userName || "Connected") + ")"
      return "OmarGram (Login Required)"
    }

    iconComponent: Component {
      Item {
        anchors.fill: parent

        // Telegram Paper Airplane Icon
        Text {
          anchors.centerIn: parent
          text: "\uf2c6"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.icon
          color: {
            if (!button.enabled) return Color.button.disabledForeground
            if (panelLoader.item && panelLoader.item.unreadCount > 0) return Color.accent
            if (button.active) return Color.accent
            if (button.hovered) return Color.button.hoverForeground
            return Color.button.foreground
          }
        }

        // Live Unread Badge
        BorderSurface {
          visible: panelLoader.item && panelLoader.item.unreadCount > 0
          anchors.top: parent.top
          anchors.topMargin: -Style.space(2)
          anchors.right: parent.right
          anchors.rightMargin: -Style.space(4)
          implicitWidth: Math.max(Style.space(14), badgeText.implicitWidth + Style.space(6))
          implicitHeight: Style.space(14)
          radius: Style.space(7)
          color: Color.accent
          borderSpec: Border.none

          Text {
            id: badgeText
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: (panelLoader.item && panelLoader.item.unreadCount > 99) ? "99+" : (panelLoader.item ? String(panelLoader.item.unreadCount) : "0")
            color: "#ffffff"
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.space(8)
            font.bold: true
          }
        }
      }
    }

    onClicked: root.togglePanel()
  }
}
