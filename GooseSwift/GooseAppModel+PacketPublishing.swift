import Foundation

// MARK: - Packet Publishing (Simplified for HealthKit)
// The BLE notification handling, packet parsing dispatch, notification ingest/parse queues,
// and WHOOP-specific data signal pipelines have been removed.
// HealthKit data bypasses the packet pipeline entirely and goes through
// GooseHealthKitManager → GooseHealthKitBridgeMapper → GooseRustBridge.

extension GooseAppModel {
  // Retained: heart rate timeline snapshot application (fed from HealthKit instead of BLE)
  // The actual application is in GooseAppModel+Lifecycle.swift via applyHeartRateTimelineSnapshot.
}
