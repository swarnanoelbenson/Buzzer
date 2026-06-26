//
//  FinalCheckView.swift
//  Buzzer
//
//  Created by Noel Benson on 5/3/2026.
//

import SwiftUI

struct FinalCheckView: View {
    @Environment(\.dismiss) var dismiss

    let unmarkedAttendees: [Attendee]
    let sessionType: SessionType
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
                    .padding(.bottom, unmarkedAttendees.isEmpty ? 48 : 24)

                // Missed students list (only shown if there are unmarked attendees)
                if !unmarkedAttendees.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Unrecorded Students")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 6)

                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(unmarkedAttendees) { attendee in
                                    missedStudentRow(for: attendee)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                        }
                        .frame(maxHeight: 200)
                    }
                    .padding(.bottom, 24)
                }

                // Time Display
                VStack(spacing: 8) {
                    Text("Final Check Time")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
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
                            .font(.system(size: 20, weight: .bold, design: .rounded))

                        Text("Confirm")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
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
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    currentTime = Date()
                }
            }
        }
    }

    // MARK: - Missed Student Row

    private func missedStudentRow(for attendee: Attendee) -> some View {
        let accentColor: Color = sessionType == .pickup ? .green : .orange
        let scheduleTime: Date? = sessionType == .pickup ? attendee.pickupTime : attendee.dropoffTime
        let scheduleLabel = sessionType == .pickup ? "AM Pickup" : "PM Dropoff"

        return HStack {
            Text(attendee.name)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            Spacer()

            if let time = scheduleTime {
                HStack(spacing: 4) {
                    Image(systemName: sessionType == .pickup ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundColor(accentColor)
                    Text("\(scheduleLabel): \(time, style: .time)")
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .font(.system(size: 15, weight: .medium, design: .rounded))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    FinalCheckView(
        unmarkedAttendees: [
            Attendee(name: "John Doe", orderIndex: 0),
            Attendee(name: "Jane Smith", orderIndex: 1)
        ],
        sessionType: .pickup
    ) { timestamp in
        print("Final check confirmed at: \(timestamp)")
    }
}
