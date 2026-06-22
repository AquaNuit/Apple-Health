import Foundation
import HealthKit

// MARK: - Bridge Payload Types

struct HealthKitBridgePayload: Codable {
  let timestamp: Double
  let metrics: HealthKitBridgeMetrics
}

struct HealthKitBridgeMetrics: Codable {
  let heart_rate_bpm: Double?
  let heart_rate_variability_ms: Double?
  let resting_heart_rate_bpm: Double?
  let sleep_duration_seconds: Double?
  let active_calories_kcal: Double?
  let respiratory_rate_bpm: Double?
}

// MARK: - Mapper

enum HealthKitBridgeMapper {

  // MARK: Heart Rate

  static func mapHeartRateSamples(_ samples: [HKQuantitySample]) -> [HealthKitBridgePayload] {
    samples.map { sample in
      let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
      return HealthKitBridgePayload(
        timestamp: sample.endDate.timeIntervalSince1970,
        metrics: HealthKitBridgeMetrics(
          heart_rate_bpm: bpm,
          heart_rate_variability_ms: nil,
          resting_heart_rate_bpm: nil,
          sleep_duration_seconds: nil,
          active_calories_kcal: nil,
          respiratory_rate_bpm: nil
        )
      )
    }
  }

  // MARK: HRV

  static func mapHRVSamples(_ samples: [HKQuantitySample]) -> [HealthKitBridgePayload] {
    samples.map { sample in
      let ms = sample.quantity.doubleValue(for: .secondUnit(with: .milli))
      return HealthKitBridgePayload(
        timestamp: sample.endDate.timeIntervalSince1970,
        metrics: HealthKitBridgeMetrics(
          heart_rate_bpm: nil,
          heart_rate_variability_ms: ms,
          resting_heart_rate_bpm: nil,
          sleep_duration_seconds: nil,
          active_calories_kcal: nil,
          respiratory_rate_bpm: nil
        )
      )
    }
  }

  // MARK: Resting Heart Rate

  static func mapRestingHeartRateSamples(_ samples: [HKQuantitySample]) -> [HealthKitBridgePayload] {
    samples.map { sample in
      let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
      return HealthKitBridgePayload(
        timestamp: sample.endDate.timeIntervalSince1970,
        metrics: HealthKitBridgeMetrics(
          heart_rate_bpm: nil,
          heart_rate_variability_ms: nil,
          resting_heart_rate_bpm: bpm,
          sleep_duration_seconds: nil,
          active_calories_kcal: nil,
          respiratory_rate_bpm: nil
        )
      )
    }
  }

  // MARK: Sleep Analysis

  static func mapSleepAnalysis(_ samples: [HKCategorySample]) -> HealthKitBridgePayload? {
    let asleepSamples = samples.filter { sample in
      // Filter to actual sleep segments (not "in bed")
      if #available(iOS 16.0, *) {
        return sample.value != HKCategoryValueSleepAnalysis.inBed.rawValue
      }
      return sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
    }
    guard !asleepSamples.isEmpty else {
      return nil
    }

    let totalSeconds = asleepSamples.reduce(0.0) { sum, sample in
      sum + sample.endDate.timeIntervalSince(sample.startDate)
    }
    let latestEnd = asleepSamples.max(by: { $0.endDate < $1.endDate })?.endDate ?? Date()

    return HealthKitBridgePayload(
      timestamp: latestEnd.timeIntervalSince1970,
      metrics: HealthKitBridgeMetrics(
        heart_rate_bpm: nil,
        heart_rate_variability_ms: nil,
        resting_heart_rate_bpm: nil,
        sleep_duration_seconds: totalSeconds,
        active_calories_kcal: nil,
        respiratory_rate_bpm: nil
      )
    )
  }

  // MARK: Active Energy

  static func mapActiveEnergy(_ samples: [HKQuantitySample]) -> HealthKitBridgePayload? {
    guard !samples.isEmpty else {
      return nil
    }

    let totalKcal = samples.reduce(0.0) { sum, sample in
      sum + sample.quantity.doubleValue(for: .kilocalorie())
    }
    let latestEnd = samples.max(by: { $0.endDate < $1.endDate })?.endDate ?? Date()

    return HealthKitBridgePayload(
      timestamp: latestEnd.timeIntervalSince1970,
      metrics: HealthKitBridgeMetrics(
        heart_rate_bpm: nil,
        heart_rate_variability_ms: nil,
        resting_heart_rate_bpm: nil,
        sleep_duration_seconds: nil,
        active_calories_kcal: totalKcal,
        respiratory_rate_bpm: nil
      )
    )
  }

  // MARK: Respiratory Rate

  static func mapRespiratoryRateSamples(_ samples: [HKQuantitySample]) -> [HealthKitBridgePayload] {
    samples.map { sample in
      let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
      return HealthKitBridgePayload(
        timestamp: sample.endDate.timeIntervalSince1970,
        metrics: HealthKitBridgeMetrics(
          heart_rate_bpm: nil,
          heart_rate_variability_ms: nil,
          resting_heart_rate_bpm: nil,
          sleep_duration_seconds: nil,
          active_calories_kcal: nil,
          respiratory_rate_bpm: bpm
        )
      )
    }
  }

  // MARK: - Bridge Packing

  static func packForBridge(_ payloads: [HealthKitBridgePayload]) -> [String: Any] {
    let items: [[String: Any]] = payloads.map { payload in
      var metricsDict: [String: Any] = [:]
      if let v = payload.metrics.heart_rate_bpm { metricsDict["heart_rate_bpm"] = v }
      if let v = payload.metrics.heart_rate_variability_ms { metricsDict["heart_rate_variability_ms"] = v }
      if let v = payload.metrics.resting_heart_rate_bpm { metricsDict["resting_heart_rate_bpm"] = v }
      if let v = payload.metrics.sleep_duration_seconds { metricsDict["sleep_duration_seconds"] = v }
      if let v = payload.metrics.active_calories_kcal { metricsDict["active_calories_kcal"] = v }
      if let v = payload.metrics.respiratory_rate_bpm { metricsDict["respiratory_rate_bpm"] = v }
      return [
        "timestamp": payload.timestamp,
        "metrics": metricsDict,
      ]
    }
    return [
      "source": "apple_health",
      "schema": "goose.healthkit.metrics.v1",
      "samples": items,
    ]
  }
}
