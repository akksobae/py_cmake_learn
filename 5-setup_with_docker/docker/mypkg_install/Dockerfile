# mypkg_base と同様の変数定義。ただし、一部は後で docker-compose.yml から与える。
ARG baseimage
FROM ${baseimage}

ARG projectname=myproject
ARG packagename=mypkg
RUN [ -n "${projectname}" ] \
    && [ -n "${packagename}" ]

# mypkg をコピーするディレクトリを設定し、コピー (ADD) する。
RUN mkdir -p /${projectname}/lib/${packagename}
WORKDIR /${projectname}
ADD ${packagename}.tar.gz /${projectname}/lib/${packagename}
WORKDIR /${projectname}/lib/${packagename}

# mypkg をビルド・インストールする。
RUN cmake .
RUN make
RUN make install