import SwiftUI

@main
struct LocationAltitudeTesterApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
#if DEBUG
            LocationSimulationPanel { _ in
                // 独立测试 App 直接在面板内显示生成结果。
                // 接入正式项目时，将这里替换成业务定位入口。
            }
            .tabItem {
                Label("精确注入", systemImage: "location.fill.viewfinder")
            }
#endif

            SystemLocationView()
                .tabItem {
                    Label("系统回调", systemImage: "antenna.radiowaves.left.and.right")
                }
        }
    }
}

