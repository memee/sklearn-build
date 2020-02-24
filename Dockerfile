# 1. Build stage
FROM lambci/lambda:build-python3.8 AS build

RUN yum update -y && \
    yum install -y \
    # utils
    findutils \
    zip \
    # additional libraris for optimized linear algebra
    atlas-devel \
    atlas-sse3-devel \
    blas-devel \
    lapack-devel && \
    yum clean all && rm -rf /var/cache/yum

WORKDIR /build

# Create VENV and use pip to install everything
RUN python -m venv --copies lambda_build && \
    chmod +x lambda_build/bin/activate && \
    source lambda_build/bin/activate && \
    pip install --upgrade pip wheel

COPY ./requirements.txt requirements.txt

# Install everything
# we temporarily not do it from requirements file
RUN source lambda_build/bin/activate && \
    pip install --upgrade pip wheel && \
    pip install --no-binary :all: cython && \
    pip install --no-binary :all: numpy && \
    pip install --no-binary :all: scipy && \
    pip install --no-binary :all: scikit-learn

# Copy shared libraries into lib and zip
RUN source lambda_build/bin/activate && \
    pip uninstall -y wheel pip cython && \
    LIBDIR="${VIRTUAL_ENV}/lib/python3.8/site-packages/lib/" && \
    mkdir -p ${LIBDIR} && \
    cp /usr/lib64/atlas/* $LIBDIR && \
    cp /usr/lib64/libquadmath.so.0 $LIBDIR && \
    cp /usr/lib64/libgfortran.so.4 $LIBDIR && \
    # Strip
    find ${VIRTUAL_ENV}/lib/python3.8/site-packages/ -name "*.so" | xargs strip && \
    # Zip
    cd ${VIRTUAL_ENV}/lib/python3.8/ && \
    mv site-packages/ python/ && \
    zip -r -9 -q /build/layer.zip python/ && \
    rm -rf /root/.cache /var/cache/yum && yum clean all

# 2. Copy Data Stage
FROM amazonlinux:2017.03.1.20170812
WORKDIR /build
COPY --from=build /build/layer.zip .
CMD cp /build/layer.zip /outputs
