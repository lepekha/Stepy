//
//  StepsApp.swift
//  Steps
//
//  Created by Ruslan Lepekha on 05.06.2026.
//

import SwiftUI

@main
struct StepsApp: App {
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
