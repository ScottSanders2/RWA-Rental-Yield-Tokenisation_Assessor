import UIKit
import ExpoModulesCore

@main
class AppDelegate: ExpoAppDelegate, RCTBridgeDelegate {
  public override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    // Call super first to initialize Expo modules
    _ = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    // Manually initialize React Native bridge
    guard let bridge = RCTBridge(delegate: self, launchOptions: launchOptions) else {
      return false
    }
    let rootView = RCTRootView(bridge: bridge, moduleName: "main", initialProperties: nil)
    
    // Set up root view controller
    let rootViewController = UIViewController()
    rootViewController.view = rootView
    
    // Create and configure window
    self.window = UIWindow(frame: UIScreen.main.bounds)
    self.window?.rootViewController = rootViewController
    self.window?.makeKeyAndVisible()
    
    return true
  }
  
  // RCTBridgeDelegate method: Specify the JavaScript bundle source URL
  public func sourceURL(for bridge: RCTBridge) -> URL? {
    #if DEBUG
      return RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index")
    #else
      return Bundle.main.url(forResource: "main", withExtension: "jsbundle")
    #endif
  }

  // Universal Links
  public override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    let result = RCTLinkingManager.application(application, continue: userActivity, restorationHandler: restorationHandler)
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler) || result
  }
}
