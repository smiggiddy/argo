# Smig.Tech HomeLab - GitOps with ArgoCD

A comprehensive Kubernetes homelab deployment using GitOps principles with ArgoCD. This repository manages the deployment of various self-hosted applications through Helm charts and ArgoCD automation.

## 🏠 Overview

This homelab setup provides a complete self-hosted infrastructure including:
- **Identity & Authentication**: Authentik SSO
- **Storage**: Longhorn distributed storage
- **Monitoring**: Prometheus, Grafana, Loki stack
- **Productivity**: Nextcloud, Mattermost, GitLab
- **Home Automation**: Home Assistant
- **Development**: Code Server, LocalStack
- **Utilities**: Homer dashboard, Linkding bookmarks, Uptime Kuma, Hashicorp Vault

## 🏗️ Architecture

### GitOps Pattern
- **ArgoCD** monitors this Git repository and automatically syncs changes to the Kubernetes cluster
- Each application is defined as an ArgoCD Application resource in `/apps/templates/`
- Application configurations are stored as Helm charts with upstream dependencies

### Key Components

1. **Main Apps Chart** (`/apps/`)
   - Orchestrates all applications as ArgoCD Application resources
   - Uses Helm templating to generate ArgoCD Application manifests
   - Global values in `values.yaml` control cluster-wide settings

2. **Application Templates** (`/apps/templates/`)
   - ArgoCD Application manifests for each service
   - Configured with upstream Helm repositories and custom values
   - Includes notifications, health checks, and sync policies

3. **Kustomizations** (`/kustomizations/`)
   - Kubernetes resource customizations for specific applications
   - Used for complex configurations requiring custom manifests

4. **Automated Updates**
   - **Renovate Bot**: Automatically creates PRs for dependency updates
   - **K3s Updates**: System components updated via Rancher's system-upgrade-controller
   - **Custom Regex Managers**: Track versions for various components

## 📁 Repository Structure

```
├── apps/                          # Main Helm chart orchestrating all applications
│   ├── Chart.yaml                 # Main chart definition
│   ├── values.yaml                # Global cluster settings
│   └── templates/                 # ArgoCD Application manifests
│       ├── nextcloud.yaml
│       ├── home-assistant.yaml
│       ├── authentik.yaml
│       └── ...
├── kustomizations/                # Custom Kubernetes resources
│   ├── home-assistant/
│   ├── rabbitmq-operator/
│   └── ...
├── auto_upgrades/                # K3s system upgrade configurations
└── renovate.json                 # Automated dependency updates
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Maintainer

- **@Smiggiddy** - https://smig.tech

---

**Note**: This is a personal homelab configuration. Adjust values and configurations according to your specific requirements and environment.
