import QtQuick
import qs.Commons
import qs.Ui

// Bar widget: Telegram paper airplane icon that opens the OmarGram panel.
BarWidget {
  id: root
  moduleName: "omargram"

  function ensurePanel() {
    if (!panelLoader.active) {
      panelLoader.active = true
    }
  }

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
    ensurePanel()
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
    else Qt.callLater(function() { if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey() })
  }

  function openChat(chatId) {
    ensurePanel()
    if (panelLoader.item && panelLoader.item.selectChatById) panelLoader.item.selectChatById(chatId)
    else Qt.callLater(function() { if (panelLoader.item && panelLoader.item.selectChatById) panelLoader.item.selectChatById(chatId) })
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    ensurePanel()
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
    else Qt.callLater(function() { if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey() })
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  readonly property int unreadCount: panelLoader.item ? panelLoader.item.unreadCount : 0

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: false
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
    tooltipText: root.unreadCount > 0
      ? "OmarGram (" + root.unreadCount + " unread)"
      : "OmarGram"

    iconComponent: Component {
      Item {
        anchors.fill: parent

        Text {
          anchors.centerIn: parent
          text: "\uf2c6"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.bar.iconFont
          color: (panelLoader.item && panelLoader.item.opened)
            ? (root.bar && root.bar.activeColor ? root.bar.activeColor : Color.accent)
            : (root.bar ? root.bar.foreground : Color.foreground)
        }

        Rectangle {
          z: 10
          visible: root.unreadCount > 0
          width: Style.space(6)
          height: Style.space(6)
          radius: width / 2
          color: (root.bar && root.bar.activeColor) ? root.bar.activeColor : Color.accent
          border.width: 1
          border.color: (root.bar && root.bar.background) ? root.bar.background : Color.background
          anchors.top: parent.top
          anchors.topMargin: Style.space(1)
          anchors.right: parent.right
          anchors.rightMargin: Style.space(1)
        }
      }
    }

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) root.refresh()
      else if (b === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }
  }
}
