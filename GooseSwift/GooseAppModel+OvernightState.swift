import Foundation

// MARK: - Overnight State (Removed)
// The WHOOP-specific overnight guard state monitoring has been removed.
// Power state, watchdog, readiness evaluation, raw spool management,
// and SQLite mirror state are all WHOOP BLE concepts that do not apply
// to Apple Health ingestion.

extension GooseAppModel {
  // Intentionally empty — overnight BLE state tracking is not applicable with HealthKit ingestion.
}
