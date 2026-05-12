#!/bin/sh

# Shared color‐printing utilities for all your scripts.

pprint() {
  local msg="$1"; shift
  printf "\n%s\n" "$msg"
}

grn_print() {
  local msg="$1"; shift
  printf "\e[32m%s\e[0m\n" "$msg"
}

yel_print() {
  local msg="$1"; shift
  printf "\e[33m%s\e[0m\n" "$msg"
}

red_print() {
  local msg="$1"; shift
  printf "\e[31m%s\e[0m\n" "$msg"
}

blue_print() {
  local msg="$1"; shift
  printf "\e[34m%s\e[0m\n" "$msg"
}

blue_pprint() {
  local msg="$1"; shift
  printf "\n"
  blue_print "$msg"
}
