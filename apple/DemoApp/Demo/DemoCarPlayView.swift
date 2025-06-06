import FerrostarCarPlayUI
import SwiftUI

struct DemoCarPlayView: View {
    @State var model: DemoCarPlayModel?

    var body: some View {
        ZStack {
            if let model {
                if let errorMessage = model.errorMessage {
                    ContentUnavailableView(
                        errorMessage, systemImage: "network.slash",
                        description: Text("error navigating.")
                    )
                } else {
                    @Bindable var bindableModel = model
                    CarPlayNavigationView(
                        navigationState: model.model.coreState,
                        styleURL: AppDefaults.mapStyleURL,
                        camera: $bindableModel.model.camera
                    )
                    .overlay {
                        Text(model.appState.description)
                            .foregroundStyle(.red)
                    }
                }
            } else {
                ContentUnavailableView(
                    "cannot create model", systemImage: "network.slash",
                    description: Text("Unable to create model.")
                )
            }
        }
    }
}
