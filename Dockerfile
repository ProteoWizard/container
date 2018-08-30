FROM ubuntu:16.04

RUN apt-get update && \
    apt-get -y install unzip bzip2
RUN mkdir -p /wineprefix64/drive_c/pwiz/skyline
ADD pwiz-bin-windows-*.tar.bz2 /wineprefix64/drive_c/pwiz
ADD SkylineTester.zip /
RUN unzip SkylineTester.zip && mv /SkylineTester\ Files/* /wineprefix64/drive_c/pwiz/skyline && rm -fr /wineprefix64/drive_c/pwiz/skyline/TestZipFiles


FROM chambm/wine-dotnet:4.7-x64
COPY --from=0 /wineprefix64/drive_c/pwiz /wineprefix64/drive_c/pwiz

ENV CONTAINER_GITHUB=https://github.com/ProteoWizard/container

LABEL description="Convert MS RAW vendor files to open formats or analyze them with Skyline."
LABEL website=https://github.com/ProteoWizard/container
LABEL documentation=https://github.com/ProteoWizard/container
LABEL license=https://github.com/ProteoWizard/container
LABEL tags="Metabolomics,Proteomics,MassSpectrometry"

ENV WINEDEBUG -all,err+all
ENV WINEPATH "C:\pwiz;C:\pwiz\skyline"

# Set up working directory and permissions to let user xclient save data
RUN mkdir /data
WORKDIR /data

CMD ["wine64", "msconvert" ]

## If you need a proxy during build, don't put it into the Dockerfile itself:
## docker build --build-arg http_proxy=http://proxy.example.com:3128/  -t repo/image:version .
