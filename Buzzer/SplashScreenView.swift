//
//  SplashScreenView.swift
//  Buzzer
//
//  Created by Noel Benson on 5/3/2026.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isAnimating = false
    @State private var showContent = false
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.6, blue: 1.0),
                    Color(red: 0.1, green: 0.4, blue: 0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Logo with animation
                BuzzerLogo(size: 140)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6), value: isAnimating)
                
                // App name
                if showContent {
                    VStack(spacing: 8) {
                        Text("BusMate")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Bus Attendance Tracking")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            // Start animation immediately
            withAnimation {
                isAnimating = true
            }
            
            // Show text after logo animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation {
                    showContent = true
                }
            }
            
            // Complete splash screen after 2.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    onComplete()
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Buzzer app is loading")
    }
}

#Preview {
    SplashScreenView {
        print("Splash complete")
    }
}
