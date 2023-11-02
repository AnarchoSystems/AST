//
//  Parser+CLR1.swift
//
//
//  Created by Markus Kasperczyk on 28.10.23.
//

// MARK: FIRST

fileprivate extension Grammar {
    func first(_ expr: Expr) -> Set<Character?> {
        switch expr {
        case .term(let term):
            return [term]
        case .nonTerm(let nT):
            var results : Set<Character?> = []
            var nTermsLookedAt : Set<String> = []
            var nTermsToLookAt : Set<String> = [nT]
            while !nTermsToLookAt.isEmpty {
                var newNTermsToLookAt : Set<String> = []
                for nT in nTermsToLookAt {
                    for rule in rules[nT]?.values ?? [:].values {
                        guard let next = Mirror(reflecting: rule).children.first(where: {$1 is Injectable || $1 is Terminal})?.value else {
                            results.insert(nil)
                            continue
                        }
                        if let term = next as? Terminal {
                            results.insert(term.wrappedValue)
                        }
                        else {
                            let inj = next as! Injectable
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

fileprivate struct Item<Chart : Grammar> : Node {
    
    struct Lookup {
        let chart : Chart
        var firsts : [Expr : Set<Character?>]
    }
    typealias Edge = String
    
    let rule : String?
    let meta : String
    let all : [Expr]
    let lookAheads : Set<Character?>
    let ptr : Int
    
    func canReach (lookup: inout Lookup) -> [String : [Item<Chart>]] {
        guard let next = tbd.first, case .nonTerm(let nT) = next else {
            return [:]
        }
        var lookAheads = self.lookAheads
        
        if let first = tbd.dropFirst().first {
            if lookup.firsts[first] == nil {
                lookup.firsts[first] = lookup.chart.first(first)
            }
            lookAheads = lookup.firsts[first]!
        }
        
        var values : [Item] = []
        
        for rule in lookup.chart.rules[nT]?.values ?? [:].values {
            let all : [Expr] = Mirror(reflecting: rule).children.compactMap{($1 as? ExprProperty)?.expr}
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

fileprivate struct ItemSet<Chart : Grammar> {
    
    let graph : ClosedGraph<Item<Chart>>
    
}

// MARK: HELPERS

extension Item {
    
    func tryAdvance(_ expr: Expr) -> Item<Chart>? {
        tbd.first.flatMap{$0 == expr ? Item(rule: rule, meta: meta, all: all, lookAheads: lookAheads, ptr: ptr + 1) : nil}
    }
    var tbd : some Collection<Expr> {
        all[ptr...]
    }
    
}

extension ItemSet : Node {
    
    struct Lookup {
        var nodeLookup : Item<Chart>.Lookup
        var seedLookup : [[Item<Chart>] : ItemSet<Chart>]
    }
    
    func canReach(lookup: inout Lookup) throws -> [Expr : [ItemSet<Chart>]] {
        let exprs = Set(graph.nodes.compactMap(\.tbd.first))
        let terms = Set(exprs.compactMap{expr -> Character? in
            guard case .term(let t) = expr else {return nil}
            return t
        }) as Set<Character?>
        let rules = try reduceRules()
        if !terms.intersection(rules.keys).isEmpty {
            throw ShiftReduceConflict()
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

fileprivate struct ItemSetTable<Chart : Grammar, Goal : ASTNode> {
    
    let graph : ClosedGraph<ItemSet<Chart>>
    
    init(rules: Chart.Type, goal: Goal.Type) throws {
        let chart = Chart()
        let augmentedRule = Item<Chart>(rule: nil,
                                        meta: "",
                                        all: [.nonTerm(Goal.typeDescription)],
                                        lookAheads: [nil],
                                        ptr: 0)
        var lookup = ItemSet<Chart>.Lookup(nodeLookup: .init(chart: chart, firsts: [:]), seedLookup: [:])
        let itemSetGraph = try ClosedGraph(seeds: [augmentedRule], lookup: &lookup.nodeLookup)
        graph = try ClosedGraph(seeds: [ItemSet(graph: itemSetGraph)], lookup: &lookup)
    }
    
}

// MARK: HELPER

extension ItemSet {
    
    func reduceRules() throws -> [Character? : (rule: String, meta: String)] {
        let results = graph.nodes.filter(\.tbd.isEmpty).flatMap{rule in rule.rule.map{val in rule.lookAheads.map{key in (key, (rule: val, meta: rule.meta))}} ?? []}
        return try Dictionary(results) {val1, val2 in
            if val1.rule == val2.rule && val1.meta == val2.meta {
                return val1
            }
            throw ReduceReduceConflict(meta1: val1.meta, meta2: val2.meta, rule1: val1.rule, rule2: val2.rule)
        }
    }
    
    
}

// MARK: ACTION + GOTO TABLES

extension ItemSetTable {
    
    func actionTable() throws -> [Character? : [Int : Action]] {
        
        // shifts
        
        let keyAndVals = graph.edges.compactMap{(key : Expr, vals : [Int : [Int]]) -> (Character, [Int : Action])? in
            guard case .term(let t) = key else {return nil}
            let dict = Dictionary(uniqueKeysWithValues: vals.map{start, ends in
                assert(ends.count == 1)
                return (start, Action.shift(ends.first!))
            })
            return (t, dict)
        }
        
        var dict = Dictionary(uniqueKeysWithValues: keyAndVals) as [Character? : [Int : Action]]
        
        for start in graph.nodes.indices {
            
            // reductions
            
            for (term, red) in try graph.nodes[start].reduceRules() {
                let (rule, meta) = red
                if dict[term] == nil {
                    dict[term] = [start: .reduce(rule: rule, recognized: meta)]
                }
                else {
                    if dict[term]?[start] != nil {
                        throw ShiftReduceConflict()
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
                        throw AcceptConflict()
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
    
    static func CLR1(rules: Chart.Type, goal: Goal.Type) throws -> Self {
        let table = try ItemSetTable(rules: rules, goal: goal)
        return Parser(actions: try table.actionTable(),
                      gotos: table.gotoTable)
    }
    
}

