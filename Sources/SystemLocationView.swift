import CoreLocation
import MapKit
import SwiftUI

final class SystemLocationObserver: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var errorMessage: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        authorizationStatus = manager.authorizationStatus
    }

    func requestAndStart() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            errorMessage = "定位权限不可用，请到系统设置中允许精确定位。"
        @unknown default:
            errorMessage = "出现未知的定位授权状态。"
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedAlways ||
            manager.authorizationStatus == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
        errorMessage = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }
}

struct SystemLocationView: View {
    @StateObject private var observer = SystemLocationObserver()
    @State private var expectedLatitude = 37.788440
    @State private var expectedLongitude = 112.557732
    @State private var expectedAltitude = 812.5
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var hasCenteredOnFirstFix = false

    var body: some View {
        NavigationStack {
            Form {
                Section("地图验证") {
                    Map(position: $cameraPosition) {
                        Marker("期望位置", coordinate: expectedCoordinate)
                            .tint(.orange)

                        if let location = observer.location {
                            Marker("系统位置", coordinate: location.coordinate)
                                .tint(.blue)

                            MapPolyline(coordinates: [expectedCoordinate, location.coordinate])
                                .stroke(.red, lineWidth: 2)
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    HStack {
                        Button("查看期望点") {
                            centerMap(on: expectedCoordinate)
                        }

                        Spacer()

                        Button("查看系统点") {
                            if let location = observer.location {
                                centerMap(on: location.coordinate)
                            }
                        }
                        .disabled(observer.location == nil)
                    }
                }

                Section("期望值（WGS-84）") {
                    numberField("期望纬度", value: $expectedLatitude)
                    numberField("期望经度", value: $expectedLongitude)
                    numberField("期望海拔（平均海平面，米）", value: $expectedAltitude)
                }

                Section("系统定位") {
                    LabeledContent("授权状态", value: authorizationText)
                    Button("请求权限并开始读取") {
                        observer.requestAndStart()
                    }
                    Button("停止读取", role: .cancel) {
                        observer.stop()
                    }
                }

                if let location = observer.location {
                    Section("验证结果") {
                        resultRow("水平误差", horizontalError(for: location), suffix: " m")
                        resultRow("海拔误差", abs(location.altitude - expectedAltitude), suffix: " m")
                        LabeledContent(
                            "系统海拔是否有效",
                            value: location.verticalAccuracy > 0 ? "有效" : "无效"
                        )
                        Text("蓝色为系统实际回调，橙色为期望点，红线为两者之间的水平误差。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    LocationDetailsView(location: location)
                } else {
                    Section {
                        Text("尚未收到 CLLocation。使用 Xcode GPX 时，此处会显示系统回调的经纬度、海拔和模拟标记。")
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage = observer.errorMessage {
                    Section("错误") {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("系统定位回调")
            .onReceive(observer.$location.compactMap { $0 }) { location in
                guard !hasCenteredOnFirstFix else { return }
                hasCenteredOnFirstFix = true
                centerMap(on: location.coordinate)
            }
            .onDisappear {
                observer.stop()
            }
        }
    }

    private var expectedCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: min(max(expectedLatitude, -90), 90),
            longitude: min(max(expectedLongitude, -180), 180)
        )
    }

    private func horizontalError(for location: CLLocation) -> CLLocationDistance {
        location.distance(
            from: CLLocation(
                latitude: expectedCoordinate.latitude,
                longitude: expectedCoordinate.longitude
            )
        )
    }

    private func centerMap(on coordinate: CLLocationCoordinate2D) {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 1_000,
                longitudinalMeters: 1_000
            )
        )
    }

    private func numberField(_ title: String, value: Binding<Double>) -> some View {
        TextField(
            title,
            value: value,
            format: .number.precision(.fractionLength(0...8))
        )
        .keyboardType(.numbersAndPunctuation)
    }

    private func resultRow(_ title: String, _ value: Double, suffix: String) -> some View {
        LabeledContent(
            title,
            value: "\(value.formatted(.number.precision(.fractionLength(0...3))))\(suffix)"
        )
    }

    private var authorizationText: String {
        switch observer.authorizationStatus {
        case .notDetermined: return "尚未请求"
        case .restricted: return "受限制"
        case .denied: return "已拒绝"
        case .authorizedAlways: return "始终允许"
        case .authorizedWhenInUse: return "使用期间允许"
        @unknown default: return "未知"
        }
    }
}

struct LocationDetailsView: View {
    let location: CLLocation

    var body: some View {
        Section("最近一次 CLLocation") {
            row("纬度", location.coordinate.latitude)
            row("经度", location.coordinate.longitude)
            row("海拔（平均海平面）", location.altitude, suffix: " m")
            row("WGS-84 椭球高", location.ellipsoidalAltitude, suffix: " m")
            row("水平精度", location.horizontalAccuracy, suffix: " m")
            row("垂直精度", location.verticalAccuracy, suffix: " m")
            row("方向", location.course, suffix: "°")
            row("速度", location.speed, suffix: " m/s")
            LabeledContent(
                "软件模拟标记",
                value: (location.sourceInformation?.isSimulatedBySoftware ?? false) ? "是" : "否"
            )
            LabeledContent("时间", value: location.timestamp.formatted())
        }
    }

    private func row(_ title: String, _ value: Double, suffix: String = "") -> some View {
        LabeledContent(
            title,
            value: "\(value.formatted(.number.precision(.fractionLength(0...8))))\(suffix)"
        )
    }
}

