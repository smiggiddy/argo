{{/*
Mattermost notification annotations.
Usage: {{ include "app.notifications" . | nindent 4 }}
*/}}
{{- define "app.notifications" -}}
notifications.argoproj.io/subscribe.on-sync-failed.mattermost: {{ .Values.mattermost.webhookId }}
notifications.argoproj.io/subscribe.on-health-degraded.mattermost: {{ .Values.mattermost.webhookId }}
notifications.argoproj.io/subscribe.on-sync-status-unknown.mattermost: {{ .Values.mattermost.webhookId }}
{{- end }}

{{/*
Standard automated sync policy with prune, selfHeal, CreateNamespace,
ApplyOutOfSyncOnly, and ServerSideApply.
Usage: {{ include "app.syncPolicy.automated" . | nindent 2 }}
*/}}
{{- define "app.syncPolicy.automated" -}}
syncPolicy:
  syncOptions:
    - CreateNamespace=true
    - ApplyOutOfSyncOnly=true
    - ServerSideApply=true
  automated:
    prune: true
    selfHeal: true
{{- end }}

{{/*
Manual sync policy (no automated block).
Usage: {{ include "app.syncPolicy.manual" . | nindent 2 }}
*/}}
{{- define "app.syncPolicy.manual" -}}
syncPolicy:
  syncOptions:
    - CreateNamespace=true
    - ApplyOutOfSyncOnly=true
    - ServerSideApply=true
{{- end }}
