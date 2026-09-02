FROM ubuntu:24.04

RUN apt-get update && \
    apt-get -y install unzip bzip2
RUN mkdir -p /wineprefix64/drive_c/pwiz/skyline
# net10 payload: one artifact. Skyline.csproj deploys the managed pwiz-sharp msconvert
# next to Skyline, and Stage-Tests.ps1 bundles the portable .NET runtime into the same
# staging tree, so SkylineTester.zip carries Skyline + msconvert + runtime together.
# The C++ pwiz-bin tarball is gone: msconvert is now the managed port.
ADD SkylineTester.zip /
RUN unzip SkylineTester.zip && mv /SkylineTester\ Files/* /wineprefix64/drive_c/pwiz/skyline && rm -fr /wineprefix64/drive_c/pwiz/skyline/TestZipFiles


FROM proteowizard/wine:stable11.0-x64
COPY --from=0 /wineprefix64/drive_c/pwiz /wineprefix64/drive_c/pwiz

ENV CONTAINER_GITHUB=https://github.com/ProteoWizard/container

LABEL description="Convert MS RAW vendor files to open formats or analyze them with Skyline."
LABEL website=https://github.com/ProteoWizard/container
LABEL documentation=https://github.com/ProteoWizard/container
LABEL license=https://github.com/ProteoWizard/container
LABEL tags="Metabolomics,Proteomics,MassSpectrometry"

ENV WINEDEBUG=-all
ENV WINEPATH="C:\pwiz;C:\pwiz\skyline"

# The payload is framework-dependent and carries its own runtime beside itself, so the
# apphosts have to be told where it is; there is no machine-wide .NET install here.
ENV DOTNET_ROOT="C:\pwiz\skyline\dotnet"

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
# Ubuntu 24.04 ships a default "ubuntu" user at uid 1000, which collides with galaxy_docker, so it is removed first.
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
