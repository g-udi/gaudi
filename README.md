# Beamery Development Environment

The Beamery developer environment makes use of a number of technologies combined in a local stack that replicates our staging and live environments while maintaining an ease of use and flexibility. This document is dedicated to helping you get your environment running on your local machine.

## Requirements

Before you can start developing at Beamery you need to make sure you have a functioning environment with the following components installed.

### Servers
* MongoDB v3.2.0+ listening on `127.0.0.1` - [Linux](https://docs.mongodb.org/v3.2/administration/install-on-linux/), [OS X](https://docs.mongodb.org/v3.2/tutorial/install-mongodb-on-os-x/), [Windows](https://docs.mongodb.org/v3.2/tutorial/install-mongodb-on-windows/)
* Redis v3.0+ listening on `127.0.0.1` - [Linux](http://redis.io/download), [OS X](https://medium.com/@petehouston/install-and-config-redis-on-mac-os-x-via-homebrew-eb8df9a4f298), [Windows](https://github.com/MSOpenTech/redis)
* RabbitMQ v3.6.0+ listening on `127.0.0.1` - [Linux](https://www.rabbitmq.com/install-debian.html), [OS X](https://www.rabbitmq.com/install-homebrew.html), [Windows](https://www.rabbitmq.com/install-windows.html)
* ElasticSearch v.5.x listening on `127.0.0.1` - [Linux](https://www.elastic.co/guide/en/elasticsearch/reference/current/install-elasticsearch.html), [OSX](https://www.elastic.co/guide/en/elasticsearch/reference/current/install-elasticsearch.html), [Windows](https://www.elastic.co/guide/en/elasticsearch/reference/current/windows.html)
* Monstache v.2.6 - [Github](https://github.com/rwynn/monstache)

### Programming Languages

JavaScript is the language of choice at Beamery for both our Front and Backend. [Node.js](https://nodejs.org/en/) is a JavaScript runtime built on Chrome's V8 JavaScript engine. Node.js uses an event-driven, non-blocking I/O model that makes it lightweight and efficient and is what powers up our backend.

> Currently we are locked on Node.js v4.3.2+ with `npm v2.14.12+`


## Environment Setup

We have tried to automate as much as we can, the process of installing and setting up the required software. In this section, we will explain all the steps required to setup your machine from zero to hero.

We recommend that you clone this repo into the folder where all of Beamery's projects will be. To do that you can execute:

```
git clone https://github.com/SeedJobs/tool-dev-env.git && cd tool-dev-env && . setup.sh
```
> note that at this point, you need to authenticate yourself with Github unless you have already set up SSH keys

There are two script that you need to execute back-to-back:

 - `setup.sh`: the main script that will install the required software and various helpers and libs
 - `configure.sh`: a configuration script to be executed after the main software has been installed. It executes various configurations and parameters tuning. If you ran the `setup.sh` then this will be executed automatically after

> The following sections will explain in details what those automatic scripts are doing. You should be able to understand what and why we are doing things, and (hopefully you will not need to) be able to debug and fix any issues that might rise.

We will also explain in details what happens in each step and what is the intended goal. We do that so that you can have a deep understanding of what is happening and be able to debug it if the script fails for any reason.

> The current installation script works for UNIX-based machines (OSX, Linux), and there is no support yet for a windows machine

Depending on your operating system of choice (Linux, OS X, or Windows) installing these components will have slightly different steps. The main step here is to ensure you have each of the servers listening on `localhost` which should point to `127.0.0.1`.

**Note:** OS X has a quirk where once installed with `brew` you will need to restart your system for it to properly listen on the `localhost` interface

### 1. Setting up SSH

**Secure Shell (SSH)** is a cryptographic network protocol for operating network services securely over an unsecured network. The best known example application is for remote login to computer systems by users. It is mainly used to communicate with our Git repositories in Github and our servers.

Setting up SSH requires a set of **keys** to be generated. These keys are used to secure the login with remote servers.

```bash
ssh-keygen -t rsa -b 4096 -C "$EMAIL"
# Add your key to the ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa
```

As you can see above, we generate the SSH keys and attach the email we prompted for in the first part of the script. This step generates two keys (a private key called by default id_rsa and a pulbic key called id_rsa.pub). You will never give away your private key, but you will need to give your public key to the administrator to ensure you can login smoothly to our remote servers and to add that as well to Github so that you can interact with our hosted repos there.

### 2. Configure `BEAMERY_HOME`

An important Unix concept is the environment, which is defined by environment variables. Some are set by the system, others by you, yet others by the shell, or any program that loads another program.

To easily configure various software, we need to setup an environment variable called `BEAMERY_HOME`. This destination will contain all the Beamery repos that will be pulled in from Github.

> In the installation script, you can use autocomplete to point out to the path you wish

Basically, this step will create two entries in your `.bash_profile` or `.bashrc` or `.zshrc` (depending on your shell and operating system). These entries will be:

```bash
# This will contain the location in your file system to beamery folder
# BEAMERY_HOME=<LOCATION_TO_BEAMERY_FOLDER>
BEAMERY_HOME="/Users/ahmadassaf/Projects/Beamery"
# This will contain the location for the executable bin files used, note that the location
# tool-dev-env/env/bin/ contains two folders. One for Linux and one for OSX as they have different
# executables. You need to speify your OS after /bin
PATH=$PATH:$BEAMERY_HOME/tool-dev-env/env/bin/osx
```

### Install pre-requisits

In this step, we are installing various pre-requisits that are required for the installation of the various software needed.

#### Linux

```bash
sudo apt-get install build-essential
sudo apt-get install libssl-dev
sudo apt-get install apt-transport-https
```
We will also check if `git` is not installed and **force** installing it. In addition, if you have selected `zsh` as your shell but it was not installed then we will prompt you to install it.

#### OSX

```bash
# We first need to make sure brew is installed. If not, then you need to install
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
# We will also install brew cask
brew tap caskroom/cask
```
We will also check if `git` is not installed and **force** installing it. In addition, if you have selected `zsh` or `bash` as your shell but it was not installed then we will prompt you to install it.

### 3. Shell and Shell Helpers

In this step, the user will be prompted if he wished to install any shell helper based on the shell he wishes to use. Currently, this script supports both `bash >= 4.x` and `zsh >- 5.x`. The shell helpers supported are [bash-it](https://github.com/Bash-it/bash-it) which is a plugins framework for bash and [oh-my-zsh](https://github.com/robbyrussell/oh-my-zsh) plugins framework for zsh.

The user will be also prompted to install specific beamery shell helpers that are detailed in the [plugins folder](https://github.com/SeedJobs/tool-dev-env/tree/master/plugins)

### 4. Software Installation

In this step, based on your operating system, the script will install a set of required software. You will be prompted at each step so that you can control exactly what you need to be installed.

> This step also makes sure you have a set of prerequisites like git, brew (for Mac) and so on.
> For Mac users, we **strongly recommend** you accept the installation of brew as it eases a lot the process of software installation

The softwares to be installed are:

| Software      | Required    | Description                                                                                                                   |
|---------------|-------------|-------------------------------------------------------------------------------------------------------------------------------|
| MongoDB       | Yes         | Our primary document-oriented database                                                                                        |
| Redis         | Yes         | Our in-memory data structure store, used as a database, cache and message broker.                                             |
| RabbitMQ      | Yes         | Our message broker software that implements the Advanced Message Queuing Protocol (AMQP)                                      |
| Java          | Yes         | A requirement for ElasticSearch with a minimum version of 8.0                                                                 |
| ElasticSearch | Yes         | Elasticsearch is a distributed, RESTful search and analytics engine                                                           |
| kibana        | Recommended | Kibana lets you visualize your Elasticsearch data and navigate the Elastic Stack                                              |
| Logstash      | No          | Logstash is an open source, server-side data processing pipeline that ingests data from a multitude of sources simultaneously |
| Monstache     | Yes         | A go daemon which syncs mongodb to elasticsearch in neal realtime                                                             |

The script gives you the option to install Node.js either via [NVM](https://github.com/creationix/nvm) where you can manage various Node versions, or manually where it will install Node.js version 4.x.

If you do not wish to use the script to install the required software, you can use the following steps according to your operating system:

#### Linux

```bash
# Adding MongoDB keys
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
echo "deb http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list

# Adding RabbitMQ Keys
echo 'deb http://www.rabbitmq.com/debian/ testing main' | sudo tee /etc/apt/sources.list.d/rabbitmq.list
wget -O- https://www.rabbitmq.com/rabbitmq-release-signing-key.asc | sudo apt-key add -

# Adding ElasticSearch Key
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/5.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-5.x.list

# Adding Kibana Key
echo "deb http://packages.elastic.co/kibana/4.4/debian stable main" | sudo tee -a /etc/apt/sources.list.d/kibana-4.4.x.list

# Adding Logstash Key
echo 'deb http://packages.elastic.co/logstash/2.2/debian stable main' | sudo tee /etc/apt/sources.list.d/logstash-2.2.x.list

# Adding JVM Repository
sudo add-apt-repository ppa:webupd8team/java

# Update apt repositories list
sudo apt-get update
sudo apt-get upgrade

# Install the required software
sudo apt-get -y --force-yes install mongodb-org
sudo apt-get -y --force-yes install redis-server
sudo apt-get -y --force-yes install rabbitmq-server
sudo apt-get -y --force-yes install oracle-java8-installer
sudo apt-get -y --force-yes install oracle-java8-set-default
sudo apt-get -y --force-yes install elasticsearch
sudo apt-get -y --force-yes install kibana
sudo apt-get -y --force-yes install logstash
```

> Please make sure you install Java before installing ElasticSearch, Kibana or Logstash as they all require JVM to be installed

#### OSX

```bash
# Install the required software
brew cask install java
brew install coreutils
brew install mongodb
brew install rabbitmq
brew install elasticsearch
brew install kibana
brew install logstash
brew install git-extras
brew install tmux
```

### Node.js and Global Packages

Currently we are locked on Node.js v4.3.2+ with `npm v2.14.12+`. Once you have installed `Node.js` either manually or via the script, you can then install each of the packages using the `npm` package manager.

Node.js' package ecosystem, npm, is the largest ecosystem of open source libraries in the world. We take advantage of various npm packages in our day-to-day work. The script will prompt you to install each package, but we recommend that you install all of them. The global npm packages to be installed are:

> Currently we do not support `npm3` due to an issue with `Zelda` linking. This will hopefully be resolved soon.

**Required:**

 - [**pm2**](http://pm2.keymetrics.io/): Advanced, production process manager for Node.js
 - [**zelda@2.4.3**](https://github.com/feross/zelda): Automatically `npm link` all your packages together

**Recommended:**

 - [**bosco**](http://bosco.readme.io): Bosco is a utility knife to help manage the complexity that using microservices. The main use for it is to easily clone all the repos that we have in Github. Bosco installation can be skipped if you wish to manually clone all the repos one by one.
 - [**bower**](http://bower.io/): Bower is a package manager that can manage components that contain HTML, CSS, JavaScript, fonts or even image files. Bower doesn’t concatenate or minify code or do anything else - it just installs the right versions of the packages you need and their dependencies.
 - [**caniuse-cmd**](https://github.com/sgentle/caniuse-cmd): "Can I use" provides up-to-date browser support tables for support of front-end web technologies on desktop and mobile web browsers.
 - [**grunt-cli**](http://gruntjs.com/): A JavaScript Task Runner
 - [**gulp-cli**](https://github.com/gulpjs/gulp): A JavaScript streaming build engine and task runner
 - [**mocha**](https://mochajs.org/): Mocha is a feature-rich JavaScript test framework running on Node.js and in the browser
 - [**Istanbul**](http://gotwarlost.github.io/istanbul/): A Javascript code coverage tool written in JS
 - [**node-inspector**](https://github.com/node-inspector/node-inspector): Node.js debugger based on Blink Developer Tools
 - [**code-notes**](https://github.com/ahmadassaf/code-notes):  It allows you to put comments in your code and then have them annotated across your whole project
 - [**prettyjson**](https://github.com/rafeca/prettyjson): Package for formatting JSON data in a coloured YAML-style, perfect for CLI output
 - [**npm-clean**](https://github.com/afc163/npm-clean): Clean unused dependencies in package.json
 - [**npm-check**](https://github.com/dylang/npm-check): Check for outdated, incorrect, and unused dependencies in package.json

If you to manually install any of the packages above, you can do that manually by:

```shell
npm install -g pm2
npm install -g bosco
npm install -g zelda@2.4.3
...
```

### Developer Productivity

This section will walk you through various hacks and configurations that aims at increasing developers productivity and automate the development process.

#### .editorconfig

[`.editorconfig`](http://editorconfig.org) helps developers define and maintain consistent coding styles between different editors and IDEs. The EditorConfig project consists of a file format for defining coding styles and a collection of text editor plugins that enable editors to read the file format and adhere to defined styles. EditorConfig files are easily readable and they work nicely with version control systems.

When opening a file, EditorConfig plugins look for a file named .editorconfig in the directory of the opened file and in every parent directory. A search for .editorconfig files will stop if the root filepath is reached or an EditorConfig file with root=true is found.

EditorConfig files are read top to bottom and the closest EditorConfig files are read last. Properties from matching EditorConfig sections are applied in the order they were read, so properties in closer files take precedence.

Our .editorconfig file is:

```yaml
root = true

[*]
insert_final_newline = true
charset = utf-8
trim_trailing_whitespace = true
end_of_line = lf

[*.{js,json}]
indent_style = space
indent_size = 2

[*.py]
indent_style = space
indent_size = 4

[*.yml]
indent_style = space
indent_size = 2
```
As part of the developer productivity automation, we prompt the user in the installation if he wishes to add the `.editorconfig` file at the root of each folder. At this step, the file will be copied to all the repos that exists under `BEAMERY_HOME` which assumes that has been already set in the steps above and if not will prompt the user to set that up.

#### Editors Configuration

At this step, we are prompting the user to install some of the well known editors; [SublimeText](https://www.sublimetext.com) and [Atom](http://atom.io).

##### Sublime Text

[Sublime Text](https://www.sublimetext.com) is a very powerful and popular editor/"ecosystem" with various tools for every code you’ll face. However, entering this ecosystem is long walk; setting up and learning all the plugins, tricks and such will take time.

In short, this script aims at automatic installation + configuration of Sublime Text in OSX, Linux by:

 1. Installs `Sublime Text 3` with `apt-get` or `brew`
 2. Installs `Package Control`
 3. Instals your desired theme that you backup in the `./themes` folder
 4. Load your default configurations that you have in `./user-settings`
 5. Configure projects (either single or multiple projects at a time)

The setup script works transparently across all platforms by leveraging python as well as OS-specific package managers

To read more about what this does, check the [full documentation](templates/editors/sublime/README.md)

##### Atom

[Atom](http://atom.io) Atom is a text editor that's modern, approachable, yet hackable to the core—a tool you can customize to do anything but also use productively without ever touching a config file.

To read more about what this does, check the [full documentation](templates/editors/atom/README.md)

#### Various Productivity Stuff

As part of the software installation, we recommend that you accept installing the following:

 - [git-extras](https://github.com/stevemao/awesome-git-addons#git-extras): Various additional git commands that will increase your git powers
 - [hub](https://github.com/github/hub): hub is a command line tool that wraps git in order to extend it with extra features and commands that make working with GitHub easier.

## Environment Configuration

**Important**: Before running the configuration, please make sure you have sourced your main shell dotfile `.zshrc`, `.bash_profile` or `.bashrc` (or simply if you don't know how to .. quit and reopen your terminal :) )

> Please make sure that RabbitMQ is running and ElasticSearch is running before running the `configure.sh` .. in the future starting those will be done by PM2 if you wish, but starting them manually is required now to configure them beforehand

Some of the installed software need to be configured to work properly. To do all the required configuration, you will need to run `sh configure.sh`. This will make sure to:

 - configure rabbitMQ via `env/lib/queueSetup.sh`
 - configure MongoDB via `env/lib/mongodbSetup.sh`
 - configure ElasitcSearch via `env/lib/elasticSearchSetup.sh`
 - install and configure Monstache via `env/lib/monstacheSetup.sh`

We have already compiled the binaries for both Mac OSX and Linux 64 bits for installation. If you wish to install Monstache manually then you need to grab the binary that matches your operating system from `env/bin` and copy that basically anywhere that can be sourced from your `.bash_profile` or `/.bashrc`. In our configuration script we configure a `BEAMERY_HOME` environment variable and we source the `bin` folder in `tool-dev-env` there so that any binary file there will be picked up.

#### Other Tools

The following are tools that we do not install via the automatic script but you might want to install separately as they can be useful:

* [Redis Desktop Manager](http://redisdesktop.com/download)
* [3T MongoChef](http://3t.io/mongochef/download/platform/)
* [ngrok v2.0+](https://ngrok.com/download) (mainly for testing web hooks)

## Getting Started

Reaching here we assume that you already have installed all the needed software and the `setup.sh` script finished successfully.

### Hosts

In addition to software requirements a number of hosts that point to `127.0.0.1` need to be configured. On `Linux` and `OS X` you can edit the file `/etc/hosts` and make sure that a line that looks like the following is present:

```
127.0.0.1    dev.seed.jobs app.dev.seed.jobs api.dev.seed.jobs mail.dev.seed.jobs notify.dev.seed.jobs sherlock.dev.seed.jobs widget.dev.seed.jobs queue.dev.seed.jobs rmq.dev.seed.jobs admin.dev.seed.jobs
```

### Databases

Setting up databases need to happen in a certain order that is described below:

#### MongoDB

An import script is in the works, until then please request a copy of the MongoDB databases to import locally.

Since [Monstache](https://github.com/rwynn/monstache) uses the mongodb oplog to tail events it is required that mongodb is configured to produce an oplog. For that, we need to make sure that it starts with a replicaSet name defined in the config file and with it pointing correctly to a data folder.

> The configuration for replicaSets is set in the MongoDB configuration file in `/env/configs/mongodb.yml`.

Starting MongoDB to produce oplog can happen in one of two ways:

 1. `--master` flag so that the command is `mongod --master --dbpath ~/Applications/mongodb/data/db`
 2. `--config`: path to the main configuration file where we define the replicaSet name

A parameter that is always needed to be set is `--dbpath` which is the location to the data folder that MongoDB will be reading/writing to

> If you have installed mongo with brew then the default path for Mongo data folder is `/usr/local/var/mongodb`

```bash
# Starting MongoDB can happen in two ways that you define in the mongodb.sh
# Method 1: Using the --master flag
mongod --master --dbpath ~/Applications/mongodb/data/db

# Method 2: Using a replicaSet defined in the configuration file
mongod --config /.../Beamery/tool-dev-env/env/configs/mongodb.conf --dbpath ~/Applications/mongodb/data/db
```

If you use the main configuration file `configure.sh` then you will prompted for the data folder location and a MongoDB start script called `mongodb.sh` will be created in `env/mongodb.sh` the will look like:

```bash
#!/bin/bash
mongod --master --dbpath ~/Applications/mongodb/data/db
```

**Important**: If you have used the configuration file to set replicaSets then it is important that you initialize the replicaSet from Mongo shell. You can do this first by logging into MongoDB shell by executing `mongo` in terminal. Then you will need to execute the following:

```bash
// Init replica set
rs.initiate({
    _id : "seed_replicaSet",
    members: [
        { _id : 0, host : "127.0.0.1:27017" }
    ]
});
```
> Note that the `_id` here is the name that we defined inside of `mongodb.conf`

#### Elasticsearch

ElasticSearch works out-of-the-box just fine. However, we need to adjust few configurations that are specific for CORS settings. The ElasticSearch configuration are set inside `env/configs/elasticsearch.yml` as follows:

```yml
http.cors.enabled : true
http.cors.allow-origin : "*"
http.cors.allow-methods : OPTIONS, HEAD, GET, POST, PUT, DELETE
http.cors.allow-headers : X-Requested-With,X-Auth-Token,Content-Type, Content-Length
```

The preferred way to start elastic which we configured in the startup script `env/elasticSearch.sh` is by passing a path to the configuration directory for the command:

```bash
elasticSearch -E path.conf="${PWD}/env/configs/"
```

> Note that the path is for the directory that has the configuration files and not to the configuration file itself. For that reason as well, we have added the `log4j2.properties` file in there as well to be picked up by elastic

If you do not wish to start elastic with the startup script then you need to make sure that you set up the HTTP CORS settings as we defined above.


#### Monstache

Before starting Monstache, we need to **make sure that ElasticSearch is running** so that we can configure it for our replication needs. You can then either run the `env/lib/elasticSearchSetup.sh` directly, or you can configure elastic from the `configure.sh` script as the last step.

Basically the configuration has two steps that you can execute from your terminal:

```bash
# Disable dynamic mapping creation
curl -XPUT 'localhost:9200/_template/template_all' -d '{"template": "*","order":0,"settings": {"index.mapper.dynamic": false}}'

# Define the new ElasticSearch Mappings
curl -XPUT 'localhost:9200/seed.contacts' -d `cat "$SOURCE_LOCATION/env/configs/elasticSearch/contactsMappings.json"`
```

> If you wish to set the mappings manually then you need to point the curl function to the correct mapping file in `env/configs/elasticSearch/contactsMapping.json` or inline the JSON string directly in the command

Starting Monstache should be also done by passing a valid configuration file that is defined in `env/configs/monstache.toml` with the command in the startup script `env/monstache.sh`:

```bash
monstache -f "${PWD}/env/configs/monstache.toml"
```

> To make sure that ElasticSearch is configured and running properly, navigate to localhost:9200/seed.contacts in your browser

> Please note that you need to have MongoDB and ElasticSearch running before starting Monstache

The replication will start for newly created/updated data. In order to make sure that all existing contacts data is moved to Elastic as well, we add a new timestamp property with the following script:

```js
// Get all contacts
db.contacts.find({}).forEach(function(doc) {
    // Trigger update the doc
    db.contacts.updateOne({ id: doc.id }, { $set: { es: new Date() } });
});
```
This will make sure that all existing data is moved from Mongo through Monstache to Elastic

### Queue

When using `service-queue`, you have to start RabbitMQ, and run the `queueSetup.sh` script found inside this repo in `env/lib/queueSetup.sh`, to setup queues and install plugins. However, if you ran the main configuration script `configure.sh` then this will be executed as part of that script.

### Zelda & Linking

Before you can run any code you will need to do an `npm install` inside of each of the main repositories. This will pull in any code dependencies. If however you are developing a particular component and need to be on a branch other than `master` then you will need to make use of the command line tool `zelda`. This allows us to perform npm linking without the pain of manually linking all repos one-by-one.

Using `api-core` as an example...

```
// Move into API core folder
cd /path/to/src/api-core

// Link with Zelda where src is the root folder where all of Beamery repos reside
zelda /path/to/src/
```
Zelda will now link all local code repositories and install other modules with npm. Once done with all the main API repos you wish to run you can then move on to starting up.

The main repositories that need to be linked are:
- `api-core`
- `api-mail`
- `api-notifications`
- `api-portal`
- `app-admin`
- `service-campaign-stats`
- `service-cron`
- `service-queue`


### Start Steps

We have also used PM2 to control our dev-env software. To do that, you simply need to execute:

```bash
pm2 start beamery-env.json

# This will make sure all the needed software is running ..
┌───────────────┬────┬──────┬───────┬────────┬─────────┬────────┬─────┬────────────┬──────────┐
│ App name      │ id │ mode │ pid   │ status │ restart │ uptime │ cpu │ mem        │ watching │
├───────────────┼────┼──────┼───────┼────────┼─────────┼────────┼─────┼────────────┼──────────┤
│ elasticSearch │ 4  │ fork │ 28505 │ online │ 0       │ 13m    │ 0%  │ 728.0 KB   │ disabled │
│ mongo         │ 3  │ fork │ 28503 │ online │ 0       │ 13m    │ 0%  │ 692.0 KB   │ disabled │
│ monstache     │ 6  │ fork │ 28536 │ online │ 0       │ 13m    │ 0%  │ 908.0 KB   │ disabled │
│ rabbitMQ      │ 5  │ fork │ 55836 │ online │ 60      │ 9m     │ 0%  │ 696.0 KB   │ disabled │
│ redis         │ 7  │ fork │ 83718 │ online │ 0       │ 0s     │ 0%  │ 1.2 MB     │ disabled │
└───────────────┴────┴──────┴───────┴────────┴─────────┴────────┴─────┴────────────┴──────────┘
```

Now we are using [pm2](http://pm2.keymetrics.io/) to manage multiple instances in our environment.

```bash
# The first launch when you start
cd /path/to/src/tool-dev-env
pm2 start beamery.json

# start only specific services
pm2 start beamery.json --only core queue:generic

# Restart the instances
pm2 restart all

# Restart a specific instance (core, queue, mail, notifications, portal, sherlock, admin)
pm2 restart core

# Show logs for all instances
pm2 logs all

# Show logs for one instance
pm2 logs core

# Monitor CPU and memory usage for each instance
pm2 monit

# View the state of running processes
pm2 ls
pm2 status
```

> Note: If you require to run sudo before starting rabbitMQ then you need to run pm2 with sudo so that `sudo pm2 start beamery-env.json`

