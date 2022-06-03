FROM python:3.10 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/opt/riscv32/bin/:/opt/lm32/bin:$PATH

WORKDIR  /usr/local/src/

RUN apt update \
  && apt install --no-install-recommends -y build-essential libipt-dev libdebuginfod-dev libgmp3-dev libmpc-dev libmpfr-dev texinfo libisl-dev zlib1g-dev 

RUN curl -O https://ftp.gnu.org/gnu/binutils/binutils-2.38.tar.xz \
  && tar xf binutils-2.38.tar.xz \
  && cd binutils-2.38 \
  && mkdir build \
  && cd build \
  && ../configure --prefix=/opt/lm32 --target=lm32-elf --with-sysroot --disable-nls --disable-werror \
  && make -j$(nproc) \
  && make install

WORKDIR /usr/local/src/binutils-2.38

RUN rm -rf build \
  && mkdir build \
  && cd build \
  && ../configure --prefix=/opt/riscv32 --target=riscv32-elf --with-arch=rv32gc_zicsr --with-abi=ilp32 --with-sysroot --disable-nls --disable-werror \
  && make -j$(nproc) \
  && make install

WORKDIR /usr/local/src/

RUN curl -O https://ftp.gnu.org/gnu/gcc/gcc-12.1.0/gcc-12.1.0.tar.xz \
  && tar xf gcc-12.1.0.tar.xz

WORKDIR /usr/local/src/gcc-12.1.0
RUN mkdir build \
  && cd build \
  && ../configure --prefix=/opt/lm32 --target=lm32-elf --enable-languages="c,c++" --disable-nls --without-headers \
  && make all-gcc -j$(nproc) \
  && make all-target-libgcc -j$(nproc) \
  && make install-gcc \
  && make install-target-libgcc

WORKDIR /usr/local/src/gcc-12.1.0

RUN rm -rf build \
  && mkdir build \
  && cd build \
  && ../configure --prefix=/opt/riscv32 --target=riscv32-elf --with-arch=rv32gc_zicsr --with-abi=ilp32 --enable-languages="c,c++" --disable-nls --without-headers \
  && make all-gcc -j$(nproc) \
  && make all-target-libgcc -j$(nproc) \
  && make install-gcc \
  && make install-target-libgcc

FROM python:3.10

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/opt/riscv32/bin/:/opt/lm32/bin:$PATH

COPY --from=builder /opt/lm32 /opt/lm32
COPY --from=builder /opt/riscv32 /opt/riscv32

COPY litex_setup.py /usr/local/src

WORKDIR  /usr/local/src/

RUN apt update \
  && apt install --no-install-recommends -y yosys libftdi1-dev cmake libboost-thread-dev libboost-iostreams-dev libboost-filesystem-dev libboost-program-options-dev libeigen3-dev

RUN chmod +x litex_setup.py \
  && ./litex_setup.py --init --install \
  && pip install meson ninja apycula \
  && git clone https://github.com/YosysHQ/icestorm.git icestorm \
  && cd icestorm \
  && make -j$(nproc) \
  && make install \
  && cd .. \
  && git clone https://github.com/YosysHQ/nextpnr nextpnr \
  && cd nextpnr \
  && cmake -DARCH="ice40;gowin" -DCMAKE_INSTALL_PREFIX=/usr/local . \
  && make -j$(nproc) \
  && make install

COPY 001.patch /usr/local/src/litex

WORKDIR /usr/local/src/litex

RUN patch -p1 < 001.patch \
  && python setup.py install

# python3 -m litex_boards.targets.muselab_icesugar --build --cpu-type=vexriscv --timer-uptime

#  python3 -m litex_boards.targets.digilent_arty_s7 --build --synth-mode yosys
