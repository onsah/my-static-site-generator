build:
    dune build

generate-help:
    dune exec bin/main.exe -- -help

generate:
    dune exec bin/main.exe -- --content-path ./content --out-path ./dist

format:
    dune fmt
    