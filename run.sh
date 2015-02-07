#!/bin/bash

ASTERISKUSER=asterisk
ASTERISKVER=13.1
FREEPBXVER=12.0.21
ASTERISK_DB_PW=pass123

#Install packets that are needed
apt-get update && apt-get install -y build-essential curl libgtk2.0-dev linux-headers-`uname -r` openssh-server apache2 mysql-server mysql-client bison flex php5 php5-curl php5-cli php5-mysql php-pear php-db php5-gd curl sox libncurses5-dev libssl-dev libmysqlclient-dev mpg123 libxml2-dev libnewt-dev sqlite3 libsqlite3-dev pkg-config automake libtool autoconf git subversion unixodbc-dev uuid uuid-dev libasound2-dev libogg-dev libvorbis-dev libcurl4-openssl-dev libical-dev libneon27-dev libsrtp0-dev libspandsp-dev wget sox mpg123 libwww-perl php5 php5-json libiksemel-dev lamp-server^

#Add user
# grab gosu for easy step-down from root
groupadd -r $ASTERISKUSER \
  && useradd -r -g $ASTERISKUSER $ASTERISKUSER \
  && mkdir /var/lib/asterisk \
  && chown $ASTERISKUSER:$ASTERISKUSER /var/lib/asterisk \
  && usermod --home /var/lib/asterisk $ASTERISKUSER \
  && rm -rf /var/lib/apt/lists/* \
  && curl -o /usr/local/bin/gosu -SL 'https://github.com/tianon/gosu/releases/download/1.1/gosu' \
  && chmod +x /usr/local/bin/gosu \
  && apt-get purge -y

#Install Pear DB
pear uninstall db && pear install db-1.7.14

#build pj project
#build jansson
cd /temp/src/
git clone https://github.com/asterisk/pjproject.git \
git clone https://github.com/akheron/jansson.git \
cd /temp/src/pjproject \
  && ./configure --enable-shared --disable-sound --disable-resample --disable-video --disable-opencore-amr \
  && make dep \
  && make \
  && make install \
  && cd /temp/src/jansson \
  && autoreconf -i 1>/dev/null \
  && ./configure 1>/dev/null \
  && make 1>/dev/null \
  && make install
  
# Download asterisk.
# Currently Certified Asterisk 13.1.
curl -sf -o /tmp/asterisk.tar.gz -L http://downloads.asterisk.org/pub/telephony/certified-asterisk/certified-asterisk-13.1-current.tar.gz 1>/dev/null

# gunzip asterisk
mkdir /tmp/asterisk
tar -xzf /tmp/asterisk.tar.gz -C /tmp/asterisk --strip-components=1
cd /tmp/asterisk

# make asterisk.
# Configure
./configure 1> /dev/null
# Remove the native build option
make menuselect.makeopts 1>/dev/null
sed -i "s/BUILD_NATIVE//" menuselect.makeopts
# Continue with a standard make.
make 1> /dev/null
make install 1> /dev/null
make config 1>/dev/null
ldconfig  

cd /var/lib/asterisk/sounds \
  && wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-extra-sounds-en-wav-current.tar.gz 1>/dev/null \
  && tar xfz asterisk-extra-sounds-en-wav-current.tar.gz \
  && rm -f asterisk-extra-sounds-en-wav-current.tar.gz \
  && wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-extra-sounds-en-g722-current.tar.gz 1>/dev/null \
  && tar xfz asterisk-extra-sounds-en-g722-current.tar.gz \
  && rm -f asterisk-extra-sounds-en-g722-current.tar.gz \
  && chown $ASRERISKUSER. /var/run/asterisk \
  && chown -R $ASTERISKUSER. /etc/asterisk \
  && chown -R $ASTERISKUSER. /var/lib/asterisk \
  && chown -R $ASTERISKUSER. /var/www/ \
  && chown -R $ASTERISKUSER. /var/www/* \
# && chown -R $ASTERISKUSER. /var/www/html/admin/libraries \
  && chown -R $ASTERISKUSER. /var/log/asterisk \
  && chown -R $ASTERISKUSER. /var/spool/asterisk \
  && chown -R $ASTERISKUSER. /var/run/asterisk \
# && chown -R $ASTERISKUSER. /usr/lib/asterisk \
  && mkdir /etc/freepbxbackup \
  && chown $ASTERISKUSER:$ASTERISKUSER /etc/freepbxbackup \
  && rm -rf /var/www/html

#mod to apache
#Setup mysql
sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php5/apache2/php.ini \
  && cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf_orig \
  && sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf \
  && service apache2 restart \
  && /etc/init.d/mysql start \
  && mysqladmin -u root create asterisk \
  && mysqladmin -u root create asteriskcdrdb \
  && mysql -u root -e "GRANT ALL PRIVILEGES ON asterisk.* TO $ASTERISKUSER@localhost IDENTIFIED BY '$ASTERISK_DB_PW';" \
  && mysql -u root -e "GRANT ALL PRIVILEGES ON asteriskcdrdb.* TO $ASTERISKUSER@localhost IDENTIFIED BY '$ASTERISK_DB_PW';" \
  && mysql -u root -e "flush privileges;"

cd /tmp
RUN wget http://mirror.freepbx.org/freepbx-$FREEPBXVER.tgz 1>/dev/null \
  && ln -s /var/lib/asterisk/moh /var/lib/asterisk/mohmp3 \
  && tar vxfz freepbx-$FREEPBXVER.tgz \
  && cd /tmp/freepbx \
  && /etc/init.d/mysql start \
  && /usr/sbin/asterisk \
  && ./install_amp --installdb --username=$ASTERISKUSER --password=$ASTERISK_DB_PW \
  && amportal chown \
  && amportal reload \
  && asterisk -rx "core restart now" \
  && amportal chown \
#  && amportal a ma install framework 1>/dev/null \
#  && amportal a ma install core 1>/dev/null \
#  && amportal a ma install voicemail 1>/dev/null \
#  && amportal a ma install sipsettings 1>/dev/null \
#  && amportal a ma install infoservices 1>/dev/null \
#  && amportal a ma install featurecodeadmin 1>/dev/null \
#  && amportal a ma install logfiles 1>/dev/null \
#  && amportal a ma install callrecording 1>/dev/null \
#  && amportal a ma install cdr 1>/dev/null \
 # && amportal a ma install dashboard 1>/dev/null \
 

#  && amportal a ma installall 1>/dev/null \
   && amportal reload 1>/dev/null \
   && asterisk -rx "core restart now" \
   && amportal a ma refreshsignatures 1>/dev/null \
   && amportal chown \
   && amportal reload \
   && asterisk -rx "core restart now"