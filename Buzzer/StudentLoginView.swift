//
//  StudentLoginView.swift
//  Buzzer
//
//  Student login — delegates to EmailSignInView.
//

import SwiftUI

struct StudentLoginView: View {
    var body: some View {
        EmailSignInView(
            role: .student,
            accentColor: .indigo,
            icon: "graduationcap.fill",
            title: "Student Login"
        )
    }
}
