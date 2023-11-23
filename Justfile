build:
    dune build

generate:
    dune exec bin/main.exe -- --content-path ./content --out-path ./dist
    