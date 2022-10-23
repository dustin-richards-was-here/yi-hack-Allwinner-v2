#!/bin/sh

YI_HACK_PREFIX="/tmp/sd/yi-hack"
CONF_FILE="etc/mqttv4.conf"
CONF_MQTT_ADVERTISE_FILE="etc/mqtt_advertise.conf"
CONF_SYSTEM_FILE="etc/system.conf"

PATH=$PATH:$YI_HACK_PREFIX/bin:$YI_HACK_PREFIX/usr/bin
LD_LIBRARY_PATH=$YI_HACK_PREFIX/lib:$LD_LIBRARY_PATH

get_config() {
    key=^$1
    grep -w $key $YI_HACK_PREFIX/$CONF_FILE | cut -d "=" -f2
}

get_system_config() {
    key=^$1
    grep -w $key $YI_HACK_PREFIX/$CONF_SYSTEM_FILE | cut -d "=" -f2
}

get_mqtt_advertise_config() {
    key=$1
    grep -w $1 $YI_HACK_PREFIX/$CONF_MQTT_ADVERTISE_FILE | cut -d "=" -f2
}

LOCAL_IP=$(ifconfig eth0 | awk '/inet addr/{print substr($2,6)}')
if [ -z $LOCAL_IP ]; then
    LOCAL_IP=$(ifconfig wlan0 | awk '/inet addr/{print substr($2,6)}')
fi
HTTPD_PORT=$(get_system_config HTTPD_PORT)

MQTT_IP=$(get_config MQTT_IP)
MQTT_PORT=$(get_config MQTT_PORT)
MQTT_USER=$(get_config MQTT_USER)
MQTT_PASSWORD=$(get_config MQTT_PASSWORD)
MQTT_QOS=$(get_config MQTT_QOS)

TOPIC_BIRTH_WILL=$(get_config TOPIC_BIRTH_WILL)
BIRTH_MSG=$(get_config BIRTH_MSG)
WILL_MSG=$(get_config WILL_MSG)

TOPIC_MOTION=$(get_config TOPIC_MOTION)
MOTION_START_MSG=$(get_config MOTION_START_MSG)
MOTION_STOP_MSG=$(get_config MOTION_STOP_MSG)

TOPIC_SOUND_DETECTION=$(get_config TOPIC_SOUND_DETECTION)
SOUND_DETECTION_MSG=$(get_config SOUND_DETECTION_MSG)

TOPIC_MOTION_IMAGE=$(get_config TOPIC_MOTION_IMAGE)

AI_HUMAN_DETECTION_MSG=$(get_config AI_HUMAN_DETECTION_MSG)

HOST=$MQTT_IP
if [ ! -z $MQTT_PORT ]; then
    HOST=$HOST' -p '$MQTT_PORT
fi
if [ ! -z $MQTT_USER ]; then
    HOST=$HOST' -u '$MQTT_USER' -P '$MQTT_PASSWORD
fi

MQTT_PREFIX=$(get_config MQTT_PREFIX)

HOMEASSISTANT_MQTT_PREFIX=$(get_mqtt_advertise_config HOMEASSISTANT_MQTT_PREFIX)
HOMEASSISTANT_RETAIN=$(get_mqtt_advertise_config HOMEASSISTANT_RETAIN)
HOMEASSISTANT_QOS=$(get_mqtt_advertise_config HOMEASSISTANT_QOS)
MQTT_ADV_INFO_GLOBAL_ENABLE=$(get_mqtt_advertise_config MQTT_ADV_INFO_GLOBAL_ENABLE)
MQTT_ADV_INFO_GLOBAL_TOPIC=$(get_mqtt_advertise_config MQTT_ADV_INFO_GLOBAL_TOPIC)
MQTT_ADV_INFO_GLOBAL_RETAIN=$(get_mqtt_advertise_config MQTT_ADV_INFO_GLOBAL_RETAIN)
MQTT_ADV_INFO_GLOBAL_QOS=$(get_mqtt_advertise_config MQTT_ADV_INFO_GLOBAL_QOS)
MQTT_ADV_CAMERA_SETTING_ENABLE=$(get_mqtt_advertise_config MQTT_ADV_CAMERA_SETTING_ENABLE)
MQTT_ADV_CAMERA_SETTING_TOPIC=$(get_mqtt_advertise_config MQTT_ADV_CAMERA_SETTING_TOPIC)
MQTT_ADV_CAMERA_SETTING_RETAIN=$(get_mqtt_advertise_config MQTT_ADV_CAMERA_SETTING_RETAIN)
MQTT_ADV_CAMERA_SETTING_QOS=$(get_mqtt_advertise_config MQTT_ADV_CAMERA_SETTING_QOS)
MQTT_ADV_TELEMETRY_ENABLE=$(get_mqtt_advertise_config MQTT_ADV_TELEMETRY_ENABLE)
MQTT_ADV_TELEMETRY_TOPIC=$(get_mqtt_advertise_config MQTT_ADV_TELEMETRY_TOPIC)
MQTT_ADV_TELEMETRY_RETAIN=$(get_mqtt_advertise_config MQTT_ADV_TELEMETRY_RETAIN)
MQTT_ADV_TELEMETRY_QOS=$(get_mqtt_advertise_config MQTT_ADV_TELEMETRY_RETAIN)
NAME=$(get_mqtt_advertise_config HOMEASSISTANT_NAME)
IDENTIFIERS=$(get_mqtt_advertise_config HOMEASSISTANT_IDENTIFIERS)
MANUFACTURER=$(get_mqtt_advertise_config HOMEASSISTANT_MANUFACTURER)
MODEL=$(get_mqtt_advertise_config HOMEASSISTANT_MODEL)
SW_VERSION=$(cat $YI_HACK_PREFIX/version)
DEVICE_DETAILS="{\"identifiers\":[\"$IDENTIFIERS\"],\"manufacturer\":\"$MANUFACTURER\",\"model\":\"$MODEL\",\"name\":\"$NAME\",\"sw_version\":\"$SW_VERSION\",\"configuration_url\":\"http://$LOCAL_IP:$HTTPD_PORT\"}"
if [ "$HOMEASSISTANT_RETAIN" == "1" ]; then
    HA_RETAIN="-r"
else
    HA_RETAIN=""
fi
if [ "$HOMEASSISTANT_QOS" == "0" ] || [ "$HOMEASSISTANT_QOS" == "1" ] || [ "$HOMEASSISTANT_QOS" == "2" ]; then
    HA_QOS="-q $HOMEASSISTANT_QOS"
else
    HA_QOS=""
fi

mqtt_publish(){
  $YI_HACK_PREFIX/bin/mosquitto_pub $HA_QOS $HA_RETAIN -h $HOST -t $TOPIC -m "$CONTENT"
}
hass_topic(){
  # type, topic, Full name (optional)
  [ -n "$3" ] && UNIQUE_NAME="$NAME $3"
  UNIQUE_ID="$IDENTIFIERS-$2"
  TOPIC="$HOMEASSISTANT_MQTT_PREFIX/$1/$IDENTIFIERS/$2/config"
}
hass_setup_sensor(){
  # topic, Full name, icon, state_topic
  hass_topic "sensor" "$1" "$2"
  CONTENT='{"availability_topic":"'$MQTT_PREFIX'/'$TOPIC_BIRTH_WILL'","payload_available":"'$BIRTH_MSG'","payload_not_available":"'$WILL_MSG'","device":'$DEVICE_DETAILS','$QOS' '$RETAIN' "icon":"mdi:'$3'","state_topic":"'$MQTT_PREFIX'/'$4'","name":"'$UNIQUE_NAME'","unique_id":"'$UNIQUE_ID'","value_template":"{{ value_json.'$1' }}", "platform": "mqtt"}'
}

if [ "$MQTT_ADV_INFO_GLOBAL_ENABLE" == "yes" ]; then
    #Don't know why... ..Home Assistant don't allow retain for Sensor and Binary Sensor
    ## if [ "$MQTT_ADV_INFO_GLOBAL_RETAIN" == "1" ]; then
    ##    RETAIN='"retain":true, '
    ## else
        RETAIN=""
    ## fi
    if [ "$MQTT_ADV_INFO_GLOBAL_QOS" == "1" ] || [ "$MQTT_ADV_INFO_GLOBAL_QOS" == "2" ]; then
        QOS='"qos":'$MQTT_ADV_INFO_GLOBAL_QOS', '
    else
        QOS=""
    fi
    #Hostname
    hass_setup_sensor "hostname" "Hostname" "network" $MQTT_ADV_INFO_GLOBAL_TOPIC
    mqtt_publish
    #IP
    hass_setup_sensor "local_ip" "Local IP" "ip" $MQTT_ADV_INFO_GLOBAL_TOPIC
    mqtt_publish
    #Netmask
    hass_setup_sensor "netmask" "Netmask" "ip" $MQTT_ADV_INFO_GLOBAL_TOPIC
    mqtt_publish
    #Gateway
    hass_setup_sensor "gateway" "Gateway" "ip" $MQTT_ADV_INFO_GLOBAL_TOPIC
    mqtt_publish
    #WLan ESSID
    hass_setup_sensor "wlan_essid" "WiFi ESSID" "wifi" $MQTT_ADV_INFO_GLOBAL_TOPIC
    mqtt_publish
    #Mac Address
    hass_setup_sensor "mac_addr" "Mac Address" "network" $MQTT_ADV_INFO_GLOBAL_TOPIC
    mqtt_publish
    #Home Version
    hass_setup_sensor "home_version" "Home Version" "memory" $MQTT_ADV_INFO_GLOBAL_TOPIC
    mqtt_publish
    #Firmware Version
    hass_setup_sensor "fw_version" "Firmware Version" "network" $MQTT_ADV_INFO_GLOBAL_TOPIC
    mqtt_publish
    #Model Suffix
    hass_setup_sensor "model_suffix" "Model Suffix" "network" $MQTT_ADV_INFO_GLOBAL_TOPIC
    mqtt_publish
    #Serial Number
    hass_setup_sensor "serial_number" "Serial Number" "webcam" $MQTT_ADV_INFO_GLOBAL_TOPIC
    mqtt_publish
else
    for ITEM in hostname local_ip netmask gateway wlan_essid mac_addr home_version fw_version model_suffix serial_number; do
        TOPIC=$HOMEASSISTANT_MQTT_PREFIX/sensor/$IDENTIFIERS/$ITEM/config
        $YI_HACK_PREFIX/bin/mosquitto_pub $HA_QOS $HA_RETAIN -h $HOST -t $TOPIC -n
    done
fi
if [ "$MQTT_ADV_TELEMETRY_ENABLE" == "yes" ]; then
    #Don't know why... ..Home Assistant don't allow retain for Sensor and Binary Sensor
    ## if [ "$MQTT_ADV_TELEMETRY_RETAIN" == "1" ]; then
    ##    RETAIN='"retain":true, '
    ## else
        RETAIN=""
    ## fi
    if [ "$MQTT_ADV_TELEMETRY_QOS" == "1" ] || [ "$MQTT_ADV_TELEMETRY_QOS" == "2" ]; then
        QOS='"qos":'$MQTT_ADV_TELEMETRY_QOS', '
    else
        QOS=""
    fi
    #Total Memory
    hass_topic "sensor" "total_memory" "Total Memory"
    CONTENT='{"availability_topic":"'$MQTT_PREFIX'/'$TOPIC_BIRTH_WILL'","payload_available":"'$BIRTH_MSG'","payload_not_available":"'$WILL_MSG'","device":'$DEVICE_DETAILS','$QOS' '$RETAIN' "icon":"mdi:memory","state_topic":"'$MQTT_PREFIX'/'$MQTT_ADV_TELEMETRY_TOPIC'","name":"'$UNIQUE_NAME'","unique_id":"'$UNIQUE_ID'","value_template":"{{ value_json.total_memory }}","unit_of_measurement":"KB", "platform": "mqtt"}'
    mqtt_publish
    #Free Memory
    hass_topic "sensor" "free_memory" "Free Memory"
    CONTENT='{"availability_topic":"'$MQTT_PREFIX'/'$TOPIC_BIRTH_WILL'","payload_available":"'$BIRTH_MSG'","payload_not_available":"'$WILL_MSG'","device":'$DEVICE_DETAILS','$QOS' '$RETAIN' "icon":"mdi:memory","state_topic":"'$MQTT_PREFIX'/'$MQTT_ADV_TELEMETRY_TOPIC'","name":"'$UNIQUE_NAME'","unique_id":"'$UNIQUE_ID'","value_template":"{{ value_json.free_memory }}","unit_of_measurement":"KB", "platform": "mqtt"}'
    mqtt_publish
    #FreeSD
    hass_topic "sensor" "free_sd" "Free SD"
    CONTENT='{"availability_topic":"'$MQTT_PREFIX'/'$TOPIC_BIRTH_WILL'","payload_available":"'$BIRTH_MSG'","payload_not_available":"'$WILL_MSG'","device":'$DEVICE_DETAILS','$QOS' '$RETAIN' "icon":"mdi:micro-sd","state_topic":"'$MQTT_PREFIX'/'$MQTT_ADV_TELEMETRY_TOPIC'","name":"'$UNIQUE_NAME'","unique_id":"'$UNIQUE_ID'","value_template":"{{ value_json.free_sd|regex_replace(find=\"%\", replace=\"\", ignorecase=False) }}","unit_of_measurement":"%", "platform": "mqtt"}'
    mqtt_publish
    #Load AVG
    hass_setup_sensor "load_avg" "Load AVG" "network" $MQTT_ADV_TELEMETRY_TOPIC
    mqtt_publish
    #Uptime
    hass_topic "sensor" "uptime" "Uptime"
    CONTENT='{"availability_topic":"'$MQTT_PREFIX'/'$TOPIC_BIRTH_WILL'","payload_available":"'$BIRTH_MSG'","payload_not_available":"'$WILL_MSG'","device":'$DEVICE_DETAILS','$QOS' '$RETAIN' "device_class":"timestamp","icon":"mdi:timer-outline","state_topic":"'$MQTT_PREFIX'/'$MQTT_ADV_TELEMETRY_TOPIC'","name":"'$UNIQUE_NAME'","'unique_id'":"'$UNIQUE_ID'","value_template":"{{ (as_timestamp(now())-(value_json.uptime|int))|timestamp_local }}", "platform": "mqtt"}'
    mqtt_publish
    #WLanStrenght
    hass_topic "sensor" "wlan_strength" "Wlan Strengh"
    CONTENT='{"availability_topic":"'$MQTT_PREFIX'/'$TOPIC_BIRTH_WILL'","payload_available":"'$BIRTH_MSG'","payload_not_available":"'$WILL_MSG'","device":'$DEVICE_DETAILS','$QOS' '$RETAIN' "device_class":"signal_strength","icon":"mdi:wifi","state_topic":"'$MQTT_PREFIX'/'$MQTT_ADV_TELEMETRY_TOPIC'","name":"'$UNIQUE_NAME'","unique_id":"'$UNIQUE_ID'","value_template":"{{ ((value_json.wlan_strength|int) * 100 / 70 )|int }}","unit_of_measurement":"%", "platform": "mqtt"}'
    mqtt_publish
else
    for ITEM in total_memory free_memory free_sd load_avg uptime wlan_strength; do
        hass_topic "sensor" "$ITEM"
        $YI_HACK_PREFIX/bin/mosquitto_pub $HA_QOS $HA_RETAIN -h $HOST -t $TOPIC -n
    done
fi

# Motion Detection
hass_topic "binary_sensor" "motion_detection" "Movement"
MQTT_RETAIN_MOTION=$(get_config MQTT_RETAIN_MOTION)
#Don't know why... ..Home Assistant don't allow retain for Sensor and Binary Sensor
# if [ "$MQTT_RETAIN_MOTION" == "1" ]; then
#    RETAIN='"retain":true, '
# else
    RETAIN=""
# fi
CONTENT='{"availability_topic":"'$MQTT_PREFIX'/'$TOPIC_BIRTH_WILL'","payload_available":"'$BIRTH_MSG'","payload_not_available":"'$WILL_MSG'","device":'$DEVICE_DETAILS', "qos": "'$MQTT_QOS'", '$RETAIN' "device_class":"motion","state_topic":"'$MQTT_PREFIX'/'$TOPIC_MOTION'","name":"'$UNIQUE_NAME'","unique_id":"'$UNIQUE_ID'","payload_on":"'$MOTION_START_MSG'","payload_off":"'$MOTION_STOP_MSG'", "platform": "mqtt"}'
mqtt_publish
# Human Detection
hass_topic "binary_sensor" "ai_human_detection" "Human Detection"
MQTT_RETAIN_AI_HUMAN_DETECTION=$(get_config MQTT_RETAIN_MOTION)
#Don't know why... ..Home Assistant don't allow retain for Sensor and Binary Sensor
# if [ "$MQTT_RETAIN_AI_HUMAN_DETECTION" == "1" ]; then
#    RETAIN='"retain":true, '
# else
    RETAIN=""
# fi
CONTENT='{"availability_topic":"'$MQTT_PREFIX'/'$TOPIC_BIRTH_WILL'","payload_available":"'$BIRTH_MSG'","payload_not_available":"'$WILL_MSG'","device":'$DEVICE_DETAILS', "qos": "'$MQTT_QOS'", '$RETAIN' "device_class":"motion","state_topic":"'$MQTT_PREFIX'/'$TOPIC_MOTION'","name":"'$UNIQUE_NAME'","unique_id":"'$UNIQUE_ID'","payload_on":"'$AI_HUMAN_DETECTION_MSG'","payload_off":"'$MOTION_STOP_MSG'", "platform": "mqtt"}'
mqtt_publish
# Sound Detection
hass_topic "binary_sensor" "sound_detection" "Sound Detection"
MQTT_RETAIN_SOUND_DETECTION=$(get_config MQTT_RETAIN_SOUND_DETECTION)
#Don't know why... ..Home Assistant don't allow retain for Sensor and Binary Sensor
# if [ "$MQTT_RETAIN_SOUND_DETECTION" == "1" ]; then
#    RETAIN='"retain":true, '
# else
    RETAIN=""
# fi
CONTENT='{"availability_topic":"'$MQTT_PREFIX'/'$TOPIC_BIRTH_WILL'","payload_available":"'$BIRTH_MSG'","payload_not_available":"'$WILL_MSG'","device":'$DEVICE_DETAILS', "qos": "'$MQTT_QOS'", '$RETAIN' "device_class":"sound","state_topic":"'$MQTT_PREFIX'/'$TOPIC_SOUND_DETECTION'","name":"'$UNIQUE_NAME'","unique_id":"'$UNIQUE_ID'","payload_on":"'$SOUND_DETECTION_MSG'","off_delay":60, "platform": "mqtt"}'
mqtt_publish
# try to remove baby_crying topic
hass_topic "binary_sensor" "baby_crying"
$YI_HACK_PREFIX/bin/mosquitto_pub -h $HOST -t $TOPIC -m ""
# Motion Detection Image
hass_topic "camera" "motion_detection_image" "Motion Detection Image"
MQTT_RETAIN_MOTION_IMAGE=$(get_config MQTT_RETAIN_MOTION_IMAGE)
#Don't know why... ..Home Assistant don't allow retain for Sensor and Binary Sensor
# if [ "$MQTT_RETAIN_MOTION_IMAGE" == "1" ]; then
#    RETAIN='"retain":true, '
# else
    RETAIN=""
# fi
CONTENT='{"availability_topic":"'$MQTT_PREFIX'/'$TOPIC_BIRTH_WILL'","payload_available":"'$BIRTH_MSG'","payload_not_available":"'$WILL_MSG'","device":'$DEVICE_DETAILS', "qos": "'$MQTT_QOS'", '$RETAIN' "topic":"'$MQTT_PREFIX'/'$TOPIC_MOTION_IMAGE'","name":"'$UNIQUE_NAME'","unique_id":"'$UNIQUE_ID'", "platform": "mqtt"}'
mqtt_publish
if [ "$MQTT_ADV_CAMERA_SETTING_ENABLE" == "yes" ]; then
    if [ "$MQTT_ADV_CAMERA_SETTING_RETAIN" == "1" ]; then
        RETAIN='"retain":true, '
    else
        RETAIN=""
    fi
    if [ "$MQTT_ADV_CAMERA_SETTING_QOS" == "1" ] || [ "$MQTT_ADV_CAMERA_SETTING_QOS" == "2" ]; then
        QOS='"qos":'$MQTT_ADV_CAMERA_SETTING_QOS', '
    else
        QOS=""
    fi
    # Switch On
    hass_topic "switch" "SWITCH_ON" "Switch Status"
    CONTENT='{"availability_topic":"'$MQTT_PREFIX'/'$TOPIC_BIRTH_WILL'","payload_available":"'$BIRTH_MSG'","payload_not_available":"'$WILL_MSG'","device":'$DEVICE_DETAILS','$QOS' '$RETAIN' "icon":"mdi:video","state_topic":"'$MQTT_PREFIX'/'$MQTT_ADV_CAMERA_SETTING_TOPIC'","command_topic":"'$MQTT_PREFIX'/'$MQTT_ADV_CAMERA_SETTING_TOPIC'/SWITCH_ON/set","name":"'$UNIQUE_NAME'","unique_id":"'$UNIQUE_ID'","value_template":"{{ value_json.SWITCH_ON }}","payload_on":"yes","payload_off":"no", "platform": "mqtt"}'
    mqtt_publish
    # Sound Detection
    hass_topic "switch" "SOUND_DETECTION" "Sound Detection"
    CONTENT='{"availability_topic":"'$MQTT_PREFIX'/'$TOPIC_BIRTH_WILL'","payload_available":"'$BIRTH_MSG'","payload_not_available":"'$WILL_MSG'","device":'$DEVICE_DETAILS', '$QOS' '$RETAIN' "icon":"mdi:music-note","state_topic":"'$MQTT_PREFIX'/'$MQTT_ADV_CAMERA_SETTING_TOPIC'","command_topic":"'$MQTT_PREFIX'/'$MQTT_ADV_CAMERA_SETTING_TOPIC'/SOUND_DETECTION/set","name":"'$UNIQUE_NAME'","unique_id":"'$UNIQUE_ID'","value_template":"{{ value_json.SOUND_DETECTION }}","payload_on":"yes","payload_off":"no", "platform": "mqtt"}'
    mqtt_publish
    # try to remove baby_crying topic
    hass_topic "switch" "BABY_CRYING_DETECT"
    $YI_HACK_PREFIX/bin/mosquitto_pub -h $HOST -t $TOPIC -n
    # Led
    hass_topic "switch" "LED" "Status Led"
    CONTENT='{"availability_topic":"'$MQTT_PREFIX'/'$TOPIC_BIRTH_WILL'","payload_available":"'$BIRTH_MSG'","payload_not_available":"'$WILL_MSG'","device":'$DEVICE_DETAILS','$QOS' '$RETAIN' "icon":"mdi:led-on","state_topic":"'$MQTT_PREFIX'/'$MQTT_ADV_CAMERA_SETTING_TOPIC'","command_topic":"'$MQTT_PREFIX'/'$MQTT_ADV_CAMERA_SETTING_TOPIC'/LED/set","name":"'$UNIQUE_NAME'","unique_id":"'$UNIQUE_ID'","value_template":"{{ value_json.LED }}","payload_on":"yes","payload_off":"no", "platform": "mqtt"}'
    mqtt_publish
    # IR
    hass_topic "switch" "IR" "IR Led"
    CONTENT='{"availability_topic":"'$MQTT_PREFIX'/'$TOPIC_BIRTH_WILL'","payload_available":"'$BIRTH_MSG'","payload_not_available":"'$WILL_MSG'","device":'$DEVICE_DETAILS','$QOS' '$RETAIN' "icon":"mdi:remote","state_topic":"'$MQTT_PREFIX'/'$MQTT_ADV_CAMERA_SETTING_TOPIC'","command_topic":"'$MQTT_PREFIX'/'$MQTT_ADV_CAMERA_SETTING_TOPIC'/IR/set","name":"'$UNIQUE_NAME'","unique_id":"'$UNIQUE_ID'","value_template":"{{ value_json.IR }}","payload_on":"yes","payload_off":"no", "platform": "mqtt"}'
    mqtt_publish
    # Rotate
    hass_topic "switch" "ROTATE" "Rotate"
    CONTENT='{"availability_topic":"'$MQTT_PREFIX'/'$TOPIC_BIRTH_WILL'","payload_available":"'$BIRTH_MSG'","payload_not_available":"'$WILL_MSG'","device":'$DEVICE_DETAILS','$QOS' '$RETAIN' "icon":"mdi:monitor","state_topic":"'$MQTT_PREFIX'/'$MQTT_ADV_CAMERA_SETTING_TOPIC'","command_topic":"'$MQTT_PREFIX'/'$MQTT_ADV_CAMERA_SETTING_TOPIC'/ROTATE/set","name":"'$UNIQUE_NAME'","unique_id":"'$UNIQUE_ID'","value_template":"{{ value_json.ROTATE }}","payload_on":"yes","payload_off":"no", "platform": "mqtt"}'
    mqtt_publish
else
    for ITEM in SWITCH_ON SOUND_DETECTION BABY_CRYING_DETECT LED IR ROTATE; do
        hass_topic "switch" "$ITEM"
        $YI_HACK_PREFIX/bin/mosquitto_pub $HA_QOS $HA_RETAIN -h $HOST -t $TOPIC -n
    done
fi
