{ ... }: {
  virtualisation.forwardPorts = [
      { from = "host"; host.port = 18080; guest.port = 8080; }
    ];
}
