//
//  DriverLoginView.swift
//  Buzzer
//
//  Driver login — delegates to EmailSignInView.
//

import SwiftUI

struct DriverLoginView: View {
    var body: some View {
        EmailSignInView(
            role: .driver,
            accentColor: .blue,
            icon: "steeringwheel",
            title: "Driver Login"
        )
    }
}

// MARK: - Supporting Model (kept for any existing references)

struct DriverListItem: Identifiable, Hashable {
    let id: String
    let name: String
}
