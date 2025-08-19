pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Services

Singleton {
  id: root

  // Generic compositor properties
  property string compositorType: "unknown" // "hyprland", "niri", or "unknown"
  property bool isHyprland: false
  property bool isNiri: false

  // Generic workspace and window data
  property ListModel workspaces: ListModel {}
  property var windows: []
  property int focusedWindowIndex: -1
  property string focusedWindowTitle: "(No active window)"
  property bool inOverview: false

  // Generic events
  signal workspaceChanged
  signal activeWindowChanged
  signal overviewStateChanged
  signal windowListChanged

  // Compositor detection
  Component.onCompleted: {
    detectCompositor()
  }

  // Hyprland connections
  Connections {
    target: Hyprland.workspaces
    enabled: isHyprland
    function onValuesChanged() {
      updateHyprlandWorkspaces()
      workspaceChanged()
    }
  }

  Connections {
    target: Hyprland.toplevels
    enabled: isHyprland
    function onValuesChanged() {
      updateHyprlandWindows()
      windowListChanged()
    }
  }

  Connections {
    target: Hyprland
    enabled: isHyprland
    function onRawEvent(event) {
      updateHyprlandWorkspaces()
      workspaceChanged()
      updateHyprlandWindows()
      windowListChanged()
    }
  }

  function detectCompositor() {
    try {
      // Try Hyprland first
      if (Hyprland.eventSocketPath) {
        compositorType = "hyprland"
        isHyprland = true
        isNiri = false
        initHyprland()
        return
      }
    } catch (e) {

      // Hyprland not available
    }

    // Try Niri (always available since we handle it directly)
    compositorType = "niri"
    isHyprland = false
    isNiri = true
    initNiri()
    return

    // No supported compositor found
    compositorType = "unknown"
    isHyprland = false
    isNiri = false
    Logger.warn("Compositor", "No supported compositor detected")
  }

  // Hyprland integration
  function initHyprland() {
    try {
      Hyprland.refreshWorkspaces()
      Hyprland.refreshToplevels()
      updateHyprlandWorkspaces()
      updateHyprlandWindows()
      setupHyprlandConnections()
      Logger.log("Compositor", "Hyprland initialized successfully")
    } catch (e) {
      Logger.error("Compositor", "Error initializing Hyprland:", e)
      compositorType = "unknown"
      isHyprland = false
    }
  }

  function setupHyprlandConnections() {// Connections are set up at the top level, this function just marks that Hyprland is ready
  }

  function updateHyprlandWorkspaces() {
    if (!isHyprland)
      return

    workspaces.clear()
    try {
      const hlWorkspaces = Hyprland.workspaces.values
      for (var i = 0; i < hlWorkspaces.length; i++) {
        const ws = hlWorkspaces[i]
        // Only append workspaces with id >= 1
        if (ws.id >= 1) {
          workspaces.append({
                              "id": i,
                              "idx": ws.id,
                              "name": ws.name || "",
                              "output": ws.monitor?.name || "",
                              "isActive": ws.active === true,
                              "isFocused": ws.focused === true,
                              "isUrgent": ws.urgent === true
                            })
        }
      }
    } catch (e) {
      Logger.error("Compositor", "Error updating Hyprland workspaces:", e)
    }
  }

  function updateHyprlandWindows() {
    if (!isHyprland)
      return

    try {
      const hlToplevels = Hyprland.toplevels.values
      const windowsList = []

      for (var i = 0; i < hlToplevels.length; i++) {
        const toplevel = hlToplevels[i]
        windowsList.push({
                           "id": toplevel.address || "",
                           "title": toplevel.title || "",
                           "appId": toplevel.class || toplevel.initialClass || "",
                           "workspaceId": toplevel.workspace?.id || null,
                           "isFocused": Hyprland.activeToplevel && Hyprland.activeToplevel.address === toplevel.address
                         })
      }

      windows = windowsList

      // Update focused window index
      focusedWindowIndex = -1
      for (var j = 0; j < windowsList.length; j++) {
        if (windowsList[j].isFocused) {
          focusedWindowIndex = j
          break
        }
      }

      updateFocusedWindowTitle()
      activeWindowChanged()
    } catch (e) {
      Logger.error("Compositor", "Error updating Hyprland windows:", e)
    }
  }

  // Niri integration
  function initNiri() {
    try {
      // Start the event stream to receive Niri events
      niriEventStream.running = true
      // Initial load of workspaces and windows
      updateNiriWorkspaces()
      updateNiriWindows()
      Logger.log("Compositor", "Niri initialized successfully")
    } catch (e) {
      Logger.error("Compositor", "Error initializing Niri:", e)
      compositorType = "unknown"
      isNiri = false
    }
  }

  function updateNiriWorkspaces() {
    if (!isNiri)
      return

    // Get workspaces from the Niri process
    niriWorkspaceProcess.running = true
  }

  function updateNiriWindows() {
    if (!isNiri)
      return

    // Get windows from the Niri process
    niriWindowsProcess.running = true
  }

  // Niri workspace process
  Process {
    id: niriWorkspaceProcess
    running: false
    command: ["niri", "msg", "--json", "workspaces"]

    stdout: SplitParser {
      onRead: function (line) {
        try {
          const workspacesData = JSON.parse(line)
          const workspacesList = []

          for (const ws of workspacesData) {
            workspacesList.push({
                                  "id": ws.id,
                                  "idx": ws.idx,
                                  "name": ws.name || "",
                                  "output": ws.output || "",
                                  "isFocused": ws.is_focused === true,
                                  "isActive": ws.is_active === true,
                                  "isUrgent": ws.is_urgent === true,
                                  "isOccupied": ws.active_window_id ? true : false
                                })
          }

          workspacesList.sort((a, b) => {
                                if (a.output !== b.output) {
                                  return a.output.localeCompare(b.output)
                                }
                                return a.id - b.id
                              })

          // Update the workspaces ListModel
          workspaces.clear()
          for (var i = 0; i < workspacesList.length; i++) {
            workspaces.append(workspacesList[i])
          }
          workspaceChanged()
        } catch (e) {
          Logger.error("Compositor", "Failed to parse workspaces:", e, line)
        }
      }
    }
  }

  // Niri event stream process
  Process {
    id: niriEventStream
    running: false
    command: ["niri", "msg", "--json", "event-stream"]

    stdout: SplitParser {
      onRead: data => {
        try {
          const event = JSON.parse(data.trim())

          if (event.WorkspacesChanged) {
            niriWorkspaceProcess.running = true
          } else if (event.WindowsChanged) {
            try {
              const windowsData = event.WindowsChanged.windows
              const windowsList = []
              for (const win of windowsData) {
                windowsList.push({
                                   "id": win.id,
                                   "title": win.title || "",
                                   "appId": win.app_id || "",
                                   "workspaceId": win.workspace_id || null,
                                   "isFocused": win.is_focused === true
                                 })
              }

              windowsList.sort((a, b) => a.id - b.id)
              windows = windowsList
              windowListChanged()

              // Update focused window index
              for (var i = 0; i < windowsList.length; i++) {
                if (windowsList[i].isFocused) {
                  focusedWindowIndex = i
                  break
                }
              }
              updateFocusedWindowTitle()
              activeWindowChanged()
            } catch (e) {
              Logger.error("Compositor", "Error parsing windows event:", e)
            }
          } else if (event.WorkspaceActivated) {
            niriWorkspaceProcess.running = true
          } else if (event.WindowFocusChanged) {
            try {
              const focusedId = event.WindowFocusChanged.id
              if (focusedId) {
                focusedWindowIndex = windows.findIndex(w => w.id === focusedId)
                if (focusedWindowIndex < 0) {
                  focusedWindowIndex = 0
                }
              } else {
                focusedWindowIndex = -1
              }
              updateFocusedWindowTitle()
              activeWindowChanged()
            } catch (e) {
              Logger.error("Compositor", "Error parsing window focus event:", e)
            }
          } else if (event.OverviewOpenedOrClosed) {
            try {
              inOverview = event.OverviewOpenedOrClosed.is_open === true
              overviewStateChanged()
            } catch (e) {
              Logger.error("Compositor", "Error parsing overview state:", e)
            }
          }
        } catch (e) {
          Logger.error("Compositor", "Error parsing event stream:", e, data)
        }
      }
    }
  }

  // Niri windows process (for initial load)
  Process {
    id: niriWindowsProcess
    running: false
    command: ["niri", "msg", "--json", "windows"]

    stdout: SplitParser {
      onRead: function (line) {
        try {
          const windowsData = JSON.parse(line)
          const windowsList = []
          for (const win of windowsData) {
            windowsList.push({
                               "id": win.id,
                               "title": win.title || "",
                               "appId": win.app_id || "",
                               "workspaceId": win.workspace_id || null,
                               "isFocused": win.is_focused === true
                             })
          }

          windowsList.sort((a, b) => a.id - b.id)
          windows = windowsList
          windowListChanged()

          // Update focused window index
          for (var i = 0; i < windowsList.length; i++) {
            if (windowsList[i].isFocused) {
              focusedWindowIndex = i
              break
            }
          }
          updateFocusedWindowTitle()
          activeWindowChanged()
        } catch (e) {
          Logger.error("Compositor", "Failed to parse windows:", e, line)
        }
      }
    }
  }

  function updateFocusedWindowTitle() {
    if (focusedWindowIndex >= 0 && focusedWindowIndex < windows.length) {
      focusedWindowTitle = windows[focusedWindowIndex].title || "(Unnamed window)"
    } else {
      focusedWindowTitle = "(No active window)"
    }
  }

  // Generic workspace switching
  function switchToWorkspace(workspaceId) {
    if (isHyprland) {
      try {
        Hyprland.dispatch(`workspace ${workspaceId}`)
      } catch (e) {
        Logger.error("Compositor", "Error switching Hyprland workspace:", e)
      }
    } else if (isNiri) {
      try {
        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", workspaceId.toString()])
      } catch (e) {
        Logger.error("Compositor", "Error switching Niri workspace:", e)
      }
    } else {
      Logger.warn("Compositor", "No supported compositor detected for workspace switching")
    }
  }

  // Generic logout/shutdown commands
  function logout() {
    if (isHyprland) {
      try {
        Quickshell.execDetached(["hyprctl", "dispatch", "exit"])
      } catch (e) {
        Logger.error("Compositor", "Error logging out from Hyprland:", e)
      }
    } else if (isNiri) {
      try {
        Quickshell.execDetached(["niri", "msg", "action", "quit", "--skip-confirmation"])
      } catch (e) {
        Logger.error("Compositor", "Error logging out from Niri:", e)
      }
    } else {
      Logger.warn("Compositor", "No supported compositor detected for logout")
    }
  }

  // Get current workspace
  function getCurrentWorkspace() {
    for (var i = 0; i < workspaces.count; i++) {
      const ws = workspaces.get(i)
      if (ws.isFocused) {
        return ws
      }
    }
    return null
  }

  // Get focused window
  function getFocusedWindow() {
    if (focusedWindowIndex >= 0 && focusedWindowIndex < windows.length) {
      return windows[focusedWindowIndex]
    }
    return null
  }
}
