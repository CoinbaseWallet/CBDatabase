// Copyright (c) 2017-2019 Coinbase Inc. See LICENSE

import Foundation

/// Represents Database Errors
enum DatabaseDecoderError: Error {
    /// Unable to decode model property
    case unableToDecodeModelProperty

    /// Decoder function not implemented
    case decoderFunctionNotImplemented
}
