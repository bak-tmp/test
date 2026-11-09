#if DEBUG

import CoreLocation
import SwiftUI

/// 测试输入全部使用 Core Location 的原始单位：
/// - 经纬度：WGS-84 十进制度
/// - 海拔：相对平均海平面的米数
/// - 精度：米
/// - 方向：从正北开始顺时针的角度
/// - 速度：米/秒
struct SimulatedLocationInput: Equatable {
    var latitude: Double = 37.788440
    var longitude: Double = 112.557732
    var altitude: Double = 812.5
    var horizontalAccuracy: Double = 3.0
    var verticalAccuracy: Double = 5.0
    var course: Double = 0.0
    var speed: Double = 0.0
}

enum SimulatedLocationError: LocalizedError, Equatable {
    case invalidLatitude
    case invalidLongitude
    case invalidAltitude
    case invalidHorizontalAccuracy
    case invalidVerticalAccuracy
    case invalidCourse
    case invalidSpeed

    var errorDescription: String? {
        switch self {
        case .invalidLatitude:
            return "纬度必须是 -90 到 90 之间的有限数值"
        case .invalidLongitude:
            return "经度必须是 -180 到 180 之间的有限数值"
        case .invalidAltitude:
            return "海拔必须是有限数值，单位为米"
        case .invalidHorizontalAccuracy:
            return "水平精度必须大于 0 米"
        case .invalidVerticalAccuracy:
            return "垂直精度必须大于 0 米，否则系统会把海拔视为无效"
        case .invalidCourse:
            return "方向必须是 0（含）到 360（不含）之间的角度"
        case .invalidSpeed:
            return "速度必须是大于或等于 0 的有限数值"
        }
    }
}

enum LocationSimulationFactory {
    static func makeLocation(
        from input: SimulatedLocationInput,
        timestamp: Date = Date()
    ) throws -> CLLocation {
        guard input.latitude.isFinite, (-90.0...90.0).contains(input.latitude) else {
            throw SimulatedLocationError.invalidLatitude
        }
        guard input.longitude.isFinite, (-180.0...180.0).contains(input.longitude) else {
            throw SimulatedLocationError.invalidLongitude
        }
        guard input.altitude.isFinite else {
            throw SimulatedLocationError.invalidAltitude
        }
        guard input.horizontalAccuracy.isFinite, input.horizontalAccuracy > 0 else {
            throw SimulatedLocationError.invalidHorizontalAccuracy
        }
        guard input.verticalAccuracy.isFinite, input.verticalAccuracy > 0 else {
            throw SimulatedLocationError.invalidVerticalAccuracy
        }
        guard input.course.isFinite, input.course >= 0, input.course < 360 else {
            throw SimulatedLocationError.invalidCourse
        }
        guard input.speed.isFinite, input.speed >= 0 else {
            throw SimulatedLocationError.invalidSpeed
        }

        return CLLocation(
            coordinate: CLLocationCoordinate2D(
                latitude: input.latitude,
                longitude: input.longitude
            ),
            altitude: input.altitude,
            horizontalAccuracy: input.horizontalAccuracy,
            verticalAccuracy: input.verticalAccuracy,
            course: input.course,
            speed: input.speed,
            timestamp: timestamp
        )
    }
}

@MainActor
final class LocationSimulationController: ObservableObject {
    @Published private(set) var lastLocation: CLLocation?
    @Published private(set) var errorMessage: String?

    private let onLocation: (CLLocation) -> Void

    init(onLocation: @escaping (CLLocation) -> Void) {
        self.onLocation = onLocation
    }

    func simulate(_ input: SimulatedLocationInput) {
        do {
            let location = try LocationSimulationFactory.makeLocation(from: input)
            lastLocation = location
            errorMessage = nil
            onLocation(location)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// 只会在 DEBUG 构建中出现的独立定位测试面板。
/// `onLocation` 应连接到应用自己的定位业务入口，而不是直接写入生产服务器。
struct LocationSimulationPanel: View {
    @State private var input = SimulatedLocationInput()
    @StateObject private var controller: LocationSimulationController

    init(onLocation: @escaping (CLLocation) -> Void) {
        _controller = StateObject(
            wrappedValue: LocationSimulationController(onLocation: onLocation)
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("WGS-84 坐标") {
                    numberField("纬度", value: $input.latitude)
                    numberField("经度", value: $input.longitude)
                    numberField("海拔（米，平均海平面）", value: $input.altitude)
                }

                Section("精度") {
                    numberField("水平精度（米）", value: $input.horizontalAccuracy)
                    numberField("垂直精度（米）", value: $input.verticalAccuracy)
                }

                Section("运动状态") {
                    numberField("方向（0–359.999°）", value: $input.course)
                    numberField("速度（米/秒）", value: $input.speed)
                }

                Section {
                    Button("发送模拟定位") {
                        controller.simulate(input)
                    }
                    .frame(maxWidth: .infinity)
                }

                if let errorMessage = controller.errorMessage {
                    Section("输入错误") {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                if let location = controller.lastLocation {
                    Section("最近一次发送") {
                        valueRow("纬度", location.coordinate.latitude)
                        valueRow("经度", location.coordinate.longitude)
                        valueRow("海拔", location.altitude, suffix: " m")
                        valueRow("水平精度", location.horizontalAccuracy, suffix: " m")
                        valueRow("垂直精度", location.verticalAccuracy, suffix: " m")
                        valueRow("方向", location.course, suffix: "°")
                        valueRow("速度", location.speed, suffix: " m/s")
                        LabeledContent("时间", value: location.timestamp.formatted())
                    }
                }
            }
            .navigationTitle("定位模拟测试")
        }
    }

    private func numberField(_ title: String, value: Binding<Double>) -> some View {
        TextField(
            title,
            value: value,
            format: .number.precision(.fractionLength(0...8))
        )
        .keyboardType(.numbersAndPunctuation)
    }

    private func valueRow(
        _ title: String,
        _ value: Double,
        suffix: String = ""
    ) -> some View {
        LabeledContent(title, value: "\(value.formatted(.number.precision(.fractionLength(0...8))))\(suffix)")
    }
}

#endif

