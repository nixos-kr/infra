{

  inputs.nixpkgs.url = github:nixos/nixpkgs/nixos-24.11;

  outputs = inputs:

  let

    inherit (inputs.nixpkgs) lib;

    system = "x86_64-linux";

    pkgs = import inputs.nixpkgs { inherit system; };

    dev-shell = pkgs.mkShell { buildInputs = [ pkgs.nixos-shell ]; };

  in

  {

    devShells.${system}.default = dev-shell;

    nixosConfigurations.vm = lib.nixosSystem {
      inherit system;
      modules = [
        ./port-forward.nix
        ./static-web-server.nix
      ];
    };

  };

}
