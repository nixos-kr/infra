use ed25519_compact::{PublicKey, Signature};
use serde::Deserialize;
use serde_json::json;
use worker::*;

#[event(fetch)]
async fn main(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    Router::new()
        .get("/health", |_, _| Response::ok("OK"))
        .post_async("/interactions", handle_interaction)
        .run(req, env)
        .await
}

async fn handle_interaction(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let public_key = ctx.secret("DISCORD_PUBLIC_KEY")?.to_string();

    // Read headers before consuming body
    let signature = req
        .headers()
        .get("X-Signature-Ed25519")?
        .ok_or_else(|| Error::RustError("Missing signature header".into()))?;
    let timestamp = req
        .headers()
        .get("X-Signature-Timestamp")?
        .ok_or_else(|| Error::RustError("Missing timestamp header".into()))?;

    let body = req.text().await?;

    // Verify Ed25519 signature
    if !verify_signature(&public_key, &signature, &timestamp, body.as_bytes()) {
        return Response::error("Invalid signature", 401);
    }

    let interaction: Interaction = serde_json::from_str(&body)
        .map_err(|e| Error::RustError(format!("Invalid JSON: {}", e)))?;

    match interaction.interaction_type {
        // PING
        1 => Response::from_json(&json!({"type": 1})),
        // APPLICATION_COMMAND
        2 => handle_command(interaction, &ctx).await,
        _ => Response::error("Unknown interaction type", 400),
    }
}

fn verify_signature(
    public_key_hex: &str,
    signature_hex: &str,
    timestamp: &str,
    body: &[u8],
) -> bool {
    let Ok(pk_bytes) = hex::decode(public_key_hex) else {
        return false;
    };
    let Ok(sig_bytes) = hex::decode(signature_hex) else {
        return false;
    };
    let Ok(pk) = PublicKey::from_slice(&pk_bytes) else {
        return false;
    };
    let Ok(sig) = Signature::from_slice(&sig_bytes) else {
        return false;
    };

    let mut message = timestamp.as_bytes().to_vec();
    message.extend_from_slice(body);
    pk.verify(&message, &sig).is_ok()
}

async fn handle_command(interaction: Interaction, ctx: &RouteContext<()>) -> Result<Response> {
    // Extract message link from command options
    let message_link = interaction
        .data
        .as_ref()
        .and_then(|d| d.options.as_ref())
        .and_then(|opts| opts.first())
        .and_then(|opt| opt.value.as_ref())
        .and_then(|v| v.as_str())
        .unwrap_or("");

    if message_link.is_empty() {
        return Response::from_json(&json!({
            "type": 4,
            "data": {"content": "메시지 링크를 입력해주세요."}
        }));
    }

    // Parse channel ID and message ID from the link
    let parts: Vec<&str> = message_link.split("/channels/").collect();
    let ids: Vec<&str> = parts
        .get(1)
        .map(|s| s.split('/').collect())
        .unwrap_or_default();
    if ids.len() < 3 {
        return Response::from_json(&json!({
            "type": 4,
            "data": {"content": "올바른 메시지 링크가 아닙니다."}
        }));
    }
    let channel_id = ids[1];
    let msg_id = ids[2];

    // Trigger GitHub Actions via repository_dispatch
    let github_token = ctx.secret("GITHUB_TOKEN")?.to_string();
    let github_repo = ctx.var("GITHUB_REPO")?.to_string();

    // Validate required fields
    let token = interaction
        .token
        .as_deref()
        .ok_or_else(|| Error::RustError("Missing interaction token".into()))?;
    let app_id = interaction
        .application_id
        .as_deref()
        .ok_or_else(|| Error::RustError("Missing application_id".into()))?;

    let dispatch_body = json!({
        "event_type": "discord-archive",
        "client_payload": {
            "channel_id": channel_id,
            "message_id": msg_id,
            "interaction_token": token,
            "application_id": app_id,
        }
    });

    let url = format!("https://api.github.com/repos/{}/dispatches", github_repo);
    let mut headers = Headers::new();
    headers.set("Authorization", &format!("Bearer {}", github_token))?;
    headers.set("Accept", "application/vnd.github+json")?;
    headers.set("Content-Type", "application/json")?;
    headers.set("User-Agent", "nixoskr-archive-bot/1.0")?;

    let mut init = RequestInit::new();
    init.with_method(Method::Post);
    init.with_headers(headers);
    init.with_body(Some(dispatch_body.to_string().into()));

    let request = Request::new_with_init(&url, &init)?;
    let resp = Fetch::Request(request).send().await?;

    if resp.status_code() != 204 {
        return Response::from_json(&json!({
            "type": 4,
            "data": {"content": "GitHub Actions 트리거에 실패했습니다."}
        }));
    }

    // Respond with deferred message (type 5 = DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE)
    Response::from_json(&json!({"type": 5}))
}

#[derive(Deserialize)]
struct Interaction {
    #[serde(rename = "type")]
    interaction_type: u8,
    token: Option<String>,
    application_id: Option<String>,
    data: Option<InteractionData>,
}

#[derive(Deserialize)]
struct InteractionData {
    #[allow(dead_code)]
    name: Option<String>,
    options: Option<Vec<InteractionOption>>,
}

#[derive(Deserialize)]
struct InteractionOption {
    #[allow(dead_code)]
    name: String,
    value: Option<serde_json::Value>,
}
