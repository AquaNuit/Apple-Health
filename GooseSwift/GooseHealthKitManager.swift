import Foundation
import HealthKit
import os

@MainActor
final class GooseHealthKitManager: ObservableObject {
  // MARK: - Published State (replaces BLE equivalents)

  @Published var latestHeartRateBPM: Int?
  @Published var latestHeartRateDate: Date?
  @Published var restingHeartRateBPM: Double?
  @Published var latestHRVms: Double?
  @Published var latestRespiratoryRate: Double?
  @Published var lastSyncAt: Date?
  @Published var syncStatus: String = "idle"
  @Published var authorizationStatus: String = "Not requested"
  @Published var isAuthorized: Bool = false

  @Published var heartRateSampleCount: Int = 0
  @Published var hrvSampleCount: Int = 0
  @Published var restingHRSampleCount: Int = 0
  @Published var sleepSampleCount: Int = 0
  @Published var activeEnergySampleCount: Int = 0
  @Published var respiratoryRateSampleCount: Int = 0

  // MARK: - Internal State

  let healthStore = HKHealthStore()
  private let logger = Logger(subsystem: "com.goose.swift", category: "HealthKitManager")
  private let bridge: GooseRustBridge
  private var anchorsByType: [HKObjectType: HKQueryAnchor] = [:]
  private var activeQueries: [HKQuery] = []
  private var pollingTimer: Timer?
  private var isPerformingSync = false

  static let pollingInterval: TimeInterval = 15 * 60 // 15 minutes

  // MARK: - HealthKit Types

  static var readTypes: Set<HKObjectType> {
    var types = Set<HKObjectType>()
    if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
      types.insert(heartRate)
    }
    if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
      types.insert(hrv)
    }
    if let restingHR = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
      types.insert(restingHR)
    }
    if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
      types.insert(sleep)
    }
    if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
      types.insert(activeEnergy)
    }
    if let respiratory = HKObjectType.quantityType(forIdentifier: .respiratoryRate) {
      types.insert(respiratory)
    }
    return types
  }

  // MARK: - Init

  init(bridge: GooseRustBridge) {
    self.bridge = bridge
    restoreAnchors()
  }

  // MARK: - Authorization

  func requestAuthorization() async {
    guard HKHealthStore.isHealthDataAvailable() else {
      authorizationStatus = "Health data unavailable on this device"
      isAuthorized = false
      return
    }

    do {
      try await healthStore.requestAuthorization(toShare: Set<HKSampleType>(), read: Self.readTypes)
      authorizationStatus = "Authorized"
      isAuthorized = true
      logger.info("HealthKit authorization granted")
    } catch {
      authorizationStatus = "Authorization failed: \(error.localizedDescription)"
      isAuthorized = false
      logger.error("HealthKit authorization failed: \(error.localizedDescription)")
    }
  }

  // MARK: - Sync Lifecycle

  func startSyncLoop() {
    guard isAuthorized else {
      return
    }
    registerBackgroundDelivery()
    startAnchoredQueries()
    startPollingTimer()
    performSync(reason: "initial")
  }

  func stopSyncLoop() {
    pollingTimer?.invalidate()
    pollingTimer = nil
    for query in activeQueries {
      healthStore.stop(query)
    }
    activeQueries.removeAll()
  }

  func triggerManualSync() {
    performSync(reason: "manual")
  }

  // MARK: - Background Delivery

  private func registerBackgroundDelivery() {
    for type in Self.readTypes {
      guard let sampleType = type as? HKSampleType else { continue }
      healthStore.enableBackgroundDelivery(for: sampleType, frequency: .hourly) { success, error in
        if let error {
          self.logger.warning("Background delivery registration failed for \(sampleType.identifier): \(error.localizedDescription)")
        }
      }
    }
  }

  // MARK: - Anchored Queries

  private func startAnchoredQueries() {
    for type in Self.readTypes {
      guard let sampleType = type as? HKSampleType else { continue }
      let anchor = anchorsByType[type]
      let query = HKAnchoredObjectQuery(
        type: sampleType,
        predicate: nil,
        anchor: anchor,
        limit: HKObjectQueryNoLimit
      ) { [weak self] query, added, deleted, newAnchor, error in
        guard let self else { return }
        Task { @MainActor in
          self.processAnchoredResults(type: sampleType, added: added, newAnchor: newAnchor, error: error)
        }
      }
      query.updateHandler = { [weak self] query, added, deleted, newAnchor, error in
        guard let self else { return }
        Task { @MainActor in
          self.processAnchoredResults(type: sampleType, added: added, newAnchor: newAnchor, error: error)
        }
      }
      healthStore.execute(query)
      activeQueries.append(query)
    }
  }

  private func processAnchoredResults(
    type: HKSampleType,
    added: [HKSample]?,
    newAnchor: HKQueryAnchor?,
    error: Error?
  ) {
    if let error {
      logger.error("Anchored query error for \(type.identifier): \(error.localizedDescription)")
      syncStatus = "error"
      return
    }

    if let newAnchor {
      anchorsByType[type] = newAnchor
      persistAnchor(newAnchor, for: type)
    }

    guard let samples = added, !samples.isEmpty else {
      return
    }

    processNewSamples(samples, type: type)
  }

  // MARK: - Sample Processing

  private func processNewSamples(_ samples: [HKSample], type: HKSampleType) {
    syncStatus = "syncing"

    switch type.identifier {
    case HKQuantityTypeIdentifier.heartRate.rawValue:
      let quantitySamples = samples.compactMap { $0 as? HKQuantitySample }
      heartRateSampleCount += quantitySamples.count
      if let latest = quantitySamples.sorted(by: { $0.endDate > $1.endDate }).first {
        let bpm = latest.quantity.doubleValue(for: HKUnit(from: "count/min"))
        latestHeartRateBPM = Int(bpm.rounded())
        latestHeartRateDate = latest.endDate
      }
      let payloads = HealthKitBridgeMapper.mapHeartRateSamples(quantitySamples)
      sendToBridge(payloads)

    case HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue:
      let quantitySamples = samples.compactMap { $0 as? HKQuantitySample }
      hrvSampleCount += quantitySamples.count
      if let latest = quantitySamples.sorted(by: { $0.endDate > $1.endDate }).first {
        latestHRVms = latest.quantity.doubleValue(for: .secondUnit(with: .milli))
      }
      let payloads = HealthKitBridgeMapper.mapHRVSamples(quantitySamples)
      sendToBridge(payloads)

    case HKQuantityTypeIdentifier.restingHeartRate.rawValue:
      let quantitySamples = samples.compactMap { $0 as? HKQuantitySample }
      restingHRSampleCount += quantitySamples.count
      if let latest = quantitySamples.sorted(by: { $0.endDate > $1.endDate }).first {
        restingHeartRateBPM = latest.quantity.doubleValue(for: HKUnit(from: "count/min"))
      }
      let payloads = HealthKitBridgeMapper.mapRestingHeartRateSamples(quantitySamples)
      sendToBridge(payloads)

    case HKCategoryTypeIdentifier.sleepAnalysis.rawValue:
      let categorySamples = samples.compactMap { $0 as? HKCategorySample }
      sleepSampleCount += categorySamples.count
      if let payload = HealthKitBridgeMapper.mapSleepAnalysis(categorySamples) {
        sendToBridge([payload])
      }

    case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
      let quantitySamples = samples.compactMap { $0 as? HKQuantitySample }
      activeEnergySampleCount += quantitySamples.count
      if let payload = HealthKitBridgeMapper.mapActiveEnergy(quantitySamples) {
        sendToBridge([payload])
      }

    case HKQuantityTypeIdentifier.respiratoryRate.rawValue:
      let quantitySamples = samples.compactMap { $0 as? HKQuantitySample }
      respiratoryRateSampleCount += quantitySamples.count
      if let latest = quantitySamples.sorted(by: { $0.endDate > $1.endDate }).first {
        latestRespiratoryRate = latest.quantity.doubleValue(for: HKUnit(from: "count/min"))
      }
      let payloads = HealthKitBridgeMapper.mapRespiratoryRateSamples(quantitySamples)
      sendToBridge(payloads)

    default:
      break
    }

    lastSyncAt = Date()
    syncStatus = "synced"
  }

  // MARK: - Bridge Communication

  private func sendToBridge(_ payloads: [HealthKitBridgePayload]) {
    guard !payloads.isEmpty else { return }
    let bridgeDict = HealthKitBridgeMapper.packForBridge(payloads)
    do {
      _ = try bridge.request(method: "ingest_healthkit_metrics", args: bridgeDict)
      logger.debug("Sent \(payloads.count) HealthKit payloads to Rust bridge")
    } catch {
      logger.warning("Rust bridge ingest failed: \(error.localizedDescription)")
    }
  }

  // MARK: - Polling Timer

  private func startPollingTimer() {
    pollingTimer?.invalidate()
    pollingTimer = Timer.scheduledTimer(withTimeInterval: Self.pollingInterval, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.performSync(reason: "timer")
      }
    }
  }

  private func performSync(reason: String) {
    guard !isPerformingSync else { return }
    isPerformingSync = true
    syncStatus = "syncing"
    logger.info("HealthKit sync triggered: \(reason)")

    // Re-execute anchored queries to fetch any missed data
    stopSyncLoop()
    startAnchoredQueries()
    startPollingTimer()

    // Mark sync as complete after a short delay to allow queries to fire
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
      self?.isPerformingSync = false
      if self?.syncStatus == "syncing" {
        self?.syncStatus = "synced"
        self?.lastSyncAt = Date()
      }
    }
  }

  // MARK: - Anchor Persistence

  private static let anchorDefaultsKeyPrefix = "GooseHealthKit.anchor."

  private func persistAnchor(_ anchor: HKQueryAnchor, for type: HKObjectType) {
    let key = Self.anchorDefaultsKeyPrefix + type.identifier
    if let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) {
      UserDefaults.standard.set(data, forKey: key)
    }
  }

  private func restoreAnchors() {
    for type in Self.readTypes {
      let key = Self.anchorDefaultsKeyPrefix + type.identifier
      if let data = UserDefaults.standard.data(forKey: key),
         let anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data) {
        anchorsByType[type] = anchor
      }
    }
  }

  // MARK: - Logging Support

  func record(source: String, title: String, body: String = "") {
    logger.info("[\(source)] \(title) \(body)")
  }
}
