COMPILER=java -jar compiler/compiler.jar
COMPILER_LIBRARY=compiler/library/closure-library-master/closure

COMPILER_ARGS=--js $(SOURCES) --externs $(EXTERN) --output_wrapper "(function() {%output%})();" --only_closure_dependencies --closure_entry_point branch_instance
COMPILER_MIN_ARGS=--compilation_level ADVANCED_OPTIMIZATIONS --define 'DEBUG=false'
COMPILER_DEBUG_ARGS=--formatting=print_input_delimiter --formatting=pretty_print --warning_level=VERBOSE --define 'DEBUG=true'

SOURCES=$(COMPILER_LIBRARY)/goog/**\
src/0_config.js src/0_queue.js\
src/1_utils.js\
src/2_resources.js src/2_session.js src/2_storage.js\
src/3_api.js src/3_banner_utils.js\
src/4_banner_css.js src/4_banner_html.js\
src/5_banner.js\
src/6_branch.js\
src/7_initialization.js

EXTERN=src/extern.js

VERSION=$(shell grep "version" package.json | perl -pe 's/\s+"version": "(.*)",/$$1/')

ONPAGE_RELEASE=$(subst ",\",$(shell perl -pe 'BEGIN{$$sub="https://cdn.branch.io/branch-v$(VERSION).min.js"};s\#SCRIPT_URL_HERE\#$$sub\#' src/onpage.js | $(COMPILER) | node transform.js branch_sdk))
ONPAGE_DEV=$(subst ",\",$(shell perl -pe 'BEGIN{$$sub="dist/build.min.js"};s\#SCRIPT_URL_HERE\#$$sub\#' src/onpage.js | $(COMPILER) | node transform.js branch_sdk))
ONPAGE_TEST=$(subst ",\",$(shell perl -pe 'BEGIN{$$sub="../dist/build.js"};s\#SCRIPT_URL_HERE\#$$sub\#' src/onpage.js | $(COMPILER) | node transform.js branch_sdk))

.PHONY: clean

all: dist/build.min.js dist/build.js README.md TITANIUM_GUIDE.md WEB_GUIDE.md example.html test/branch-deps.js test/integration-test.html
clean:
	rm -f dist/** docs/web/3_branch_web.md README.md example.html test/branch-deps.js dist/build.min.js.gz test/integration-test.html
release: clean all dist/build.min.js.gz
	@echo "released"

# Download closure compiler if none is found
compiler/compiler.jar:
	mkdir -p compiler && \
		wget http://dl.google.com/closure-compiler/compiler-latest.zip && \
		unzip compiler-latest.zip -d compiler && \
		rm -f compiler-latest.zip

compiler/library/closure-library-master/closure/goog/**:
	mkdir -p compiler/library && \
		wget https://github.com/google/closure-library/archive/master.zip && \
		unzip master.zip -d compiler/library && \
		rm -f master.zip

test/branch-deps.js: $(SOURCES) compiler/library
	python $(COMPILER_LIBRARY)/bin/calcdeps.py \
		--dep $(COMPILER_LIBRARY)/goog \
		--path src \
		--path test \
		--output_mode deps \
		--exclude test/branch-deps.js > test/branch-deps.js.tmp
	echo "// jscs:disable" | cat - test/branch-deps.js.tmp | sed -e 's#src/0_config.js#test/web-config.js#' > test/branch-deps.js && \
		rm test/branch-deps.js.tmp

dist/build.js: $(SOURCES) $(EXTERN) compiler/compiler.jar
	$(COMPILER) $(COMPILER_ARGS) $(COMPILER_DEBUG_ARGS) --define 'WEB_BUILD=true' > dist/build.js

dist/build.min.js: $(SOURCES) $(EXTERN) compiler/compiler.jar
	$(COMPILER) $(COMPILER_ARGS) $(COMPILER_MIN_ARGS) --define 'WEB_BUILD=true' > dist/build.min.js

dist/build.min.js.gz: dist/build.min.js
	gzip -c dist/build.min.js > dist/build.min.js.gz

example.html: src/web/example.template.html
ifeq ($(MAKECMDGOALS), release)
	perl -pe 'BEGIN{$$a="$(ONPAGE_RELEASE)"}; s#// INSERT INIT CODE#$$a#' src/web/example.template.html > example.html
else
	perl -pe 'BEGIN{$$a="$(ONPAGE_DEV)"}; s#// INSERT INIT CODE#$$a#' src/web/example.template.html > example.html
endif

# Documentation

docs/web/3_branch_web.md: $(SOURCES)
	perl -pe 's/\/\*\*\ =CORDOVA/\/\*\*\*/gx' src/6_branch.js > src/3_branch_web.js
	perl -p -i -e 's/=WEB//gx' src/3_branch_web.js
	jsdox src/3_branch_web.js --output docs/web
	rm src/3_branch_web.js

README.md: docs/0_notice.md docs/readme/1_main.md docs/4_footer.md
	cat docs/0_notice.md docs/readme/1_main.md docs/4_footer.md | \
		perl -pe 'BEGIN{$$a="$(ONPAGE_RELEASE)"}; s#// INSERT INIT CODE#$$a#' > README.md

WEB_GUIDE.md: docs/0_notice.md docs/web/1_intro.md docs/web/3_branch_web.md docs/4_footer.md
	perl build_utils/toc_generator.pl src/6_branch.js docs/web/2_table_of_contents.md WEB
	cat docs/0_notice.md docs/web/1_intro.md docs/web/2_table_of_contents.md docs/web/3_branch_web.md docs/4_footer.md | \
		perl -pe 'BEGIN{$$a="$(ONPAGE_RELEASE)"}; s#// INSERT INIT CODE#$$a#' > WEB_GUIDE.md
	perl -p -i -e 's/# Global//' WEB_GUIDE.md

test/integration-test.html: test/integration-test.template.html
	perl -pe 'BEGIN{$$a="$(ONPAGE_TEST)"}; s#// INSERT INIT CODE#$$a#' test/integration-test.template.html > test/integration-test.html
