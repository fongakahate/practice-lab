#!/bin/bash
echo "---START---"
cat manifest.json | grep artifact_id | awk '{print substr($2, 1, length($2)-2)}' > id.txt
sed -i "s/\"us-east-1://g" id.txt
id=$(cat id.txt)
echo $id
sed -i "s/ami-id/$id/g" main.tf
echo "---FINISH---"

