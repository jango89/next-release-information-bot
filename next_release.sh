#!/bin/sh

prepare_info() {

  # Check is valid Uri
  local is_valid=$(validate_http_status)
  if [ "$is_valid" == "-1" ]; then
    echo "\n"$cloud_uri"\n =>  is Not Valid, Exiting now !!!\n"
    return -1
  fi

  # Gather data from Eureka  
  cloud_uri_response="$(curl -s $cloud_uri)"

  ip_addresses=$(get_ip_addresses)

  adminUri=$(get_status_page_uri)

  service_machine_names=$(find_matching_machine_names)

  service_rollback_versions=$(find_running_versions)

  service_new_versions_ready_to_release=$(find_new_version_to_release)

  splunk_link=$(add_splunk_link)

  print_info=$(print_info)
  
  # Invoking chat webhook
  create_temp_files
  notify_via_g_chat
  notify_via_slack
  remove_temp_files
}

add_splunk_link() {
  echo "<$open_splunk_link|Click for Splunk logs here>"
}

find_new_version_to_release() {
  local last_five_release_artifacts=$(curl -s $release_artifactory_path/$service_name_with_dashes/ | tail -n 8)
  if [[ $last_five_release_artifacts == *"error"* ]]; then 
    last_five_release_artifacts="Not available from artifactory"
  fi

  if [[ $version_no ]]; then 
    last_five_release_artifacts=$version_no
  fi

  echo "$last_five_release_artifacts"
}

find_running_versions() {

  local running_version_with_instance_details="$(echo "$ip_addresses" | 
    while read IP_ADDRESS; do
        
      echo "$adminUri" | 
        while read ADMIN_URI; do

          # Match ADMIN URI with machine names
          if [[ $ADMIN_URI == *$IP_ADDRESS* ]]; then
            local build_version_metadata=$(curl -s $ADMIN_URI --header 'Content-Type: application/json')
            echo "$IP_ADDRESS  ==>  $build_version_metadata"
          fi  
        done
      done
  )"
  echo "$running_version_with_instance_details"

}

find_matching_machine_names() {
  data_set=$(curl -s $templates_uri_from_bitbucket --header "$(echo $BITBUCKET_TOKEN)" --header 'Content-Type: application/json')
  local response_splitted=$(split_bit_bucket_response_json)
  
  local names_matching_ips="$(echo "$ip_addresses" | 
    while read IP_ADDRESS; do
        
      echo "$response_splitted" | 
        while read BIT_BUCKET_DATA_LINE; do

          # Match IP with machine names
          if [[ $BIT_BUCKET_DATA_LINE == *$IP_ADDRESS* ]]; then

            # Replacing all unwanted strings
            local replace_tag="$(echo "$BIT_BUCKET_DATA_LINE" | sed 's/,//g')"
            replace_tag="$(echo "$replace_tag" | sed 's/}//g')"
            replace_tag="$(echo "$replace_tag" | sed 's/\"text\"://g')"
            replace_tag="$(echo "$replace_tag" | sed 's/ /  =>  /g')"
            echo "$replace_tag"

          fi 
        done
      done
  )"
  echo "$names_matching_ips"

}

split_bit_bucket_response_json() {
    local delimiter="{"  
    local part
    while read -d "$delimiter" part; do
        echo $part
    done <<< "$data_set"
    echo $part
}

validate_http_status() {
  local http_code="$(curl -o /dev/null -s -w "%{http_code}\n" $cloud_uri)"
  if [[ $http_code != "200" ]]; then
    echo "-1"
  elif [[ $http_code == "200" ]]; then
    echo "0"
  fi
}

get_ip_addresses() {
  local ip_addresses="$(echo "$cloud_uri_response" | 
      while read LINE; do
        if [[ $LINE == *"<hostName>"* ]]; then
          
          # Replacing xml tag <hostName></hostName>
          local replace_tag="$(echo "$LINE" | sed 's/<hostName>//g')"
          replace_tag="$(echo "$replace_tag" | sed 's/<\/hostName>//g')"
          echo "$replace_tag"
        fi 
      done
    )"
  echo "$ip_addresses"
}

get_status_page_uri() {
  local adminUri="$(echo "$cloud_uri_response" | 
      while read LINE; do
        if [[ $LINE == *"<statusPageUrl>"* ]]; then 
          
          # Replacing xml tag <statusPageUrl></statusPageUrl>
          local replace_tag="$(echo "$LINE" | sed 's/<statusPageUrl>//g')"
          replace_tag="$(echo "$replace_tag" | sed 's/<\/statusPageUrl>//g')"
          echo "$replace_tag"
        fi 
      done
    )"
  echo "$adminUri"
}

print_info() {
  local information_to_sent="\n\n****** *Release Information for $service_name* ******\n\n"
  information_to_sent+="\n*Current Instance Information:*\n\n$service_rollback_versions\n"
  information_to_sent+="\n*Machine Name Mapping's*\n\n$service_machine_names\n"
  information_to_sent+="\n*Last artifacts from release artifactory's*\n\n$service_new_versions_ready_to_release\n"
  information_to_sent+="\n*$splunk_link*\n"
  information_to_sent+="\n******************\n"
  echo "$information_to_sent"
}

create_temp_files() {
  printf "${print_info}"
  local print_info_without_double_quotes="$(echo "$print_info" | sed 's/"/ /g')"
  local messageInJson="{\"text\":\"$print_info_without_double_quotes\"}"
  echo "$messageInJson" >$DATA_STORE_PATH
}

remove_temp_files() {
  #clean the files
  rm -r $DATA_STORE_PATH
  rm -r null
}

notify_via_g_chat() {
  if [ "$google_chat_webhook_uri" ]; then
    curl -s -o null --request POST "$google_chat_webhook_uri" --header 'Content-Type: application/json' --data-raw "$(cat $DATA_STORE_PATH)"
  fi
}

notify_via_slack() {
  if [ "$slack_webhook_uri" ]; then
    curl -s -o null --request POST "$slack_webhook_uri" --header 'Content-Type: application/json' --data-raw "$(cat curl_data.txt)"
  fi
}


# Main function
version_no=$2
service_name_with_dashes=$1

#withoutdashes
service_name=$(echo "$service_name_with_dashes" | sed 's/-//g')

source environment.sh
clear
echo "\nGathering next release metadata for $service_name\n"
prepare_info
