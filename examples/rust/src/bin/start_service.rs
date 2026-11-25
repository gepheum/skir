// Starts a SkirRPC service on http://localhost:8787/myapi
//
// Run with:
//
//     cargo run --bin start-service
//
// Use call-service to send requests to this service.

use std::collections::HashMap;
use std::sync::Arc;

use axum::body::Bytes;
use axum::extract::{RawQuery, State};
use axum::http::{header, StatusCode};
use axum::response::IntoResponse;
use axum::routing::get;
use axum::Router;
use tokio::sync::RwLock;

use skir_rust_example::skir_client::{HttpErrorCode, Service, ServiceBuilder, ServiceError};
use skir_rust_example::skirout::base::service::{
    add_user_method, get_user_method, AddUserResponse, GetUserResponse,
};
use skir_rust_example::skirout::base::user::User;

type UserStore = Arc<RwLock<HashMap<i32, User>>>;

async fn handle_get(
    State((service, _store)): State<(Arc<Service<()>>, UserStore)>,
    RawQuery(query): RawQuery,
) -> impl IntoResponse {
    // Percent-decode the query string and use it as the request body.
    let raw = query.as_deref().unwrap_or("");
    let decoded = urlencoding::decode(raw).unwrap_or(std::borrow::Cow::Borrowed(raw));
    let resp = service.handle_request(&decoded, ()).await;
    let status =
        StatusCode::from_u16(resp.status_code).unwrap_or(StatusCode::INTERNAL_SERVER_ERROR);
    (
        status,
        [(header::CONTENT_TYPE, resp.content_type)],
        resp.data,
    )
}

async fn handle(
    State((service, _store)): State<(Arc<Service<()>>, UserStore)>,
    body: Bytes,
) -> impl IntoResponse {
    let body_str = match std::str::from_utf8(&body) {
        Ok(s) => s,
        Err(_) => {
            return (
                StatusCode::BAD_REQUEST,
                [(header::CONTENT_TYPE, "text/plain; charset=utf-8")],
                "bad request: body is not valid UTF-8".to_string(),
            );
        }
    };
    let resp = service.handle_request(body_str, ()).await;
    let status =
        StatusCode::from_u16(resp.status_code).unwrap_or(StatusCode::INTERNAL_SERVER_ERROR);
    (
        status,
        [(header::CONTENT_TYPE, resp.content_type)],
        resp.data,
    )
}

#[tokio::main]
async fn main() {
    let store: UserStore = Arc::new(RwLock::new(HashMap::new()));

    let store_get = store.clone();
    let store_add = store.clone();

    let service = Arc::new(
        ServiceBuilder::<()>::new()
            .add_method(get_user_method(), move |req, _: ()| {
                let store = store_get.clone();
                async move {
                    let guard = store.read().await;
                    let user = guard.get(&req.user_id).cloned();
                    Ok(GetUserResponse {
                        user,
                        _unrecognized: None,
                    })
                }
            })
            .unwrap()
            .add_method(add_user_method(), move |req, _: ()| {
                let store = store_add.clone();
                async move {
                    if req.user.user_id == 0 {
                        return Err(anyhow::Error::from(ServiceError {
                            status_code: HttpErrorCode::_400_BadRequest,
                            message: "user_id must be non-zero".to_string(),
                            source: None,
                        }));
                    }
                    let mut guard = store.write().await;
                    guard.insert(req.user.user_id, req.user);
                    Ok(AddUserResponse {
                        _unrecognized: None,
                    })
                }
            })
            .unwrap()
            .build(),
    );

    let app = Router::new()
        .route("/myapi", get(handle_get).post(handle))
        .with_state((service, store));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:8787").await.unwrap();
    println!("Listening on http://localhost:8787/myapi");
    axum::serve(listener, app).await.unwrap();
}
