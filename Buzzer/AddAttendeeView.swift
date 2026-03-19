//
//  AddAttendeeView.swift
//  Buzzer
//

import SwiftUI

struct AddAttendeeView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss

    let list: AttendeeList

    @State private var attendeeName = ""
    @State private var address = ""
    @State private var primaryPhone = ""
    @State private var primaryPhoneTag: PhoneTag = .mother
    @State private var secondaryPhone = ""
    @State private var secondaryPhoneTag: PhoneTag = .mother

    @State private var primaryPhoneError: String?
    @State private var secondaryPhoneError: String?

    @FocusState private var focusedField: Field?

    private enum Field {
        case name, address, primaryPhone, secondaryPhone
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

                // MARK: Address (required)
                Section {
                    TextField("e.g. 12 Oak Street, Springfield", text: $address)
                        .focused($focusedField, equals: .address)
                } header: {
                    Text("Home Address")
                }

                // MARK: Primary Phone (required)
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
                    Text("Must start with 04 and be 10 digits")
                }

                // MARK: Secondary Phone (optional)
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
                    Text("Optional — must start with 04 and be 10 digits if entered")
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
        let addressOK = !address.trimmingCharacters(in: .whitespaces).isEmpty
        let primaryOK = validatePhone(primaryPhone, required: true) == nil
        let secondaryOK = validatePhone(secondaryPhone, required: false) == nil
        return nameOK && addressOK && primaryOK && secondaryOK
    }

    /// Returns an error string if invalid, nil if valid.
    private func validatePhone(_ value: String, required: Bool) -> String? {
        if value.isEmpty {
            return required ? "Primary phone number is required" : nil
        }
        if value.count != 10 {
            return "Must be exactly 10 digits"
        }
        if !value.hasPrefix("04") {
            return "Must start with 04"
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
        let trimmedAddress = address.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !trimmedAddress.isEmpty else { return }

        dataManager.addAttendee(
            to: list,
            name: trimmedName,
            address: trimmedAddress,
            primaryPhone: primaryPhone,
            primaryPhoneTag: primaryPhoneTag,
            secondaryPhone: secondaryPhone,
            secondaryPhoneTag: secondaryPhoneTag
        )
        dismiss()
    }
}

#Preview {
    AddAttendeeView(list: AttendeeList(name: "Sample List"))
        .environmentObject(DataManager(persistenceController: PersistenceController()))
}
