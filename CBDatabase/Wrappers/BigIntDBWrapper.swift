// Copyright (c) 2017-2019 Coinbase Inc. See LICENSE

import BigInt

/// DB datatype wrapper to allow `BigInt` storage in Database
public final class BigIntDBWrapper: NSObject, DBDataTypeWrapper {
    private let model: BigInt

    public var asModel: Any? { return model }

    public required init?(model: Any) {
        guard let bigIntModel = model as? BigInt else { return nil }

        self.model = bigIntModel
    }

    public required init?(coder aDecoder: NSCoder) {
        guard
            let value = aDecoder.decodeObject(forKey: "model") as? String,
            let model = BigInt(value)
            else { return nil }

        self.model = model
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(String(model), forKey: "model")
    }

    public func isEqual(to otherWrapper: Any) -> Bool {
        guard let otherWrapper = otherWrapper as? BigIntDBWrapper else { return false }

        return model == otherWrapper.model
    }
}
