#!/usr/bin/env bash
# Rebuilds the flat apt repository index from the latest release of each
# source repo. The .deb files themselves are never copied into this repo;
# Packages' Filename fields point straight at the GitHub Release asset URLs,
# so this repo (and the gh-pages branch) stays tiny text-only.
set -euo pipefail

KEYID="$1"
OUTDIR="$(pwd)/public"
PUBKEY="$(pwd)/pubkey.asc"

REPOS=(packet-net/pdn-soundmodem packet-net/axcall packet-net/packet.net)

WORK="$(mktemp -d)"
POOL="$WORK/pool"
mkdir -p "$POOL" "$OUTDIR"

declare -A URLMAP

for repo in "${REPOS[@]}"; do
  echo "Fetching latest release for $repo"
  assets="$(gh api "repos/$repo/releases/latest" --jq '.assets[] | select(.name | endswith(".deb")) | "\(.name)\t\(.browser_download_url)"')"
  while IFS=$'\t' read -r name url; do
    [ -z "$name" ] && continue
    echo "  $name"
    curl -sL -o "$POOL/$name" "$url"
    URLMAP["$name"]="$url"
  done <<< "$assets"
done

cd "$WORK"
dpkg-scanpackages --multiversion pool /dev/null > Packages

for name in "${!URLMAP[@]}"; do
  sed -i "s#Filename: pool/${name}#Filename: ${URLMAP[$name]}#" Packages
done

gzip -9 -c Packages > Packages.gz

{
  echo "Origin: packet-net"
  echo "Label: packet-net"
  echo "Suite: stable"
  echo "Codename: flat"
  echo "Date: $(date -Ru)"
  echo "Architectures: amd64 arm64 armhf"
  echo "Description: Public apt repository for packet-net packages (pdn-soundmodem, axcall, axinetd, axsocks, axtun, packetnet)"
  echo "MD5Sum:"
  for f in Packages Packages.gz; do
    printf ' %s %16d %s\n' "$(md5sum "$f" | cut -d' ' -f1)" "$(stat -c%s "$f")" "$f"
  done
  echo "SHA1:"
  for f in Packages Packages.gz; do
    printf ' %s %16d %s\n' "$(sha1sum "$f" | cut -d' ' -f1)" "$(stat -c%s "$f")" "$f"
  done
  echo "SHA256:"
  for f in Packages Packages.gz; do
    printf ' %s %16d %s\n' "$(sha256sum "$f" | cut -d' ' -f1)" "$(stat -c%s "$f")" "$f"
  done
} > Release

gpg --batch --yes --default-key "$KEYID" -abs -o Release.gpg Release
gpg --batch --yes --default-key "$KEYID" --clearsign -o InRelease Release

cp Packages Packages.gz Release Release.gpg InRelease "$OUTDIR/"
cp "$PUBKEY" "$OUTDIR/pubkey.asc"

cat > "$OUTDIR/index.html" <<'EOF'
<!doctype html>
<meta charset="utf-8">
<title>packet-net apt repository</title>
<pre>
packet-net apt repository

  curl -fsSL https://packet-net.github.io/apt/pubkey.asc | sudo gpg --dearmor -o /usr/share/keyrings/packet-net.gpg
  echo "deb [signed-by=/usr/share/keyrings/packet-net.gpg] https://packet-net.github.io/apt ./" | sudo tee /etc/apt/sources.list.d/packet-net.list
  sudo apt update
  sudo apt install pdn-soundmodem axcall axinetd axsocks axtun packetnet

See https://github.com/packet-net/apt for details.
</pre>
EOF

echo "Built repository index in $OUTDIR"
