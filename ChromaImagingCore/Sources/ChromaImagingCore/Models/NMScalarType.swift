/// Scalar types supported by the imaging core.
///
/// We can expand this later as needed (e.g. 8-bit, 32-bit int, etc.).
public enum NMScalarType: Sendable {
    case int16
    case uint16
    case float32
    case float64

    /// Number of bytes per scalar component.
    public var bytesPerComponent: Int {
        switch self {
        case .int16, .uint16:
            return 2
        case .float32:
            return 4
        case .float64:
            return 8
        }
    }
}
