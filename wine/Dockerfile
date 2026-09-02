FROM ubuntu:24.04

LABEL description="Wine 11 base for ProteoWizard containers"
LABEL website=https://github.com/ProteoWizard/container
LABEL documentation=https://github.com/ProteoWizard/container
LABEL license=https://github.com/ProteoWizard/container
LABEL tags="Wine"

ENV CONTAINER_GITHUB=https://github.com/ProteoWizard/container/wine

# Prevents annoying debconf errors during builds
ARG DEBIAN_FRONTEND="noninteractive"

# Ubuntu 24.04 (noble), not 20.04 (focal): WineHQ's focal builds stop at 10.6, which is
# why the previous base was pinned there. Wine 11 is published for jammy and noble only.
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y \
# Required for wine
        winbind \
# Required for winetricks
        cabextract \
        p7zip \
        unzip \
        wget \
        zenity \
        xvfb \
        ca-certificates && \
    apt-get -y clean && \
    rm -rf \
      /var/lib/apt/lists/* \
      /usr/share/doc \
      /usr/share/doc-base \
      /usr/share/man \
      /usr/share/locale \
      /usr/share/zoneinfo

ENV WINEDISTRO=stable
ENV WINEVERSION=11.0.0.0~noble-1

# apt-key is removed in noble, so the WineHQ key goes to /etc/apt/keyrings and the repo
# comes from WineHQ's own deb822 .sources file rather than add-apt-repository.
RUN mkdir -pm755 /etc/apt/keyrings \
    && wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key \
    && wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources \
    && apt-get update \
    && apt-get install -y --install-recommends \
        winehq-$WINEDISTRO=$WINEVERSION \
        wine-$WINEDISTRO=$WINEVERSION \
        wine-$WINEDISTRO-i386=$WINEVERSION \
        wine-$WINEDISTRO-amd64=$WINEVERSION && \
    apt-get -y clean && \
    rm -rf \
      /var/lib/apt/lists/* \
      /usr/share/doc \
      /usr/share/doc-base \
      /usr/share/man \
      /usr/share/locale \
      /usr/share/zoneinfo \
      && \
    wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
      -O /usr/local/bin/winetricks && chmod +x /usr/local/bin/winetricks

ENV WINEDEBUG="-all,err+all"

# Vendor SDK filenames and sample names are not all ASCII (e.g. the Shimadzu CJK fixture).
# Without a UTF-8 locale wine mangles them and the reader reports "Invalid name".
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# To be singularity friendly, avoid installing anything to /root
RUN mkdir -p /wineprefix64/
ENV WINEPREFIX=/wineprefix64
WORKDIR /wineprefix64

# No .NET Framework and no VC++ redistributables here, unlike the wine-dotnet base:
#   - .NET Framework was for net472 Skyline. The net10 payload carries its own runtime.
#   - The VC++ runtimes the vendor SDKs need (VC90 for Bruker CompassXtract, VC120 for
#     Agilent BaseTof, VC140/MFC140 for Shimadzu) are deployed app-local by pwiz-sharp,
#     so they no longer have to be installed into the prefix. MFC140 was the one wine has
#     no builtin for, and was silently making Shimadzu return zero spectra.
# corefonts is kept: it is font rendering for the Skyline UI, not a runtime dependency.
#
# Wine offers to download Mono and Gecko the first time a prefix is created; in a container
# that offer is a GUI dialog with nobody to answer it, so wineboot hangs forever, even under
# xvfb. The old wine-dotnet base never hit this because winetricks dotnet48 set mscoree to
# native first. The override is scoped to this RUN deliberately -- as a persistent ENV it
# breaks the payload, which then dies on every input with
#   FileNotFoundException ... System.Runtime.dll ... Module not found
# even though the runtime is present and complete.
#
# `wineserver -k` (kill), not `-w` (wait): -w blocks until every wine process in the prefix
# exits, and winetricks leaves one behind, so -w hangs the build here.
RUN WINEDLLOVERRIDES="mscoree,mshtml=" wineboot -u && wineserver -k \
    && xvfb-run winetricks -q corefonts \
    && wineserver -k \
    && rm -fr /root/.cache/winetricks
