//
//  AdminDriversView.swift
//  Buzzer
//
//  Admin view to add and view drivers.
//

import SwiftUI
import FirebaseFirestore

struct AdminDriversView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var drivers: [Driver] = []
    @State private var isLoading = true
    @State private var showAddSheet = false
    @State private var errorMessage = ""

    private let db = Firestore.db

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if drivers.isEmpty {
                    ContentUnavailableView("No Drivers", systemImage: "person.2", description: Text("Add a driver to get started."))
                } else {
                    List(drivers) { driver in
                        DriverRow(driver: driver)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Drivers")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet, onDismiss: loadDrivers) {
                AddDriverSheet()
            }
            .task { loadDrivers() }
        }
    }

    private func loadDrivers() {
        isLoading = true
        Task {
            do {
                let snap = try await db.collection("drivers")
                    .whereField("isActive", isEqualTo: true)
                    .getDocuments()
                let loaded = try snap.documents.compactMap { try $0.data(as: Driver.self) }
                await MainActor.run {
                    drivers = loaded.sorted { $0.name < $1.name }
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}

// MARK: - Driver Row

private struct DriverRow: View {
    let driver: Driver

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(driver.name)
                .font(.headline)
            HStack(spacing: 16) {
                Label(driver.phone, systemImage: "phone")
                Label(driver.busRegistration, systemImage: "bus")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Label(driver.driversLicense, systemImage: "creditcard")
                Label(driver.licenseExpiry.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar.badge.clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Driver Sheet

struct AddDriverSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var phone = ""
    @State private var age = ""
    @State private var gender = "Male"
    @State private var address = ""
    @State private var childrenCheck = ""
    @State private var driversLicense = ""
    @State private var licenseExpiry = Date()
    @State private var busRegistration = ""

    @State private var isSaving = false
    @State private var errorMessage = ""

    private let db = Firestore.db
    private let genders = ["Male", "Female", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Personal") {
                    TextField("Full Name", text: $name)
                    TextField("Phone (e.g. 0412 345 678)", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Age", text: $age)
                        .keyboardType(.numberPad)
                    Picker("Gender", selection: $gender) {
                        ForEach(genders, id: \.self) { Text($0) }
                    }
                    TextField("Address", text: $address)
                }

                Section("Licence & Compliance") {
                    TextField("Drivers Licence Number", text: $driversLicense)
                    DatePicker("Licence Expiry", selection: $licenseExpiry, displayedComponents: .date)
                    TextField("Working with Children Check", text: $childrenCheck)
                }

                Section("Vehicle") {
                    TextField("Bus Registration", text: $busRegistration)
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("Add Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(isSaving || name.isEmpty || phone.isEmpty)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = ""
        Task {
            do {
                let ref = db.collection("drivers").document()
                try await ref.setData([
                    "name": name.trimmingCharacters(in: .whitespaces),
                    "phone": phone.trimmingCharacters(in: .whitespaces),
                    "age": Int(age) ?? 0,
                    "gender": gender,
                    "address": address.trimmingCharacters(in: .whitespaces),
                    "childrenCheck": childrenCheck.trimmingCharacters(in: .whitespaces),
                    "driversLicense": driversLicense.trimmingCharacters(in: .whitespaces),
                    "licenseExpiry": Timestamp(date: licenseExpiry),
                    "busRegistration": busRegistration.trimmingCharacters(in: .whitespaces),
                    "isActive": true,
                    "createdAt": Timestamp(date: Date()),
                ])
                await MainActor.run { isSaving = false; dismiss() }
            } catch {
                await MainActor.run { isSaving = false; errorMessage = error.localizedDescription }
            }
        }
    }
}
