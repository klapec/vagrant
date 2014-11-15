# Vagrant

This repo contains stuff necessary to set up local development environment for Wordpress and Ghost. It is based on [Vagrant](http://vagrantup.com) and [Varying Vagrant Vagrants](https://github.com/varying-vagrant-vagrants/vvv/). All credits and kudos to developers maintaining these fantastic projects.

### What's inside
* Ubuntu 14.04
* Nginx
* PHP
* MySQL
* Node
* Wordpress
* Ghost
* Git
* Fish shell + oh-my-fish
* [Personal dotfiles](https://github.com/klapec/.dotfiles)

### Usernames and passwords

Database username and password for WordPress installation is `wp` and `wp`.

WordPress admin username and password for WordPress installation is `admin` and `password`.

#### WordPress
* LOCAL PATH: vagrant/www/wordpress
* VM PATH: /srv/www/wordpress
* URL: `http://wp.vvv.dev`
* DB Name: `wordpress`

#### MySQL
* User: `root`
* Pass: `root`

#### Ghost
* LOCAL PATH: vagrant/www/ghost
* VM PATH: /srv/www/ghost
* URL: `http://ghost.vvv.dev`
