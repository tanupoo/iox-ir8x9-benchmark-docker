IR8x9 IOx Docker版アプリの起動の例
==================================

- 2021年11月くらいの話。
- sysbenchを動かす例。
- 以前のDockerイメージからLXC版IOxパッケージを作る黒魔術ではない。

## Dockerを使ったアプリのビルド

- マルチステージビルドでさくっと作る。便利。
- ちなみに、このDockefileができるまで、色々とトライアンドエラーの連続だった。

```
% cat Dockerfile
# dev
FROM devhub-docker.cisco.com/iox-docker/ir800/base-rootfs as builder
RUN opkg update
RUN opkg install coreutils
RUN opkg install git pkgconfig
RUN opkg install iox-toolchain git pkgconfig
WORKDIR /build
RUN git clone https://github.com/akopytov/sysbench && \
        cd sysbench && \
        git checkout 1.0.20 && \
        ./autogen.sh && \
        ./configure --prefix=/build --without-mysql --enable-static && \
        make && \
        make install
RUN mkdir /build/lib && cp /lib/libgcc_s.so* /build/lib/

# app
FROM devhub-docker.cisco.com/iox-docker/ir800/base-rootfs
RUN opkg update
RUN opkg install coreutils
RUN (opkg install tzdata ; exit 0) && \
        cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
COPY --from=builder /build/bin/sysbench /bin/
COPY --from=builder /build/share/sysbench /usr/share/sysbench
COPY --from=builder /build/lib /lib
COPY benchmark.sh /bin/
```

コンテナのビルド

```
docker build -t ir8x9-benchmark .
```

## DockerfileのCMDについて

IOX環境ではログやアプリデータ用のディレクトリが存在している。
アプリの中でこれらのディレクトリを使っている場合に、
手元の環境では存在していないためエラーになる。
CMDで自動起動すると、コンテナそのものがエラーになりデバッグできない。
(起動時に上書きできるけど)

よって、手元でデバッグする事を考えると、CMDは書かないという選択もある。
activateする時に、package.yamlのtargetで指定できる。

## パッケージの作成

Dockerイメージを含んだIOxパッケージを作る。

```
mkdir pkg
vi pkg/package.yaml
```

IOS 15.8(3)M7に同梱されているIOxではpackageスキーマ2.12は使えない。
2.7はOKだった。

package.yaml

```
descriptor-schema-version: "2.7"
info:
  name: ir8x9-linux-test
  description: "Ubuntu Linux with sysbench"
  version: "a1"
app:
  cpuarch: "x86_64"
  type: docker
  env:
    PATH: /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  resources:
    profile: custom
    cpu: 512
    memory: 64
    disk: 2
    network:
    - interface-name: eth0
      ports: {}
  startup:
    rootfs: rootfs.tar
    target:
    - /bin/sh
    - -c
    - /bin/benchmark.sh
```

package.yamlを先に作らないとデフォルトで下記のpackage.yamlが作られるのでハマる。

```
descriptor-schema-version: "2.2"
info:
  name: ir8x9-sysbench-cpu
  description: buildkit.dockerfile.v0
  version: latest
app:
  cpuarch: x86_64
  env:
    PATH: /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  resources:
    cpu: "400"
    memory: "128"
    network:
    - interface-name: eth0
      ports: {}
    profile: custom
  startup:
    rootfs: rootfs.tar
    target:
    - /bin/bash
  type: docker
```

パッケージ作成の前に必要ならioxclientを初期設定する。
ioxclientについては、[What is ioxclient?](https://developer.cisco.com/docs/iox/#what-is-ioxclient)を参照する。

```
ioxclient pr c
```

DockerイメージからDocker版IOxパッケージを作る。

```
ioxclient docker pkg ir8x9-benchmark pkg/
```

## パッケージのインストール

パッケージのインストールから起動してログ取得まで。

```
ioxclient app in benchmark pkg/package.tar
ioxclient app act benchmark
ioxclient app appdata upload benchmark appenv.txt appenv.txt
ioxclient app start benchmark
ioxclient app logs download benchmark benchmark.log
```

よく使うコマンド

```
ioxclient app logs info benchmark
ioxclient app appdata delete benchmark appenv.txt
ioxclient app console benchmark
ioxclient app stop benchmark
```

## 一連の流れ

```
docker build -t ir8x9-benchmark .
ioxclient docker pkg ir8x9-benchmark pkg/
ioxclient app in benchmark pkg/package.tar
ioxclient app act benchmark
ioxclient app appdata upload benchmark appenv.txt appenv.txt
ioxclient app start benchmark
ioxclient app logs download benchmark benchmark.log

ioxclient app logs info benchmark
ioxclient app appdata delete benchmark appenv.txt
ioxclient app console benchmark
ioxclient app stop benchmark
```

