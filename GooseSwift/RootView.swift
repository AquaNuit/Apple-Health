import SwiftUI

struct RootView: View {
  @EnvironmentObject private var model: GooseAppModel
  @AppStorage(OnboardingStorage.onboardingComplete) private var onboardingComplete = false
  @AppStorage(OnboardingStorage.onboardingRedoRequested) private var onboardingRedoRequested = false

  var body: some View {
    ZStack(alignment: .top) {
      Group {
        if onboardingComplete {
          AppShellView()
        } else {
          OnboardingView {
            onboardingRedoRequested = false
            onboardingComplete = true
            model.completeOnboarding()
          }
        }
      }
      HealthKitSyncStatusBar(healthKit: model.healthKit)
    }
    .gooseScreenBackground()
    .onAppear {
      mirrorCurrentOnboardingStateIfNeeded()
      restorePersistedOnboardingStateIfNeeded()
      syncModelOnboardingState()
    }
    .onChange(of: onboardingComplete) { _, _ in
      mirrorCurrentOnboardingStateIfNeeded()
      syncModelOnboardingState()
    }
  }

  private func mirrorCurrentOnboardingStateIfNeeded() {
    guard onboardingComplete else {
      return
    }
    OnboardingProfilePersistence.saveProfileFromDefaults(onboardingComplete: true)
  }

  private func restorePersistedOnboardingStateIfNeeded() {
    guard !onboardingComplete, !onboardingRedoRequested else {
      return
    }
    guard
      let state = OnboardingProfilePersistence.restoreIntoDefaultsIfAvailable(restoreCompletion: true),
      state.onboardingComplete
    else {
      return
    }
    onboardingComplete = true
  }

  private func syncModelOnboardingState() {
    guard model.onboardingComplete != onboardingComplete else {
      return
    }
    model.onboardingComplete = onboardingComplete
  }
}

// MARK: - HealthKit Sync Status Indicator (replaces BLE SyncToastHost)

private struct HealthKitSyncStatusBar: View {
  @ObservedObject var healthKit: GooseHealthKitManager

  var body: some View {
    VStack {
      if healthKit.syncStatus == "syncing" {
        HStack(spacing: 8) {
          ProgressView()
            .progressViewStyle(.circular)
            .scaleEffect(0.7)
          Text("Syncing from Apple Health…")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.primary)
            .lineLimit(1)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background {
          Capsule(style: .continuous)
            .fill(syncFill)
        }
        .overlay {
          Capsule(style: .continuous)
            .strokeBorder(syncTint, lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 7)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .transition(.asymmetric(
          insertion: .move(edge: .top).combined(with: .opacity),
          removal: .move(edge: .top).combined(with: .opacity)
        ))
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .allowsHitTesting(false)
    .animation(.spring(response: 0.34, dampingFraction: 0.86), value: healthKit.syncStatus)
  }

  @Environment(\.colorScheme) private var colorScheme

  private var syncTint: Color {
    Color(red: 0.18, green: 0.48, blue: 0.95)
  }

  private var syncFill: Color {
    colorScheme == .dark
      ? Color(red: 0.07, green: 0.16, blue: 0.25)
      : Color(red: 0.84, green: 0.91, blue: 1.0)
  }
}
