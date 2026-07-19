# Hermes Config Notes

Findings from debugging the hermes-agent deployment (2026-07-10).

## Per-profile credential scoping (2026-07-19) — SUPERSEDES parts of the multiplex notes below

Post-v0.18.2 main builds completed the per-profile credential model (upstream
#64674 + multiplexing workstream). Under `multiplex_profiles: true`:

- Each profile's adapters start inside a secret scope built **only from that
  profile's `.env`** — `/opt/data/.env` for default,
  `/opt/data/profiles/family/.env` for family. `get_secret` does NOT fall back
  to `os.environ` when a scope is active (and fails closed if no scope is
  installed while multiplexing) — process env may hold another profile's value.
- Consequence: pod-env platform tokens (secretRef) are invisible to adapter
  startup. Telegram died after the update because `TELEGRAM_BOT_TOKEN` existed
  only in process env; it must live in `/opt/data/.env` (managed manually).
- This obsoletes the old "detection always reads os.environ / a profile's .env
  cannot enable a platform" findings below: plugin check_fns now accept
  `config.token` (populated from the scoped profile `.env`), and authz
  allowlists resolve per profile. Cross-profile same-token collisions are
  detected and refused at startup.
- Cred placement is managed **manually** on the PVC (deliberate choice, no
  init-container seeding): telegram creds in `/opt/data/.env`, mattermost creds
  in `profiles/family/.env` (removable from `/opt/data/.env`).

## model_aliases → model.aliases (2026-07-19)

The post-0.18.2 config validator warns on unknown top-level keys.
`model_aliases:` (dict form) is still read but flagged; replaced in the managed
config with `model.aliases` (string form, `"provider/model"`). String aliases
carry no base_url — resolution falls through to the provider path: named
`providers:` entries supply their own base_url (qwen-small), lmstudio resolves
via `LM_BASE_URL` env. Verified in hermes_cli/model_switch.py at upstream main.

## Image policy (2026-07-19)

Staying on digest-pinned `latest` (main builds) deliberately: the v2026.7.7.2
release predates the completed per-profile credential model (its mattermost
check_fn is still env-only), so the clean layout doesn't work there.
Re-evaluate pinning to release tags at v0.19.

## Config layout

- `/etc/hermes/config.yaml` — the "managed scope" config, mounted read-only from
  the `hermes-config-file` ConfigMap (source: `hermes-config.yaml` in this dir).
  Hermes treats `/etc/hermes` as an admin-managed overlay and merges it with its
  own state config at load.
- `/opt/data/config.yaml` — hermes' runtime state config on the PVC. Managed by
  hermes itself; expected to differ from the managed file (e.g. model settings
  live only in the managed file).
- `/opt/data/.env` — where interactive commands like `/sethome` persist settings.
  Loaded into the process environment **only at gateway startup**.
- Caution: dropping a `.env` into `/etc/hermes` makes those keys admin-locked —
  `/sethome`-style commands will refuse to change them.

## Telegram home channel nag

The "📬 No home channel is set for Telegram" prompt fires on every fresh session
(`/new`, `/clear`) when `os.getenv("TELEGRAM_HOME_CHANNEL")` is empty.

`/sethome` **does** persist correctly (writes `TELEGRAM_HOME_CHANNEL=<chat_id>` to
`/opt/data/.env` and updates the in-memory config), but it never updates
`os.environ` — so the nag keeps firing until the gateway restarts and reloads
`.env`. Upstream bug in the same family as NousResearch/hermes-agent#9220.

Fixes:
- Immediate: restart the pod (`kubectl rollout restart -n ai deploy/hermes-agent`).
- Durable/declarative: set `TELEGRAM_HOME_CHANNEL` in `secret.yaml` (same value as
  `TELEGRAM_ALLOWED_USERS` — a personal DM chat ID equals the Telegram user ID).
  Survives a PVC wipe.

## Model picker only shows some providers

The `/model` picker builds its provider list from **credentials detected in
environment variables**, not from `model:` / `model_aliases:` in config.yaml:

- **LM Studio** needs `LM_API_KEY` (any non-empty value — LM Studio ignores it)
  to pass the credential gate, and `LM_BASE_URL` to point discovery at the right
  host. Without these it doesn't get a row even when it's the current provider.
  → Both set in `configmap.yaml`.
- **Custom OpenAI-compatible endpoints** (e.g. qwen on smig-inference) need a
  `providers:` entry in the managed config to appear as a picker row.
  `model_aliases:` entries are only `/model <alias>` shortcuts — they don't
  register an endpoint. `discover_models: true` live-fetches `/v1/models`.
  → `qwen-small` registered in `hermes-config.yaml`.
- **Ollama Cloud (43 models)** appears because the Vault secret
  (`k8s/data/argocd/hermes`) sets `OLLAMA_API_KEY=none` — any non-empty string
  counts as configured. Delete the key from Vault to drop the row.

## Auxiliary model overrides need `provider: custom`

`auxiliary.<task>.base_url` alone is **ignored** — `_resolve_task_provider_model()`
only honors a config-file base_url when `api_key` is also set or `provider` is
explicitly non-auto. A bare `base_url` + `model` falls through to auto, which
targets the **main provider with the overridden model name** → LM Studio 400
`model_not_found` for `qwen3-8b`. This gate is deliberate: upstream #16829
(bare base_url hijacked the custom path with an empty key → 401s) was fixed by
PR #20215, which requires the api_key-or-provider signal. Fix: set
`provider: "custom"` alongside `base_url` (local servers then get a
`no-key-required` placeholder key automatically).

## Multiplexed profiles (2026-07-11)

`multiplex_profiles: true` (**top-level**, not under `gateway:`) — one gateway
process serves all profiles. Default profile = telegram, `family` profile
(home: `/opt/data/profiles/family/`, created with `hermes profile create
family`) = mattermost.

- Flag gotcha: the docs say `gateway.multiplex_profiles`, but
  `load_gateway_config()` (gateway/config.py ~864) only copies the **top-level**
  key from config.yaml; from the nested `gateway:` section it extracts only
  `max_concurrent_sessions` and `streaming`. The nested-form fallback in
  `from_dict` only ever sees legacy `gateway.json`. Nested form = silently off:
  "running with 1 platform(s)", family stays "registered" but unserved.

### How secondary-profile platforms actually resolve (this build)

Platform **detection** always reads `os.environ` (`os.getenv` in
`_apply_env_overrides` and each plugin's `check_fn`) — a profile's own `.env`
is **never** consulted for it (`_profile_runtime_scope` loads profile `.env`
into an isolated `get_secret` scope only, by design, to avoid cross-profile
secret leaks). Two consequences:

1. **Process env leaks into every profile.** With `TELEGRAM_BOT_TOKEN` in the
   pod env, the family profile also enabled telegram with the *same* token —
   the duplicate-credential fingerprint failed for the telegram plugin adapter,
   both polled, and getUpdates conflict-looped. Fix: explicit
   `platforms.telegram.enabled: false` in the family profile's config.yaml
   (`_enabled_explicit` survives env re-enable, upstream #41112).
2. **A profile's `.env` cannot enable a platform.** Mattermost only came up
   with (a) `MATTERMOST_TOKEN` + `MATTERMOST_URL` in the **process env** —
   they live in `/opt/data/.env`, which the gateway loads into `os.environ` at
   startup — so `check_mattermost_requirements()` passes at adapter creation
   ("requirements not met (pip install aiohttp)" is this check failing, not a
   dependency problem), and (b) the platform explicitly configured in the
   family profile's config.yaml (the adapter reads `config.token` /
   `extra["url"]`).
3. **The enforced allowlist is env-only.** `_is_user_authorized`
   (authz_mixin) reads `MATTERMOST_ALLOWED_USERS` from `os.getenv` via the
   plugin registry. Config `allow_from` is honored only for adapters that
   gate at intake with an "allowlist" policy — the mattermost adapter has no
   such gating, so `allow_from` in the profile config.yaml is decorative.
   The allowlist must be in the process env (`/opt/data/.env`). Only family
   runs a mattermost adapter, so the process-wide list effectively scopes
   to it.

Working layout:

- `/opt/data/.env` — `MATTERMOST_TOKEN`, `MATTERMOST_URL`,
  `MATTERMOST_ALLOWED_USERS` (family user IDs + smig; process-env gate).
- `/opt/data/config.yaml` — `platforms.mattermost.enabled: false` (set via
  `hermes config set`) so the default profile doesn't claim the token first.
- `/opt/data/profiles/family/config.yaml` — telegram disabled; mattermost
  enabled with `token`, `extra.url`, `extra.reply_mode`; and the tool
  lockdown:
  `platform_toolsets: mattermost: ["safe", "memory", "session_search",
  "todo", "clarify", "tts"]`. The default `hermes-mattermost` toolset
  includes terminal / file / execute_code / browser, and profiles do NOT
  sandbox the filesystem — the pod shares one uid and all of `/opt/data`,
  so those tools can read the default profile's `.env`, sessions, and
  memories (observed: family agent ran `find /opt/data`). `safe` resolves to
  web_search/web_extract/vision_analyze/image_generate; memory and
  session_search are profile-scoped via the multiplexer home override.
  `cronjob` deliberately excluded — cron turns default to a terminal-bearing
  toolset. This is tool-registry policy, not a sandbox; real isolation
  needs a separate pod or upstream per-profile fs/env scoping.
- `/opt/data/profiles/family/.env` — same MATTERMOST_* vars for turn-time
  `get_secret`.
- Per-profile enable/disable must live in **per-profile** config.yaml — the
  managed `/etc/hermes/config.yaml` overlays ALL profiles, so a disable there
  would kill the family adapter too.
- Port-binding platforms (webhook/API/SMS) are default-profile-only under
  multiplexing; mattermost connects outbound (REST v4 + websocket), so it's
  fine on a secondary profile.
- s6 note: `reconcile: profile=family action=registered` (not started) is
  correct under multiplexing — the default gateway serves it.
- TODO: declarative pass — MATTERMOST_URL → configmap.yaml, MATTERMOST_TOKEN →
  secret.yaml (Vault), and init-container seeding of the family profile files
  so a PVC wipe is a non-event.

## Deployment behavior

- The kustomize `configMapGenerator` hash suffix means any config change rolls
  the pod on ArgoCD sync — which also reloads `/opt/data/.env`.
- Init container freezes bundled skills via `/opt/data/.no-bundled-skills`.
