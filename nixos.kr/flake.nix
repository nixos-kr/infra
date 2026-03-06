{
  nixConfig = {
    extra-substituters = "https://cache.nixos.asia/oss";
    extra-trusted-public-keys = "oss:KO872wNJkCDgmGN3xy9dT89WAhvv13EiKncTtHDItVU=";
  };

  inputs = {
    emanote.url = "github:srid/emanote";
    emanote.inputs.emanote-template.follows = "";
    nixpkgs.follows = "emanote/nixpkgs";
    flake-parts.follows = "emanote/flake-parts";
  };

  outputs = inputs@{ self, flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      imports = [ inputs.emanote.flakeModule ];
      perSystem = { self', pkgs, ... }: {
        emanote.sites = {
          default = {
            layers = [
              { path = ./global; pathString = "./global"; }
              { path = ./ko; pathString = "./ko"; }
            ];
          };
        };
        apps.dns = {
          type = "app";
          program = toString (pkgs.writeShellScript "dns" ''
            set -euo pipefail
            if [ -f dns/.env ]; then
              set -a; source dns/.env; set +a
            else
              echo "dns/.env not found. Create from dns/.env.example"
              exit 1
            fi
            ${pkgs.opentofu}/bin/tofu -chdir=dns init -upgrade -input=false > /dev/null 2>&1
            if [ $# -eq 0 ]; then
              ${pkgs.opentofu}/bin/tofu -chdir=dns apply
            else
              ${pkgs.opentofu}/bin/tofu -chdir=dns "$@"
            fi
          '');
        };
        devShells.default = pkgs.mkShell {
          buildInputs = [ pkgs.nixpkgs-fmt pkgs.opentofu ];
        };
      };
    };
}
