PREFIX=/usr/local
BINDIR=$(PREFIX)/bin
MANDIR=$(PREFIX)/share/man

.PHONY: test clean

all: README.pod run-parts.1

run-parts.pod: LICENSE run-parts.pod.in
	awk -v l="`cat LICENSE`" '{gsub(/@LICENSE@/,l)}1' run-parts.pod.in > $@

run-parts.1: run-parts.pod
	pod2man run-parts.pod --center="run-parts Manual" --release="run-parts" > run-parts.1

README.pod: run-parts.pod
	printf "=for HTML <a href='https://travis-ci.org/wolfbox/run-parts'><img src='https://travis-ci.org/wolfbox/run-parts.svg'></a>\n\n" > README.pod
	cat run-parts.pod >> README.pod

install: run-parts.1
	install -m755 run-parts.sh $(BINDIR)/run-parts
	install -m644 run-parts.1 $(MANDIR)/man1/run-parts.1

test:
	./test.sh

clean:
	rm -f run-parts.1 run-parts.pod
