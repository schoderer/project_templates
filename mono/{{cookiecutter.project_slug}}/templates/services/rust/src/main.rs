//! __NAME__: sample HTTP service.
//!
//! Routes:
//! - `GET /health`       -> `ok`
//! - `GET /hello/{name}` -> `Hello, {name}!`
//!
//! Listens on `0.0.0.0:$PORT` (default 8080).

use axum::{Router, extract::Path, routing::get};
use tokio::signal::unix::{SignalKind, signal};

async fn health() -> &'static str {
    "ok"
}

async fn hello(Path(name): Path<String>) -> String {
    format!("Hello, {name}!")
}

fn app() -> Router {
    Router::new()
        .route("/health", get(health))
        .route("/hello/{name}", get(hello))
}

/// Resolves on Ctrl-C or SIGTERM (what `docker stop` sends).
async fn shutdown_signal() {
    let mut terminate = signal(SignalKind::terminate()).expect("install SIGTERM handler");
    tokio::select! {
        _ = tokio::signal::ctrl_c() => {}
        _ = terminate.recv() => {}
    }
}

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let port = std::env::var("PORT")
        .ok()
        .and_then(|port| port.parse::<u16>().ok())
        .unwrap_or(8080);

    let listener = tokio::net::TcpListener::bind(("0.0.0.0", port)).await?;
    println!("listening on {}", listener.local_addr()?);

    axum::serve(listener, app())
        .with_graceful_shutdown(shutdown_signal())
        .await
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn health_is_ok() {
        assert_eq!(health().await, "ok");
    }

    #[tokio::test]
    async fn hello_greets_by_name() {
        assert_eq!(hello(Path("nix".to_string())).await, "Hello, nix!");
    }
}
