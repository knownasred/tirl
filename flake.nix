{
  description = "zig-scene - Zig development environment";

  inputs = {
    zig2nix.url = "github:Cloudef/zig2nix";
  };

  outputs = {zig2nix, ...}: let
    flake-utils = zig2nix.inputs.flake-utils;
  in (flake-utils.lib.eachDefaultSystem (system: let
    env = zig2nix.outputs.zig-env.${system} {};
  in
    with builtins;
    with env.pkgs.lib; rec {
      packages.foreign = env.package {
        src = cleanSource ./.;
        nativeBuildInputs = with env.pkgs; [wayland-scanner];
        buildInputs = with env.pkgs; [
          wayland
          wayland-protocols
          libxkbcommon
          libGL
        ];
        zigPreferMusl = true;
      };

      packages.default = packages.foreign.override (attrs: {
        zigPreferMusl = false;
        zigWrapperBins = with env.pkgs; [];
        zigWrapperLibs = attrs.buildInputs or [];
      });

      apps.bundle = {
        type = "app";
        program = "${packages.foreign}/bin/zig_scene";
      };

      apps.default = env.app [env.pkgs.wayland-scanner] "zig build run -- \"$@\"";
      apps.build = env.app [env.pkgs.wayland-scanner] "zig build \"$@\"";
      apps.test = env.app [] "zig build test -- \"$@\"";
      apps.docs = env.app [] "zig build docs -- \"$@\"";
      apps.zig2nix = env.app [] "zig2nix \"$@\"";

      devShells.default = env.mkShell {
        nativeBuildInputs = with env.pkgs;
          [
            tinymist
            typst
            zig-zlint
            vscode-extensions.vadimcn.vscode-lldb
          ]
          ++ packages.default.nativeBuildInputs
          ++ packages.default.buildInputs
          ++ packages.default.zigWrapperBins
          ++ packages.default.zigWrapperLibs;

        shellHook = ''
          mkdir -p .zed
          ln -sfn "${env.pkgs.vscode-extensions.vadimcn.vscode-lldb}/share/vscode/extensions/vadimcn.vscode-lldb/adapter/codelldb" .zed/codelldb
        '';
      };
    }));
}
