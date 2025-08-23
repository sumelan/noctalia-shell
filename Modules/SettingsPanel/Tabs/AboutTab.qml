import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services
import qs.Widgets

ColumnLayout {
  id: root

  property string latestVersion: GitHubService.latestVersion
  property string currentVersion: "Unknown" // Fallback version
  property var contributors: GitHubService.contributors

  spacing: 0
  Layout.fillWidth: true
  Layout.fillHeight: true

  Process {
    id: currentVersionProcess

    command: ["sh", "-c", "cd " + Quickshell.shellDir + " && git describe --tags --abbrev=0 2>/dev/null || echo 'Unknown'"]
    Component.onCompleted: {
      running = true
    }

    stdout: StdioCollector {
      onStreamFinished: {
        const version = text.trim()
        if (version && version !== "Unknown") {
          root.currentVersion = version
        } else {
          currentVersionProcess.command = ["sh", "-c", "cd " + Quickshell.shellDir
                                           + " && cat package.json 2>/dev/null | grep '\"version\"' | cut -d'\"' -f4 || echo 'Unknown'"]
          currentVersionProcess.running = true
        }
      }
    }
  }

  ScrollView {
    id: scrollView

    Layout.fillWidth: true
    Layout.fillHeight: true
    padding: Style.marginL * scaling
    rightPadding: Style.marginM * scaling
    clip: true
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    ScrollBar.vertical.policy: ScrollBar.AsNeeded

    ColumnLayout {
      width: scrollView.availableWidth
      spacing: 0

      NText {
        text: "Noctalia: quiet by design"
        font.pointSize: Style.fontSizeXXXL * scaling
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
        Layout.alignment: Qt.AlignCenter
        Layout.bottomMargin: Style.marginS * scaling
      }

      NText {
        text: "It may just be another quickshell setup but it won't get in your way."
        font.pointSize: Style.fontSizeM * scaling
        color: Color.mOnSurface
        Layout.alignment: Qt.AlignCenter
        Layout.bottomMargin: Style.marginL * scaling
      }

      GridLayout {
        Layout.alignment: Qt.AlignCenter
        columns: 2
        rowSpacing: Style.marginXS * scaling
        columnSpacing: Style.marginS * scaling

        NText {
          text: "Latest Version:"
          color: Color.mOnSurface
          Layout.alignment: Qt.AlignRight
        }

        NText {
          text: root.latestVersion
          color: Color.mOnSurface
          font.weight: Style.fontWeightBold
        }

        NText {
          text: "Installed Version:"
          color: Color.mOnSurface
          Layout.alignment: Qt.AlignRight
        }

        NText {
          text: root.currentVersion
          color: Color.mOnSurface
          font.weight: Style.fontWeightBold
        }
      }

      Rectangle {
        Layout.alignment: Qt.AlignCenter
        Layout.topMargin: Style.marginS * scaling
        Layout.preferredWidth: updateText.implicitWidth + 46 * scaling
        Layout.preferredHeight: Style.barHeight * scaling
        radius: Style.radiusL * scaling
        color: updateArea.containsMouse ? Color.mPrimary : Color.transparent
        border.color: Color.mPrimary
        border.width: Math.max(1, Style.borderS * scaling)
        visible: {
          if (root.currentVersion === "Unknown" || root.latestVersion === "Unknown")
            return false

          const latest = root.latestVersion.replace("v", "").split(".")
          const current = root.currentVersion.replace("v", "").split(".")
          for (var i = 0; i < Math.max(latest.length, current.length); i++) {
            const l = parseInt(latest[i] || "0")
            const c = parseInt(current[i] || "0")
            if (l > c)
              return true

            if (l < c)
              return false
          }
          return false
        }

        RowLayout {
          anchors.centerIn: parent
          spacing: Style.marginS * scaling

          NIcon {
            text: "system_update"
            font.pointSize: Style.fontSizeXXL * scaling
            color: updateArea.containsMouse ? Color.mSurface : Color.mPrimary
          }

          NText {
            id: updateText
            text: "Download latest release"
            font.pointSize: Style.fontSizeL * scaling
            color: updateArea.containsMouse ? Color.mSurface : Color.mPrimary
          }
        }

        MouseArea {
          id: updateArea

          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            Quickshell.execDetached(["xdg-open", "https://github.com/Ly-sec/Noctalia/releases/latest"])
          }
        }
      }

      NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginL * 2 * scaling
        Layout.bottomMargin: Style.marginL * scaling
      }

      NText {
        text: `Shout-out to our ${root.contributors.length} awesome contributors!`
        font.pointSize: Style.fontSizeL * scaling
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
        Layout.alignment: Qt.AlignCenter
        Layout.topMargin: Style.marginL * 2
      }

      ScrollView {
        Layout.alignment: Qt.AlignCenter
        Layout.preferredWidth: 200 * Style.marginXS * scaling
        Layout.fillHeight: true
        Layout.topMargin: Style.marginL * scaling
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        GridView {
          id: contributorsGrid

          anchors.fill: parent
          width: 200 * 4 * scaling
          height: Math.ceil(root.contributors.length / 4) * 100
          cellWidth: Style.baseWidgetSize * 6.25 * scaling
          cellHeight: Style.baseWidgetSize * 3.125 * scaling
          model: root.contributors

          delegate: Rectangle {
            width: contributorsGrid.cellWidth - Style.marginL * scaling
            height: contributorsGrid.cellHeight - Style.marginXS * scaling
            radius: Style.radiusL * scaling
            color: contributorArea.containsMouse ? Color.mSecondary : Color.transparent

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.marginS * scaling
              spacing: Style.marginM * scaling

              Item {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Style.baseWidgetSize * 2 * scaling
                Layout.preferredHeight: Style.baseWidgetSize * 2 * scaling

                NImageCircled {
                  imagePath: modelData.avatar_url || ""
                  anchors.fill: parent
                  anchors.margins: Style.marginXS * scaling
                  fallbackIcon: "person"
                  borderColor: Color.mPrimary
                  borderWidth: Math.max(1, Style.borderM * scaling)
                }
              }

              ColumnLayout {
                spacing: Style.marginXS * scaling
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true

                NText {
                  text: modelData.login || "Unknown"
                  font.weight: Style.fontWeightBold
                  color: contributorArea.containsMouse ? Color.mSurface : Color.mOnSurface
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                NText {
                  text: (modelData.contributions || 0) + " " + ((modelData.contributions
                                                                 || 0) === 1 ? "commit" : "commits")
                  font.pointSize: Style.fontSizeXS * scaling
                  color: contributorArea.containsMouse ? Color.mSurface : Color.mOnSurface
                }
              }
            }

            MouseArea {
              id: contributorArea

              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (modelData.html_url)
                  Quickshell.execDetached(["xdg-open", modelData.html_url])
              }
            }
          }
        }
      }
    }
  }
}
