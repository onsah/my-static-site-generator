#!/usr/bin/env nu

rsync -av --ignore-times --delete -e ssh ./result/dist/ $"root@($env.SELF_HOSTED_SERVER_IP_V4):/etc/nix-config/devices/hetzner-nixos/blog/"

ssh $env.SERVER_IP -l root ('
  pushd /etc/nix-config/devices/hetzner-nixos/
  nixos-rebuild switch -I nixos-config=configuration.nix
  popd
')
