#!/bin/bash

HOST=provider
PORT=8100
SENSOR_IDS="arduino sensor1 sensor2 sensor3"
UPDATE_INTERVAL_IN_SEC=30
START_TEMPERATURE=5.1
MAX_TEMPERATURE=10
MIN_TEMPERATURE=-5

sensors=""

function getColumn {
   local input=$1
   local index=$2
   echo "$input" | cut --delimiter='|' --fields=$index
}

function sendNewValue {
   local id=$1
   local temperature=$2

   echo "$id : $temperature"
   curl --header  "Content-Type: application/json" \
        --request POST \
        --data    "{\"sensorId\": \"$id\",\"temperature\": $temperature}" \
        http://$HOST:$PORT/sensordata

   exitCode=$?
   if [ $exitCode -ne 0 ]; then
      echo "failed to update $sensor (exitCode: $exitCode)"
   fi
}

export LC_NUMERIC="en_US.UTF-8"

for sensorId in $SENSOR_IDS; do
   sensors="$sensors $sensorId|$START_TEMPERATURE"
done
sensors=$(echo $sensors | sed 's/^\s+//')

while(true); do
   echo "$(date) updating sensor values"
   currentSensors="$sensors"
   sensors=""

   for sensor in $currentSensors; do
      increment=$(printf "%.1f" $(echo "scale=1; (($RANDOM / 32767) - 0.5) * 2" | bc))          # range: -1 to 1
      sensorId=$(getColumn $sensor 1)
      currentTemperature=$(getColumn $sensor 2)
      nextTemperature=$(printf "%.1f" $(echo "scale=1; $currentTemperature + $increment" | bc))
      tooHigh=$(echo "if($nextTemperature > $MAX_TEMPERATURE) 1 else 0" | bc)
      tooLow=$(echo  "if($nextTemperature < $MIN_TEMPERATURE) 1 else 0" | bc)
      if [ "$tooHigh" == "1" ] || [ "$tooLow" == "1" ]; then
         nextTemperature=$(printf "%.1f" $(echo "scale=1; $currentTemperature - $increment" | bc))
      fi

      sensors="$sensors $sensorId|$nextTemperature"
      sensors=$(echo $sensors | sed 's/^\s+//')
      sendNewValue $sensorId $nextTemperature
   done
   sleep $UPDATE_INTERVAL_IN_SEC
done