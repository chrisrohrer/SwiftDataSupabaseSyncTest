//
//  Array ID Index.import RealmSwift
//  Poool1
//
//  Created by Christoph Rohrer on 31.08.22.
//

import Foundation


// von mir: bildet laufende Summe - array.accumulate(by: \.keypath)
public extension Collection {
    
    func accumulate<T: AdditiveArithmetic>(by property: WritableKeyPath<Element, T>) -> [Element] {
        var sum = T.zero
        var new = [Element].init()
        for item in self {
            sum += item[keyPath: property]
            var newitem = item
            newitem[keyPath: property] = sum
            new.append(newitem)
        }
        return new
    }
}



// von mir: statt reduce - array.sum(by: \.keypath)
public extension Collection  {
    
    func sum<T: AdditiveArithmetic>(by property: KeyPath<Element, T>) -> T {
        self.reduce(T.zero, {$0 + $1[keyPath: property] })
    }
    
    func sum() -> Self.Element where Self.Element: AdditiveArithmetic {
        self.reduce(Self.Element.zero, {$0 + $1})
    }

    func max<T: Comparable>(keypath property: KeyPath<Element, T>) -> Element? {
        self.max(by: { $0[keyPath: property] < $1[keyPath: property] })
    }

}


// von mir: statt sorted(by: - array.sorted(by: \.keypath)
public extension Sequence  { // war collection
    
    func sorted<T: Comparable>(keypath: KeyPath<Element, T>, ascending: Bool = true) -> [Element] {
        if ascending {
            return self.sorted(by: { $0[keyPath: keypath] < $1[keyPath: keypath] })
        } else {
            return self.sorted(by: { $0[keyPath: keypath] > $1[keyPath: keypath] })
        }
    }
}


// folgende von Harvard.edu
public extension Array where Array.Element: Identifiable {
    
    subscript(elementID: Element.ID?) -> Element? {
        if let elementID, let element = self.first(where: { $0.id == elementID }) {
            return element
        }
        return nil
    }
}


public extension Collection where Element: Identifiable {
    
    subscript(elementID: Element.ID?) -> Element? {
        if let element = self.first(where: {$0.id == elementID}) {
            return element
        } else {
            return nil
        }
    }
    
    
    func index(matching element: Element) -> Self.Index? {
        firstIndex(where: { $0.id == element.id })
    }
}


public extension RangeReplaceableCollection where Element: Identifiable {

    subscript(_ element: Element) -> Element {
         get {
             if let index = index(matching: element) {
                 return self[index]
             } else {
                 return element
             }
         }
         set {
             if let index = index(matching: element) {
                 replaceSubrange(index...index, with: [newValue])
             }
         }
     }

}


// unique values from an array
public extension Sequence where Iterator.Element: Hashable {
    
    func uniqueValues() -> [Iterator.Element] {
        var seen: Set<Iterator.Element> = []
        return filter { seen.insert($0).inserted }
    }
}
