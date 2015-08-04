#!/bin/bash
start_seconds="$(date +%s)"

if [[ "$(wget --tries=3 --timeout=5 --spider http://google.com 2>&1 | grep 'connected')" ]]; then
	echo "Network connection detected."
	ping_result="Connected"
else
	echo "Network connection not detected. Unable to reach google.com."
	ping_result="Not Connected"
fi

# PACKAGE INSTALLATION
#
# Build a bash array to pass all of the packages we want to install to a single
# apt-get command. This avoids doing all the leg work each time a package is
# set to install. It also allows us to easily comment out or add single
# packages. We set the array as empty to begin with so that we can append
# individual packages to it as required.
apt_package_install_list=()

# Start with a bash array containing all packages we want to install in the
# virtual machine. We'll then loop through each of these and check individual
# status before adding them to the apt_package_install_list array.
apt_package_check_list=(
	php5-fpm
	php5-cli
	php5-common
	php5-dev
	php5-mysql
	php5-curl
	php-pear
	php5-gd
	nginx
	mysql-server
	sqlite
	nodejs
	git
	zip
	unzip
	fish
	htop
)

echo "Check for apt packages to install."

# Loop through each of our packages that should be installed on the system. If
# not yet installed, it should be added to the array of packages to install.
for pkg in "${apt_package_check_list[@]}"; do
	package_version="$(dpkg -s $pkg 2>&1 | grep 'Version:' | cut -d " " -f 2)"
	if [[ -n "${package_version}" ]]; then
		space_count="$(expr 20 - "${#pkg}")" #11
		pack_space_count="$(expr 30 - "${#package_version}")"
		real_space="$(expr ${space_count} + ${pack_space_count} + ${#package_version})"
		printf " * $pkg %${real_space}.${#package_version}s ${package_version}\n"
	else
		echo " *" $pkg [not installed]
		apt_package_install_list+=($pkg)
	fi
done

# MySQL
#
# Use debconf-set-selections to specify the default password for the root MySQL
# account. This runs on every provision, even if MySQL has been installed. If
# MySQL is already installed, it will not affect anything.
echo mysql-server mysql-server/root_password password root | debconf-set-selections
echo mysql-server mysql-server/root_password_again password root | debconf-set-selections

# Provide our custom apt sources before running `apt-get update`
ln -sf /srv/config/apt-source-append.list /etc/apt/sources.list.d/vvv-sources.list
echo "Linked custom apt sources."

if [[ $ping_result == "Connected" ]]; then
	# If there are any packages to be installed in the apt_package_list array,
	# then we'll run `apt-get update` and then `apt-get install` to proceed.
	if [[ ${#apt_package_install_list[@]} = 0 ]]; then
		echo -e "No apt packages to install.\n"
	else
		# Before running `apt-get update`, we should add the public keys for
		# the packages that we are installing from non standard sources via
		# our appended apt source.list

		# Retrieve the Nginx signing key from nginx.org
		echo "Applying Nginx signing key."
		wget --quiet http://nginx.org/keys/nginx_signing.key -O- | apt-key add -

		# Apply the git assigning key
		echo "Applying git signing key."
		apt-key adv --quiet --keyserver hkp://keyserver.ubuntu.com:80 --recv-key E1DF1F24 2>&1 | grep "gpg:"
		apt-key export E1DF1F24 | apt-key add -

		# Apply the fish assigning key
		echo "Applying fish signing key."
		apt-key adv --quiet --keyserver hkp://keyserver.ubuntu.com:80 --recv-key 6DC33CA5 2>&1 | grep "gpg:"
		apt-key export 6DC33CA5 | apt-key add -

		# Node.js repo
		echo "Adding node.js repository"
		curl -sS -L https://deb.nodesource.com/setup_0.12 | sudo bash -

		# Install required packages
		echo "Installing apt-get packages."
		apt-get install --assume-yes ${apt_package_install_list[@]}

		echo "Cleaning up apt caches."
		apt-get clean
	fi

else
	echo -e "\nNo network connection available, skipping package installation."
fi

# Configuration for nginx
if [[ ! -e /etc/nginx/server.key ]]; then
	echo "Generate Nginx server private key."
	vvvgenrsa="$(openssl genrsa -out /etc/nginx/server.key 2048 2>&1)"
	echo $vvvgenrsa
fi
if [[ ! -e /etc/nginx/server.csr ]]; then
	echo "Generate Certificate Signing Request (CSR)."
	openssl req -new -batch -key /etc/nginx/server.key -out /etc/nginx/server.csr
fi
if [[ ! -e /etc/nginx/server.crt ]]; then
	echo "Sign the certificate using the above private key and CSR."
	vvvsigncert="$(openssl x509 -req -days 365 -in /etc/nginx/server.csr -signkey /etc/nginx/server.key -out /etc/nginx/server.crt 2>&1)"
	echo $vvvsigncert
fi

echo -e "\nSetup configuration files."

# Used to to ensure proper services are started on `vagrant up`
echo " * /srv/config/init/vvv-start.conf               -> /etc/init/vvv-start.conf"
cp /srv/config/init/vvv-start.conf /etc/init/vvv-start.conf

# Copy nginx configuration from local
echo " * /srv/config/nginx-config/nginx.conf           -> /etc/nginx/nginx.conf"
cp /srv/config/nginx-config/nginx.conf /etc/nginx/nginx.conf

echo " * /srv/config/nginx-config/nginx-wp-common.conf -> /etc/nginx/nginx-wp-common.conf"
cp /srv/config/nginx-config/nginx-wp-common.conf /etc/nginx/nginx-wp-common.conf

echo " * /srv/config/nginx-config/sites/               -> /etc/nginx/custom-sites"
if [[ ! -d /etc/nginx/custom-sites ]]; then
	mkdir /etc/nginx/custom-sites/
fi
rsync -rvzh --delete /srv/config/nginx-config/sites/ /etc/nginx/custom-sites/

# Copy php-fpm configuration from local
echo " * /srv/config/php5-fpm-config/php5-fpm.conf     -> /etc/php5/fpm/php5-fpm.conf"
cp /srv/config/php5-fpm-config/php5-fpm.conf /etc/php5/fpm/php5-fpm.conf

echo " * /srv/config/php5-fpm-config/www.conf          -> /etc/php5/fpm/pool.d/www.conf"
cp /srv/config/php5-fpm-config/www.conf /etc/php5/fpm/pool.d/www.conf

echo " * /srv/config/php5-fpm-config/php-custom.ini    -> /etc/php5/fpm/conf.d/php-custom.ini"
cp /srv/config/php5-fpm-config/php-custom.ini /etc/php5/fpm/conf.d/php-custom.ini

echo " * /srv/config/homebin                           -> /home/vagrant/bin"
rsync -rvzh --delete /srv/config/homebin/ /home/vagrant/bin/



# RESTART SERVICES
#
# Make sure the services we expect to be running are running.
echo -e "\nRestarting services."
service nginx restart
service php5-fpm restart

# If MySQL is installed, go through the various imports and service tasks.
exists_mysql="$(service mysql status)"
if [[ "mysql: unrecognized service" != "${exists_mysql}" ]]; then
	echo -e "\nSetting up MySQL configuration file links."

	# Copy mysql configuration from local
	echo " * /srv/config/mysql-config/my.cnf               -> /etc/mysql/my.cnf"
	cp /srv/config/mysql-config/my.cnf /etc/mysql/my.cnf

	echo " * /srv/config/mysql-config/root-my.cnf          -> /home/vagrant/.my.cnf"
	cp /srv/config/mysql-config/root-my.cnf /home/vagrant/.my.cnf

	# MySQL gives us an error if we restart a non running service, which
	# happens after a `vagrant halt`. Check to see if it's running before
	# deciding whether to start or restart.
	if [[ "mysql stop/waiting" == "${exists_mysql}" ]]; then
		echo "Starting MySQL service."
		service mysql start
	else
		echo "Restarting MySQL service."
		service mysql restart
	fi

	# IMPORT SQL
	#
	# Create the databases (unique to system) that will be imported with
	# the mysqldump files located in database/backups/
	if [[ -f /srv/database/init-custom.sql ]]; then
		echo -e "\nInitial custom MySQL scripting."
		mysql -u root -proot < /srv/database/init-custom.sql
	else
		echo -e "\nNo custom MySQL scripting found in database/init-custom.sql, skipping."
	fi

	# Setup MySQL by importing an init file that creates necessary
	# users and databases that our vagrant setup relies on.
	echo "Initial MySQL preparations."
	mysql -u root -proot < /srv/database/init.sql

	# Process each mysqldump SQL file in database/backups to import
	# an initial data set for MySQL.
	/srv/database/import-sql.sh
else
	echo -e "\nMySQL is not installed. No databases imported."
fi

# Run wp-cli as vagrant user
if (( $EUID == 0 )); then
    wp() { sudo -EH -u vagrant -- wp "$@"; }
fi

if [[ $ping_result == "Connected" ]]; then
	# WP-CLI Install
	if [[ ! -a /usr/local/bin/wp ]]; then
		echo -e "\nDownloading wp-cli."
		curl -sS -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
		chmod +x wp-cli.phar
		sudo mv wp-cli.phar /usr/local/bin/wp
	fi

	# Install and configure the latest stable version of WordPress
	if [[ ! -d /srv/www/wordpress ]]; then
		echo "Downloading WordPress."
		cd /srv/www/
		curl -sS -L -O https://wordpress.org/latest.tar.gz
		tar -xvf latest.tar.gz
		rm latest.tar.gz
		cd /srv/www/wordpress
		echo "Configuring WordPress."
		wp core config --dbname=wordpress --dbuser=wp --dbpass=wp --quiet --extra-php <<PHP
define( 'WP_DEBUG', true );
PHP
		wp core install --url=wp.vvv.dev --quiet --title="Wordpress" --admin_name=admin --admin_email="admin@local.dev" --admin_password="password"
	else
		echo "Updating WordPress."
		cd /srv/www/wordpress
		wp core upgrade
	fi

	# Download phpMyAdmin
	if [[ ! -d /srv/www/default/database-admin ]]; then
		echo "Downloading phpMyAdmin 4.4.11."
		cd /srv/www/default
		wget -q -O phpmyadmin.tar.gz 'https://files.phpmyadmin.net/phpMyAdmin/4.4.11/phpMyAdmin-4.4.11-all-languages.tar.gz'
		tar -xf phpmyadmin.tar.gz
		mv phpMyAdmin-4.4.11-all-languages database-admin
		rm phpmyadmin.tar.gz
	else
		echo "PHPMyAdmin already installed."
	fi
	cp /srv/config/phpmyadmin-config/config.inc.php /srv/www/default/database-admin/
else
	echo -e "\nNo network available, skipping network installations."
fi

# Find new sites to setup.
# Kill previously symlinked Nginx configs
# We can't know what sites have been removed, so we have to remove all
# the configs and add them back in again.
find /etc/nginx/custom-sites -name 'vvv-auto-*.conf' -exec rm {} \;

# Look for site setup scripts
for SITE_CONFIG_FILE in $(find /srv/www -maxdepth 5 -name 'vvv-init.sh'); do
	DIR="$(dirname $SITE_CONFIG_FILE)"
	(
		cd $DIR
		source vvv-init.sh
	)
done

# Look for Nginx vhost files, symlink them into the custom sites dir
for SITE_CONFIG_FILE in $(find /srv/www -maxdepth 5 -name 'vvv-nginx.conf'); do
	DEST_CONFIG_FILE=${SITE_CONFIG_FILE//\/srv\/www\//}
	DEST_CONFIG_FILE=${DEST_CONFIG_FILE//\//\-}
	DEST_CONFIG_FILE=${DEST_CONFIG_FILE/%-vvv-nginx.conf/}
	DEST_CONFIG_FILE="vvv-auto-$DEST_CONFIG_FILE-$(md5sum <<< $SITE_CONFIG_FILE | cut -c1-32).conf"
	# We allow the replacement of the {vvv_path_to_folder} token with
	# whatever you want, allowing flexible placement of the site folder
	# while still having an Nginx config which works.
	DIR="$(dirname $SITE_CONFIG_FILE)"
	sed "s#{vvv_path_to_folder}#$DIR#" $SITE_CONFIG_FILE > /etc/nginx/custom-sites/$DEST_CONFIG_FILE
done

# RESTART SERVICES AGAIN
#
# Make sure the services we expect to be running are running.
echo -e "\nRestarting Nginx."
service nginx restart

# Parse any vvv-hosts file located in www/ or subdirectories of www/
# for domains to be added to the virtual machine's host file so that it is
# self aware.
#
# Domains should be entered on new lines.
echo "Cleaning the virtual machine's /etc/hosts file."
sed -n '/# vvv-auto$/!p' /etc/hosts > /tmp/hosts
mv /tmp/hosts /etc/hosts
echo "Adding domains to the virtual machine's /etc/hosts file."
find /srv/www/ -maxdepth 5 -name 'vvv-hosts' | \
while read hostfile; do
	while IFS='' read -r line || [ -n "$line" ]; do
		if [[ "#" != ${line:0:1} ]]; then
			if [[ -z "$(grep -q "^127.0.0.1 $line$" /etc/hosts)" ]]; then
				echo "127.0.0.1 $line # vvv-auto" >> /etc/hosts
				echo " * Added $line from $hostfile"
			fi
		fi
	done < $hostfile
done

# Install oh-my-fish
if [[ ! -d /home/vagrant/.oh-my-fish ]]; then
	echo "Installing Oh-my-fish"
	cd /home/vagrant/
	sudo -u vagrant -H sh -c "curl -L -sS https://github.com/oh-my-fish/oh-my-fish/raw/master/tools/install.fish | fish"
	mkdir -p .config/fish
	echo vagrant | sudo -S chsh -s /usr/bin/fish vagrant
else
	echo "Oh-my-fish already installed."
fi

# Install dotfiles
if [[ ! -d /home/vagrant/.dotfiles ]]; then
	echo "Installing dotfiles"
	cd /home/vagrant/
	sudo -u vagrant -H sh -c "git clone https://github.com/klapec/.dotfiles.git .dotfiles"
	cp .dotfiles/config.fish .config/fish/
	cd .oh-my-fish/plugins/
	sudo -u vagrant -H sh -c "git clone https://github.com/oh-my-fish/plugin-theme.git theme"
	sudo -u vagrant -H sh -c "git clone https://github.com/oh-my-fish/plugin-sublime.git sublime"
	sudo -u vagrant -H sh -c "git clone https://github.com/oh-my-fish/plugin-brew.git brew"
	cd ../themes/
	sudo -u vagrant -H sh -c "git clone https://github.com/oh-my-fish/theme-bobthefish.git bobthefish"
	rm bobthefish/fish_greeting.fish
	rm bobthefish/fish_right_prompt.fish
else
	echo "Dotfiles already installed."
fi

# Install Ghost
if [[ ! -d /srv/www/ghost ]]; then
	echo "Downloading Ghost."
	cd /srv/www/
	curl -L -sS https://ghost.org/zip/ghost-latest.zip -o ghost.zip
	unzip -uo ghost.zip -d ghost
	rm ghost.zip
	cd ghost
	echo "Setting up Ghost. (this will take some time)"
	npm install --production
	cp /srv/config/ghost-config/config.js /srv/www/ghost/
	cp /srv/config/ghost-config/ghost.conf /etc/init/
	service ghost start

else
	echo "Ghost already installed."
	service ghost restart
fi

# Clean up MOTD
if [[ -a /etc/update-motd.d/10-help-text ]]; then
	echo "Cleaning up MOTD."
	cd /etc/update-motd.d/
	rm 10-help-text 50-landscape-sysinfo 51-cloudguest 98-cloudguest

else
	echo "MOTD already cleaned up."
fi

end_seconds="$(date +%s)"
echo "-----------------------------"
echo "Provisioning complete in "$(expr $end_seconds - $start_seconds)" seconds."
if [[ $ping_result == "Connected" ]]; then
	echo "External network connection established, packages up to date."
else
	echo "No external network available. Package installation and maintenance skipped."
fi
echo "Visit http://vvv.dev"
