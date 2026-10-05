import SwiftUI

struct IncompleteSessionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let session: AttendanceSession
    let list: AttendeeList
    let onContinue: () -> Void
    let onStartNew: () -> Void

    private var marked: Int { session.records.count }
    private var total: Int { list.attendees.count }
    private var unmarked: Int { max(0, total - marked) }
    private var present: Int { session.records.filter { $0.status == .present }.count }
    private var absent: Int { session.records.filter { $0.status == .absent }.count }
    private var sessionLabel: String { session.sessionType == .pickup ? "AM Pickup" : "PM Dropoff" }
    private var accentColor: Color { session.sessionType == .pickup ? .green : .orange }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // Header banner
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    VStack(spacing: 2) {
                        Text(session.sessionType == .pickup ? "On Bus" : "Off Bus")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(accentColor)
                        Text("Incomplete Session Found")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                    }

                    Text("A \(sessionLabel) session from earlier today was not finished.")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 32)
                .padding(.bottom, 24)

                // Progress card
                VStack(spacing: 16) {
                    HStack {
                        Text("Session started")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(session.createdDate, style: .time)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }

                    Divider()

                    // Progress bar
                    VStack(spacing: 8) {
                        HStack {
                            Text("Progress")
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(marked) of \(total)")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                        }
                        ProgressView(value: Double(marked), total: Double(max(total, 1)))
                            .tint(accentColor)
                    }

                    Divider()

                    // Marked breakdown
                    HStack(spacing: 0) {
                        statCell(value: present, label: session.sessionType == .pickup ? "On Bus" : "Off Bus", color: .green, icon: "checkmark.circle.fill")
                        Divider().frame(height: 44)
                        statCell(value: absent, label: "Absent", color: .red, icon: "xmark.circle.fill")
                        Divider().frame(height: 44)
                        statCell(value: unmarked, label: "Unmarked", color: .orange, icon: "questionmark.circle.fill")
                    }
                }
                .padding(20)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal, 20)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        dismiss()
                        onContinue()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.system(size: 26))
                            Text("Continue Session")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }

                    Button {
                        dismiss()
                        onStartNew()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 26))
                            Text("Start New Session")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(uiColor: .separator), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
            .navigationTitle("Incomplete Session")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func statCell(value: Int, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 24))
            Text("\(value)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
