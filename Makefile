all: generate-data

clean: clean-json-ps clean-data

WGET = wget
CURL = curl
GIT = git
PERL = ./perl

updatenightly: update-deps dataautoupdate

update-deps: local/bin/pmbp.pl
	#$(CURL) -s -S -L https://gist.githubusercontent.com/wakaba/34a71d3137a52abb562d/raw/gistfile1.txt | sh
	#$(GIT) add modules t_deps/modules
	perl local/bin/pmbp.pl --update
	$(GIT) add config

dataautoupdate:
	$(MAKE) clean
	$(MAKE) deps all
	$(GIT) add data/*.json

## ------ Setup ------

deps: git-submodules pmbp-install json-ps

git-submodules:
	$(GIT) submodule update --init

PMBP_OPTIONS=

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(CURL) -s -S -L https://raw.githubusercontent.com/wakaba/perl-setupenv/master/bin/pmbp.pl > $@
pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --update-pmbp-pl
pmbp-update: git-submodules pmbp-upgrade
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --update
pmbp-install: pmbp-upgrade
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --install \
            --create-perl-command-shortcut @perl \
            --create-perl-command-shortcut @prove \
	    --install-perl-app git://github.com/geocol/mwx
	cd local/mwx && perl local/bin/pmbp.pl \
	    --create-perl-command-shortcut plackup=perl\ modules/twiggy-packed/script/plackup

json-ps: local/perl-latest/pm/lib/perl5/JSON/PS.pm
clean-json-ps:
	rm -fr local/perl-latest/pm/lib/perl5/JSON/PS.pm
local/perl-latest/pm/lib/perl5/JSON/PS.pm:
	mkdir -p local/perl-latest/pm/lib/perl5/JSON
	$(WGET) -O $@ https://raw.githubusercontent.com/wakaba/perl-json-ps/master/lib/JSON/PS.pm

## ------ Build ------

generate-data: data/days-ja.json

clean-data:
	rm -fr local/input-*

EXTRACTOR = local/mwx/perl local/mwx/bin/extract-from-pages-remote.pl
EXTRACTOR_OPTS = --rules-file-name src/days.txt --url-prefix "$$JA_WPSERVER_URL_PREFIX"

local/input-1.json:
	perl -e 'print "1月$$_日\n" for 1..31' | xargs -- $(EXTRACTOR) $(EXTRACTOR_OPTS) > $@
local/input-2.json:
	perl -e 'print "2月$$_日\n" for 1..29' | xargs -- $(EXTRACTOR) $(EXTRACTOR_OPTS) > $@
local/input-3.json:
	perl -e 'print "3月$$_日\n" for 1..31' | xargs -- $(EXTRACTOR) $(EXTRACTOR_OPTS) > $@
local/input-4.json:
	perl -e 'print "4月$$_日\n" for 1..30' | xargs -- $(EXTRACTOR) $(EXTRACTOR_OPTS) > $@
local/input-5.json:
	perl -e 'print "5月$$_日\n" for 1..31' | xargs -- $(EXTRACTOR) $(EXTRACTOR_OPTS) > $@
local/input-6.json:
	perl -e 'print "6月$$_日\n" for 1..30' | xargs -- $(EXTRACTOR) $(EXTRACTOR_OPTS) > $@
local/input-7.json:
	perl -e 'print "7月$$_日\n" for 1..31' | xargs -- $(EXTRACTOR) $(EXTRACTOR_OPTS) > $@
local/input-8.json:
	perl -e 'print "8月$$_日\n" for 1..31' | xargs -- $(EXTRACTOR) $(EXTRACTOR_OPTS) > $@
local/input-9.json:
	perl -e 'print "9月$$_日\n" for 1..30' | xargs -- $(EXTRACTOR) $(EXTRACTOR_OPTS) > $@
local/input-10.json:
	perl -e 'print "10月$$_日\n" for 1..31' | xargs -- $(EXTRACTOR) $(EXTRACTOR_OPTS) > $@
local/input-11.json:
	perl -e 'print "11月$$_日\n" for 1..30' | xargs -- $(EXTRACTOR) $(EXTRACTOR_OPTS) > $@
local/input-12.json:
	perl -e 'print "12月$$_日\n" for 1..31' | xargs -- $(EXTRACTOR) $(EXTRACTOR_OPTS) > $@

local/days-ja-%.json: local/input-%.json
	$(PERL) bin/generate.pl $< > $@

local/days-ja: \
  local/days-ja-1.json local/days-ja-2.json local/days-ja-3.json \
  local/days-ja-4.json local/days-ja-5.json local/days-ja-6.json \
  local/days-ja-7.json local/days-ja-8.json local/days-ja-9.json \
  local/days-ja-10.json local/days-ja-11.json local/days-ja-12.json

local/era-defs.json:
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-locale/master/data/calendar/era-defs.json

data/days-ja.json: bin/date-fixup.pl local/days-ja local/era-defs.json
	$(PERL) $< > $@

## ------ Tests ------

PROVE = ./prove

local/bin/jq:
	$(WGET) -O $@ http://stedolan.github.io/jq/download/linux64/jq
	chmod u+x local/bin/jq

test: test-deps test-main

test-deps: deps local/bin/jq

test-main:
	$(PROVE) t/*.t

## License: Public Domain.
