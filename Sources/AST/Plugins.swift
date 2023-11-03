//
//  Plugins.swift
//
//
//  Created by Markus Kasperczyk on 03.11.23.
//

public protocol Plugin<Pattern, Meta> where Meta == Pattern.MetaType {
    associatedtype Pattern : Rule
    associatedtype Meta
    func onDetect(_ rule: Pattern, node: inout Meta, context: Context) throws
}

public extension Plugin {
    var ruleKind : String {
        String(describing: Pattern.self)
    }
}

public struct Plugins {
    private let dict : [String : [any Plugin]]
    
    public func get(ruleKind: String) -> [any Plugin] {
        guard let result = dict[ruleKind] else {
            return []
        }
        return result
    }
    
    public init(_ plugins: [any Plugin]) {
        self.dict =  Dictionary(plugins.map{(plugin) in (plugin.ruleKind, [plugin])}, uniquingKeysWith: +)
    }
    
}
