# Machine Learning PhenoCam playground

This is a playground of Machine Learning (ML) models as applied to PhenoCam time series, predicting either Gcc values from Daymet climate drivers, or predicting GPP using the same Daymet climate drivers and Gcc as a constraint on phenology (rough stand in for fAPAR). The model architecture is identical in both cases, and relies on an LSTM model basis. 

As this only serves demonstration purposes, for now, no hyper-parameter tuning is applied (model structure is ad-hoc and can be wasteful on resources). Other model structures and questions can be answered with this data and I'll add other examples in due time.

## Use

### R project

To run the project clone it locally and open the `Rproj` file in the RStudio IDE.

Analysis scripts are stored in the `analysis` folder and should be run in sequence. Where possible, run the analysis on an accelerated platform (GPU) rather than on CPU. The Dockerfile included with this project sets up a reproducible R environment to run all code (see below).

### Docker images

It is adviced to run this code on an accelerated setup (CUDA GPU). To ensure consistency across platforms, and not deal with a zoo of required CUDA drivers which can conflict due to platform and ML platforms already in use I suggest to use the included docker file (and environment). To install and use docker on your system I refer to the [docker documentation](https://www.docker.com/).

The dockerfile included provides a GPU torch setup. You can build
this docker image using the below command. This will download the NVIDIA CUDA
drivers for GPU support, the tidyverse, rstudio IDE and quarto publishing
environment. Note that this setup will require some time to build given the
the large downloads involved. Once build locally no further downloads will be
required.

```
# In the main project directory run
docker build -f Dockerfile -t rocker-torch .
```

To spin up a GPU docker image use **in the project directory**:

```
docker run --gpus all -e PASSWORD="rstudio" -p 5656:8787 -v $(pwd):/workspace rocker-torch
```

In any browser use the [http://localhost:5656](http://localhost:5656) url to access the docker RStudio Server instance which should be running.

The password to the RStudio Server instance is set to `rstudio` when using the above commands (but can and should be changed if the computer is exposed to a larger institutional network). This is not a secured setup, use a stronger password or a local firewall to avoid abuse.

Data will be mounted in the docker virtual machine at `/workspace` and is fully accessible (writing and reading of files on your local file system).
