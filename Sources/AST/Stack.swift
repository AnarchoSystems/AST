//
//  Stack.swift
//
//
//  Created by Markus Kasperczyk on 28.10.23.
//

public struct Stack<T> {
    
    var rep : [T] = []
    public init() {}
    
    public mutating func push(_ t: T) {
        rep.append(t)
    }
    
    public mutating func pop() -> T? {
        guard peek() != nil else {return nil}
        return rep.removeLast()
    }
    
    public func peek() -> T? {
        rep.last
    }
    
}
