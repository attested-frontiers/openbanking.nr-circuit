#!/bin/bash

cd ..

bb gates -b target/jwt_rsa_pss_example.json | grep "circuit"