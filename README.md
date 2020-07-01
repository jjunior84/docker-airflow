# Docker Airflow

Repository contains **Dockerfile** and other files to support the automated build of a [Docker](https://www.docker.com/) image with [apache-airflow](https://github.com/apache/airflow) published to the public [Docker Hub Registry](https://hub.docker.com/repository/docker/buzz84/docker-airflow).

## Informations and Prerequisites

* Based on Python (python:3.7-slim) official Image [python:3.7-slim]
* Install [Docker](https://www.docker.com/)
* Install [Docker Compose](https://docs.docker.com/compose/install/)
* Following the Airflow release from [Python Package Index](https://pypi.python.org/pypi/apache-airflow)

## Installation

Pull the image from the Docker repository.

    docker push buzz84/docker-airflow

 **OR**

 Clone the repository and build and build through command

    docker build --rm -t buzz84/docker-airflow .


## Usage

Entrypoint for this docker was setting up to accept various entries, the default will start a container running airflow with **SequencialExecutor**, it means several limitations, good for assembly DAGs without execute them:

    docker run -d -p 8080:8080 buzz84/docker-airflow webserver

If you want to run another executor, with a better and complex environment, design a docker-composer.yml file to do that, and execute through it

Example file for use of **CeleryExecutor** in the repository:

    docker-compose -f docker-compose.yml up -d

As you can see in composer file we set an fernet_key to be used by the docker-airflow to set the same key on startup across all containers, to generate a fernet_key you can use the follow command:

    docker run buzz84/docker-airflow python -c "from cryptography.fernet import Fernet; FERNET_KEY = Fernet.generate_key().decode(); print(FERNET_KEY)"


## Install custom python package

The entrypoint script is read to take the file requirement.txt from the root system of you container and install all additional package that you want, you just have to mount the volume with the file or add it to the composer yaml file to do that for you

## UI Links

- Airflow: [localhost:8080](http://localhost:8080/)
- Flower: [localhost:5555](http://localhost:5555/)


## Scale the number of workers

Easy scaling using docker-compose:

    docker-compose -f docker-compose-CeleryExecutor.yml scale worker=5

This can be used to scale to a multi node setup using docker swarm.

## Running extra command in your docker

As soon as the entrypoint has an alternative exception to run the commands no predefined in its script (webserver, scheduler, worker...)

It means that you could run any other commands inside of you docker container, like airflow commands, python commands, even open the bash from the container (this last one, very useful to check your container installation)

    docker run --rm -ti buzz84/docker-airflow airflow list_dags
    docker run --rm -ti buzz84/docker-airflow bash
    docker run --rm -ti buzz84/docker-airflow ls -alrt

# Thanks

Apache Airflow contributors for this marvelous tool 

[Puckel](https://github.com/puckel/docker-airflow) for the excellent docker-airflow project (that a based so much to build this one)