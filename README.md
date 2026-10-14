# Salah

## RDP workflow

`.github/workflows/main.yml` contains a manually triggered Windows RDP workflow. It is not a permanent cloud PC or a guarantee of free hosting. Use GitHub-hosted runners only as permitted by GitHub's current Actions terms and your account's usage limits; a personal cloud desktop should use your own VM instead.

### Configuration

In repository **Settings → Secrets and variables → Actions**, create:

- `TAILSCALE_AUTH_KEY`: a short-lived, preferably ephemeral Tailscale authentication key. Never commit the key to a file.
- `RDP_PASSWORD`: a unique password of at least 16 characters, with uppercase, lowercase, numbers, and symbols. Do not share it in chat or workflow logs.

The root file named `TAILSCALE_AUTH_KEY` is not a GitHub Actions secret. GitHub only supplies secrets configured in repository settings.

For an authorized workflow run, connect your client to the same Tailscale network. Configure tailnet access rules so only your client can reach the runner on TCP port 3389. Start **Actions → RDP → Run workflow** using the branch containing the workflow. The connection step prints the private Tailscale IP; use it in your Remote Desktop client with username `RDP` (or `.\RDP`) and the password you saved. The account is not an administrator.

Network Level Authentication and TLS remain enabled. The added firewall rule allows Tailscale IPv4 peers, not the whole internet. Other existing firewall rules can also grant access, so this rule alone is not an isolation guarantee.

The job timeout is **360 minutes including installation and setup**, not six hours of guaranteed connected time. Cancel using **Cancel workflow run**. Runner availability and account limits may end the session earlier. Files on a hosted runner are temporary; save needed work before cancellation. An IP and password only become usable after a successful run.

### Validation

The workflow needs a Windows runner, available GitHub Actions secrets, and access to Tailscale to test end to end. Editing or parsing its YAML does not verify that RDP connections work.
