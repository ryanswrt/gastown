{
  description = "Multi-agent orchestration system for Claude Code with persistent work tracking";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    beads.url = "github:gastownhall/beads";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      beads,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        beadsPkg = beads.packages.${system}.default;
        # Single source of truth: parse Version from internal/cmd/version.go
        # so the flake never drifts from the Go const.
        versionMatch = builtins.match
          ".*Version = \"([^\"]+)\".*"
          (builtins.readFile ./internal/cmd/version.go);
        gtVersion =
          if versionMatch == null
          then throw "could not parse Version from internal/cmd/version.go"
          else builtins.head versionMatch;
      in
      {
        packages = {
          gt = pkgs.buildGoModule {
            pname = "gt";
            version = gtVersion;
            src = ./.;
            vendorHash = "sha256-PQT/Xq9na3vI8Oy9INBYJf3GsiN5IxAVCxrNLhyIpO8=";

            ldflags = [
              "-X github.com/gastownhall/gastown/internal/cmd.Build=nix"
              "-X github.com/steveyegge/gastown/internal/cmd.BuiltProperly=1"
            ];

            subPackages = [ "cmd/gt" ];

            meta = with pkgs.lib; {
              description = "Multi-agent orchestration system for Claude Code with persistent work tracking";
              homepage = "https://github.com/gastownhall/gastown";
              license = licenses.mit;
              mainProgram = "gt";
            };
          };
          default = self.packages.${system}.gt;
        };

        apps = {
          gt = flake-utils.lib.mkApp {
            drv = self.packages.${system}.gt;
          };
          default = self.apps.${system}.gt;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            beadsPkg
            pkgs.go_1_25
            pkgs.gopls
            pkgs.gotools
            pkgs.go-tools
          ];
        };
      }
    );
}
