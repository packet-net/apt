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

This repo holds no `.deb` files itself. A [scheduled GitHub Actions
workflow](.github/workflows/build.yml) reads the latest release of each
source repo, downloads its `.deb` assets, runs `dpkg-scanpackages` to build a
`Packages` index, rewrites each entry's `Filename` to point straight at the
original GitHub Release asset URL, signs the result with the repo's GPG key,
and pushes the (small, text-only) index to the `gh-pages` branch that GitHub
Pages serves. The actual package downloads are served by GitHub Releases,
not by Pages.

It runs every 15 minutes and can also be triggered manually from the
Actions tab.

## Signing key

Fingerprint: `FA6D 3F5F CE47 E89B D84A  67E4 92EC F05A 666C 239F`

The private key is held only as a GitHub Actions secret on this repo.
