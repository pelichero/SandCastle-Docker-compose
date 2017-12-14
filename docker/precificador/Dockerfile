FROM docker.reservafacil.tur.br/reservafacil/tomcat:tc7.0-jre8

LABEL maintainer="Arquitetura"

ENV http_proxy http://192.168.110.1:3128
ENV https_proxy http://192.168.110.1:3128

EXPOSE 8080
EXPOSE 5005

RUN apt-get update
RUN apt-get install -y curl
RUN curl -o /usr/share/tomcat7/lib/postgresql-9.4-1201.jdbc41.jar https://jdbc.postgresql.org/download/postgresql-9.4-1201.jdbc41.jar
