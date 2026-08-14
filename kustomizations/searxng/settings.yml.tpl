# Vault Agent template -> rendered to /vault/secrets/settings.yml at pod start.
# Carries only deviations; the rest comes from the image via use_default_settings.
# No literal double-braces anywhere (including comments) - fatal parse error.

use_default_settings:
  engines:
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
      - yahoo
      - yep
      - presearch
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
  safe_search: 0
  autocomplete: "duckduckgo"
  autocomplete_min: 4
  default_lang: "auto"
  formats:
    - html
    - json   # required by Vane + hermes
  ban_time_on_fail: 5
  max_ban_time_on_fail: 120
  suspended_times:
    SearxEngineAccessDenied: 3600
    SearxEngineCaptcha: 1800
    SearxEngineTooManyRequests: 900
    cf_SearxEngineCaptcha: 3600
    cf_SearxEngineAccessDenied: 3600
    recaptcha_SearxEngineCaptcha: 3600

server:
  secret_key: "{{ with secret "k8s/data/argocd/searxng" }}{{ .Data.data.searxng_secret }}{{ end }}"
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

outgoing:
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

  - name: duckduckgo
    weight: 2

  - name: brave
    max_connections: 2
    max_keepalive_connections: 1

  - name: crossref
    disabled: false
    timeout: 6.0
  - name: gentoo
    timeout: 6
  - name: wolframalpha
    disabled: false
    timeout: 6.0

  - name: piped
    inactive: false
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

  - name: yahoo news
    inactive: false
  - name: piped.music
    inactive: false
    frontend_url: https://srv.piped.video

  # opt-in only; request it by NAME (engines=braveapi), not shortcut brapi
  - name: braveapi
    inactive: false
    disabled: true
    api_key: "{{ with secret "k8s/data/argocd/searxng" }}{{ .Data.data.brave_api_key }}{{ end }}"
    results_per_page: 20
  - name: qwant
    disabled: true
  - name: wikinews
    disabled: true
  - name: wikicommons.audio
    disabled: true
