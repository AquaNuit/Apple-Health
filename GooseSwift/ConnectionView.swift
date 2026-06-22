import SwiftUI

struct ConnectionView: View {
  @EnvironmentObject private var model: GooseAppModel

  var body: some View {
    ConnectionContentView(healthKit: model.healthKit)
      .environmentObject(model)
  }
}

private struct ConnectionContentView: View {
  @EnvironmentObject private var model: GooseAppModel
  @ObservedObject var healthKit: GooseHealthKitManager

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        connectionStatus
        syncDetails
      }
      .padding(.horizontal, 22)
      .padding(.vertical, 24)
    }
    .gooseScreenBackground()
    .navigationTitle("Connection")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          Task {
            await healthKit.requestAuthorization()
            healthKit.triggerManualSync()
          }
        } label: {
          Image(systemName: "arrow.clockwise")
            .font(.system(size: 16, weight: .semibold))
        }
        .accessibilityLabel("Refresh")
      }
    }
  }

  private var connectionStatus: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("HEALTH SOURCE")
        .font(sectionLabelFont)
        .foregroundStyle(secondaryLabelColor)

      HStack(spacing: 14) {
        Image(systemName: "heart.fill")
          .font(.system(size: 32, weight: .bold))
          .foregroundStyle(heartTint)
          .shadow(color: heartTint.opacity(0.3), radius: 8, y: 4)

        VStack(alignment: .leading, spacing: 5) {
          Text("Apple Health")
            .font(.system(size: 20, weight: .black))
            .foregroundStyle(primaryLabelColor)
          Text(healthKit.authorizationStatus)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(healthKit.isAuthorized ? connectedGreen : disconnectedRed)
        }

        Spacer()

        if !healthKit.isAuthorized {
          Button {
            Task {
              await healthKit.requestAuthorization()
            }
          } label: {
            Text("Authorize")
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(.white)
              .padding(.horizontal, 16)
              .padding(.vertical, 9)
              .background(heartTint, in: Capsule(style: .continuous))
          }
        }
      }
      .padding(18)
      .background(cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
  }

  private var syncDetails: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("SYNC STATUS")
        .font(sectionLabelFont)
        .foregroundStyle(secondaryLabelColor)

      VStack(alignment: .leading, spacing: 16) {
        syncRow(label: "Status", value: healthKit.syncStatus.capitalized)
        syncRow(label: "Last Sync", value: lastSyncDisplay)

        Divider()
          .background(secondaryLabelColor.opacity(0.3))

        syncRow(label: "Heart Rate", value: "\(healthKit.heartRateSampleCount) samples")
        syncRow(label: "HRV", value: "\(healthKit.hrvSampleCount) samples")
        syncRow(label: "Resting HR", value: "\(healthKit.restingHRSampleCount) samples")
        syncRow(label: "Sleep", value: "\(healthKit.sleepSampleCount) sessions")
        syncRow(label: "Active Energy", value: "\(healthKit.activeEnergySampleCount) records")
        syncRow(label: "Respiratory Rate", value: "\(healthKit.respiratoryRateSampleCount) samples")
      }
      .padding(18)
      .background(cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
  }

  @ViewBuilder
  private func syncRow(label: String, value: String) -> some View {
    HStack {
      Text(label)
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(secondaryLabelColor)
      Spacer()
      Text(value)
        .font(.system(size: 14, weight: .black, design: .monospaced))
        .foregroundStyle(primaryLabelColor)
        .lineLimit(1)
    }
  }

  private var lastSyncDisplay: String {
    guard let date = healthKit.lastSyncAt else {
      return "Never"
    }
    if abs(date.timeIntervalSinceNow) < 10 {
      return "Just now"
    }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date()).capitalized
  }
}

// MARK: - Design Tokens

private let heartTint = Color(red: 1.0, green: 0.23, blue: 0.33)
private let connectedGreen = Color(red: 0.42, green: 0.84, blue: 0.30)
private let disconnectedRed = Color(red: 1.0, green: 0.27, blue: 0.23)
private let primaryLabelColor = Color(uiColor: .label)
private let secondaryLabelColor = Color(uiColor: .secondaryLabel)
private let sectionLabelFont = Font.system(size: 15, weight: .black)
private let cardBackground = Color(uiColor: UIColor { traits in
  traits.userInterfaceStyle == .dark
    ? UIColor(red: 0.12, green: 0.16, blue: 0.18, alpha: 1)
    : .secondarySystemGroupedBackground
})
