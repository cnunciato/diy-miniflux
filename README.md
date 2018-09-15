# miniflux

So, you want to run a [Miniflux](https://miniflux.app/) server, eh? Awesome!

This repo gives you a couple of ways to get started.

## With Docker and Docker Compose


1. [Install Docker](https://store.docker.com/search?offering=community&type=edition).

1. Run:

    ```
    docker-compose up
    ```

1. Wait a few seconds for the database migrations to complete, then browse to http://localhost, sign in (`admin`/`changeme`) and have fun!

## With Terraform and AWS

When you're ready to get started with real AWS resources (and you know enough about Terraform to understand what we're doing, here), follow the instructions below. This'll create a new AWS instance for you (an Ubuntu VM, by default), install Miniflux and Postgres on it, and set up a new VPC and load balancer with the appropriate connections to _make it all work_.

1. Register with AWS and obtain (both for use with Terrafowm):
  1. An AWS access key ID and secret
  1. An AWS key pair (specifically the private key file)
  1. An SSL certificate from the [AWS Certificate Manager](https://console.aws.amazon.com/acm/home), which you'll associate with your ELB below.

1. [Install Terraform](https://www.terraform.io/downloads.html).

1. Export your AWS credentials and region:

    ```
    export AWS_ACCESS_KEY_ID="<YOUR_KEY>"
    export AWS_SECRET_ACCESS_KEY="<YOUR_SECRET>"
    export AWS_DEFAULT_REGION="us-east-1" # Or whatever your preferred region is
    ```

1. Create an S3 bucket to hold your Terraform state.

1. Copy the example Terraform configs and **replace their values with your own** (using the bucket name and SSL certificate ID referenced above):

    ```
    cp terraform.backend.example terraform.backend
    cp terraform.tfvars.example terraform.tfvars
    ```
1. Initialize Terraform:

    ```
    terraform init --backend-config ./terraform.backend
    ```

1. Run Terraform plan to preview your changes:

    ```
    terraform plan
    ```

    You should be creating nine resources, including:

    * A new VPC
    * A new security group
    * A new subnet
    * A new internet gateway
    * A new route definition
    * A new VM instance
    * A new ELB, instance attachment and associated SSL cert

    By default, you'll get a `t2.nano`, which I happen to find totally suitable for personal use.

1. If everything looks good...

    ```
    terraform apply
    ```

    ... and roll forward when you're ready. In a minute or so, you should see output reflecting your new ELB and an SSH command to get into it:

    ```
    elb_host = tf-lb-....elb.amazonaws.com
    elb_url = https://tf-lb-....elb.amazonaws.com.elb.amazonaws.com
    instance_ip = 34.123.123.123
    instance_connect = ssh ubuntu@34.123.123.123 -i ~/.aws/ec2-us-east-personal.pem
    ```

Once you see that, you should be able to browse to that `elb_url` and sign in with the default credentials (`admin`/`changeme`). Be sure to **change the administrator password**!

Enjoy. I'll write more docs for this soon, promise.
