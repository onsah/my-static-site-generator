#!/usr/bin/env nu

rsync -av --ignore-times --delete -e ssh ./result/dist/ $"root@($env.SELF_HOSTED_SERVER_IP_V4):/var/www/html/blog/"

