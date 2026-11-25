// Sends RPCs to the SkirRPC service. See start-service for how to start it.
//
// Run with:
//
//     cargo run --bin call-service
//
// Make sure the service is running first (using start-service).

use skir_rust_example::skir_client::{JsonFlavor, ServiceClient};
use skir_rust_example::skirout::base::service::{
    add_user_method, get_user_method, AddUserRequest, GetUserRequest,
};
use skir_rust_example::skirout::base::user::{tarzan_const, SubscriptionStatus, User};

#[tokio::main]
async fn main() {
    let client = ServiceClient::new("http://localhost:8787/myapi").unwrap();

    // Add two users.
    for user in [
        User {
            user_id: 42,
            name: "John Doe".to_string(),
            quote: "Coffee is just a socially acceptable form of rage.".to_string(),
            pets: vec![],
            subscription_status: SubscriptionStatus::Free,
            _unrecognized: None,
        },
        tarzan_const().clone(),
    ] {
        let name = user.name.clone();
        let id = user.user_id;
        client
            .invoke_remote(
                add_user_method(),
                &AddUserRequest {
                    user,
                    _unrecognized: None,
                },
                &[],
            )
            .await
            .unwrap();
        println!("Added user {:?} (id={})", name, id);
    }

    // Retrieve Tarzan.
    let tarzan = tarzan_const();
    let resp = client
        .invoke_remote(
            get_user_method(),
            &GetUserRequest {
                user_id: tarzan.user_id,
                _unrecognized: None,
            },
            &[],
        )
        .await
        .unwrap();

    match resp.user {
        Some(user) => println!(
            "Got user: {}",
            User::serializer().to_json(&user, JsonFlavor::Readable)
        ),
        None => println!("User not found"),
    }
}
