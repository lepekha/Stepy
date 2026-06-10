//
//  StepsApp.swift
//  Steps
//
//  Created by Ruslan Lepekha on 05.06.2026.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}


@main
struct StepsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    init() {
        Task {
            let svc = HealthKitService.shared
            _ = await svc.requestAuth()
            await svc.enableBackgroundDelivery()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
