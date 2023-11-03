//
//  Action.swift
//  
//
//  Created by Markus Kasperczyk on 03.11.23.
//

import Foundation

public enum Action : Codable, Equatable {
    case shift(Int)
    case reduce(rule: String, recognized: String)
    case accept
    
    enum RawType : String, Codable {
        case shift, reduce, accept
    }
    struct TypeCoder : Codable {
        let type : RawType
    }
    enum _Shift : String, Codable {case shift}
    struct Shift : Codable {
        let type : _Shift
        let newState : Int
    }
    enum _Reduce : String, Codable {case reduce}
    struct Reduce : Codable {
        let type : _Reduce
        let rule : String
        let recognized : String
    }
    
    public init(from decoder: Decoder) throws {
        let type = try TypeCoder(from: decoder)
        switch type.type {
        case .shift:
            let this = try Shift(from: decoder)
            self = .shift(this.newState)
        case .reduce:
            let this = try Reduce(from: decoder)
            self = .reduce(rule: this.rule, recognized: this.recognized)
        case .accept:
            self = .accept
        }
    }
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .shift(let newState):
            try Shift(type: .shift, newState: newState).encode(to: encoder)
        case .reduce(let rule, let meta):
            try Reduce(type: .reduce, rule: rule, recognized: meta).encode(to: encoder)
        case .accept:
            try TypeCoder(type: .accept).encode(to: encoder)
        }
    }
}
