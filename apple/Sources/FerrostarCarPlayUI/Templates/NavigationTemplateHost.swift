import CarPlay
import FerrostarCore
import FerrostarCoreFFI
import FerrostarSwiftUI

class NavigatingTemplateHost {
    private let mapTemplate: CPMapTemplate
    private let formatters: FormatterCollection
    private let units: MKDistanceFormatter.Units

    private var currentSession: CPNavigationSession?

    init(
        mapTemplate: CPMapTemplate,
        formatters: FormatterCollection,
        units: MKDistanceFormatter.Units,
        showCentering _: Bool, // TODO: Dynamically handle this - it may need to move to a camera listener
        onCenter: @escaping () -> Void,
        onStartTrip: @escaping () -> Void,
        onCancelTrip: @escaping () -> Void
    ) {
        self.mapTemplate = mapTemplate
        self.formatters = formatters
        self.units = units

        // Top Bar
        self.mapTemplate.automaticallyHidesNavigationBar = false
        self.mapTemplate.trailingNavigationBarButtons = [
            // TODO: Dynamically handle start stop.
            CarPlayBarButtons.startNavigationButton { onStartTrip() },
            CarPlayBarButtons.cancelNavigationButton { onCancelTrip() },
        ]

        // Map Buttons
        self.mapTemplate.mapButtons = [
            CarPlayMapButtons.recenterButton { onCenter() },
        ]
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func start(routes: [Route], waypoints: [Waypoint]) throws {
        let currentTrip: CPTrip = try .fromFerrostar(
            routes: routes,
            waypoints: waypoints,
            distanceFormatter: formatters.distanceFormatter,
            durationFormatter: formatters.durationFormatter
        )

        currentSession = mapTemplate.startNavigationSession(for: currentTrip)
    }

    func update(navigationState: NavigationState) {
        updateArrival(navigationState.currentProgress)
    }

    func update(_ instruction: VisualInstruction, currentStep: RouteStep) {
        let stepDistance = CarPlayMeasurementLength(units: units, distance: currentStep.distance)

        currentSession?.upcomingManeuvers = [instruction.maneuver(
            stepDuration: currentStep.duration,
            stepDistance: stepDistance.rounded()
        )]
    }

    func cancelTrip() {
        currentSession?.cancelTrip()
        currentSession = nil
    }

    func completeTrip() {
        currentSession?.finishTrip()
        currentSession = nil
    }

    private func updateArrival(_ progress: TripProgress?) {
        guard let currentSession, let progress else {
            // TODO: Remove Progress?
            return
        }

        let estimates = CPTravelEstimates.fromFerrostarForTrip(
            progress: progress,
            units: units,
            locale: .current
        )

        mapTemplate.updateEstimates(estimates, for: currentSession.trip)

        if let currentManeuer = currentSession.upcomingManeuvers.first {
            let estimates = CPTravelEstimates.fromFerrostarForStep(
                progress: progress,
                units: units,
                locale: .current
            )

            currentSession.updateEstimates(estimates, for: currentManeuer)
        }
    }
}
