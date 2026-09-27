# ansible-k8s-cks

Ansible provisioning for the **CKS practice cluster** running on Multipass VMs
(Mac / Apple Silicon). It reproduces the existing, hand-built setup: a kubeadm
cluster with one control plane (`cp1`) + one worker (`worker1`), Cilium as the CNI,
and the CKS toolset (Gatekeeper, Kyverno, ingress-nginx, NGINX Gateway Fabric,
Falco, kube-bench, gVisor).

## What it deploys

| Component | Version | Where |
|-----------|---------|-------|
| Kubernetes (kubeadm/kubelet/kubectl) | 1.35.6 | all nodes |
| containerd (Ubuntu pkg, SystemdCgroup) | 2.x | all nodes |
| Cilium (CNI, helm) | 1.20.1 | cluster |
| Hubble relay + UI | via Cilium | cluster |
| OPA Gatekeeper (helm) | 3.23.1 | cluster |
| Kyverno (helm) | 3.9.0 | cluster |
| ingress-nginx (helm, NodePort) | 4.15.1 | cluster |
| NGINX Gateway Fabric (helm/OCI, NodePort) | 2.6.7 | cluster |
| Falco (modern eBPF + custom rules) | apt | worker |
| kube-bench (CIS) | 0.16.0 | cp |
| gVisor / runsc | apt | worker |
| docker (snap), cilium-cli, conftest, sysdig, etcd-client | — | cp |

Pod CIDR `10.244.0.0/16`, service CIDR `10.96.0.0/12`. All binary downloads use `arm64`.

## Requirements (on the Mac)

- [Multipass](https://multipass.run/), `ansible`, `jq` (`brew install ansible multipass jq`)
- An SSH key pair (`ssh-keygen -t ed25519`) — the public key is injected into the
  VMs so Ansible can reach them.

```bash
make deps          # Ansible collections (kubernetes.core, community.general, ansible.posix)
```

## Fresh cluster from scratch

```bash
make up            # multipass launch cp1 + worker1 (injects your SSH public key)
make inventory     # writes inventory/hosts.yml with the assigned IPs
make ping          # connectivity check
make site          # full provisioning
```

Or in one go: `make all`.

> **IPs / subnet:** `make inventory` picks the first IPv4 address per VM by default.
> If your VMs sit on a specific Multipass subnet, force it with e.g.
> `MP_SUBNET=192.168.252. make inventory`.

## Networking (important)

Multipass gives each VM several interfaces. Only the **primary** network
(`bridge100`, `192.168.252.x`) is reachable from the Mac host — so Ansible must use
that address (it lives in `hosts.yml` and is filled in by `make inventory`).

The existing hand-built cluster deliberately advertises on a **secondary** network
(`192.168.74.x`, not routable from the host). A fresh cluster built by this playbook
simply uses the primary `192.168.252.x` network for both SSH and the k8s
node-ip/apiserver — that works out of the box.

## Running against the EXISTING cluster? Caution

This playbook is meant to build a **fresh** cluster. Do not point it at the running
cp1/worker1 as-is: the node-ip (`192.168.74.x`) and some manual tweaks differ, so a
run would try to "converge" (among other things, change the kubelet node-ip) and
could disrupt the live cluster. For the existing cluster: first `make reset` (or
`make down` + `make up`) and then provision cleanly.

## Other commands

```bash
make reset         # kubeadm reset on all nodes (VMs are kept)
make down          # delete the VMs
```

## Layout

```
inventory/            hosts + group_vars (all versions/tunables in group_vars/all.yml)
playbooks/site.yml    phased orchestration (node prep -> cp -> worker -> cni/add-ons -> falco -> tooling)
playbooks/reset.yml   kubeadm reset
roles/
  common              kernel modules, sysctl, swap-off, base packages
  containerd          Ubuntu containerd + SystemdCgroup
  kube_packages       pkgs.k8s.io repo + pinned kube* + node-ip
  control_plane       kubeadm init + kubeconfig + helm + join token
  worker              kubeadm join
  cni_cilium          Cilium via helm + wait until nodes are Ready
  addon_*             gatekeeper / kyverno / ingress_nginx / nginx_gateway
  falco               Falco modern eBPF + custom local rules
  kube_bench          CIS benchmark tool
  security_tools      docker-snap, cilium-cli, conftest, sysdig, etcd-client (cp) / gVisor (worker)
scripts/              multipass up/down + inventory generator
```

## Enabling / disabling add-ons

Set the `enable_*` flags in `inventory/group_vars/all.yml` to `false` to skip
components (e.g. `enable_nginx_gateway: false`).

## License

MIT — see [LICENSE](LICENSE).
