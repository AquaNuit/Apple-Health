import Foundation
import UIKit


@MainActor
final class GooseAppModel: ObservableObject {
  @Published var onboardingComplete = false
  @Published var rustStatus = "Rust bridge not checked"
  @Published var helloSummary = "Client hello not prepared"
  @Published var packetImportRevision = 0
  @Published var packetImportStatus = "No packet import"
  @Published var activityPersistenceStatus = "No activity stored"
  @Published var homeActivityTimelineItems: [ActivityTimelineItem] = []
  @Published var homeActivityTimelineStatus = "Activity timeline not loaded"
  @Published var activityDetectionStatus = "HealthKit-based detection"
  @Published var heartRateHourlyRanges: [HeartRateHourlyRange] = []
  @Published var heartRateStorageStatus = "No HR samples stored"

  let healthKit: GooseHealthKitManager
  let healthKitImporter: GooseHealthKitImporter
  let packetMonitor = PacketMonitorModel()
  let activitySession = ActivitySessionModel()
  let activityLocationTracker = ActivityLocationTracker()
  let rust = GooseRustBridge()
  let rustStartupQueue = DispatchQueue(label: "com.goose.swift.rust-startup", qos: .utility)
  let activityTimelineRefreshQueue = DispatchQueue(label: "com.goose.swift.activity-timeline-refresh", qos: .utility)
  let heartRateSamplePipeline = HeartRateSamplePipeline(
    timelinePublishInterval: GooseAppModel.heartRateHourlyRangePublishInterval
  )
  var activeActivityPersistence: ActiveActivityPersistence?
  var activityTimelineRefreshGeneration = 0

  static let heartRateHourlyRangePublishInterval: TimeInterval = 1

  init() {
    healthKit = GooseHealthKitManager(bridge: rust)
    healthKitImporter = GooseHealthKitImporter(bridge: rust)

    let heartRateSamplePipeline = self.heartRateSamplePipeline
    heartRateSamplePipeline.onHeartRateTimelineSnapshot = { [weak self] snapshot in
      Task { @MainActor in
        self?.applyHeartRateTimelineSnapshot(snapshot)
      }
    }

    refreshHeartRateHourlyRanges()
    prepareClientHello()
    cleanupOrphanedActivityCaptureSessions()
    refreshActivityTimeline()

    Task {
      await healthKit.requestAuthorization()
      healthKit.startSyncLoop()
    }
  }

  deinit {
    healthKit.stopSyncLoop()
  }

  func triggerHealthKitSync() {
    healthKit.triggerManualSync()
  }
}
