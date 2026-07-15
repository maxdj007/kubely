# Privacy Policy — Kubelly

**Last updated:** 2026-07-15

Kubelly ("the app") is a Kubernetes client published by Falqor Technologies. This policy
explains what the app does — and does not do — with your data.

## Summary

**Kubelly collects no data. It has no backend, no analytics, no crash reporting, and no
telemetry.** Nothing you enter or view in the app is ever sent to Falqor or any third
party. The app communicates only with the Kubernetes clusters you choose to connect to.

## Data we collect

**None.** We do not collect, store, transmit, sell, or share any personal or usage data.
Falqor operates no server that Kubelly talks to.

## Data stored on your device

The app stores the following **only on your device**, so it can function:

- **Cluster credentials (kubeconfigs, tokens, client certificates).** Stored encrypted in
  the iOS Keychain (and Android EncryptedSharedPreferences). They never leave your device
  except to authenticate directly with the cluster API server you connect to.
- **App preferences** (such as selected cluster and namespace).

You can remove all of this at any time by deleting a cluster in the app or uninstalling
the app.

## Network connections

Kubelly makes network requests **only to the Kubernetes API servers of the clusters you
add**. These connections go directly from your device to your cluster — there is no
intermediary or proxy operated by Falqor. TLS is verified against the certificate
authority in your kubeconfig.

When connecting to managed providers, the app talks directly to that provider's standard
endpoints on your behalf using credentials you supply:

- **AWS EKS:** AWS STS, to generate short-lived authentication tokens.
- **Google GKE:** Google OAuth, for the sign-in flow you initiate.

The app sends nothing to these providers beyond what is required to authenticate to your
own cluster.

## Camera

The app can scan a kubeconfig from a QR code. The camera is used **only** to read the QR
code on-device; no image or video data is stored or transmitted. If you decline camera
access, you can still add clusters by pasting text or choosing a file.

## Tracking

Kubelly does **not** track you across apps or websites and does not use any advertising or
analytics identifiers.

## Children's privacy

The app is rated 4+ and does not knowingly collect any information from anyone, including
children.

## Changes to this policy

If this policy changes, the "Last updated" date above will change and the revised policy
will be published at this location.

## Contact

Questions about this policy can be raised via the project's GitHub repository:
https://github.com/maxdj007/kubely
