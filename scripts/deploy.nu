#!/usr/bin/env nu

def main [server_ip : string] {
    ^rsync -av --ignore-times --delete -e ssh ./result/dist/ $"root@($server_ip):/var/www/html/blog/"
}

