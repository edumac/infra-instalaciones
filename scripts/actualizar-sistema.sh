#!/bin/bash

# ------------------------------------------------------------------------------------------------------
# Actualizacion de GIA-WEB
# Se elimina archivo de instalador anterior (si existe)
# Se descarga del ftp la version a actualizar
# Se setean permisos de ejecución.
# Se ejecuta instlaador en modo silencioso, apuntando a parametros de instalacion preexistentes
# Se cambia el owner de toda la carpeta tomcat (entre los archivos est谩n los que se acaban de instalar)
# ------------------------------------------------------------------------------------------------------

# ------------------------------------------------------------------------------------------------------
# Seteo de variables del proceso
# ------------------------------------------------------------------------------------------------------

#v_sistema=GIA-WEB
#v_url_instalacion=gfepy.test.datalogic-software.com
#v_ejecutable_instalador=GIAWeb_unix_6_10_00.sh
#v_tipo_descarga="Beta"

# Parametros que vienen cargados desde Jenkins:
echo "v_sistema              ="$v_sistema
echo "v_ejecutable_instalador="$v_ejecutable_instalador
echo "v_url_instalacion      ="$v_url_instalacion
echo "v_tipo_descarga        ="$v_tipo_descarga
echo "v_apps_a_recargar      ="$v_apps_a_recargar

# Parametros que se cargan fijos:
v_carpeta_instaladores=/home/datalogic/INSTALADORES
v_carpeta_instalador_sistema=$v_carpeta_instaladores/$v_url_instalacion/$v_sistema
v_carpeta_configuraciones=/home/datalogic/ARCHIVOS_INSTALACIONES
v_carpeta_configuracion_sistema=$v_carpeta_configuraciones/$v_url_instalacion/$v_sistema
v_archivo_log_instalacion=$v_carpeta_configuracion_sistema/.install4j/installation.log
v_ftp_url=ftp.datalogic.com.uy
v_ftp_usuario=cliente
v_ftp_password=cli.1717
v_manager_usuario=datalogic
v_manager_password=dlc/1840
v_tomcat_puerto_local=8080
v_tomcat_usuario=tomcat
v_tomcat_grupo=tomcat
v_tomcat_carpeta=/opt/tomcat

# Rutina de chequeo de error, si la ultima operacion fallo, se aborta el proceso.
checkerror() {
   v_exitcode=$?
   if [ $v_exitcode != 0 ]
   then
      echo "[ERROR] Error al ejecutar ultima operacion (exitcode="$v_exitcode")"
      exit $v_exitcode
   fi
}

# Si es una beta, a la carpeta del ftp para la descarga se le agrega /beta
if [ "$v_tipo_descarga" == "Beta" ]
then
   v_ftp_carpeta_descarga=$v_sistema/betas
else
   v_ftp_carpeta_descarga=$v_sistema
fi

# Si la carpeta de descarga del instalador no existe, se creará (mkdir -p crea carpetas padres si no existen)
if [ ! -d "$v_carpeta_instalador_sistema" ]; then
  echo "=== Carpeta de instaladores no existe, creando carpeta: " $v_carpeta_instalador_sistema
  mkdir -p "$v_carpeta_instalador_sistema"
  checkerror
fi

# Si el archivo del instalador existe, se elimina. Siempre se descarga de nuevo y en la carpeta del subdominio para 
# permitir que se puedan ejecutar varias actualizaciones al mismo tiempo sin que se pisen las descargas.
if [ -f "$v_carpeta_instalador_sistema/$v_ejecutable_instalador" ]; then
  echo "=== Eliminando instalador anterior: " $v_carpeta_instalador_sistema/$v_ejecutable_instalador
  rm -f $v_carpeta_instalador_sistema/$v_ejecutable_instalador
  checkerror
fi

# Descarga del ejecutable desde el ftp.
echo "=== Descargando instalador desde ftp (carpeta de descarga): ftp://"$v_ftp_url/$v_ftp_carpeta_descarga/$v_ejecutable_instalador
wget -nv ftp://$v_ftp_usuario:$v_ftp_password@$v_ftp_url/$v_ftp_carpeta_descarga/$v_ejecutable_instalador -P $v_carpeta_instalador_sistema
checkerror

# Permiso de ejecución en archivo ejecutable del instalador.
echo "=== Seteando permisos de ejecuci贸n en: " $v_carpeta_instalador_sistema/$v_ejecutable_instalador
chmod 777 $v_carpeta_instalador_sistema/$v_ejecutable_instalador
checkerror

# Ejecución del instalador, se pasa carpeta de configuración, -q para desatendido, -console para que muestre errores si los hay.
echo "=== Ejecutando instalador en base a configuraci贸n de carpeta: " $v_carpeta_configuracion_sistema
$v_carpeta_instalador_sistema/$v_ejecutable_instalador -q -console -dir $v_carpeta_configuracion_sistema
checkerror

# Controlar que el log de la instalacion no contiene ningun error.
if grep "\[ERROR\]" "$v_archivo_log_instalacion"; then
  echo "=== [ERROR] Se detectaron errores en el archivo de log de la instalacion"
  echo "    Archivo: $v_archivo_log_instalacion"
  echo "    Revise el log de la instalacion para conocer mas detalles, y vuelva a ejecutar el proceso de instalacion."
  exit 1
else
  echo "=== Instalacion finalizada OK."
fi

# Cambio de owner de carpetas debajo de tomcat porque quedaron con root luego de la ejecución del instalador.
echo "=== Cambiando owner para ejecuci贸n de tomcat en archivos instalados en carpeta " $v_tomcat_carpeta
chown -R $v_tomcat_usuario:$v_tomcat_grupo $v_tomcat_carpeta
checkerror

# ------------------------------------------------------------------------------------------------------
# Recarga de la aplicacion 
# En lugar de bajar el tomcat completo, se procede a recargar la aplicaci贸n que se acaba de actualizar.
# para esto se invoca por crul el comando de recargar
# Atenci贸n: para poder hacer esto el usuario datalogic debe tener rol manager-script en tomcat-users.xml
#           en /opt/tomcat/conf/Catalina/gfepy.test.datalogic-software.com/manager.xml debe agregarse 
#           127.0.0.1 a las ip aceptadas.
# Si no se desea recargar individualmente la aplicacion, se puede bajar el tomcat completo con:
# systemctl stop tomcat
# systemctl start tomcat

echo "=== Recargando aplicaciones... " 
IFS=',' read -r -a v_array_apps_a_recargar <<< "$v_apps_a_recargar"
for v_app in "${v_array_apps_a_recargar[@]}"
do
   echo "=== Recargando http://"$v_url_instalacion:$v_tomcat_puerto_local/$v_app
   echo "    Ejecutando: " http://$v_url_instalacion:$v_tomcat_puerto_local/manager/text/reload?path=/$v_app
   curl --user $v_manager_usuario:$v_manager_password http://$v_url_instalacion:$v_tomcat_puerto_local/manager/text/reload?path=/$v_app
   checkerror
done

# Se elimina instalador utilizado en el proceso.
if [ -f "$v_carpeta_instalador_sistema/$v_ejecutable_instalador" ]; then
  echo "=== Eliminando instalador utilizado: " $v_carpeta_instalador_sistema/$v_ejecutable_instalador
  rm -f $v_carpeta_instalador_sistema/$v_ejecutable_instalador
  checkerror
fi

echo "=== PROCESO TERMINADO === " 

