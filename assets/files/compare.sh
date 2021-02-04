#!/bin/bash

function wait_http_success {
  # ${1}=http_uri, ${2}=wait_time_resolution
  local CODE=500

  while [ ${CODE} -ne 200 ]
  do
    CODE=$(curl "${1}" -w "%{http_code}" -o /dev/null -s)
    sleep ${2}
    #echo "Waiting http success for ${1}, but got ${CODE}" instead
  done
}

# Start the spring boot native image
SPRINGBOOT_RUNNER='./camel-example-spring-boot-rest-openapi'
SPRINGBOOT_START_MS=$(date +%s%3N)
"${SPRINGBOOT_RUNNER}" 2>&1 > "${SPRINGBOOT_RUNNER}.log" &
SPRINGBOOT_PID=$(pgrep -f ${SPRINGBOOT_RUNNER})
wait_http_success http://localhost:8080/api/users 0.010
SPRINGBOOT_READY_MS=$(date +%s%3N)
SPRINGBOOT_FIRST_RESPONSE_DELAY=$((SPRINGBOOT_READY_MS-SPRINGBOOT_START_MS))
#echo "Delay to first response for Spring Boot Native: ${SPRINGBOOT_FIRST_RESPONSE_DELAY}"

# Start the quarkus native image
QUARKUS_NATIVE_RUNNER='./camel-quarkus-openapi-example-1.0.0-SNAPSHOT-runner'
QUARKUS_NATIVE_START_MS=$(date +%s%3N)
"${QUARKUS_NATIVE_RUNNER}" -Dquarkus.http.port=8081 2>&1 > "${QUARKUS_NATIVE_RUNNER}.log" &
QUARKUS_NATIVE_PID=$(pgrep -f ${QUARKUS_NATIVE_RUNNER})
#echo "Camel-hello started with Quarkus Native Mode, PID = ${QUARKUS_NATIVE_PID}"
wait_http_success http://localhost:8081/api/users 0.010
QUARKUS_NATIVE_READY_MS=$(date +%s%3N)
QUARKUS_NATIVE_FIRST_RESPONSE_DELAY=$((QUARKUS_NATIVE_READY_MS-QUARKUS_NATIVE_START_MS))
#echo "Delay to first response for Quarkus Native: ${QUARKUS_NATIVE_FIRST_RESPONSE_DELAY}"

# Get package size
QUARKUS_NATIVE_DISK_SIZE=$(du -sh "${QUARKUS_NATIVE_RUNNER}" | cut -f1)
SPRINGBOOT_DISK_SIZE=$(du -sh "${SPRINGBOOT_RUNNER}" | cut -f1)

# Get Camel boot time
QUARKUS_NATIVE_BOOT_SECONDS=$(grep -Po "started in (.*) seconds" "${QUARKUS_NATIVE_RUNNER}.log" | sed -r 's/started in (.*) seconds/\1/g')
SPRINGBOOT_BOOT_SECONDS=$(grep -Po "started in (.*) seconds" "${SPRINGBOOT_RUNNER}.log" | sed -r 's/started in (.*) seconds/\1/g')

# Get total boot time
QUARKUS_NATIVE_TOTAL_BOOT_SECONDS=$(grep -Po "started in (.*)s[.]" "${QUARKUS_NATIVE_RUNNER}.log" | sed -r 's/started in (.*)s./\1/g')
SPRINGBOOT_TOTAL_BOOT_SECONDS=$(grep -Po "JVM running for (.*)" "${SPRINGBOOT_RUNNER}.log" | sed -r 's/JVM running for (.*)[)]/\1/g')

# Get rss
QUARKUS_NATIVE_RSS=$(ps -o rss ${QUARKUS_NATIVE_PID} | sed -n 2p)
SPRINGBOOT_RSS=$(ps -o rss ${SPRINGBOOT_PID} | sed -n 2p)

# Print report
#printf '=%.0s' {1..80} && printf '\n'
#printf "| %-58s |\n" 'NOT A FULL BENCHMARK BUT GIVES A GOOD OVERVIEW'
printf '=%.0s' {1..93} && printf '\n'
printf "| %-14s | %-10s | %-27s | %-9s | %-17s |\n" 'Runtime' 'Startup' 'Boot + First Response Delay' 'Disk Size' 'Resident Set Size'
printf '=%.0s' {1..93} && printf '\n'
printf "| %-14s | %10s | %27s | %9s | %17s |\n" 'Spring Native' ${SPRINGBOOT_TOTAL_BOOT_SECONDS}s ${SPRINGBOOT_FIRST_RESPONSE_DELAY}ms ${SPRINGBOOT_DISK_SIZE} ${SPRINGBOOT_RSS}K
printf "| %-14s | %10s | %27s | %9s | %17s |\n" 'Quarkus Native' ${QUARKUS_NATIVE_TOTAL_BOOT_SECONDS}s ${QUARKUS_NATIVE_FIRST_RESPONSE_DELAY}ms ${QUARKUS_NATIVE_DISK_SIZE} ${QUARKUS_NATIVE_RSS}K
printf '=%.0s' {1..93} && printf '\n'


# Killing processes
kill -9 ${QUARKUS_NATIVE_PID} ${SPRINGBOOT_PID}
