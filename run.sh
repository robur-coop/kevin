#!/bin/bash

dune build --profile=release
cp _build/solo5/main.exe unikave.hvt
chmod +w unikave.hvt
strip unikave.hvt
solo5-hvt --mem=1024 --net:service=tap0 --block:rowex=rowex.idx -- \
  unikave.hvt --ipv4=10.0.0.2/24 --color=always -vvv > log.txt
