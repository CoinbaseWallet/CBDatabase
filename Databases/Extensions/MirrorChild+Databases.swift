// Copyright (c) 2017-2018 Coinbase Inc. See LICENSE

import Foundation

extension Collection where Element == Mirror.Child {
    /// Converts array of mirror child pairs to a dictionary
    var asDictionary: [String: Any] {
        return reduce(into: [:]) { dict, keyValue in
            guard let label = keyValue.label else { return }
            dict[label] = keyValue.value
        }
    }
}
