import CarPlay
import FerrostarCarPlayUI
import FerrostarCore
import FerrostarCoreFFI
import FerrostarSwiftUI
import Foundation

@Observable final class DemoCarPlayModel: NSObject, CPMapTemplateDelegate {
    var model: DemoModel
    var session: CPNavigationSession?

    let formatterCollection: FormatterCollection = FoundationFormatterCollection()

    init?(model: DemoModel?) {
        guard let model else { return nil }
        self.model = model
    }

    var appState: DemoAppState { model.appState }
    var errorMessage: String? {
        get {
            model.errorMessage
        }
        set {
            model.errorMessage = newValue
        }
    }

    var core: FerrostarCore { model.core }

    func chooseDestination() {
        model.chooseDestination()
    }

    func loadRoute(_ destination: CLLocationCoordinate2D) async {
        await model.loadRoute(destination)
    }

    func chooseRoute(_ route: Route) {
        model.chooseRoute(route)
    }

    func navigate(_ route: Route) {
        model.navigate(route)
    }

    func stop() {
        session?.cancelTrip()
        model.stop()
    }

    private func start(choice: CPRouteChoice, mapTemplate: CPMapTemplate) {
        do {
            guard let route = choice.route else { throw DemoError.invalidCPRouteChoice }
            startNavigationSession(route, mapTemplate: mapTemplate)
        } catch {
            model.errorMessage = error.localizedDescription
            model.appState = .idle
        }
    }

    private func select(choice: CPRouteChoice) {
        do {
            guard let route = choice.route else { throw DemoError.invalidCPRouteChoice }
            model.chooseRoute(route)
        } catch {
            model.errorMessage = error.localizedDescription
            model.appState = .idle
        }
    }

    private func trackCoreChanges(_ mapTemplate: CPMapTemplate, units: MKDistanceFormatter.Units = .default) {
        withObservationTracking {
            guard let session else { return }
            guard let state = model.coreState else { return }

            state.updateEstimates(mapTemplate: mapTemplate, session: session, units: units)
        } onChange: {
            Task { @MainActor in
                self.trackCoreChanges(mapTemplate, units: units)
            }
        }
    }

    private var start: MKMapItem { MKMapItem(placemark: MKPlacemark(coordinate: model.origin)) }
    private var end: MKMapItem { MKMapItem(placemark: MKPlacemark(coordinate: model.destination)) }

    func trip(_ routes: [Route]) -> CPTrip {
        CPTrip.fromFerrostar(
            routes: routes,
            origin: start,
            destination: end,
            distanceFormatter: formatterCollection.distanceFormatter,
            durationFormatter: formatterCollection.durationFormatter
        )
    }

    func startNavigationSession(_ route: Route, mapTemplate: CPMapTemplate) {
        let trip = trip([route])
        session = mapTemplate.startNavigationSession(for: trip)
        navigate(route)
        trackCoreChanges(mapTemplate)
    }

    func preview(_ routes: [Route], mapTemplate: CPMapTemplate) {
        let trip = trip(routes)
        mapTemplate.showRouteChoicesPreview(for: trip, textConfiguration: nil)
    }

    func mapTemplate(_: CPMapTemplate, selectedPreviewFor _: CPTrip, using routeChoice: CPRouteChoice) {
        // FIXME: Show route on the map.
        select(choice: routeChoice)
    }

    func mapTemplate(_ mapTemplate: CPMapTemplate, startedTrip _: CPTrip, using routeChoice: CPRouteChoice) {
        start(choice: routeChoice, mapTemplate: mapTemplate)
        mapTemplate.hideTripPreviews()
    }

    func mapTemplateDidCancelNavigation(_: CPMapTemplate) {
        stop()
    }
}
