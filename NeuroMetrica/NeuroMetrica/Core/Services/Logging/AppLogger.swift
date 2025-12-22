import Foundation
import os

enum AppLogger {
    private static let subsystem = "com.neurometrica.app"
    private static let appLogger = Logger(subsystem: subsystem, category: "app")

    static func info(_ message: String) {
        appLogger.info("\(message, privacy: .public)")
    }

    static func error(_ message: String, error: Error? = nil) {
        if let error {
            appLogger.error("\(message, privacy: .public) \(error.localizedDescription, privacy: .public)")
        } else {
            appLogger.error("\(message, privacy: .public)")
        }
    }
}
