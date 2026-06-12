#!/bin/sh
set -ex

# Build the NIF from source on Linux against the locally installed
# Erlang/OTP (so the NIF version always matches the runtime that loads
# it). Unlike build-for-mac.sh this needs no OTP download — the system
# OTP provides the erl_nif headers — and no jq: the per-arch pdfium
# download is inlined below, pinned to the tag in LIBPDFIUM_TAG.

arch=$1 # aarch64/arm64, x86_64/amd64

libpdfium_tag=$(cat ../LIBPDFIUM_TAG)

case "$arch" in
  aarch64|arm64)
    pdfium_archive_name=pdfium-linux-arm64.tgz
    pdfium_sha256sum=248fcfb8ed8cbf11051e30945a3fb6f8022636076fe6ea20820c4b423402db7f
    ;;
  x86_64|amd64)
    pdfium_archive_name=pdfium-linux-x64.tgz
    pdfium_sha256sum=d7fa72d7df0ecc11be9076722d97ee61aab874f3dc561eb8c6b3da324bb8c2a1
    ;;
  *)
    echo "unsupported architecture: $arch" >&2
    exit 1
    ;;
esac

pdfium_download_link="https://github.com/bblanchon/pdfium-binaries/releases/download/$(echo $libpdfium_tag | sed 's|/|%2F|')/${pdfium_archive_name}"
pdfium_directory_name=$(basename $pdfium_archive_name .tgz)

erlang_root=$(erl -noshell -eval 'io:format("~ts", [code:root_dir()]), halt().')

# When invoked by elixir_make (mix compile), FINE_INCLUDE_DIR points at
# the hex-packaged Fine headers. When invoked directly (CI), fetch them.
if [ -n "$FINE_INCLUDE_DIR" ]; then
  fine_include_dir=$FINE_INCLUDE_DIR
  fine_directory_name=""
else
  fine_tag=v0.1.6
  fine_directory_name="fine-${fine_tag}"
  fine_include_dir="${fine_directory_name}/c_include"
fi

# 1. Clean-up
rm -fr $pdfium_directory_name
rm -fr $pdfium_archive_name
if [ -n "$fine_directory_name" ]; then rm -fr $fine_directory_name; fi

mkdir $pdfium_directory_name

# 2. Download PDFium
curl --fail --silent --show-error --location --output $pdfium_archive_name $pdfium_download_link
echo "$pdfium_sha256sum  $pdfium_archive_name" | sha256sum --check
tar --extract --gunzip --directory=$pdfium_directory_name --file=$pdfium_archive_name

# 3. Fetch Fine headers (only if not supplied via FINE_INCLUDE_DIR)
if [ -n "$fine_directory_name" ]; then
  git clone --quiet --depth 1 --branch $fine_tag https://github.com/elixir-nx/fine $fine_directory_name
fi

# 4. Compile (flags mirror the Dagger CI pipeline, minus -march=native
# so the binary isn't tied to the build machine's CPU)
g++ \
  -fpic \
  -fvisibility=hidden \
  --optimize=2 \
  --all-warnings \
  --extra-warnings \
  -Wno-unused-parameter \
  --std=c++17 \
  --include-directory $erlang_root/usr/include \
  --include-directory $pdfium_directory_name/include \
  --include-directory $fine_include_dir \
  --compile \
  --output=pdfium_nif.o \
  ../c_src/pdfium_nif.cpp

g++ \
  pdfium_nif.o \
  --shared \
  --output=pdfium_nif.so \
  --library-directory $erlang_root/usr/lib \
  --library-directory $pdfium_directory_name/lib \
  -static-libstdc++ \
  -Wl,-s \
  -Wl,--disable-new-dtags \
  -Wl,-rpath,'$ORIGIN' \
  -l:libpdfium.so

# 5. Install into priv/. priv/ is gitignored, so it may be absent on a
# fresh checkout. A bare `cp file ../priv` would then create a *file*
# named priv instead of populating a directory, so ensure priv/ exists
# as a directory first.
if [ -e ../priv ] && [ ! -d ../priv ]; then rm -f ../priv; fi
mkdir -p ../priv
cp pdfium_nif.so ../priv
cp $pdfium_directory_name/lib/libpdfium.so ../priv

# 6. Cleanup
rm pdfium_nif.o
rm pdfium_nif.so
rm -fr $pdfium_directory_name
rm -fr $pdfium_archive_name
if [ -n "$fine_directory_name" ]; then rm -fr $fine_directory_name; fi
