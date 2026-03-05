//
//  FinalCheckView.swift
//  Buzzer
//
//  Created by Noel Benson on 5/3/2026.
//

import SwiftUI

struct FinalCheckView: View {
    @Environment(\.dismiss) var dismiss
    
    let onConfirm: (Date) -> Void
    
    @State private var currentTime = Date()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Spacer()
                
                // Checkmark Icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.green)
                    .padding(.bottom, 32)
                
                // Message
                Text("NO CHILDREN LEFT ON BUS")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
                
                // Time Display
                VStack(spacing: 8) {
                    Text("Final Check Time")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(currentTime, style: .time)
                        .font(.system(size: 48, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(20)
                
                Spacer()
                
                // Confirm Button
                Button {
                    let finalTimestamp = Date()
                    onConfirm(finalTimestamp)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                        
                        Text("Confirm")
                            .font(.system(size: 20, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .foregroundColor(.white)
                    .background(Color.green)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .navigationTitle("Final Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Back")
                    }
                }
            }
            .onAppear {
                // Update time every second
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    currentTime = Date()
                }
            }
        }
    }
}

#Preview {
    FinalCheckView { timestamp in
        print("Final check confirmed at: \(timestamp)")
    }
}
