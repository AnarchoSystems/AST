//
//  Rule.swift
//  
//
//  Created by Markus Kasperczyk on 02.11.23.
//

public protocol Plugin {
    associatedtype Node : ASTNode
    var name : String {get}
}

public extension Plugin {
    var nodeType : String {
        Node.typeDescription
    }
}

public struct PluginsError : Error {
    public let nodeType : String
    public let name : String
    public let kind : Kind
    public enum Kind {
        case nameConflict
        case notFound
    }
}

public struct Plugins {
    private let dict : [String : [String : any Plugin]]
    public func get<Meta : ASTNode, T : Plugin>(meta: Meta.Type, name: String, as: T.Type = T.self) throws -> T {
        guard let result = dict[Meta.typeDescription]?[name] as? T else {
            throw PluginsError(nodeType: Meta.typeDescription, name: name, kind: .notFound)
        }
        return result
    }
    public init(_ plugins: [any Plugin]) throws {
        self.dict = try Dictionary(plugins.map{plugin in (plugin.nodeType, [plugin.name : plugin])}) {dict1, dict2 in
            try dict1.merging(dict2) {
                throw PluginsError(nodeType: $1.nodeType, name: $1.name, kind: .nameConflict)
            }
        }
    }
}

public extension AnyParser {
    var goal : String {
        Goal.typeDescription
    }
}

public struct ParserDefinitionError : Error {
    public let goal : String
    public let kind : Kind
    public enum Kind {
        case notDefined
        case multiplyDefined
    }
}

public struct Parsers {
    private let dict : [String : any AnyParser]
    public func get<Goal : ASTNode>(goal: Goal.Type) throws -> any AnyParser<Goal> {
        guard let result = dict[Goal.typeDescription] as? any AnyParser<Goal> else {
            throw ParserDefinitionError(goal: Goal.typeDescription, kind: .notDefined)
        }
        return result
    }
    public init(_ parsers: [any AnyParser]) throws {
        dict = try Dictionary(parsers.map{($0.goal, $0)}) {_, p in
            throw ParserDefinitionError(goal: p.goal, kind: .multiplyDefined)
        }
    }
}

public struct Context {
    public let plugins : Plugins
    public let parsers : Parsers
    public init(plugins: Plugins = try! .init([]),
                parsers: Parsers = try! .init([])) {
        self.plugins = plugins
        self.parsers = parsers
    }
}

public protocol Rule {
    var ruleName : String {get}
    associatedtype MetaType : ASTNode
    func onRecognize(in range: ClosedRange<String.Index>, context: Context) throws -> MetaType
}

public extension Rule {
    var ruleName : String {
        String(describing: Self.self)
    }
    var typeName : String {
        MetaType.typeDescription
    }
}

// MARK: Property Wrappers

public protocol ExprProperty {
    var expr : Expr {get}
}

public struct UnexpectedType : Error {
    public let given : Any
    public let expected : Any.Type
}

public protocol Injectable {
    var typeName : String {get}
    func inject(_ any: Any) throws
}

@propertyWrapper
public class NonTerminal<Meta : ASTNode> : ExprProperty, Injectable {
    public var typeName: String {
        Meta.typeDescription
    }
    var wrapped : Meta?
    public func inject(_ any: Any) throws {
        guard let meta = any as? Meta else {
            throw UnexpectedType(given: any, expected: Meta.self)
        }
        wrapped = meta
    }
    public var wrappedValue : Meta {
        get
        {
            wrapped!
        }
        set
        {
            wrapped = newValue
        }
    }
    public init() {}
    public var expr: Expr {
        .nonTerm(typeName)
    }
}

@propertyWrapper
public struct Terminal : ExprProperty {
    public let wrappedValue : Character
    public init(wrappedValue: Character) {
        self.wrappedValue = wrappedValue
    }
    public var expr: Expr {
        .term(wrappedValue)
    }
}
