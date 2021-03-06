#
# Copyright (C) 2011 Battelle Memorial Institute <http://www.battelle.org>
#
# Author: Brandon Carpenter
#
# This package is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This package is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#

defsyms-names = $(foreach N,$(basename $(obj-m)),$(if $($N-defsyms),$N))

ifneq ($(defsyms-names),)

# Should check if defsyms are in Module.symvers before getting an address.
# It would be nice to use modpost.
# SYMVERS ?= $(or $(realpath $(CURDIR)/Module.symvers), $(src)/Module.symvers)

SYSMAP ?= $(or $(realpath $(CURDIR)/System.map), \
	$(realpath /boot/System.map-$(KERNELRELEASE)), \
	$(realpath /lib/modules/$(KERNELRELEASE)/build/System.map), \
	$(if $(findstring $(KERNELRELEASE),$(shell uname -r)),$(realpath /proc/kallsyms)), \
	$(src)/System.map)

quiet_cmd_defsyms = DEFSYMS $@
cmd_defsyms = sed -r '/\s($(shell echo '$($*-defsyms)' | awk '{OFS="|";$$1=$$1;print $$0}'))\s*$$/!d;s/^(\S+)\s+\S+\s*(\S+)/\2 = 0x\1;/' $(SYSMAP) > $@
quiet_cmd_md5 = MD5SUM  $3
cmd_md5 = md5sum $2 > $3
quiet_cmd_symvers = SYMVERS $@
cmd_symvers = sed -r 's/^\s*(\w+)\s*=\s*0x\S*(\S{8})\s*;\s*$$/0x\2\t\1\tvmlinux/;t;d' $(defsyms-lds) > $@

defsyms-roots := $(addprefix $(obj)/,$(defsyms-names))
defsyms-obj := $(addsuffix .o,$(defsyms-roots))
defsyms-m := $(addsuffix .ko,$(defsyms-roots))
defsyms-lds := $(addsuffix .defsyms,$(defsyms-roots))
clean-files += $(defsyms-m) $(defsyms-lds) .System.map.md5 defsyms.symvers

$(obj)/.System.map.md5: $(shell [ -f $(obj)/.System.map.md5 ] && md5sum $(SYSMAP) | cmp $(obj)/.System.map.md5 -s - || echo FORCE)
	$(call cmd,md5,$(SYSMAP),$@)

$(defsyms-obj): $(obj)/defsyms.symvers

$(obj)/defsyms.symvers: $(defsyms-lds)
	$(call cmd,symvers)

KBUILD_EXTRA_SYMBOLS += $(obj)/defsyms.symvers
LDFLAGS_MODULE += $(DEFSYMS_LDFLAGS_$(notdir $@))

$(foreach N,$(defsyms-names),$(eval DEFSYMS_LDFLAGS_$(N).ko = -T $(obj)/$(N).defsyms))

$(defsyms-lds): $(obj)/%.defsyms: $(obj)/.System.map.md5
	$(call cmd,defsyms)

endif
