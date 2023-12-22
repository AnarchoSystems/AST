//
//  SymbolProtocol.swift
//
//
//  Created by Markus Kasperczyk on 22.12.23.
//

import Foundation

public protocol SymbolProtocol {
    associatedtype RawValue : Hashable & Codable
    var rawValue : RawValue {get}
}

extension Character : Codable {
    
    public func encode(to encoder: Encoder) throws {
        try String(self).encode(to: encoder)
    }
    
    public init(from decoder: Decoder) throws {
        let str = try String(from: decoder)
        guard str.count == 1 else {
            throw NSError() //todo
        }
        self = str.first!
    }
    
}

extension Character : SymbolProtocol {
    public var rawValue : Character {
        self
    }
}
