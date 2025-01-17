#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
export BITCOIN_VERSION=25.1
export ELEMENTS_VERSION=22.0.2
export RUST_VERSION=stable

sudo useradd -ms /bin/bash tester
sudo apt-get update -qq

sudo apt-get -qq install --no-install-recommends --allow-unauthenticated -yy \
     autoconf \
     automake \
     binfmt-support \
     build-essential \
     clang \
     cppcheck \
     docbook-xml \
     eatmydata \
     gcc-i686-linux-gnu \
	 gcc-s390x-linux-gnu \
     gcc-arm-linux-gnueabihf \
     gcc-aarch64-linux-gnu \
     gcc-mips-linux-gnu \
     gcc-mips64-linux-gnuabi64 \
     gcc-powerpc-linux-gnu \
     gcc-powerpc64-linux-gnu \
     gcc-riscv64-linux-gnu \
     gettext \
     git \
	 libc6-dev-i386-cross \
	 libc6-dev-s390x-cross \
	 libc6-dev-mips64-cross \
     libc6-dev-armhf-cross \
     libc6-dev-arm64-cross \
     libc6-dev-mips-cross \
     libc6-dev-mips64-cross \
     libc6-dev-powerpc-cross \
     libc6-dev-ppc64-cross \
     libc6-dev-riscv64-cross \
     libpython3-dev \
     libpq-dev \
     libprotobuf-c-dev \
     libsqlite3-dev \
     libtool \
     libxml2-utils \
     locales \
     net-tools \
     postgresql \
     python-pkg-resources \
     python3 \
     python3-dev \
     python3-pip \
     python3-setuptools \
     qemu-user-static \
     shellcheck \
     software-properties-common \
     sudo \
     tcl \
     unzip \
     wget \
     xsltproc \
     zlib1g-dev

echo "tester ALL=(root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/tester
sudo chmod 0440 /etc/sudoers.d/tester

(
    cd /tmp/ || exit 1
	wget https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz
    wget https://github.com/ElementsProject/elements/releases/download/elements-${ELEMENTS_VERSION}/elements-${ELEMENTS_VERSION}-x86_64-linux-gnu.tar.gz
	tar -xf bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz
    tar -xf elements-${ELEMENTS_VERSION}-x86_64-linux-gnu.tar.gz
    sudo mv bitcoin-${BITCOIN_VERSION}/bin/* /usr/local/bin
    sudo mv elements-${ELEMENTS_VERSION}/bin/* /usr/local/bin
    rm -rf \
       bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz \
       bitcoin-${BITCOIN_VERSION} \
       elements-${ELEMENTS_VERSION}-x86_64-linux-gnu.tar.gz \
       elements-${ELEMENTS_VERSION}
)

if [ "$RUST" == "1" ]; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- \
      -y --default-toolchain ${RUST_VERSION}
fi

# We also need a relatively recent protobuf-compiler, at least 3.12.0,
# in order to support the experimental `optional` flag.

# BUT WAIT!  Gentoo wants this to match the version from the Python protobuf,
# which comes from the same tree.  Makes sense!

# And
#   grpcio-tools-1.54.0` requires `protobuf = ">=4.21.6,<5.0dev"`

# Now, protoc changed to date-based releases, BUT Python protobuf
# didn't, so Python protobuf 4.21.12 (in Ubuntu 23.04) corresponds to
# protoc 21.12 (which, FYI, is packaged in Ubuntu as version 3.21.12).

# So we're going to nail these versions as 21.12, which is what recent
# Ubuntu has, and hopefully everyone else can get.  And this means that
# When CI checks that no files have changed under regeneration, you won't
# get a fail just because the dev's protoc is a different version.

# Honorable mention go to Matt Whitlock for spelunking this horror with me!

PROTOC_VERSION=21.12
PB_REL="https://github.com/protocolbuffers/protobuf/releases"
curl -LO $PB_REL/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-x86_64.zip
sudo unzip protoc-${PROTOC_VERSION}-linux-x86_64.zip -d /usr/local/
sudo chmod a+x /usr/local/bin/protoc
export PROTOC=/usr/local/bin/protoc
export PATH=$PATH:/usr/local/bin
env
ls -lha /usr/local/bin
