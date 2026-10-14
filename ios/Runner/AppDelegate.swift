import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var routeChannel: FlutterMethodChannel?
  private var pendingRoute: Any?
  private var routeClientReady = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      routeChannel = FlutterMethodChannel(name: "com.munichways/route_transfer", binaryMessenger: controller.binaryMessenger)
      routeChannel?.setMethodCallHandler { [weak self] call, result in
        guard call.method == "initialGpx" else { result(FlutterMethodNotImplemented); return }
        self?.routeClientReady = true
        result(self?.pendingRoute)
        self?.pendingRoute = nil
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  override func application(_ app: UIApplication, open url: URL,
      options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    guard url.isFileURL, url.pathExtension.lowercased() == "gpx" else {
      return super.application(app, open: url, options: options)
    }
    let scoped = url.startAccessingSecurityScopedResource()
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      defer { if scoped { url.stopAccessingSecurityScopedResource() } }
      let value: Any
      do {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attrs[.size] as? NSNumber, size.intValue <= 4 * 1024 * 1024 else {
          throw NSError(domain: "GPX", code: 1)
        }
        let data = try Data(contentsOf: url)
        guard data.count <= 4 * 1024 * 1024 else { throw NSError(domain: "GPX", code: 1) }
        value = FlutterStandardTypedData(bytes: data)
      } catch { value = "GPX could not be opened (maximum 4 MB)" }
      DispatchQueue.main.async {
        if self?.routeClientReady == true { self?.routeChannel?.invokeMethod("gpx", arguments: value) }
        else { self?.pendingRoute = value }
      }
    }
    return true
  }
}
