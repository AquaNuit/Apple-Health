import Foundation
import UIKit
import os

private let activityLogger = Logger(subsystem: "com.goose.swift", category: "ActivityRecording")

extension GooseAppModel {
  func beginActivityRecording(
    activity: ActivityKind,
    startedAt: Date,
    source: String = "ios.live_activity",
    detectionMethod: String = "user_assigned",
    syncStatus: String = "user_confirmed"
  ) {
    if detectionMethod == "user_assigned" {
      finishAutoDetectedActivityIfActive(endedAt: startedAt, reason: "manual_activity_started")
    }

    let activitySessionID = "ios.activity.\(UUID().uuidString)"
    let existingCaptureSessionID = activeActivityPersistence?.captureSessionID
    let captureSessionID = existingCaptureSessionID ?? "\(activitySessionID).capture"
    let ownsCaptureSession = existingCaptureSessionID == nil
    activeActivityOwnsCaptureSession = ownsCaptureSession
    activeActivityPersistence = ActiveActivityPersistence(
      activitySessionID: activitySessionID,
      captureSessionID: captureSessionID,
      startedAt: startedAt,
      source: source,
      detectionMethod: detectionMethod,
      syncStatus: syncStatus,
      importedFrameCount: 0
    )
    activityPersistenceStatus = syncStatus == "candidate" ? "Candidate \(activity.title)" : "Recording \(activity.title)"

    if ownsCaptureSession {
      do {
        _ = try rust.request(
          method: "capture.start_session",
          args: [
            "database_path": HealthDataStore.defaultDatabasePath(),
            "session_id": captureSessionID,
            "source": source,
            "started_at_unix_ms": unixMilliseconds(startedAt),
            "device_model": "Apple Health",
            "active_device_id": NSNull(),
            "provenance": [
              "activity_session_id": activitySessionID,
              "activity_type": rustActivityType(for: activity),
              "activity_title": activity.title,
              "started_by": source,
              "detection_method": detectionMethod,
              "sync_status": syncStatus,
              "capture_mode": "activity",
            ],
          ]
        )
        activityLogger.info("activity.capture.start.ok: \(captureSessionID)")
      } catch {
        activityLogger.error("activity.capture.start.failed: \(error.localizedDescription)")
      }
    } else {
      activityLogger.info("activity.capture.attach_existing: \(captureSessionID)")
    }
  }

  func finishActivityRecording(
    activity: ActivityKind,
    startedAt: Date?,
    endedAt: Date,
    elapsed: TimeInterval,
    averageHeartRate: Int?,
    maxHeartRate: Int?,
    zoneDurations: [Int: TimeInterval],
    distanceMeters: Double,
    elevationGainMeters: Double,
    routePointCount: Int,
    source: String = "ios.live_activity",
    detectionMethod: String = "user_assigned",
    syncStatus: String = "user_confirmed",
    confidence: Double = 1.0,
    extraProvenance: [String: Any] = [:]
  ) {
    let persistence = activeActivityPersistence
    let ownsCaptureSession = activeActivityOwnsCaptureSession
    activeActivityPersistence = nil
    activeActivityOwnsCaptureSession = false

    let sessionID = persistence?.activitySessionID ?? "ios.activity.\(UUID().uuidString)"
    let captureSessionID = persistence?.captureSessionID
    let start = startedAt ?? persistence?.startedAt ?? endedAt.addingTimeInterval(-max(elapsed, 1))
    let end = max(endedAt, start.addingTimeInterval(1))
    let startMs = unixMilliseconds(start)
    let endMs = unixMilliseconds(end)
    let activityType = rustActivityType(for: activity)
    let sessionSource = persistence?.source ?? source
    let sessionDetectionMethod = persistence?.detectionMethod ?? detectionMethod
    let sessionSyncStatus = persistence?.syncStatus ?? syncStatus
    let boundedConfidence = min(max(confidence, 0), 1)
    let persistedElapsed = max(end.timeIntervalSince(start), 1)
    let activeTimerElapsed = max(elapsed, 0)
    let storesLocationMetrics = activity.usesGPS
    let sensorMetrics = sessionDetectionMethod == "user_assigned"
      ? persistence?.sensorMetricSnapshot(endedAt: end)
      : nil
    let metricAverageHeartRate = sensorMetrics?.averageHeartRate ?? averageHeartRate
    let metricMaxHeartRate = sensorMetrics?.maxHeartRate ?? maxHeartRate
    let metricZoneDurations = normalizedZoneDurations(
      sensorMetrics?.zoneDurations ?? zoneDurations,
      targetDuration: persistedElapsed,
      fallbackHeartRate: metricAverageHeartRate
    )

    if let captureSessionID, ownsCaptureSession {
      do {
        _ = try rust.request(
          method: "capture.finish_session",
          args: [
            "database_path": HealthDataStore.defaultDatabasePath(),
            "session_id": captureSessionID,
            "ended_at_unix_ms": endMs,
            "frame_count": persistence?.importedFrameCount ?? 0,
          ]
        )
        activityLogger.info("activity.capture.finish.ok: \(captureSessionID) frames=\(persistence?.importedFrameCount ?? 0)")
      } catch {
        activityLogger.error("activity.capture.finish.failed: \(error.localizedDescription)")
      }
    }

    var provenance: [String: Any] = [
      "capture_session_id": captureSessionID ?? NSNull(),
      "device_id": NSNull(),
      "device_model": "Apple Health",
      "distance_source": storesLocationMetrics ? "ios.core_location" : "none",
      "heart_rate_source": "apple_health",
      "route_point_count": storesLocationMetrics ? routePointCount : 0,
      "imported_frame_count": persistence?.importedFrameCount ?? 0,
      "source": sessionSource,
      "detection_method": sessionDetectionMethod,
      "sync_status": sessionSyncStatus,
      "activity_elapsed_seconds": persistedElapsed,
      "active_timer_elapsed_seconds": activeTimerElapsed,
      "heart_rate_metric_source": sensorMetrics?.hasHeartRate == true ? "apple_health" : "ui_timer_live_hr",
    ]
    if let sensorMetrics, sensorMetrics.movementPacketCount > 0 {
      provenance["movement_packet_count"] = sensorMetrics.movementPacketCount
      provenance["mean_motion_intensity_0_to_1"] = sensorMetrics.meanMotionIntensity
      provenance["peak_motion_intensity_0_to_1"] = sensorMetrics.peakMotionIntensity
    }
    if let lastImportedFrameAt = persistence?.lastImportedFrameAt {
      provenance["last_imported_frame_at"] = Self.captureTimestampFormatter.string(from: lastImportedFrameAt)
    }
    for (key, value) in extraProvenance {
      provenance[key] = value
    }

    do {
      _ = try rust.request(
        method: "activity.create_session",
        args: [
          "database_path": HealthDataStore.defaultDatabasePath(),
          "session_id": sessionID,
          "source": sessionSource,
          "start_time_unix_ms": startMs,
          "end_time_unix_ms": endMs,
          "activity_type": activityType,
          "external_activity_type_name": activityExternalName(for: activity),
          "custom_label": activity.title,
          "confidence": boundedConfidence,
          "detection_method": sessionDetectionMethod,
          "sync_status": sessionSyncStatus,
          "provenance": provenance,
        ]
      )

      var activityMetrics: [[String: Any]] = []
      appendActivityMetric(&activityMetrics, sessionID: sessionID, name: "duration", value: persistedElapsed, unit: "s", startMs: startMs, endMs: endMs, source: sessionSource)
      if abs(activeTimerElapsed - persistedElapsed) > 1 {
        appendActivityMetric(&activityMetrics, sessionID: sessionID, name: "active_duration", value: activeTimerElapsed, unit: "s", startMs: startMs, endMs: endMs, source: sessionSource)
      }
      if storesLocationMetrics {
        appendActivityMetric(&activityMetrics, sessionID: sessionID, name: "distance", value: max(distanceMeters, 0), unit: "m", startMs: startMs, endMs: endMs, source: sessionSource)
        appendActivityMetric(&activityMetrics, sessionID: sessionID, name: "route_points", value: Double(routePointCount), unit: "count", startMs: startMs, endMs: endMs, source: sessionSource)
        appendActivityMetric(&activityMetrics, sessionID: sessionID, name: "elevation_gain", value: max(elevationGainMeters, 0), unit: "m", startMs: startMs, endMs: endMs, source: sessionSource)
      }
      if let metricAverageHeartRate {
        appendActivityMetric(&activityMetrics, sessionID: sessionID, name: "average_hr", value: Double(metricAverageHeartRate), unit: "bpm", startMs: startMs, endMs: endMs, source: sessionSource)
      }
      if let metricMaxHeartRate {
        appendActivityMetric(&activityMetrics, sessionID: sessionID, name: "max_hr", value: Double(metricMaxHeartRate), unit: "bpm", startMs: startMs, endMs: endMs, source: sessionSource)
      }
      for zoneID in 1...5 {
        let seconds = metricZoneDurations[zoneID, default: 0]
        appendActivityMetric(&activityMetrics, sessionID: sessionID, name: "hr_zone_\(zoneID)_duration", value: seconds, unit: "s", startMs: startMs, endMs: endMs, source: sessionSource)
      }
      attachActivityMetrics(activityMetrics)

      let storedPrefix = sessionSyncStatus == "candidate" ? "Stored candidate" : "Stored"
      let storedDistance = storesLocationMetrics ? " \(formatPersistedDistance(distanceMeters))" : ""
      let logDistance = storesLocationMetrics ? "\(Int(distanceMeters.rounded()))m" : "no distance"
      activityPersistenceStatus = "\(storedPrefix) \(activity.title)\(storedDistance)"
      activityLogger.info("activity.session.store.ok: \(sessionID) \(activityType) \(logDistance)")
      refreshActivityTimeline(for: end)
    } catch {
      activityPersistenceStatus = "Activity store failed"
      activityLogger.error("activity.session.store.failed: \(error.localizedDescription)")
    }
  }
}
