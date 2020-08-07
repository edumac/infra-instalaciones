#!/bin/bash

# ------------------------------------------------------------------------------------------------------
# Actualizacion de GFEPY
# Se elimina archivo de instalador anterior (si existe)
# Se descarga del ftp la beta a actualizar
# Se setean permisos de ejecución
# Se ejecuta instlaador en modo silencioso, apuntando a parametros de instalacion preexistentes
# Se cambia el owner de toda la carpeta tomcat (entre los archivos están los que se acaban de instalar)
# ------------------------------------------------------------------------------------------------------

# ------------------------------------------------------------------------------------------------------
# Seteo de variables del proceso
# ------------------------------------------------------------------------------------------------------
v_ejecutable_instalador=GFE_unix_2_28_00.sh
v_carpeta_instaladores=/home/datalogic/INSTALADORES/
v_carpeta_configuracion_instalacion=/home/datalogic/ARCHIVOS_INSTALACIONES/gfepy.test-gfe
v_ftp_usuario=cliente
v_ftp_password=cli.1717
v_ftp_carpeta_betas=GFE/betas
v_tomcat_usuario=tomcat
v_tomcat_grupo=tomcat
v_tomcat_carpeta=/opt/tomcat

echo "=== Moviendo a carpeta de instaladores: " $v_carpeta_instaladores 
cd $v_carpeta_instaladores

echo "=== Eliminando instalador anterior: " $v_ejecutable_instalador
rm -f ./$v_ejecutable_instalador

echo "=== Descargando instlaador desde ftp (carpeta de betas): ftp://ftp.datalogic.com.uy/"$v_ftp_carpeta_betas/$v_ejecutable_instalador
wget ftp://$v_ftp_usuario:$v_ftp_password@ftp.datalogic.com.uy/$v_ftp_carpeta_betas/$v_ejecutable_instalador

echo "=== Seteando permisos de ejecución en: " $v_ejecutable_instalador
chmod 777 ./$v_ejecutable_instalador

echo "=== Ejecutando instalador en base a configuración de carpeta: " $v_carpeta_configuracion_instalacion
./$v_ejecutable_instalador -q -dir $v_carpeta_configuracion_instalacion

echo "=== Cambiando owner para ejecución de tomcat en archivos instalados en carpeta " $v_tomcat_carpeta
chown -R $v_tomcat_usuario:$v_tomcat_grupo $v_tomcat_carpeta

# ------------------------------------------------------------------------------------------------------
# Recarga de la aplicacion 
# En lugar de bajar el tomcat completo, se procede a recargar la aplicación que se acaba de actualizar.
# para esto se invoca por crul el comando de recargar
# Atención: para poder hacer esto el usuario datalogic debe tener rol manager-script en tomcat-users.xml
#           en /opt/tomcat/conf/Catalina/gfepy.test.datalogic-software.com/manager.xml debe agregarse 
#           127.0.0.1 a las ip aceptadas.
# Si no se desea recargar individualmente la aplicacion, se puede bajar el tomcat completo con:
# systemctl stop tomcat
# systemctl start tomcat

echo "=== Recargando aplicaciones... " 
curl --user datalogic:dlc/1840 http://gfepy.test.datalogic-software.com:8080/manager/text/reload?path=/dlportal
curl --user datalogic:dlc/1840 http://gfepy.test.datalogic-software.com:8080/manager/text/reload?path=/gfeserver
curl --user datalogic:dlc/1840 http://gfepy.test.datalogic-software.com:8080/manager/text/reload?path=/gfeclient
curl --user datalogic:dlc/1840 http://gfepy.test.datalogic-software.com:8080/manager/text/reload?path=/FirmaCFE
curl --user datalogic:dlc/1840 http://gfepy.test.datalogic-software.com:8080/manager/text/reload?path=/rutinasgfe
curl --user datalogic:dlc/1840 http://gfepy.test.datalogic-software.com:8080/manager/text/reload?path=/consultaweb
curl --user datalogic:dlc/1840 http://gfepy.test.datalogic-software.com:8080/manager/text/reload?path=/dl-scheduler

echo "=== PROCESO TERMINADO === " 

