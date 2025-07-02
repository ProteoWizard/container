FROM ubuntu:20.04

LABEL description="Wine with .NET"
LABEL website=https://github.com/ProteoWizard/container/dotnet
LABEL documentation=https://github.com/ProteoWizard/container/dotnet
LABEL license=https://github.com/ProteoWizard/container/dotnet
LABEL tags="Wine,.NET"

ENV CONTAINER_GITHUB=https://github.com/ProteoWizard/container/dotnet

# Prevents annoying debconf errors during builds
ARG DEBIAN_FRONTEND="noninteractive"

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y \
# Required for adding repositories
        software-properties-common \
# Required for wine
        winbind \
# Required for winetricks
        cabextract \
        p7zip \
        unzip \
        wget \
        zenity \
        xvfb && \
    apt-get -y clean && \
    rm -rf \
      /var/lib/apt/lists/* \
      /usr/share/doc \
      /usr/share/doc-base \
      /usr/share/man \
      /usr/share/locale \
      /usr/share/zoneinfo

ENV WINEDISTRO=staging
ENV WINEVERSION=10.6~focal-1

# Install wine
RUN wget -nc https://dl.winehq.org/wine-builds/winehq.key \
    && apt-key add winehq.key \
    && apt-get update \
    && apt-get install -y apt-transport-https \
    && add-apt-repository https://dl.winehq.org/wine-builds/ubuntu/ \
    && apt-get update \
    && apt-get install -y --allow-unauthenticated --install-recommends winehq-$WINEDISTRO=$WINEVERSION wine-$WINEDISTRO=$WINEVERSION wine-$WINEDISTRO-i386=$WINEVERSION wine-$WINEDISTRO-amd64=$WINEVERSION && \
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

# put C:\pwiz on the Windows search path
#ENV WINEARCH win64
ENV WINEDEBUG -all,err+all

# To be singularity friendly, avoid installing anything to /root
RUN mkdir -p /wineprefix64/
ENV WINEPREFIX /wineprefix64
WORKDIR /wineprefix64

# Install Windows dependencies
#ADD winetricks_cache /root/.cache/winetricks
RUN winetricks -q dotnet48 && wineserver -w && winetricks -q win7 && xvfb-run winetricks -q vcrun2008 vcrun2017 corefonts && wineserver -w && rm -fr /root/.cache/winetricks


