#!/bin/bash
find /var/log/ -name "*.gz" -exec gunzip {} \;