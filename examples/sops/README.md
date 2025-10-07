# SOPS Walkthrough Artifacts

This folder contains helper assets that demonstrate how we will manage encrypted configuration in this repository.

## Files

- `demo-secret.plain.yaml` – example Kubernetes secret manifest kept in plaintext for reference.
- `demo-secret.enc.yaml` – the SOPS-encrypted version of the same manifest. Creation rules live in the repo root `.sops.yaml`.
- `demo.agekey` – demo Age private key paired with the public recipient already registered in `.sops.yaml`. Use for local experiments only.

## Quick Start

```bash
# optional: install sops (macOS)
brew install sops

# decrypt the sample secret using the bundled Age key
SOPS_AGE_KEY_FILE=examples/sops/demo.agekey sops --decrypt \
  examples/sops/demo-secret.enc.yaml

# update the plaintext helper and re-encrypt it
cp examples/sops/demo-secret.plain.yaml \
   examples/sops/demo-secret.enc.yaml
SOPS_AGE_KEY_FILE=examples/sops/demo.agekey sops --encrypt --in-place \
   examples/sops/demo-secret.enc.yaml
```

## Production Usage Notes

- Generate your own Age key and keep the private half outside the repository (for example, `~/.config/sops/age/keys.txt`).
- Add new public recipients to `.sops.yaml` under the appropriate `creation_rules`.
- Run `scripts/rotate_secrets.sh` after changing recipients so existing files are re-wrapped for the new keys.
- Avoid committing plaintext assets beyond instructional templates like the one above.
