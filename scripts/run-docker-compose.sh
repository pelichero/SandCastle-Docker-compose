#!/usr/bin/env bash

##########
#Profiles#
##########
PROFILE="dockerdev"
PROFILE_FRONT="development"

########
#Colors#
########
RED=$'\e[1;31m'
GRN=$'\e[1;32m'
YEL=$'\e[1;33m'
BLU=$'\e[1;34m'
MAG=$'\e[1;35m'
CYN=$'\e[1;36m'
END=$'\e[0m'

##########
#Commands#
##########
DOCKER_COMPOSE_CMD="docker-compose"
DOCKER_CMD="docker"

#######
#Paths#
#######
DOCKER_COMPOSE_PATH="./docker"

############
#Containers#
############
DEV_SERVICES="postgres redis rf-api"
DEV_SERVICES_PLUS_FRONT="postgres redis rf-api precificador-front"
ALL_SERVICES="postgres postgres-bigdata redis rf-api precificador"
ALL_SERVICES_PLUS_FRONT="postgres postgres-bigdata redis rf-api precificador-front precificador"

#############
#Desatachado#
#############
DETACHED=

###########
#Finalizar#
###########
TERMINATE=

############################################
#Env variables usadas no docker-compose.yml#
############################################
export PROJECTS_PATH=~/projetos

##################################################################################################################
# Para que o precificador consiga se conectar ao host do gw-aereo (upado por fora), é necessário                 #
# configurar no docker-compose um "extra-host", de modo que "localhost" refere-se ao localhost do container      #
# do precificador e não ao docker-host, a variável abaixo permite que o docker-compose substitua o valor         #
# pelo ip da maquina local ao qual o docker-compose será startado                                                #
##################################################################################################################
case "$(uname -s)" in
    Linux*)  LOCALHOST_DOCKER=$(ip route get 8.8.8.8 | awk '{print $NF; exit}') ;;
    Darwin*) LOCALHOST_DOCKER=$(ifconfig en0 | awk '$1 == "inet" {print $2}') ;;
esac
export LOCALHOST_DOCKER

checkOptions() {
    for arg in $*; do
        case $arg in
            -d)
                DETACHED="-d"
            ;;
            -s)
                TERMINATE="TERMINATE"
            ;;
        esac
    done
}

##################################################################################################################
# Utilizado quando há necessidade de subir containers passados via parametro                                     #
##################################################################################################################
custom(){
    clear

    shift 1
    printConsole " Subindo os containers: $* "
    dockerUp "$*" "${DETACHED}"
}

##################################################################################################################
# Utilizado apenas para subir os serviços de banco de dados e cache, também é possível                           #
# subir o serviço de fronto com a opção -f                                                                       #
# O serviço PRECIFICADOR deve ser startado por fora, assim como o gw-aereo e rf-api (caso haja necessidade)      #
##################################################################################################################
dev(){
    clear

    CONTAINERS=${DEV_SERVICES}

    checkOptions $*

    for arg in $*; do
        case $arg in
            -b)
                if ! [ ${TERMINATE} ]; then
                    buildRfApi
                fi
            ;;
            -f)
                CONTAINERS=${DEV_SERVICES_PLUS_FRONT}
                if [ ! ${TERMINATE} ]; then
                    compilePrecifierFront
                fi
            ;;
        esac
    done

    if [ ${TERMINATE} ]; then
        terminate "${CONTAINERS}"
    else
        printConsole " Subindo os containers: [${CONTAINERS}] "
        dockerUp "${CONTAINERS}"
    fi
}

##################################################################################################################
# Utilizado para subir todos os serviços utilizados pelo precificador no docker                                  #
# também é possível buildá-los com a opção -b e subir o precificador-front com a opção -f                        #
# O serviço GW-AEREO não será upado no docker, sendo necessário subi-lo por fora (caso haja necessidade)         #
##################################################################################################################
all(){
    clear

    CONTAINERS=${ALL_SERVICES}

    checkOptions $*

    for arg in $*; do
        case $arg in
            -b)
                if ! [ ${TERMINATE} ]; then
                    buildPrecifier
                    buildRfApi
                fi
            ;;
            -f)
                CONTAINERS=${ALL_SERVICES_PLUS_FRONT}
                if ! [ ${TERMINATE} ]; then
                    compilePrecifierFront
                fi
            ;;
        esac
    done

    if [ ${TERMINATE} ]; then
        terminate "${CONTAINERS}"
    else
        printConsole " Subindo os containers: [${CONTAINERS}] "
        dockerUp "${CONTAINERS}" "${DETACHED}"
    fi
}

terminate(){
    printConsole " Parando o docker-compose"
    ${DOCKER_COMPOSE_CMD} -f ${DOCKER_COMPOSE_PATH}/docker-compose.yml stop
}

clear(){
    printConsole " Removendo as versões anteriores"
    ${DOCKER_COMPOSE_CMD} -f ${DOCKER_COMPOSE_PATH}/docker-compose.yml rm -f
}

buildPrecifier(){
    printConsole " Building precificador image com profile: ${PROFILE}"
    mvn clean install -P${PROFILE} -DskipTests
}

buildRfApi(){
    printConsole " Building rfapi image com profile: ${PROFILE}"
    mvn clean install -f ${PROJECTS_PATH}/rf-api/pom.xml -DskipTests
}

compilePrecifierFront(){
    printConsole " Compiling precificador-front image com profile: ${PROFILE_FRONT}"
    npm run build ${PROFILE_FRONT} --prefix ${PROJECTS_PATH}/precificador-front
}

dockerUp(){
    ${DOCKER_COMPOSE_CMD} -f ${DOCKER_COMPOSE_PATH}/docker-compose.yml build
    ${DOCKER_COMPOSE_CMD} -f ${DOCKER_COMPOSE_PATH}/docker-compose.yml up ${DETACHED} $1
}

helper() {
echo "
    Usage: $0 COMMAND

    Options:

    --clear   Limpa versoes anteriores

    --custom  containers aceitos [$ALL_SERVICES] (todos disponíveis no docker-compose.yml)
              (Ex: --custom postgres redis)

    --dev     Sobe apenas os container do redis e postgres.
        -b    Builda os projetos antes de subir os containers (rf-api)
        -f    Compila e sobe o container com o front
        -d    Modo detached, rodará em background.
        -s    Termina o docker-compose (quando foi iniciado em background). Informe os mesmos argumentos
              que foram utilizados para iniciar o docker.

    --all     Builda o precificador e sobe as imagens do rf-api e precificador no docker.
        -b    Builda os projetos antes de subir os containers (rf-api e precificador)
        -f    Compila e sobe o container com o front
        -d    Modo detached, rodará em background.
        -s    Termina o docker-compose (quando foi iniciado em background). Informe os mesmos argumentos
              que foram utilizados para iniciar o docker.
"
  exit 1
}

printConsole(){
    printf "%s\n" "${RED} ---> $1 ${END}"
}

case $1 in
    --dev) dev $*;;
    --all) all $*;;
    --custom) custom $*;;
    --clear) clear ;;
    *) helper ;;
esac