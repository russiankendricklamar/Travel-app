import SwiftUI
import WidgetKit

@main
struct TravelWidgetBundle: WidgetBundle {
    var body: some Widget {
        TravelLiveActivity()
        TrackingLiveActivity()
        CountdownWidget()
    }
}
