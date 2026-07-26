{
  description = "Monarchic source flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          source = pkgs.lib.cleanSourceWith {
            src = ./.;
            filter = path: type:
              let
                base = baseNameOf path;
              in
              !(base == ".jj"
                || base == ".git"
                || base == "result"
                || base == "node_modules"
                || base == "target"
                || base == "dist"
                || base == "build");
          };
        in
        {
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "monarchic-source";
            version = "0.1.0";
            src = source;
            dontConfigure = true;
            dontBuild = true;
            installPhase = ''
              runHook preInstall
              mkdir -p "$out"
              ln -s ${source} "$out/src"
              printf '%s\n' ${source} > "$out/source-path"
              runHook postInstall
            '';
          };
        });

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              bash
              cacert
              curl
              git
              jq
              just
              gnumake
              nodejs
              pnpm
              yarn
              go
              rustc
              cargo
              python3
              jdk
              maven
              gradle
              dotnet-sdk
              elixir
              php
              composer
              cabal-install
              ghc
              lua
              zig
              sbt
              dart
              swift
              julia
              opam
              dune_3
            ];
          };
        });
    };
}
