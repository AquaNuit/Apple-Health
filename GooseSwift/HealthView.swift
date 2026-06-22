import Darwin
import Foundation
import SwiftUI
import UIKit

struct HealthView: View {
  @EnvironmentObject private var model: GooseAppModel
  @ObservedObject var store: HealthDataStore

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 22) {
        HealthDashboardStatusHeader(
          catalogStatus: store.catalogStatus,
          usesSampleData: store.usesSampleData
        )

        HealthActivityOverviewSection(
          steps: store.whoopStepsDisplayText(),
          activeEnergy: store.whoopActiveCaloriesDisplayText(),
          stepsFreshness: store.whoopStepsStatusText(),
          stepsSource: store.whoopStepsSource(),
          activeEnergyFreshness: store.whoopActiveCaloriesStatusText(),
          activeEnergySource: store.whoopActiveCaloriesSource(),
          heartRateValue: liveHeartRateValue,
          heartRateStatus: liveHeartRateStatus,
          heartRateSource: liveHeartRateSource
        )

        HealthVitalsPreviewSection(snapshots: vitalSnapshots)

        HealthRouteShortcutSection(
          title: "Explore Health",
          snapshots: snapshots(for: [.sleep, .recovery, .strain, .stress, .cardioLoad, .energyBank])
        )

        HealthRouteShortcutSection(
          title: "Data & Algorithms",
          snapshots: snapshots(for: [.packetInputs, .algorithms, .calibration])
        )
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 18)
    }
    .gooseScreenBackground()
    .navigationTitle("Health")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
    .navigationDestination(for: HealthRoute.self) { route in
      HealthRouteContentView(route: route, store: store)
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          refreshDashboard()
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .accessibilityLabel("Refresh Health")
      }
    }
    .onAppear {
      model.recordUIAction("page.opened", detail: "Health")
      store.loadBridgeCatalogsIfNeeded()
      store.refreshHeartRateTimeline()
    }
  }

  private var landingSnapshots: [HealthMetricSnapshot] {
    store
      .landingSnapshots(
        liveHeartRateBPM: model.healthKit.latestHeartRateBPM,
        liveHeartRateSource: "Apple Health",
        liveHeartRateUpdatedAt: model.healthKit.latestHeartRateDate
      )
  }

  private var vitalSnapshots: [HealthMetricSnapshot] {
    Array(store.healthMonitorSnapshots().prefix(4))
  }

  private var liveHeartRateValue: String {
    guard let bpm = model.healthKit.latestHeartRateBPM else {
      return "--"
    }
    return "\(bpm) bpm"
  }

  private var liveHeartRateStatus: String {
    guard model.healthKit.latestHeartRateBPM != nil else {
      return store.heartRateTimelineStatus
    }
    return HealthDataStore.relativeText(for: model.healthKit.latestHeartRateDate) ?? "Recent"
  }

  private var liveHeartRateSource: HealthDataSource {
    model.healthKit.latestHeartRateBPM == nil
      ? .unavailable("No HealthKit heart-rate data")
      : .live("Apple Health")
  }

  private func snapshots(for routes: [HealthRoute]) -> [HealthMetricSnapshot] {
    routes.compactMap { route in
      landingSnapshots.first { $0.route == route } ?? store.snapshot(for: route)
    }
  }

  @MainActor
  private func refreshDashboard() {
    store.refreshBridgeCatalogs()
    store.refreshHeartRateTimeline()
    store.refreshPacketInputsIfNeeded()
    model.triggerHealthKitSync()
  }
}
