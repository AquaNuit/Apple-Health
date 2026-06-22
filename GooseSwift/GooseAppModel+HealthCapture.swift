import Foundation

// MARK: - Health Capture (Simplified for HealthKit)
// The WHOOP-specific health packet capture, temperature capture, physiology capture,
// respiratory packet watch, and BLE-based data streaming have been removed.
// Health data is now ingested passively via GooseHealthKitManager.

extension GooseAppModel {
  func refreshActivityTimeline(for date: Date = Date()) {
    let calendar = Calendar.current
    let dayStart = calendar.startOfDay(for: date)
    let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 60 * 60)
    let queryStart = calendar.date(byAdding: .hour, value: -6, to: dayStart) ?? dayStart
    let queryEnd = calendar.date(byAdding: .hour, value: 6, to: dayEnd) ?? dayEnd
    let queryStartMs = unixMilliseconds(queryStart)
    let queryEndMs = unixMilliseconds(queryEnd)
    let databasePath = HealthDataStore.defaultDatabasePath()
    activityTimelineRefreshGeneration += 1
    let generation = activityTimelineRefreshGeneration

    activityTimelineRefreshQueue.async { [weak self] in
      let result: Result<ActivityTimelineRefreshResult, Error>
      do {
        let report = try GooseRustBridge().request(
          method: "activity.list_sessions_with_metrics",
          args: [
            "database_path": databasePath,
            "start_time_unix_ms": queryStartMs,
            "end_time_unix_ms": queryEndMs,
          ]
        )
        let sessions = report["sessions"] as? [[String: Any]] ?? []
        let rawMetricsBySession = report["metrics_by_session"] as? [String: Any] ?? [:]
        let metricsBySession = rawMetricsBySession.reduce(into: [String: [[String: Any]]]()) { output, element in
          if let metrics = element.value as? [[String: Any]] {
            output[element.key] = metrics
          }
        }
        result = .success(
          Self.activityTimelineRefreshResult(
            sessions: sessions,
            dayStart: dayStart,
            dayEnd: dayEnd,
            metricsBySession: metricsBySession
          )
        )
      } catch {
        result = .failure(error)
      }

      DispatchQueue.main.async { [weak self] in
        guard let self, self.activityTimelineRefreshGeneration == generation else {
          return
        }
        switch result {
        case .success(let refresh):
          self.homeActivityTimelineItems = refresh.items
          self.homeActivityTimelineStatus = refresh.status
        case .failure:
          self.homeActivityTimelineStatus = "Activity timeline failed"
        }
      }
    }
  }
}
