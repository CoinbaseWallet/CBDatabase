// Copyright (c) 2017-2019 Coinbase Inc. See LICENSE

import Foundation

/// This protocol is used to compare custom data types. `Equality` cannot be used since it has `Self` requirement.
public protocol DBDataTypeEquality {
    /// Compare current conformer to other conformer
    ///
    /// - Parameter:
    ///     - otherObject: The object to compare against the conformer of this protocol
    ///
    /// - Returns: True if object are equal. Otherwise, false.
    func isEqual(to otherObject: Any) -> Bool
}

// MARK: - Default standard Swift data types conformers

extension Int: DBDataTypeEquality {
    public func isEqual(to otherObject: Any) -> Bool {
        return self == (otherObject as? Int)
    }
}

extension Int8: DBDataTypeEquality {
    public func isEqual(to otherObject: Any) -> Bool {
        return self == (otherObject as? Int8)
    }
}

extension Int16: DBDataTypeEquality {
    public func isEqual(to otherObject: Any) -> Bool {
        return self == (otherObject as? Int16)
    }
}

extension Int32: DBDataTypeEquality {
    public func isEqual(to otherObject: Any) -> Bool {
        return self == (otherObject as? Int32)
    }
}

extension Int64: DBDataTypeEquality {
    public func isEqual(to otherObject: Any) -> Bool {
        return self == (otherObject as? Int64)
    }
}

extension UInt: DBDataTypeEquality {
    public func isEqual(to otherObject: Any) -> Bool {
        return self == (otherObject as? UInt)
    }
}

extension UInt8: DBDataTypeEquality {
    public func isEqual(to otherObject: Any) -> Bool {
        return self == (otherObject as? UInt8)
    }
}

extension UInt16: DBDataTypeEquality {
    public func isEqual(to otherObject: Any) -> Bool {
        return self == (otherObject as? UInt16)
    }
}

extension UInt32: DBDataTypeEquality {
    public func isEqual(to otherObject: Any) -> Bool {
        return self == (otherObject as? UInt32)
    }
}

extension UInt64: DBDataTypeEquality {
    public func isEqual(to otherObject: Any) -> Bool {
        return self == (otherObject as? UInt64)
    }
}

extension Decimal: DBDataTypeEquality {
    public func isEqual(to otherObject: Any) -> Bool {
        return self == (otherObject as? Decimal)
    }
}

extension Double: DBDataTypeEquality {
    public func isEqual(to otherObject: Any) -> Bool {
        return self == (otherObject as? Double)
    }
}

extension Float: DBDataTypeEquality {
    public func isEqual(to otherObject: Any) -> Bool {
        return self == (otherObject as? Float)
    }
}

extension String: DBDataTypeEquality {
    public func isEqual(to otherObject: Any) -> Bool {
        return self == (otherObject as? String)
    }
}

extension Bool: DBDataTypeEquality {
    public func isEqual(to otherObject: Any) -> Bool {
        return self == (otherObject as? Bool)
    }
}

extension Date: DBDataTypeEquality {
    public func isEqual(to otherObject: Any) -> Bool {
        return self == (otherObject as? Date)
    }
}

extension Data: DBDataTypeEquality {
    public func isEqual(to otherObject: Any) -> Bool {
        return self == (otherObject as? Data)
    }
}

extension UUID: DBDataTypeEquality {
    public func isEqual(to otherObject: Any) -> Bool {
        return self == (otherObject as? UUID)
    }
}

extension URL: DBDataTypeEquality {
    public func isEqual(to otherObject: Any) -> Bool {
        return self == (otherObject as? URL)
    }
}
