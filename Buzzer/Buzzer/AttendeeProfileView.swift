//
//  AttendeeProfileView.swift
//  Buzzer
//

import SwiftUI

struct AttendeeProfileView: View {
    @Environment(\.dismiss) var dismiss

    let attendee: Attendee

    var body: some View {
        NavigationView {
            List {
                // MARK: - Basic Info
                Section {
                    profileRow(label: "Name", value: attendee.name, icon: "person.fill", color: .accentColor)

                    if !attendee.grade.isEmpty {
                        profileRow(label: "Grade", value: attendee.grade, icon: "graduationcap.fill", color: .purple)
                    }

                    if !attendee.address.isEmpty {
                        profileRow(label: "Address", value: attendee.address, icon: "mappin.circle.fill", color: .red)
                    }
                } header: {
                    Text("Student Info")
                }

                // MARK: - Schedule
                if attendee.pickupTime != nil || attendee.dropoffTime != nil {
                    Section {
                        if let pickupTime = attendee.pickupTime {
                            profileRow(
                                label: "AM Pickup",
                                value: TimestampFormatter.formatTime(pickupTime),
                                icon: "arrow.up.circle.fill",
                                color: .green
                            )
                        }
                        if let dropoffTime = attendee.dropoffTime {
                            profileRow(
                                label: "PM Dropoff",
                                value: TimestampFormatter.formatTime(dropoffTime),
                                icon: "arrow.down.circle.fill",
                                color: .orange
                            )
                        }
                    } header: {
                        Text("Schedule")
                    }
                }

                // MARK: - Contacts
                Section {
                    if !attendee.motherName.isEmpty || !attendee.primaryPhone.isEmpty {
                        if !attendee.motherName.isEmpty {
                            profileRow(label: "Mother's Name", value: attendee.motherName, icon: "person.fill", color: .pink)
                        }
                        if !attendee.primaryPhone.isEmpty {
                            phoneRow(label: "Mother's Phone", number: attendee.primaryPhone, color: .pink)
                        }
                    }

                    if !attendee.fatherName.isEmpty || !attendee.secondaryPhone.isEmpty {
                        if !attendee.fatherName.isEmpty {
                            profileRow(label: "Father's Name", value: attendee.fatherName, icon: "person.fill", color: .blue)
                        }
                        if !attendee.secondaryPhone.isEmpty {
                            phoneRow(label: "Father's Phone", number: attendee.secondaryPhone, color: .blue)
                        }
                    }

                    if !attendee.studentPhone.isEmpty {
                        phoneRow(label: "Student's Phone", number: attendee.studentPhone, color: .teal)
                    }
                } header: {
                    Text("Contacts")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(attendee.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Profile Row

    private func profileRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundColor(color)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Phone Row (with call button)

    private func phoneRow(label: String, number: String, color: Color) -> some View {
        HStack {
            Label(label, systemImage: "phone.fill")
                .foregroundColor(color)
            Spacer()
            Text(number)
                .foregroundColor(.secondary)
            Button {
                if let url = URL(string: "tel://\(number.filter { $0.isNumber })") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Image(systemName: "phone.circle.fill")
                    .foregroundColor(.green)
                    .imageScale(.large)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    AttendeeProfileView(
        attendee: Attendee(
            name: "John Smith",
            orderIndex: 0,
            grade: "Grade 6",
            address: "11 Demo Street, Sydney NSW 2000",
            primaryPhone: "0411000001",
            secondaryPhone: "0422000001",
            studentPhone: "0433000001",
            motherName: "Mary Smith",
            fatherName: "Robert Smith",
            pickupTime: Calendar.current.date(bySettingHour: 7, minute: 45, second: 0, of: Date()),
            dropoffTime: Calendar.current.date(bySettingHour: 15, minute: 30, second: 0, of: Date())
        )
    )
}
