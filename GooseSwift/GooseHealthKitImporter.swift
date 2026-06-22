import Foundation
import os

@MainActor
final class GooseHealthKitImporter: ObservableObject, GooseHealthKitXMLParserDelegate {
  @Published var isImporting: Bool = false
  @Published var importProgress: String = ""
  @Published var recordsImported: Int = 0

  private let bridge: GooseRustBridge
  private var parser: GooseHealthKitXMLParser?
  private let logger = Logger(subsystem: "com.goose.swift", category: "HealthKitImporter")

  init(bridge: GooseRustBridge) {
    self.bridge = bridge
  }

  func startImport(from fileURL: URL) {
    guard !isImporting else { return }
    isImporting = true
    recordsImported = 0
    importProgress = "Starting import..."

    parser = GooseHealthKitXMLParser(fileURL: fileURL, batchSize: 2000)
    parser?.delegate = self
    parser?.startParsing()
  }

  // MARK: - GooseHealthKitXMLParserDelegate

  nonisolated func parser(_ parser: GooseHealthKitXMLParser, didParseBatch batch: [ParsedXMLHealthRecord]) {
    let payloads = batch.compactMap { record -> HealthKitBridgePayload? in
      let timestamp = record.endDate.timeIntervalSince1970
      let duration = record.endDate.timeIntervalSince(record.startDate)
      guard let doubleValue = Double(record.value) else {
        // Sleep analysis uses strings instead of numbers for `value`
        if record.type == "HKCategoryTypeIdentifierSleepAnalysis",
           record.value.contains("Asleep") {
          return HealthKitBridgePayload(
            timestamp: timestamp,
            metrics: HealthKitBridgeMetrics(
              heart_rate_bpm: nil,
              heart_rate_variability_ms: nil,
              resting_heart_rate_bpm: nil,
              sleep_duration_seconds: duration,
              active_calories_kcal: nil,
              respiratory_rate_bpm: nil
            )
          )
        }
        return nil
      }

      switch record.type {
      case "HKQuantityTypeIdentifierHeartRate":
        return HealthKitBridgePayload(timestamp: timestamp, metrics: HealthKitBridgeMetrics(heart_rate_bpm: doubleValue, heart_rate_variability_ms: nil, resting_heart_rate_bpm: nil, sleep_duration_seconds: nil, active_calories_kcal: nil, respiratory_rate_bpm: nil))
      case "HKQuantityTypeIdentifierHeartRateVariabilitySDNN":
        return HealthKitBridgePayload(timestamp: timestamp, metrics: HealthKitBridgeMetrics(heart_rate_bpm: nil, heart_rate_variability_ms: doubleValue, resting_heart_rate_bpm: nil, sleep_duration_seconds: nil, active_calories_kcal: nil, respiratory_rate_bpm: nil))
      case "HKQuantityTypeIdentifierRestingHeartRate":
        return HealthKitBridgePayload(timestamp: timestamp, metrics: HealthKitBridgeMetrics(heart_rate_bpm: nil, heart_rate_variability_ms: nil, resting_heart_rate_bpm: doubleValue, sleep_duration_seconds: nil, active_calories_kcal: nil, respiratory_rate_bpm: nil))
      case "HKQuantityTypeIdentifierActiveEnergyBurned":
        return HealthKitBridgePayload(timestamp: timestamp, metrics: HealthKitBridgeMetrics(heart_rate_bpm: nil, heart_rate_variability_ms: nil, resting_heart_rate_bpm: nil, sleep_duration_seconds: nil, active_calories_kcal: doubleValue, respiratory_rate_bpm: nil))
      case "HKQuantityTypeIdentifierRespiratoryRate":
        return HealthKitBridgePayload(timestamp: timestamp, metrics: HealthKitBridgeMetrics(heart_rate_bpm: nil, heart_rate_variability_ms: nil, resting_heart_rate_bpm: nil, sleep_duration_seconds: nil, active_calories_kcal: nil, respiratory_rate_bpm: doubleValue))
      default:
        return nil
      }
    }

    if !payloads.isEmpty {
      let bridgeDict = HealthKitBridgeMapper.packForBridge(payloads)
      do {
        _ = try bridge.request(method: "ingest_healthkit_metrics", args: bridgeDict)
      } catch {
        logger.warning("Failed to ingest batch: \(error.localizedDescription)")
      }
    }

    Task { @MainActor in
      self.recordsImported += batch.count
      self.importProgress = "Imported \(self.recordsImported) records..."
    }
  }

  nonisolated func parserDidFinish(_ parser: GooseHealthKitXMLParser) {
    Task { @MainActor in
      self.isImporting = false
      self.importProgress = "Import complete! (\(self.recordsImported) records)"
      self.logger.info("Historical Apple Health import finished successfully.")
    }
  }

  nonisolated func parser(_ parser: GooseHealthKitXMLParser, didFailWithError error: Error) {
    Task { @MainActor in
      self.isImporting = false
      self.importProgress = "Import failed: \(error.localizedDescription)"
      self.logger.error("Historical Apple Health import failed: \(error.localizedDescription)")
    }
  }
}
