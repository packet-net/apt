# packet-net apt repository

A public apt repository for Debian/Ubuntu packages built by the
[packet-net](https://github.com/packet-net) org, published via GitHub Pages
at https://packet-net.github.io/apt.

Currently tracks the latest release of:

- [pdn-soundmodem](https://github.com/packet-net/pdn-soundmodem) - `pdn-soundmodem`
- [axcall](https://github.com/packet-net/axcall) - `axcall`, `axinetd`, `axsocks`, `axtun`
- [packet.net](https://github.com/packet-net/packet.net) - `packetnet`
- [pdn-bbs](https://github.com/packet-net/pdn-bbs) - `pdn-bbs`
- [pdn-bpqchat](https://github.com/packet-net/pdn-bpqchat) - `pdn-bpqchat`
- [pdn-convers](https://github.com/packet-net/pdn-convers) - `pdn-convers`
- [pdn-libax25](https://github.com/packet-net/pdn-libax25) - `pdn-libax25`
- [pdn-net](https://github.com/packet-net/pdn-net) - `pdn-net`
- [pdn-qso](https://github.com/packet-net/pdn-qso) - `pdn-qso`
- [tait-codeplug](https://github.com/M0LTE/tait-codeplug) - `tait-codeplug`
- [tait-cli](https://github.com/M0LTE/tait-cli) - `tait-cli`
- [nprflash](https://github.com/M0LTE/nprflash) - `nprflash` (`Architecture: all`)

for `amd64`, `arm64` and `armhf`.

The list lives in [`sources.txt`](sources.txt), one `owner/repo` per line.

## Usage

```sh
curl -fsSL https://packet-net.github.io/apt/pubkey.asc | sudo gpg --dearmor -o /usr/share/keyrings/packet-net.gpg
echo "deb [signed-by=/usr/share/keyrings/packet-net.gpg] https://packet-net.github.io/apt ./" | sudo tee /etc/apt/sources.list.d/packet-net.list
sudo apt update
sudo apt install pdn-soundmodem axcall axinetd axsocks axtun packetnet pdn-bbs pdn-bpqchat pdn-convers pdn-libax25 pdn-net pdn-qso tait-codeplug tait-cli nprflash
```

## How it works

A [scheduled GitHub Actions workflow](.github/workflows/build.yml) reads the
latest release of each source repo, downloads its `.deb` assets into
`pool/`, runs `dpkg-scanpackages` to build a `Packages` index, signs the
result with the repo's GPG key, and pushes it all to the `gh-pages` branch
that GitHub Pages serves.

The `.deb` files are mirrored into this repo's `pool/` rather than just
linked from the GitHub Release: apt joins a package's `Filename:` to the
repository's base URL even when `Filename:` is already an absolute URL, so
pointing it straight at a release asset produces a broken double-URL and
apt fails at the download step. Keeping `Filename:` as the plain
`dpkg-scanpackages` output (`pool/<name>.deb`, relative to the repo) and
serving the actual files from `pool/` is the only layout that works.

The build is normally triggered by the project that just released. At the end
of its release workflow, after the assets are attached, a source repo POSTs a
`release-published` [`repository_dispatch`](https://docs.github.com/en/rest/repos/repos#create-a-repository-dispatch-event)
at this repo, which rebuilds the whole index from every source repo's latest
release. Tag to installable is then about a minute. The payload is only there
for the run log; nothing is uploaded from the source repo, because the signing
key lives only here and the `Packages` index is a single flat index across every
project, so it has to be rebuilt centrally whatever happens.

A source repo needs one secret to do that: a fine-grained PAT with **Contents:
Read and write** on *this* repo and nothing else, exposed to its release
workflow as `APT_DISPATCH_TOKEN`. A `packet-net/*` repo can use an org secret;
a repo in a personal account needs its own copy. The dispatch step is expected
to warn rather than fail when the secret is missing, so a release never fails
over it.

The hourly cron is the self-heal path for a dispatch that never arrived, and
the build can also be triggered manually from the Actions tab.

## Adding a project

1. Add `owner/repo` to [`sources.txt`](sources.txt) here. Its latest release's
   `.deb` assets are picked up from the next build onwards. The repo must be
   public: the build uses this repo's own `GITHUB_TOKEN`, which can read any
   public repo's releases but not a private one.
2. Add the dispatch step to that project's release workflow, after its assets
   are published, so it does not wait for the cron.

A release marked prerelease or draft is invisible to `releases/latest`, so it
never reaches apt. That is deliberate: apt gets stable releases only.

## Signing key

Fingerprint: `FA6D 3F5F CE47 E89B D84A  67E4 92EC F05A 666C 239F`

The private key is held only as a GitHub Actions secret on this repo.
