import Foundation

// MARK: - Overnight Run (Removed)
// The WHOOP-specific overnight guard run logic has been removed.
// Overnight health data is now sourced passively from Apple Health via
// GooseHealthKitManager, which uses HKAnchoredObjectQuery and
// background delivery to fetch sleep analysis and heart rate data.

extension GooseAppModel {
  // Intentionally empty — overnight BLE guard run is not applicable with HealthKit ingestion.
}
