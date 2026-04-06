//
//  AddAttendeeView.swift
//  Buzzer
//

import SwiftUI

struct AddAttendeeView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss

    let list: AttendeeList

    // MARK: - Student info
    @State private var attendeeName = ""
    @State private var grade = ""
    @State private var address = ""

    // MARK: - Guardian info
    @State private var motherName = ""
    @State private var fatherName = ""

    // MARK: - Phone fields
    @State private var primaryPhone = ""                    // Mother's phone (required)
    @State private var primaryPhoneTag: PhoneTag = .mother
    @State private var secondaryPhone = ""                  // Father's phone (optional)
    @State private var secondaryPhoneTag: PhoneTag = .father
    @State private var studentPhone = ""                    // Student's phone (optional)
    @State private var studentPhoneTag: PhoneTag = .student

    // MARK: - Phone validation errors
    @State private var primaryPhoneError: String?
    @State private var secondaryPhoneError: String?
    @State private var studentPhoneError: String?

    // MARK: - Schedule times
    @State private var pickupTime: Date = Date()
    @State private var dropoffTime: Date = Date()

    @FocusState private var focusedField: Field?

    private enum Field {
        case name, grade, address, motherName, fatherName, primaryPhone, secondaryPhone, studentPhone
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
                    TextField("e.g. Oak Street, Springfield", text: $address)
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
            .navigationTitle("Add Student")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") { addAttendee() }
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
        let addressOK = !address.trimmingCharacters(in: .whitespaces).isEmpty
        let motherNameOK = !motherName.trimmingCharacters(in: .whitespaces).isEmpty
        let fatherNameOK = !fatherName.trimmingCharacters(in: .whitespaces).isEmpty
        let primaryOK = validatePhone(primaryPhone, required: true) == nil
        let secondaryOK = validatePhone(secondaryPhone, required: false) == nil
        let studentOK = validatePhone(studentPhone, required: false) == nil
        return nameOK && gradeOK && addressOK && motherNameOK && fatherNameOK && primaryOK && secondaryOK && studentOK
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

    private func addAttendee() {
        let trimmedName = attendeeName.trimmingCharacters(in: .whitespaces)
        let trimmedGrade = grade.trimmingCharacters(in: .whitespaces)
        let trimmedAddress = address.trimmingCharacters(in: .whitespaces)
        let trimmedMotherName = motherName.trimmingCharacters(in: .whitespaces)
        let trimmedFatherName = fatherName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !trimmedGrade.isEmpty, !trimmedAddress.isEmpty,
              !trimmedMotherName.isEmpty, !trimmedFatherName.isEmpty else { return }

        dataManager.addAttendee(
            to: list,
            name: trimmedName,
            grade: trimmedGrade,
            address: trimmedAddress,
            primaryPhone: primaryPhone,
            primaryPhoneTag: primaryPhoneTag,
            secondaryPhone: secondaryPhone,
            secondaryPhoneTag: secondaryPhoneTag,
            studentPhone: studentPhone,
            studentPhoneTag: studentPhoneTag,
            motherName: trimmedMotherName,
            fatherName: trimmedFatherName,
            pickupTime: pickupTime,
            dropoffTime: dropoffTime
        )
        dismiss()
    }
}

#Preview {
    AddAttendeeView(list: AttendeeList(name: "Sample List"))
        .environmentObject(DataManager(persistenceController: PersistenceController()))
}
