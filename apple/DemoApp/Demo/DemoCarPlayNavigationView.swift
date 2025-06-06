import FerrostarCarPlayUI
import FerrostarCore
import MapLibreSwiftUI
import SwiftUI

struct DemoCarPlayNavigationView: View {
    var model: DemoCarPlayModel
    let styleURL: URL

    var body: some View {
        @Bindable var bindableModel = model
        CarPlayNavigationView(
            navigationState: model.model.coreState,
            styleURL: styleURL,
            camera: $bindableModel.model.camera
        )
    }
}
