## Summary
Database framework provides a unified API for storing, retrieving and observing Database values on iOS and Android.

## Rationale
Deciding where to store data, how to transform it, how to observe it, or where to save the data requires additional decision making and manual work. This framework alleviates all that by providing a simple consistent API across both platforms.

## Usage
First we need to define a `StoreKey`. A `StoreKey` defines how, what and where to store the value.

On iOS:
```swift
// Add an extension on StoreKeys
extension StoreKeys {
   // This will store a String in UserDefaults
   static let userId = UserDefaultsStoreKey<String>("userId")
   
   // This will cache a Boolean in memory.
   static let isPillHidden = MemoryStoreKey<Bool>("isPillHidden")
   
   // This will securily store a User object in Keychain
   static let user = KeychainStoreKey<User>("user")
}
```

On Android
```kotlin
// Add an extension on StoreKeys object

// This will store a String in Android SharedPreferences
val StoreKeys.userId by lazy { SharedPrefsStoreKey(id = "userId", clazz = String::class.java) }

// This will cache a Boolean in memory.
val StoreKeys.isPillHidden by lazy { MemoryStoreKey(id = "isPillHidden", clazz = Boolean::class.java) }
   
// This will encrypt & store a User object in SharedPreferences
val StoreKeys.user by lazy { EncryptedSharedPrefsStoreKey(id = "user", clazz = User::class.java) }
```

Once the key is defined, the store can be accessed, modified, or observed as follows:

On iOS
```swift
// Get operation
let userId = store.get(.userId)
let user = store.get(.user)


// Set operation
store.set(.userId, "420")
store.set(.user, User(id: 123, name: "Adam"))

// Observe operation
store.observe(.isPillHidden)
    .subscribe(onNext: { value in
        // value is of type Bool
    })
```

On Android:
```kotlin
// Get operation
val userId = store.get(StoreKeys.userId)
val user = store.get(StoreKeys.user)

// Set operation
store.set(StoreKeys.userId, "420")
store.set(StoreKeys.user, User(id = 123, name = "Adam"))

// Observe operation
store.observe(StoreKeys.isPillHidden)
    .subscribe { value -> 
        // value is of type Boolean
    }
```
