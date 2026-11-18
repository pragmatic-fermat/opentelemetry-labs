# Conventions des labs

Ce document s'adresse aux auteurs des TP. Il fixe l'environnement cible, le format des TP et les règles de rédaction. Chaque TP est écrit dans son propre dossier `tpNN-*/` sans toucher aux autres.

## Public et durée

- Public : ingénieurs et exploitants avec des bases Linux, Docker et YAML. OpenTelemetry est découvert pendant la formation.
- Durée : 1/4 de journée par TP, soit environ 2 heures de manipulation. Le sujet doit tenir dans ce temps, avec des étapes courtes et vérifiables. Mieux vaut un TP resserré qu'un TP trop ambitieux.
- Un participant par environnement. Le numéro 0 est celui du formateur.

## Environnement cible

Chaque participant N (0 pour le formateur) dispose de trois machines. L'infrastructure est décrite dans `infra/` (construite en parallèle de la rédaction des TP : les TP s'appuient sur les hypothèses ci-dessous, pas sur le code de `infra/`).

| Machine | Rôle | Contenu préinstallé |
|---|---|---|
| `clt-N` | Poste de travail principal | Ubuntu 24.04, Docker et Docker Compose, Ansible, git, jq, yq, curl |
| `srv-N` | Serveur Linux cible | Ubuntu 24.04 minimal, sans Docker, Python 3, curl, git. Cible des déploiements Ansible et des auto-instrumentations sur hôte |
| `k8s-N` | Cluster Kubernetes | Docker, KinD (cluster à un nœud control-plane et un worker), kubectl, helm, ingress-nginx |

Règles communes :

- Accès par terminal web (code-server, VS Code dans le navigateur) sur `https://clt-N.<domaine>`, `https://srv-N.<domaine>` et `https://k8s-N.<domaine>`. Les participants n'utilisent pas SSH depuis leur poste.
- Utilisateur `stagiaire`, sudo sans mot de passe. Le repo des labs est cloné dans `~/opentelemetry-labs`.
- Depuis `clt-N`, la clé SSH de l'utilisateur `stagiaire` permet de se connecter à `srv-N` sans mot de passe.
- Variables d'environnement disponibles dans tous les terminaux : `LAB_ID` (le numéro N), `LAB_DOMAIN`, `CLT_HOST`, `SRV_HOST`, `K8S_HOST` (noms DNS complets des trois machines). Sur `k8s-N`, `INGRESS_HOST` vaut `<ip-avec-tirets>.sslip.io`, un nom qui pointe vers la VM.
- Les ports 80 et 443 de chaque VM sont réservés au terminal web (Caddy). Les applications des TP utilisent d'autres ports.
- Ports ouverts depuis Internet vers les VM, à utiliser pour les interfaces web des TP : 3000 (Grafana), 8080 (application), 9090 (Prometheus), 16686 (Jaeger), 4317 et 4318 (OTLP), 8888 (métriques internes du Collector). Sur `k8s-N`, l'ingress du cluster est exposé sur les ports 8080 (HTTP) et 8443 (HTTPS).
- Un TP doit fonctionner sur n'importe quelle machine Ubuntu 24.04 équipée des outils indiqués, sans dépendre d'un fournisseur cloud particulier.

## Dépendances et versions

- Épingler toutes les versions d'images, de charts Helm, de paquets et de binaires. Vérifier la dernière version stable réelle (API GitHub, releases, registre) au moment de la rédaction, ne jamais l'écrire de mémoire. Noter la date de vérification dans le README du TP.
- Collector : distribution `otelcol-contrib` sauf mention contraire.
- Ne pas copier de code applicatif tiers dans ce repo. Pour une application d'exemple existante, la cloner à l'exécution depuis son dépôt, à un commit ou une étiquette précis, et écrire le commit dans le TP. Sources de référence possibles :
  - `https://github.com/pragmatic-fermat/observabilite_des_applications` : labs précédents de la formation (format, configurations, images). Bon point de départ pour reprendre des idées, à moderniser.
  - `https://github.com/pragmatic-fermat/grafanacon2026-opentelemetry-instrumentation` : application Tapas Finder (backend Go, frontend Node.js, Postgres, k6, mode chaos) et exercices au format détaillé (blocs `diff`, sections de vérification). Licence Apache 2.0.
- Les applications écrites spécifiquement pour un TP (petites, quelques dizaines de lignes) peuvent être versionnées dans le dossier du TP.

## Structure d'un TP

```text
tpNN-slug/
  README.md        énoncé destiné aux participants
  files/           fichiers de départ fournis (compose, configs, squelettes)
  solution/        corrigé : README.md (explications) et fichiers corrigés
  formateur.md     notes pour le formateur (optionnel : clés de correction, pièges, minutage)
```

Le `README.md` de l'énoncé contient, dans cet ordre :

1. Titre, durée, machine(s) utilisée(s).
2. Objectifs (3 à 5 puces mesurables).
3. Prérequis (TP précédents éventuels, outils).
4. Parties numérotées, chacune avec des étapes courtes. Chaque partie se termine par un bloc **Vérifier** qui donne un résultat observable (commande et sortie attendue, ou capture décrite).
5. Dépannage : les trois ou quatre erreurs les plus probables et leur correction.
6. Pour aller plus loin (facultatif, court).

Le corrigé ne doit pas être lisible depuis l'énoncé : l'énoncé guide sans donner la solution complète des étapes de réflexion, il fournit les commandes pour les étapes d'installation et laisse les participants écrire les configurations clés. Les fichiers de départ dans `files/` doivent permettre de démarrer sans friction.

## Règles de rédaction

- Langue : français.
- Pas d'emojis, d'émoticônes ni de logos.
- Pas de tiret quadratique. Utiliser les deux-points, la virgule, les parenthèses ou le tiret simple.
- Pas de syntaxe de slogan : pas de formules chocs, d'accroches publicitaires ou de phrases nominales percutantes en guise de titres ou de conclusions.
- Adresser les participants avec des verbes à l'impératif ou avec « vous ». Pas de « je » dans les énoncés.
- Blocs de code avec indication de langage (`bash`, `yaml`, `json`, `diff`...). Les commandes à copier-coller doivent fonctionner telles quelles, avec les variables d'environnement de l'environnement cible.
- Termes techniques OpenTelemetry (span, trace, collector, receiver, processor, exporter, pipeline) conservés en anglais.

## Qualité et validation

- Tester tout ce qui peut l'être dans l'environnement de rédaction : `docker compose config`, démarrage réel des stacks si le démon Docker est disponible, validation des configurations du Collector (`otelcol-contrib validate --config=...`), `helm template`, `ansible-playbook --syntax-check`, `kubectl apply --dry-run=client`, exécution des scripts et applications d'exemple.
- Consigner clairement ce qui a été testé et ce qui ne l'a pas été (par exemple parce que cela exige un vrai cluster ou la VM cible) dans le texte de la PR.
- Markdown propre : titres hiérarchisés, listes homogènes, blocs de code balisés, pas de ligne vide multiple.

## Workflow Git

- Un auteur par TP, une branche par TP (`tpNN-slug`), créée depuis `main`.
- Ne modifier que le dossier du TP. Ne pas toucher au README racine, à `infra/`, à `CONVENTIONS.md` ni aux autres TP. Si un besoin transverse apparaît, le signaler dans la PR.
- Messages de commit et titres de PR en français, sans emoji.
- Une fois la rédaction initiale terminée : pousser la branche et ouvrir une pull request vers `main`. Ne jamais fusionner. La revue GitHub Copilot démarre à l'ouverture de la PR.
- Le texte de la PR contient : le résumé du TP, le contenu du dossier, ce qui a été testé et comment, ce qui n'a pas pu l'être, les décisions de conception et les points qui méritent l'attention du relecteur.
