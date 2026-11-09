# iOS 定位模拟测试组件

这是一个只用于测试的独立 iOS App，可模拟并验证：

- WGS-84 纬度、经度
- 相对平均海平面的海拔
- 水平精度、垂直精度
- 速度、方向和时间戳

不需要服务器，也不依赖 WrapPin。代码注入用于确定性业务测试；`TestRoute.gpx` 用于 Xcode/Core Location 集成测试。App 包含两个页面：

- **精确注入**：自行输入全部 CLLocation 字段并查看生成结果。
- **系统回调**：读取 CLLocationManager 返回的真实或 Xcode GPX 定位，显示海拔、两种精度和 `isSimulatedBySoftware`。

## 生成完整 Xcode 工程

已提供 `project.yml`，在 macOS 安装 XcodeGen 后执行：

```bash
brew install xcodegen
cd iOSLocationSimulationDemo
xcodegen generate
open LocationAltitudeTester.xcodeproj
```

## 通过 GitHub Actions 生成未签名 IPA

目录中的 `.github/workflows/build-unsigned-ipa.yml` 会在 GitHub 的 macOS 执行器上：

1. 生成 Xcode 工程。
2. 执行三个 XCTest 测试。
3. 编译真机 Debug App。
4. 输出 `LocationAltitudeTester-unsigned.ipa`。

将本目录内容作为 GitHub 仓库根目录推送，在 Actions 中运行 **Build unsigned test IPA**，然后下载构建产物。这个 IPA 没有签名，可在 SideStore 中重新签名后安装。

## 加入现有工程

1. 把 `LocationSimulationHarness.swift` 添加到 App target。
2. 把 `LocationSimulationHarnessTests.swift` 添加到 Unit Test target。
3. 在应用已有的定位数据入口接收测试位置。例如：

```swift
#if DEBUG
LocationSimulationPanel { location in
    // 替换成你现有的位置处理入口。
    locationStore.accept(location)
}
#endif
```

这里的 `locationStore.accept(location)` 只是示例。关键点是让真实 `CLLocationManager` 和测试面板最终调用同一个业务入口，从而验证距离、围栏、海拔和上传参数等逻辑。

## 运行自动测试

把测试文件加入 Unit Test target 后，在 Xcode 中执行：

```text
Product → Test
```

测试会验证创建出的 `CLLocation` 是否完整保留经纬度、海拔、精度、速度、方向和时间戳，并验证非法输入会被拒绝。

## 使用 GPX 测试系统定位链路

1. 把 `TestRoute.gpx` 加入 Xcode 工程。
2. 打开 `Product → Scheme → Edit Scheme → Run → Options`。
3. 开启 `Allow Location Simulation` 并选择 `TestRoute`。
4. 用 Xcode 启动真机或模拟器上的 App。

GPX 适合验证 `CLLocationManager` 回调和路线变化，但不能自定义 `horizontalAccuracy`、`verticalAccuracy` 等所有字段；需要精确控制全部字段时，应使用代码注入测试。

## 坐标与海拔约定

- Core Location 和 GPX 输入统一使用 WGS-84，不要先转成 GCJ-02。
- `CLLocation.altitude` 是相对近似平均海平面的高度。
- `verticalAccuracy` 必须大于 `0`，否则海拔应被视为无效。
- 如果地图 SDK 需要 GCJ-02，只在地图显示适配层进行一次转换，业务和服务器应明确保存哪种坐标系。

## 安全边界

精确注入组件被 `#if DEBUG` 包围，Release 构建不会包含测试面板。云构建明确使用 Debug 配置生成这个专用测试 App。不要把可任意提交模拟坐标的入口放进正式业务版本，也不要让它直接连接生产数据。

