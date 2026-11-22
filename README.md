# Labs OpenTelemetry

Labs OpenTelemetry, du socle Collector jusqu'au diagnostic d'incident.

## Programme

Labs retenus pour la version finale : 1, 3, 4, 5, 6, 7, 10 et 11 (numérotation d'origine conservée). Les TP 1, 3, 4, 5, 6 et 7 sont détaillés ; les TP 10 et 11 seront finalisés.

| TP | Titre | Contenu |
|---|---|---|
| [TP1](Lab_TP01_Socle.md) | Socle (1A, 1B, 1C) | Backend Jaeger, premier **collector**, processors (batch, filtrage, OTTL) |
| [TP3](Lab_TP03_Kubernetes.md) | Kubernetes | **collector** en **agent** et **gateway** (Helm), **operator** OTel et auto-instrumentation par annotation |
| [TP4](Lab_TP04_Ansible_Jinja2.md) | Ansible + Jinja2 | Déploiement du **collector** sur VM Linux, puis modification de la configuration |
| [TP5](tp05-nodejs-nginx/) | Node.js + Nginx | Auto-instrumentation, export OTLP vers Jaeger, trace de bout en bout |
| [TP6](tp06-java-python-dotnet/) | Java, Python et .NET | Auto-instrumentation sur Linux |
| [TP7](Lab_TP07_Instrumentation_Manuelle.md) | Instrumentation manuelle | Spans et attributs custom, propagation, corrélation logs/traces |
| [TP10](tp10-exploitation/) | Exploitation | Supervision du **collector**, dépannage de pipeline, export OTLP vers le backend du client |
| [TP11](tp11-diagnostic-incident/) | Diagnostic d'incident | OpenTelemetry Demo (feature flags) |
