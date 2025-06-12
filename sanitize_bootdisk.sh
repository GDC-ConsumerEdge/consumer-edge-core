stateful_partition_dir="/mnt/stateful_partition/etc/googlekeychainagent"
if [[ -d "${stateful_partition_dir}" ]]; then
  for keychain_blob in $(find ${stateful_partition_dir}); do
    if [[ -f "${keychain_blob}" ]] && ! shred "${keychain_blob}"; then
      echo "Failed to shred ${keychain_blob}"
    fi
  done

  rm -rf ${stateful_partition_dir}
fi

stateful_partitions=$(blkid --match-types crypto_LUKS --match-token PARTLABEL="STATE" --output device)
if [[ -z "$stateful_partitions" ]]; then
  echo "No stateful partitions found"
  exit 0
fi

luks_drop_status=0
if ! cryptsetup erase "$stateful_partitions"; then
  echo "Failed to erase ${stateful_partitions}, will try to clear TPM2..."
  luks_drop_status=1
fi
if ! tpm2_clear; then
  echo "Running tpm2_clear failed"
  luks_drop_status=1
fi
exit "$luks_drop_status"
