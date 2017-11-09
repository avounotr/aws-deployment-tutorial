# Deploy on aws (Tutorial)

## Introduction

Amazon ECS is a highly scalable, high performance ontainer management service that
supports Docker Containers and allows you to easily run applications on a managed
cluster of Amazon EC2 instances. You don't have to worry about where your containers
working in a cluster or servers. ECS essentially turns one or more EC2 instances
into one single computing resource and amazon ECS will handle the logistics of figuring
out where the container should run based on systems resources or other availability
requirements that you can set.
Amazon ECS is a lower level Amazon resource for dealing with docker container management.
Elastic Beanstalk uses the ECS under the hood.

### Extensible and flexible

- Leverage third party schedulers
- mix and match EC2 instances
- Integrate with third party services such as CI / CD systems.
- Itegrates with other AWS resources and it does not cost anything extra to use!


The following example will present us with a good overview on how to deploy
on aws using the EC2 Container Service. According to this example we should
use docker, nginx, node and wordpress the result should be like this:

1. Route /: Show a simple hello world SSR node project
2. Route /wordpress: Show a simple hello world wordpress project


## Tutorial

### 1. Create an admin user

An admin user (AdministratorAccess) should be created through the IAM. Should have programmatic and Console Management Access.
example:  

User's credentials information (example):
- username: test-user
- password: test-pass
- accessKeyId: AKIAIJLMX7APXQXKRLMA
- secretAccessKey: ***************************
- region: eu-central-1
- output: json

Save these information to the .aws folder (credentials and config files)

### 2. Create a key pair

Example:
- keyname: test-kp
- path: ~/.ssh/test-kp.pem

#### How to create a key-pair file

- From Console: You can easily create a Key Pair on EC2/Network & Security/Key Pairs.
- From terminal: aws ec2 create-key-pair --key-name test-kp --query 'KeyMaterial' --output text > ~/.ssh/test-kp.pem

Set chmod 400 to keypair from terminal: chmod 400 ~/.ssh/test-kp.pem

#### Describe key-pair
aws ec2 describe-key-pairs --key-name test-kp


### 3. Add a security group

Security group is an important security layer in order secure the communication between users and EC2 instances trhough SSH protocol

#### How to create a security group

- From Console: EC2/Network & Security/Security Group.
- From terminal: aws ec2 create-security-group --group-name test-sg --description "Security group for test-user"

This command is going to return a group-id. Please save it. In our case:
Security Group Id: sg-09378c63

#### Describe Security Group

```
aws ec2 describe-security-groups --group-id sg-09378c63
```

#### Set security group authorizations

##### a. SSH port
```
aws ec2 authorize-security-group-ingress --group-id sg-09378c63 --protocol tcp --port 22 --cidr 0.0.0.0/0
```

##### b. HTTP port
```
aws ec2 authorize-security-group-ingress --group-id sg-09378c63 --protocol tcp --port 80 --cidr 0.0.0.0/0
```

##### c. MySQL port
```
aws ec2 authorize-security-group-ingress --group-id sg-09378c63 --protocol tcp --port 3306 --cidr 0.0.0.0/0
```

##### d. Node port
```
aws ec2 authorize-security-group-ingress --group-id sg-09378c63 --protocol tcp --port 3000 --cidr 0.0.0.0/0
```

##### e. Wordpress port
```
aws ec2 authorize-security-group-ingress --group-id sg-09378c63 --protocol tcp --port 8181 --cidr 0.0.0.0/0
```

### 4. Add Roles

We should also create 2 roles which will be useful in the next steps.

ecsInstanceRole <AmazonEC2ContainerServiceforEC2Role and AmazonS3ReadOnlyAccess>
ecsServiceRole <AmazonEC2ContainerServiceRole>


### 5. Create Cluster

Cluster name (example): test-cluster

#### How to create a cluster

- From console: Simply from EC2 Container Service
- From terminal: aws ecs create-cluster --cluster-name test-cluster

#### Get clusters
```
aws ecs list-clusters
```

#### Describe cluster
```
aws ecs describe-clusters --clusters test-cluster
```

### 6. Container Agent

Bucket name (example): test-bucket-20171

#### Create Bucket
```
aws s3api create-bucket --bucket test-bucket-20171 --create-bucket-configuration LocationConstraint=eu-central-1
```

#### Copy ecs.config file to bucket
```
aws s3 cp container_agent/ecs.config s3://test-bucket-20171/ecs.config
```

#### Show list of files inside a bucket
```
aws s3 ls s3://test-bucket-20171
```

### 7. Contaainer instances

AMI for amazon server: ami-e28d098d

#### Create instance:
```
aws ec2 run-instances --image-id ami-ebfb7e84 --count 2 --instance-type t2.micro --iam-instance-profile Name=ecsInstanceRole --key-name test-kp --security-group-ids sg-09378c63 --user-data file://container_agent/ecs-to-s3
```

### 8. Setup Load Balancer

In the previous step, we create 2 instances. The reason why this happens is because
this way we can deploy any change of our application without Downtime!

#### The load balancer works like the following example:
- Instance 1 is serving version 1
- Instance 2 is service version 1
- You push version 2
- Instance 1 goes down
- Instance 1 removed from the Load Balancer
- Instance 1 gets updated version 2
- Instance 1 gets added back to the Load Balancer
- Instance 1 is service vversion 2
- <Repeat from step 4 for the Instance 2>

Load Balancer Name: test-elb

####  Get subnets
```
aws ec2 describe-subnets  # get subnets - ignore those with DefaultForAZ = false
```

In our case subnetsId: subnet-6a929b10 subnet-42b3730f subnet-40be752b

#### Create Load Balancer
```
aws elb create-load-balancer --load-balancer-name test-elb --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80" --subnets subnet-6a929b10 subnet-42b3730f subnet-40be752b --security-groups sg-09378c63
```

It returns dns-name so, saving it as:
```
elbDns = test-elb-1599931724.eu-central-1.elb.amazonaws.com
```

### 9. Setting Up RDS for MySQL

#### Information  
Instance Identifier: test-db
DB Name: blog
DB Username: blog_user
DB Password: blog_pass (Just because it is an example - password should be much stronger)

#### Create db instance
```
aws rds create-db-instance --engine mysql --no-multi-az --no-publicly-accessible --vpc-security-group-id sg-09378c63 --db-instance-class db.t2.micro --allocated-storage 20 --db-instance-identifier test-db --db-name blog --master-username blog_user --master-user-password blog_pass
```

#### How to modify the db instance (Update the password in the example):
```
aws rds modify-db-instance --db-instance-identifier test-db --master-user-password {New password}
```

#### Get the database endpoint address (Important - It may takes 5-10 minutes)
```
aws rds describe-db-instances
```

Results:          
**endpoint.address**: test-db.cyrv3tzrsvne.eu-central-1.rds.amazonaws.com  
**endpoint.port**: 3306 (As expected)  


### 8. Dockerize your Application

The code for the following apps is shown in the 'project' folder

#### a. Node SSR Hello World

We can find a lot of SSR example in the internet. Clone the following github example:
```
git clone https://github.com/mhart/react-server-example.git .
```

##### Build docker image
```
sudo docker build -t test/application .
```

##### Run image
```
sudo docker run -p 3000:3000 -d test/application
```

#### b. Wordpress blog

##### Start docker
```
sudo docker-compose up -d
```

##### Stop docker
```
sudo docker-compose stop
```

##### Terminate docker
```
sudo docker-compose down
```

#### c. Dockerized nginx

Nginx is an important tool in our case. We can use it as a proxy server in
order to move from one project to another according to the url.

##### Build docker image
```
sudo docker build -t test/application .
```

##### Run image
```
sudo docker run -p 3000:3000 -d test/application
```

### 10.Set Repositories and push

#### Login
```
eval "sudo $(aws ecr get-login)"
```

#### Create 3 Repositories

##### a. Nginx repo
```
aws ecr create-repository --repository-name test/nginx
```

##### b. Application repo (SSR Node)
```
aws ecr create-repository --repository-name test/application
```

##### c. Blog repo (Wordpress)
```
aws ecr create-repository --repository-name test/blog
```

#### Get Images of repos
```
aws ecr list-images --repository-name test/nginx
aws ecr list-images --repository-name test/application
aws ecr list-images --repository-name test/blog
```

### 11. Push code to repos

#### Login
```
eval "sudo $(aws ecr get-login)"
```

#### Tag and push repositories
```
aws ecr describe-repositories (Get the registryId)
registryId: 269286422109

sudo docker images (Get all repo names - need in tagging)
```

test/application -> test/application
test/blog -> docker.io/wordpress
test/nginx -> test/nginx

#### a. Application repository
```
sudo docker tag test/application:latest 269286422109.dkr.ecr.eu-central-1.amazonaws.com/test/application:latest
sudo docker push 269286422109.dkr.ecr.eu-central-1.amazonaws.com/test/application:latest
```

#### b. Blog repository
```
sudo docker tag docker.io/wordpress:latest 269286422109.dkr.ecr.eu-central-1.amazonaws.com/test/blog:latest
sudo docker push 269286422109.dkr.ecr.eu-central-1.amazonaws.com/test/blog:latest
```

#### c. NGINX repository
```
sudo docker tag test/nginx:latest 269286422109.dkr.ecr.eu-central-1.amazonaws.com/test/nginx:latest
sudo docker push 269286422109.dkr.ecr.eu-central-1.amazonaws.com/test/nginx:latest
```

### 12. Set tasks

#### Register task
```
aws ecs register-task-definition --cli-input-json file://tasks/web-task-definition.json
```

#### List of tasks
```
aws ecs list-task-definitions
```

### 13. Set Services

#### Create Service
```
aws ecs create-service --cli-input-json file://services/web-service.json
```

#### Update Service
```
aws ecs update-service --cluster test-cluster --service test-service-web --task-definition test-task-web --desired-count { desiredCount }
```

### 14. Automating the Deployment!

Automating the deployment, (and other processes like back up, or run the code
on staging, reset database, migrate database etc) is one of the most important
advantages for ECS and its integration with Aws-cli.

The script code is in deploy/deploy.sh


### 15. Visualization
In this section we can see the architecture of current project

![](images/architecture.png?raw=true)

## Future Work

1. The result of this project is found on the following link: http://18.195.73.33/.
During the redirect of wordpress sublink, the port is shown. This is a detail
that should change.

2. It is very simple to add an SSL certificate to this project.

3. VPC is a good solution in order to improve the security of our deployed code.  
