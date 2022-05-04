#!/bin/bash
#
# For connecting to the DremioREST API
# Getting a list of Catalogs and then
# doing some other things with it
# https://docs.dremio.com/rest-api/catalog/get-catalog/


function usage {
    echo
    echo "Usage: $0 <foo> <bar>"
    echo
    exit
}

function check_creds {
    if [ $DREMIO_USER"x" = "x" ] || [ $DREMIO_PASS"x" = "x" ]
    then
        echo "Please ensure DREMIO_USER and DREMIO_PASS are both set"
    fi
}

function login {
    RESP=$(curl -s -H "Content-Type: application/json" -X POST "$TARGET/apiv2/login" \
        -d '{
             "userName":"'$DREMIO_USER'", 
             "password":"'$DREMIO_PASS'"
        }' \
       )
    TOKEN=$(echo $RESP | jq -r '.token')
}

function get_catalog {
    curl -s -H 'Content-Type: application/json' -H "Authorization: _dremio$TOKEN" -X GET "$TARGET/api/v3/catalog?pretty" > $CATALOG_FILE
}

function find_sources {
   SOURCES=$(cat $CATALOG_FILE | jq -r '.data[] | select(.containerType == "SOURCE") | .id')
}

function query_sources {
    cat /dev/null > $SOURCES_FILE
    for SOURCE in $SOURCES
    do
        curl -s -H 'Content-Type: application/json' -H "Authorization: _dremio$TOKEN" -X GET "$TARGET/api/v3/catalog/$SOURCE?pretty" >> $SOURCES_FILE
    done    
}

function find_datasets {
   cat /dev/null > $DATASETS_FILE
   while read DS_PATH
   do
      echo "Finding info for $DS_PATH"
      DS_PATH_ENC=$( echo $DS_PATH | sed -E "s/\ /%20/g" )
      curl -s -H 'Content-Type: application/json' -H "Authorization: _dremio$TOKEN" -X GET "$TARGET/api/v3/catalog/by-path/$DS_PATH_ENC" | jq . >> $DATASETS_FILE
   done < $DS_PATH_FILE
}


# Setup
RESP=""
TOKEN=""
CATALOG=""
SQL_RESULT=""
CATALOG_FILE=".catalog_info"
VIEWS_FILE=".views_info"
DS_PATH_FILE=".dspath_info"
DATASETS_FILE=".datasets_info"
SOURCES_FILE="sources_info.out"
TARGET="http://127.0.0.1:9047"
DELAY=5

# Run
check_creds
login
get_catalog
find_sources
query_sources
echo "Output in file $SOURCES_FILE"
