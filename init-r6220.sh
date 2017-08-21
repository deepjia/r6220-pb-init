#!/bin/bash
echo -e "\033[0;36m仅适用于 macOS 下的 R6220 PandoraBox 固件初始化配置。\033[0m"
sed -i '' '/192.168.1.1/d' ~/.ssh/known_hosts
expect -c "spawn scp -r router root@192.168.1.1:/tmp; expect \"(yes/no)?\"; send \"yes\n\"; expect \"password:\"; send \"admin\n\"; expect eof"
echo "已上传，正在自动调用脚本……"
if [ -f ./router/custom.sh ]
then expect -c "spawn ssh root@192.168.1.1; expect \"password:\"; send \"admin\n\"; expect \"#\"; send \"sh /tmp/router/custom.sh\n\"; interact"
else expect -c "spawn ssh root@192.168.1.1; expect \"password:\"; send \"admin\n\"; expect \"#\"; send \"sh /tmp/router/general.sh\n\"; interact"
fi
