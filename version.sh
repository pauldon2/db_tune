#!/bin/bash

version=$(ls /root/postgresql | awk '{print $0}')

echo "$version"
