import WidgetKit
import SwiftUI

@main
struct StepsWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        StepsMediumWidget()
        StepsSmallWidget()
    }
}
