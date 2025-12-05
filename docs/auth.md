# Authentication System

This document explains the Google OAuth + JWT authentication flow implemented in Elyra.

## Overview

The authentication system uses:

- **Google OAuth 2.0** for user identity verification
- **JWT (JSON Web Tokens)** for stateless session management
- **Ueberauth** (Elixir library) for OAuth handling
- **Guardian** (Elixir library) for JWT encoding/decoding

## Authentication Flow

```
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│    Frontend     │      │     Backend     │      │     Google      │
│  (SvelteKit)    │      │    (Phoenix)    │      │    OAuth 2.0    │
└────────┬────────┘      └────────┬────────┘      └────────┬────────┘
         │                        │                        │
         │  1. Click "Sign in     │                        │
         │     with Google"       │                        │
         │───────────────────────>│                        │
         │  GET /api/auth/google  │                        │
         │                        │                        │
         │                        │  2. Redirect to Google │
         │                        │───────────────────────>│
         │                        │                        │
         │                        │                        │  3. User logs in
         │                        │                        │     & approves
         │                        │                        │
         │                        │  4. Callback with code │
         │                        │<───────────────────────│
         │                        │  GET /api/auth/google/ │
         │                        │      callback?code=... │
         │                        │                        │
         │                        │  5. Exchange code for  │
         │                        │     user info          │
         │                        │───────────────────────>│
         │                        │<───────────────────────│
         │                        │                        │
         │                        │  6. Create/find user   │
         │                        │     in database        │
         │                        │                        │
         │                        │  7. Generate JWT       │
         │                        │                        │
         │  8. Redirect with JWT  │                        │
         │<───────────────────────│                        │
         │  /auth/callback?token= │                        │
         │                        │                        │
         │  9. Store JWT in       │                        │
         │     localStorage       │                        │
         │                        │                        │
         │  10. Redirect to       │                        │
         │      /onboarding or    │                        │
         │      /dashboard        │                        │
         │                        │                        │
         │  11. API requests with │                        │
         │      Authorization:    │                        │
         │      Bearer <JWT>      │                        │
         │───────────────────────>│                        │
         │                        │                        │
         │  12. Validate JWT,     │                        │
         │      return user data  │                        │
         │<───────────────────────│                        │
```

## Backend Files

### Configuration

#### `config/config.exs`

Configures Ueberauth providers and Guardian settings:

```elixir
config :ueberauth, Ueberauth,
  base_path: "/api/auth",
  providers: [
    google: {Ueberauth.Strategy.Google, [default_scope: "email profile"]}
  ]

config :backend, Backend.Guardian,
  issuer: "backend",
  secret_key: "..."
```

#### `config/runtime.exs`

Loads Google OAuth credentials from environment variables at runtime:

```elixir
config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: env!("GOOGLE_CLIENT_ID", :string, nil),
  client_secret: env!("GOOGLE_CLIENT_SECRET", :string, nil)
```

### Database

#### `lib/backend/accounts/user.ex`

User schema with fields from Google OAuth:

- `google_id` - Unique Google user ID
- `email` - User's email
- `name`, `given_name`, `family_name` - Name fields
- `picture` - Profile photo URL
- `username` - App-specific username (set during onboarding)

#### `lib/backend/accounts.ex`

Context module with user operations:

- `find_or_create_from_google/1` - Creates user from OAuth data or returns existing
- `set_username/2` - Sets username during onboarding
- `username_available?/1` - Checks if username is taken

### Authentication

#### `lib/backend/guardian.ex`

Guardian implementation for JWT handling:

```elixir
defmodule Backend.Guardian do
  use Guardian, otp_app: :backend

  # Encode user ID into JWT subject claim
  def subject_for_token(%{id: id}, _claims), do: {:ok, to_string(id)}

  # Decode JWT subject back to user
  def resource_from_claims(%{"sub" => id}) do
    case Accounts.get_user(id) do
      nil -> {:error, :resource_not_found}
      user -> {:ok, user}
    end
  end
end
```

#### `lib/backend_web/plugs/auth_pipeline.ex`

Guardian plug pipeline for protected routes:

```elixir
defmodule BackendWeb.AuthPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :backend,
    module: Backend.Guardian,
    error_handler: BackendWeb.AuthErrorHandler

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer"  # Check Authorization header
  plug Guardian.Plug.EnsureAuthenticated             # Require valid token
  plug Guardian.Plug.LoadResource                    # Load user from token
end
```

### Controllers

#### `lib/backend_web/controllers/auth_controller.ex`

Handles OAuth flow:

- `request/2` - Ueberauth intercepts and redirects to Google
- `callback/2` - Receives Google callback, creates user, generates JWT, redirects to frontend

#### `lib/backend_web/controllers/user_controller.ex`

User API endpoints:

- `me/2` - Returns current authenticated user
- `set_username/2` - Updates username (onboarding)
- `check_username/2` - Checks username availability

### Router

#### `lib/backend_web/router.ex`

```elixir
# OAuth routes (public, need sessions for CSRF)
scope "/api/auth", BackendWeb do
  pipe_through(:browser)
  get("/:provider", AuthController, :request)
  get("/:provider/callback", AuthController, :callback)
end

# Public API routes
scope "/api", BackendWeb do
  pipe_through(:api)
  get("/users/check-username", UserController, :check_username)
end

# Protected API routes (require JWT)
scope "/api", BackendWeb do
  pipe_through([:api, :authenticated])
  get("/users/me", UserController, :me)
  put("/users/username", UserController, :set_username)
end
```

## Frontend Files

### API Layer

#### `src/lib/api/types.ts`

TypeScript interfaces:

```typescript
interface User {
  id: number;
  email: string;
  name: string | null;
  username: string | null;
  picture: string | null;
  onboarding_complete: boolean;
}
```

#### `src/lib/api/client.ts`

API client that automatically includes JWT in requests:

```typescript
function getHeaders(): HeadersInit {
  const headers = { "Content-Type": "application/json" };
  const token = localStorage.getItem("auth_token");
  if (token) {
    headers["Authorization"] = `Bearer ${token}`;
  }
  return headers;
}
```

### State Management

#### `src/lib/stores/auth.svelte.ts`

Svelte 5 runes-based auth store:

```typescript
class AuthStore {
  user = $state<User | null>(null);
  token = $state<string | null>(null);
  isLoading = $state(true);

  get isAuthenticated() {
    return !!this.token && !!this.user;
  }
  get needsOnboarding() {
    return !!this.user && !this.user.onboarding_complete;
  }

  setToken(token: string) {
    /* stores in localStorage */
  }
  async loadUser() {
    /* fetches /api/users/me */
  }
  logout() {
    /* clears state and localStorage */
  }
}
```

### Pages

#### `src/routes/+page.svelte`

Home page with "Sign in with Google" button:

```svelte
function signInWithGoogle() {
  window.location.href = 'http://localhost:4000/api/auth/google';
}
```

#### `src/routes/auth/callback/+page.svelte`

OAuth callback handler:

1. Extracts `token` and `redirect` from URL params
2. Stores token via `auth.setToken(token)`
3. Loads user via `auth.loadUser()`
4. Redirects to `/onboarding` or `/dashboard`

#### `src/routes/onboarding/+page.svelte`

Username selection page:

- Real-time availability checking via `/api/users/check-username`
- Sets username via `PUT /api/users/username`
- Redirects to `/dashboard` on success

#### `src/routes/dashboard/+page.svelte`

Protected dashboard:

- Checks authentication on mount
- Redirects to `/` if not authenticated
- Redirects to `/onboarding` if username not set

## JWT Structure

The JWT contains:

```json
{
  "sub": "123", // User ID
  "iss": "backend", // Issuer
  "iat": 1701820000, // Issued at
  "exp": 1702424800 // Expires (7 days)
}
```

## Security Considerations

1. **JWT Storage**: Stored in `localStorage` - convenient but vulnerable to XSS. For higher security, consider HttpOnly cookies.

2. **Token Expiration**: JWTs expire after 7 days. Consider implementing refresh tokens for better UX.

3. **CORS**: Backend allows requests from `http://localhost:3000` only.

4. **CSRF**: Ueberauth uses state parameter to prevent CSRF attacks during OAuth flow.

## Environment Variables

Backend `.env`:

```
GOOGLE_CLIENT_ID=your-client-id
GOOGLE_CLIENT_SECRET=your-client-secret
```

Get these from [Google Cloud Console](https://console.cloud.google.com/apis/credentials):

1. Create OAuth 2.0 Client ID
2. Set authorized redirect URI: `http://localhost:4000/api/auth/google/callback`
