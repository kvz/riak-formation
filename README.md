# riak-formation

Create/restore a riak cluster on any cloudprovider using Terraform

## What

 - [Riak](http://basho.com/riak/) is fine distributed key-value store built by [Basho](http://basho.com/)
 - [Riak CS](http://basho.com/riak-cloud-storage/) is an addon so that you can build your own S3 compatible storage service, with Riak as a backend.
 - [Terraform](http://www.terraform.io/) is a tool to launch clusters in the cloud, using nothing but simple configuration files.

**[riak-formation](https://github.com/kvz/riak-formation)** is a collection of config files and scripts that let you create/restore a Riak (CS) cluster in the cloud using a single command.

## Why

Launching a Riak cluster can be involved. Hence Basho has
[released a few scripts](https://github.com/basho/cloudformation-riak) for
[AWS CloudFormation](http://aws.amazon.com/cloudformation/)
to automate this.

While these scripts are more advanced than what **riak-formation** is aiming for - they tie you in with Amazon's EC2. The Terraform approach also works with other vendors such as e.g. Digital Ocean. You could even mix multiple providers to some extent.

Terraform works idempotent, meaning if it encounters servers that diverged from our config, we can just run it again and it will make all the required changes to restore our cluster as it was defined.

Terraform config uses the [HLC](https://github.com/hashicorp/hcl) configuration language and is more [dense](https://github.com/kvz/riak-formation/blob/master/scripts/riak.tf) than the `48.189 kb` CloudFormation JSON files, so it's easy to spot mistakes, and more fun to work on.

## How

First, **riak-formation** needs to know which cloud provider you wish to target, and the associated account. You can pass it these via cluster config. Either directly on the commandline, or add them to `clusters/production/config.sh`. `production` can be any name, you you could be deploying many completely different riak clusters from this project.
Since `config.sh` supports many configuration options, it is not required to define your own cluster's infrastructure definitions (`*.tf`), it instead will automatically borrow `infra.tf` from the `example` cluster to reduce duplication. SSH keys, SSL keys, `config.sh`, state files, and plan files, do have to be administerd on a cluster-by-cluster basis.

Now type `make launch`. riak-formation will launch as many machines as you defined, set up firewalls, install riak nodes, connect them together, set up Riak Control, and end with this summary:

![screen shot 2014-11-21 at 21 12 26](https://cloud.githubusercontent.com/assets/26752/5148855/4d7712fe-71c3-11e4-8bc8-72577dfcd2b2.png)

Click any of the links, and you're right in the control panel:

![screen shot 2014-11-21 at 21 12 39](https://cloud.githubusercontent.com/assets/26752/5148857/4fc8815a-71c3-11e4-8fb0-2e2a6d04bf5c.png)

## Todo

- [ ] Make env file dictate ingress, ports, server count, etc. So that you can launch different Riak clusters by just sourcing different env files.
- [ ] S3 emulation
- [ ] Can we servie read-only json files
- [ ] Multi datacenter replication? Can we do that for free somehow?
- [ ] Enable Search
- [ ] Research/Document CRDTs in 2.0
- [ ] Backup / Restore
- [x] Simplify directory layout

## Credits

This project draws from

 - [Installing on Debian and Ubuntu](http://docs.basho.com/riak/latest/ops/building/installing/debian-ubuntu/#Installing-From-Apt-Get)
 - [How To Create a Riak Cluster on an Ubuntu VPS](https://www.digitalocean.com/community/tutorials/how-to-create-a-riak-cluster-on-an-ubuntu-vps)
 - [Call Me Maybe: Carly Rae Jepsen and the Perils of Network Partitions - RICON East 2013](https://www.youtube.com/watch?v=mxdpqr-loyA)
 - [Jepsen: ZK, NuoDB, Kafka, & Cassandra](https://www.youtube.com/watch?v=NsI51Mo6r3o) 
 - [Kyle Kingsbury and Al Tobey - Cassandra and Go Doubleheader](https://www.youtube.com/watch?v=oEFqxi_n1vU)
 
