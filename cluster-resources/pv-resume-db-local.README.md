# Instructions for Node-local PV for resume-backend

Mount path: /mnt/data/resume-db (change as needed)

On the node where the PV will be attached, run:

```bash
sudo mkdir -p /mnt/data/resume-db
sudo chown 1001:1001 /mnt/data/resume-db
sudo chmod 700 /mnt/data/resume-db
```

Note: The UID 1001 matches the Postgres container `runAsUser` in the chart values.
Change the owner if you use a different Postgres image or user.

If you use a cloud provider boot disk, attach a separate block device to the VM and
mount it on `/mnt/data/resume-db` so that the data persists across restarts.

Important: By default the Terraform configuration does NOT create a separate OCI block volume
for the resume DB (`create_resume_db_block_storage=false`). This means the local PV will use
the VM's boot disk path `/mnt/data/resume-db`. If you explicitly enable block storage creation
by setting `create_resume_db_block_storage=true`, Terraform will attempt to create and attach
an OCI block volume (minimum size of 50 GiB applies). Use that only if you want a separate
block device and accept the Always Free usage impact.
