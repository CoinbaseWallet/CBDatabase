// Copyright (c) 2017-2019 Coinbase Inc. See LICENSE

import Foundation

/// This protocol is used to wrap custom non-NSObject datatype
public protocol DBDataTypeWrapper: class, NSObjectProtocol, NSCoding, DBDataTypeEquality {
    /// Constructor with the wrapped custom datatype
    init?(model: Any)

    /// Returns original wrapped model
    var asModel: Any? { get }
}
