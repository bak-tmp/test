import CoreLocation
import XCTest
@testable import LocationAltitudeTester

final class LocationSimulationHarnessTests: XCTestCase {
    func testCreatesLocationWithEveryRequestedValue() throws {
        let timestamp = Date(timeIntervalSince1970: 1_799_100_000)
        let input = SimulatedLocationInput(
            latitude: 37.788440,
            longitude: 112.557732,
            altitude: 812.5,
            horizontalAccuracy: 2.5,
            verticalAccuracy: 4.0,
            course: 135.0,
            speed: 1.4
        )

        let location = try LocationSimulationFactory.makeLocation(
            from: input,
            timestamp: timestamp
        )

        XCTAssertEqual(location.coordinate.latitude, input.latitude, accuracy: 0.000_000_1)
        XCTAssertEqual(location.coordinate.longitude, input.longitude, accuracy: 0.000_000_1)
        XCTAssertEqual(location.altitude, input.altitude, accuracy: 0.001)
        XCTAssertEqual(location.horizontalAccuracy, input.horizontalAccuracy, accuracy: 0.001)
        XCTAssertEqual(location.verticalAccuracy, input.verticalAccuracy, accuracy: 0.001)
        XCTAssertEqual(location.course, input.course, accuracy: 0.001)
        XCTAssertEqual(location.speed, input.speed, accuracy: 0.001)
        XCTAssertEqual(location.timestamp, timestamp)
    }

    func testRejectsInvalidCoordinate() {
        var input = SimulatedLocationInput()
        input.latitude = 91

        XCTAssertThrowsError(try LocationSimulationFactory.makeLocation(from: input)) { error in
            XCTAssertEqual(error as? SimulatedLocationError, .invalidLatitude)
        }
    }

    func testRejectsInvalidVerticalAccuracy() {
        var input = SimulatedLocationInput()
        input.verticalAccuracy = 0

        XCTAssertThrowsError(try LocationSimulationFactory.makeLocation(from: input)) { error in
            XCTAssertEqual(error as? SimulatedLocationError, .invalidVerticalAccuracy)
        }
    }
}

