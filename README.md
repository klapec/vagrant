# Vagrant

This repo contains stuff necessary to set up local development environment for Wordpress and Ghost. It is based on [Vagrant](http://vagrantup.com) and [Varying Vagrant Vagrants](https://github.com/varying-vagrant-vagrants/vvv/). All credits and kudos to developers maintaining these fantastic projects.

### Requirements
* vagrant-hostsupdater plugin - `vagrant plugin install vagrant-hostsupdater`

### How to use
Once vagrant-hostsupdater installed, run `vagrant up` and you're ready to go.

### What's inside
* Ubuntu 14.04
* Nginx
* PHP
* MySQL
* Node
* Wordpress
* Ghost
* Git
* Fish shell with oh-my-fish

### Usernames and passwords

#### WordPress
* Local path: vagrant/www/wordpress
* VM path: /srv/www/wordpress
* URL: `http://wp.vvv.dev`
* Admin username: `admin`
* Admin password: `password`
* DB name: `wordpress`
* DB nsername: `wp`
* DB nassword: `wp`

#### MySQL
* User: `root`
* Pass: `root`

#### Ghost
* Local path: vagrant/www/ghost
* VM path: /srv/www/ghost
* URL: `http://ghost.vvv.dev`
* Admin panel URL: `http://ghost.vvv.dev/ghost`
