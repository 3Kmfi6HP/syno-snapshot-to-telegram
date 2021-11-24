#!/bin/bash
#set -x
#set -e

TG_TOKEN=""
TG_CHAT_ID=""
TG_API="https://api.telegram.org"
filenamekey="door1 door2 rode_1"
hh=`date '+%H%M'`
mm=`date '+%M'`
online=/tmp/cf_online
offline=/tmp/cf_offline
volume="volume3"
#随机
function rand(){
	min=$1
	max=$(($2-$min+1))
	num=$(cat /proc/sys/kernel/random/uuid | cksum | awk -F ' ' '{print $1}')
	echo $(($num%$max+$min))
}

function check_cf() {
	if [ $mm -ge 20 -a $mm -le 30 ]
	then
		echo -e "Check cloudflare cdn connection time"
		#check cloudflare proxy
		check=$(
			curl -s "https://xxx.workers.dev/bot$TG_TOKEN/getMe" \
			-H 'Connection: keep-alive' \
			-H 'Accept: application/json, text/javascript, */*; q=0.01' \
			-H 'DNT: 1' \
			-H 'User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1' \
			-H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
			-H 'Referer: https://t.me' \
			-H 'Accept-Language: zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7' \
			--compressed | jq '.ok' | sed 's/\"//g'
		)
		if [ "$check" = "true" ]
		then
			echo "cloudflare can connected"
			rm -rf $offline
			# if never online then log and notify
			if [ ! -f $online ]; then
				touch $online
			fi
		else
			echo "cloudflare can't connected"
			rm -rf $online
			if [ ! -f $offline ]; then
				touch $offline
				curl -o /dev/null -s -x socks5h://192.168.1.1:1080 POST https://api.telegram.org/bot$TG_TOKEN/sendMessage -d chat_id=$TG_CHAT_ID -d text="Cloudflare maybe can't connecting"
			fi
		fi
	else
		echo -e "Not check cloudflare cdn connection time"
	fi
}

function fnish() {
	rm -f /tmp/log_$cam.log && echo -e "Deleted log success"
	ls -lt /$volume/surveillance/@Snapshot/ | grep $cam | head -n 1 |awk '{print $9}' >> /tmp/log_$cam.log 2>&1 && echo -e "Create log file"
}
function send() {
	if [ ! -f $offline ]
	then
    # if faill use socks5
		curl -m 10 -s -x socks5h://192.168.1.1:1080 -o /dev/null -F caption="#Cam$cam：$formart_date - $filename" -F chat_id="$TG_CHAT_ID" -F photo=@"/$volume/surveillance/@Snapshot/$filename" https://api.telegram.org/bot$TG_TOKEN/sendPhoto && echo -e "by socks5"
	else
		curl -m 10 -s -o /dev/null -F caption="#Cam$cam：$formart_date - $filename" -F chat_id="$TG_CHAT_ID" -F photo=@"/$volume/surveillance/@Snapshot/$filename" $TG_API/bot$TG_TOKEN/sendPhoto && echo -e "by https"
	fi
}
function find_flies() {
	if [ -f "/tmp/log_$cam.log" ]
	then
		echo "Find file /tmp/log_$cam.log"
	else
		touch /tmp/log_$cam.log
	fi
}
function flies_info() {
	log_name=$(cat /tmp/log_$cam.log)
	last_modify=`stat -c %Y  /$volume/surveillance/@Snapshot/$filename`
	formart_date=`date '+%m-%d %H:%M:%S' -d @$last_modify`
	real_date=`date '+%Y-%m-%d %H:%M:%S'`
}
check_cf
for cam in $filenamekey
do
	filename=$(ls -lt /$volume/surveillance/@Snapshot/ | grep $cam | head -n 1 |awk '{print $9}')
	echo -e '--------------------------------------------'
	echo -e 'Camera Name '$cam'File '$filename
	find_flies
	flies_info
	if [ "$log_name" = "$filename" ]
	then
		echo -e "Latest file:[$formart_date] Now time:[$real_date] No file changes!"
	#elif [ $hh -ge 000 -a $hh -le 2359 -a "$log_name" != "$filename" ] #只在 5:30 - 23:30 之间发送图片
	elif [ "$log_name" != "$filename" ]
	then
		echo -e "[$real_date] sending [$filename] now!"
		send &
		sleep 3s &
		fnish &
		wait
	else
		echo -e "[$real_date] no sending time!"
		sleep 1s
		fnish
	fi
done
exit
