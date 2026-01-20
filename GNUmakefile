vendors:
	test ! -d $@
	mkdir vendors
	@./source.sh

kevin.hvt.target: | vendors
	@echo " BUILD main.exe"
	@dune build --root . --profile=release ./main.exe
	@echo " DESCR main.exe"
	@dune describe location \
		--context solo5 --no-print-directory --root . --display=quiet \
		./main.exe 2>&1 tee $@

kevin.hvt: kevin.hvt.target
	@echo " COPY kevin.hvt"
	@cp $(file < kevin.hvt.target) $@
	@chmod +w $@
	@echo " STRIP kevin.hvt"
	@strip $@

kevin.install: kevin.hvt
	@echo " GEN kevin.install"
	@ocaml install.ml > $@

all: kevin.install | vendors

.PHONY: clean
clean:
	if [ -d vendors ] ; then rm -fr vendors ; fi
	rm -f kevin.hvt.target
	rm -f kevin.hvt
	rm -f kevin.install

install: kevin.intall
	@echo " INSTALL kevin"
	opam-installer kevin.install
