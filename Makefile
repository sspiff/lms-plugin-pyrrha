

PLUGIN_NAME     := $(shell sed -n 's,.*<plugin.*name="\([^"]*\)".*,\1,p' misc/repo.xml)

# We use a git tag to define the version of the plugin we are building.
# Usually this is of the form x.y.z, but if we're building for dev testing
# and we have some commits after the most recent x.y.z tag, then git describe
# will append additional information, e.g. "0.4.2-4-g5a21db7".
# However, the LMS plugin version comparator doesn't grok the "-4-g5a21db7"
# the way we want it to and it sees this dev build as less than the base
# 0.4.2 version.
# So, we transform it to something like "0.4.2+4g5a21db7", which seems to
# cause LMS to see this build as newer than 0.4.2.
# This is definitely an abuse of the current implementation of the version
# comparator, but we only depend on it for dev testing builds.
PLUGIN_VERSION  := $(shell git describe | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+)-(g[0-9a-f]+)$$/\1+\2\3/')

GIT_COMMIT_DATE := $(shell env TZ= date -r `git log -1 --format="%at"` '+%Y-%m-%dT%H:%M:%S')
PLUGIN_ZIP       = lms-plugin-$(PLUGIN_NAME)-$(PLUGIN_VERSION).zip
PLUGIN_ZIPURL    = https://github.com/sspiff/lms-plugin-pyrrha/releases/download/$(PLUGIN_VERSION)/$(PLUGIN_ZIP)

OBJDIR = obj

ZIPEXTRAS += README.md
ZIPEXTRAS += LICENSE
ZIPEXTRAS += 3RDPARTY.md


.PHONY: dist
dist:
	rm -Rf $(OBJDIR)
	mkdir -p $(OBJDIR)
	# seed the plugin dir
	tar cf - plugin | (cd $(OBJDIR) && tar xf -)
	cp $(ZIPEXTRAS) $(OBJDIR)/plugin/
	# update install.xml with our version
	m4 -D__VERSION__=$(PLUGIN_VERSION) plugin/install.xml \
	  > $(OBJDIR)/plugin/install.xml
	# set all file times to the git commit date
	find $(OBJDIR)/plugin -type f | while read f; do \
	  env TZ= touch -d $(GIT_COMMIT_DATE) "$$f" ;    \
	  done
	# zip it up
	(cd $(OBJDIR)/plugin && find . -type f | sort \
	  | zip -X --names-stdin ../plugin.zip)
	# create the distribution
	mkdir -p $(OBJDIR)/dist
	cp $(OBJDIR)/plugin.zip $(OBJDIR)/dist/$(PLUGIN_ZIP)
	m4 -D__VERSION__=$(PLUGIN_VERSION)                                \
	   -D__ZIPURL__=$(PLUGIN_ZIPURL)                                  \
	   -D__SHA__=`shasum $(OBJDIR)/dist/$(PLUGIN_ZIP) | cut -d\  -f1` \
	   misc/repo.xml > $(OBJDIR)/dist/repo.xml


.PHONY: clean
clean:
	rm -Rf $(OBJDIR)

