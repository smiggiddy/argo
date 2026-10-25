{{/*
Shared Application annotations.
Usage: {{ include "app.notifications" . | nindent 4 }}
*/}}
{{- define "app.notifications" -}}
notifications.argoproj.io/subscribe.on-sync-failed.mattermost: {{ .Values.mattermost.webhookId }}
notifications.argoproj.io/subscribe.on-health-degraded.mattermost: {{ .Values.mattermost.webhookId }}
notifications.argoproj.io/subscribe.on-sync-status-unknown.mattermost: {{ .Values.mattermost.webhookId }}
argocd.argoproj.io/compare-options: ServerSideDiff=true
{{- end }}

{{/*
GitHub commit status annotations. Only for Applications with a
github.com/smiggiddy/argo source, since statuses are posted to that repo.
Usage: {{ include "app.notifications.github" . | nindent 4 }}
*/}}
{{- define "app.notifications.github" -}}
notifications.argoproj.io/subscribe.on-sync-running-github.github: ""
notifications.argoproj.io/subscribe.on-deployed-github.github: ""
notifications.argoproj.io/subscribe.on-sync-failed-github.github: ""
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
