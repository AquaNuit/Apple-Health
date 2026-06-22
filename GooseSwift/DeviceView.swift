import SwiftUI
import UIKit

struct DeviceView: View {
  @EnvironmentObject private var model: GooseAppModel

  var body: some View {
    DeviceContentView(healthKit: model.healthKit)
      .environmentObject(model)
  }
}

private struct DeviceContentView: View {
  @EnvironmentObject private var model: GooseAppModel
  @ObservedObject var healthKit: GooseHealthKitManager

  var body: some View {
    ZStack {
      deviceScreenBackground.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          HealthSourceHeader(
            authorized: healthKit.isAuthorized,
            statusText: healthKit.isAuthorized ? "AUTHORIZED" : "NOT AUTHORIZED",
            lastSync: lastSyncSummary
          )
          .padding(.bottom, 30)

          HealthSourceIcon()
            .padding(.bottom, 36)

          MetricAvailabilityGrid(healthKit: healthKit)
            .padding(.bottom, 28)

          HealthSourceActions(healthKit: healthKit, model: model)
        }
        .padding(.horizontal, 22)
        .padding(.top, 36)
        .padding(.bottom, 28)
      }
    }
    .navigationTitle("Health Source")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
    .tint(devicePrimaryText)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          model.triggerHealthKitSync()
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .foregroundStyle(devicePrimaryText)
        .accessibilityLabel("Refresh")
      }
    }
  }

  private var lastSyncSummary: String {
    relativeSummary(for: healthKit.lastSyncAt) ?? "Not synced"
  }
}

// MARK: - Header

private struct HealthSourceHeader: View {
  let authorized: Bool
  let statusText: String
  let lastSync: String

  var body: some View {
    HStack(alignment: .bottom, spacing: 16) {
      VStack(alignment: .leading, spacing: 7) {
        Text(statusText)
          .font(deviceLabelFont)
          .foregroundStyle(authorized ? connectedGreen : disconnectedRed)
          .lineLimit(1)
        Text("APPLE HEALTH")
          .font(.system(size: 26, weight: .black, design: .default))
          .foregroundStyle(devicePrimaryText)
          .lineLimit(2)
          .minimumScaleFactor(0.78)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      VStack(alignment: .trailing, spacing: 7) {
        Text("LAST SYNCED")
          .font(deviceLabelFont)
          .foregroundStyle(secondaryText)
        HStack(spacing: 8) {
          Text(lastSync)
            .font(deviceBodyFont.weight(.black))
            .foregroundStyle(devicePrimaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
          Image(systemName: "heart.text.square")
            .font(.system(size: 24, weight: .regular))
            .foregroundStyle(secondaryText)
        }
      }
    }
  }
}

// MARK: - Health Source Icon

private struct HealthSourceIcon: View {
  var body: some View {
    HStack {
      Spacer()
      Image(systemName: "heart.fill")
        .font(.system(size: 80, weight: .bold))
        .foregroundStyle(
          LinearGradient(
            colors: [
              Color(red: 1.0, green: 0.23, blue: 0.33),
              Color(red: 0.98, green: 0.36, blue: 0.45),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .shadow(color: Color(red: 1.0, green: 0.23, blue: 0.33).opacity(0.35), radius: 20, y: 8)
        .accessibilityLabel("Apple Health")
      Spacer()
    }
    .padding(.vertical, 16)
  }
}

// MARK: - Metric Availability Grid

private struct MetricAvailabilityGrid: View {
  @ObservedObject var healthKit: GooseHealthKitManager

  private let columns = [
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("DATA AVAILABILITY")
        .font(deviceLabelFont)
        .foregroundStyle(secondaryText)

      LazyVGrid(columns: columns, spacing: 12) {
        MetricCard(
          title: "Heart Rate",
          systemImage: "heart.fill",
          count: healthKit.heartRateSampleCount,
          value: healthKit.latestHeartRateBPM.map { "\($0) bpm" },
          tint: Color(red: 1.0, green: 0.27, blue: 0.33)
        )
        MetricCard(
          title: "HRV",
          systemImage: "waveform.path.ecg",
          count: healthKit.hrvSampleCount,
          value: healthKit.latestHRVms.map { String(format: "%.0f ms", $0) },
          tint: Color(red: 0.35, green: 0.78, blue: 0.98)
        )
        MetricCard(
          title: "Resting HR",
          systemImage: "heart.circle",
          count: healthKit.restingHRSampleCount,
          value: healthKit.restingHeartRateBPM.map { String(format: "%.0f bpm", $0) },
          tint: Color(red: 0.95, green: 0.55, blue: 0.25)
        )
        MetricCard(
          title: "Sleep",
          systemImage: "moon.zzz.fill",
          count: healthKit.sleepSampleCount,
          value: nil,
          tint: Color(red: 0.58, green: 0.39, blue: 0.91)
        )
        MetricCard(
          title: "Active Energy",
          systemImage: "flame.fill",
          count: healthKit.activeEnergySampleCount,
          value: nil,
          tint: Color(red: 0.98, green: 0.75, blue: 0.18)
        )
        MetricCard(
          title: "Respiratory",
          systemImage: "lungs.fill",
          count: healthKit.respiratoryRateSampleCount,
          value: healthKit.latestRespiratoryRate.map { String(format: "%.1f rpm", $0) },
          tint: Color(red: 0.40, green: 0.85, blue: 0.55)
        )
      }
    }
  }
}

private struct MetricCard: View {
  let title: String
  let systemImage: String
  let count: Int
  let value: String?
  let tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: systemImage)
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(tint)
        Text(title)
          .font(.system(size: 14, weight: .black))
          .foregroundStyle(devicePrimaryText)
          .lineLimit(1)
      }
      HStack(spacing: 4) {
        Image(systemName: count > 0 ? "checkmark.circle.fill" : "circle.dashed")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(count > 0 ? .green : mutedText)
        if let value {
          Text(value)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(secondaryText)
            .lineLimit(1)
        } else {
          Text(count > 0 ? "\(count) samples" : "No data")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(count > 0 ? secondaryText : mutedText)
            .lineLimit(1)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(controlBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
  }
}

// MARK: - Actions

private struct HealthSourceActions: View {
  @ObservedObject var healthKit: GooseHealthKitManager
  @ObservedObject var model: GooseAppModel

  private let columns = [
    GridItem(.flexible(), spacing: 10),
    GridItem(.flexible(), spacing: 10),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("ACTIONS")
        .font(deviceLabelFont)
        .foregroundStyle(secondaryText)

      LazyVGrid(columns: columns, spacing: 10) {
        HealthSourceActionButton(title: "Sync Now", systemName: "arrow.triangle.2.circlepath") {
          model.triggerHealthKitSync()
        }
        HealthSourceActionButton(title: "Open Health", systemName: "heart.text.square") {
          if let url = URL(string: "x-apple-health://") {
            UIApplication.shared.open(url)
          }
        }
      }
    }
  }
}

private struct HealthSourceActionButton: View {
  let title: String
  let systemName: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: systemName)
          .font(.system(size: 15, weight: .bold))
        Text(title)
          .font(.system(size: 15, weight: .black, design: .default))
          .lineLimit(1)
          .minimumScaleFactor(0.78)
      }
      .frame(maxWidth: .infinity, minHeight: 46)
      .padding(.horizontal, 10)
      .foregroundStyle(devicePrimaryText)
      .background(controlBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Helpers

private func relativeSummary(for date: Date?) -> String? {
  guard let date else {
    return nil
  }
  if abs(date.timeIntervalSinceNow) < 10 {
    return "Now"
  }
  let formatter = RelativeDateTimeFormatter()
  formatter.unitsStyle = .short
  return formatter.localizedString(for: date, relativeTo: Date()).capitalized
}

// MARK: - Design Tokens

private let deviceScreenBackground = GooseTheme.appBackground
private let devicePrimaryText = Color(uiColor: .label)
private let controlBackground = Color(uiColor: UIColor { traits in
  traits.userInterfaceStyle == .dark
    ? UIColor(red: 0.12, green: 0.16, blue: 0.18, alpha: 1)
    : .secondarySystemGroupedBackground
})
private let secondaryText = Color(uiColor: UIColor { traits in
  traits.userInterfaceStyle == .dark
    ? UIColor(red: 0.63, green: 0.65, blue: 0.67, alpha: 1)
    : .secondaryLabel
})
private let mutedText = Color(uiColor: UIColor { traits in
  traits.userInterfaceStyle == .dark
    ? UIColor(red: 0.56, green: 0.58, blue: 0.60, alpha: 1)
    : .tertiaryLabel
})
private let connectedGreen = Color(red: 0.42, green: 0.84, blue: 0.30)
private let disconnectedRed = Color(red: 1.0, green: 0.27, blue: 0.23)
private let deviceLabelFont = Font.system(size: 15, weight: .black, design: .default)
private let deviceBodyFont = Font.system(size: 17, weight: .bold, design: .default)
