import Foundation
import Combine

// MARK: - UserDefault Property Wrapper

/// Backs a property directly by `UserDefaults.standard`, publishing changes through the
/// enclosing `ObservableObject`'s `objectWillChange` — the same reactivity `@Published`
/// gives, but in one line: no separate stored property, no `didSet` that re-spells the
/// UserDefaults key as a string, and no init-time hydration line to keep in sync.
///
/// Relies on the "enclosing self" property wrapper subscript, which only works on stored
/// properties of a class conforming to `ObservableObject`.
@propertyWrapper
struct UserDefault<Value> {
    let key: String
    let defaultValue: Value

    init(_ key: String, default defaultValue: Value) {
        self.key = key
        self.defaultValue = defaultValue
    }

    @available(*, unavailable, message: "@UserDefault can only be applied to properties of a class conforming to ObservableObject")
    var wrappedValue: Value {
        get { fatalError() }
        // swiftlint:disable:next unused_setter_value
        set { fatalError() }
    }

    static subscript<EnclosingSelf: ObservableObject>(
        _enclosingInstance instance: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Self>
    ) -> Value {
        get {
            let box = instance[keyPath: storageKeyPath]
            return UserDefaults.standard.object(forKey: box.key) as? Value ?? box.defaultValue
        }
        set {
            let box = instance[keyPath: storageKeyPath]
            (instance.objectWillChange as? ObservableObjectPublisher)?.send()
            UserDefaults.standard.set(newValue, forKey: box.key)
        }
    }
}

// MARK: - UserDefaultRaw Property Wrapper

/// Same as `UserDefault`, but for `RawRepresentable` types (typically enums) that
/// UserDefaults can't store directly — persists `rawValue` instead.
@propertyWrapper
struct UserDefaultRaw<Value: RawRepresentable> where Value.RawValue == String {
    let key: String
    let defaultValue: Value

    init(_ key: String, default defaultValue: Value) {
        self.key = key
        self.defaultValue = defaultValue
    }

    @available(*, unavailable, message: "@UserDefaultRaw can only be applied to properties of a class conforming to ObservableObject")
    var wrappedValue: Value {
        get { fatalError() }
        // swiftlint:disable:next unused_setter_value
        set { fatalError() }
    }

    static subscript<EnclosingSelf: ObservableObject>(
        _enclosingInstance instance: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Self>
    ) -> Value {
        get {
            let box = instance[keyPath: storageKeyPath]
            guard let raw = UserDefaults.standard.string(forKey: box.key) else { return box.defaultValue }
            return Value(rawValue: raw) ?? box.defaultValue
        }
        set {
            let box = instance[keyPath: storageKeyPath]
            (instance.objectWillChange as? ObservableObjectPublisher)?.send()
            UserDefaults.standard.set(newValue.rawValue, forKey: box.key)
        }
    }
}
