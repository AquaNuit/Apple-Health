import CoreLocation
import MapKit
import SwiftUI
import UIKit

struct LiveActivityView: View {
  @EnvironmentObject private var model: GooseAppModel

  var body: some View {
    LiveActivityContentView(
      healthKit: model.healthKit,
      session: model.activitySession,
      locationTracker: model.activityLocationTracker
    )
    .environmentObject(model)
  }
}

