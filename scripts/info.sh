#!/bin/bash

cd ../jwt-rsa-pss-example/target

bb gates -b jwt_rsa_pss_example.json | grep "circuit"