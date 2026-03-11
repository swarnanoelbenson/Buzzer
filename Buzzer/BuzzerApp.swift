//
//  BuzzerApp.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import SwiftUI

@main
struct BuzzerApp: App {
    @StateObject private var dataManager = DataManager(persistenceController: .shared)
    @StateObject private var driverManager = DriverManager.shared
    
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashScreenView {
                        showSplash = false
                    }
                } else {
                    if driverManager.isSetupComplete {
                        // Main app
                        ListsView()
                            .environmentObject(dataManager)
                            .environmentObject(driverManager)
                    } else {
                        // Driver setup screen (first-time use)
                        DriverSetupView()
                            .environmentObject(driverManager)
                    }
                }
            }
        }
    }
}
