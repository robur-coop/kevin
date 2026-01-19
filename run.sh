#!/bin/bash

dune build --profile=release
cp _build/solo5/main.exe unikave.hvt
chmod +w unikave.hvt
strip unikave.hvt
# dd if=/dev/zero of=rowex.idx  bs=24M  count=1
solo5-hvt --mem=1024 --net:service=tap0 --block:rowex=rowex.idx -- \
  unikave.hvt --ipv4=10.0.0.2/24 --color=always -vvv -l gc -l rowex -l mpart &> log.txt
