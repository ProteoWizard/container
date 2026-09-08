# Flavor selection.
#
# One Dockerfile rather than two because the two TeamCity container configs share this
# file: the GithubContainer VCS root is mounted at `=>container` pinned to
# refs/heads/master, so a pwiz PR always gets master here and a coordinated container PR
# is impossible. Both flavors therefore have to build from whatever master holds.
#
# The defaults are the net472 flavor deliberately. Any caller that passes no --build-arg
# -- the release-branch container config, the Docker Hub publish path, a developer running
# a plain `docker build .` -- keeps producing exactly the image it produced before.
#
# The net10 config passes both:
#   --build-arg PAYLOAD_BASE=proteowizard/wine:stable11.0-x64
#   --build-arg RUNTIME_BASE=proteowizard/wine:stable11.0-x64
# The payload stage needs a wine base there because the net10 pwiz payload is an installer
# that has to be run, not an archive to unpack.
ARG PAYLOAD_BASE=ubuntu:20.04
ARG RUNTIME_BASE=proteowizard/wine-dotnet:winestaging10.6-net4.8-x64


# Two payloads, either way: ProteoWizard in C:\pwiz and Skyline in C:\pwiz\skyline.
#
# net472: the C++ pwiz-bin tarball, unpacked.
#
# net10: the shipping installer -- msconvert is now the managed port.
# ProteoWizard-WithVendorSdks-Setup carries three things this image needs: the apps, the
# .NET 10 runtime they are built against, and every Windows vendor SDK pre-extracted into
# VendorSdkLoader's cache. The cache is what lets the image run with no network at all;
# without it each SDK is fetched from raw.githubusercontent.com the first time a reader is
# used, which fails in an offline or air-gapped deployment.
#
# This stage normalizes both into one fixed layout under /out, so the runtime stage below
# copies the same three paths whichever flavor was built. It is discarded, which is what
# keeps the ~104 MB setup EXE out of the shipped image -- an `rm` in a later layer would
# not reclaim it.
FROM ${PAYLOAD_BASE} AS payload

RUN apt-get update && \
    apt-get -y install unzip bzip2 && \
    rm -rf /var/lib/apt/lists/*

# The whole context, not `ADD <glob>`: ADD fails the build outright when its glob matches
# nothing ("ADD failed: no source files were specified"), which is exactly how the net10
# config fails against the net472 Dockerfile today. A glob that has to be allowed to miss
# cannot be an ADD. The context is sent to the daemon regardless, and this stage is thrown
# away, so nothing is paid for it in the shipped image.
COPY . /ctx/

# The dotnet and ProgramData trees are created unconditionally, even when empty, because
# `COPY --from` of a path that does not exist fails the build. net472 produces neither.
#
# net10 install flags: /CURRENTUSER installs per-user so nothing needs elevation, and /DIR
# overrides Inno's versioned default directory so WINEPATH below does not have to track the
# version. xvfb-run because Inno still creates a window in /VERYSILENT mode.
#
# `wineserver -k` (kill), not `-w` (wait): the installer leaves a wine process alive in the
# prefix, and -w waits on that very process and blocks forever. Killing it is not optional
# -- starting a conversion while it is still alive deadlocks the Shimadzu reader.
#
# Setup exits 0 on failures that matter here, so the install is gated on the artifacts it
# has to have produced rather than on its exit code.
RUN set -e; \
    mkdir -p /out/pwiz/skyline "/out/Program Files/dotnet" /out/ProgramData/ProteoWizard; \
    if ls /ctx/pwiz-bin-windows-*.tar.bz2 >/dev/null 2>&1; then \
        echo "pwiz payload: net472 tarball"; \
        tar xjf /ctx/pwiz-bin-windows-*.tar.bz2 -C /out/pwiz; \
    elif ls /ctx/ProteoWizard-WithVendorSdks-Setup-*.exe >/dev/null 2>&1; then \
        echo "pwiz payload: net10 installer"; \
        exe=$(ls /ctx/ProteoWizard-WithVendorSdks-Setup-*.exe | head -1); \
        timeout -k 10 900 xvfb-run -a wine "$exe" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART \
            /CURRENTUSER /TASKS= "/DIR=C:\pwiz" < /dev/null; \
        wineserver -k; \
        test -f /wineprefix64/drive_c/pwiz/msconvert.exe; \
        test -f "/wineprefix64/drive_c/Program Files/dotnet/dotnet.exe"; \
        test -f /wineprefix64/drive_c/ProgramData/ProteoWizard/vendor-cache-root.txt; \
        cp -a /wineprefix64/drive_c/pwiz/. /out/pwiz/; \
        cp -a "/wineprefix64/drive_c/Program Files/dotnet/." "/out/Program Files/dotnet/"; \
        cp -a /wineprefix64/drive_c/ProgramData/ProteoWizard/. /out/ProgramData/ProteoWizard/; \
    else \
        echo "no pwiz payload in build context: expected pwiz-bin-windows-*.tar.bz2 or ProteoWizard-WithVendorSdks-Setup-*.exe" >&2; \
        exit 1; \
    fi; \
    test -f /ctx/SkylineTester.zip; \
    unzip -q /ctx/SkylineTester.zip -d /unz; \
    mv "/unz/SkylineTester Files"/* /out/pwiz/skyline; \
    rm -rf /unz /out/pwiz/skyline/TestZipFiles /ctx


FROM ${RUNTIME_BASE}
COPY --from=payload /out/pwiz /wineprefix64/drive_c/pwiz
# The .NET 10 runtime the installer put in place, then the vendor SDK cache together with
# the vendor-cache-root.txt marker that points VendorSdkLoader at it. Both are empty in the
# net472 flavor. JSON form because the source path has a space in it, which the shell form
# cannot express.
COPY --from=payload ["/out/Program Files/dotnet", "/wineprefix64/drive_c/Program Files/dotnet"]
COPY --from=payload /out/ProgramData/ProteoWizard /wineprefix64/drive_c/ProgramData/ProteoWizard

ENV CONTAINER_GITHUB=https://github.com/ProteoWizard/container

LABEL description="Convert MS RAW vendor files to open formats or analyze them with Skyline."
LABEL website=https://github.com/ProteoWizard/container
LABEL documentation=https://github.com/ProteoWizard/container
LABEL license=https://github.com/ProteoWizard/container
LABEL tags="Metabolomics,Proteomics,MassSpectrometry"

ENV WINEDEBUG=-all
ENV WINEPATH="C:\pwiz;C:\pwiz\skyline"

# net10: both payloads are framework-dependent, and both resolve against the one runtime the
# installer put in place -- so the Skyline payload's own bundled copy in
# C:\pwiz\skyline\dotnet goes unused. DOTNET_ROOT has to be set explicitly because the
# runtime's HKLM registration does not survive the stage boundary; only its files are copied.
# net472: inert, and points at the empty directory the payload stage created.
ENV DOTNET_ROOT="C:\Program Files\dotnet"

# sudo needed to run wine when container is run as a non-default user (e.g. -u 1234)
# wine*_anyuser scripts are convenience scripts that work like wine/wine64 no matter what user calls them.
# wine >= 10 uses the unified WoW64 build, which ships only a single `wine` binary (no `wine64`),
# so wine64_anyuser is now identical to wine_anyuser.
RUN apt-get update && \
    apt-get -y install sudo && \
    apt-get -y clean && \
    echo "ALL     ALL=NOPASSWD:  ALL" >> /etc/sudoers && \
    printf '#!/bin/sh\nsudo -E -H -u root wine "$@"\n' > /usr/bin/wine64_anyuser && \
    printf '#!/bin/sh\nsudo -E -H -u root wine "$@"\n' > /usr/bin/wine_anyuser && \
    chmod ugo+rx /usr/bin/wine*anyuser && \
    rm -rf \
      /var/lib/apt/lists/* \
      /usr/share/doc \
      /usr/share/doc-base \
      /usr/share/man \
      /usr/share/locale \
      /usr/share/zoneinfo

# create UIDs that Galaxy uses in default configs to launch docker containers; the UID must exist for sudo to work.
# Ubuntu 24.04 (the wine 11 base) ships a default "ubuntu" user at uid 1000, which collides with
# galaxy_docker, so it is removed first. There is no such user on the 20.04 wine-dotnet base,
# where the guarded first command is a no-op.
RUN touch /var/mail/ubuntu && chown ubuntu /var/mail/ubuntu && userdel -r ubuntu 2>/dev/null || true; \
    groupadd -r galaxy -g 1450 && \
    useradd -u 1450 -r -g galaxy -d /home/galaxy -c "Galaxy user" galaxy && \
    useradd -u 1000 -r -g galaxy -d /home/galaxy -c "Galaxy docker user" galaxy_docker && \
    useradd -u 2000 -r -g galaxy -d /home/galaxy -c "Galaxy Travis user" galaxy_travis && \
    useradd -u 999 -r -g galaxy -d /home/galaxy -c "usegalaxy.eu user" galaxy_eu

# Set up working directory and permissions to let user xclient save data
RUN mkdir /data
WORKDIR /data

CMD ["wine64_anyuser", "msconvert" ]

## If you need a proxy during build, don't put it into the Dockerfile itself:
## docker build --build-arg http_proxy=http://proxy.example.com:3128/  -t repo/image:version .

ADD mywine /usr/bin/
RUN chmod ugo+rx /usr/bin/mywine

# Fixes for running the container in apptainer.
# Sets the TEMP and TMP environment variables for the wine user to Z:\tmp
# Z:\tmp in wine maps to /tmp on the host operating system in apptainer
RUN echo "\"TMP\"=\"Z:\\\\\\\\tmp\"" >> /wineprefix64/user.reg
