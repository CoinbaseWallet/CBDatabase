// Copyright (c) 2017-2019 Coinbase Inc. See LICENSE

import Foundation

extension Collection where Element == Mirror.Child {
    /// Converts array of mirror child pairs to a dictionary
    var asDictionary: [String: Any] {
        return reduce(into: [:]) { dict, keyValue in
            guard let label = keyValue.label else { return }

            if let optionalValue = keyValue.value as? OptionalProtocol {
                dict[label] = optionalValue.unwrap()
            } else {
                dict[label] = keyValue.value
            }
        }
    }
}

/// Needed to unwrap an `Optional<Any>` from `Any` data type
private protocol OptionalProtocol {
    func unwrap() -> Any?
}

extension Optional: OptionalProtocol {
    func unwrap() -> Any? {
        return map { $0 }
    }
}
