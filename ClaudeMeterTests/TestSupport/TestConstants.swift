//
//  TestConstants.swift
//  ClaudeMeterTests
//

import Foundation

enum TestConstants {
    static let sessionPercentage: Double = 42
    static let cachedPercentage: Double = 75
    /// Icon render inputs, expressed as quota remaining.
    static let menuBarSnapshotRemaining: Double = 28
    static let menuBarSnapshotSecondaryRemaining: Double = 66
    static let iconRemaining: Double = 58
    static let secondaryRemaining: Double = 90
    static let weeklyPercentage: Double = 10
    static let oneHourInterval: TimeInterval = 3600
    static let previousErrorMessage = "Previous error"
    static let fetchFailureMessage = "Fetch failed"
    static let unexpectedErrorMessage = "Unexpected"
    static let managementKey = "test-management-key"
    static let managementAddress = "http://127.0.0.1:8317"
}
