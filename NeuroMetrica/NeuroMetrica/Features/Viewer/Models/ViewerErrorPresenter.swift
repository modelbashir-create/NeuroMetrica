import Foundation

enum ViewerErrorContext {
    case openVolume
    case openStudy
    case openSeries
    case renderSlice
}

struct ViewerErrorPresentation: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let context: ViewerErrorContext
}

enum ViewerErrorPresenter {
    static func presentation(for error: Error, context: ViewerErrorContext) -> ViewerErrorPresentation {
        if let bridgeError = error as? ChromaEngineBridgeError {
            return presentation(for: bridgeError, context: context)
        }

        let normalized = error.localizedDescription.lowercased()
        if normalized.contains("too large") || normalized.contains("out of memory") || normalized.contains("memory") {
            return ViewerErrorPresentation(
                title: title(for: context),
                message: "The selected file is larger than this device can safely handle.",
                context: context
            )
        }

        if context == .renderSlice {
            return ViewerErrorPresentation(
                title: "Unable to display slice",
                message: "A processing error occurred in the imaging engine.",
                context: context
            )
        }

        return ViewerErrorPresentation(
            title: title(for: context),
            message: unexpectedMessage(for: context),
            context: context
        )
    }

    private static func presentation(
        for error: ChromaEngineBridgeError,
        context: ViewerErrorContext
    ) -> ViewerErrorPresentation {
        switch error {
        case .unsupportedFormat:
            return ViewerErrorPresentation(
                title: title(for: context),
                message: "File is not a valid DICOM/NIfTI/NRRD volume.",
                context: context
            )
        case .volumeNotFound:
            return ViewerErrorPresentation(
                title: title(for: context),
                message: "The selected file is no longer available.",
                context: context
            )
        case .underlyingEngineError(let message):
            let normalized = message.lowercased()
            if normalized.contains("no readable") || normalized.contains("no images") {
                return ViewerErrorPresentation(
                    title: title(for: context),
                    message: "No readable images were found in this folder.",
                    context: context
                )
            }
            if normalized.contains("corrupt") || normalized.contains("incomplete") {
                return ViewerErrorPresentation(
                    title: title(for: context),
                    message: "DICOM data appears incomplete or corrupted.",
                    context: context
                )
            }
            if normalized.contains("too large") || normalized.contains("out of memory") || normalized.contains("memory") {
                return ViewerErrorPresentation(
                    title: title(for: context),
                    message: "The selected file is larger than this device can safely handle.",
                    context: context
                )
            }
            if context == .renderSlice {
                return ViewerErrorPresentation(
                    title: "Unable to display slice",
                    message: "A processing error occurred in the imaging engine.",
                    context: context
                )
            }
            return ViewerErrorPresentation(
                title: title(for: context),
                message: unexpectedMessage(for: context),
                context: context
            )
        case .notImplemented:
            return ViewerErrorPresentation(
                title: title(for: context),
                message: "Requested imaging feature is not available yet.",
                context: context
            )
        }
    }

    private static func title(for context: ViewerErrorContext) -> String {
        switch context {
        case .openSeries:
            return "Unable to open series"
        case .renderSlice:
            return "Unable to display slice"
        case .openVolume, .openStudy:
            return "Unable to open study"
        }
    }

    private static func unexpectedMessage(for context: ViewerErrorContext) -> String {
        switch context {
        case .openSeries:
            return "Unable to open series due to an unexpected error."
        case .renderSlice:
            return "A processing error occurred in the imaging engine."
        case .openVolume, .openStudy:
            return "Unable to open study due to an unexpected error."
        }
    }
}
