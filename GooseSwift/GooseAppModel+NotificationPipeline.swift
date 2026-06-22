import Foundation

// MARK: - Notification Pipeline (Removed)
// The BLE notification handling, frame reassembly, packet parsing dispatch,
// and WHOOP-specific notification ingest pipeline have been removed.
// HealthKit data bypasses the notification pipeline entirely and goes through
// GooseHealthKitManager → GooseHealthKitBridgeMapper → GooseRustBridge.

extension GooseAppModel {
  // Intentionally empty — BLE notification pipeline is not applicable with HealthKit ingestion.

  func prepareClientHello() {
    helloSummary = "HealthKit mode — no BLE hello required"
    rustStartupQueue.async { [weak self] in
      do {
        let result = try GooseRustBridge().request(method: "status")
        let version = result["version"] as? String ?? "unknown"
        DispatchQueue.main.async {
          self?.rustStatus = "Rust v\(version) ready"
        }
      } catch {
        DispatchQueue.main.async {
          self?.rustStatus = "Rust bridge error: \(error.localizedDescription)"
        }
      }
    }
  }

  func cleanupOrphanedActivityCaptureSessions() {
    // Retained: cleanup logic is independent of BLE
    let databasePath = HealthDataStore.defaultDatabasePath()
    rustStartupQueue.async {
      do {
        _ = try GooseRustBridge().request(
          method: "capture.cleanup_orphaned_sessions",
          args: ["database_path": databasePath]
        )
      } catch {
        // Best effort cleanup
      }
    }
  }
}
