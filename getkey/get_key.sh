#!/bin/bash

# Created by Loora1N 2023/10/24
#   This is a Script for php_screw encrypto 
#   to get the pm9screw_mycryptkey.
#   It can only be used when the .so file 
#   is not be stripped the symbol table.
#   Usage:
#       ./get_key.sh [file_path]

#   get_pm9screw_mycryptkey symbol 
pm9screw_mycryptokey_symbol="pm9screw_mycryptkey"

#   help table
usage() {
    echo "Usage: ./get_key.sh [file_path]"
    exit -1
}

#   ERROR when file striped
no_symbol () {
    echo "This .so file seems to have stripped the symbol table and did not search for the string 'pm9screw_mycryptkey'"
    exit -1
}

#   Handle little-endian data to make it output normally  
swap_positions() {
    local original_string="$1"
    local part1 part2 part3 part4 new_string

    if [ ${#original_string} -ne 4 ]; then
        echo "Input string must be four characters long."
        return
    fi

    part1=$(echo "$original_string" | cut -c1)
    part2=$(echo "$original_string" | cut -c2)
    part3=$(echo "$original_string" | cut -c3)
    part4=$(echo "$original_string" | cut -c4)

    new_string="${part3}${part4}${part1}${part2}"
    echo "$new_string"
}

#   check the argv count
if [ $# -ne 1 ]; then
    usage
fi

filename="$1"

#   Get address of pm9screw_mycryptokey from symbol table by readelf
pm9screw_mycryptokey_addr=$(readelf -s ${filename} | grep ${pm9screw_mycryptokey_symbol} | head -n 1)

if [ -z "$pm9screw_mycryptokey_addr" ]; then
    no_symbol
fi

pm9screw_mycryptokey_addr=$(echo ${pm9screw_mycryptokey_addr} | awk -F': ' '{print $2}' | awk '{print $1}')
pm9screw_mycryptokey_addr=$(printf "%d" "0x${pm9screw_mycryptokey_addr}") 

#   Get data from .data section
data_hex=$(readelf -x .data ${filename} | tail -n +3)

tmp_addr=$(echo ${data_hex} | awk -F ' ' '{print $1}'| awk -F '0x' '{print $2}')
tmp_addr=$(printf "%d" "0x${tmp_addr}")

#   Check if address of pm9screw_mycryptokey is in the .data section
if [ ${pm9screw_mycryptokey_addr} = ${tmp_addr} ]; then
    pos=2
elif [ ${pm9screw_mycryptokey_addr} -gt ${tmp_addr} ]; then
    cnt=$(expr ${pm9screw_mycryptokey_addr} - ${tmp_addr})
    pos=$(expr (((${cnt} % 16) * 6) + 2 ))
else
    echo "pm9screw_mycryptokey_addr: ${pm9screw_mycryptokey_addr} is not in .data section"
fi

#   Store pm9screw_mycryptokey in key_array
key_array=()
offset=0
key_cnt=-1  #the idx of key_array
tmp_data=1

while [ ${tmp_data} -ne 0 ]; do
    key_cnt=$(expr ${key_cnt} + 1)
    #   stroage
    if [ $((key_cnt % 2)) -eq 0 ]; then
        cnt_left=1
        cnt_right=4

        tmp_data=$(echo ${data_hex} | awk -v pos="${pos}" '{print $pos}' | cut -c ${cnt_left}-${cnt_right})
        tmp_data=$(swap_positions "${tmp_data}")
        tmp_data=$(printf "%d" "0x${tmp_data}")
        key_array[${key_cnt}]=${tmp_data}

    else
        cnt_left=5
        cnt_right=8

        tmp_data=$(echo ${data_hex} | awk -v pos="${pos}" '{print $pos}' | cut -c ${cnt_left}-${cnt_right})
        tmp_data=$(swap_positions "${tmp_data}")
        tmp_data=$(printf "%d" "0x${tmp_data}")
        key_array[${key_cnt}]=${tmp_data}
        
        #   need to set pos to another
        offset=$(expr ${offset} + 1)
        if [ $((offset % 4)) -eq 0 ]; then
            pos=$(expr ${pos} + 3)
            offset=0
        else
            pos=$(expr ${pos} + 1)
        fi
    fi
done

# output 
echo "pm9screw_mycryptkey: "
array_len=${#key_array[@]}
array_len=$(expr ${array_len} - 1)

for ((i=0; i<array_len; i++)); do
    echo "key[${i}]: ${key_array[i]}"
done