# riak-formation

Create/restore a riak cluster on any cloudprovider using Terraform

## What

[Riak](http://basho.com/riak/) is fine distributed key-value store.
[Riak CS](http://basho.com/riak-cloud-storage/) is an addon so that you can build your own S3 compatible storage service, with Riak as a backend.
[Terraform](http://www.terraform.io/) is a tool to launch clusters in the cloud, using nothing but simple configuration files.

**[riak-formation](https://github.com/kvz/riak-formation)** is a collection of config files and scripts that let you create/restore a Riak (CS) cluster in the cloud using a single command.

## Why

Launching a Riak cluster can be involved. Hence
[Basho](http://basho.com/) has
[released a few scripts](https://github.com/basho/cloudformation-riak) for
[AWS CloudFormation](http://aws.amazon.com/cloudformation/)
to automate this.

While these scripts are more advanced than what **riak-formation** is aiming for - they tie you in with Amazon's EC2. The Terraform approach also works with other vendors such as e.g. Digital Ocean. You could even mix multiple providers to some extent.

Terraform works idempotent, meaning if it encounters servers that diverged from our config, we can just run it again and it will make all the required changes to restore our cluster as it was defined.

Terraform config uses the [HLC](https://github.com/hashicorp/hcl) configuration language and is more dense than the `48.189 kb` CloudFormation JSON files, so it's easier to spot mistakes, and more fun to work on.

## How

First, **riak-formation** needs to know which cloud provider you wish to target, and the associated account. You can pass it these via environment config. Either directly on the commandline, or add them to `env.sh`.


