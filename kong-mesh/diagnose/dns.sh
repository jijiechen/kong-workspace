#!/bin/bash

HOST=$1
TYPE=$2

if [ "$TYPE" == "" ]; then
    TYPE=A
fi

dig "$TYPE" @127.0.0.1  "$HOST" -p 15053
