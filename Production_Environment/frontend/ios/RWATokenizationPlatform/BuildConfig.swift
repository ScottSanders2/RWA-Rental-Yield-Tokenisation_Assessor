import Foundation
import React

@objc(BuildConfig)
class BuildConfig: NSObject, RCTBridgeModule {
  
  @objc
  static func moduleName() -> String! {
    return "BuildConfig"
  }
  
  @objc
  static func requiresMainQueueSetup() -> Bool {
    return true
  }
  
  @objc
  func constantsToExport() -> [AnyHashable : Any]! {
    // Check if we're running in E2E test mode
    // Swift compilation conditions are boolean - just use #if directly
    #if E2E_TEST_MODE
      return ["IS_E2E_TEST": true]
    #else
      return ["IS_E2E_TEST": false]
    #endif
  }
}

