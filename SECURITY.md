# ClovaLink Security Documentation

This document details the security architecture, access controls, and hardening measures implemented in ClovaLink.

---

## Table of Contents

1. [Authentication](#authentication)
2. [Role-Based Access Control](#role-based-access-control)
3. [Multi-Tenant Security](#multi-tenant-security)
4. [File Access Control](#file-access-control)
5. [API Security](#api-security)
6. [Compliance Modes](#compliance-modes)
7. [Audit Logging](#audit-logging)
8. [Storage Security](#storage-security)

---

## Authentication

### JWT Token Security

- **No hardcoded secrets**: `JWT_SECRET` must be set via environment variable
- **Production enforcement**: Server panics on startup if `JWT_SECRET` is missing in production
- **Key rotation support**: `JWT_SECRET_SECONDARY` allows zero-downtime key rotation
- **Issuer/Audience validation**: Tokens are validated against `JWT_ISSUER` and `JWT_AUDIENCE` claims
- **Expiration**: Tokens expire after configurable duration (default: session timeout from tenant settings)

### Password Security

- **Argon2 hashing**: Industry-standard password hashing with automatic salt generation
- **Compliance-enforced strength**: HIPAA/SOX modes require 12+ characters with uppercase, lowercase, numbers, and special characters

### Two-Factor Authentication (2FA)

- **TOTP-based**: RFC 6238 compliant time-based one-time passwords
- **Recovery codes**: Backup codes for account recovery
- **Per-tenant enforcement**: Admins can require 2FA for all users
- **Compliance-locked**: HIPAA/SOX modes force MFA on and prevent disabling

---

## Role-Based Access Control

### Standard Roles

| Role | Description |
|------|-------------|
| **SuperAdmin** | Platform-wide access across all tenants |
| **Admin** | Full access within their tenant |
| **Manager** | Department oversight and file management |
| **Employee** | Basic file access within their scope |

### Permission Matrix

#### Page Access

| Feature | SuperAdmin | Admin | Manager | Employee |
|---------|:----------:|:-----:|:-------:|:--------:|
| Dashboard | ✅ | ✅ | ❌ | ❌ |
| Companies | ✅ | ❌ | ❌ | ❌ |
| Users | ✅ | ✅ | ❌ | ❌ |
| Files | ✅ | ✅ | ✅ | ✅ |
| File Requests | ✅ | ✅ | ✅ | ✅ |
| Settings | ✅ | ✅ | ❌ | ❌ |
| Roles | ✅ | ✅ | ❌ | ❌ |
| Audit Logs | ✅ | ✅ | ❌ | ❌ |

#### File Operations

| Operation | SuperAdmin | Admin | Manager | Employee |
|-----------|:----------:|:-----:|:-------:|:--------:|
| View all files | ✅ | ✅ | Own dept | Own dept |
| View private files | ✅ | ✅ | Own only | Own only |
| View locked files | ✅ | ✅ | ✅ | Authorized only |
| Upload files | ✅ | ✅ | ✅ | ✅ |
| Download files | ✅ | ✅ | Accessible | Accessible |
| Delete files | ✅ | ✅ | Own files | Own files |
| Lock/Unlock files | ✅ | ✅ | ✅ | ❌ |
| Share files | ✅ | ✅ | ✅ | Own files |
| Create folders | ✅ | ✅ | ✅ | ✅ |

#### Search Results

| Search Type | SuperAdmin | Admin | Manager | Employee |
|-------------|:----------:|:-----:|:-------:|:--------:|
| Companies | ✅ | ❌ | ❌ | ❌ |
| Users | ✅ | ✅ | ❌ | ❌ |
| Files | All | All tenant | Accessible | Accessible |

### Custom Roles

Custom roles inherit permissions from a **base role** (Manager, Employee) and can have additional permissions granted:

```
files.lock      - Can lock files
files.unlock    - Can unlock files
users.view      - Can view user list
users.manage    - Can create/edit users
```

The system looks up a custom role's `base_role` to determine baseline permissions, then applies any additional granted permissions.

---

## Multi-Tenant Security

### Row-Level Isolation

Every database table with tenant data includes a `tenant_id` foreign key. All queries filter by tenant to prevent data leakage.

```sql
-- Example: Every file query includes tenant check
SELECT * FROM files_metadata 
WHERE tenant_id = $1 AND id = $2 AND is_deleted = false
```

### Tenant Scoping

- **API middleware**: Validates that users can only access their tenant's resources
- **SuperAdmin exception**: Can access any tenant for platform management
- **Cross-tenant protection**: Even if an attacker guesses a file ID, they cannot access it without matching tenant_id

### Tenant Switching

Users with access to multiple tenants (via `allowed_tenant_ids`) can switch contexts. A new JWT is issued with the target tenant, invalidating the old session context.

---

## File Access Control

### Visibility Levels

| Visibility | Who Can Access |
|------------|----------------|
| **department** | Users in the same department or with department in `allowed_department_ids` |
| **private** | Only the file owner |

### File Locking

Locked files have restricted access:

1. **Locker**: User who locked the file
2. **Owner**: File owner always has access
3. **Role requirement**: Optional role restriction (e.g., "Manager" required)
4. **Password protection**: Optional password for unlock

Non-authorized users cannot:
- Preview locked files
- Download locked files
- Share locked files
- View locked files in search results

### Department Access

Files inherit department from their parent folder. Users can access files if:

1. File has no department (root-level)
2. File is in user's primary department
3. File is in user's `allowed_department_ids`
4. User owns the file

---

## API Security

### CORS Configuration

```bash
# Production: Explicit allowed origins
CORS_ALLOWED_ORIGINS=https://app.example.com,https://admin.example.com

# Development: Enable localhost origins
CORS_DEV_MODE=true
```

- **Strict origin validation**: Only configured origins allowed
- **Credentials support**: Cookies and auth headers permitted from allowed origins
- **Limited methods**: Only GET, POST, PUT, DELETE, PATCH, OPTIONS
- **Limited headers**: Only Content-Type, Authorization, X-Requested-With

### Rate Limiting

Atomic Redis-based rate limiting prevents abuse:

```bash
# Configuration
RATE_LIMIT_REQUESTS=100    # Max requests
RATE_LIMIT_WINDOW=60       # Per this many seconds
```

- **Atomic operations**: Uses Redis INCR + EXPIRE to prevent race conditions
- **Per-IP tracking**: Limits applied per client IP
- **Trusted proxy support**: Configure `TRUSTED_PROXY_IPS` for load balancer scenarios

### Request Security

- **Content-Disposition sanitization**: Prevents header injection in file downloads
- **Path traversal prevention**: Zip downloads sanitize paths to prevent zip-slip attacks
- **Size limits**: Configurable max upload size, zip download limits
- **Streaming downloads**: Large files streamed to prevent OOM

---

## Compliance Modes

### HIPAA Mode

For healthcare organizations handling Protected Health Information (PHI):

| Setting | Value | Locked |
|---------|-------|:------:|
| MFA Required | Yes | ✅ |
| Session Timeout | 15 minutes | ✅ |
| Public Sharing | Disabled | ✅ |
| Audit Logging | Required | ✅ |
| Minimum Retention | 7 years | ✅ |
| File Versioning | Required | ✅ |

### SOX Mode

For financial compliance (Sarbanes-Oxley):

| Setting | Value | Locked |
|---------|-------|:------:|
| MFA Required | Yes | ✅ |
| Session Timeout | 30 minutes | ❌ |
| Public Sharing | Disabled | ✅ |
| Audit Logging | Required | ✅ |
| Minimum Retention | 7 years | ✅ |
| File Versioning | Required | ✅ |

### GDPR Mode

For EU data protection compliance:

| Setting | Value | Locked |
|---------|-------|:------:|
| MFA Required | No | ❌ |
| Export Logging | Required | ✅ |
| Data Export | Available | ✅ |
| Minimum Retention | 2 years | ✅ |
| Consent Tracking | Enabled | ✅ |

### Standard Mode

No restrictions—full flexibility for organizations without regulatory requirements.

---

## Audit Logging

### Logged Events

| Category | Events |
|----------|--------|
| **Authentication** | Login success/failure, logout, MFA challenges |
| **Files** | Upload, download, delete, rename, move, share |
| **Sharing** | Link created, link accessed, link expired |
| **Users** | Created, updated, role changed, suspended |
| **Admin** | Settings changed, compliance mode changed |
| **Security** | Failed access attempts, rate limit hits |

### Log Structure

```json
{
  "id": "uuid",
  "tenant_id": "uuid",
  "user_id": "uuid",
  "action": "file_downloaded",
  "resource_type": "file",
  "resource_id": "uuid",
  "metadata": {
    "file_name": "report.pdf",
    "ip_address": "192.168.1.1"
  },
  "created_at": "2024-01-15T10:30:00Z"
}
```

### Retention

- **HIPAA/SOX**: 7 years minimum, cannot be disabled
- **GDPR**: 2 years minimum
- **Standard**: Configurable (30-730 days)

---

## Storage Security

### Content-Addressed Storage

Files are stored using Blake3 content hashes:

```
uploads/{tenant_id}/{department_id}/{content_hash}
```

Benefits:
- **Deduplication**: Identical files stored once per department
- **Integrity verification**: Hash mismatch indicates corruption
- **Immutable references**: Renaming/moving files doesn't touch storage

### Encryption

- **In-transit**: TLS 1.2+ required for all connections
- **At-rest**: Depends on storage backend (S3 SSE, MinIO encryption)
- **Application-level**: ChaCha20-Poly1305 available for sensitive files (compliance modes)

### Presigned URLs

For S3-compatible storage, downloads can use presigned URLs:

```bash
USE_PRESIGNED_URLS=true
PRESIGNED_URL_EXPIRY=3600  # 1 hour
```

Benefits:
- Bypasses application server for large files
- Reduces bandwidth costs
- Maintains security via time-limited signed URLs

### Streaming Downloads (Zero-Copy)

When presigned URLs are unavailable (local storage or fallback), downloads use zero-copy streaming:

| File Size | Memory Usage |
|-----------|--------------|
| 10 MB | ~64 KB buffer |
| 100 MB | ~64 KB buffer |
| 1 GB | ~64 KB buffer |

Benefits:
- Constant memory usage regardless of file size
- No OOM risk from large file downloads
- Multiple concurrent downloads without memory pressure
- Files are never fully loaded into RAM

---

## Security Best Practices

### Production Checklist

- [ ] Set strong `JWT_SECRET` (64+ random characters)
- [ ] Configure explicit `CORS_ALLOWED_ORIGINS`
- [ ] Enable TLS termination (Nginx/Caddy)
- [ ] Use managed PostgreSQL with encryption
- [ ] Enable S3 server-side encryption
- [ ] Configure rate limiting
- [ ] Set up log aggregation for audit logs
- [ ] Regular security updates for containers

### Environment Variables

```bash
# Required for production
JWT_SECRET=<64-char-random>
DATABASE_URL=postgres://user:pass@host/db?sslmode=require
REDIS_URL=redis://:password@host:6379

# Recommended
CORS_ALLOWED_ORIGINS=https://your-domain.com
TRUSTED_PROXY_IPS=10.0.0.0/8
RATE_LIMIT_REQUESTS=100
RATE_LIMIT_WINDOW=60
```

---

## Reporting Security Issues

If you discover a security vulnerability, please email security@clovalink.com with:

1. Description of the vulnerability
2. Steps to reproduce
3. Potential impact assessment

We aim to respond within 48 hours and provide a fix within 7 days for critical issues.

---

*Last updated: December 2025*

