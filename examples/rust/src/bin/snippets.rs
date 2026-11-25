// Code snippets showing how to use Rust-generated data types.
//
// Run with: cargo run --bin snippets

use skir_rust_example::skir_client::{JsonFlavor, Serializer, UnrecognizedValues};
use skir_rust_example::skirout::base::service::{
    add_user_method, get_user_method, AddUserRequest, GetUserRequest,
};
use skir_rust_example::skirout::base::user::{
    tarzan_const, SubscriptionStatus, SubscriptionStatus_Trial, User, UserRegistry, User_Pet,
};

fn main() {
    // =========================================================================
    // STRUCT TYPES
    // =========================================================================

    // Skir generates a plain Rust struct for every struct in the .skir file.
    // Construct one by filling in each field directly.
    let john = User {
        user_id: 42,
        name: "John Doe".to_string(),
        quote: "Coffee is just a socially acceptable form of rage.".to_string(),
        pets: vec![User_Pet {
            name: "Dumbo".to_string(),
            height_in_meters: 1.0,
            picture: "🐘".to_string(),
            _unrecognized: None,
        }],
        subscription_status: SubscriptionStatus::Free,
        _unrecognized: None, // Present in every struct, always set it to None
    };

    println!("{}", john.name); // John Doe

    // User::default() returns a User with every field set to its default value.
    println!("{}", User::default().name); // (empty string)
    println!("{}", User::default().user_id); // 0

    // This Rust syntax allows you to specify just a few fields and use defaults
    // for the rest.
    let jane = User {
        user_id: 43,
        name: "Jane Doe".to_string(),
        ..User::default()
    };

    println!("{}", jane.quote); // (empty string)
    println!("{}", jane.pets.len()); // 0

    // Two ways to create a modified copy of a struct without mutating the original.

    // Option 1: clone, then mutate.
    let mut evil_john = john.clone();
    evil_john.name = "Evil John".to_string();
    evil_john.quote = "I solemnly swear I am up to no good.".to_string();

    println!("{}", evil_john.name); // Evil John
    println!("{}", evil_john.user_id); // 42 (copied from john)
    println!("{}", john.name); // John Doe (john is unchanged)

    // Option 2: use struct update syntax to copy fields from an existing instance.
    let evil_john_2 = User {
        name: "Evil John".to_string(),
        quote: "I solemnly swear I am up to no good.".to_string(),
        ..john.clone()
    };

    println!("{}", evil_john_2.name); // Evil John
    println!("{}", evil_john_2.user_id); // 42 (copied from john)
    println!("{}", john.name); // John Doe (john is unchanged)

    // =========================================================================
    // ENUM TYPES
    // =========================================================================

    // Skir generates a Rust enum for every enum in the .skir file.
    // The Unknown variant is added automatically and is the default.
    let _ = [
        // Unknown is the default and is present in all Skir enums.
        SubscriptionStatus::Unknown(None),
        SubscriptionStatus::default(), // Same as ::Unknown(None)
        SubscriptionStatus::Free,
        SubscriptionStatus::Premium,
        // Wrapper variants carry a value inside a Box.
        SubscriptionStatus::Trial(Box::new(SubscriptionStatus_Trial {
            start_time: std::time::SystemTime::now(),
            _unrecognized: None,
        })),
    ];

    // =========================================================================
    // ENUM MATCHING
    // =========================================================================

    // Direct match on enum variants:
    let get_info_text = |status: &SubscriptionStatus| -> String {
        match status {
            SubscriptionStatus::Free => "Free user".to_string(),
            SubscriptionStatus::Premium => "Premium user".to_string(),
            SubscriptionStatus::Trial(t) => {
                format!("On trial since {:?}", t.start_time)
            }
            SubscriptionStatus::Unknown(_) => "Unknown subscription status".to_string(),
        }
    };

    println!("{}", get_info_text(&john.subscription_status)); // Free user

    let now = std::time::SystemTime::now();
    let trial_status = SubscriptionStatus::Trial(Box::new(SubscriptionStatus_Trial {
        start_time: now,
        _unrecognized: None,
    }));
    println!("{}", get_info_text(&trial_status)); // On trial since ...

    // =========================================================================
    // SERIALIZATION
    // =========================================================================

    let serializer = User::serializer();

    // Serialize to dense JSON (field-number-based; the default mode).
    // Use this when you plan to deserialize the value later. Because field
    // names are not included, renaming a field remains backward-compatible.
    let john_dense_json = serializer.to_json(&john, JsonFlavor::Dense);
    println!("{}", john_dense_json);
    // [42,"John Doe",...]

    // Serialize to readable (name-based, indented) JSON.
    // Use this mainly for debugging.
    println!("{}", serializer.to_json(&john, JsonFlavor::Readable));
    // {
    //   "user_id": 42,
    //   "name": "John Doe",
    //   ...
    // }

    // Deserialize from JSON (both dense and readable formats are accepted).
    let reserialized_john = serializer
        .from_json(&john_dense_json, UnrecognizedValues::Drop)
        .unwrap();
    assert_eq!(reserialized_john, john);

    // Serialize to binary format (more compact than JSON; useful when
    // performance matters, though the difference is rarely significant).
    let john_bytes = serializer.to_bytes(&john);
    let from_bytes = serializer
        .from_bytes(&john_bytes, UnrecognizedValues::Drop)
        .unwrap();
    assert_eq!(from_bytes, john);

    // =========================================================================
    // PRIMITIVE SERIALIZERS
    // =========================================================================

    println!("{}", Serializer::bool().to_json(&true, JsonFlavor::Dense));
    // 1
    println!("{}", Serializer::int32().to_json(&3_i32, JsonFlavor::Dense));
    // 3
    println!(
        "{}",
        Serializer::int64().to_json(&9_223_372_036_854_775_807_i64, JsonFlavor::Dense)
    );
    // "9223372036854775807"
    println!(
        "{}",
        Serializer::float32().to_json(&1.5_f32, JsonFlavor::Dense)
    );
    // 1.5
    println!(
        "{}",
        Serializer::float64().to_json(&1.5_f64, JsonFlavor::Dense)
    );
    // 1.5
    println!(
        "{}",
        Serializer::string().to_json(&"Foo".to_string(), JsonFlavor::Dense)
    );
    // "Foo"

    // =========================================================================
    // COMPOSITE SERIALIZERS
    // =========================================================================

    // Optional serializer:
    println!(
        "{}",
        Serializer::optional(Serializer::string())
            .to_json(&Some("foo".to_string()), JsonFlavor::Dense)
    );
    // "foo"

    println!(
        "{}",
        Serializer::optional(Serializer::string()).to_json(&None::<String>, JsonFlavor::Dense)
    );
    // null

    // Array serializer:
    println!(
        "{}",
        Serializer::array(Serializer::bool()).to_json(&vec![true, false], JsonFlavor::Dense)
    );
    // [1,0]

    // =========================================================================
    // CONSTANTS
    // =========================================================================

    // Constants declared with 'const' in the .skir file are available as
    // functions in the generated Rust code.
    println!(
        "{}",
        User::serializer().to_json(tarzan_const(), JsonFlavor::Readable)
    );
    // {
    //   "user_id": 123,
    //   "name": "Tarzan",
    //   ...
    // }

    // =========================================================================
    // KEYED LISTS
    // =========================================================================

    // In the .skir file:
    //   struct UserRegistry {
    //     users: [User|user_id];
    //   }
    // The '|user_id' part tells Skir to generate a keyed array with O(1)
    // lookup by user_id.

    let user_registry = UserRegistry {
        users: vec![john.clone(), jane.clone(), evil_john.clone()].into(),
        _unrecognized: None,
    };

    // find_by_key returns the first element whose user_id matches.
    // The first call is O(n) to build the index; subsequent calls are O(1).
    let found = user_registry.users.find_by_key(43);
    println!("{}", found.is_some()); // true
    println!("{}", found.unwrap() == &jane); // true

    // If multiple elements share the same key, the first one wins.
    let found2 = user_registry.users.find_by_key(42);
    println!("{}", found2.unwrap() == &john); // true

    let not_found = user_registry.users.find_by_key(999_i32);
    println!("{}", not_found.is_none()); // true

    // find_by_key_or_default() returns a reference to the default (zero) value
    // when the key is not present, instead of returning None.
    let not_found_or_default = user_registry.users.find_by_key_or_default(999_i32);
    println!("{}", not_found_or_default.pets.len()); // 0

    // =========================================================================
    // REFLECTION
    // =========================================================================

    // Reflection allows you to inspect a Skir type at runtime.

    let td = User::serializer().type_descriptor();
    if let skir_rust_example::skir_client::TypeDescriptor::Struct(sd) = td {
        let names: Vec<&str> = sd.fields().iter().map(|f| f.name()).collect();
        println!("{:?}", names);
        // ["user_id", "name", "quote", "pets", "subscription_status"]
    }

    // A TypeDescriptor can be serialized to JSON and deserialized later.
    let td2 = skir_rust_example::skir_client::TypeDescriptor::parse_from_json(
        &User::serializer().type_descriptor().as_json(),
    )
    .unwrap();
    if let skir_rust_example::skir_client::TypeDescriptor::Struct(sd2) = td2 {
        println!("{}", sd2.fields().len()); // 5
    }

    // =========================================================================
    // RPC METHODS
    // =========================================================================

    // Skir generates a Method value for every 'method' declaration in the
    // .skir file. Methods carry their name, number, request/response
    // serializers, and documentation.
    let get_user = get_user_method();
    println!("{}", get_user.name); // GetUser
    println!("{}", get_user.number); // 12345
    println!("{}", get_user.doc); // Returns the user with the given user_id...

    // Suppress unused variable warnings.
    let _ = add_user_method();
    let _ = (jane, evil_john);
    let _ = AddUserRequest::default();
    let _ = GetUserRequest::default();
}
