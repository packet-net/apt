#!/usr/bin/env bash
# Rebuilds the apt repository (index + pool/ of .deb files) from the latest
# release of each source repo. apt joins Filename: to the repo base URI even
# when it's already an absolute URL (producing a broken double-URL), so the
# .deb files have to actually live under this repo's pool/, not just be
# linked to from the index.
set -euo pipefail

KEYID="$1"
OUTDIR="$(pwd)/public"
PUBKEY="$(pwd)/pubkey.asc"

# The source repos are data, not code: sources.txt at the repo root, one owner/repo per
# line. Adding a project to this apt repo is a line there.
SOURCES="$(pwd)/sources.txt"
mapfile -t REPOS < <(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' -e 's/[[:space:]]//g' "$SOURCES")
[ "${#REPOS[@]}" -gt 0 ] || { echo "sources.txt lists no repos" >&2; exit 2; }

WORK="$(mktemp -d)"
POOL="$WORK/pool"
mkdir -p "$POOL" "$OUTDIR"

for repo in "${REPOS[@]}"; do
  echo "Fetching latest release for $repo"
  # The run's own GITHUB_TOKEN is enough to read a *public* repo's releases in any other
  # account or org. If a source repo is ever made private this stops working and it needs
  # a PAT with read access to that repo instead.
  # A repo that has never cut a release 404s here. That is an expected state, not a fault: the
  # documented way to adopt this repo is to add the line first and release afterwards, and a
  # project that has not got there yet must not turn the index red for every other project. It
  # simply contributes nothing until it has a release. Anything else (a typo in sources.txt, a
  # repo gone private, a rate limit) also lands here, so say so loudly rather than silently.
  if ! assets="$(gh api "repos/$repo/releases/latest" --jq '.assets[] | select(.name | endswith(".deb")) | "\(.name)\t\(.browser_download_url)"' 2>/dev/null)"; then
    echo "  no published release readable for $repo; skipping it this run" >&2
    continue
  fi
  while IFS=$'\t' read -r name url; do
    [ -z "$name" ] && continue
    echo "  $name"
    # -f, not bare -sL: without it a 404 or an error page is written to the pool and
    # indexed as a corrupt .deb. Fail the run instead, and let set -e stop here.
    curl -fsSL --retry 3 --retry-all-errors -o "$POOL/$name" "$url"
  done <<< "$assets"
done

cd "$WORK"
dpkg-scanpackages --multiversion pool /dev/null > Packages

gzip -9 -c Packages > Packages.gz

{
  echo "Origin: packet-net"
  echo "Label: packet-net"
  echo "Suite: stable"
  echo "Codename: flat"
  echo "Date: $(date -Ru)"
  # `all` because nprflash is Architecture: all - one package for every machine, which is what a
  # pure-Python tool should ship. apt installs it on any host whether or not it is named here (a
  # flat repo has a single Packages index, not a per-architecture split, so there is nothing to
  # miss it out of), but the field is meant to describe what the repo actually carries.
  echo "Architectures: all amd64 arm64 armhf"
  echo "Description: Public apt repository for packet-net packages (dapps, pdn-soundmodem, axcall, axinetd, axsocks, axtun, packetnet, pdn-bbs, pdn-bpqchat, pdn-convers, pdn-libax25, pdn-net, pdn-qso, tait-codeplug, tait-cli, nprflash)"
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
rm -rf "$OUTDIR/pool"
cp -r pool "$OUTDIR/pool"

cat > "$OUTDIR/index.html" <<'EOF'
<!doctype html>
<meta charset="utf-8">
<title>packet-net apt repository</title>
<pre>
packet-net apt repository

  curl -fsSL https://packet-net.github.io/apt/pubkey.asc | sudo gpg --dearmor -o /usr/share/keyrings/packet-net.gpg
  echo "deb [signed-by=/usr/share/keyrings/packet-net.gpg] https://packet-net.github.io/apt ./" | sudo tee /etc/apt/sources.list.d/packet-net.list
  sudo apt update
  sudo apt install dapps pdn-soundmodem axcall axinetd axsocks axtun packetnet pdn-bbs pdn-bpqchat pdn-convers pdn-libax25 pdn-net pdn-qso tait-codeplug tait-cli nprflash

See https://github.com/packet-net/apt for details.
</pre>
EOF

echo "Built repository index in $OUTDIR"
