#!/bin/bash

[ ! -d "vendors" ] && mkdir vendors
[ ! -d "vendors/bstr" ] && opam source bstr --dir vendors/bstr
[ ! -d "vendors/carton" ] && opam source carton --dir vendors/carton
[ ! -d "vendors/cachet" ] && opam source cachet --dir vendors/cachet
[ ! -d "vendors/digestif" ] && opam source digestif --dir vendors/digestif
[ ! -d "vendors/gmp" ] && opam source gmp --dir vendors/gmp
[ ! -d "vendors/mkernel" ] && opam source mkernel --dir vendors/mkernel
[ ! -d "vendors/bancos" ] && opam source bancos --dir vendors/bancos
[ ! -d "vendors/mirage-crypto-rng-mkernel" ] && opam source mirage-crypto-rng-mkernel --dir vendors/mirage-crypto-rng-mkernel
[ ! -d "vendors/mnet" ] && opam source mnet --dir vendors/mnet
[ ! -d "vendors/kdf" ] && opam source kdf --dir vendors/kdf
[ ! -d "vendors/tls" ] && opam source tls --dir vendors/tls
[ ! -d "vendors/x509" ] && opam source x509 --dir vendors/x509
[ ! -d "vendors/mhttp" ] && opam source mhttp --dir vendors/mhttp
[ ! -d "vendors/h1" ] && opam source h1 --dir vendors/h1
[ ! -d "vendors/httpcats" ] && opam source httpcats --dir vendors/httpcats
[ ! -d "vendors/vif" ] && opam source vif --dir vendors/vif
[ ! -d "vendors/flux" ] && opam source flux --dir vendors/flux
[ ! -d "vendors/multipart_form" ] && opam source multipart_form --dir vendors/multipart_form
[ ! -d "vendors/prettym" ] && opam source prettym --dir vendors/prettym
