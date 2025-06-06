import CarPlay
import FerrostarCarPlayUI
import FerrostarCore
import MapLibreSwiftUI
import os
import SwiftUI
import UIKit

private extension Logger {
    static let carPlay = Logger(subsystem: "ferrostar", category: "carplaydelegate")
}

private let ModelKey = "com.stadiamaps.ferrostar.model"

private extension UISceneSession {
    var model: DemoCarPlayModel? {
        get {
            userInfo?[ModelKey] as? DemoCarPlayModel
        }
        set {
            var info = userInfo ?? [:]
            info[ModelKey] = newValue
            userInfo = info
        }
    }
}

@MainActor
private extension CPBarButton {
    convenience init(appState: DemoAppState, model: DemoCarPlayModel, mapTemplate: CPMapTemplate) {
        self.init(title: appState.buttonText, handler: appState.handler(model, mapTemplate: mapTemplate))
    }

    convenience init(model: DemoCarPlayModel, mapTemplate: CPMapTemplate) {
        let appState = model.appState
        self.init(appState: appState, model: model, mapTemplate: mapTemplate)
    }
}

@MainActor
private extension DemoAppState {
    func handler(_ model: DemoCarPlayModel, mapTemplate: CPMapTemplate) -> CPBarButtonHandler {
        { _ in
            Logger.carPlay.debug("\(self.buttonText, privacy: .public)")
            switch self {
            case .idle:
                model.chooseDestination()
                model.updateButtons(mapTemplate)
            case let .destination(coordinate):
                Task {
                    await model.loadRoute(coordinate)
                    model.updateButtons(mapTemplate)
                }
            case let .routes(routes):
                model.preview(routes, mapTemplate: mapTemplate)
                model.updateButtons(mapTemplate)
            case let .selectedRoute(route):
                model.startNavigationSession(route, mapTemplate: mapTemplate)
                model.updateButtons(mapTemplate)
            case .navigating:
                model.stop()
                model.updateButtons(mapTemplate)
            }
        }
    }
}

private extension DemoCarPlayModel {
    private func leadingNavigationBarButtons(_ mapTemplate: CPMapTemplate) -> [CPBarButton] {
        if case .navigating = appState {
            []
        } else {
            [CPBarButton(model: self, mapTemplate: mapTemplate)]
        }
    }

    private func trailingNavigationBarButtons(_ mapTemplate: CPMapTemplate) -> [CPBarButton] {
        if case .idle = appState {
            []
        } else {
            [CPBarButton(appState: .navigating, model: self, mapTemplate: mapTemplate)]
        }
    }

    func updateButtons(_ mapTemplate: CPMapTemplate) {
        mapTemplate.leadingNavigationBarButtons = leadingNavigationBarButtons(mapTemplate)
        mapTemplate.trailingNavigationBarButtons = trailingNavigationBarButtons(mapTemplate)
    }
}

class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        Logger.carPlay.debug("\(#function)")

        guard templateApplicationScene.session.model == nil else {
            Logger.carPlay.error("CarPlay already connected?")
            return
        }
        guard let model = demoModel else {
            Logger.carPlay.error("No shared DemoModel")
            return
        }

        let carPlayModel = DemoCarPlayModel(model: model)
        templateApplicationScene.session.model = carPlayModel

        let view = DemoCarPlayView(model: carPlayModel)

        let vc = UIHostingController(rootView: view)
        window.rootViewController = vc
        window.makeKeyAndVisible()

        let mapTemplate = CPMapTemplate()
        mapTemplate.mapDelegate = carPlayModel
        carPlayModel?.updateButtons(mapTemplate)

        Task { @MainActor in
            do {
                _ = try await interfaceController.setRootTemplate(mapTemplate, animated: true)
            } catch {
                Logger.carPlay.error("Cannot setRootTemplate")
                carPlayModel?.errorMessage = error.localizedDescription
            }
        }
    }

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect _: CPInterfaceController,
        from window: CPWindow
    ) {
        Logger.carPlay.debug("\(#function)")

        guard let model = templateApplicationScene.session.model else {
            Logger.carPlay.error("CarPlay not connected?")
            return
        }

        model.stop()
        window.isHidden = true

        templateApplicationScene.session.model = nil
    }
}
