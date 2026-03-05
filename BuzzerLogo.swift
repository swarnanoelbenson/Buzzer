//
//  BuzzerLogo.swift
//  Buzzer
//
//  Created by Noel Benson on 5/3/2026.
//

import SwiftUI

/// Buzzer app logo - Letter "B" design
/// Automatically adapts to light/dark mode
struct BuzzerLogo: View {
    let size: CGFloat
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
            
            // Letter "B"
            Text("B")
                .font(.system(size: size * 0.55, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
    
    private var gradientColors: [Color] {
        if colorScheme == .dark {
            // Dark mode: Softer, muted gradient
            return [
                Color(red: 0.3, green: 0.5, blue: 0.9),
                Color(red: 0.2, green: 0.4, blue: 0.7)
            ]
        } else {
            // Light mode: Vibrant gradient
            return [
                Color(red: 0.2, green: 0.6, blue: 1.0),
                Color(red: 0.1, green: 0.4, blue: 0.8)
            ]
        }
    }
}

/// Small icon variant for navigation bars
struct BuzzerIconSmall: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        BuzzerLogo(size: 32)
    }
}

#Preview("Logo Light Mode") {
    VStack(spacing: 40) {
        BuzzerLogo(size: 120)
        BuzzerLogo(size: 80)
        BuzzerLogo(size: 60)
        BuzzerIconSmall()
    }
    .preferredColorScheme(.light)
    .padding()
}

#Preview("Logo Dark Mode") {
    VStack(spacing: 40) {
        BuzzerLogo(size: 120)
        BuzzerLogo(size: 80)
        BuzzerLogo(size: 60)
        BuzzerIconSmall()
    }
    .preferredColorScheme(.dark)
    .padding()
}
