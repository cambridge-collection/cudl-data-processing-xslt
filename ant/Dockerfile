FROM eclipse-temurin:17-jdk-jammy

ENV ANT_VERSION=1.10.14
ENV ANT_HOME=/opt/ant


# Install unzip
RUN apt-get update -y && apt-get upgrade -y
RUN apt-get install -y unzip

# change to tmp folder
WORKDIR /tmp

# Download and extract apache ant to opt folder
RUN wget --no-check-certificate --no-cookies "https://dlcdn.apache.org//ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz" \
    && wget --no-check-certificate --no-cookies "https://dlcdn.apache.org//ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz.sha512" \
    && echo "$(cat apache-ant-${ANT_VERSION}-bin.tar.gz.sha512) apache-ant-${ANT_VERSION}-bin.tar.gz" | sha512sum -c \
    && tar -zvxf "apache-ant-${ANT_VERSION}-bin.tar.gz" -C /opt/ \
    && ln -s /opt/apache-ant-${ANT_VERSION} /opt/ant \
    && rm -f "apache-ant-${ANT_VERSION}-bin.tar.gz" \
    && rm -f "apache-ant-${ANT_VERSION}-bin.tar.gz.sha512"

# add ant executables to path
RUN update-alternatives --install "/usr/bin/ant" "ant" "/opt/ant/bin/ant" 1 && \
    update-alternatives --set "ant" "/opt/ant/bin/ant"

# Download Saxon XSLT
RUN mkdir saxon \
    && wget --no-check-certificate --no-cookies "https://github.com/Saxonica/Saxon-HE/releases/download/SaxonHE12-4/SaxonHE12-4J.zip" \
    && unzip SaxonHE12-4J.zip -d saxon \
    && mv saxon /opt/

ENV CLASSPATH=/opt/saxon/saxon-he-12.4.jar

RUN mkdir -p /opt/cdcp/
COPY ./bin /opt/cdcp/bin
COPY ./xslt /opt/cdcp/xslt
    #&& cp ./xslt /opt/cdcp/xslt
