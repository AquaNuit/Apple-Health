import Darwin
import Foundation
import SwiftUI
import UIKit

struct SleepDataBridgeSection: View {
  @ObservedObject var store: HealthDataStore

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HealthSectionTitle("Sleep Data")
      VStack(spacing: 8) {
        HealthInfoRow(row: HealthSummaryRow("Band history", value: "Not applicable with Apple Health", source: .unavailable("WHOOP historical sync removed"), systemImage: "antenna.radiowaves.left.and.right"))
        HealthInfoRow(row: HealthSummaryRow("Band sleep import", value: store.bandSleepImportStatus, source: .bridge("band historical packets"), systemImage: "square.stack.3d.up"))
        HealthInfoRow(row: HealthSummaryRow("Goose sleep score", value: store.sleepFeatureScoreSummary(), source: store.packetScoreSource("metrics.sleep_score_from_features"), systemImage: "bed.double"))
      }
      HStack(spacing: 10) {
        Button {
          // No-op for HealthKit
        } label: {
          Label("Sync from band", systemImage: "arrow.down.circle")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(true)

        Button {
          store.refreshSleepAfterBandSync(packetCount: 0)
        } label: {
          Label("Refresh Score", systemImage: "chart.xyaxis.line")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
      }
    }
  }
}

struct SleepAlarmBridgeSection: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HealthSectionTitle("WHOOP Alarm")
      VStack(spacing: 8) {
        HealthInfoRow(row: HealthSummaryRow("Write support", value: "Not applicable with Apple Health", source: .unavailable("WHOOP alarms require BLE connection"), systemImage: "antenna.radiowaves.left.and.right"))
        HealthInfoRow(row: HealthSummaryRow("Last alarm state", value: "Unavailable", source: .unavailable("WHOOP alarms require BLE connection"), systemImage: "bell"))
      }
      
      HStack(spacing: 10) {
        Button {
          // No-op
        } label: {
          Label("Set Alarm", systemImage: "bell.badge")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(true)

        Button {
          // No-op
        } label: {
          Label("Run Now", systemImage: "waveform")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(true)
      }

      Button(role: .destructive) {
        // No-op
      } label: {
        Label("Disable WHOOP Alarms", systemImage: "bell.slash")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .disabled(true)
    }
  }
}

