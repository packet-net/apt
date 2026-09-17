# packet-net apt repository

A public apt repository for Debian/Ubuntu packages built by the
[packet-net](https://github.com/packet-net) org, published via GitHub Pages
at https://packet-net.github.io/apt.

Currently tracks the latest release of:

- [pdn-soundmodem](https://github.com/packet-net/pdn-soundmodem) - `pdn-soundmodem`
- [axcall](https://github.com/packet-net/axcall) - `axcall`, `axinetd`, `axsocks`, `axtun`
- [packet.net](https://github.com/packet-net/packet.net) - `packetnet`

for `amd64`, `arm64` and `armhf`.

## Usage

```sh
curl -fsSL https://packet-net.github.io/apt/pubkey.asc | sudo gpg --dearmor -o /usr/share/keyrings/packet-net.gpg
echo "deb [signed-by=/usr/share/keyrings/packet-net.gpg] https://packet-net.github.io/apt ./" | sudo tee /etc/apt/sources.list.d/packet-net.list
sudo apt update
sudo apt install pdn-soundmodem axcall axinetd axsocks axtun packetnet
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

It runs every 15 minutes and can also be triggered manually from the
Actions tab.

## Signing key

Fingerprint: `FA6D 3F5F CE47 E89B D84A  67E4 92EC F05A 666C 239F`

The private key is held only as a GitHub Actions secret on this repo.
