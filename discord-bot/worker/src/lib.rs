use worker::*;

#[event(fetch)]
async fn main(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    Router::new()
        .get("/health", |_, _| Response::ok("OK"))
        .post_async("/interactions", |_req, _ctx| async move {
            Response::ok("TODO: handle Discord interactions")
        })
        .run(req, env)
        .await
}
