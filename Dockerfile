FROM lambci/lambda:build-ruby2.5

ARG MYSQL2_VERSION

RUN gem install gem-compiler && \
  yum install -y yum-plugin-ovl && yum clean all && \
  yum install -y mysql-libs mysql-devel zip && \
  gem fetch mysql2 -v ${MYSQL2_VERSION} && \
  gem compile mysql2-${MYSQL2_VERSION}.gem && \
  mv mysql2-${MYSQL2_VERSION}-x86_64-linux.gem /tmp && \
  mkdir -p /opt/lib && \
  cp -L /usr/lib64/mysql/libmysqlclient.so.18 /opt/lib && \
  cd /opt && \
  zip -yr /tmp/mysql-libs.zip ./*
