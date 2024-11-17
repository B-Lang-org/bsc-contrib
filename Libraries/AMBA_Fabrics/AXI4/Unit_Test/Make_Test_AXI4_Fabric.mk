###  -*-Makefile-*-

# Copyright (c) 2024 Rishiyur S. Nikhil and Bluespec, Inc. All Rights Reserved

# Makefile for standalone Unit Tester for AXI4_Fabric

include Include.mk

TOPFILE  ?= Test_AXI4_Fabric.bsv

TESTCASE ?= 1
BSCFLAGS += -D TESTCASE=$(TESTCASE)
