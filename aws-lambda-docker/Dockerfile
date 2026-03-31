FROM public.ecr.aws/lambda/python:3.12

ENV ANT_VERSION=1.10.14
ENV ANT_HOME=/opt/ant

# Install system dependencies for Ant and Saxon
RUN dnf install -y wget tar gzip unzip java-11-amazon-corretto-headless && dnf clean all

ENV JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto

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

# Create application directory structure
RUN mkdir -p /opt/cdcp

WORKDIR /opt/cdcp
RUN mkdir -p dist && mkdir -p transcriptions && mkdir -p cudl-data-source

# Copy build files and XSLT (unchanged)
COPY ./bin bin
COPY ./xslt xslt

# Copy Python source to Lambda task root
COPY ./src/ ${LAMBDA_TASK_ROOT}/

# Set Lambda handler
CMD ["handler.handler"]
