import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 16.4, *) {
      SimpleLiveShortcuts.updateAppShortcutParameters()
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "SimpleLiveNativeBridge"
    ) {
      let messenger = registrar.messenger()
      AppIntentBridge.shared.configure(with: messenger)
      AppleResourceUsageBridge.configure(binaryMessenger: messenger)
      AppleSafeAreaBridge.configure(binaryMessenger: messenger)
    }
  }

}

private enum AppleResourceUsageBridge {
  private static var channel: FlutterMethodChannel?

  static func configure(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.xycz.simple-live/resource_usage",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "sample" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(sample())
    }
    self.channel = channel
  }

  private static func sample() -> [String: Any] {
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    let cpuTimeMicroseconds =
      Int64(usage.ru_utime.tv_sec) * 1_000_000
      + Int64(usage.ru_utime.tv_usec)
      + Int64(usage.ru_stime.tv_sec) * 1_000_000
      + Int64(usage.ru_stime.tv_usec)
    let network = networkBytes()
    return [
      "cpuTimeMicroseconds": cpuTimeMicroseconds,
      "networkReceiveBytes": network.receive,
      "networkTransmitBytes": network.transmit,
    ]
  }

  private static func networkBytes() -> (receive: Int64, transmit: Int64) {
    var head: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&head) == 0, let first = head else {
      return (0, 0)
    }
    defer { freeifaddrs(head) }

    var receive: UInt64 = 0
    var transmit: UInt64 = 0
    var cursor: UnsafeMutablePointer<ifaddrs>? = first
    while let current = cursor {
      let interface = current.pointee
      let flags = Int32(interface.ifa_flags)
      let name = String(cString: interface.ifa_name)
      if let address = interface.ifa_addr,
        Int32(address.pointee.sa_family) == AF_LINK,
        (flags & IFF_UP) != 0,
        (flags & IFF_LOOPBACK) == 0,
        name.hasPrefix("en") || name.hasPrefix("pdp_ip"),
        let rawData = interface.ifa_data
      {
        let data = rawData.assumingMemoryBound(to: if_data.self).pointee
        receive += UInt64(data.ifi_ibytes)
        transmit += UInt64(data.ifi_obytes)
      }
      cursor = interface.ifa_next
    }
    return (Int64(clamping: receive), Int64(clamping: transmit))
  }
}

private enum AppleSafeAreaBridge {
  private static var channel: FlutterMethodChannel?

  static func configure(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.xycz.simple-live/safe_area",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "insets" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let insets = currentWindow()?.safeAreaInsets ?? .zero
      result([
        "left": insets.left,
        "top": insets.top,
        "right": insets.right,
        "bottom": insets.bottom,
      ])
    }
    self.channel = channel
  }

  private static func currentWindow() -> UIWindow? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
    return windows.first(where: \.isKeyWindow) ?? windows.first
  }
}
