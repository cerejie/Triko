# Security audit (defensive)

Goal: find where the system trusts something it should not. Defensive review only — describe the
weakness and how to verify it safely; never write a working exploit against a live system, never
run attacks against production, never exfiltrate data.

**First law:** the frontend hiding a button protects nothing. For every action the UI restricts
by role, find where the **server** (API handler, database policy, RPC guard) enforces it. No
server-side check found = finding.

## 1. Authentication and sessions
- How are credentials verified? Passwords hashed with a slow KDF (bcrypt/scrypt/argon2), never
  reversible or fast-hashed. Minimum length; breached-password check (judgment).
- Brute force: rate limiting / lockout / backoff on login, reset and signup endpoints.
- Tokens: where stored (httpOnly cookie vs localStorage — XSS exposure), lifetime, refresh flow,
  rotation, revocation on password change and sign-out. JWT: algorithm pinned, signature verified
  server-side, `exp` enforced, no secrets in the payload, signing key never in the client.
- Account enumeration through different errors for "unknown user" vs "wrong password".
- Password reset: single-use, expiring, not guessable; does not log the user in on another device
  silently.

## 2. Authorization
- Role model: where are roles stored and who can change them? Can a user change their own role
  through any write path (profile update, mass assignment)?
- IDOR: every endpoint/query taking an ID — is ownership or tenancy checked server-side?
- Row-level policies (Postgres RLS, Firestore rules, ORM scopes): enabled on every table?
  `SECURITY DEFINER` functions check the caller's role themselves? Policies cover SELECT,
  INSERT, UPDATE and DELETE separately? `WITH CHECK` on writes?
- Privilege escalation via functions/RPCs granted to all authenticated users.
- Multi-tenant: tenant ID derived from the session, never from the request body.

## 3. Input and output
- Validation on the server for every input (type, range, length, enum), not only in the form.
- Injection: SQL built by string concatenation; shell commands with user input; template
  injection; NoSQL operator injection; path traversal in file names.
- XSS: raw HTML rendering (`dangerouslySetInnerHTML`, `v-html`, `innerHTML`, `[innerHTML]`,
  `Html.Raw`), user content in `href`/`src` (`javascript:`), markdown renderers without sanitizing.
- SSRF: server fetching user-supplied URLs.
- File uploads: type checked by content not extension, size limits, stored outside the web root
  or in a bucket with correct access policy, served with safe content-type.
- Mass assignment: request bodies spread directly into DB updates.

## 4. Secrets and configuration
- Secrets in the repo, client bundle, `.env` committed, CI logs, or mobile/PWA assets. Grep for
  keys, tokens, private keys, service-role/admin keys. Anything prefixed for client exposure
  (`VITE_`, `NEXT_PUBLIC_`, `REACT_APP_`, `EXPO_PUBLIC_`) is public — is it meant to be?
- Environment separation: prod credentials usable from dev? One database for all environments?
- Debug modes, verbose errors, source maps with secrets in production.

## 5. Transport and browser
- HTTPS everywhere; HSTS. CORS: not `*` with credentials; allowed origins explicit.
- CSRF: cookie-authenticated state-changing requests need SameSite + token or origin check.
- Security headers at the host: CSP (no `unsafe-inline` scripts without nonce), `X-Content-Type-Options`,
  `Referrer-Policy`, `frame-ancestors`/`X-Frame-Options`, `Permissions-Policy`. If the host config
  is not in the repo, mark as unverified rather than missing.
- Service worker caching authenticated responses (data leaks across users on a shared device).

## 6. Data protection and logging
- Personal and financial data minimized, not logged, not in URLs, not in analytics events.
- Error messages leak stack traces, SQL, internal IDs, or which accounts exist.
- Sign-out clears tokens, caches, IndexedDB/localStorage user data, push subscriptions.
- Audit trail for sensitive actions (who changed role, voided, refunded, deleted).

## 7. Abuse and availability
- Rate limits on expensive or enumerable endpoints; request size limits; pagination caps.
- Idempotency on payments, checkouts and any write that a retry or double-tap could duplicate.
- Webhooks / edge functions: signature or shared secret verified; unauthenticated endpoints
  justified.

## 8. Dependencies and supply chain
- Lockfile committed; known-vulnerable packages (use the project's existing audit command only
  if it is read-only); abandoned packages in security-critical paths; postinstall scripts.

## Reporting security findings
- Severity follows exploitability × impact: unauthenticated data access or privilege escalation is
  Critical; authenticated cross-user access is High; missing defense-in-depth with another layer
  present is Medium/Low.
- Verification must be safe: describe the request a tester would make in a dev/staging
  environment with test accounts, and the expected vs observed response.
