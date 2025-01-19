#!/usr/bin/env nu

rsync -av --ignore-times -e ssh ./result/dist/ $"root@($env.SERVER_IP):/etc/nix-config/devices/hetzner-nixos/blog/"

ssh $env.SERVER_IP -l root ('
  pushd /etc/nix-config/devices/hetzner-nixos/
  nixos-rebuild switch -I nixos-config=configuration.nix
  popd
')
