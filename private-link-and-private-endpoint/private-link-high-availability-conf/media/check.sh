#!/bin/bash
HEADNAME=$(date +"%H-%M-%S")
TAILNAME="_log.txt"
fileName="$HOME/$HEADNAME$TAILNAME"
URL="http://ep.mydom.net/"
OK=200
WORDTOREMOVE1="<style> h1 { color: blue; } </style> <h1>"
WORDTOREMOVE2="</h1>"
for (( ; ; ))
{
  response=$(curl -s -w "%{http_code}" $URL --connect-timeout 1 )
  http_code=$(tail -n1 <<< "$response")  # get the last line
  content=$(sed '$ d' <<< "$response")   # get all but the last line which contains the status code
  # echo "$http_code $content"
  if [ "$(($http_code))" == "$OK" ]; then
          NOW=$(date +"%H-%M:%S")
          # echo $NOW" UP" >> $fileName
          # The // replaces all occurences of the substring ($WORDTOREMOVE) with the content between /}
          content=${content//$WORDTOREMOVE1/}
          content=${content//$WORDTOREMOVE2/}
          echo $NOW" UP "$content | tee -a $fileName
  else
      NOW=$(date +"%H-%M:%S")
      # echo $NOW" DOWN" >> $fileName
      echo $NOW" DOWN " | tee -a $fileName
  fi
  sleep 1
}
done
