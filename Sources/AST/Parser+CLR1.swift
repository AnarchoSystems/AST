//
//  Parser+CLR1.swift
//
//
//  Created by Markus Kasperczyk on 28.10.23.
//

// MARK: FIRST

fileprivate extension Grammar {
    func first(_ expr: Expr<Symbol.RawValue>) -> Set<Symbol.RawValue?> {
        switch expr {
        case .term(let term):
            return [term]
        case .nonTerm(let nT):
            var results : Set<Symbol.RawValue?> = []
            var nTermsLookedAt : Set<String> = []
            var nTermsToLookAt : Set<String> = [nT]
            while !nTermsToLookAt.isEmpty {
                var newNTermsToLookAt : Set<String> = []
                for nT in nTermsToLookAt {
                    for rule in rules[nT]?.values ?? [:].values {
                        guard let next = Mirror(reflecting: rule).children.first(where: {$1 is Injectable || $1 is _Terminal<Symbol>})?.value else {
                            results.insert(nil)
                            continue
                        }
                        if let term = next as? _Terminal<Symbol> {
                            results.insert(term.checkSymbol)
                        }
                        else {
                            let inj = next as! HasTypeName
                            if !nTermsLookedAt.contains(inj.typeName) {
                                newNTermsToLookAt.insert(inj.typeName)
                            }
                        }
                    }
                }
                nTermsLookedAt.formUnion(nTermsToLookAt)
                nTermsToLookAt = newNTermsToLookAt
            }
            return results
        case .eof:
            return [nil]
        }
    }
}

// MARK: CLR(1) ITEMS

fileprivate struct Item<G : Grammar> : Node {
    
    struct Lookup {
        let G : G
        var firsts : [Expr<G.Symbol.RawValue> : Set<G.Symbol.RawValue?>]
    }
    typealias Edge = String
    
    let rule : String?
    let meta : String
    let all : [Expr<G.Symbol.RawValue>]
    let lookAheads : Set<G.Symbol.RawValue?>
    let ptr : Int
    
    func canReach (lookup: inout Lookup) -> [String : [Item<G>]] {
        guard let next = tbd.first, case .nonTerm(let nT) = next else {
            return [:]
        }
        var lookAheads = self.lookAheads
        
        if let first = tbd.dropFirst().first {
            if lookup.firsts[first] == nil {
                lookup.firsts[first] = lookup.G.first(first)
            }
            lookAheads = lookup.firsts[first]!
        }
        
        var values : [Item] = []
        
        for rule in lookup.G.rules[nT]?.values ?? [:].values {
            let all : [Expr] = Mirror(reflecting: rule).children.compactMap{($1 as? any ExprProperty<G.Symbol.RawValue>)?.expr}
            values.append(Item(rule: rule.ruleName,
                               meta: rule.typeName,
                               all: all,
                               lookAheads: lookAheads,
                               ptr: 0))
        }
        
        return [nT : values]
    }
    
}

// MARK: CLR(1) ITEM SETS

fileprivate struct ItemSet<G : Grammar> {
    
    let graph : ClosedGraph<Item<G>>
    
}

// MARK: HELPERS

extension Item {
    
    func tryAdvance(_ expr: Expr<G.Symbol.RawValue>) -> Item<G>? {
        tbd.first.flatMap{$0 == expr ? Item(rule: rule, meta: meta, all: all, lookAheads: lookAheads, ptr: ptr + 1) : nil}
    }
    var tbd : some Collection<Expr<G.Context.State.Symbol.RawValue>> {
        all[ptr...]
    }
    
}

extension ItemSet : Node {
    
    struct Lookup {
        var nodeLookup : Item<G>.Lookup
        var seedLookup : [[Item<G>] : ItemSet<G>]
    }
    
    func canReach(lookup: inout Lookup) throws -> [Expr<G.Symbol.RawValue> : [ItemSet<G>]] {
        let exprs = Set(graph.nodes.compactMap(\.tbd.first))
        let terms = Set(exprs.compactMap{expr -> G.Symbol.RawValue? in
            guard case .term(let t) = expr else {return nil}
            return t
        }) as Set<G.Symbol.RawValue?>
        let rules = try reduceRules()
        if !terms.intersection(rules.keys).isEmpty {
            throw ASTError.parserGeneration(.shiftReduceConflict)
        }
        if exprs.isEmpty {
            return [:]
        }
        else {
            return try Dictionary(uniqueKeysWithValues: exprs.map{expr in
                let seeds = graph.nodes.compactMap{$0.tryAdvance(expr)}
                if let result = lookup.seedLookup[seeds] {
                    return (expr, [result])
                }
                let result = try ItemSet(graph: ClosedGraph(seeds: graph.nodes.compactMap{$0.tryAdvance(expr)}, lookup: &lookup.nodeLookup))
                lookup.seedLookup[seeds] = result
                return (expr, [result])
            })
        }
    }
}


// MARK: CLR(1) GRAPH

fileprivate struct ItemSetTable<G : Grammar, Goal : ASTNode> {
    
    let graph : ClosedGraph<ItemSet<G>>
    
    init(rules: G.Type, goal: Goal.Type) throws {
        let G = G()
        let augmentedRule = Item<G>(rule: nil,
                                        meta: "",
                                        all: [.nonTerm(Goal.typeDescription)],
                                        lookAheads: [nil],
                                        ptr: 0)
        var lookup = ItemSet<G>.Lookup(nodeLookup: .init(G: G, firsts: [:]), seedLookup: [:])
        let itemSetGraph = try ClosedGraph(seeds: [augmentedRule], lookup: &lookup.nodeLookup)
        graph = try ClosedGraph(seeds: [ItemSet(graph: itemSetGraph)], lookup: &lookup)
    }
    
}

// MARK: HELPER

extension ItemSet {
    
    func reduceRules() throws -> [G.Symbol.RawValue? : (rule: String, meta: String)] {
        let results = graph.nodes.filter(\.tbd.isEmpty).flatMap{rule in rule.rule.map{val in rule.lookAheads.map{key in (key, (rule: val, meta: rule.meta))}} ?? []}
        return try Dictionary(results) {val1, val2 in
            if val1.rule == val2.rule && val1.meta == val2.meta {
                return val1
            }
            throw ASTError.parserGeneration(.reduceReduceConflict(meta1: val1.meta, meta2: val2.meta, rule1: val1.rule, rule2: val2.rule))
        }
    }
    
    
}

// MARK: ACTION + GOTO TABLES

extension ItemSetTable {
    
    func actionTable() throws -> [G.Symbol.RawValue? : [Int : Action]] {
        
        // shifts
        
        let keyAndVals = graph.edges.compactMap{(key : Expr, vals : [Int : [Int]]) -> (G.Symbol.RawValue, [Int : Action])? in
            guard case .term(let t) = key else {return nil}
            let dict = Dictionary(uniqueKeysWithValues: vals.map{start, ends in
                assert(ends.count == 1)
                return (start, Action.shift(ends.first!))
            })
            return (t, dict)
        }
        
        var dict = Dictionary(uniqueKeysWithValues: keyAndVals) as [G.Symbol.RawValue? : [Int : Action]]
        
        for start in graph.nodes.indices {
            
            // reductions
            
            for (term, red) in try graph.nodes[start].reduceRules() {
                let (rule, meta) = red
                if dict[term] == nil {
                    dict[term] = [start: .reduce(rule: rule, recognized: meta)]
                }
                else {
                    if dict[term]?[start] != nil {
                        throw ASTError.parserGeneration(.shiftReduceConflict)
                    }
                    dict[term]?[start] = .reduce(rule: rule, recognized: meta)
                }
            }
            
            // accepts
            
            if graph.nodes[start].graph.nodes.contains(where: {$0.rule == nil && $0.tbd.isEmpty}) {
                if dict[nil] == nil {
                    dict[nil] = [start : .accept]
                }
                else {
                    if dict[nil]?[start] != nil {
                        throw ASTError.parserGeneration(.acceptConflict)
                    }
                    dict[nil]?[start] = .accept
                }
            }
        }
        return dict
    }
    
    var gotoTable : [String : [Int : Int]] {
        Dictionary(uniqueKeysWithValues: graph.edges.compactMap{(key : Expr, vals : [Int : [Int]]) in
            guard case .nonTerm(let nT) = key else {return nil}
            return (nT, vals.mapValues{ints in
                assert(ints.count == 1)
                return ints.first!
            })
        })
    }
    
}

// MARK: CLR(1) PARSER

public extension Parser {
    
    static func CLR1(rules: G.Type, goal: Goal.Type) throws -> Self {
        let table = try ItemSetTable(rules: rules, goal: goal)
        return Parser(actions: try table.actionTable(),
                      gotos: table.gotoTable)
    }
    
}

