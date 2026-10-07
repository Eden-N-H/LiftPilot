//  ErrorMessage.swift

import Foundation

/// Turns any error into the lifter-facing message its use case defined.
enum ErrorMessage {
    static func forLifter(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Something went wrong. Please try again."
    }
}
