//
//  FirestoreConfig.swift
//  Buzzer
//
//  Central Firestore database reference.
//  Our database is named "busmate-db" (not the default).
//

import FirebaseFirestore

extension Firestore {
    /// Returns the named Firestore database for this project.
    static var db: Firestore {
        Firestore.firestore(database: "busmate-db")
    }
}
