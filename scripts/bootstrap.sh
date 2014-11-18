#!/bin/bash
source /etc/profile.d/env_variables.sh

PACKAGE_TYPE=$package
NAME=openresty
BUILD_DIR=/tmp/openresty

do_install_debian_dependencies() {
  # Installs needed package dependencies
  apt-get update
  apt-get upgrade -y
  apt-get -y install make
  apt-get -y install ruby1.9.1
  apt-get -y install ruby1.9.1-dev
  apt-get -y install git-core
  apt-get -y install libpcre3-dev
  apt-get -y install libxslt1-dev
  apt-get -y install libgd2-xpm-dev
  apt-get -y install libgeoip-dev
  apt-get -y install unzip
  apt-get -y install zip
  apt-get -y install curl
  apt-get -y install build-essential
  apt-get -y install libssl-dev
  apt-get -y install git

  # Installs FPM
  /usr/bin/gem1.9.1 install fpm --no-ri --no-rdoc

  # Installs package_cloud gem
  /usr/bin/gem1.9.1 install package_cloud --no-ri --no-rdoc
}

do_download_openresty_scripts() {
  local scriptspath=/usr/src/scripts
  mkdir -p $scriptspath
  cd $scriptspath
  curl -O -s https://github.com/rhoml/vagrant-openresty-dev/blob/master/scripts/openresty.init
  curl -O -s https://github.com/rhoml/vagrant-openresty-dev/blob/master/scripts/openresty.logrotate
}

do_retrieve_openresty_code() {
  local version=$openresty_version
  cd /usr/src
  curl -O -s http://openresty.org/download/ngx_openresty-${version}.tar.gz
}

do_build_openresty() {
  local version=$openresty_version
  cd /usr/src
  tar -zxvf ngx_openresty-${version}.tar.gz
  cd ngx_openresty-${version}
  ./configure \
    --with-luajit \
    --prefix=/opt/openresty \
    --conf-path=/opt/openresty/nginx/conf.d/nginx.conf \
    --error-log-path=/opt/openresty/nginx/logs/error.log \
    --http-log-path=/opt/openresty/nginx/logs/access.log \
    --http-client-body-temp-path=/opt/openresty/nginx/client_body_temp \
    --http-fastcgi-temp-path=/opt/openresty/nginx/fastcgi_temp \
    --http-scgi-temp-path=/opt/openresty/nginx/scgi_temp \
    --http-uwsgi-temp-path=/opt/openresty/nginx/uwsgi_temp \
    --http-proxy-temp-path=/opt/openresty/nginx/proxy_temp \
    --pid-path=/opt/openresty/nginx/logs/nginx.pid \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_geoip_module \
    --with-http_gzip_static_module \
    --with-http_image_filter_module \
    --with-http_realip_module \
    --with-http_stub_status_module \
    --with-http_ssl_module \
    --with-http_sub_module \
    --with-http_xslt_module \
    --with-ipv6 \
    --with-sha1=/usr/include/openssl \
    --with-md5=/usr/include/openssl \
    --with-mail \
    --with-mail_ssl_module \
    --with-http_stub_status_module \
    --with-http_secure_link_module \
    --with-http_sub_module && make
}

do_prepare_fpm() {
  local build_path=/tmp/openresty

  make install DESTDIR=$build_path
  mkdir -p $build_path/opt/openresty/nginx
  install -m 0555 -D /usr/src/scripts/openresty.init $build_path/etc/init.d/openresty
  install -m 0555 -D /usr/src/scripts/openresty.logrotate $build_path/etc/logrotate.d/openresty
}

do_build_fpm_package() {
  local build_path=/tmp/openresty
  local destination=deb
  local source=dir
  local package_name=openresty
  local version=$openresty_version
  local description='OpenResty (aka. ngx_openresty) is a full-fledged web application server by bundling the standard Nginx core, lots of 3rd-party Nginx modules, as well as most of their external dependencies.'
  local maintainer='Rhommel Lamas <roml@rhommell.com> @rhoml'

  cd $build_path
  fpm -s $source -t $destination -n $package_name -v $version --iteration 1 --maintainer "${maintainer}" -C $build_path \
  --description "${description}" \
  -d libxslt1.1 \
  -d libgd2-xpm \
  -d libgeoip1 \
  -d libpcre3 \
  .
}

do_push_package_cloud() {
  local package_name=$1

  echo "{\"https://packagecloud.io\":\"https://packagecloud.io\",\"token\":\"${pc_token}\"}" >> /root/.packagecloud
  package_cloud push rhoml/openresty/Ubuntu/precise /tmp/openresty/${package_name}
}

main() {
    do_install_debian_dependencies
    do_download_openresty_scripts
    do_retrieve_openresty_code
    do_build_openresty
    do_prepare_fpm
    do_build_fpm_package
    do_push_package_cloud openresty_${openresty_version}-1_${architecture}.deb
}

main
