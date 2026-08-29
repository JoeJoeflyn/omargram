import QtQuick
import QtQuick.Controls
import QtMultimedia
import qs.Commons
import qs.Ui

// Full-featured media viewer modal for OmarGram: high-resolution photo zooming & video playback
Item {
  id: root
  property var p

  readonly property var mediaData: p ? p.activeMediaViewer : null
  readonly property string mediaPath: mediaData ? (mediaData.path || "") : ""
  readonly property string mediaThumb: mediaData ? (mediaData.thumb || "") : ""
  readonly property string mediaType: mediaData ? (mediaData.type || "photo") : "photo"
  readonly property var messageData: mediaData ? (mediaData.message || null) : null
  readonly property var mediaInfo: mediaData ? (mediaData.info || (messageData ? messageData.media_info : null)) : null

  property real zoomScale: 1.0
  property real panX: 0
  property real panY: 0
  property bool isDownloading: false
  property bool isLooping: false
  property bool isMuted: false

  visible: mediaData !== null
  anchors.fill: parent
  z: 10000

  onVisibleChanged: {
    if (visible) {
      root.zoomScale = 1.0
      root.panX = 0
      root.panY = 0
      if (root.mediaType === "video") {
        if (root.mediaPath !== "") {
          videoPlayer.source = "file://" + root.mediaPath
          videoPlayer.play()
        }
        if (root.messageData && root.messageData.chat_id && root.messageData.id) {
          root.isDownloading = (root.mediaPath === "")
          p.downloadMedia(root.messageData.chat_id, root.messageData.id, "video")
        }
      } else if (root.mediaType === "photo") {
        if (root.messageData && root.messageData.chat_id && root.messageData.id) {
          p.downloadMedia(root.messageData.chat_id, root.messageData.id, "photo")
        }
      }
    } else {
      if (videoPlayer.playbackState === MediaPlayer.PlayingState) {
        videoPlayer.stop()
      }
      videoPlayer.source = ""
      root.isDownloading = false
    }
  }

  Connections {
    target: p
    function onActiveMediaViewerChanged() {
      if (p.activeMediaViewer) {
        if (p.activeMediaViewer.path && p.activeMediaViewer.path !== "") {
          root.isDownloading = false
          if (p.activeMediaViewer.type === "video") {
            videoPlayer.source = "file://" + p.activeMediaViewer.path
            videoPlayer.play()
          }
        }
      }
    }
  }

  // Dark backdrop
  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.92)

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }
  }

  function close() {
    if (videoPlayer.playbackState === MediaPlayer.PlayingState) {
      videoPlayer.stop()
    }
    p.closeMediaViewer()
  }

  function formatTime(ms) {
    var totalSecs = Math.floor((ms || 0) / 1000)
    var m = Math.floor(totalSecs / 60)
    var s = totalSecs % 60
    return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
  }

  // ---- Main Container Box
  Item {
    anchors.fill: parent
    anchors.margins: Style.space(8)

    // 1. Top Header Toolbar
    BorderSurface {
      id: topToolbar
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: Style.space(42)
      radius: Style.space(10)
      color: Qt.rgba(0, 0, 0, 0.75)
      borderSpec: Border.flat(Qt.rgba(1, 1, 1, 0.12), 1)
      z: 50

      Item {
        anchors.fill: parent
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(12)

        // Left Title / Sender / Info
        Row {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          Text {
            text: root.mediaType === "video" ? "\uf03d" : "\uf03e"
            color: Color.accent
            font.family: p.fontFamily
            font.pixelSize: Style.space(13)
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: (root.messageData && root.messageData.sender_name) ? root.messageData.sender_name : "Media Viewer"
            color: "#ffffff"
            font.family: p.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            visible: root.messageData && root.messageData.time !== ""
            text: root.messageData ? ("• " + root.messageData.time) : ""
            color: Qt.rgba(1, 1, 1, 0.6)
            font.family: p.fontFamily
            font.pixelSize: Style.font.caption
            anchors.verticalCenter: parent.verticalCenter
          }

          // Size / Duration info
          Text {
            visible: root.mediaInfo && (root.mediaInfo.formatted_duration || root.mediaInfo.size)
            text: root.mediaInfo ? ("[" + (root.mediaInfo.formatted_duration ? root.mediaInfo.formatted_duration + " • " : "") + (root.mediaInfo.size || "") + "]") : ""
            color: Qt.rgba(1, 1, 1, 0.5)
            font.family: p.fontFamily
            font.pixelSize: Style.font.caption * 0.9
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        // Right Actions (Zoom / External / Copy / Close)
        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)

          // Zoom Controls (Image mode only)
          Row {
            visible: root.mediaType !== "video"
            spacing: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter

            // Zoom Out
            BorderSurface {
              width: Style.space(26); height: Style.space(26)
              radius: Style.space(6)
              color: zoomOutM.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
              borderSpec: Border.none
              Text {
                anchors.centerIn: parent
                text: "\uf010"
                color: "#ffffff"
                font.family: p.fontFamily
                font.pixelSize: Style.space(10)
              }
              MouseArea {
                id: zoomOutM
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.zoomScale = Math.max(0.5, root.zoomScale - 0.25)
              }
            }

            // Zoom percentage badge / Reset
            BorderSurface {
              height: Style.space(26)
              implicitWidth: zoomPctTxt.implicitWidth + Style.space(12)
              radius: Style.space(6)
              color: zoomResetM.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
              borderSpec: Border.none
              Text {
                id: zoomPctTxt
                anchors.centerIn: parent
                text: Math.round(root.zoomScale * 100) + "%"
                color: "#ffffff"
                font.family: p.fontFamily
                font.pixelSize: Style.font.caption * 0.85
                font.bold: true
              }
              MouseArea {
                id: zoomResetM
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.zoomScale = 1.0; root.panX = 0; root.panY = 0 }
              }
            }

            // Zoom In
            BorderSurface {
              width: Style.space(26); height: Style.space(26)
              radius: Style.space(6)
              color: zoomInM.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
              borderSpec: Border.none
              Text {
                anchors.centerIn: parent
                text: "\uf00e"
                color: "#ffffff"
                font.family: p.fontFamily
                font.pixelSize: Style.space(10)
              }
              MouseArea {
                id: zoomInM
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.zoomScale = Math.min(4.0, root.zoomScale + 0.25)
              }
            }
          }

          // Open in External Player / Viewer
          BorderSurface {
            width: Style.space(28); height: Style.space(28)
            radius: Style.space(6)
            color: openExtM.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)
            borderSpec: Border.none

            Text {
              anchors.centerIn: parent
              text: "\uf08e"
              color: openExtM.containsMouse ? Color.accent : "#ffffff"
              font.family: p.fontFamily
              font.pixelSize: Style.space(11)
            }

            ToolTip.visible: openExtM.containsMouse
            ToolTip.delay: 350
            ToolTip.text: root.mediaType === "video" ? "Open in MPV / Video Player" : "Open in Default System Viewer"

            MouseArea {
              id: openExtM
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                var target = root.mediaPath || root.mediaThumb
                if (target) {
                  p.openMediaExternally(target, root.mediaType === "video" ? "mpv" : "xdg-open")
                }
              }
            }
          }

          // Copy Image / File
          BorderSurface {
            width: Style.space(28); height: Style.space(28)
            radius: Style.space(6)
            color: copyM.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)
            borderSpec: Border.none

            Text {
              anchors.centerIn: parent
              text: "\uf0c5"
              color: copyM.containsMouse ? Color.accent : "#ffffff"
              font.family: p.fontFamily
              font.pixelSize: Style.space(11)
            }

            ToolTip.visible: copyM.containsMouse
            ToolTip.delay: 350
            ToolTip.text: "Copy media file path"

            MouseArea {
              id: copyM
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                var target = root.mediaPath || root.mediaThumb
                if (target) p.copyToClipboard(target)
              }
            }
          }

          // Close Button (Esc)
          BorderSurface {
            width: Style.space(28); height: Style.space(28)
            radius: Style.space(6)
            color: closeBtnM.containsMouse ? Qt.rgba(239/255, 68/255, 68/255, 0.4) : Qt.rgba(1, 1, 1, 0.08)
            borderSpec: Border.none

            Text {
              anchors.centerIn: parent
              text: "\uf00d"
              color: closeBtnM.containsMouse ? "#ef4444" : "#ffffff"
              font.family: p.fontFamily
              font.pixelSize: Style.space(12)
            }

            ToolTip.visible: closeBtnM.containsMouse
            ToolTip.delay: 350
            ToolTip.text: "Close (Esc)"

            MouseArea {
              id: closeBtnM
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.close()
            }
          }
        }
      }
    }

    // 2. Media Content Display Area
    Item {
      id: contentArea
      anchors.top: topToolbar.bottom
      anchors.topMargin: Style.space(8)
      anchors.bottom: (root.mediaType === "video" && videoControlsBar.visible) ? videoControlsBar.top : parent.bottom
      anchors.bottomMargin: (root.mediaType === "video" && videoControlsBar.visible) ? Style.space(8) : 0
      anchors.left: parent.left
      anchors.right: parent.right
      clip: true

      // ---- Photo Display with Pan & Zoom
      Item {
        id: imageContainer
        visible: root.mediaType !== "video"
        anchors.fill: parent

        Image {
          id: mainImg
          anchors.centerIn: parent
          width: Math.min(parent.width, parent.height * 1.5)
          height: parent.height
          source: (root.mediaType !== "video" && root.mediaPath) ? ("file://" + root.mediaPath) : (root.mediaThumb ? ("file://" + root.mediaThumb) : "")
          fillMode: Image.PreserveAspectFit
          smooth: true
          mipmap: true
          scale: root.zoomScale
          transform: Translate { x: root.panX; y: root.panY }
          transformOrigin: Item.Center

          Behavior on scale { NumberAnimation { duration: 120 } }
        }

        // Photo loading indicator if image file is downloading
        BorderSurface {
          visible: root.isDownloading || (mainImg.status === Image.Loading)
          anchors.centerIn: parent
          width: Style.space(180)
          height: Style.space(90)
          radius: Style.space(12)
          color: Qt.rgba(0, 0, 0, 0.8)
          borderSpec: Border.flat(Color.accent, 1)

          Column {
            anchors.centerIn: parent
            spacing: Style.space(8)
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "\uf110"
              color: Color.accent
              font.family: p.fontFamily
              font.pixelSize: Style.space(24)
              RotationAnimation on rotation {
                running: true
                loops: Animation.Infinite
                from: 0; to: 360; duration: 900
              }
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "Loading photo..."
              color: "#ffffff"
              font.family: p.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        MouseArea {
          id: imgDragArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: root.zoomScale > 1.0 ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor

          property real lastX: 0
          property real lastY: 0

          onPressed: function(mouse) {
            lastX = mouse.x
            lastY = mouse.y
          }

          onPositionChanged: function(mouse) {
            if (pressed && root.zoomScale > 1.0) {
              var dx = mouse.x - lastX
              var dy = mouse.y - lastY
              root.panX += dx
              root.panY += dy
              lastX = mouse.x
              lastY = mouse.y
            }
          }

          onWheel: function(wheel) {
            var delta = wheel.angleDelta.y > 0 ? 0.25 : -0.25
            root.zoomScale = Math.max(0.5, Math.min(4.0, root.zoomScale + delta))
            if (root.zoomScale <= 1.0) {
              root.panX = 0
              root.panY = 0
            }
          }

          onDoubleClicked: {
            if (root.zoomScale > 1.1) {
              root.zoomScale = 1.0
              root.panX = 0
              root.panY = 0
            } else {
              root.zoomScale = 2.0
            }
          }
        }
      }

      // ---- Video Display Player
      Item {
        id: videoContainer
        visible: root.mediaType === "video"
        anchors.fill: parent

        MediaPlayer {
          id: videoPlayer
          videoOutput: videoOutput
          audioOutput: AudioOutput {
            id: audioOut
            volume: volSlider.value
            muted: root.isMuted
          }
          loops: root.isLooping ? MediaPlayer.Infinite : 1
        }

        VideoOutput {
          id: videoOutput
          anchors.fill: parent
          fillMode: VideoOutput.PreserveAspectFit
          visible: root.mediaPath !== "" && !root.isDownloading

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (videoPlayer.playbackState === MediaPlayer.PlayingState) {
                videoPlayer.pause()
              } else {
                videoPlayer.play()
              }
            }
          }
        }

        // Thumbnail fallback while downloading
        Image {
          visible: root.mediaPath === "" || root.isDownloading
          anchors.fill: parent
          source: root.mediaThumb ? ("file://" + root.mediaThumb) : ""
          fillMode: Image.PreserveAspectFit
          opacity: 0.6
        }

        // Center Download / Spinner Card
        BorderSurface {
          visible: root.mediaPath === "" || root.isDownloading
          anchors.centerIn: parent
          width: Style.space(220)
          height: Style.space(120)
          radius: Style.space(14)
          color: Qt.rgba(0, 0, 0, 0.85)
          borderSpec: Border.flat(Color.accent, 1.5)

          Column {
            anchors.centerIn: parent
            spacing: Style.space(10)

            // Animated Spinner
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.isDownloading ? "\uf110" : "\uf019"
              color: Color.accent
              font.family: p.fontFamily
              font.pixelSize: Style.space(28)

              RotationAnimation on rotation {
                running: root.isDownloading
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 900
              }
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              textFormat: Text.PlainText
              text: root.isDownloading ? "Downloading video..." : "Download & Play Video"
              color: "#ffffff"
              font.family: p.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            Text {
              visible: root.mediaInfo && root.mediaInfo.size
              anchors.horizontalCenter: parent.horizontalCenter
              textFormat: Text.PlainText
              text: root.mediaInfo ? root.mediaInfo.size : ""
              color: Qt.rgba(1, 1, 1, 0.6)
              font.family: p.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (!root.isDownloading && root.messageData) {
                root.isDownloading = true
                p.downloadMedia(root.messageData.chat_id, root.messageData.id, "video")
              }
            }
          }
        }
      }
    }

    // 3. Bottom Video Controls Bar
    BorderSurface {
      id: videoControlsBar
      visible: root.mediaType === "video" && root.mediaPath !== "" && !root.isDownloading
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      height: Style.space(48)
      radius: Style.space(10)
      color: Qt.rgba(0, 0, 0, 0.75)
      borderSpec: Border.flat(Qt.rgba(1, 1, 1, 0.12), 1)
      z: 50

      Row {
        anchors.fill: parent
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(12)
        spacing: Style.space(10)

        // Play / Pause Button
        BorderSurface {
          width: Style.space(32); height: Style.space(32)
          radius: width / 2
          color: playBtnM.containsMouse ? Color.accent : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
          borderSpec: Border.none
          anchors.verticalCenter: parent.verticalCenter

          Text {
            anchors.centerIn: parent
            text: videoPlayer.playbackState === MediaPlayer.PlayingState ? "\uf04c" : "\uf04b"
            color: playBtnM.containsMouse ? "#ffffff" : Color.accent
            font.family: p.fontFamily
            font.pixelSize: Style.space(12)
          }

          MouseArea {
            id: playBtnM
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (videoPlayer.playbackState === MediaPlayer.PlayingState) videoPlayer.pause()
              else videoPlayer.play()
            }
          }
        }

        // Time elapsed / Total duration
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.formatTime(videoPlayer.position) + " / " + root.formatTime(videoPlayer.duration)
          color: "#ffffff"
          font.family: p.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        // Progress Scrub Bar
        Item {
          id: scrubContainer
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - Style.space(260)
          height: Style.space(20)

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Style.space(4)
            radius: Style.space(2)
            color: Qt.rgba(1, 1, 1, 0.2)

            // Buffer / Progress Track
            Rectangle {
              height: parent.height
              radius: parent.radius
              color: Color.accent
              width: (videoPlayer.duration > 0) ? Math.min(parent.width, parent.width * (videoPlayer.position / videoPlayer.duration)) : 0
            }
          }

          // Scrub handle
          Rectangle {
            visible: scrubM.containsMouse || scrubM.pressed
            width: Style.space(10); height: Style.space(10)
            radius: width / 2
            color: "#ffffff"
            anchors.verticalCenter: parent.verticalCenter
            x: (videoPlayer.duration > 0) ? Math.max(0, Math.min(parent.width - width, (parent.width * (videoPlayer.position / videoPlayer.duration)) - width/2)) : 0
          }

          MouseArea {
            id: scrubM
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) {
              if (videoPlayer.duration > 0) {
                var pos = Math.max(0, Math.min(1.0, mouse.x / width))
                videoPlayer.position = Math.floor(pos * videoPlayer.duration)
              }
            }
            onPositionChanged: function(mouse) {
              if (pressed && videoPlayer.duration > 0) {
                var pos = Math.max(0, Math.min(1.0, mouse.x / width))
                videoPlayer.position = Math.floor(pos * videoPlayer.duration)
              }
            }
          }
        }

        // Volume / Mute Button
        BorderSurface {
          width: Style.space(28); height: Style.space(28)
          radius: Style.space(6)
          color: muteM.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
          borderSpec: Border.none
          anchors.verticalCenter: parent.verticalCenter

          Text {
            anchors.centerIn: parent
            text: root.isMuted || volSlider.value === 0 ? "\uf6a9" : "\uf028"
            color: "#ffffff"
            font.family: p.fontFamily
            font.pixelSize: Style.space(11)
          }

          MouseArea {
            id: muteM
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.isMuted = !root.isMuted
          }
        }

        // Volume Slider
        Item {
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(50)
          height: Style.space(20)

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Style.space(3)
            radius: 1.5
            color: Qt.rgba(1, 1, 1, 0.2)

            Rectangle {
              height: parent.height
              radius: parent.radius
              color: "#ffffff"
              width: parent.width * volSlider.value
            }
          }

          Slider {
            id: volSlider
            anchors.fill: parent
            from: 0.0
            to: 1.0
            value: 1.0
            opacity: 0.0
          }
        }

        // Loop Toggle
        BorderSurface {
          width: Style.space(28); height: Style.space(28)
          radius: Style.space(6)
          color: root.isLooping ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : (loopM.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent")
          borderSpec: Border.none
          anchors.verticalCenter: parent.verticalCenter

          Text {
            anchors.centerIn: parent
            text: "\uf01e"
            color: root.isLooping ? Color.accent : "#ffffff"
            font.family: p.fontFamily
            font.pixelSize: Style.space(11)
          }

          ToolTip.visible: loopM.containsMouse
          ToolTip.delay: 350
          ToolTip.text: root.isLooping ? "Repeat: On" : "Repeat: Off"

          MouseArea {
            id: loopM
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.isLooping = !root.isLooping
          }
        }
      }
    }
  }
}
