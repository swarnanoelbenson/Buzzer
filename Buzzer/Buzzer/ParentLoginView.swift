//
//  ParentLoginView.swift
//  Buzzer
//
//  Parent login — delegates to EmailSignInView.
//

import SwiftUI

struct ParentLoginView: View {
    var body: some View {
        EmailSignInView(
            role: .parent,
            accentColor: .orange,
            icon: "person.2.fill",
            title: "Parent Login"
        )
    }
}
