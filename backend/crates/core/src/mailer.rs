use lettre::{
    transport::smtp::authentication::Credentials,
    transport::smtp::client::Tls,
    transport::smtp::client::TlsParameters,
    Message, AsyncTransport,
};
use crate::models::Tenant;
use std::time::Duration;

#[derive(Debug, thiserror::Error)]
pub enum MailerError {
    #[error("SMTP configuration missing")]
    ConfigurationMissing,
    #[error("Failed to build email: {0}")]
    BuildError(#[from] lettre::error::Error),
    #[error("Failed to send email: {0}")]
    SendError(#[from] lettre::transport::smtp::Error),
    #[error("Invalid email address: {0}")]
    AddressError(#[from] lettre::address::AddressError),
}

pub async fn send_email(
    tenant: &Tenant,
    to: &str,
    subject: &str,
    body: &str,
) -> Result<(), MailerError> {
    let (host, port, username, password, from) = match (
        &tenant.smtp_host,
        tenant.smtp_port,
        &tenant.smtp_username,
        &tenant.smtp_password,
        &tenant.smtp_from,
    ) {
        (Some(h), Some(p), Some(u), Some(pw), Some(f)) => (h, p, u, pw, f),
        _ => return Err(MailerError::ConfigurationMissing),
    };

    let email = Message::builder()
        .from(from.parse()?)
        .to(to.parse()?)
        .subject(subject)
        .body(body.to_string())?;

    let creds = Credentials::new(username.clone(), password.clone());

    // Basic TLS configuration - in production, might need more options based on provider
    let tls = if tenant.smtp_secure.unwrap_or(true) {
        Tls::Wrapper(TlsParameters::new(host.clone())?)
    } else {
        Tls::None
    };



    // Lettre's async support is feature-gated and might require specific runtime setup.
    // For simplicity in this iteration, we use the synchronous transport in a blocking task if needed,
    // but here we are using the standard transport which is blocking.
    // Ideally, we should use AsyncSmtpTransport with Tokio.
    // Given the Cargo.toml has `tokio1` feature, let's assume we can use async if we change the type.
    // However, to avoid complexity with async traits in this step, we'll run it blocking for now
    // or use the async version if available.
    // Let's stick to the blocking `send` for now wrapped in `spawn_blocking` in the caller if needed,
    // OR just use it directly as this is a prototype.
    // Wait, `lettre` 0.11 `SmtpTransport` IS the synchronous one. `AsyncSmtpTransport` is for async.
    // Let's use `AsyncSmtpTransport` to be proper.

    // Re-implementation with AsyncSmtpTransport
    use lettre::AsyncSmtpTransport;
    use lettre::Tokio1Executor;

    let mailer: AsyncSmtpTransport<Tokio1Executor> = AsyncSmtpTransport::<Tokio1Executor>::relay(host)?
        .port(port as u16)
        .credentials(creds)
        .tls(tls)
        .timeout(Some(Duration::from_secs(10)))
        .build();

    mailer.send(email).await?;

    Ok(())
}

pub async fn test_smtp_connection(
    host: &str,
    port: i32,
    username: &str,
    password: &str,
    secure: bool,
) -> Result<(), MailerError> {
    use lettre::AsyncSmtpTransport;
    use lettre::Tokio1Executor;

    let creds = Credentials::new(username.to_string(), password.to_string());
    
    let tls = if secure {
        Tls::Wrapper(TlsParameters::new(host.to_string())?)
    } else {
        Tls::None
    };

    let mailer: AsyncSmtpTransport<Tokio1Executor> = AsyncSmtpTransport::<Tokio1Executor>::relay(host)?
        .port(port as u16)
        .credentials(creds)
        .tls(tls)
        .timeout(Some(Duration::from_secs(5)))
        .build();

    // Test connection by sending a NOOP
    mailer.test_connection().await?;

    Ok(())
}
