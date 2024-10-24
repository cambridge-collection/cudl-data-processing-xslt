FROM public.ecr.aws/lambda/provided:al2

ARG TARGETARCH

ENV ANT_VERSION=1.10.14
ENV ANT_HOME=/opt/ant

RUN yum install -y wget tar gzip unzip java jq

ENV JAVA_HOME=/usr/lib/jvm

WORKDIR /tmp

# Download and extract apache ant to /opt
RUN wget --no-check-certificate --no-cookies "https://dlcdn.apache.org//ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz" \
    && wget --no-check-certificate --no-cookies "https://dlcdn.apache.org//ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz.sha512" \
    && echo "$(cat apache-ant-${ANT_VERSION}-bin.tar.gz.sha512) apache-ant-${ANT_VERSION}-bin.tar.gz" | sha512sum -c \
    && tar -zvxf "apache-ant-${ANT_VERSION}-bin.tar.gz" -C /opt/ \
    && ln -s /opt/apache-ant-${ANT_VERSION} /opt/ant \
    && rm -f "apache-ant-${ANT_VERSION}-bin.tar.gz" \
    && rm -f "apache-ant-${ANT_VERSION}-bin.tar.gz.sha512"

# Download Saxon jar -- can't find checksum files for releases
RUN mkdir saxon \
    && wget --no-check-certificate --no-cookies "https://github.com/Saxonica/Saxon-HE/releases/download/SaxonHE12-4/SaxonHE12-4J.zip" \
    && unzip SaxonHE12-4J.zip -d saxon \
    && mv saxon /opt/

ENV CLASSPATH=/opt/saxon/saxon-he-12.4.jar

COPY bootstrap ${LAMBDA_RUNTIME_DIR}
RUN chmod 755 ${LAMBDA_RUNTIME_DIR}/bootstrap

RUN mkdir -p /opt/cdcp

WORKDIR /opt/cdcp
RUN mkdir -p dist && mkdir -p transcriptions && mkdir -p cudl-data-source
COPY ./bin bin
COPY ./*.sh ${LAMBDA_TASK_ROOT}
COPY ./xslt xslt

RUN chmod a+x ${LAMBDA_TASK_ROOT}/*.sh

RUN ${LAMBDA_TASK_ROOT}/install-awscli-${TARGETARCH}.sh

CMD [ "aws.sh.handler" ]
