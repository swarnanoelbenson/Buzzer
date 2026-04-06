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

    // MARK: - Student info
    @State private var attendeeName: String
    @State private var grade: String
    @State private var address: String

    // MARK: - Guardian info
    @State private var motherName: String
    @State private var fatherName: String

    // MARK: - Phone fields
    @State private var primaryPhone: String       // Mother's phone (required)
    @State private var primaryPhoneTag: PhoneTag
    @State private var secondaryPhone: String     // Father's phone (optional)
    @State private var secondaryPhoneTag: PhoneTag
    @State private var studentPhone: String       // Student's phone (optional)
    @State private var studentPhoneTag: PhoneTag

    // MARK: - Phone validation errors
    @State private var primaryPhoneError: String?
    @State private var secondaryPhoneError: String?
    @State private var studentPhoneError: String?

    // MARK: - Schedule times
    @State private var pickupTime: Date
    @State private var dropoffTime: Date

    @FocusState private var focusedField: Field?

    private enum Field {
        case name, grade, address, motherName, fatherName, primaryPhone, secondaryPhone, studentPhone
    }

    init(list: AttendeeList, attendee: Attendee) {
        self.list = list
        self.attendee = attendee
        _attendeeName = State(initialValue: attendee.name)
        _grade = State(initialValue: attendee.grade)
        _address = State(initialValue: attendee.address)
        _motherName = State(initialValue: attendee.motherName)
        _fatherName = State(initialValue: attendee.fatherName)
        _primaryPhone = State(initialValue: attendee.primaryPhone)
        _primaryPhoneTag = State(initialValue: attendee.primaryPhoneTag)
        _secondaryPhone = State(initialValue: attendee.secondaryPhone)
        _secondaryPhoneTag = State(initialValue: attendee.secondaryPhoneTag)
        _studentPhone = State(initialValue: attendee.studentPhone)
        _studentPhoneTag = State(initialValue: attendee.studentPhoneTag)
        _pickupTime = State(initialValue: attendee.pickupTime ?? Date())
        _dropoffTime = State(initialValue: attendee.dropoffTime ?? Date())
    }

    var body: some View {
        NavigationView {
            Form {
                // MARK: Student Name
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

                // MARK: Guardian Info
                Section {
                    TextField("Mother's full name", text: $motherName)
                        .focused($focusedField, equals: .motherName)
                    TextField("Father's full name", text: $fatherName)
                        .focused($focusedField, equals: .fatherName)
                } header: {
                    Text("Guardian Information")
                }

                // MARK: Mother's Phone (primary, required)
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
                    Text("Mother's Phone")
                } footer: {
                    Text("Required — 10 digits, mobile (04xx/05xx) or landline (02/03/07/08)")
                }

                // MARK: Father's Phone (secondary, optional)
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
                    Text("Father's Phone")
                } footer: {
                    Text("Optional — 10 digits, mobile (04xx/05xx) or landline (02/03/07/08)")
                }

                // MARK: Student's Phone (optional)
                Section {
                    HStack(spacing: 12) {
                        Picker("", selection: $studentPhoneTag) {
                            ForEach(PhoneTag.allCases, id: \.self) { tag in
                                Text(tag.rawValue).tag(tag)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 90)

                        TextField("04XX XXX XXX", text: $studentPhone)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .studentPhone)
                            .onChange(of: studentPhone) { newValue in
                                studentPhone = sanitisePhone(newValue)
                                studentPhoneError = validatePhone(studentPhone, required: false)
                            }
                    }

                    if let error = studentPhoneError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Student's Phone")
                } footer: {
                    Text("Optional — 10 digits, mobile (04xx/05xx) or landline (02/03/07/08)")
                }

                // MARK: Schedule Times
                Section {
                    DatePicker("Pickup Time", selection: $pickupTime, displayedComponents: .hourAndMinute)
                    DatePicker("Drop-off Time", selection: $dropoffTime, displayedComponents: .hourAndMinute)
                } header: {
                    Text("Schedule")
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
        let motherNameOK = !motherName.trimmingCharacters(in: .whitespaces).isEmpty
        let fatherNameOK = !fatherName.trimmingCharacters(in: .whitespaces).isEmpty
        let primaryOK = validatePhone(primaryPhone, required: true) == nil
        let secondaryOK = validatePhone(secondaryPhone, required: false) == nil
        let studentOK = validatePhone(studentPhone, required: false) == nil
        return nameOK && gradeOK && motherNameOK && fatherNameOK && primaryOK && secondaryOK && studentOK
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
        updated.motherName = motherName.trimmingCharacters(in: .whitespaces)
        updated.fatherName = fatherName.trimmingCharacters(in: .whitespaces)
        updated.primaryPhone = primaryPhone
        updated.primaryPhoneTag = primaryPhoneTag
        updated.secondaryPhone = secondaryPhone
        updated.secondaryPhoneTag = secondaryPhoneTag
        updated.studentPhone = studentPhone
        updated.studentPhoneTag = studentPhoneTag
        updated.pickupTime = pickupTime
        updated.dropoffTime = dropoffTime

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
