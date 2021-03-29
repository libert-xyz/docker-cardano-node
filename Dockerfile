FROM ubuntu:20.04 AS builder
LABEL maintainer="libert-xyz"

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    automake \
    build-essential \
    pkg-config \
    libffi-dev \
    libgmp-dev \
    libssl-dev \
    libtinfo-dev \
    libsystemd-dev \
    zlib1g-dev \
    make g++ \
    tmux git \
    jq \
    wget \
    libncursesw5 \
    libtool \
    autoconf

WORKDIR /src

#Install cabal
RUN wget https://downloads.haskell.org/~cabal/cabal-install-3.4.0.0/cabal-install-3.4.0.0-x86_64-ubuntu-16.04.tar.xz \
    && tar -xf cabal-install-3.4.0.0-x86_64-ubuntu-16.04.tar.xz \
    && rm cabal-install-3.4.0.0-x86_64-ubuntu-16.04.tar.xz \
    && mv cabal /usr/local/bin/ \
    && cabal update

#Install GHC compiler
RUN wget https://downloads.haskell.org/ghc/8.10.2/ghc-8.10.2-x86_64-deb9-linux.tar.xz \
    && tar -xf ghc-8.10.2-x86_64-deb9-linux.tar.xz \
    && rm ghc-8.10.2-x86_64-deb9-linux.tar.xz \
    && cd ghc-8.10.2 \
    && ./configure \
    &&  make install


#Installing Libsodium
RUN git clone https://github.com/input-output-hk/libsodium \
    && cd libsodium \
    && git checkout 66f017f1 \
    && ./autogen.sh \
    && ./configure \
    && make \
    && make install

ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"


#Install cardano-node
ARG TAG=1.24.2
RUN git clone https://github.com/input-output-hk/cardano-node.git \
    && cd cardano-node \
    && git fetch --all --recurse-submodules --tags \
    && git checkout tags/$TAG \
    && cabal configure --with-compiler=ghc-8.10.2 \
    && echo "package cardano-crypto-praos" >>  cabal.project.local \
    && echo "  flags: -external-libsodium-vrf" >>  cabal.project.local \
    && cabal build all \
    && cabal install --installdir /usr/local/bin cardano-cli cardano-node


FROM ubuntu:20.04

COPY --from=builder /usr/local/lib/libsodium.so* /usr/local/lib/
COPY --from=builder /usr/local/bin/cardano-cli /usr/local/bin/
COPY --from=builder /usr/local/bin/cardano-node /usr/local/bin/
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"


# Install required packages
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Create a group and user
ARG USERNAME="ada"
ARG GROUP="ada"
ARG USERID="1000"
ARG GROUPID="1024"
RUN groupadd -g $GROUPID -r $USERNAME \
  && useradd --no-log-init -r --gid $GROUPID -u $USERID $USERNAME \
  && mkdir /home/$USERNAME \
  && chown -R ${USERID}:${GROUPID} /home/${USERNAME} \
  && echo ${USERNAME}:${USERNAME} | chpasswd

USER ${USERNAME}

RUN mkdir /home/${USERNAME}/cardano-node/

ENTRYPOINT ["cardano-cli"]
CMD ["--version"]