ARG CONDA_VER=latest
ARG OS_TYPE=x86_64
ARG PY_VER=3.8
ARG PANDAS_VER=1.3

FROM nvidia/cuda:11.4.3-cudnn8-devel-ubuntu20.04

RUN echo "tzdata tzdata/Areas select America"> timezone.txt
RUN echo "tzdata tzdata/Zones/Europe select New_York">> timezone.txt

RUN apt clean && \
    rm -r /var/lib/apt/lists/* \
    && apt update
RUN DEBIAN_FRONTEND=noninteractive TZ="America/New_York" apt -y install tzdata
RUN apt update \
    && apt install -y software-properties-common apt-utils locales
RUN apt update \
    && apt install -y --allow-unauthenticated gnupg

RUN apt update \ 
    && apt install -y --allow-unauthenticated wget unzip sudo lsof python3-pip curl jq vim net-tools

RUN apt update \ 
    && apt -y --allow-unauthenticated install sudo ssh wget
#RUN DEBIAN_FRONTEND=noninteractive apt -y --allow-unauthenticated install --no-install-recommends ubuntu-desktop
#RUN apt -y --allow-unauthenticated install ubuntu-desktop xubuntu-desktop kubuntu-desktop

# Use the above args
ARG CONDA_VER
ARG OS_TYPE
# Install miniconda to /miniconda
RUN curl -LO "https://repo.anaconda.com/miniconda/Miniconda3-${CONDA_VER}-Linux-${OS_TYPE}.sh"
RUN bash Miniconda3-${CONDA_VER}-Linux-${OS_TYPE}.sh -p /miniconda -b
RUN rm Miniconda3-${CONDA_VER}-Linux-${OS_TYPE}.sh
ENV PATH=/miniconda/bin:${PATH}
RUN conda update -y conda
RUN conda init

ARG PY_VER
ARG PANDAS_VER
# Install packages from conda
RUN conda install -c anaconda -y python=${PY_VER}
RUN conda install -c anaconda -y \
    pandas=${PANDAS_VER}

# 注意使用root来启动训练任务，区分大小写
USER root
# 添加一个用户组admin，并添加系统用户admin，赋予编号505
RUN groupadd -r -g 505 admin && useradd --no-log-init -m -r -g 505 -u 505 admin -s /bin/bash -p admin && mkdir -p /data && chown -fR admin:admin /data && \
echo admin:admin | chpasswd
RUN adduser admin sudo

# 安装jupyterlab等python包
RUN pip install jupyterlab pylama pylint yacs torch\
    && chmod 777 /root \
    && ln -s `which jupyter` /usr/local/bin/jupyter || true \
    && apt install -y --allow-unauthenticated iputils-ping \
    && pip install tb-nightly \
    && mkdir /result \
    && mkdir /model \
    && mkdir /log \
    && mkdir /summary \
    && mkdir /inference_result \
    && mkdir /evaluation_result \
    && mkdir -p /code \
    && mkdir -p /scripts
# ailice相关的配置，需要的同学进行配置
# && export TVM_HOME=/root/ailiceDependency/tvm_12cfe4a:$TVM_HOME \
# && export PYTHONPATH=/root/ailice/python/:/root/ailiceDependency/tvm_12cfe4a/python:/root/ailiceDependency/tvm_12cfe4a/topi/python/:$PYTHONPATH

# 安装vscode
# 先创建一个assets文件夹，把vscode上传到oss上，再下载到这个assets文件夹里
RUN mkdir -p asserts
# 这个oss路径是示例，请提供自己的oss路径
COPY code-server_4.1.0_amd64.deb asserts

RUN dpkg -i asserts/code-server_4.1.0_amd64.deb && rm asserts/code-server_4.1.0_amd64.deb

# 安装VSCODE插件
RUN code-server --extensions-dir ~/.local/share/code-server/extensions --install-extension  ms-python.black-formatter --force &
RUN code-server --extensions-dir ~/.local/share/code-server/extensions --install-extension  ms-python.python --force &
RUN code-server --extensions-dir ~/.local/share/code-server/extensions --install-extension  ms-python.vscode-pylance --force &
RUN code-server --extensions-dir ~/.local/share/code-server/extensions --install-extension  ms-toolsai.jupyter --force &
RUN code-server --extensions-dir ~/.local/share/code-server/extensions --install-extension  ms-toolsai.jupyter-keymap --force &
RUN code-server --extensions-dir ~/.local/share/code-server/extensions --install-extension  ms-toolsai.jupyter-renderers --force &
RUN code-server --extensions-dir ~/.local/share/code-server/extensions --install-extension  njpwerner.autodocstring --force &
RUN code-server --extensions-dir ~/.local/share/code-server/extensions --install-extension  VisualStudioExptTeam.vscodeintellicode-1.2.30.vsix --force &

# Install OpenJDK-8
RUN apt update && \
    apt install -y openjdk-8-jdk && \
    apt install -y ant && \
    apt clean;

# Fix certificate issues
RUN apt update && \
    apt install ca-certificates-java && \
    apt clean && \
    update-ca-certificates -f;

# Setup JAVA_HOME -- useful for docker commandline
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/
RUN export JAVA_HOME

USER root
