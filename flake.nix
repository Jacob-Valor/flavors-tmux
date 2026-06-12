{
  description = "flavors-tmux development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            zig_0_16
            bash
            git
            tmux
            shellcheck
            jq
          ];

          shellHook = ''
            echo "flavors-tmux dev environment"
            echo "  zig $(zig version)"
            echo "  run: zig build test"
          '';
        };
      });
}
