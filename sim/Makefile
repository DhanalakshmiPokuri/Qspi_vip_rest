#=========================================================
# Makefile for QSPI XIP CTRL UVM Testbench
# Location: Qspi_project_vip/sim/Makefile
# Tool: Questa/ModelSim
#=========================================================

WORK = work

UP       = ..
RTL_DIR  = $(UP)/rtl
AHB_DIR  = $(UP)/ahb_master_vip
QSPI_DIR = $(UP)/qspi_vip
TB_DIR   = $(UP)/tb

#---------------------------------------------------------
# RTL Files
#---------------------------------------------------------
RTL = $(RTL_DIR)/DMC.v \
      $(RTL_DIR)/EF_QSPI_XIP_CTRL.v \
      $(RTL_DIR)/bus_wrappers/EF_QSPI_XIP_CTRL_AHBL.v

#---------------------------------------------------------
# VIP files - interfaces, checkers, and packages
#---------------------------------------------------------
AHB_FILES = $(AHB_DIR)/ahb_if.sv \
            $(AHB_DIR)/ahb_checker.sv \
            $(AHB_DIR)/ahb_pkg.sv

QSPI_FILES = $(QSPI_DIR)/qspi_if.sv \
             $(QSPI_DIR)/qspi_checker.sv \
             $(QSPI_DIR)/qspi_pkg.sv

TB_FILES = $(TB_DIR)/tb_pkg.sv \
           $(TB_DIR)/tb_top.sv

#---------------------------------------------------------
# Include Directories
#---------------------------------------------------------
INC = +incdir+$(AHB_DIR) \
      +incdir+$(QSPI_DIR) \
      +incdir+$(TB_DIR)

#---------------------------------------------------------
# Simulation Options
#---------------------------------------------------------
VSIMOPT   = -vopt -voptargs=+acc
VSIMCOV   = -coverage -sva
VSIMBATCH = -c -do "log -r /*; run -all; exit"

TEST ?= ahb_single_read
SEED ?= random

.PHONY: help sv_cmp run view clean \
        ahb_single_read multi_read_rand_addr burst_incr_read burst_wrap_read \
        xip_eb_read xip_continuous_read ahb_backpressure \
        sclk_generation_check reset_during_txn rand_stress_regression \
        illegal_ahb_transfers hsel_deselected multiple_reads_idle_cycles \
        cache_hit_test run_all

help:
	@echo "=========================================================================="
	@echo "                      QSPI XIP UVM TESTBENCH HELP                         "
	@echo "=========================================================================="
	@echo "make sv_cmp                              - Compile design and testbench"
	@echo "make run TEST=<test_name> [SEED=<seed>]  - Run specific test with seed"
	@echo "make view                                - Open waveform viewer"
	@echo "make clean                               - Remove sim artifacts and logs"
	@echo "--------------------------------------------------------------------------"
	@echo "Predefined Test Targets:"
	@echo "  make ahb_single_read             - Sanity check: AHB read -> QSPI flash"
	@echo "  make multi_read_rand_addr        - Independent reads to random addresses"
	@echo "  make burst_incr_read             - Incremental burst reads (INCR4/8/16)"
	@echo "  make burst_wrap_read             - Wrapping burst reads (WRAP4/8/16)"
	@echo "  make xip_eb_read                 - XIP quad read with 0xEB command"
	@echo "  make xip_continuous_read         - Continuous read mode (skip command)"
	@echo "  make ahb_backpressure            - HREADY wait states during flash fetch"
	@echo "  make sclk_generation_check       - SCLK frequency and Mode 00 check"
	@echo "  make reset_during_txn            - Mid-transaction reset recovery"
	@echo "  make rand_stress_regression      - Constrained-random stress"
	@echo "  make illegal_ahb_transfers       - Misaligned and unsupported transfers"
	@echo "  make hsel_deselected             - Transfer behavior when deselected"
	@echo "  make multiple_reads_idle_cycles  - Pipelined reads with idle intervals"
	@echo "  make cache_hit_test              - Zero wait-state cache hit verify"
	@echo "  make run_all                     - Run complete regression suite"
	@echo "=========================================================================="

sv_cmp:
	vlib $(WORK) 2>/dev/null || true
	vmap work $(WORK)
	vlog -sv -work $(WORK) \
	+timescale=1ns/1ps \
	$(INC) \
	$(RTL) \
	$(AHB_FILES) \
	$(QSPI_FILES) \
	$(TB_FILES)
run: sv_cmp
	vsim \
	$(VSIMOPT) \
	$(VSIMCOV) \
	$(VSIMBATCH) \
	-suppress 3009 \
	-wlf $(TEST).wlf \
	-l $(TEST).log \
	-sv_seed $(SEED) \
	work.tb_top \
	+UVM_TESTNAME=$(TEST)
view1:
	vsim -view ahb_single_read.wlf

view2:
	vsim -view multi_read_rand_addr.wlf

view3:
	vsim -view burst_incr_read.wlf

view4:
	vsim -view burst_wrap_read.wlf

view5:
	vsim -view xip_eb_read.wlf

view6:
	vsim -view xip_continuous_read.wlf

view7:
	vsim -view ahb_backpressure.wlf

view8:
	vsim -view sclk_generation_check.wlf

view9:
	vsim -view reset_during_txn.wlf

view10:
	vsim -view rand_stress_regression.wlf

view11:
	vsim -view illegal_ahb_transfers.wlf

view12:
	vsim -view hsel_deselected.wlf

view13:
	vsim -view multiple_reads_idle_cycles.wlf

view14:
	vsim -view cache_hit_test.wlf
clean:
	rm -rf work transcript* *.log *.wlf modelsim.ini covhtml* fcover*
# Shortcut test targets
ahb_single_read:
	$(MAKE) run TEST=ahb_single_read

multi_read_rand_addr:
	$(MAKE) run TEST=multi_read_rand_addr

burst_incr_read:
	$(MAKE) run TEST=burst_incr_read

burst_wrap_read:
	$(MAKE) run TEST=burst_wrap_read

xip_eb_read:
	$(MAKE) run TEST=xip_eb_read

xip_continuous_read:
	$(MAKE) run TEST=xip_continuous_read

ahb_backpressure:
	$(MAKE) run TEST=ahb_backpressure

sclk_generation_check:
	$(MAKE) run TEST=sclk_generation_check

reset_during_txn:
	$(MAKE) run TEST=reset_during_txn

rand_stress_regression:
	$(MAKE) run TEST=rand_stress_regression

illegal_ahb_transfers:
	$(MAKE) run TEST=illegal_ahb_transfers

hsel_deselected:
	$(MAKE) run TEST=hsel_deselected

multiple_reads_idle_cycles:
	$(MAKE) run TEST=multiple_reads_idle_cycles

cache_hit_test:
	$(MAKE) run TEST=cache_hit_test

run_all:
	@for t in ahb_single_read multi_read_rand_addr burst_incr_read burst_wrap_read \
	          xip_eb_read xip_continuous_read ahb_backpressure \
	          sclk_generation_check reset_during_txn rand_stress_regression \
	          illegal_ahb_transfers hsel_deselected multiple_reads_idle_cycles \
	          cache_hit_test; do \
		echo "=== RUNNING TEST: $$t ==="; \
		$(MAKE) run TEST=$$t || exit 1; \
	done


