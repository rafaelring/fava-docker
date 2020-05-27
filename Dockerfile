FROM python:3.7.3-alpine3.9 as build_env

ENV FINGERPRINT "sha256:5E:7E:34:26:F0:DB:84:8F:53:5D:3E:A5:63:B2:FD:A0:88:3F:9D:1C:53:72:67:83:1C:A3:7F:34:D1:29:D6:86"
ENV BUILDDEPS "libxml2-dev libxslt-dev gcc musl-dev mercurial git npm make g++"
# Short python version.
ENV PV "3.7"

WORKDIR /root
RUN apk add --no-cache ${BUILDDEPS}

RUN hg clone --config hostsecurity.bitbucket.org:fingerprints=${FINGERPRINT} https://bitbucket.org/blais/beancount
RUN echo "Beancount version:" && cd beancount && hg log -l1

RUN git clone --branch v1.14 https://github.com/beancount/fava.git
RUN echo "Fava version:" && cd fava && git log -1

RUN echo "Deleting symlink files as they will cause docker build error" && find ./ -type l -delete -print

RUN echo "Install Beancount..."
RUN python3 -mpip install ./beancount

RUN echo "Install Fava..."
RUN make -C fava
RUN make -C fava mostlyclean
RUN python3 -mpip install ./fava

RUN echo "Strip .so files to reduce image size:"
RUN find /usr/local/lib/python${PV}/site-packages -name '*.so' -print0|xargs -0 strip -v
RUN echo "Remove unused files to reduce image size:"
RUN find /usr/local/lib/python${PV} -name __pycache__ -exec rm -rf -v {} +
RUN find /usr/local/lib/python${PV} -type f -name '*.dist-info' -delete
RUN find /usr/local/lib/python${PV} -type f -name '*.exe' -delete


FROM python:3.7.3-alpine3.9
ENV PV "3.7"
ENV BEANCOUNT_INPUT_FILE ""
ENV FAVA_OPTIONS "-H 0.0.0.0"
COPY --from=build_env /usr/local/lib/python${PV}/site-packages /usr/local/lib/python${PV}/site-packages
COPY --from=build_env /usr/local/bin/fava /usr/local/bin

# Default fava port number
EXPOSE 5000

CMD ["sh", "-c", "fava $FAVA_OPTIONS $BEANCOUNT_INPUT_FILE"]
