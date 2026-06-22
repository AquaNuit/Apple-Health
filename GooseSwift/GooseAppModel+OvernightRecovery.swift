import Foundation

// MARK: - Overnight Recovery (Removed)
// The WHOOP-specific overnight recovery session logic has been removed.
// Sleep recovery is now driven by HKCategoryTypeIdentifierSleepAnalysis
// data from Apple Health, collected passively via GooseHealthKitManager.

extension GooseAppModel {
  // Intentionally empty — overnight BLE recovery is not applicable with HealthKit ingestion.
}
