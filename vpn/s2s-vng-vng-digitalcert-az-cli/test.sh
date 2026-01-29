#!/bin/bash
# Test script to generate Key Vault names based on resource group and gateway names

rgName="test-s2s-cert2-powershell"
gw1Name="gw1"
gw2Name="gw2"

seed="$rgName-$gw1Name"
suffix=$(echo -n "$seed" | sha256sum | cut -c1-6)
keyVault1Name="kv-$gw1Name-$suffix"

echo "keyVault1: $keyVault1Name"

seed="$rgName-$gw2Name"
suffix=$(echo -n "$seed" | sha256sum | cut -c1-6)
keyVault2Name="kv-$gw2Name-$suffix"

echo "keyVault2: $keyVault2Name"
