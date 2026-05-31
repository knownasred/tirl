FROM alpine:3.22 AS build

RUN wget -qO- https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz | tar -xJ -C /opt --strip-components=1
ENV PATH="/opt:${PATH}"

WORKDIR /app
COPY build.zig build.zig.zon ./
COPY src/ src/

RUN zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-linux-musl -Dgui=false --summary all

FROM scratch

COPY --from=build /app/zig-out/bin/zig_scene_web /zig_scene_web

EXPOSE 8080

ENTRYPOINT ["/zig_scene_web"]
