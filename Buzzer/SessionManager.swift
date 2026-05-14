//
//  SessionManager.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import Foundation
import Combine

class SessionManager: ObservableObject {
    @Published var currentSession: AttendanceSession?
    @Published var currentAttendeeIndex: Int = 0
    @Published var recordedStatuses: [UUID: AttendanceRecord] = [:]
    @Published var isSessionActive: Bool = false
    @Published var finalCheckTimestamp: Date?

    /// True when the current session was resumed from a previously saved incomplete session.
    /// stopSession() will update the existing Core Data record instead of inserting a new one.
    private var isResumed: Bool = false

    private let dataManager: DataManager
    
    init(dataManager: DataManager) {
        self.dataManager = dataManager
    }
    
    // MARK: - Session Control
    
    func startSession(for list: AttendeeList, type: SessionType) {
        let now = Date()
        let session = AttendanceSession(
            listId: list.id,
            sessionType: type,
            createdDate: now,
            records: [],
            sessionStartTimestamp: now
        )
        
        currentSession = session
        currentAttendeeIndex = 0
        recordedStatuses.removeAll()
        finalCheckTimestamp = nil
        isSessionActive = true
        isResumed = false
    }
    
    func stopSession() {
        guard let session = currentSession else { return }

        if isResumed {
            // Update the existing Core Data session record instead of inserting a new one
            dataManager.updateSession(session, records: Array(recordedStatuses.values), finalCheckTimestamp: finalCheckTimestamp)
        } else {
            dataManager.saveSession(session, records: Array(recordedStatuses.values), finalCheckTimestamp: finalCheckTimestamp)
        }

        // Clear state
        currentSession = nil
        currentAttendeeIndex = 0
        recordedStatuses.removeAll()
        finalCheckTimestamp = nil
        isSessionActive = false
        isResumed = false
    }
    
    /// Restores an existing saved session into active state, jumping to the first unmarked attendee.
    func resumeSession(_ session: AttendanceSession, records: [AttendanceRecord], orderedAttendees: [Attendee]) {
        currentSession = session
        recordedStatuses = Dictionary(uniqueKeysWithValues: records.map { ($0.attendeeId, $0) })
        finalCheckTimestamp = nil
        isSessionActive = true
        isResumed = true

        // Jump to first unmarked attendee
        if let index = orderedAttendees.firstIndex(where: { recordedStatuses[$0.id] == nil }) {
            currentAttendeeIndex = index
        } else {
            currentAttendeeIndex = orderedAttendees.count
        }
    }

    /// Persists the current in-progress session to Core Data without ending it in memory.
    /// Called when the app backgrounds so the session survives an app kill.
    func saveIncompleteSnapshot() {
        guard let session = currentSession else { return }
        if isResumed {
            dataManager.updateSession(session, records: Array(recordedStatuses.values), finalCheckTimestamp: nil)
        } else {
            // Only save a snapshot if not already persisted
            dataManager.saveSessionIfNotExists(session, records: Array(recordedStatuses.values))
        }
    }

    func cancelSession() {
        currentSession = nil
        currentAttendeeIndex = 0
        recordedStatuses.removeAll()
        finalCheckTimestamp = nil
        isSessionActive = false
        isResumed = false
    }
    
    // MARK: - Attendance Recording
    
    func recordAttendance(for attendee: Attendee, status: AttendanceStatus, timestamp: Date? = nil) {
        guard currentSession != nil else { return }

        // Use the provided timestamp if given, otherwise use now for present or nil for absent
        let resolvedTimestamp: Date?
        if status == .present {
            resolvedTimestamp = timestamp ?? Date()
        } else {
            resolvedTimestamp = nil
        }

        let record = AttendanceRecord(
            attendeeId: attendee.id,
            status: status,
            timestamp: resolvedTimestamp
        )
        
        recordedStatuses[attendee.id] = record
    }
    
    func undoLastRecord(for attendee: Attendee) {
        recordedStatuses.removeValue(forKey: attendee.id)
    }
    
    func setFinalCheckTimestamp(_ timestamp: Date) {
        finalCheckTimestamp = timestamp
    }
    
    // MARK: - Navigation
    
    func advanceToNext() {
        currentAttendeeIndex += 1
    }
    
    func goToPrevious() {
        if currentAttendeeIndex > 0 {
            currentAttendeeIndex -= 1
        }
    }
    
    // MARK: - Helpers
    
    func getRecord(for attendee: Attendee) -> AttendanceRecord? {
        return recordedStatuses[attendee.id]
    }
    
    func isCompleted(for list: AttendeeList) -> Bool {
        return currentAttendeeIndex >= list.attendees.count
    }
    
    func getProgress(for list: AttendeeList) -> (current: Int, total: Int) {
        return (min(currentAttendeeIndex + 1, list.attendees.count), list.attendees.count)
    }
    
    func getSummary() -> (present: Int, absent: Int) {
        let present = recordedStatuses.values.filter { $0.status == .present }.count
        let absent = recordedStatuses.values.filter { $0.status == .absent }.count
        return (present, absent)
    }
    
    func unmarkedCount(for list: AttendeeList) -> Int {
        let orderedAttendees = list.attendees
        return orderedAttendees.filter { recordedStatuses[$0.id] == nil }.count
    }
    
    /// Navigates to the first attendee in `orderedAttendees` that has no attendance record yet.
    func navigateToNextUnmarked(in orderedAttendees: [Attendee]) {
        if let index = orderedAttendees.firstIndex(where: { recordedStatuses[$0.id] == nil }) {
            currentAttendeeIndex = index
        }
    }
}
