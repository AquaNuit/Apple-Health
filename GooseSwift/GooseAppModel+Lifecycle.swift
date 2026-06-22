import Foundation
import UIKit
import os

private let lifecycleLogger = Logger(subsystem: "com.goose.swift", category: "Lifecycle")

extension GooseAppModel {
  func handleAppLifecycleChange(_ phase: String) {
    lifecycleLogger.info("scene_phase: \(phase)")
    if phase == "active" {
      healthKit.triggerManualSync()
    }
  }

  func completeOnboarding() {
    onboardingComplete = true
    lifecycleLogger.info("onboarding.complete")
  }

  func recordUIAction(_ title: String, detail: String = "") {
    lifecycleLogger.info("[\(title)] \(detail)")
  }

  @discardableResult
  func handleDebugCommandDeepLink(_ url: URL) -> Bool {
    guard ["gooseswift", "goose"].contains(url.scheme?.lowercased() ?? ""),
          url.host == "debug-command" else {
      return false
    }
    lifecycleLogger.info("debug_command.deep_link: \(url.absoluteString)")
    return true
  }

  func refreshHeartRateHourlyRanges(for date: Date = Date()) {
    heartRateSamplePipeline.refreshHeartRateTimeline(for: date)
  }

  func applyHeartRateTimelineSnapshot(_ snapshot: HeartRateTimelineSnapshot) {
    heartRateHourlyRanges = snapshot.ranges
    heartRateStorageStatus = snapshot.status
  }
}
