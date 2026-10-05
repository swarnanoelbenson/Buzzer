//
//  DriverDetails.swift
//  Buzzer
//
//  Created by Noel Benson on 11/3/2026.
//

import Foundation

struct DriverDetails: Codable, Equatable, Sendable {
    var name: String
    var busRego: String
    var phoneNo: String
    var email: String
    
    init(name: String, busRego: String, phoneNo: String, email: String) {
        self.name = name
        self.busRego = busRego
        self.phoneNo = phoneNo
        self.email = email
    }
}
