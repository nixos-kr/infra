{ pkgs, ...}:

let

  index-html = pkgs.writeTextDir "index.html"
  ''
    <h1>Hello NixOS Korea</h1>
  '';

in

{

  services.static-web-server = {

    enable = true;

    listen = "[::]:8080";

    root = "${index-html}";

  };

}
