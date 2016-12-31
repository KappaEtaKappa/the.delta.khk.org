#!/bin/bash
#this script will handle the installation and rebuilding of all sub-projects of khk-web
#Joe Dailey

pwd=$(pwd)
ind="/opt/khk-web"
if [ "$pwd" != "$ind" ]; then
	echo !! Projects installed to the wrong directory.
	echo !! Projects must be installed to /opt/khk-web.
	exit 1
fi

	
if [ ! -d /opt/cert ]; then
	echo !! Missing /opt/cert/. These files are crucial for SSO with Google Drive.
	exit 1
fi


if [ ! -d /opt/tls ]; then
	echo !! Missing /opt/tls/. These files are crucial for HTTPS configuration.
	exit 1
fi

echo ::  Veryifying repo\(s\) are up to date.
git pull
git submodule init
git submodule update

#custom nginx conf
echo :: Installing main Nginx configuration
if ! which nginx > /dev/null 2>&1; then
	echo !! "Nginx not installed. Install and retry"
	exit 1
fi
sudo cp ./nginx/nginx.conf /etc/nginx/. -v
sudo mkdir /etc/nginx/sites -v

#sub-project installation and configuration
for D in `find . -maxdepth 1 -name "khk-*" -type d`
do
	echo :: Installing Nginx configuration for ${D#./}
	if cd ${D}; then
		if /bin/bash build.sh; then
			cd cp
			#Move nginx conf into place and test configuration
			site=$(find . -maxdepth 1 -name "*.site")
			echo $site
			if [ -f $site ]; then
				sudo cp $site /etc/nginx/sites/. -v
		        else
				echo !! ${D#./} is missing a NGINX .site config. Please see the standards in the README.
				exit 1
			fi
			echo :: Testing updated NGINX site config for ${D#./}.
			echo ::: \(Previously loaded sites may have already broken NGINX\) 
			sudo nginx -t
			service=$(find . -maxdepth 1 -name "*.service")
		        if [ -f $service ]; then
		                sudo cp $service /etc/systemd/system/.
				sudo systemctl daemon-reload
				sudo systemctl enable ${service#./}
				sudo systemctl start ${service#./}
		        else
		                echo !! Project located at ${D} is missing a systemd *.service file.
										echo !!! Please see the standards in the README.
		                exit 1
		        fi
			echo ""
			echo ""
			echo ?? ${D#./} has been successfully installed. Please verify successfull operation:
			echo ???  \(press \'q\' to continue\)
			echo ""
			echo ""
			sudo systemctl status ${service#./}
			echo ""
			echo ""
			cd ../../
		else
			exit 1
		fi
	else
		echo !! ${D#./} does not have a cp directory. Please see the standards in the README.
	fi

	sudo systemctl restart nginx.service
done

/bin/bash reload-apps.sh
