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
    
    var body: some Scene {
        WindowGroup {
            ListsView()
                .environmentObject(dataManager)
        }
    }
}
