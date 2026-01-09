# Unikave, a simple KV-store as an unikernel with HTTP endpoints

Unikave is a simple unikernel that, from a block device, has a Key-Value store
for which several HTTP routes exist:
- POST http://unikernel/add, which allows a new entry to be added; this route
  expects a JSON value such as:
```shell
$ jq -cn --arg key foo --arg value 42 '{key: $key, value: $value}' | \
  curl -X POST --data-binary @- \
    -H Content-Type:application/json http://unikernel/add
```
- GET http://unikernel/get/key returns the value associated with key if it
  exists (otherwise, the unikernel responds with 404 Not Found)
```shell
$ curl -s http://unikernel/get/foo | jq
"42"
```
- DELETE http://unikernel/rem/key deletes the value associated with key if it
  exists (otherwise, it does nothing) 

Storage is said to be persistent, meaning that data is saved in the given block
device and if the unikernel is restarted with the same file, the entries should
be available.

Adding, reading and deleting can be done in total concurrency (see in parallel,
but this is not the case for unikernels). This means that multiple clients can
add, read or delete data without any consistency issues.

## How to build

```shell
$ git clone https://git.robur.coop/robur/unikave.git
$ cd unikave
$ opam pin add -yn --deps-only .
$ ./source.sh
$ dune build
$ cp _build/solo5/main.exe unikave.hvt
$ chmod +w unikave.hvt
$ strip unikave.hvt
```

## How to launch the unikernel

```shell
$ ./net.sh # require sudo to create a bridge and a tap interface
$ dd if=/dev/zero of=rowex.idx bs=24M count=1
$ solo5-hvt --net:service=tap0 --block:rowex=rowex.idx -- \
  unikave.hvt --ipv4=10.0.0.2/24 --color=always
```
