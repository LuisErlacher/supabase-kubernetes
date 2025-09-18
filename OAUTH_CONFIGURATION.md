# OAuth and SSO Configuration for Supabase Self-Hosted on Kubernetes

## Important: Self-Hosted Limitations

In Supabase self-hosted deployments, many features available in the cloud version must be configured via environment variables rather than through the Studio dashboard UI. This includes:

- **OAuth/SSO providers** (Google, GitHub, etc.)
- **Connection pooling settings**
- **Email templates**
- **Advanced auth settings**
- **Vault integrations**

## OAuth Provider Configuration

### Step 1: Edit values.yaml

Add OAuth provider configuration to the `auth.environment` section in `charts/supabase/values.yaml`:

```yaml
auth:
  environment:
    # Existing config...

    # Google OAuth
    GOTRUE_EXTERNAL_GOOGLE_ENABLED: "true"
    GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID: "your-google-client-id.apps.googleusercontent.com"
    GOTRUE_EXTERNAL_GOOGLE_SECRET: "your-google-secret"
    GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI: "https://your-domain.com/auth/v1/callback"

    # GitHub OAuth
    GOTRUE_EXTERNAL_GITHUB_ENABLED: "true"
    GOTRUE_EXTERNAL_GITHUB_CLIENT_ID: "your-github-client-id"
    GOTRUE_EXTERNAL_GITHUB_SECRET: "your-github-secret"
    GOTRUE_EXTERNAL_GITHUB_REDIRECT_URI: "https://your-domain.com/auth/v1/callback"
```

### Step 2: Create OAuth Apps

#### Google OAuth Setup
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable Google+ API
4. Create OAuth 2.0 credentials
5. Add authorized redirect URIs:
   - `https://your-domain.com/auth/v1/callback`
   - `http://localhost:3000/auth/v1/callback` (for development)

#### GitHub OAuth Setup
1. Go to GitHub Settings > Developer settings > OAuth Apps
2. Create a new OAuth App
3. Set Authorization callback URL: `https://your-domain.com/auth/v1/callback`

### Step 3: Using Secrets (Recommended)

Instead of hardcoding credentials, use Kubernetes secrets:

```yaml
# Create secret
kubectl create secret generic oauth-credentials \
  --from-literal=google-client-id=your-google-client-id \
  --from-literal=google-secret=your-google-secret \
  --from-literal=github-client-id=your-github-client-id \
  --from-literal=github-secret=your-github-secret

# Reference in values.yaml
auth:
  envFrom:
    - secretRef:
        name: oauth-credentials
```

### Step 4: Deploy Changes

```bash
helm upgrade <release-name> -f charts/supabase/values.yaml charts/supabase/
```

## Available OAuth Providers

The following providers can be configured using the same pattern:

- **Apple**: `GOTRUE_EXTERNAL_APPLE_*`
- **Azure**: `GOTRUE_EXTERNAL_AZURE_*`
- **Bitbucket**: `GOTRUE_EXTERNAL_BITBUCKET_*`
- **Discord**: `GOTRUE_EXTERNAL_DISCORD_*`
- **Facebook**: `GOTRUE_EXTERNAL_FACEBOOK_*`
- **Figma**: `GOTRUE_EXTERNAL_FIGMA_*`
- **GitLab**: `GOTRUE_EXTERNAL_GITLAB_*`
- **Kakao**: `GOTRUE_EXTERNAL_KAKAO_*`
- **Keycloak**: `GOTRUE_EXTERNAL_KEYCLOAK_*`
- **LinkedIn**: `GOTRUE_EXTERNAL_LINKEDIN_*`
- **Notion**: `GOTRUE_EXTERNAL_NOTION_*`
- **Slack**: `GOTRUE_EXTERNAL_SLACK_*`
- **Spotify**: `GOTRUE_EXTERNAL_SPOTIFY_*`
- **Twitch**: `GOTRUE_EXTERNAL_TWITCH_*`
- **Twitter**: `GOTRUE_EXTERNAL_TWITTER_*`
- **WorkOS**: `GOTRUE_EXTERNAL_WORKOS_*`
- **Zoom**: `GOTRUE_EXTERNAL_ZOOM_*`

## Connection Pooling

PgBouncer is pre-configured but connection pooling settings must be adjusted via environment variables or database configuration, not through the dashboard.

## Email Templates

Custom email templates must be configured via environment variables:

```yaml
auth:
  environment:
    GOTRUE_MAILER_SUBJECTS_CONFIRMATION: "Confirm your email"
    GOTRUE_MAILER_SUBJECTS_RECOVERY: "Reset your password"
    GOTRUE_MAILER_SUBJECTS_INVITE: "You have been invited"
```

## Verification

After deployment, verify OAuth is working:

1. Check auth service logs:
```bash
kubectl logs -l app.kubernetes.io/name=supabase-auth
```

2. Test OAuth flow in your application
3. Check that providers appear in the auth endpoints

## Troubleshooting

1. **Providers not showing**: Ensure environment variables are set correctly
2. **Callback errors**: Verify redirect URIs match exactly
3. **Secret not found**: Check secret is created in the same namespace
4. **Connection refused**: Ensure auth service is running and healthy

## Note on Self-Hosted vs Cloud

Unlike Supabase Cloud, self-hosted deployments:
- Cannot configure OAuth through the Studio dashboard
- Must restart services after configuration changes
- Don't have automatic SSL/TLS (must be configured separately)
- Require manual management of redirect URIs