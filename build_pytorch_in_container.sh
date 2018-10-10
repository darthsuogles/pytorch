#!/bin/bash

set -eu -o pipefail

nvidia-docker build docker \
	      -t pytorch-builder \
	      -f-<<'_DOCKERFILE_EOF_'
FROM nvidia/cuda:9.0-cudnn7-devel-ubuntu16.04
ARG PYTHON_VERSION=3.7

RUN apt-get update && apt-get install -y --no-install-recommends \
         build-essential \
         cmake \
         git \
         curl \
         vim \
         ca-certificates \
         libjpeg-dev \
         libpng-dev &&\
     rm -rf /var/lib/apt/lists/*


RUN curl -o ~/miniconda.sh -O  https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh  && \
     chmod +x ~/miniconda.sh && \
     ~/miniconda.sh -b -p /opt/conda && \
     rm ~/miniconda.sh && \
     /opt/conda/bin/conda install -y python=$PYTHON_VERSION numpy pyyaml scipy ipython mkl mkl-include cython typing && \
     /opt/conda/bin/conda install -y -c pytorch magma-cuda92 && \
     /opt/conda/bin/conda clean -ya

ENV PATH /opt/conda/bin:$PATH

ENV TORCH_CUDA_ARCH_LIST="3.5 5.2 6.0 6.1 7.0+PTX" \
    TORCH_NVCC_FLAGS="-Xfatbin -compress-all" \
    CMAKE_PREFIX_PATH="$(dirname $(which conda))/../"

# This must be done before pip so that requirements.txt is available
WORKDIR /opt/pytorch

_DOCKERFILE_EOF_

docker rm -f pytorch-builder-env >&/dev/null || true

nvidia-docker run -d \
	      -v $PWD:/opt/pytorch \
	      --name pytorch-builder-env \
	      pytorch-builder \
	      sleep infinity

nvidia-docker exec \
	      pytorch-builder-env \
	      pip install -v .
