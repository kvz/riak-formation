# riak-formation


Create/restore a riak cluster on any cloudprovider using Terraform

## What

[Riak](http://basho.com/riak/) is fine distributed key-value store. It can be involved to set up a cluster and maintain it.
[Terraform](http://www.terraform.io/) is a tool to launch clusters in the cloud, using nothing but simple configuration files.
[riak-formation](https://github.com/kvz/riak-formation) is a collection of config files and scripts so you can launch a Riak cluster in the cloud using one command.

## Why

[Basho](http://basho.com/) has released
[a few](https://github.com/basho/cloudformation-riak/blob/master/riak-cluster.json)
[cloudformation](https://github.com/basho/cloudformation-riak/blob/master/riak-vpc-cluster-with-frontend-appservers.json)
[scripts](https://github.com/basho/cloudformation-riak/blob/master/riak-vpc-cluster.json) to do something similar, but they tie you in with EC2. Terraform also works on e.g. Digital Ocean.

Terraform also works idempotent, which means if it encounters servers that diverged from our config, we can just run it again and it will make all the required changes to restore our cluster as it was defined.

Terraform config is also much more dense than the `48.189 kb` cloudformation json files, so it's easier to spot mistakes, and more fun to work on.

## How

First, riak-formation needs to know which cloud provider you wish to target, and the associated account. You can pass it these via environment config. Either directly on the commandline, or add them to `env.sh`.
