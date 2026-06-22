import SwiftUI

struct MoreDebugView: View {
  @EnvironmentObject private var model: GooseAppModel
  @EnvironmentObject private var packetMonitor: PacketMonitorModel
  @ObservedObject var store: MoreDataStore
  @AppStorage(OnboardingStorage.onboardingComplete) private var onboardingComplete = false
  @AppStorage(OnboardingStorage.onboardingRedoRequested) private var onboardingRedoRequested = false
  @State private var showDestructiveConfirmation = false

  var body: some View {
    List {
      Section("Rust And Parser") {
        MoreInfoRow(title: "Rust Bridge/Core", value: store.coreVersionStatus, systemImage: "shippingbox", status: store.coreVersionStatus.hasPrefix("Rust core") ? .ready : .pending)
        MoreInfoRow(title: "Frame Parse", value: store.frameParseStatus, systemImage: "curlybraces.square", status: store.frameParseStatus.hasPrefix("Parsed") ? .ready : .pending)
        MoreInfoRow(title: "CRC", value: store.frameCRCStatus, systemImage: "checkmark.seal", status: .pending)
        MoreInfoRow(title: "Payload", value: store.framePayloadStatus, systemImage: "doc.text.magnifyingglass", status: .pending)
        MoreInfoRow(title: "Warnings", value: store.frameWarningsStatus, systemImage: "exclamationmark.triangle", status: store.frameWarningsStatus == "No warnings" ? .ready : .stale)
        MoreInfoRow(title: "Timeline", value: store.frameTimelineStatus, systemImage: "timeline.selection", status: .pending)
        Button {
          store.runFrameParseProbe()
        } label: {
          Label("Run Parser Probe", systemImage: "play.circle")
        }
      }

      Section("Debug Session") {
        MoreInfoRow(title: "WebSocket", value: store.debugWebSocketStatus, systemImage: "network", status: store.debugWebSocketStatus.contains("started") ? .ready : .pending)
        MoreInfoRow(title: "Next Action", value: store.debugNextAction, systemImage: "arrow.forward.circle", status: .pending)
        Button {
          store.startDebugSession()
        } label: {
          Label("Start Debug Session", systemImage: "play.circle")
        }
        Button {
          store.refreshDebugSnapshot()
        } label: {
          Label("Refresh Snapshot", systemImage: "arrow.clockwise")
        }
      }

      Section("Apple Health Data Source") {
        MoreInfoRow(
          title: "Data Source",
          value: "Apple Health | \(model.healthKit.isAuthorized ? "Authorized" : "Not Authorized")",
          systemImage: "heart.fill",
          status: model.healthKit.isAuthorized ? .ready : .blocked
        )
        MoreInfoRow(
          title: "Sync Status",
          value: model.healthKit.syncStatus.capitalized,
          systemImage: "arrow.triangle.2.circlepath",
          status: model.healthKit.syncStatus == "idle" ? .ready : .pending
        )
        MoreInfoRow(
          title: "Heart Rate",
          value: "\(model.healthKit.heartRateSampleCount) samples | \(model.healthKit.latestHeartRateBPM.map { "\($0) bpm" } ?? "—")",
          systemImage: "heart",
          status: model.healthKit.heartRateSampleCount > 0 ? .ready : .pending
        )
        MoreInfoRow(
          title: "HRV",
          value: "\(model.healthKit.hrvSampleCount) samples | \(model.healthKit.latestHRVms.map { String(format: "%.0f ms", $0) } ?? "—")",
          systemImage: "waveform.path.ecg",
          status: model.healthKit.hrvSampleCount > 0 ? .ready : .pending
        )
        MoreInfoRow(
          title: "Resting HR",
          value: "\(model.healthKit.restingHRSampleCount) samples | \(model.healthKit.restingHeartRateBPM.map { String(format: "%.0f bpm", $0) } ?? "—")",
          systemImage: "heart.circle",
          status: model.healthKit.restingHRSampleCount > 0 ? .ready : .pending
        )
        MoreInfoRow(
          title: "Sleep",
          value: "\(model.healthKit.sleepSampleCount) sessions",
          systemImage: "moon.zzz.fill",
          status: model.healthKit.sleepSampleCount > 0 ? .ready : .pending
        )
        MoreInfoRow(
          title: "Active Energy",
          value: "\(model.healthKit.activeEnergySampleCount) records",
          systemImage: "flame.fill",
          status: model.healthKit.activeEnergySampleCount > 0 ? .ready : .pending
        )
        MoreInfoRow(
          title: "Respiratory Rate",
          value: "\(model.healthKit.respiratoryRateSampleCount) samples | \(model.healthKit.latestRespiratoryRate.map { String(format: "%.1f rpm", $0) } ?? "—")",
          systemImage: "lungs.fill",
          status: model.healthKit.respiratoryRateSampleCount > 0 ? .ready : .pending
        )
        MoreActionRow(
          title: "Sync Now",
          detail: "Triggers a manual HealthKit sync for all data types",
          systemImage: "arrow.triangle.2.circlepath",
          status: model.healthKit.isAuthorized ? .pending : .blocked,
          disabled: !model.healthKit.isAuthorized
        ) {
          model.triggerHealthKitSync()
        }
        MoreActionRow(
          title: "Request Authorization",
          detail: "Opens the HealthKit authorization sheet",
          systemImage: "lock.open",
          status: model.healthKit.isAuthorized ? .ready : .pending,
          disabled: false
        ) {
          Task {
            await model.healthKit.requestAuthorization()
          }
        }
        MoreActionRow(
          title: "Import Historical Data",
          detail: model.healthKitImporter.isImporting ? model.healthKitImporter.importProgress : "Import export.xml from Documents",
          systemImage: "arrow.down.doc.fill",
          status: model.healthKitImporter.isImporting ? .pending : .ready,
          disabled: model.healthKitImporter.isImporting
        ) {
          let docsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
          let exportUrl = docsUrl.appendingPathComponent("apple-health-export/export.xml")
          model.healthKitImporter.startImport(from: exportUrl)
        }
      }

      Section("Health Packet Capture") {
        MoreInfoRow(
          title: "Session",
          value: model.healthPacketCaptureStatus,
          systemImage: "record.circle",
          status: self.healthPacketCaptureStatus
        )
        MoreInfoRow(
          title: "Last Packet",
          value: model.healthPacketCaptureLastPacketSummary,
          systemImage: "waveform.path.ecg.rectangle",
          status: model.healthPacketCaptureLastPacketSummary == "No packets captured" ? .pending : .ready
        )
        MoreInfoRow(
          title: "Live Data",
          value: packetMonitor.liveDeviceDataSummary,
          systemImage: "dot.radiowaves.left.and.right",
          status: packetMonitor.recentDeviceSignalPoints.isEmpty ? .pending : .ready
        )
        if model.healthPacketCaptureFamilyRows.isEmpty {
          MoreInfoRow(
            title: "Families",
            value: "No decoded packet families in this capture yet",
            systemImage: "list.bullet.rectangle",
            status: .pending
          )
        } else {
          ForEach(model.healthPacketCaptureFamilyRows.prefix(10)) { family in
            MoreInfoRow(
              title: "\(family.title) x\(family.count)",
              value: family.detail,
              systemImage: self.healthPacketFamilyIcon(family),
              status: self.healthPacketFamilyStatus(family)
            )
          }
        }
      }

      Section("Diagnostics") {
        MoreInfoRow(title: "UI Coverage", value: store.uiCoverageStatus, systemImage: "rectangle.3.group", status: .pending)
        MoreInfoRow(title: "Deferred Surfaces", value: store.deferredSurfaceStatus, systemImage: "rectangle.badge.plus", status: .pending)
        MoreInfoRow(title: "Property Suite", value: store.propertySuiteStatus, systemImage: "checklist", status: .pending)
        MoreInfoRow(title: "Perf Budget", value: store.perfBudgetStatus, systemImage: "speedometer", status: .pending)
        Button {
          store.runUICoverageAudit()
        } label: {
          Label("Run UI Coverage", systemImage: "rectangle.3.group")
        }
        Button {
          store.runPropertySuite()
        } label: {
          Label("Run Property Suite", systemImage: "checklist")
        }
        Button {
          store.runPerfBudget()
        } label: {
          Label("Run Perf Budget", systemImage: "speedometer")
        }
      }

      Section("Command Evidence") {
        MoreInfoRow(title: "Evidence Import", value: store.commandEvidenceImportStatus, systemImage: "doc.text.magnifyingglass", status: .unavailable)
        MoreInfoRow(title: "Gate Sweep", value: store.commandGateSweepStatus, systemImage: "checkmark.shield", status: .pending)
        MoreInfoRow(title: "Capture Plan", value: store.commandCapturePlanStatus, systemImage: "scope", status: store.validationStatusKind(store.commandCapturePlanStatus))
        Button {
          store.loadCommandDefinitions()
        } label: {
          Label("Load Command Definitions", systemImage: "list.bullet.rectangle")
        }
        Button {
          store.runCaptureArrivalPlan()
        } label: {
          Label("Run Capture Arrival Plan", systemImage: "scope")
        }
      }

      Section("Command Shortcuts") {
        ForEach(store.commandGroups) { group in
          MoreCommandGroupRow(group: group)
        }
      }

      Section("Protected Controls") {
        Button {
          showDestructiveConfirmation = true
        } label: {
          Label("Destructive Commands Locked", systemImage: "lock.shield")
        }
        MoreInfoRow(title: "Gate", value: store.destructiveGateStatus, systemImage: "lock", status: .blocked)
      }

#if DEBUG
      Section("Developer") {
        Button {
          model.recordUIAction("ui.debug.redo_onboarding")
          OnboardingProfilePersistence.requestRedoFromDefaults()
          model.onboardingComplete = false
          onboardingComplete = false
          onboardingRedoRequested = true
        } label: {
          Label("Re-do Onboarding", systemImage: "arrow.counterclockwise.circle")
        }
      }
#endif
    }
    .gooseListBackground()
    .navigationTitle("Debug")
    .onAppear {
      model.recordUIAction("page.opened", detail: "More Debug")
      store.refreshBridgeStatus(model: model)
    }
    .alert("Destructive commands are locked", isPresented: $showDestructiveConfirmation) {
      Button("Keep Locked", role: .cancel) {
        store.showDestructiveGate()
      }
    } message: {
      Text("This surface records the gate only. No haptics, firmware, config, or reboot command is sent from this tap.")
    }
  }

  private var healthPacketCaptureStatus: MoreStatusKind {
    if model.healthPacketCaptureSessionID != nil {
      return .pending
    }
    if model.healthPacketCaptureStatus.hasPrefix("Stopped") {
      return .ready
    }
    if model.healthPacketCaptureStatus.contains("failed") {
      return .blocked
    }
    return .pending
  }

  private func healthPacketFamilyStatus(_ family: HealthPacketCaptureFamily) -> MoreStatusKind {
    switch family.status {
    case .target:
      return .ready
    case .expected:
      return .pending
    case .unresolved:
      return .stale
    case .unknown:
      return .blocked
    }
  }

  private func healthPacketFamilyIcon(_ family: HealthPacketCaptureFamily) -> String {
    switch family.status {
    case .target:
      return "scope"
    case .expected:
      return "waveform.path.ecg"
    case .unresolved:
      return "questionmark.diamond"
    case .unknown:
      return "questionmark.circle"
    }
  }
}
