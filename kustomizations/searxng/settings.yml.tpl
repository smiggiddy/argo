# SearXNG instance settings — a Vault Agent template, NOT a plain settings file.
#
# Shipped to the pod in a ConfigMap, then rendered by the Vault Agent init
# container to /vault/secrets/settings.yml with its template actions resolved.
# SEARXNG_SETTINGS_PATH points SearXNG at the rendered copy.
#
# Secrets live only in Vault at k8s/data/argocd/searxng — never in a Secret,
# a ConfigMap, or git. Only the two `secret` lookups below are template actions;
# nothing else in this file uses braces, so the renderer touches nothing else.
# Do not write literal double-braces anywhere here, including in comments — the
# renderer parses the whole file and an empty action is a fatal parse error.
#
# This file only carries DEVIATIONS from the engine/settings definitions shipped
# in the image. Everything else (all ~281 engine definitions, plugin defaults,
# doi resolvers, category tabs, UI defaults) is inherited via use_default_settings.
#
# Consequence: engine definitions track the image. When renovate bumps the tag,
# upstream engine fixes come along for free instead of rotting in a pinned copy.

use_default_settings:
  engines:
    # Curated instance: any engine not listed here is dropped entirely.
    keep_only:
      # --- general web ---
      - duckduckgo
      - google
      - bing
      - brave
      - braveapi
      - startpage
      - mojeek
      - qwant
      - wikidata
      - wikipedia
      # independent fallbacks — no captcha/ratelimit exposure, added to keep
      # the general category alive when the scrapers get suspended
      - yahoo
      - yep
      - presearch
      - marginalia
      # --- images ---
      - google images
      - bing images
      - brave.images
      - startpage images
      - duckduckgo images
      - openverse
      - unsplash
      - flickr
      - deviantart
      - pinterest
      - artic
      - public domain image archive
      - wikicommons.images
      # --- videos ---
      - youtube
      - google videos
      - bing videos
      - brave.videos
      - duckduckgo videos
      - dailymotion
      - vimeo
      - piped
      - sepiasearch
      - wikicommons.videos
      # --- news ---
      - google news
      - bing news
      - brave.news
      - startpage news
      - duckduckgo news
      - yahoo news
      - mojeek news
      - reuters
      - wikinews
      # --- music ---
      - bandcamp
      - soundcloud
      - mixcloud
      - genius
      - piped.music
      - radio browser
      - wikicommons.audio
      # --- it / code / q&a ---
      - github
      - stackoverflow
      - askubuntu
      - superuser
      - hackernews
      - reddit
      - mdn
      - docker hub
      - arch linux wiki
      - nixos wiki
      - gentoo
      - huggingface
      - pypi
      - npm
      - crates.io
      - pkg.go.dev
      - hoogle
      - mankier
      # --- science ---
      - arxiv
      - pubmed
      - google scholar
      - crossref
      - semantic scholar
      - pdbe
      - openairepublications
      # --- wikis ---
      - wikibooks
      - wikiquote
      - wikisource
      - wikiversity
      - wikivoyage
      - wikicommons.files
      # --- maps ---
      - openstreetmap
      - photon
      # --- social ---
      - mastodon users
      - mastodon hashtags
      - lemmy communities
      - lemmy users
      - lemmy posts
      - lemmy comments
      - tootfinder
      # --- reference / tools ---
      - wiktionary
      - etymonline
      - dictzone
      - wordnik
      - mymemory translated
      - lingva
      - wolframalpha
      - currency
      - wttr.in
      - bt4g

general:
  instance_name: "SearXNG"
  enable_metrics: true

search:
  # 0, not 1: this instance is an API backend for Vane. Safe-search filtering
  # trims recall before the LLM ever sees the results.
  safe_search: 0
  autocomplete: "duckduckgo"
  autocomplete_min: 4
  default_lang: "auto"
  # json is required by Vane; do not remove.
  formats:
    - html
    - json
  ban_time_on_fail: 5
  max_ban_time_on_fail: 120
  suspended_times:
    # Was 86400/1296000/604800. A day-long ban meant one captcha from Startpage
    # took it out until the next day; these retry within the hour instead.
    SearxEngineAccessDenied: 3600
    SearxEngineCaptcha: 1800
    SearxEngineTooManyRequests: 900
    cf_SearxEngineCaptcha: 3600
    cf_SearxEngineAccessDenied: 3600
    recaptcha_SearxEngineCaptcha: 3600

server:
  # Rendered from Vault by the agent init container.
  secret_key: "{{ with secret "k8s/data/argocd/searxng" }}{{ .Data.data.searxng_secret }}{{ end }}"
  #
  # port/bind_address are deliberately absent: the image's entrypoint launches
  # granian with GRANIAN_PORT/GRANIAN_HOST, so values here never take effect.
  limiter: false
  public_instance: false
  image_proxy: false
  http_protocol_version: "1.1"
  method: "POST"
  default_http_headers:
    X-Content-Type-Options: nosniff
    X-Download-Options: noopen
    X-Robots-Tag: noindex, nofollow
    Referrer-Policy: no-referrer

valkey:
  url: redis://searxng-redis:6379/0

outgoing:
  # Was 3.0/6.0, which silently truncated every engine configured above 3s and
  # dropped slow-but-good results before they could be returned.
  request_timeout: 6.0
  max_request_timeout: 15.0
  useragent_suffix: "(smig homelab; admin@smig.tech)"
  pool_connections: 100
  pool_maxsize: 20
  enable_http2: true

plugins:
  searx.plugins.calculator.SXNGPlugin:
    active: true
  searx.plugins.hash_plugin.SXNGPlugin:
    active: true
  searx.plugins.self_info.SXNGPlugin:
    active: true
  searx.plugins.unit_converter.SXNGPlugin:
    active: true
  searx.plugins.ahmia_filter.SXNGPlugin:
    active: true
  searx.plugins.hostnames.SXNGPlugin:
    active: true
  searx.plugins.oa_doi_rewrite.SXNGPlugin:
    active: false
  searx.plugins.tor_check.SXNGPlugin:
    active: false
  searx.plugins.tracker_url_remover.SXNGPlugin:
    active: true

# Per-engine deviations from the image defaults. Merged by engine name.
engines:

  # -- engines upstream ships disabled that this instance wants on --
  - name: bing
    disabled: false
  - name: mojeek
    disabled: false
    weight: 2
  - name: mojeek news
    disabled: false
  - name: hackernews
    disabled: false
  - name: reddit
    disabled: false
  - name: huggingface
    disabled: false
  - name: nixos wiki
    disabled: false
  - name: npm
    disabled: false
  - name: crates.io
    disabled: false
  - name: pkg.go.dev
    disabled: false
  - name: public domain image archive
    disabled: false
  - name: wikibooks
    disabled: false
  - name: wikiquote
    disabled: false
  - name: wikisource
    disabled: false
  - name: wikiversity
    disabled: false
  - name: wikivoyage
    disabled: false

  # -- independent fallbacks (all upstream-disabled by default) --
  - name: yahoo
    disabled: false
  - name: yep
    disabled: false
  - name: presearch
    disabled: false
  - name: marginalia
    disabled: false

  # -- ranking --
  # duckduckgo previously carried `enabled: false`, which is not a valid engine
  # key and was silently ignored. It stays ON deliberately: alongside bing it is
  # one of only two general engines currently returning results.
  - name: duckduckgo
    weight: 2

  # -- rate-limit mitigation: brave 429s under parallel fan-out --
  - name: brave
    max_connections: 2
    max_keepalive_connections: 1

  # -- timeouts: upstream ships crossref at 30s and gentoo at 10s, which would
  #    now be capped at max_request_timeout (15s) and stall science searches --
  - name: crossref
    disabled: false
    timeout: 6.0
  - name: gentoo
    timeout: 6
  - name: wolframalpha
    disabled: false
    timeout: 10.0

  # -- extra piped mirrors for resilience (upstream ships 2) --
  - name: piped
    backend_url:
      - https://pipedapi.adminforge.de
      - https://pipedapi.nosebs.ru
      - https://pipedapi.ducks.party
      - https://pipedapi.reallyaweso.me
      - https://api.piped.private.coffee
      - https://pipedapi.darkness.services

  - name: wikicommons.images
    number_of_results: 10
  - name: wikicommons.videos
    number_of_results: 10
  - name: wikicommons.files
    number_of_results: 10

  # -- kept available but off by default --
  # braveapi: the official Brave REST API — no captchas or 403s, unlike the
  # `brave` scraper above. Deliberately opt-in: flip disabled to false to spend
  # against the API quota. The key is rendered from Vault at pod start.
  - name: braveapi
    disabled: true
    api_key: "{{ with secret "k8s/data/argocd/searxng" }}{{ .Data.data.brave_api_key }}{{ end }}"
    results_per_page: 20
  # qwant: upstream-disabled, returns HTML/empty -> JSONDecodeError.
  - name: qwant
    disabled: true
  # wikidata: init crashes with "no such table: properties" on this image.
  # Try flipping to false after an image bump and check /stats/errors.
  - name: wikidata
    disabled: true
  # These two carried `disable: true` (typo, silently ignored) and were running
  # against intent. Now actually off.
  - name: wikinews
    disabled: true
  - name: wikicommons.audio
    disabled: true
