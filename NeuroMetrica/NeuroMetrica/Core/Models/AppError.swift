import Foundation

/// App-level error wrapper for user-facing messaging and logging.
enum AppError: Error, LocalizedError {
    case message(String)
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .message(let message):
            return message
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}
