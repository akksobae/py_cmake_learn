# mypkg_base と同様の変数定義。ただし、一部は後で docker-compose.yml から与える。
ARG baseimage
FROM ${baseimage}

ARG projectname
RUN [ -n "${projectname}" ]

RUN mkdir /${projectname}/test
COPY test.bash /${projectname}/test
