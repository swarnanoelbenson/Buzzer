//
//  EditAttendeeView.swift
//  Buzzer
//

import SwiftUI

struct EditAttendeeView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss

    let list: AttendeeList
    let attendee: Attendee

    @State private var attendeeName: String
    @State private var grade: String
    @State private var address: String
    @State private var primaryPhone: String
    @State private var primaryPhoneTag: PhoneTag
    @State private var secondaryPhone: String
    @State private var secondaryPhoneTag: PhoneTag

    @State private var primaryPhoneError: String?
    @State private var secondaryPhoneError: String?

    @FocusState private var focusedField: Field?

    private enum Field {
        case name, grade, address, primaryPhone, secondaryPhone
    }

    init(list: AttendeeList, attendee: Attendee) {
        self.list = list
        self.attendee = attendee
        _attendeeName = State(initialValue: attendee.name)
        _grade = State(initialValue: attendee.grade)
        _address = State(initialValue: attendee.address)
        _primaryPhone = State(initialValue: attendee.primaryPhone)
        _primaryPhoneTag = State(initialValue: attendee.primaryPhoneTag)
        _secondaryPhone = State(initialValue: attendee.secondaryPhone)
        _secondaryPhoneTag = State(initialValue: attendee.secondaryPhoneTag)
        
    }

    var body: some View {
        NavigationView {
            Form {
                // MARK: Name
                Section {
                    TextField("Full name", text: $attendeeName)
                        .focused($focusedField, equals: .name)
                } header: {
                    Text("Student Name")
                }

                // MARK: Grade
                Section {
                    TextField("e.g. Year 5", text: $grade)
                        .focused($focusedField, equals: .grade)
                } header: {
                    Text("Grade")
                }

                // MARK: Address
                Section {
                    TextField("e.g. 12 Oak Street, Springfield", text: $address)
                        .focused($focusedField, equals: .address)
                } header: {
                    Text("Stop Address")
                }

                // MARK: Primary Phone
                Section {
                    HStack(spacing: 12) {
                        Picker("", selection: $primaryPhoneTag) {
                            ForEach(PhoneTag.allCases, id: \.self) { tag in
                                Text(tag.rawValue).tag(tag)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 90)

                        TextField("04XX XXX XXX", text: $primaryPhone)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .primaryPhone)
                            .onChange(of: primaryPhone) { newValue in
                                primaryPhone = sanitisePhone(newValue)
                                primaryPhoneError = validatePhone(primaryPhone, required: true)
                            }
                    }

                    if let error = primaryPhoneError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Primary Contact Phone")
                } footer: {
                    Text("10 digits — mobile (04xx/05xx) or landline (02/03/07/08)")
                }

                // MARK: Secondary Phone
                Section {
                    HStack(spacing: 12) {
                        Picker("", selection: $secondaryPhoneTag) {
                            ForEach(PhoneTag.allCases, id: \.self) { tag in
                                Text(tag.rawValue).tag(tag)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 90)

                        TextField("04XX XXX XXX", text: $secondaryPhone)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .secondaryPhone)
                            .onChange(of: secondaryPhone) { newValue in
                                secondaryPhone = sanitisePhone(newValue)
                                secondaryPhoneError = validatePhone(secondaryPhone, required: false)
                            }
                    }

                    if let error = secondaryPhoneError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Secondary Contact Phone")
                } footer: {
                    Text("Optional — 10 digits, mobile (04xx/05xx) or landline (02/03/07/08)")
                }
            }
            .navigationTitle("Edit Student")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveAttendee() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                focusedField = .name
            }
        }
    }

    // MARK: - Validation

    private var canSave: Bool {
        let nameOK = !attendeeName.trimmingCharacters(in: .whitespaces).isEmpty
        let gradeOK = !grade.trimmingCharacters(in: .whitespaces).isEmpty
        let primaryOK = validatePhone(primaryPhone, required: true) == nil
        let secondaryOK = validatePhone(secondaryPhone, required: false) == nil
        return nameOK && gradeOK && primaryOK && secondaryOK
    }

    /// Returns an error string if invalid, nil if valid.
    private func validatePhone(_ value: String, required: Bool) -> String? {
        if value.isEmpty {
            return required ? "Phone number is required" : nil
        }
        if value.count != 10 {
            return "Must be exactly 10 digits"
        }
        let validPrefixes = ["04", "05", "02", "03", "07", "08"]
        if !validPrefixes.contains(where: { value.hasPrefix($0) }) {
            return "Must start with 04, 05, 02, 03, 07, or 08"
        }
        return nil
    }

    /// Strips non-digits and caps at 10 characters.
    private func sanitisePhone(_ value: String) -> String {
        let digits = value.filter { $0.isNumber }
        return String(digits.prefix(10))
    }

    // MARK: - Save

    private func saveAttendee() {
        let trimmedName = attendeeName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        var updated = attendee
        updated.name = trimmedName
        updated.grade = grade.trimmingCharacters(in: .whitespaces)
        updated.address = address.trimmingCharacters(in: .whitespaces)
        updated.primaryPhone = primaryPhone
        updated.primaryPhoneTag = primaryPhoneTag
        updated.secondaryPhone = secondaryPhone
        updated.secondaryPhoneTag = secondaryPhoneTag

        dataManager.updateAttendee(updated, in: list)
        dismiss()
    }
}

#Preview {
    EditAttendeeView(
        list: AttendeeList(name: "Sample List"),
        attendee: Attendee(name: "John Doe")
    )
    .environmentObject(DataManager(persistenceController: PersistenceController()))
}
